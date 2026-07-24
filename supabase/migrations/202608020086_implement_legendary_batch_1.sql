-- Migration 202608020086_implement_legendary_batch_1.sql
-- Implementação da lógica das cartas Legendary Batch 1 (001-020)

BEGIN;

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_proc WHERE proname = 'execute_common_effect_internal_v34_core') THEN
        ALTER FUNCTION game_private.execute_common_effect_internal(uuid, uuid, uuid, text, jsonb, uuid, jsonb)
        RENAME TO execute_common_effect_internal_v34_core;
    END IF;
END $$;

CREATE OR REPLACE FUNCTION game_private.execute_common_effect_internal(
    p_match_id uuid,
    p_actor uuid,
    p_source uuid,
    p_code text,
    p_params jsonb,
    p_target uuid DEFAULT NULL,
    p_event jsonb DEFAULT NULL
) RETURNS void LANGUAGE plpgsql AS $$
DECLARE
    v_player_id uuid;
    v_opponent_id uuid;
    v_actor_record record;
    v_target_record record;
    v_count integer;
    v_record record;
    v_half integer;
    v_life integer;
    v_target_id uuid;
BEGIN
    SELECT * INTO v_actor_record FROM game_private.match_cards WHERE id = p_actor;
    v_player_id := v_actor_record.owner_id;
    
    SELECT p1_id, p2_id INTO v_record FROM public.matches WHERE id = p_match_id;
    IF v_record.p1_id = v_player_id THEN
        v_opponent_id := v_record.p2_id;
    ELSE
        v_opponent_id := v_record.p1_id;
    END IF;

    IF p_code = 'leg_dettlaff_multi_direct_strike' THEN
        SELECT count(*) INTO v_count FROM game_private.match_cards WHERE match_id = p_match_id AND owner_id = v_player_id AND zone = 'life' AND current_life > 0;
        FOR v_target_record IN SELECT * FROM game_private.match_cards WHERE match_id = p_match_id AND owner_id = v_opponent_id AND zone = 'life' AND current_life > 0 LIMIT v_count LOOP
            UPDATE game_private.match_cards SET current_life = GREATEST(0, current_life - v_actor_record.base_power) WHERE id = v_target_record.id;
        END LOOP;
        
    ELSIF p_code = 'leg_geels_double_surgical_swap' THEN
        IF p_params ? 'target_life_id' AND p_params ? 'deck_card_id_for_life' THEN
            UPDATE game_private.match_cards SET zone = 'deck' WHERE id = (p_params->>'target_life_id')::uuid;
            UPDATE game_private.match_cards SET zone = 'life', current_life = base_max_life WHERE id = (p_params->>'deck_card_id_for_life')::uuid;
        END IF;
        IF p_params ? 'target_hand_id' AND p_params ? 'deck_card_id_for_hand' THEN
            UPDATE game_private.match_cards SET zone = 'deck' WHERE id = (p_params->>'target_hand_id')::uuid;
            UPDATE game_private.match_cards SET zone = 'hand' WHERE id = (p_params->>'deck_card_id_for_hand')::uuid;
        END IF;

    ELSIF p_code = 'leg_filavandrel_elf_hijack_to_deck' THEN
        UPDATE public.match_players SET modifiers = coalesce(modifiers, '{}'::jsonb) || '{"leg_filavandrel_elf_hijack": true}' WHERE match_id = p_match_id AND player_id = v_player_id;

    ELSIF p_code = 'leg_auberon_double_enemy_elf_mana' THEN
        UPDATE game_private.match_cards
        SET modifiers = coalesce(modifiers, '{}'::jsonb) || '{"mana_cost_multiplier": 2}'
        WHERE match_id = p_match_id AND owner_id = v_opponent_id AND zone = 'deck'
          AND card_id IN (SELECT id FROM public.cards WHERE element = 'Elfica');

    ELSIF p_code = 'leg_eredin_solo_attack_bleed_tax' THEN
        UPDATE game_private.match_cards
        SET current_life = GREATEST(0, current_life - 1000),
            modifiers = coalesce(modifiers, '{}'::jsonb) || jsonb_build_object('mana_cost_add', coalesce((modifiers->>'mana_cost_add')::int, 0) + 1)
        WHERE match_id = p_match_id AND owner_id = v_opponent_id AND zone = 'life' AND current_life > 0;

    ELSIF p_code = 'leg_verdum_legendary_generator_loop' THEN
        UPDATE public.match_players SET modifiers = coalesce(modifiers, '{}'::jsonb) || '{"leg_verdum_generator": true}' WHERE match_id = p_match_id AND player_id = v_player_id;

    ELSIF p_code = 'leg_erland_slay_mana_ramp' THEN
        UPDATE public.match_players
        SET modifiers = coalesce(modifiers, '{}'::jsonb) || jsonb_build_object('next_turn_mana_bonus', coalesce((modifiers->>'next_turn_mana_bonus')::int, 0) + coalesce((p_event->>'destroyed_count')::int, 1))
        WHERE match_id = p_match_id AND player_id = v_player_id;

    ELSIF p_code = 'leg_arnaghad_clone_reinforcements' THEN
        UPDATE game_private.match_cards
        SET card_id = v_actor_record.card_id,
            base_power = v_actor_record.base_power,
            base_max_life = v_actor_record.base_max_life,
            current_life = v_actor_record.base_max_life
        WHERE match_id = p_match_id AND owner_id = v_player_id AND zone = 'reinforcement' AND id != p_actor;

    ELSIF p_code = 'leg_gezras_hijack_enemy_deck_card' THEN
        IF p_params ? 'target_deck_card_id' THEN
            UPDATE game_private.match_cards SET owner_id = v_player_id, zone = 'hand' WHERE id = (p_params->>'target_deck_card_id')::uuid;
        END IF;

    ELSIF p_code = 'leg_cosimo_reduce_enemy_witchers_to_one' THEN
        UPDATE game_private.match_cards
        SET current_life = 1
        WHERE match_id = p_match_id AND owner_id = v_opponent_id AND zone IN ('life', 'reinforcement') AND current_life > 0
          AND card_id IN (SELECT id FROM public.cards WHERE element = 'Witcher');

    ELSIF p_code = 'leg_alzur_global_field_bounce_reset' THEN
        UPDATE game_private.match_cards
        SET zone = 'hand'
        WHERE match_id = p_match_id AND zone IN ('life', 'reinforcement');

    ELSIF p_code = 'leg_tissaia_tutor_discount_yennefers' THEN
        UPDATE game_private.match_cards
        SET zone = 'hand',
            modifiers = coalesce(modifiers, '{}'::jsonb) || '{"mana_cost_multiplier": 0.5}'
        WHERE match_id = p_match_id AND owner_id = v_player_id AND zone = 'deck'
          AND card_id IN (SELECT id FROM public.cards WHERE code = 'LEGENDARY_025');

    ELSIF p_code = 'leg_carla_mill_ten_enemy_beasts' THEN
        FOR v_target_record IN SELECT * FROM game_private.match_cards WHERE match_id = p_match_id AND owner_id = v_opponent_id AND zone = 'deck' AND card_id IN (SELECT id FROM public.cards WHERE element = 'Bestiario') LIMIT 10 LOOP
            UPDATE game_private.match_cards SET zone = 'graveyard' WHERE id = v_target_record.id;
        END LOOP;

    ELSIF p_code = 'leg_tetra_execute_weaker_lives' THEN
        v_life := coalesce(v_actor_record.current_life, 0);
        UPDATE game_private.match_cards
        SET current_life = 0, zone = 'graveyard'
        WHERE match_id = p_match_id AND zone = 'life' AND current_life > 0 AND current_life < v_life;

    ELSIF p_code = 'leg_kitsu_transmute_half_enemy_deck' THEN
        SELECT count(*) / 2 INTO v_half FROM game_private.match_cards WHERE match_id = p_match_id AND owner_id = v_opponent_id AND zone = 'deck';
        FOR v_target_record IN SELECT * FROM game_private.match_cards WHERE match_id = p_match_id AND owner_id = v_opponent_id AND zone = 'deck' ORDER BY random() LIMIT v_half LOOP
            UPDATE game_private.match_cards
            SET card_id = (SELECT id FROM public.cards WHERE rarity = 'rare' ORDER BY random() LIMIT 1)
            WHERE id = v_target_record.id;
        END LOOP;

    ELSIF p_code = 'leg_lady_of_lake_deck_protection' THEN
        UPDATE public.match_players SET modifiers = coalesce(modifiers, '{}'::jsonb) || '{"leg_lady_deck_protection": true}' WHERE match_id = p_match_id AND player_id = v_player_id;

    ELSIF p_code = 'leg_dandelion_forced_hand_trade' THEN
        IF p_params ? 'swap_pairs' THEN
            FOR v_record IN SELECT * FROM jsonb_array_elements(p_params->'swap_pairs') LOOP
                UPDATE game_private.match_cards SET owner_id = v_opponent_id WHERE id = (v_record.value->>0)::uuid;
                UPDATE game_private.match_cards SET owner_id = v_player_id WHERE id = (v_record.value->>1)::uuid;
            END LOOP;
        END IF;

    ELSIF p_code = 'leg_caretaker_endturn_direct_snipe' THEN
        UPDATE game_private.match_cards SET modifiers = coalesce(modifiers, '{}'::jsonb) || '{"leg_caretaker_snipe": true}' WHERE id = p_actor;

    ELSIF p_code = 'leg_von_everec_solo_bounce_discount' THEN
        UPDATE game_private.match_cards SET zone = 'hand' WHERE id = p_actor;
        UPDATE game_private.match_cards SET modifiers = coalesce(modifiers, '{}'::jsonb) || jsonb_build_object('mana_cost_add', coalesce((modifiers->>'mana_cost_add')::int, 0) - 1)
        WHERE match_id = p_match_id AND owner_id = v_player_id AND zone = 'hand' AND id != p_actor;

    ELSIF p_code = 'leg_regis_vampire_mass_tutor_revive' THEN
        IF coalesce(v_actor_record.current_life, 0) > 0 THEN
            UPDATE game_private.match_cards
            SET zone = 'hand'
            WHERE match_id = p_match_id AND owner_id = v_player_id AND zone IN ('deck', 'graveyard')
              AND card_id IN (SELECT id FROM public.cards WHERE element = 'Vampiro');
        END IF;

    ELSE
        PERFORM game_private.execute_common_effect_internal_v34_core(p_match_id, p_actor, p_source, p_code, p_params, p_target, p_event);
    END IF;
END;
$$;

COMMIT;
