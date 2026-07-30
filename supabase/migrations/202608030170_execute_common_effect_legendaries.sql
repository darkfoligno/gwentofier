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
 SET search_path TO ''
AS $function$
DECLARE
    v_source_card_rec public.match_cards;
    v_target_card_rec public.match_cards;
    v_opponent_id uuid;
    v_result jsonb := '{"actions":[]}';
    v_action jsonb;
    v_temp_id uuid;
    v_has_selenne boolean;
    v_discard_ids uuid[];
    v_discarded_count int;
    v_dmg int;
    v_roll numeric;
    v_val int;
    v_adjacent_id uuid;
    v_target_rarity text;
BEGIN
    -- Query match_cards and match_players directly instead of game_players view
    SELECT * INTO v_source_card_rec FROM public.match_cards WHERE id = p_source AND match_id = p_match_id;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Effect source card not found';
    END IF;

    SELECT user_id INTO v_opponent_id FROM public.match_players WHERE match_id = p_match_id AND user_id != p_actor LIMIT 1;
    
    IF p_target IS NOT NULL THEN
        SELECT * INTO v_target_card_rec FROM public.match_cards WHERE id = p_target AND match_id = p_match_id;
        IF FOUND THEN
            SELECT rarity INTO v_target_rarity FROM public.match_deck_cards WHERE id = v_target_card_rec.match_deck_card_id;
        END IF;
    END IF;

    CASE p_code
        WHEN 'leg_arma_x_mass_attack' THEN
            DECLARE
                v_target_life_id uuid := p_target;
                v_mana_avail integer;
            BEGIN
                IF v_target_life_id IS NOT NULL THEN
                    IF NOT EXISTS (
                        SELECT 1 FROM public.match_cards 
                        WHERE id = v_target_life_id AND match_id = p_match_id AND owner_user_id = v_opponent_id AND zone = 'life' AND current_life > 0
                    ) THEN
                        v_target_life_id := NULL;
                    END IF;
                END IF;

                IF v_target_life_id IS NOT NULL THEN
                    SELECT mana_available INTO v_mana_avail FROM public.match_players WHERE match_id = p_match_id AND user_id = p_actor;
                    IF v_mana_avail < 1 THEN
                        RAISE EXCEPTION 'Mana disponível insuficiente para pular para outra defesa (precisa de 1).';
                    END IF;

                    UPDATE public.match_players 
                    SET mana_available = mana_available - 1,
                        mana_spent_this_turn = mana_spent_this_turn + 1
                    WHERE match_id = p_match_id AND user_id = p_actor;
                ELSE
                    SELECT id INTO v_target_life_id FROM public.match_cards
                    WHERE match_id = p_match_id AND owner_user_id = v_opponent_id AND zone = 'life' AND current_life > 0
                    ORDER BY zone_position ASC LIMIT 1;
                END IF;

                IF v_target_life_id IS NOT NULL THEN
                    UPDATE public.match_cards 
                    SET current_life = GREATEST(0, current_life - v_source_card_rec.current_power),
                        zone = CASE WHEN current_life <= v_source_card_rec.current_power THEN 'graveyard' ELSE zone END
                    WHERE id = v_target_life_id;
                END IF;

                UPDATE public.match_cards 
                SET current_life = GREATEST(0, current_life - v_source_card_rec.current_power),
                    zone = CASE WHEN current_life <= v_source_card_rec.current_power THEN 'graveyard' ELSE zone END
                WHERE match_id = p_match_id AND owner_user_id = v_opponent_id AND zone = 'reinforcement' AND current_life > 0;

                UPDATE public.match_cards 
                SET zone = 'graveyard'
                WHERE match_id = p_match_id AND owner_user_id = v_opponent_id AND zone = 'hand';

                RETURN jsonb_build_object('success', true, 'message', 'Arma X mass attack executed.', 'code', p_code);
            END;

        WHEN 'leg_pavetta_deck_buff' THEN
            UPDATE public.match_cards 
            SET current_power = current_power + 2000,
                base_power = base_power + 2000,
                maximum_power = maximum_power + 2000
            WHERE match_id = p_match_id AND owner_user_id = p_actor AND zone = 'deck';

            UPDATE public.match_deck_cards 
            SET effect_mana_cost = 0
            WHERE id IN (
                SELECT match_deck_card_id FROM public.match_cards
                WHERE match_id = p_match_id AND owner_user_id = p_actor AND zone = 'deck' AND source_card_id = '9088670c-9eb9-4bb7-96fc-9edfdb01fae6'::uuid
            );

            UPDATE public.match_cards
            SET modifiers = coalesce(modifiers, '{}'::jsonb) || '{"mana_cost_multiplier": 0}'
            WHERE match_id = p_match_id AND owner_user_id = p_actor AND zone = 'deck' AND source_card_id = '9088670c-9eb9-4bb7-96fc-9edfdb01fae6'::uuid;

            RETURN jsonb_build_object('success', true, 'message', 'Rainha Pavetta deck buff executed.', 'code', p_code);

        WHEN 'comp_adrian_common_revive_hand' THEN
            IF v_target_card_rec.zone = 'graveyard' AND v_target_rarity = 'common' AND v_target_card_rec.owner_user_id = p_actor THEN
                v_action := jsonb_build_object(
                    'type', 'move_card',
                    'card_id', p_target,
                    'source_zone', 'graveyard',
                    'target_zone', 'hand',
                    'player_id', p_actor
                );
                v_result := jsonb_set(v_result, '{actions}', (v_result->'actions') || v_action);
            END IF;
            RETURN v_result;

        WHEN 'comp_altair_selenne_direct_snipe' THEN
            SELECT EXISTS(
                SELECT 1 FROM public.match_cards mc
                JOIN public.cards c ON c.id = mc.source_card_id
                WHERE mc.match_id = p_match_id AND mc.owner_user_id = p_actor AND mc.zone = 'hand' AND c.code = 'EXTRA_RARE_02'
            ) INTO v_has_selenne;
            
            IF v_has_selenne AND p_target IS NOT NULL THEN
                IF v_target_card_rec.zone = 'life' AND v_target_card_rec.owner_user_id = v_opponent_id THEN
                    v_dmg := COALESCE(v_source_card_rec.current_power, 1800);
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
            IF p_target IS NOT NULL AND v_target_card_rec.owner_user_id = p_actor THEN
                IF v_target_card_rec.zone IN ('hand', 'life', 'reinforcement') THEN
                    v_action := jsonb_build_object(
                        'type', 'invert_stats',
                        'target_id', p_target,
                        'is_permanent', true
                    );
                    v_result := jsonb_set(v_result, '{actions}', (v_result->'actions') || v_action);
                END IF;
            END IF;
            RETURN v_result;

        WHEN 'common_panther_direct_life' THEN
            IF v_source_card_rec.zone <> 'attacker' THEN 
                RAISE EXCEPTION 'DIRECT_EFFECT_REQUIRES_ATTACK_FIELD'; 
            END IF;
            
            IF (SELECT count(*) FROM public.match_cards WHERE match_id = p_match_id AND owner_user_id = p_actor AND zone = 'hand') <=
               (SELECT count(*) FROM public.match_cards WHERE match_id = p_match_id AND owner_user_id = v_opponent_id AND zone = 'hand') THEN 
                RAISE EXCEPTION 'PANTHER_REQUIRES_HAND_ADVANTAGE'; 
            END IF;
            
            INSERT INTO public.match_runtime_effects(
                match_id, owner_user_id, source_match_card_id, target_match_card_id, effect_code, scope, payload, starts_on_turn, expires_on_turn, active
            )
            VALUES (
                p_match_id, p_actor, p_source, p_target, p_code, 'card', jsonb_build_object('prepared', true), 
                (SELECT current_turn FROM public.matches WHERE id = p_match_id), 
                (SELECT current_turn FROM public.matches WHERE id = p_match_id), 
                true
            ) RETURNING id INTO v_temp_id;
            RETURN jsonb_build_object('direct_attack_prepared', true, 'runtime_effect_id', v_temp_id);

        WHEN 'comp_alpor_lifesteal_tenth' THEN
            INSERT INTO public.match_runtime_effects(
                match_id, owner_user_id, source_match_card_id, effect_code, scope, payload, starts_on_turn, expires_on_turn, active
            )
            VALUES (
                p_match_id, p_actor, p_source, p_code, 'card', jsonb_build_object('prepared', true), 
                (SELECT current_turn FROM public.matches WHERE id = p_match_id), 
                (SELECT current_turn FROM public.matches WHERE id = p_match_id), 
                true
            );
            
            v_action := jsonb_build_object(
                'type', 'add_aura',
                'target_id', p_source,
                'aura_type', 'lifesteal_tenth_to_random_life',
                'duration', 'end_of_turn'
            );
            v_result := jsonb_set(v_result, '{actions}', (v_result->'actions') || v_action);
            RETURN v_result;

        WHEN 'rare_bloody_baron_debuff_deck' THEN
            UPDATE public.match_cards mc
            SET current_power = GREATEST(0, mc.current_power - 1000)
            FROM public.cards c
            WHERE mc.source_card_id = c.id 
              AND mc.match_id = p_match_id 
              AND mc.owner_user_id = v_opponent_id 
              AND mc.zone = 'deck' 
              AND c.element IN ('Bestiary', 'Bestiário');
              
            RETURN jsonb_build_object('success', true, 'message', 'Enemy Bestiary deck debuffed', 'code', p_code);

        WHEN 'comp_protofleders_coinflip_snipe' THEN
            v_roll := random();
            IF v_roll <= 0.5 THEN
                SELECT id INTO v_temp_id FROM public.match_cards
                WHERE match_id = p_match_id AND owner_user_id = v_opponent_id AND zone = 'life' AND current_life > 0
                ORDER BY random() LIMIT 1;

                IF v_temp_id IS NOT NULL THEN
                    v_dmg := COALESCE(v_source_card_rec.current_power, 2900);
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
            IF v_source_card_rec.zone = 'graveyard' THEN
                SELECT count(*) INTO v_val FROM public.match_cards
                WHERE match_id = p_match_id AND owner_user_id = p_actor AND zone = 'hand';
                IF v_val < 10 THEN
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
            SELECT id INTO v_temp_id FROM public.match_cards
            WHERE match_id = p_match_id AND owner_user_id = v_opponent_id AND zone = 'hand'
            ORDER BY random() LIMIT 1;

            IF v_temp_id IS NOT NULL THEN
                v_action := jsonb_build_object(
                    'type', 'move_card',
                    'card_id', v_temp_id,
                    'source_zone', 'hand',
                    'target_zone', 'hand',
                    'player_id', p_actor,
                    'from_player_id', v_opponent_id
                );
                v_result := jsonb_set(v_result, '{actions}', (v_result->'actions') || v_action);
            END IF;
            RETURN v_result;

        WHEN 'comp_dismas_death_heal_adjacent_life' THEN
            IF v_source_card_rec.zone = 'reinforcement' THEN
                SELECT id INTO v_adjacent_id FROM public.match_cards
                WHERE match_id = p_match_id AND owner_user_id = p_actor AND zone = 'life' AND current_life > 0
                ORDER BY CASE WHEN current_life < maximum_life THEN 0 ELSE 1 END, random()
                LIMIT 1;

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
            FOR v_target_card_rec IN 
                SELECT * FROM public.match_cards mc
                WHERE mc.match_id = p_match_id AND mc.owner_user_id = v_opponent_id AND mc.zone = 'reinforcement' AND mc.current_life > 0
            LOOP
                IF (v_target_card_rec.metadata->'auras') @> '[{"aura_type": "taunt"}]' 
                   OR (v_target_card_rec.metadata->'auras') @> '[{"aura_type": "block_direct_attack"}]' 
                   OR (v_target_card_rec.metadata->'auras') @> '[{"aura_type": "block_attack"}]'
                   OR COALESCE((v_target_card_rec.metadata->>'has_taunt')::boolean, false) = true THEN
                   
                    v_action := jsonb_build_object(
                        'type', 'destroy_card',
                        'target_id', v_target_card_rec.id
                    );
                    v_result := jsonb_set(v_result, '{actions}', (v_result->'actions') || v_action);
                END IF;
            END LOOP;
            RETURN v_result;

        WHEN 'comp_lyra_cap_highest_deck_mana' THEN
            SELECT mc.id INTO v_temp_id
            FROM public.match_cards mc
            JOIN public.match_deck_cards d ON d.id = mc.match_deck_card_id
            WHERE mc.match_id = p_match_id and mc.owner_user_id = p_actor and mc.zone = 'deck'
            ORDER BY d.effect_mana_cost DESC, random()
            LIMIT 1;

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
            PERFORM game_private.execute_common_effect_internal_v35_core(p_match_id, p_actor, p_source, p_code, p_params, p_target, p_event);
            RETURN '{}'::jsonb;
    END CASE;
END;
$function$;
