BEGIN;

-- 1. Refatoração do Banimento (Exatamente 1 carta do inimigo)
CREATE OR REPLACE FUNCTION public.ban_card(
    p_match_id uuid,
    p_source_card_id uuid,
    p_expected_version bigint default 0
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    v_user_id uuid := game_private.require_authenticated();
    v_match public.matches;
    v_target_id uuid;
    v_complete boolean;
    v_new_version bigint;
BEGIN
    v_match := game_private.lock_match_for_action(p_match_id, p_expected_version, array['ban_phase']);
    
    SELECT user_id INTO v_target_id FROM public.match_players
    WHERE match_id = p_match_id AND user_id <> v_user_id;
    
    IF v_target_id IS NULL THEN RAISE EXCEPTION 'OPPONENT_NOT_FOUND'; END IF;
    
    -- Verifica se já baniu 1 carta
    IF EXISTS(SELECT 1 FROM public.match_bans WHERE match_id = p_match_id AND banned_by_user_id = v_user_id) THEN
        RAISE EXCEPTION 'ALREADY_BANNED_A_CARD';
    END IF;

    IF p_source_card_id IS NULL THEN
        RAISE EXCEPTION 'MUST_SELECT_A_CARD_TO_BAN';
    END IF;

    -- Banir a carta (move para banished)
    INSERT INTO public.match_bans(match_id, banned_by_user_id, target_user_id, source_card_id, ban_category, is_skipped)
    VALUES (p_match_id, v_user_id, v_target_id, p_source_card_id, 'deck_card', false);

    UPDATE public.match_cards
    SET zone = 'banished', zone_position = null, is_face_up = true
    WHERE match_id = p_match_id AND owner_user_id = v_target_id
      AND source_card_id = p_source_card_id AND zone = 'deck'
      -- Remove only one copy
      AND id = (
          SELECT id FROM public.match_cards 
          WHERE match_id = p_match_id AND owner_user_id = v_target_id 
          AND source_card_id = p_source_card_id AND zone = 'deck' 
          LIMIT 1
      );

    -- Verifica se os 2 já baniram
    SELECT count(*) = 2 INTO v_complete
    FROM public.match_bans WHERE match_id = p_match_id;

    IF v_complete THEN
        PERFORM game_private.deal_initial_hands(p_match_id);
    END IF;

    v_new_version := game_private.record_match_action(
        p_match_id, v_user_id, 'card_banned',
        jsonb_build_object('target_user_id', v_target_id, 'source_card_id', p_source_card_id, 'ban_phase_complete', v_complete),
        '{}'::jsonb, p_expected_version
    );

    RETURN jsonb_build_object('ban_phase_complete', v_complete, 'state_version', v_new_version);
END;
$$;

-- Ajuste no deal_initial_hands para sempre comprar 7 (Turno 0)
CREATE OR REPLACE FUNCTION game_private.deal_initial_hands(p_match_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    v_size integer := 7; -- OBRIGATÓRIO 7 CARTAS (V38)
    v_player record;
BEGIN
    FOR v_player IN
        SELECT user_id FROM public.match_players WHERE match_id = p_match_id ORDER BY player_number
    LOOP
        IF NOT EXISTS (
            SELECT 1 FROM public.match_cards
            WHERE match_id = p_match_id AND owner_user_id = v_player.user_id AND zone = 'hand'
        ) THEN
            PERFORM game_private.draw_internal(p_match_id, v_player.user_id, v_size);
        END IF;
    END LOOP;

    UPDATE public.matches SET status = 'setup' WHERE id = p_match_id;
    PERFORM game_private.recalculate_match_public_state(p_match_id);
END;
$$;

-- 2. Turno 0: Alocação Tática e Lançamento de Moeda
CREATE OR REPLACE FUNCTION public.submit_match_setup(
    p_match_id uuid,
    p_life_card_ids uuid[],
    p_reinforcement_card_ids uuid[] default array[]::uuid[],
    p_leader_card_id uuid default null,
    p_expected_version bigint default 0
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    v_user_id uuid := game_private.require_authenticated();
    v_match public.matches;
    v_ready boolean;
    v_new_version bigint;
    v_all_ids uuid[];
    v_distinct_count integer;
    v_total_selected integer;
    v_p1 uuid;
    v_p2 uuid;
    v_first uuid;
BEGIN
    v_match := game_private.lock_match_for_action(p_match_id, p_expected_version, array['setup']);
    
    IF EXISTS(SELECT 1 FROM public.match_players WHERE match_id = p_match_id AND user_id = v_user_id AND setup_finished = true) THEN
        RAISE EXCEPTION 'SETUP_ALREADY_SUBMITTED';
    END IF;

    -- OBRIGATÓRIO: EXATAMENTE 3 CARTAS DE VIDA (V38)
    IF coalesce(cardinality(p_life_card_ids), 0) <> 3 THEN 
        RAISE EXCEPTION 'EXACT_LIFE_CARDS_REQUIRED'; 
    END IF;

    -- Validação de duplicatas
    v_all_ids := p_life_card_ids || coalesce(p_reinforcement_card_ids, array[]::uuid[]);
    v_total_selected := cardinality(v_all_ids);
    
    SELECT count(distinct u.id)::integer INTO v_distinct_count FROM unnest(v_all_ids) AS u(id);
    IF v_distinct_count <> v_total_selected THEN
        RAISE EXCEPTION 'DUPLICATED_SETUP_CARD';
    END IF;

    -- Verifica se estão na mão
    IF EXISTS(
        SELECT 1 FROM unnest(v_all_ids) AS selected(id)
        WHERE NOT EXISTS(
            SELECT 1 FROM public.match_cards mc
            WHERE mc.id = selected.id AND mc.match_id = p_match_id AND mc.owner_user_id = v_user_id AND mc.zone = 'hand'
        )
    ) THEN 
        RAISE EXCEPTION 'SETUP_CARD_NOT_IN_HAND'; 
    END IF;

    -- Posicionar vidas
    FOR i IN 1..cardinality(p_life_card_ids) LOOP
        UPDATE public.match_cards SET zone = 'life', zone_position = i, is_face_up = true
        WHERE id = p_life_card_ids[i] AND match_id = p_match_id;
    END LOOP;

    -- Posicionar reforços (ocultos)
    IF p_reinforcement_card_ids IS NOT NULL THEN
        FOR i IN 1..cardinality(p_reinforcement_card_ids) LOOP
            UPDATE public.match_cards SET zone = 'reinforcement', zone_position = i, is_face_up = false
            WHERE id = p_reinforcement_card_ids[i] AND match_id = p_match_id;
        END LOOP;
    END IF;

    UPDATE public.match_players SET setup_finished = true WHERE match_id = p_match_id AND user_id = v_user_id;

    SELECT count(*) = 2 INTO v_ready FROM public.match_players WHERE match_id = p_match_id AND setup_finished = true;

    IF v_ready THEN
        -- RNG da Moeda 3D
        SELECT user_id INTO v_p1 FROM public.match_players WHERE match_id = p_match_id AND player_number = 1;
        SELECT user_id INTO v_p2 FROM public.match_players WHERE match_id = p_match_id AND player_number = 2;
        
        IF random() <= 0.5 THEN
            v_first := v_p1;
        ELSE
            v_first := v_p2;
        END IF;

        UPDATE public.matches 
        SET status = 'initiative', 
            initiative_result = jsonb_build_object('coin_flip', true, 'first_player', v_first),
            active_player_id = v_first
        WHERE id = p_match_id;
    END IF;

    PERFORM game_private.recalculate_match_public_state(p_match_id);

    v_new_version := game_private.record_match_action(
        p_match_id, v_user_id, 'setup_submitted',
        jsonb_build_object('life_cards', p_life_card_ids, 'reinforcement_cards', p_reinforcement_card_ids, 'all_ready', v_ready),
        '{}'::jsonb, p_expected_version
    );

    RETURN jsonb_build_object('all_ready', v_ready, 'state_version', v_new_version);
END;
$$;

-- Novo RPC: O front-end chama isso após exibir a animação 3D da Moeda
CREATE OR REPLACE FUNCTION public.acknowledge_initiative(p_match_id uuid, p_expected_version bigint default 0)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    v_user_id uuid := game_private.require_authenticated();
    v_match public.matches;
    v_new_version bigint;
BEGIN
    v_match := game_private.lock_match_for_action(p_match_id, p_expected_version, array['initiative']);
    
    -- Começa oficialmente a rodada 1
    UPDATE public.matches SET status = 'in_progress', current_turn = 1 WHERE id = p_match_id;
    
    -- Trigger on_turn_start para o jogador 1 (se precisar de mana ou passiva de start)
    -- Por padrão, no Gwentofier, mana pode ser dada no on_turn_start.
    -- (Aqui poderíamos chamar `game_private.trigger_auto_engines(p_match_id, 'on_turn_start')`)

    v_new_version := game_private.record_match_action(
        p_match_id, v_user_id, 'turn_started',
        jsonb_build_object('turn', 1, 'active_player', v_match.active_player_id),
        '{}'::jsonb, p_expected_version
    );

    RETURN jsonb_build_object('success', true, 'state_version', v_new_version);
END;
$$;

COMMIT;
