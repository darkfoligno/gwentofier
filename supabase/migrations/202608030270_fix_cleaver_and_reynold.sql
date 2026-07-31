-- Migration 202608030270_fix_cleaver_and_reynold.sql
-- Corrige o efeito de Cutelo (COMMON_024) para descartar apenas 1 carta
-- Corrige o efeito de Reynold (COMMON_035) para mover o anão do deck para a zona attacker antes de declarar o ataque

BEGIN;

-- 1. Atualizar o parâmetro de descarte do Cutelo no catálogo
UPDATE public.card_effects ce
SET parameters = '{"allowed_source_zones":["attacker"],"discard_cost":1,"chosen_discard":true,"chosen_enemy_life":true,"ignore_reinforcement":true}'::jsonb
FROM public.cards c
WHERE ce.card_id = c.id AND c.code = 'COMMON_024';

-- 2. Renomear e criar a nova função execute_common_effect_internal (Chain of Responsibility)
ALTER FUNCTION game_private.execute_common_effect_internal(uuid,uuid,uuid,text,jsonb,uuid,jsonb) RENAME TO execute_common_effect_internal_v37_core;

CREATE OR REPLACE FUNCTION game_private.execute_common_effect_internal(
    p_match_id uuid,
    p_actor uuid,
    p_source uuid,
    p_code text,
    p_params jsonb,
    p_target uuid DEFAULT NULL::uuid,
    p_event jsonb DEFAULT NULL::jsonb
)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path = ''
AS $$
DECLARE
    v_ids uuid[];
    v_id uuid;
    v_id2 uuid;
    v_pos integer;
    v_turn integer;
    v_damage jsonb;
    v_result jsonb;
    v_roll integer;
    v_opp_hand jsonb;
    v_opp_grave jsonb;
    v_opponent_id uuid;
    s public.match_cards;
    t public.match_cards;
    opp uuid;
BEGIN
    SELECT * INTO s FROM public.match_cards WHERE id = p_source AND match_id = p_match_id;
    SELECT user_id INTO opp FROM public.match_players WHERE match_id = p_match_id AND user_id != p_actor LIMIT 1;
    SELECT current_turn INTO v_turn FROM public.matches WHERE id = p_match_id;

    IF p_code = 'common_cleaver_discard_for_direct' THEN
        IF s.zone <> 'attacker' THEN 
            RAISE EXCEPTION 'CLEAVER_MUST_BE_IN_ATTACK_FIELD'; 
        END IF;
        IF NOT EXISTS (
            SELECT 1 FROM public.match_cards mc 
            WHERE mc.id = p_target AND mc.match_id = p_match_id AND mc.controller_user_id = opp AND mc.zone = 'life' AND mc.current_life > 0
        ) THEN 
            RAISE EXCEPTION 'CLEAVER_REQUIRES_ENEMY_LIFE_TARGET'; 
        END IF;
        
        SELECT coalesce(array_agg(mc.id), '{}'::uuid[]) INTO v_ids 
        FROM public.match_cards mc 
        WHERE mc.match_id = p_match_id AND mc.owner_user_id = p_actor AND mc.zone = 'hand';
        
        IF cardinality(v_ids) < 1 THEN 
            RAISE EXCEPTION 'CLEAVER_REQUIRES_ONE_HAND_CARD'; 
        END IF;
        
        INSERT INTO public.pending_effect_choices(
            match_id, actor_user_id, source_match_card_id, effect_order, effect_code, choice_type, min_choices, max_choices, candidate_ids, public_prompt, private_context, expected_state_version
        ) VALUES (
            p_match_id, p_actor, p_source, 1, p_code, 'hand_card', 1, 1, v_ids, 'Escolha exatamente 1 carta da sua mão para descartar.', jsonb_build_object('target_life_card_id', p_target), (SELECT state_version FROM public.matches WHERE id = p_match_id)
        );
        
        RETURN jsonb_build_object('choice_pending', true, 'discard_candidates', cardinality(v_ids), 'target_life_card_id', p_target);

    ELSIF p_code = 'common_reynold_forced_dwarf_attack' THEN
        SELECT mc.* INTO t 
        FROM public.match_cards mc 
        JOIN public.match_deck_cards d ON d.id = mc.match_deck_card_id 
        WHERE mc.match_id = p_match_id AND mc.owner_user_id = p_actor AND mc.zone = 'deck' AND d.card_name ILIKE '%Anão%' 
        ORDER BY random() LIMIT 1 FOR UPDATE OF mc;
        
        IF NOT FOUND THEN
            SELECT coalesce(array_agg(mc.id), '{}'::uuid[]) INTO v_ids 
            FROM public.match_cards mc 
            JOIN public.match_deck_cards d ON d.id = mc.match_deck_card_id 
            WHERE mc.match_id = p_match_id AND mc.owner_user_id = p_actor AND mc.zone = 'deck' AND lower(d.card_name) = lower('Reynold Longmes');
            
            FOREACH v_id IN ARRAY v_ids LOOP 
                PERFORM game_private.move_card_checked(v_id, 'graveyard', null, true); 
            END LOOP;
            
            RETURN jsonb_build_object('dwarf_found', false,'reynolds_sent_to_graveyard',v_ids);
        END IF;

        -- Localizar um slot livre na linha attacker do próprio jogador
        SELECT coalesce(max(mc.zone_position), -1) + 1 INTO v_pos 
        FROM public.match_cards mc 
        WHERE mc.match_id = p_match_id AND mc.owner_user_id = p_actor AND mc.zone = 'attacker';

        -- Mover o Anão do deck para o campo de ataque (move_card_checked validará se o campo está cheio)
        PERFORM game_private.move_card_checked(t.id, 'attacker', v_pos, true);

        -- Selecionar uma Carta de Vida ativa do inimigo
        SELECT mc.id INTO v_id 
        FROM public.match_cards mc 
        WHERE mc.match_id = p_match_id AND mc.controller_user_id = opp AND mc.zone = 'life' AND mc.current_life > 0 
        ORDER BY random() LIMIT 1 FOR UPDATE;
        
        IF v_id IS NULL THEN 
            RAISE EXCEPTION 'NO_ENEMY_LIFE_CARD'; 
        END IF;
        
        v_damage := game_private.apply_damage_internal(p_match_id, v_id, t.current_power, v_turn);
        
        IF NOT coalesce((v_damage->>'destroyed')::boolean, false) THEN 
            UPDATE public.match_cards mc 
            SET zone = 'banished', zone_position = null, is_face_up = true 
            FROM public.match_deck_cards d 
            WHERE d.id = mc.match_deck_card_id AND mc.match_id = p_match_id AND mc.owner_user_id = p_actor AND mc.zone = 'deck' AND lower(d.card_name) = lower('Reynold Longmes');
        END IF;
        
        RETURN jsonb_build_object('dwarf_found', true, 'dwarf_card_id', t.id, 'random_life_target_id', v_id, 'damage', v_damage, 'reynolds_banished_on_failure', NOT coalesce((v_damage->>'destroyed')::boolean, false));

    ELSE
        RETURN game_private.execute_common_effect_internal_v37_core(p_match_id, p_actor, p_source, p_code, p_params, p_target, p_event);
    END IF;
END;
$$;

COMMIT;
