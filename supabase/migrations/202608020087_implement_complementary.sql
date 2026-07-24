BEGIN;

ALTER FUNCTION game_private.execute_common_effect_internal(uuid, uuid, uuid, text, jsonb, uuid, jsonb) 
RENAME TO execute_common_effect_internal_v35_core;

CREATE OR REPLACE FUNCTION game_private.execute_common_effect_internal(
    p_match_id uuid,
    p_actor uuid,
    p_source uuid,
    p_code text,
    p_params jsonb,
    p_target uuid DEFAULT NULL,
    p_event jsonb DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    v_source_state jsonb;
    v_source_card jsonb;
    v_target_state jsonb;
    v_target_card jsonb;
    v_actor_state jsonb;
    v_opponent_id uuid;
    v_opponent_state jsonb;
    v_result jsonb := '{"actions":[]}';
    v_action jsonb;
    v_elem jsonb;
    v_val int;
    v_val2 int;
    v_temp_id uuid;
    v_has_selenne boolean;
    v_discard_ids uuid[];
    v_discarded_count int;
    v_dmg int;
    v_roll numeric;
    v_robbed_card jsonb;
    v_adjacent_id uuid;
BEGIN
    SELECT state INTO v_actor_state FROM game_players WHERE match_id = p_match_id AND user_id = p_actor;
    SELECT user_id, state INTO v_opponent_id, v_opponent_state FROM game_players WHERE match_id = p_match_id AND user_id != p_actor LIMIT 1;
    
    v_source_card := game_private.get_card_from_player_state(v_actor_state, p_source);
    IF v_source_card IS NULL THEN
        v_source_card := game_private.get_card_from_player_state(v_opponent_state, p_source);
        IF v_source_card IS NOT NULL THEN
            v_source_state := v_opponent_state;
        END IF;
    ELSE
        v_source_state := v_actor_state;
    END IF;

    IF p_target IS NOT NULL THEN
        v_target_card := game_private.get_card_from_player_state(v_actor_state, p_target);
        IF v_target_card IS NOT NULL THEN
            v_target_state := v_actor_state;
        ELSE
            v_target_card := game_private.get_card_from_player_state(v_opponent_state, p_target);
            IF v_target_card IS NOT NULL THEN
                v_target_state := v_opponent_state;
            END IF;
        END IF;
    END IF;

    CASE p_code
        WHEN 'comp_adrian_common_revive_hand' THEN
            IF p_target IS NOT NULL THEN
                IF v_target_card->>'zone' = 'graveyard' AND (v_target_card->'card_data'->>'rarity') = 'common' AND v_target_state->>'user_id' = v_actor_state->>'user_id' THEN
                    v_action := jsonb_build_object(
                        'type', 'move_card',
                        'card_id', p_target,
                        'source_zone', 'graveyard',
                        'target_zone', 'hand',
                        'player_id', p_actor
                    );
                    v_result := jsonb_set(v_result, '{actions}', (v_result->'actions') || v_action);
                END IF;
            END IF;
            RETURN v_result;

        WHEN 'comp_altair_selenne_direct_snipe' THEN
            v_has_selenne := false;
            FOR v_elem IN SELECT * FROM jsonb_array_elements(v_actor_state->'hand') LOOP
                IF v_elem->'card_data'->>'code' = 'EXTRA_RARE_02' THEN
                    v_has_selenne := true;
                    EXIT;
                END IF;
            END LOOP;
            
            IF v_has_selenne AND p_target IS NOT NULL THEN
                IF v_target_card->>'zone' = 'life_area' AND v_target_state->>'user_id' = v_opponent_id THEN
                    v_dmg := COALESCE((v_source_card->>'current_power')::int, 1800);
                    v_action := jsonb_build_object(
                        'type', 'damage',
                        'target_id', p_target,
                        'amount', v_dmg,
                        'source_id', p_source,
                        'ignore_reinforcements', true
                    );
                    v_result := jsonb_set(v_result, '{actions}', (v_result->'actions') || v_action);
                END IF;
            END IF;
            RETURN v_result;

        WHEN 'comp_selenne_discard_scaling_buff' THEN
            IF p_event ? 'discard_ids' THEN
                v_discard_ids := ARRAY(SELECT jsonb_array_elements_text(p_event->'discard_ids')::uuid);
            ELSIF p_params ? 'discard_ids' THEN
                v_discard_ids := ARRAY(SELECT jsonb_array_elements_text(p_params->'discard_ids')::uuid);
            END IF;
            
            IF array_length(v_discard_ids, 1) > 0 THEN
                FOR i IN 1..array_length(v_discard_ids, 1) LOOP
                    v_action := jsonb_build_object(
                        'type', 'move_card',
                        'card_id', v_discard_ids[i],
                        'source_zone', 'hand',
                        'target_zone', 'graveyard',
                        'player_id', p_actor
                    );
                    v_result := jsonb_set(v_result, '{actions}', (v_result->'actions') || v_action);
                END LOOP;
                v_discarded_count := array_length(v_discard_ids, 1);
                v_action := jsonb_build_object(
                    'type', 'modify_stats',
                    'target_id', p_source,
                    'power_change', 2000 * v_discarded_count,
                    'life_change', 2000 * v_discarded_count,
                    'is_permanent', true
                );
                v_result := jsonb_set(v_result, '{actions}', (v_result->'actions') || v_action);
            END IF;
            RETURN v_result;

        WHEN 'comp_arella_stat_inversion' THEN
            IF p_target IS NOT NULL AND v_target_state->>'user_id' = v_actor_state->>'user_id' THEN
                IF v_target_card->>'zone' IN ('hand', 'life_area', 'reinforcement_area') THEN
                    v_action := jsonb_build_object(
                        'type', 'invert_stats',
                        'target_id', p_target,
                        'is_permanent', true
                    );
                    v_result := jsonb_set(v_result, '{actions}', (v_result->'actions') || v_action);
                END IF;
            END IF;
            RETURN v_result;

        WHEN 'comp_alpor_lifesteal_tenth' THEN
            v_action := jsonb_build_object(
                'type', 'add_aura',
                'target_id', p_source,
                'aura_type', 'lifesteal_tenth_to_random_life',
                'duration', 'end_of_turn'
            );
            v_result := jsonb_set(v_result, '{actions}', (v_result->'actions') || v_action);
            RETURN v_result;

        WHEN 'comp_protofleders_coinflip_snipe' THEN
            v_roll := random();
            IF v_roll <= 0.5 THEN
                v_temp_id := NULL;
                FOR v_elem IN SELECT * FROM jsonb_array_elements(v_opponent_state->'life_area') LOOP
                    IF v_temp_id IS NULL OR random() < 0.5 THEN
                        v_temp_id := (v_elem->>'id')::uuid;
                    END IF;
                END LOOP;
                IF v_temp_id IS NOT NULL THEN
                    v_dmg := COALESCE((v_source_card->>'current_power')::int, 2900);
                    v_action := jsonb_build_object(
                        'type', 'damage',
                        'target_id', v_temp_id,
                        'amount', v_dmg,
                        'source_id', p_source,
                        'ignore_reinforcements', true
                    );
                    v_result := jsonb_set(v_result, '{actions}', (v_result->'actions') || v_action);
                END IF;
            END IF;
            RETURN v_result;

        WHEN 'comp_lamia_graveyard_return_loop' THEN
            IF v_source_card->>'zone' = 'graveyard' THEN
                v_val := jsonb_array_length(v_actor_state->'hand');
                v_val2 := COALESCE((v_actor_state->>'max_hand_size')::int, 10);
                IF v_val < v_val2 THEN
                    v_action := jsonb_build_object(
                        'type', 'move_card',
                        'card_id', p_source,
                        'source_zone', 'graveyard',
                        'target_zone', 'hand',
                        'player_id', p_actor
                    );
                    v_result := jsonb_set(v_result, '{actions}', (v_result->'actions') || v_action);
                END IF;
            END IF;
            RETURN v_result;

        WHEN 'comp_darion_hand_robbery' THEN
            v_val := jsonb_array_length(v_opponent_state->'hand');
            IF v_val > 0 THEN
                v_val2 := floor(random() * v_val)::int;
                v_robbed_card := (v_opponent_state->'hand')->v_val2;
                v_action := jsonb_build_object(
                    'type', 'move_card',
                    'card_id', (v_robbed_card->>'id')::uuid,
                    'source_zone', 'hand',
                    'target_zone', 'hand',
                    'player_id', p_actor,
                    'from_player_id', v_opponent_id
                );
                v_result := jsonb_set(v_result, '{actions}', (v_result->'actions') || v_action);
            END IF;
            RETURN v_result;

        WHEN 'comp_dismas_death_heal_adjacent_life' THEN
            IF v_source_card->>'zone' = 'reinforcement_area' THEN
                v_adjacent_id := (v_source_card->>'attached_to_life_card')::uuid;
                IF v_adjacent_id IS NULL THEN
                    FOR v_elem IN SELECT * FROM jsonb_array_elements(v_actor_state->'life_area') LOOP
                        v_adjacent_id := (v_elem->>'id')::uuid;
                        EXIT;
                    END LOOP;
                END IF;
                IF v_adjacent_id IS NOT NULL THEN
                    v_action := jsonb_build_object(
                        'type', 'heal',
                        'target_id', v_adjacent_id,
                        'amount', 1000,
                        'source_id', p_source
                    );
                    v_result := jsonb_set(v_result, '{actions}', (v_result->'actions') || v_action);
                END IF;
            END IF;
            RETURN v_result;

        WHEN 'comp_razen_destroy_anti_direct_attackers' THEN
            FOR v_elem IN SELECT * FROM jsonb_array_elements(v_opponent_state->'reinforcement_area') LOOP
                IF (v_elem->'auras') @> '[{"aura_type": "taunt"}]' OR (v_elem->'auras') @> '[{"aura_type": "block_direct_attack"}]' OR (v_elem->'auras') @> '[{"aura_type": "block_attack"}]' THEN
                    v_temp_id := (v_elem->>'id')::uuid;
                    v_action := jsonb_build_object(
                        'type', 'destroy_card',
                        'target_id', v_temp_id
                    );
                    v_result := jsonb_set(v_result, '{actions}', (v_result->'actions') || v_action);
                END IF;
            END LOOP;
            RETURN v_result;

        WHEN 'comp_lyra_cap_highest_deck_mana' THEN
            v_temp_id := NULL;
            v_val := -1;
            FOR v_elem IN SELECT * FROM jsonb_array_elements(v_actor_state->'deck') LOOP
                v_val2 := (v_elem->'card_data'->>'effect_mana_cost')::int;
                IF v_val2 > v_val THEN
                    v_val := v_val2;
                    v_temp_id := (v_elem->>'id')::uuid;
                END IF;
            END LOOP;
            IF v_temp_id IS NOT NULL THEN
                v_action := jsonb_build_object(
                    'type', 'modify_cost',
                    'target_id', v_temp_id,
                    'new_cost', 5,
                    'duration', 'while_in_deck'
                );
                v_result := jsonb_set(v_result, '{actions}', (v_result->'actions') || v_action);
            END IF;
            RETURN v_result;

        ELSE
            RETURN game_private.execute_common_effect_internal_v35_core(p_match_id, p_actor, p_source, p_code, p_params, p_target, p_event);
    END CASE;
END;
$$;

COMMIT;
