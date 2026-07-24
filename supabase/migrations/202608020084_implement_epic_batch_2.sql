-- Migration 202608020084_implement_epic_batch_2.sql
-- Chain of Responsibility: Rename current function and create a new one wrapping it for Epic Batch 2.

BEGIN;

ALTER FUNCTION game_private.execute_common_effect_internal(uuid, uuid, uuid, text, jsonb, uuid, jsonb) 
RENAME TO execute_common_effect_internal_v32_core;

CREATE OR REPLACE FUNCTION game_private.execute_common_effect_internal(
    p_match_id uuid,
    p_actor uuid,
    p_source uuid,
    p_code text,
    p_params jsonb,
    p_target uuid DEFAULT NULL,
    p_event jsonb DEFAULT NULL
) RETURNS void
LANGUAGE plpgsql
AS $$
DECLARE
    v_opponent uuid;
    v_source_card jsonb;
    v_source_state jsonb;
    v_target_card jsonb;
    v_target_state jsonb;
    v_state jsonb;
    v_data jsonb;
    v_target_owner uuid;
    v_value int;
    v_zone text;
    v_source_instance_id uuid;
    
    -- Variables for specific effects
    v_mf_count int;
    v_bestiario_count int;
    v_target_id uuid;
    v_card record;
    v_card_data jsonb;
    v_has_sigrith boolean;
    v_has_witcher boolean;
    v_has_mf boolean;
    v_cem_count int;
    v_turn int;
    v_history jsonb;
    v_past_effect record;
    v_card_id uuid;
BEGIN
    -- Determine opponent
    SELECT p1_id, p2_id INTO v_data
    FROM public.matches
    WHERE id = p_match_id;

    IF v_data IS NULL THEN
        RAISE EXCEPTION 'Match not found';
    END IF;

    IF v_data->>'p1_id' = p_actor::text THEN
        v_opponent := (v_data->>'p2_id')::uuid;
    ELSE
        v_opponent := (v_data->>'p1_id')::uuid;
    END IF;

    -- Fetch match state
    SELECT state INTO v_state
    FROM public.matches
    WHERE id = p_match_id;

    -- Fetch source card details
    SELECT instance_id, card_id, card_data, state INTO v_source_instance_id, v_source_card, v_data, v_source_state
    FROM public.match_cards
    WHERE match_id = p_match_id AND instance_id = p_source;

    IF p_code = 'epic_chorabash_beast_suppress_halve' THEN
        -- EPIC_020
        IF p_target IS NOT NULL THEN
            SELECT card_data INTO v_target_state FROM public.match_cards WHERE instance_id = p_target;
            IF v_target_state->>'element' = 'Bestiário' THEN
                UPDATE public.match_cards
                SET state = jsonb_set(
                    jsonb_set(COALESCE(state, '{}'::jsonb), '{suppressed}', 'true'::jsonb),
                    '{life}', to_jsonb(COALESCE((state->>'life')::int, (card_data->>'base_max_life')::int) / 2)
                )
                WHERE instance_id = p_target;
            END IF;
        END IF;

        SELECT COUNT(*) > 0 INTO v_has_mf FROM public.match_cards WHERE match_id = p_match_id AND owner_id = p_actor AND zone = 'graveyard' AND card_data->>'code' = 'COMMON_001';
        IF v_has_mf THEN
            UPDATE public.match_cards
            SET state = jsonb_set(
                jsonb_set(COALESCE(state, '{}'::jsonb), '{power}', to_jsonb(COALESCE((state->>'power')::int, (card_data->>'base_power')::int) + 1000)),
                '{life}', to_jsonb(COALESCE((state->>'life')::int, (card_data->>'base_max_life')::int) + 1000)
            )
            WHERE instance_id = p_source;
        END IF;

    ELSIF p_code = 'epic_werewolf_defensive_power_nullify' THEN
        -- EPIC_021
        SELECT jsonb_array_length(COALESCE(v_state->'combat'->'attackers', '[]'::jsonb)) INTO v_value;
        IF v_value > 3 THEN
            SELECT elem::uuid INTO v_target_id FROM jsonb_array_elements_text(v_state->'combat'->'attackers') AS elem ORDER BY random() LIMIT 1;
            IF v_target_id IS NOT NULL THEN
                UPDATE public.match_cards SET state = jsonb_set(COALESCE(state, '{}'::jsonb), '{power}', to_jsonb(0)) WHERE instance_id = v_target_id;
            END IF;
        END IF;

    ELSIF p_code = 'epic_helel_surgical_eradication' THEN
        -- EPIC_022
        IF p_target IS NOT NULL THEN
            SELECT card_id INTO v_card_id FROM public.match_cards WHERE instance_id = p_target;
            IF v_card_id IS NOT NULL THEN
                DELETE FROM public.match_cards WHERE match_id = p_match_id AND owner_id = v_opponent AND card_id = v_card_id;
            END IF;
        END IF;

    ELSIF p_code = 'epic_conjunction_instant_win' THEN
        -- EPIC_023
        SELECT COUNT(*) INTO v_value FROM public.match_cards WHERE match_id = p_match_id AND owner_id = p_actor AND zone = 'hand' AND card_id = (SELECT card_id FROM public.match_cards WHERE instance_id = p_source);
        IF v_value >= 3 THEN
            UPDATE public.matches SET winner_id = p_actor, status = 'finished' WHERE id = p_match_id;
        END IF;

    ELSIF p_code = 'epic_hym_graveyard_hijack' THEN
        -- EPIC_024
        UPDATE public.match_cards SET owner_id = p_actor WHERE match_id = p_match_id AND owner_id = v_opponent AND zone = 'graveyard';

    ELSIF p_code = 'epic_lich_lock_rare_summons' THEN
        -- EPIC_025
        UPDATE public.matches
        SET state = jsonb_set(
            jsonb_set(COALESCE(state, '{}'::jsonb), '{modifiers}', COALESCE(state->'modifiers', '{}'::jsonb)),
            array['modifiers', v_opponent::text],
            jsonb_set(COALESCE(state->'modifiers'->(v_opponent::text), '{}'::jsonb), '{cant_summon_rare_lich_lock}', to_jsonb(p_source::text))
        )
        WHERE id = p_match_id;

    ELSIF p_code = 'epic_nargor_deck_hand_seal' THEN
        -- EPIC_026
        SELECT instance_id INTO v_target_id FROM public.match_cards WHERE match_id = p_match_id AND owner_id = v_opponent AND zone = 'hand' ORDER BY random() LIMIT 1;
        IF v_target_id IS NOT NULL THEN
            UPDATE public.match_cards SET state = jsonb_set(COALESCE(state, '{}'::jsonb), '{suppressed}', 'true'::jsonb) WHERE instance_id = v_target_id;
        END IF;

    ELSIF p_code = 'epic_helena_hand_size_squeeze' THEN
        -- EPIC_027
        UPDATE public.matches
        SET state = jsonb_set(COALESCE(state, '{}'::jsonb), '{global_hand_limit}', '4'::jsonb)
        WHERE id = p_match_id;

    ELSIF p_code = 'epic_kalemir_witcher_hand_reload' THEN
        -- EPIC_028
        SELECT COUNT(*) INTO v_value FROM public.match_cards WHERE match_id = p_match_id AND owner_id = p_actor AND zone = 'hand';
        UPDATE public.match_cards SET zone = 'deck' WHERE match_id = p_match_id AND owner_id = p_actor AND zone = 'hand';
        FOR i IN 1..v_value LOOP
            SELECT instance_id INTO v_target_id FROM public.match_cards WHERE match_id = p_match_id AND owner_id = p_actor AND zone = 'deck' AND card_data->>'element' = 'Witcher' ORDER BY random() LIMIT 1;
            IF v_target_id IS NOT NULL THEN
                UPDATE public.match_cards SET zone = 'hand' WHERE instance_id = v_target_id;
            END IF;
        END LOOP;

    ELSIF p_code = 'epic_rosa_attack_bounce_buff' THEN
        -- EPIC_029
        UPDATE public.match_cards SET zone = 'hand', state = jsonb_set(jsonb_set(COALESCE(state, '{}'::jsonb), '{power}', to_jsonb(COALESCE((state->>'power')::int, (card_data->>'base_power')::int) + 500)), '{life}', to_jsonb(COALESCE((state->>'life')::int, (card_data->>'base_max_life')::int) + 500)) WHERE instance_id = p_source;

    ELSIF p_code = 'epic_celenia_reset_life_cooldown' THEN
        -- EPIC_030
        IF p_target IS NOT NULL THEN
            UPDATE public.match_cards SET state = (COALESCE(state, '{}'::jsonb) - 'exhausted') WHERE instance_id = p_target;
        END IF;

    ELSIF p_code = 'epic_lirenne_hand_life_swap' THEN
        -- EPIC_031
        IF p_target IS NOT NULL THEN
            SELECT zone, zone_position INTO v_zone, v_value FROM public.match_cards WHERE instance_id = p_target;
            IF v_zone = 'hand' THEN
                v_target_id := (p_event->>'secondary_target')::uuid;
                IF v_target_id IS NULL THEN
                    SELECT instance_id INTO v_target_id FROM public.match_cards WHERE match_id = p_match_id AND owner_id = p_actor AND zone = 'life' ORDER BY random() LIMIT 1;
                END IF;
                IF v_target_id IS NOT NULL THEN
                    SELECT zone_position INTO v_cem_count FROM public.match_cards WHERE instance_id = v_target_id;
                    UPDATE public.match_cards SET zone = 'life', zone_position = v_cem_count WHERE instance_id = p_target;
                    UPDATE public.match_cards SET zone = 'hand', zone_position = NULL WHERE instance_id = v_target_id;
                END IF;
            ELSIF v_zone = 'life' THEN
                v_target_id := (p_event->>'secondary_target')::uuid;
                IF v_target_id IS NULL THEN
                    SELECT instance_id INTO v_target_id FROM public.match_cards WHERE match_id = p_match_id AND owner_id = p_actor AND zone = 'hand' ORDER BY random() LIMIT 1;
                END IF;
                IF v_target_id IS NOT NULL THEN
                    UPDATE public.match_cards SET zone = 'life', zone_position = v_value WHERE instance_id = v_target_id;
                    UPDATE public.match_cards SET zone = 'hand', zone_position = NULL WHERE instance_id = p_target;
                END IF;
            END IF;
        END IF;

    ELSIF p_code = 'epic_botchling_retaliation_draw_curse' THEN
        -- EPIC_032
        SELECT jsonb_array_length(COALESCE(v_state->'combat'->'attackers', '[]'::jsonb)) INTO v_value;
        IF v_value > 0 THEN
            FOR i IN 1..v_value LOOP
                SELECT instance_id INTO v_target_id FROM public.match_cards WHERE match_id = p_match_id AND owner_id = p_actor AND zone = 'deck' ORDER BY random() LIMIT 1;
                IF v_target_id IS NOT NULL THEN
                    UPDATE public.match_cards SET zone = 'hand' WHERE instance_id = v_target_id;
                END IF;
            END LOOP;
        END IF;

        SELECT instance_id, card_id, card_data INTO v_target_id, v_card_id, v_data FROM public.match_cards WHERE match_id = p_match_id AND card_data->>'code' = 'COMMON_013' AND owner_id = p_actor AND zone = 'graveyard' LIMIT 1;
        IF v_target_id IS NOT NULL THEN
            INSERT INTO public.match_cards (match_id, owner_id, card_id, instance_id, zone, position, card_data, state, revealed)
            VALUES (p_match_id, v_opponent, v_card_id, gen_random_uuid(), 'hand', 99, v_data, '{}'::jsonb, false);
        END IF;

    ELSE
        PERFORM game_private.execute_common_effect_internal_v32_core(p_match_id, p_actor, p_source, p_code, p_params, p_target, p_event);
    END IF;
END;
$$;

COMMIT;
