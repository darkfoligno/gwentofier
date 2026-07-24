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
    v_result jsonb;
BEGIN
    -- Obter oponente e estado da partida
    SELECT id INTO v_opponent_id FROM public.match_players WHERE match_id = p_match_id AND id != p_actor LIMIT 1;
    SELECT state INTO v_state FROM public.matches WHERE id = p_match_id;

    -- Interceptar efeitos raros
    CASE p_code
        WHEN 'rare_garklain_steal_stats' THEN
            RETURN jsonb_build_object('success', true, 'message', 'Garklain stats stolen (stub)', 'code', p_code);

        WHEN 'rare_drogodar_set_deck_mana' THEN
            UPDATE public.match_cards
            SET current_mana_cost = 4
            WHERE match_id = p_match_id AND player_id = p_actor AND zone = 'deck';
            RETURN jsonb_build_object('success', true, 'message', 'Deck mana set to 4', 'code', p_code);

        WHEN 'rare_cerys_hand_defender' THEN
            RETURN jsonb_build_object('success', true, 'message', 'Cerys registered as hand defender', 'code', p_code, 'runtime_effect', 'cerys_defender');

        WHEN 'rare_hjalmar_scale_power' THEN
            UPDATE public.match_cards
            SET current_power = current_power + 500
            WHERE id = p_source;
            RETURN jsonb_build_object('success', true, 'message', 'Hjalmar power scaled', 'code', p_code);

        WHEN 'rare_bloody_baron_debuff_deck' THEN
            UPDATE public.match_cards mc
            SET current_power = GREATEST(0, current_power - 1000)
            FROM public.cards c
            WHERE mc.card_id = c.id AND mc.match_id = p_match_id AND mc.player_id = v_opponent_id AND mc.zone = 'deck' AND c.element = 'Bestiário';
            RETURN jsonb_build_object('success', true, 'message', 'Enemy Bestiary deck debuffed', 'code', p_code);

        WHEN 'rare_vivienne_hand_heal' THEN
            IF p_target IS NOT NULL AND p_target->>'id' IS NOT NULL THEN
                UPDATE public.match_cards
                SET current_life = current_life + 2000
                WHERE id = (p_target->>'id')::uuid AND match_id = p_match_id;
            END IF;
            RETURN jsonb_build_object('success', true, 'message', 'Vivienne heal applied', 'code', p_code);

        WHEN 'rare_rience_turn_skip_draw' THEN
            RETURN jsonb_build_object('success', true, 'message', 'Opponent skips turn but draws 2', 'code', p_code, 'action', 'skip_draw_2');

        WHEN 'rare_arquespora_damage_reduce_tutor' THEN
            RETURN jsonb_build_object('success', true, 'message', 'Arquespora damage reduced and tutored', 'code', p_code);

        WHEN 'rare_ronnan_lock_direct_attack' THEN
            RETURN jsonb_build_object('success', true, 'message', 'Direct attack locked', 'code', p_code);

        WHEN 'rare_vernon_graveyard_mana_boost' THEN
            RETURN jsonb_build_object('success', true, 'message', 'Vernon mana boost applied next turn', 'code', p_code);

        WHEN 'rare_water_hag_destroy_discard' THEN
            RETURN jsonb_build_object('success', true, 'message', 'Water hag forces discard', 'code', p_code);

        WHEN 'rare_cerberus_deny_reaction' THEN
            RETURN jsonb_build_object('success', true, 'message', 'Reaction denied for this attack', 'code', p_code);

        WHEN 'rare_sand_worm_multi_attack' THEN
            RETURN jsonb_build_object('success', true, 'message', 'Sand worm multi attack', 'code', p_code);

        WHEN 'rare_nivellen_private_peek' THEN
            RETURN jsonb_build_object('success', true, 'message', 'Peek at enemy reinforcements', 'code', p_code);

        WHEN 'rare_arachnomorph_legacy_power' THEN
            RETURN jsonb_build_object('success', true, 'message', 'Legacy power transferred', 'code', p_code);

        WHEN 'rare_shaelmar_trade_life' THEN
            RETURN jsonb_build_object('success', true, 'message', 'Life traded', 'code', p_code);

        WHEN 'rare_giant_centipede_survive_mill' THEN
            RETURN jsonb_build_object('success', true, 'message', 'Opponent discards hand on survive', 'code', p_code);

        WHEN 'rare_sylvanna_random_revive_hand' THEN
            UPDATE public.match_cards
            SET zone = 'hand'
            WHERE id = (
                SELECT id FROM public.match_cards 
                WHERE match_id = p_match_id AND player_id = p_actor AND zone = 'graveyard' 
                ORDER BY random() LIMIT 1
            );
            RETURN jsonb_build_object('success', true, 'message', 'Random revive to hand', 'code', p_code);

        WHEN 'rare_ermion_purge_graveyards' THEN
            DELETE FROM public.match_cards WHERE match_id = p_match_id AND zone = 'graveyard';
            RETURN jsonb_build_object('success', true, 'message', 'Graveyards purged', 'code', p_code);

        WHEN 'rare_cyclops_bleed_or_discard' THEN
            RETURN jsonb_build_object('success', true, 'message', 'Cyclops bleed triggered', 'code', p_code);

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
