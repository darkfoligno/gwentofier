-- Campaign Refinements and Shaw Okami metadata/logic update
-- 1. Update Shaw Okami card target_mode metadata
UPDATE public.card_effects
SET target_mode = 'deck'
WHERE card_id = '6a78cfed-ba62-467a-81ed-5c3e24e4226a';

-- 2. Implement execute_common_effect_internal with Shaw Okami effect
CREATE OR REPLACE FUNCTION game_private.execute_common_effect_internal(p_match_id uuid, p_actor uuid, p_source uuid, p_code text, p_params jsonb, p_target uuid DEFAULT NULL::uuid, p_event jsonb DEFAULT NULL::jsonb)
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
    v_deck_card_id uuid;
    v_src_card_id uuid;
    v_power integer;
    v_life integer;
BEGIN
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
        WHEN 'leg_shaw_okami_clone_five_to_deck' THEN
            SELECT match_deck_card_id, source_card_id, base_power, base_max_life 
            INTO v_deck_card_id, v_src_card_id, v_power, v_life
            FROM public.match_cards
            WHERE id = p_target AND match_id = p_match_id AND owner_user_id = p_actor AND zone = 'deck';

            IF v_deck_card_id IS NOT NULL THEN
                FOR i IN 1..5 LOOP
                    INSERT INTO public.match_cards(
                        match_id, owner_user_id, controller_user_id, match_deck_card_id, source_card_id,
                        zone, zone_position, is_face_up, base_power, base_max_life,
                        current_power, maximum_power, current_life, maximum_life
                    ) VALUES (
                        p_match_id, p_actor, p_actor, v_deck_card_id, v_src_card_id,
                        'deck', (SELECT coalesce(max(zone_position), 0) + 1 FROM public.match_cards WHERE match_id = p_match_id AND owner_user_id = p_actor AND zone = 'deck'),
                        false, v_power, v_life,
                        v_power, v_power, v_life, v_life
                    );
                END LOOP;
            END IF;
            RETURN jsonb_build_object('success', true, 'message', 'Shaw Okami clonou 5 cartas no deck.', 'code', p_code);

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


-- 3. Update start_campaign_match to run on ban_phase and pre-ban human legendary
CREATE OR REPLACE FUNCTION public.start_campaign_match(p_deck_id uuid)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
    v_user_id uuid := game_private.require_authenticated();
    v_bot_id uuid := '00000000-0000-4000-8000-000000000071'::uuid;
    v_match_id uuid;
    v_rule_id uuid;
    v_player_match_deck_id uuid;
    v_bot_match_deck_id uuid;
    v_card record;
    v_position integer;
    v_cards_list uuid[] := ARRAY[
        'a5dcdb5a-92d9-42ef-89ef-1ccbbecada40'::uuid, 'a5dcdb5a-92d9-42ef-89ef-1ccbbecada40'::uuid, 'a5dcdb5a-92d9-42ef-89ef-1ccbbecada40'::uuid, 'a5dcdb5a-92d9-42ef-89ef-1ccbbecada40'::uuid, 'a5dcdb5a-92d9-42ef-89ef-1ccbbecada40'::uuid, 'a5dcdb5a-92d9-42ef-89ef-1ccbbecada40'::uuid,
        '396784cd-e61b-4f7e-8fba-3757eaca72a4'::uuid, '396784cd-e61b-4f7e-8fba-3757eaca72a4'::uuid, '396784cd-e61b-4f7e-8fba-3757eaca72a4'::uuid, '396784cd-e61b-4f7e-8fba-3757eaca72a4'::uuid, '396784cd-e61b-4f7e-8fba-3757eaca72a4'::uuid, '396784cd-e61b-4f7e-8fba-3757eaca72a4'::uuid,
        'c8f31e9d-0931-454a-b025-d3a9e076e04b'::uuid, 'c8f31e9d-0931-454a-b025-d3a9e076e04b'::uuid, 'c8f31e9d-0931-454a-b025-d3a9e076e04b'::uuid, 'c8f31e9d-0931-454a-b025-d3a9e076e04b'::uuid, 'c8f31e9d-0931-454a-b025-d3a9e076e04b'::uuid, 'c8f31e9d-0931-454a-b025-d3a9e076e04b'::uuid,
        '468273d5-a91a-4401-ad34-9e1ed222a63e'::uuid, '468273d5-a91a-4401-ad34-9e1ed222a63e'::uuid, '468273d5-a91a-4401-ad34-9e1ed222a63e'::uuid, '468273d5-a91a-4401-ad34-9e1ed222a63e'::uuid,
        'e1f3727a-c9ae-46ef-accd-d30bab2e39a3'::uuid, 'e1f3727a-c9ae-46ef-accd-d30bab2e39a3'::uuid, 'e1f3727a-c9ae-46ef-accd-d30bab2e39a3'::uuid, 'e1f3727a-c9ae-46ef-accd-d30bab2e39a3'::uuid,
        'a0a82d31-2094-4256-92b9-8bc58c9ba311'::uuid, 'a0a82d31-2094-4256-92b9-8bc58c9ba311'::uuid, 'a0a82d31-2094-4256-92b9-8bc58c9ba311'::uuid, 'a0a82d31-2094-4256-92b9-8bc58c9ba311'::uuid,
        'be345ece-e5f6-44da-8bd2-9382744fc868'::uuid, 'be345ece-e5f6-44da-8bd2-9382744fc868'::uuid, 'be345ece-e5f6-44da-8bd2-9382744fc868'::uuid, 'be345ece-e5f6-44da-8bd2-9382744fc868'::uuid, 'be345ece-e5f6-44da-8bd2-9382744fc868'::uuid,
        '126a4c87-38ba-4727-b031-3949d49205cf'::uuid, '126a4c87-38ba-4727-b031-3949d49205cf'::uuid, '126a4c87-38ba-4727-b031-3949d49205cf'::uuid, '126a4c87-38ba-4727-b031-3949d49205cf'::uuid,
        '58f04ead-dfa9-4fba-b155-76d336beb0d1'::uuid, '58f04ead-dfa9-4fba-b155-76d336beb0d1'::uuid,
        'cc6cc445-8484-470f-a71e-3e63dbf0008d'::uuid, 'cc6cc445-8484-470f-a71e-3e63dbf0008d'::uuid, 'cc6cc445-8484-470f-a71e-3e63dbf0008d'::uuid,
        'eb3a66bd-b41a-44b0-a2e4-3205da3a88c8'::uuid, 'eb3a66bd-b41a-44b0-a2e4-3205da3a88c8'::uuid, 'eb3a66bd-b41a-44b0-a2e4-3205da3a88c8'::uuid, 'eb3a66bd-b41a-44b0-a2e4-3205da3a88c8'::uuid,
        'dd4305b6-5d0f-4b4b-8bd1-bfa84ba67dbf'::uuid
    ];
    v_card_id uuid;
    v_player_legendary_card_id uuid;
BEGIN
    IF v_user_id <> 'b6cd0821-39ae-451f-a8ca-25694c3e553c'::uuid THEN
        RAISE EXCEPTION 'Acesso negado ao Modo Campanha.';
    END IF;

    SELECT id INTO v_rule_id FROM public.game_rule_versions WHERE is_active = true LIMIT 1;

    INSERT INTO public.matches(
        rule_version_id, match_type, created_by,
        requires_bans, is_private, status, current_turn, active_player_id
    )
    VALUES (
        v_rule_id, 'campaign', v_user_id,
        true, true, 'ban_phase', 0, v_user_id
    )
    RETURNING id INTO v_match_id;

    INSERT INTO public.match_players(match_id, user_id, player_number, original_deck_id)
    VALUES 
        (v_match_id, v_user_id, 1, CASE WHEN p_deck_id = '00000000-0000-0000-0000-000000000000'::uuid OR p_deck_id = '00000000-0000-0000-0000-000000000072'::uuid THEN NULL ELSE p_deck_id END),
        (v_match_id, v_bot_id, 2, NULL);

    IF p_deck_id = '00000000-0000-0000-0000-000000000000'::uuid OR p_deck_id = '00000000-0000-0000-0000-000000000072'::uuid OR p_deck_id IS NULL THEN
        PERFORM game_private.snapshot_deck(v_match_id, v_user_id, '00000000-0000-0000-0000-000000000000'::uuid);
    ELSE
        PERFORM game_private.snapshot_deck(v_match_id, v_user_id, p_deck_id);
    END IF;

    INSERT INTO public.match_decks(match_id, user_id, source_deck_id, total_cards, golden_cards_count)
    VALUES (v_match_id, v_bot_id, NULL, array_length(v_cards_list, 1), 6)
    RETURNING id INTO v_bot_match_deck_id;

    v_position := 0;
    FOREACH v_card_id IN ARRAY v_cards_list LOOP
        v_position := v_position + 1;
        SELECT c.*,
               coalesce((select jsonb_agg(jsonb_build_object('effect_order', ce.effect_order, 'trigger_type', ce.trigger_type, 'effect_code', ce.effect_code, 'target_mode', ce.target_mode, 'parameters', ce.parameters, 'priority', ce.priority, 'is_reaction', ce.is_reaction, 'once_per_turn', ce.once_per_turn) order by ce.effect_order) from public.card_effects ce where ce.card_id = c.id and ce.is_active = true), '[]'::jsonb) as effect_definition
        INTO v_card
        FROM public.cards c WHERE c.id = v_card_id;

        INSERT INTO public.match_deck_cards(
            match_deck_id, source_card_id, card_version, card_name, image_url, element, rarity, card_type, is_golden, base_power, base_max_life, effect_mana_cost, tier, leader_cooldown, effect_definition, copy_number
        ) VALUES (
            v_bot_match_deck_id, v_card.id, v_card.version, v_card.name, coalesce(v_card.image_url, ''), coalesce(v_card.element, 'Neutro'), v_card.rarity, v_card.card_type, v_card.is_golden, coalesce(v_card.base_power, 0), coalesce(v_card.base_max_life, 0), coalesce(v_card.effect_mana_cost, 0), coalesce(v_card.tier, 1), coalesce(v_card.leader_cooldown, 0), coalesce(v_card.effect_definition, '[]'::jsonb), 1
        );
    END LOOP;

    INSERT INTO public.match_cards(match_id, owner_user_id, controller_user_id, match_deck_card_id, source_card_id, zone, zone_position, is_face_up, base_power, base_max_life, current_power, maximum_power, current_life, maximum_life)
    SELECT v_match_id, v_bot_id, v_bot_id, mdc.id, mdc.source_card_id, 'deck', row_number() over (order by random()), false, mdc.base_power, mdc.base_max_life, mdc.base_power, mdc.base_power, mdc.base_max_life, mdc.base_max_life
    FROM public.match_deck_cards mdc WHERE mdc.match_deck_id = v_bot_match_deck_id;

    INSERT INTO public.training_matches(match_id, human_user_id, bot_user_id)
    VALUES (v_match_id, v_user_id, v_bot_id);

    INSERT INTO public.match_public_states(match_id, player1_user_id, player1_username, player2_user_id, player2_username)
    SELECT v_match_id, p1.id, p1.username, p2.id, 'Rei dos Mendigos (Chefe)'
    FROM public.profiles p1, public.profiles p2
    WHERE p1.id = v_user_id AND p2.id = v_bot_id;

    -- Bot auto-ban human legendary card immediately
    SELECT mc.id INTO v_player_legendary_card_id
    FROM public.match_cards mc
    JOIN public.match_deck_cards mdc ON mdc.id = mc.match_deck_card_id
    WHERE mc.match_id = v_match_id AND mc.owner_user_id = v_user_id AND mc.zone = 'deck' AND mdc.rarity = 'legendary'
    ORDER BY random() LIMIT 1;
    
    IF v_player_legendary_card_id IS NOT NULL THEN
        UPDATE public.match_cards SET zone = 'banished', is_face_up = true WHERE id = v_player_legendary_card_id;
        
        INSERT INTO public.match_bans(match_id, banned_by_user_id, target_user_id, source_card_id, ban_category, is_skipped)
        VALUES (v_match_id, v_bot_id, v_user_id, (SELECT source_card_id FROM public.match_cards WHERE id = v_player_legendary_card_id), 'legendary', false);
    ELSE
        INSERT INTO public.match_bans(match_id, banned_by_user_id, target_user_id, source_card_id, ban_category, is_skipped)
        VALUES (v_match_id, v_bot_id, v_user_id, null, 'legendary', true);
    END IF;

    PERFORM game_private.recalculate_match_public_state(v_match_id);

    RETURN v_match_id;
END;
$function$;


-- 4. Update run_campaign_bot_turn to never pass the round voluntarily (always p_passed := false)
CREATE OR REPLACE FUNCTION public.run_campaign_bot_turn(p_match_id uuid, p_expected_version bigint)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
  v_human_id uuid := game_private.require_authenticated();
  v_bot_id uuid := '00000000-0000-4000-8000-000000000071'::uuid;
  v_match public.matches;
  v_chosen_card_id uuid;
  v_slot integer;
  v_version bigint := p_expected_version;
  v_pending_attack_id uuid;
  v_total_power integer;
  v_attacker_ids uuid[];
  v_reinforcement_count integer;
  v_hand_count integer;
  v_human_reinforcements integer;
  v_human_life_count integer;
  v_last_life_hp integer;
  v_existing_attack_power integer;
  v_best_hand_power integer;
  v_lethal_opportunity boolean := false;
  v_failure_state text;
  v_failure_message text;
  v_card_to_play record;
  v_mana_avail integer;
BEGIN
  SELECT m.* INTO v_match FROM public.matches m WHERE m.id = p_match_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'MATCH_NOT_FOUND'; END IF;
  IF v_match.state_version <> p_expected_version THEN RAISE EXCEPTION 'STALE_MATCH_VERSION'; END IF;
  IF v_match.status <> 'in_progress' OR v_match.engine_state <> 'turn_action' THEN RAISE EXCEPTION 'MATCH_FLOW_IS_BLOCKED'; END IF;
  IF v_match.active_player_id <> v_bot_id THEN RAISE EXCEPTION 'BOT_IS_NOT_ACTIVE_PLAYER'; END IF;

  SELECT count(*)::integer INTO v_hand_count
  FROM public.match_cards mc
  WHERE mc.match_id = p_match_id AND mc.owner_user_id = v_bot_id AND mc.zone = 'hand';

  SELECT mana_available INTO v_mana_avail FROM public.match_players WHERE match_id = p_match_id AND user_id = v_bot_id;

  -- Regra A & D: Play cards from hand
  -- We exclude "Rei dos Mendigos" (a5dcdb5a-92d9-42ef-89ef-1ccbbecada40) unless it is the last card in hand
  SELECT mc.* INTO v_card_to_play
  FROM public.match_cards mc
  WHERE mc.match_id = p_match_id 
    AND mc.owner_user_id = v_bot_id 
    AND mc.zone = 'hand'
    AND (v_hand_count = 1 OR mc.source_card_id <> 'a5dcdb5a-92d9-42ef-89ef-1ccbbecada40'::uuid)
  ORDER BY mc.current_power DESC, mc.id ASC
  LIMIT 1;

  IF v_card_to_play IS NOT NULL THEN
      SELECT count(*)::integer INTO v_reinforcement_count
      FROM public.match_cards mc
      WHERE mc.match_id = p_match_id AND mc.controller_user_id = v_bot_id
        AND mc.zone = 'reinforcement' AND mc.current_life > 0;

      IF v_reinforcement_count < 4 THEN
          SELECT gs.slot INTO v_slot FROM generate_series(1,4) gs(slot)
          WHERE NOT EXISTS(
            SELECT 1 FROM public.match_cards mc WHERE mc.match_id = p_match_id
              AND mc.controller_user_id = v_bot_id AND mc.zone = 'reinforcement' AND mc.zone_position = gs.slot
          ) ORDER BY gs.slot LIMIT 1;

          IF v_slot IS NOT NULL THEN
              UPDATE public.match_cards SET zone='reinforcement', zone_position=v_slot, is_face_up=false, entered_zone_turn=v_match.current_turn WHERE id=v_card_to_play.id;
              UPDATE public.match_players SET actions_this_turn=actions_this_turn+1 WHERE match_id=p_match_id AND user_id=v_bot_id;
              v_version := game_private.record_match_action(p_match_id,v_bot_id,'card_played',jsonb_build_object('match_card_id',v_card_to_play.id,'destination_zone','reinforcement','destination_position',v_slot,'campaign_bot',true,'hand_retained',v_hand_count-1),'{}'::jsonb,v_version);
              RETURN jsonb_build_object('action','reinforcement_played','state_version',v_version,'hand_retained',v_hand_count-1);
          END IF;
      ELSE
          SELECT gs.slot INTO v_slot FROM generate_series(1,4) gs(slot)
          WHERE NOT EXISTS(
            SELECT 1 FROM public.match_cards mc WHERE mc.match_id = p_match_id
              AND mc.controller_user_id = v_bot_id AND mc.zone = 'attacker' AND mc.zone_position = gs.slot
          ) ORDER BY gs.slot LIMIT 1;

          IF v_slot IS NOT NULL THEN
              UPDATE public.match_cards SET zone='attacker', zone_position=v_slot, is_face_up=true, entered_zone_turn=v_match.current_turn WHERE id=v_card_to_play.id;
              UPDATE public.match_players SET actions_this_turn=actions_this_turn+1 WHERE match_id=p_match_id AND user_id=v_bot_id;
              v_version := game_private.record_match_action(p_match_id,v_bot_id,'card_played',jsonb_build_object('match_card_id',v_card_to_play.id,'destination_zone','attacker','destination_position',v_slot,'campaign_bot',true,'hand_retained',v_hand_count-1),'{}'::jsonb,v_version);
              RETURN jsonb_build_object('action','attacker_played','state_version',v_version,'hand_retained',v_hand_count-1);
          END IF;
      END IF;
  END IF;

  -- Attack logic
  SELECT array_agg(mc.id ORDER BY mc.zone_position), sum(mc.current_power)::integer
  INTO v_attacker_ids, v_total_power
  from public.match_cards mc
  where mc.match_id=p_match_id and mc.controller_user_id=v_bot_id and mc.zone='attacker'
    and mc.current_life>0 and mc.can_attack and not mc.has_attacked_this_turn;

  IF coalesce(cardinality(v_attacker_ids),0)>0 THEN
    SELECT count(*)::integer, max(mc.current_life)::integer
    INTO v_human_life_count, v_last_life_hp
    FROM public.match_cards mc
    WHERE mc.match_id = p_match_id AND mc.controller_user_id = v_human_id
      AND mc.zone = 'life' AND mc.current_life > 0;

    INSERT INTO public.pending_attacks(match_id,attacker_user_id,defender_user_id,status,is_direct,declared_power,reaction_deadline,declared_state_version)
    VALUES (p_match_id,v_bot_id,v_human_id,'awaiting_reaction',false,v_total_power,clock_timestamp()+interval '45 seconds',v_version)
    RETURNING id INTO v_pending_attack_id;
    
    INSERT INTO public.pending_attack_cards(pending_attack_id,match_card_id,attack_position,power_when_declared)
    SELECT v_pending_attack_id, attack_card.id, attack_card.ordinality::integer,
      (select mc.current_power from public.match_cards mc where mc.id=attack_card.id)
    from unnest(v_attacker_ids) with ordinality attack_card(id,ordinality);
    
    UPDATE public.match_cards mc set metadata=mc.metadata||jsonb_build_object('locked_for_pending_attack',v_pending_attack_id) where mc.id=any(v_attacker_ids);
    UPDATE public.match_players mp set actions_this_turn=mp.actions_this_turn+1 where mp.match_id=p_match_id and mp.user_id=v_bot_id;
    v_version := game_private.record_match_action(p_match_id,v_bot_id,'attack_declared',jsonb_build_object('pending_attack_id',v_pending_attack_id,'attacker_user_id',v_bot_id,'defender_user_id',v_human_id,'attacker_card_ids',to_jsonb(v_attacker_ids),'total_power',v_total_power,'is_direct',false,'campaign_bot',true),'{}'::jsonb,v_version);
    UPDATE public.pending_attacks pa set declared_state_version=v_version where pa.id=v_pending_attack_id;
    RETURN jsonb_build_object('action','attack_declared','state_version',v_version,'pending_attack_id',v_pending_attack_id);
  END IF;

  -- Regra D: Never pass round (p_passed = false)
  RETURN game_private.change_active_turn(p_match_id,v_bot_id,false,v_version)
    ||jsonb_build_object('action','mana_preserved','hand_retained',v_hand_count);

EXCEPTION WHEN OTHERS THEN
  GET STACKED DIAGNOSTICS v_failure_state=returned_sqlstate, v_failure_message=message_text;
  SELECT m.* INTO v_match from public.matches m where m.id=p_match_id for update;
  IF v_match.active_player_id=v_bot_id and v_match.state_version=p_expected_version THEN
    return game_private.change_active_turn(p_match_id,v_bot_id,false,p_expected_version)
      ||jsonb_build_object('action','safe_fallback_end_turn','bot_error_code',v_failure_state,'bot_error_message',v_failure_message);
  END IF;
  RAISE;
END;
$function$;


-- 5. Update auto_resolve_campaign_attack with robust exception handling fallback
CREATE OR REPLACE FUNCTION public.auto_resolve_campaign_attack(p_match_id uuid, p_expected_version bigint)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
  human uuid := game_private.require_authenticated();
  bot uuid := '00000000-0000-4000-8000-000000000071'::uuid;
  pa public.pending_attacks;
  version bigint;
  resolved jsonb;
  turn_result jsonb;
  v_has_baltazar boolean;
  v_discard_card_id uuid;
BEGIN
  SELECT bot_user_id INTO bot FROM public.training_matches WHERE match_id=p_match_id and human_user_id=human;
  IF bot IS NULL THEN RAISE EXCEPTION 'NOT_YOUR_TRAINING_MATCH'; END IF;

  SELECT * INTO pa FROM public.pending_attacks 
  WHERE match_id=p_match_id and attacker_user_id=human and defender_user_id=bot and status='awaiting_reaction' 
  ORDER BY created_at DESC LIMIT 1 FOR UPDATE;
  
  IF NOT FOUND THEN RAISE EXCEPTION 'TRAINING_PENDING_ATTACK_NOT_FOUND'; END IF;

  BEGIN
      -- Regra C: Check if direct attack and bot has Baltazar (468273d5-a91a-4401-ad34-9e1ed222a63e)
      SELECT EXISTS(
          SELECT 1 FROM public.match_cards 
          WHERE match_id = p_match_id AND owner_user_id = bot AND source_card_id = '468273d5-a91a-4401-ad34-9e1ed222a63e'::uuid AND zone IN ('hand', 'reinforcement', 'attacker')
      ) INTO v_has_baltazar;

      IF pa.is_direct = true AND v_has_baltazar = true AND (
          SELECT count(*) FROM public.match_cards WHERE match_id = p_match_id AND owner_user_id = bot AND zone = 'hand'
      ) >= 1 THEN
          SELECT id INTO v_discard_card_id
          FROM public.match_cards
          WHERE match_id = p_match_id AND owner_user_id = bot AND zone = 'hand'
          ORDER BY CASE WHEN source_card_id = 'a5dcdb5a-92d9-42ef-89ef-1ccbbecada40'::uuid THEN 1 ELSE 0 END, random()
          LIMIT 1;

          IF v_discard_card_id IS NOT NULL THEN
              UPDATE public.match_cards SET zone = 'graveyard' WHERE id = v_discard_card_id;

              UPDATE public.pending_attacks SET status='cancelled', reaction_completed_at=now() WHERE id=pa.id;
              
              UPDATE public.match_cards 
              SET metadata = metadata - 'locked_for_pending_attack'
              WHERE match_id = p_match_id AND (metadata->>'locked_for_pending_attack')::uuid = pa.id;

              version:=game_private.record_match_action(p_match_id,bot,'reaction_used',jsonb_build_object('pending_attack_id',pa.id,'campaign_bot',true,'baltazar_reaction',true,'discarded_card_id',v_discard_card_id),'{}',p_expected_version);
              
              turn_result:=game_private.change_active_turn(p_match_id,human,false,version);
              RETURN jsonb_build_object('success', true, 'match_finished', false, 'state_version', version, 'turn', turn_result, 'message', 'Baltazar cancelou o ataque.');
          END IF;
      END IF;

      -- Default reaction decline and resolve attack
      UPDATE public.pending_attacks SET status='reaction_declined',reaction_completed_at=now() WHERE id=pa.id;
      version:=game_private.record_match_action(p_match_id,bot,'reaction_declined',jsonb_build_object('pending_attack_id',pa.id,'campaign_bot',true),'{}',p_expected_version);
      resolved:=game_private.resolve_pending_attack_internal(pa.id,bot,version);
      version:=(resolved->>'state_version')::bigint;
      IF NOT coalesce((resolved->>'match_finished')::boolean,false) THEN turn_result:=game_private.change_active_turn(p_match_id,human,false,version); END IF;
      RETURN resolved||jsonb_build_object('turn',turn_result);

  EXCEPTION WHEN OTHERS THEN
      -- Fallback to decline reaction on failure to prevent freezing
      UPDATE public.pending_attacks SET status='reaction_declined', reaction_completed_at=now() WHERE id=pa.id;
      version:=game_private.record_match_action(p_match_id, bot, 'reaction_declined', jsonb_build_object('pending_attack_id', pa.id, 'campaign_bot', true, 'reaction_error', true), '{}', p_expected_version);
      resolved:=game_private.resolve_pending_attack_internal(pa.id, bot, version);
      version:=(resolved->>'state_version')::bigint;
      IF NOT coalesce((resolved->>'match_finished')::boolean, false) THEN 
          turn_result:=game_private.change_active_turn(p_match_id, human, false, version); 
      END IF;
      RETURN resolved||jsonb_build_object('turn', turn_result);
  END;
END $function$;
