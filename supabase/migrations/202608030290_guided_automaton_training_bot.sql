-- Migration 202608030290_guided_automaton_training_bot.sql
-- Implementa o Bot Autômato de Treino (PvE), regras de turno 0, deck com exatamente 5 lendárias e 35 outras raridades, spam de efeitos com mana e reação inteligente

BEGIN;

CREATE SCHEMA IF NOT EXISTS game_ai;

-- 1. Helper para tirar snapshot do deck do bot com exatamente 5 lendárias e 35 outras
CREATE OR REPLACE FUNCTION game_private.snapshot_bot_training_deck(
  p_match_id uuid, p_user_id uuid, p_size integer
) RETURNS uuid LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE
    deck_id uuid;
    v_card_rec record;
    v_pos integer := 1;
BEGIN
    IF p_size <> 40 THEN 
        RAISE EXCEPTION 'TRAINING_DECK_SIZE_MUST_BE_40'; 
    END IF;
    
    INSERT INTO public.match_decks(match_id, user_id, total_cards, golden_cards_count)
    VALUES (p_match_id, p_user_id, p_size, 0) RETURNING id INTO deck_id;

    -- Inserir exatamente 5 cartas lendárias aleatórias
    FOR v_card_rec IN (
        SELECT * FROM public.cards 
        WHERE is_active AND card_type = 'normal' AND rarity = 'legendary'
        ORDER BY random() LIMIT 5
    ) LOOP
        INSERT INTO public.match_deck_cards(
            match_deck_id, source_card_id, card_version, card_name, image_url,
            element, rarity, card_type, is_golden, base_power, base_max_life, effect_mana_cost, tier,
            leader_cooldown, effect_definition, copy_number, initial_deck_position
        ) VALUES (
            deck_id, v_card_rec.id, v_card_rec.version, v_card_rec.name, v_card_rec.image_url,
            v_card_rec.element, v_card_rec.rarity, v_card_rec.card_type, v_card_rec.is_golden,
            v_card_rec.base_power, v_card_rec.base_max_life, v_card_rec.effect_mana_cost, v_card_rec.tier,
            v_card_rec.leader_cooldown,
            coalesce((SELECT jsonb_agg(jsonb_build_object('effect_order', e.effect_order, 'trigger_type', e.trigger_type,
              'effect_code', e.effect_code, 'target_mode', e.target_mode, 'parameters', e.parameters, 'priority', e.priority,
              'is_reaction', e.is_reaction, 'once_per_turn', e.once_per_turn) ORDER BY e.effect_order)
              FROM public.card_effects e WHERE e.card_id = v_card_rec.id AND e.is_active), '[]'::jsonb),
            1, v_pos
        );
        v_pos := v_pos + 1;
    END LOOP;

    -- Inserir exatamente 35 cartas aleatórias das outras raridades
    FOR v_card_rec IN (
        SELECT * FROM public.cards 
        WHERE is_active AND card_type = 'normal' AND rarity IN ('common', 'rare', 'epic')
        ORDER BY random() LIMIT 35
    ) LOOP
        INSERT INTO public.match_deck_cards(
            match_deck_id, source_card_id, card_version, card_name, image_url,
            element, rarity, card_type, is_golden, base_power, base_max_life, effect_mana_cost, tier,
            leader_cooldown, effect_definition, copy_number, initial_deck_position
        ) VALUES (
            deck_id, v_card_rec.id, v_card_rec.version, v_card_rec.name, v_card_rec.image_url,
            v_card_rec.element, v_card_rec.rarity, v_card_rec.card_type, v_card_rec.is_golden,
            v_card_rec.base_power, v_card_rec.base_max_life, v_card_rec.effect_mana_cost, v_card_rec.tier,
            v_card_rec.leader_cooldown,
            coalesce((SELECT jsonb_agg(jsonb_build_object('effect_order', e.effect_order, 'trigger_type', e.trigger_type,
              'effect_code', e.effect_code, 'target_mode', e.target_mode, 'parameters', e.parameters, 'priority', e.priority,
              'is_reaction', e.is_reaction, 'once_per_turn', e.once_per_turn) ORDER BY e.effect_order)
              FROM public.card_effects e WHERE e.card_id = v_card_rec.id AND e.is_active), '[]'::jsonb),
            1, v_pos
        );
        v_pos := v_pos + 1;
    END LOOP;

    -- Criar instâncias das cartas
    INSERT INTO public.match_cards(
        match_id, owner_user_id, controller_user_id, match_deck_card_id,
        source_card_id, zone, zone_position, is_face_up, base_power, base_max_life, current_power,
        maximum_power, current_life, maximum_life
    )
    SELECT p_match_id, p_user_id, p_user_id, d.id, d.source_card_id, 'deck', d.initial_deck_position, false,
      d.base_power, d.base_max_life, d.base_power, d.base_power, d.base_max_life, d.base_max_life
    FROM public.match_deck_cards d WHERE d.match_deck_id = deck_id;
    
    RETURN deck_id;
END;
$$;

-- 2. Redefinir a criação de partidas de treino
CREATE OR REPLACE FUNCTION public.create_training_match(p_deck_size integer DEFAULT 40)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $$
DECLARE
    human uuid := game_private.require_authenticated();
    bot constant uuid := '00000000-0000-4000-8000-000000000071';
    mid uuid;
    rule_id uuid;
BEGIN
    IF p_deck_size <> 40 THEN 
        RAISE EXCEPTION 'TRAINING_DECK_SIZE_MUST_BE_40'; 
    END IF;
    
    SELECT id INTO rule_id FROM public.game_rule_versions WHERE is_active ORDER BY created_at DESC LIMIT 1;
    IF rule_id IS NULL THEN 
        RAISE EXCEPTION 'ACTIVE_GAME_RULE_VERSION_REQUIRED'; 
    END IF;
    
    -- Inicia na fase de banimento (requires_bans = true)
    INSERT INTO public.matches(rule_version_id, match_type, status, created_by, requires_bans, is_private, started_at, expires_at, current_turn, active_player_id)
    VALUES (rule_id, 'training', 'ban_phase', human, true, true, now(), now() + interval '8 hours', 0, human)
    RETURNING id INTO mid;
    
    INSERT INTO public.match_players(match_id, user_id, player_number)
    VALUES (mid, human, 1), (mid, bot, 2);
    
    -- Decks snapshots
    PERFORM game_private.snapshot_random_training_deck(mid, human, p_deck_size);
    PERFORM game_private.snapshot_bot_training_deck(mid, bot, p_deck_size);
    
    INSERT INTO public.match_public_states(match_id, player1_user_id, player2_user_id, player1_username, player2_username, player1_avatar_url, player2_avatar_url)
    SELECT mid, human, bot, p1.username, p2.username, p1.avatar_url, p2.avatar_url
    FROM public.profiles p1 CROSS JOIN public.profiles p2 WHERE p1.id = human AND p2.id = bot;
    
    INSERT INTO public.training_matches(match_id, human_user_id, bot_user_id) 
    VALUES (mid, human, bot);
    
    PERFORM game_private.deal_initial_hands(mid);
    PERFORM game_private.recalculate_match_public_state(mid);
    
    RETURN jsonb_build_object('match_id', mid, 'bot_user_id', bot, 'deck_size', 40, 'status', 'ban_phase');
END;
$$;

-- 3. Intervenção na RPC submit_match_ban para tratar o bot no banimento
CREATE OR REPLACE FUNCTION public.submit_match_ban(p_match_id uuid, p_source_card_id uuid, p_ban_category text, p_expected_version bigint DEFAULT NULL::bigint)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $$
DECLARE
    v_user_id uuid := auth.uid();
    v_target_id uuid;
    v_bot_id uuid := '00000000-0000-4000-8000-000000000071'::uuid;
    v_match_type text;
    v_player_legendary_card_id uuid;
BEGIN
    SELECT match_type INTO v_match_type FROM public.matches WHERE id = p_match_id;

    SELECT user_id INTO v_target_id FROM public.match_players
    WHERE match_id = p_match_id AND user_id <> v_user_id LIMIT 1;
    
    IF v_target_id IS NULL THEN 
        RAISE EXCEPTION 'OPPONENT_NOT_FOUND'; 
    END IF;

    IF p_source_card_id IS NULL THEN
        INSERT INTO public.match_bans(match_id, banned_by_user_id, target_user_id, source_card_id, ban_category, is_skipped)
        VALUES (p_match_id, v_user_id, v_target_id, null, coalesce(p_ban_category, 'rare'), true);
    ELSE
        INSERT INTO public.match_bans(match_id, banned_by_user_id, target_user_id, source_card_id, ban_category, is_skipped)
        VALUES (p_match_id, v_user_id, v_target_id, p_source_card_id, coalesce(p_ban_category, 'rare'), false);

        UPDATE public.match_cards
        SET zone = 'banished', is_face_up = true
        WHERE id = (
            SELECT id FROM public.match_cards 
            WHERE match_id = p_match_id AND owner_user_id = v_target_id AND source_card_id = p_source_card_id AND zone = 'deck'
            LIMIT 1
        );
    END IF;

    -- Automação de banimento do bot em treino e campanha
    IF v_target_id = v_bot_id AND NOT EXISTS (SELECT 1 FROM public.match_bans WHERE match_id = p_match_id AND banned_by_user_id = v_bot_id) THEN
        -- Sorteia uma carta aleatória do deck do humano para banir
        SELECT mc.id INTO v_player_legendary_card_id
        FROM public.match_cards mc
        WHERE mc.match_id = p_match_id AND mc.owner_user_id = v_user_id AND mc.zone = 'deck'
        ORDER BY random() LIMIT 1;
        
        IF v_player_legendary_card_id IS NOT NULL THEN
            UPDATE public.match_cards SET zone = 'banished', is_face_up = true WHERE id = v_player_legendary_card_id;
            
            INSERT INTO public.match_bans(match_id, banned_by_user_id, target_user_id, source_card_id, ban_category, is_skipped)
            VALUES (p_match_id, v_bot_id, v_user_id, (SELECT source_card_id FROM public.match_cards WHERE id = v_player_legendary_card_id), 'any', false);
        ELSE
            INSERT INTO public.match_bans(match_id, banned_by_user_id, target_user_id, source_card_id, ban_category, is_skipped)
            VALUES (p_match_id, v_bot_id, v_user_id, null, 'any', true);
        END IF;
    END IF;

    IF (SELECT count(*) FROM public.match_bans WHERE match_id = p_match_id) >= 2 THEN
        UPDATE public.matches SET status = 'setup' WHERE id = p_match_id;
        PERFORM game_private.deal_initial_hands(p_match_id);
        RETURN jsonb_build_object('ban_phase_complete', true);
    END IF;

    RETURN jsonb_build_object('ban_phase_complete', false);
END;
$$;

-- 4. Intervenção na RPC submit_match_setup para automatizar o bot
CREATE OR REPLACE FUNCTION public.submit_match_setup(p_match_id uuid, p_life_card_ids uuid[], p_reinforcement_card_ids uuid[] DEFAULT '{}'::uuid[], p_leader_card_id uuid DEFAULT NULL::uuid, p_expected_version bigint DEFAULT NULL::bigint)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $$
DECLARE
    v_user_id uuid := auth.uid();
    v_target_id uuid;
    v_bot_id uuid := '00000000-0000-4000-8000-000000000071'::uuid;
    v_card_id uuid;
    v_pos int := 1;
    v_bot_card record;
    v_first_player uuid;
    v_d1 int;
    v_d2 int;
    v_match_type text;
BEGIN
    SELECT match_type INTO v_match_type FROM public.matches WHERE id = p_match_id;

    SELECT user_id INTO v_target_id FROM public.match_players
    WHERE match_id = p_match_id AND user_id <> v_user_id LIMIT 1;

    IF v_target_id IS NULL THEN
        v_target_id := v_bot_id;
    END IF;

    -- Human setup
    v_pos := 1;
    FOREACH v_card_id IN ARRAY p_life_card_ids LOOP
        UPDATE public.match_cards
        SET zone = 'life', zone_position = v_pos, is_face_up = true
        WHERE match_id = p_match_id 
          AND owner_user_id = v_user_id 
          AND (id = v_card_id OR source_card_id = v_card_id)
          AND zone = 'hand';
        v_pos := v_pos + 1;
    END LOOP;

    IF array_length(p_reinforcement_card_ids, 1) > 0 THEN
        v_pos := 1;
        FOREACH v_card_id IN ARRAY p_reinforcement_card_ids LOOP
            UPDATE public.match_cards
            SET zone = 'reinforcement', zone_position = v_pos, is_face_up = false
            WHERE match_id = p_match_id 
              AND owner_user_id = v_user_id 
              AND (id = v_card_id OR source_card_id = v_card_id)
              AND zone = 'hand';
        v_pos := v_pos + 1;
        END LOOP;
    END IF;

    -- Bot setup (Automaton)
    IF v_target_id = v_bot_id OR NOT EXISTS (SELECT 1 FROM public.profiles WHERE id = v_target_id) THEN
        IF v_match_type = 'campaign' THEN
            v_pos := 1;
            FOR v_bot_card IN (
                SELECT mc.id 
                FROM public.match_cards mc
                JOIN public.match_deck_cards mdc ON mdc.id = mc.match_deck_card_id
                WHERE mc.match_id = p_match_id AND mc.owner_user_id = v_bot_id AND mc.zone = 'hand'
                ORDER BY mdc.base_max_life DESC, mc.id ASC
                LIMIT 3
            ) LOOP
                UPDATE public.match_cards 
                SET zone = 'life', zone_position = v_pos, is_face_up = true 
                WHERE id = v_bot_card.id;
                v_pos := v_pos + 1;
            END LOOP;

            v_pos := 1;
            FOR v_bot_card IN (
                SELECT mc.id 
                FROM public.match_cards mc
                WHERE mc.match_id = p_match_id AND mc.owner_user_id = v_bot_id AND mc.zone = 'hand'
                ORDER BY random()
                LIMIT 2
            ) LOOP
                UPDATE public.match_cards 
                SET zone = 'reinforcement', zone_position = v_pos, is_face_up = false 
                WHERE id = v_bot_card.id;
                v_pos := v_pos + 1;
            END LOOP;
        ELSE
            -- Modo Treino: as 3 com maior HP base na vida; o resto na mão (sem reforços no turno 0)
            v_pos := 1;
            FOR v_bot_card IN (
                SELECT mc.id 
                FROM public.match_cards mc
                JOIN public.match_deck_cards mdc ON mdc.id = mc.match_deck_card_id
                WHERE mc.match_id = p_match_id AND mc.owner_user_id = v_bot_id AND mc.zone = 'hand'
                ORDER BY mdc.base_max_life DESC, mc.id ASC
                LIMIT 3
            ) LOOP
                UPDATE public.match_cards 
                SET zone = 'life', zone_position = v_pos, is_face_up = true 
                WHERE id = v_bot_card.id;
                v_pos := v_pos + 1;
            END LOOP;
        END IF;
    END IF;

    -- Iniciativa
    v_d1 := floor(random() * 20 + 1)::int;
    v_d2 := floor(random() * 20 + 1)::int;
    IF v_d1 >= v_d2 THEN
        v_first_player := v_user_id;
    ELSE
        v_first_player := v_target_id;
    END IF;

    UPDATE public.matches 
    SET status = 'initiative', 
        engine_state = 'lifecycle',
        active_player_id = v_first_player,
        initiative_result = jsonb_build_object(
            'winner_user_id', v_first_player,
            'player1', v_d1,
            'player2', v_d2
        )
    WHERE id = p_match_id;

    RETURN jsonb_build_object('setup_complete', true, 'status', 'initiative');
END;
$$;

-- 5. Rotina de Inteligência PVE: game_ai.execute_bot_actions
CREATE OR REPLACE FUNCTION game_ai.execute_bot_actions(p_match_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path = ''
AS $$
DECLARE
    v_bot_id constant uuid := '00000000-0000-4000-8000-000000000071';
    v_human_id uuid;
    v_match public.matches;
    v_reinforcement_count integer;
    v_hand_count integer;
    v_chosen_card record;
    v_slot integer;
    v_version bigint;
    v_attacker_ids uuid[];
    v_total_power integer;
    v_effect_card record;
    v_target_id uuid;
    v_mana_available integer;
    v_play_count integer;
    v_success boolean;
    v_res jsonb;
BEGIN
    SELECT human_user_id INTO v_human_id FROM public.training_matches WHERE match_id = p_match_id;
    IF v_human_id IS NULL THEN
        RAISE EXCEPTION 'TRAINING_MATCH_NOT_FOUND';
    END IF;

    SELECT * INTO v_match FROM public.matches WHERE id = p_match_id FOR UPDATE;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'MATCH_NOT_FOUND';
    END IF;
    
    IF v_match.status <> 'in_progress' OR v_match.engine_state <> 'turn_action' THEN
        RETURN jsonb_build_object('success', false, 'reason', 'MATCH_FLOW_BLOCKED');
    END IF;

    IF v_match.active_player_id <> v_bot_id THEN
        RETURN jsonb_build_object('success', false, 'reason', 'BOT_IS_NOT_ACTIVE');
    END IF;

    v_version := v_match.state_version;

    SELECT COUNT(*)::integer INTO v_hand_count
    FROM public.match_cards
    WHERE match_id = p_match_id AND owner_user_id = v_bot_id AND zone = 'hand';

    SELECT COUNT(*)::integer INTO v_reinforcement_count
    FROM public.match_cards
    WHERE match_id = p_match_id AND controller_user_id = v_bot_id AND zone = 'reinforcement' AND current_life > 0;

    -- A. Regra de Reforço (Defesa Inteligente)
    IF v_reinforcement_count = 0 AND v_hand_count > 0 THEN
        SELECT * INTO v_chosen_card
        FROM public.match_cards
        WHERE match_id = p_match_id AND owner_user_id = v_bot_id AND zone = 'hand'
        ORDER BY random() LIMIT 1;

        IF FOUND THEN
            SELECT gs.slot INTO v_slot 
            FROM generate_series(1, 5) gs(slot)
            WHERE NOT EXISTS (
                SELECT 1 FROM public.match_cards 
                WHERE match_id = p_match_id AND controller_user_id = v_bot_id AND zone = 'reinforcement' AND zone_position = gs.slot
            ) ORDER BY gs.slot LIMIT 1;

            IF v_slot IS NOT NULL THEN
                PERFORM game_private.move_card_checked(v_chosen_card.id, 'reinforcement', v_slot, false);
                v_hand_count := v_hand_count - 1;
                v_reinforcement_count := 1;
                
                v_version := game_private.record_match_action(
                    p_match_id, v_bot_id, 'card_played', 
                    jsonb_build_object('match_card_id', v_chosen_card.id, 'destination_zone', 'reinforcement', 'destination_position', v_slot, 'training_bot', true), 
                    '{}'::jsonb, v_version
                );
            END IF;
        END IF;
    END IF;

    -- B. Regra de Ataque (Ofensiva Cadenciada)
    v_play_count := floor(random() * 2 + 2)::integer; -- 2 ou 3
    FOR i IN 1..v_play_count LOOP
        IF v_hand_count > 0 THEN
            SELECT * INTO v_chosen_card
            FROM public.match_cards
            WHERE match_id = p_match_id AND owner_user_id = v_bot_id AND zone = 'hand'
            ORDER BY random() LIMIT 1;

            IF FOUND THEN
                SELECT gs.slot INTO v_slot 
                FROM generate_series(1, 5) gs(slot)
                WHERE NOT EXISTS (
                    SELECT 1 FROM public.match_cards 
                    WHERE match_id = p_match_id AND controller_user_id = v_bot_id AND zone = 'attacker' AND zone_position = gs.slot
                ) ORDER BY gs.slot LIMIT 1;

                IF v_slot IS NOT NULL THEN
                    PERFORM game_private.move_card_checked(v_chosen_card.id, 'attacker', v_slot, true);
                    v_hand_count := v_hand_count - 1;
                    
                    v_version := game_private.record_match_action(
                        p_match_id, v_bot_id, 'card_played', 
                        jsonb_build_object('match_card_id', v_chosen_card.id, 'destination_zone', 'attacker', 'destination_position', v_slot, 'training_bot', true), 
                        '{}'::jsonb, v_version
                    );
                END IF;
            END IF;
        END IF;
    END LOOP;

    -- C. Regra de Efeitos (Spam de Mana)
    SELECT mana_available INTO v_mana_available 
    FROM public.match_players 
    WHERE match_id = p_match_id AND user_id = v_bot_id;

    WHILE v_mana_available > 0 LOOP
        SELECT mc.id, ce.effect_code, ce.target_mode, ce.effect_mana_cost
        INTO v_effect_card
        FROM public.match_cards mc
        JOIN public.match_deck_cards mdc ON mdc.id = mc.match_deck_card_id
        JOIN public.card_effects ce ON ce.card_id = mc.source_card_id
        WHERE mc.match_id = p_match_id
          AND mc.controller_user_id = v_bot_id
          AND mc.zone IN ('life', 'reinforcement')
          AND mc.current_life > 0
          AND ce.trigger_type = 'manual'
          AND ce.effect_mana_cost <= v_mana_available
          AND NOT EXISTS (
              SELECT 1 FROM public.match_effect_uses 
              WHERE match_id = p_match_id AND match_card_id = mc.id AND turn_number = v_match.current_turn
          )
        ORDER BY random() LIMIT 1;

        IF NOT FOUND THEN
            EXIT;
        END IF;

        v_target_id := NULL;
        IF v_effect_card.target_mode IN ('enemy', 'selected') THEN
            SELECT id INTO v_target_id 
            FROM public.match_cards
            WHERE match_id = p_match_id AND controller_user_id = v_human_id AND zone IN ('attacker', 'reinforcement', 'life') AND current_life > 0
            ORDER BY random() LIMIT 1;
        ELSIF v_effect_card.target_mode = 'enemy_graveyard' THEN
            SELECT id INTO v_target_id 
            FROM public.match_cards
            WHERE match_id = p_match_id AND owner_user_id = v_human_id AND zone = 'graveyard'
            ORDER BY random() LIMIT 1;
        ELSIF v_effect_card.target_mode = 'ally' THEN
            SELECT id INTO v_target_id 
            FROM public.match_cards
            WHERE match_id = p_match_id AND controller_user_id = v_bot_id AND zone IN ('attacker', 'reinforcement', 'life') AND current_life > 0 AND id != v_effect_card.id
            ORDER BY random() LIMIT 1;
        ELSIF v_effect_card.target_mode = 'hand' THEN
            SELECT id INTO v_target_id 
            FROM public.match_cards
            WHERE match_id = p_match_id AND owner_user_id = v_bot_id AND zone = 'hand'
            ORDER BY random() LIMIT 1;
        ELSIF v_effect_card.target_mode = 'deck' THEN
            SELECT id INTO v_target_id 
            FROM public.match_cards
            WHERE match_id = p_match_id AND owner_user_id = v_bot_id AND zone = 'deck'
            ORDER BY random() LIMIT 1;
        END IF;

        BEGIN
            v_res := public.activate_card_effect_v2(p_match_id, v_effect_card.id, 1, v_target_id, v_version);
            v_version := (v_res->>'state_version')::bigint;
            
            SELECT mana_available INTO v_mana_available 
            FROM public.match_players 
            WHERE match_id = p_match_id AND user_id = v_bot_id;
        EXCEPTION WHEN OTHERS THEN
            INSERT INTO public.match_effect_uses (match_id, match_card_id, turn_number, used_at)
            VALUES (p_match_id, v_effect_card.id, v_match.current_turn, now())
            ON CONFLICT DO NOTHING;
        END;
    END LOOP;

    -- D. Encerramento (Declara Ataque ou Passa)
    SELECT array_agg(mc.id ORDER BY mc.zone_position), sum(mc.current_power)::integer
    INTO v_attacker_ids, v_total_power
    FROM public.match_cards mc
    WHERE mc.match_id = p_match_id AND mc.controller_user_id = v_bot_id AND mc.zone = 'attacker'
      AND mc.current_life > 0 AND mc.can_attack AND NOT mc.has_attacked_this_turn;

    IF coalesce(cardinality(v_attacker_ids), 0) > 0 THEN
        v_res := public.declare_attack(p_match_id, v_attacker_ids, false, v_version);
        v_version := (v_res->>'state_version')::bigint;
        RETURN jsonb_build_object('success', true, 'action', 'attack_declared', 'state_version', v_version);
    ELSE
        v_res := public.end_turn(p_match_id, v_version);
        v_version := (v_res->>'state_version')::bigint;
        RETURN jsonb_build_object('success', true, 'action', 'turn_ended', 'state_version', v_version);
    END IF;
END;
$$;

-- 6. Trigger para automação da janela de reação do Bot no modo treino
CREATE OR REPLACE FUNCTION game_private.auto_bot_attack_reaction_trigger()
RETURNS TRIGGER
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    v_is_training boolean;
    v_react_card record;
    v_mana_available integer;
    v_res jsonb;
    v_version bigint;
BEGIN
    SELECT EXISTS (
        SELECT 1 FROM public.training_matches 
        WHERE match_id = NEW.match_id AND bot_user_id = NEW.defender_user_id
    ) INTO v_is_training;

    IF v_is_training AND NEW.status = 'awaiting_reaction' THEN
        -- 50% de chance de reagir
        IF random() < 0.5 THEN
            SELECT mana_available INTO v_mana_available 
            FROM public.match_players 
            WHERE match_id = NEW.match_id AND user_id = NEW.defender_user_id;

            SELECT mc.id, ce.effect_mana_cost
            INTO v_react_card
            FROM public.match_cards mc
            JOIN public.card_effects ce ON ce.card_id = mc.source_card_id
            WHERE mc.match_id = NEW.match_id
              AND mc.controller_user_id = NEW.defender_user_id
              AND mc.zone IN ('life', 'reinforcement')
              AND mc.current_life > 0
              AND ce.trigger_type = 'reaction'
              AND ce.effect_mana_cost <= v_mana_available
            ORDER BY random() LIMIT 1;

            IF FOUND THEN
                BEGIN
                    v_res := public.activate_card_effect_v2(NEW.match_id, v_react_card.id, 1, null, NEW.declared_state_version);
                    RETURN NEW;
                EXCEPTION WHEN OTHERS THEN
                END;
            END IF;
        END IF;

        -- Declinar reação
        BEGIN
            v_res := public.decline_attack_reaction(NEW.id, NEW.declared_state_version);
            v_version := (v_res->>'state_version')::bigint;
            PERFORM public.finalize_pending_attack_turn(NEW.id, v_version);
        EXCEPTION WHEN OTHERS THEN
        END;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS auto_bot_attack_reaction ON public.pending_attacks;
CREATE TRIGGER auto_bot_attack_reaction
AFTER INSERT ON public.pending_attacks
FOR EACH ROW EXECUTE FUNCTION game_private.auto_bot_attack_reaction_trigger();

COMMIT;
