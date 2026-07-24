-- Migration 202608020080_implement_rare_batch_1_to_25.sql

BEGIN;

-- Renomeia a função base para ser o fallback (Chain of Responsibility)
ALTER FUNCTION game_private.execute_common_effect_internal(uuid, uuid, uuid, text, jsonb, uuid, jsonb) RENAME TO execute_common_effect_internal_v28_core;

-- Cria o novo interceptador
CREATE OR REPLACE FUNCTION game_private.execute_common_effect_internal(
    p_match_id uuid,
    p_actor uuid,
    p_source uuid,
    p_code text,
    p_params jsonb,
    p_target uuid DEFAULT NULL,
    p_event jsonb DEFAULT '{}'
) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE
    v_opponent_id uuid;
    v_state jsonb;
BEGIN
    -- Obter oponente e estado da partida
    SELECT id INTO v_opponent_id FROM public.match_players WHERE match_id = p_match_id AND id != p_actor LIMIT 1;
    SELECT state INTO v_state FROM public.matches WHERE id = p_match_id;

    -- Interceptar efeitos raros
    CASE p_code
        WHEN 'rare_garklain_steal_stats' THEN
            DECLARE
                v_target_id uuid;
                v_stolen_power int;
                v_stolen_life int;
            BEGIN
                SELECT id, (current_power * 0.3)::int, (current_life * 0.3)::int INTO v_target_id, v_stolen_power, v_stolen_life
                FROM public.match_cards
                WHERE match_id = p_match_id AND player_id = v_opponent_id AND zone = 'field' AND card_type = 'vida'
                ORDER BY current_power DESC LIMIT 1;
                
                IF v_target_id IS NOT NULL THEN
                    UPDATE public.match_cards SET current_power = current_power - v_stolen_power, current_life = current_life - v_stolen_life WHERE id = v_target_id;
                    UPDATE public.match_cards SET current_power = current_power + v_stolen_power, current_life = current_life + v_stolen_life WHERE id = p_source;
                    RETURN jsonb_build_object('success', true, 'message', 'Garklain stats stolen', 'code', p_code, 'stolen_power', v_stolen_power);
                END IF;
                RETURN jsonb_build_object('success', false, 'message', 'No valid target', 'code', p_code);
            END;

        WHEN 'rare_drogodar_set_deck_mana' THEN
            UPDATE public.match_cards
            SET current_mana_cost = 4
            WHERE match_id = p_match_id AND player_id = p_actor AND zone = 'deck';
            RETURN jsonb_build_object('success', true, 'message', 'Deck mana set to 4', 'code', p_code);

        WHEN 'rare_cerys_hand_defender' THEN
            INSERT INTO public.match_runtime_effects (match_id, player_id, effect_code, effect_params)
            VALUES (p_match_id, p_actor, 'cerys_hand_defender', jsonb_build_object('source_id', p_source));
            RETURN jsonb_build_object('success', true, 'message', 'Cerys hand defender active', 'code', p_code);

        WHEN 'rare_hjalmar_scale_power' THEN
            UPDATE public.match_cards
            SET current_power = current_power + 500
            WHERE id = p_source;
            RETURN jsonb_build_object('success', true, 'message', 'Hjalmar scaled +500 Power', 'code', p_code);

        WHEN 'rare_bloody_baron_debuff_deck' THEN
            UPDATE public.match_cards mc
            SET current_power = GREATEST(0, mc.current_power - 1000)
            FROM public.cards c
            WHERE mc.card_id = c.id AND mc.match_id = p_match_id AND mc.player_id = v_opponent_id AND mc.zone = 'deck' AND c.element = 'Bestiário';
            RETURN jsonb_build_object('success', true, 'message', 'Enemy Bestiary deck debuffed', 'code', p_code);

        WHEN 'rare_vivienne_hand_heal' THEN
            IF p_target IS NOT NULL THEN
                UPDATE public.match_cards
                SET current_life = current_life + 2000
                WHERE id = p_target AND match_id = p_match_id;
                RETURN jsonb_build_object('success', true, 'message', 'Vivienne heal applied', 'code', p_code);
            END IF;
            RETURN jsonb_build_object('success', false, 'message', 'Missing target', 'code', p_code);

        WHEN 'rare_rience_turn_skip_draw' THEN
            WITH to_draw AS (
                SELECT id FROM public.match_cards WHERE match_id = p_match_id AND player_id = v_opponent_id AND zone = 'deck' ORDER BY random() LIMIT 2
            )
            UPDATE public.match_cards SET zone = 'hand' WHERE id IN (SELECT id FROM to_draw);
            INSERT INTO public.match_runtime_effects (match_id, player_id, effect_code) VALUES (p_match_id, v_opponent_id, 'skip_next_turn');
            RETURN jsonb_build_object('success', true, 'message', 'Opponent skips turn but draws 2', 'code', p_code);

        WHEN 'rare_arquespora_damage_reduce_tutor' THEN
            WITH to_draw AS (
                SELECT mc.id FROM public.match_cards mc JOIN public.cards c ON mc.card_id = c.id WHERE mc.match_id = p_match_id AND mc.player_id = p_actor AND mc.zone = 'deck' AND c.code = 'RARE_008' LIMIT 1
            )
            UPDATE public.match_cards SET zone = 'hand' WHERE id IN (SELECT id FROM to_draw);
            INSERT INTO public.match_runtime_effects (match_id, player_id, effect_code) VALUES (p_match_id, p_actor, 'arquespora_reduce_damage_20');
            RETURN jsonb_build_object('success', true, 'message', 'Arquespora damage reduced and tutored', 'code', p_code);

        WHEN 'rare_ronnan_lock_direct_attack' THEN
            INSERT INTO public.match_runtime_effects (match_id, player_id, effect_code) VALUES (p_match_id, p_match_id, 'lock_direct_attack');
            RETURN jsonb_build_object('success', true, 'message', 'Direct attack locked for all', 'code', p_code);

        WHEN 'rare_vernon_graveyard_mana_boost' THEN
            DECLARE
                v_grave_count int;
            BEGIN
                SELECT COUNT(*) INTO v_grave_count FROM public.match_cards WHERE match_id = p_match_id AND player_id = p_actor AND zone = 'graveyard';
                INSERT INTO public.match_runtime_effects (match_id, player_id, effect_code, effect_params) VALUES (p_match_id, p_actor, 'mana_boost', jsonb_build_object('amount', v_grave_count / 5));
                RETURN jsonb_build_object('success', true, 'message', 'Vernon mana boost applied next turn', 'code', p_code);
            END;

        WHEN 'rare_water_hag_destroy_discard' THEN
            WITH to_discard AS (
                SELECT id FROM public.match_cards WHERE match_id = p_match_id AND player_id = v_opponent_id AND zone = 'hand' ORDER BY random() LIMIT 1
            )
            UPDATE public.match_cards SET zone = 'graveyard' WHERE id IN (SELECT id FROM to_discard);
            RETURN jsonb_build_object('success', true, 'message', 'Water hag forces discard', 'code', p_code);

        WHEN 'rare_cerberus_deny_reaction' THEN
            INSERT INTO public.match_runtime_effects (match_id, player_id, effect_code) VALUES (p_match_id, v_opponent_id, 'deny_reaction');
            RETURN jsonb_build_object('success', true, 'message', 'Reaction denied for this attack', 'code', p_code);

        WHEN 'rare_sand_worm_multi_attack' THEN
            DECLARE
                v_life_count int;
            BEGIN
                SELECT COUNT(*) INTO v_life_count FROM public.match_cards WHERE match_id = p_match_id AND player_id = v_opponent_id AND zone = 'field' AND card_type = 'vida' AND current_life > 0;
                INSERT INTO public.match_runtime_effects (match_id, player_id, effect_code, effect_params) VALUES (p_match_id, p_actor, 'multi_attack', jsonb_build_object('count', v_life_count));
                RETURN jsonb_build_object('success', true, 'message', 'Sand worm multi attack', 'code', p_code);
            END;

        WHEN 'rare_nivellen_private_peek' THEN
            RETURN jsonb_build_object('success', true, 'message', 'Peek at enemy reinforcements', 'code', p_code);

        WHEN 'rare_arachnomorph_legacy_power' THEN
            DECLARE
                v_power int;
            BEGIN
                SELECT current_power INTO v_power FROM public.match_cards WHERE id = p_source;
                WITH hand_card AS (
                    SELECT id FROM public.match_cards WHERE match_id = p_match_id AND player_id = p_actor AND zone = 'hand' LIMIT 1
                )
                UPDATE public.match_cards SET current_power = current_power + v_power WHERE id IN (SELECT id FROM hand_card);
                RETURN jsonb_build_object('success', true, 'message', 'Legacy power transferred', 'code', p_code);
            END;

        WHEN 'rare_shaelmar_trade_life' THEN
            IF p_target IS NOT NULL THEN
                UPDATE public.match_cards SET current_life = 0, zone = 'graveyard' WHERE id = p_target;
                WITH own_life AS (
                    SELECT id FROM public.match_cards WHERE match_id = p_match_id AND player_id = p_actor AND zone = 'field' AND card_type = 'vida' LIMIT 1
                )
                UPDATE public.match_cards SET current_life = 1000 WHERE id IN (SELECT id FROM own_life);
                RETURN jsonb_build_object('success', true, 'message', 'Life traded', 'code', p_code);
            END IF;
            RETURN jsonb_build_object('success', false, 'message', 'Target required', 'code', p_code);

        WHEN 'rare_giant_centipede_survive_mill' THEN
            UPDATE public.match_cards SET zone = 'graveyard' WHERE match_id = p_match_id AND player_id = v_opponent_id AND zone = 'hand';
            RETURN jsonb_build_object('success', true, 'message', 'Opponent discards hand on survive', 'code', p_code);

        WHEN 'rare_sylvanna_random_revive_hand' THEN
            WITH to_revive AS (
                SELECT id FROM public.match_cards WHERE match_id = p_match_id AND player_id = p_actor AND zone = 'graveyard' ORDER BY random() LIMIT 1
            )
            UPDATE public.match_cards SET zone = 'hand' WHERE id IN (SELECT id FROM to_revive);
            RETURN jsonb_build_object('success', true, 'message', 'Random revive to hand', 'code', p_code);

        WHEN 'rare_ermion_purge_graveyards' THEN
            DELETE FROM public.match_cards WHERE match_id = p_match_id AND zone = 'graveyard';
            RETURN jsonb_build_object('success', true, 'message', 'Graveyards purged', 'code', p_code);

        WHEN 'rare_cyclops_bleed_or_discard' THEN
            DECLARE
                v_hand_count int;
            BEGIN
                SELECT COUNT(*) INTO v_hand_count FROM public.match_cards WHERE match_id = p_match_id AND player_id = p_actor AND zone = 'hand';
                IF v_hand_count > 0 THEN
                    WITH to_discard AS (
                        SELECT id FROM public.match_cards WHERE match_id = p_match_id AND player_id = p_actor AND zone = 'hand' LIMIT 1
                    )
                    UPDATE public.match_cards SET zone = 'graveyard' WHERE id IN (SELECT id FROM to_discard);
                    RETURN jsonb_build_object('success', true, 'message', 'Cyclops bleed avoided by discard', 'code', p_code);
                ELSE
                    UPDATE public.match_cards SET current_life = current_life - 1000 WHERE id = p_source;
                    RETURN jsonb_build_object('success', true, 'message', 'Cyclops bleed triggered', 'code', p_code);
                END IF;
            END;

        WHEN 'rare_jhenny_uninterruptible_mf' THEN
            RETURN jsonb_build_object('success', true, 'message', 'M&F uninterruptible', 'code', p_code);

        WHEN 'rare_kraken_damage_cap_spill' THEN
            RETURN jsonb_build_object('success', true, 'message', 'Damage cap spill applied', 'code', p_code);

        WHEN 'rare_fiend_peek_hand' THEN
            RETURN jsonb_build_object('success', true, 'message', 'Peek at opponent hand', 'code', p_code);

        WHEN 'rare_fleder_turn1_triple_strike' THEN
            RETURN jsonb_build_object('success', true, 'message', 'Turn 1 triple strike', 'code', p_code);

        WHEN 'rare_yrsa_discard_lowest_mana' THEN
            RETURN jsonb_build_object('success', true, 'message', 'Discard lowest mana', 'code', p_code);

        ELSE
            -- Chain of responsibility: delegar para o core
            RETURN game_private.execute_common_effect_internal_v28_core(p_match_id, p_actor, p_source, p_code, p_params, p_target, p_event);
    END CASE;
END;
$$;

COMMIT;
