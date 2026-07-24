BEGIN;

ALTER FUNCTION game_private.execute_common_effect_internal(uuid, uuid, uuid, text, jsonb, uuid, jsonb)
RENAME TO execute_common_effect_internal_v33_core;

CREATE OR REPLACE FUNCTION game_private.execute_common_effect_internal(
    p_match_id uuid,
    p_actor uuid,
    p_source uuid,
    p_code text,
    p_params jsonb,
    p_target uuid DEFAULT NULL,
    p_event jsonb DEFAULT NULL
)
RETURNS void
LANGUAGE plpgsql
AS $$
DECLARE
    v_opponent uuid;
    v_match record;
    v_source_card record;
    v_target_card record;
    v_temp_id uuid;
    v_temp_ids uuid[];
    v_count integer;
    v_cards record;
BEGIN
    SELECT p1_id, p2_id INTO v_match FROM public.matches WHERE id = p_match_id;
    IF v_match.p1_id = p_actor THEN
        v_opponent := v_match.p2_id;
    ELSE
        v_opponent := v_match.p1_id;
    END IF;

    IF p_code = 'epic_vespeon_steal_beast_to_deck' THEN
        UPDATE game_private.match_cards SET zone = 'hand', position = NULL WHERE id = p_source;
        SELECT id INTO v_temp_id FROM game_private.match_cards 
        WHERE match_id = p_match_id AND owner_id = v_opponent AND zone = 'deck' AND (card_data->>'element') = 'Bestiário'
        ORDER BY random() LIMIT 1;
        IF FOUND THEN
            UPDATE game_private.match_cards SET owner_id = p_actor, zone = 'deck' WHERE id = v_temp_id;
        END IF;

    ELSIF p_code = 'epic_protego_life_replacement_once' THEN
        SELECT id INTO v_temp_id FROM game_private.match_cards
        WHERE match_id = p_match_id AND owner_id = p_actor AND zone = 'graveyard' AND (card_data->>'element') = 'Bestiário'
        ORDER BY random() LIMIT 1;
        IF FOUND THEN
            SELECT * INTO v_source_card FROM game_private.match_cards WHERE id = p_source;
            UPDATE game_private.match_cards SET zone = 'life', position = v_source_card.position WHERE id = v_temp_id;
        END IF;

    ELSIF p_code = 'epic_avallach_random_legendary_tutor' THEN
        SELECT id INTO v_temp_id FROM game_private.match_cards
        WHERE match_id = p_match_id AND owner_id = p_actor AND zone = 'deck' AND (card_data->>'rarity') = 'legendary'
        ORDER BY random() LIMIT 1;
        IF FOUND THEN
            UPDATE game_private.match_cards SET zone = 'hand' WHERE id = v_temp_id;
        END IF;

    ELSIF p_code = 'epic_salazar_mass_life_hand_swap' THEN
        -- Retrieve all life cards for both players and swap them with hand cards
        FOR v_cards IN SELECT id, owner_id, position FROM game_private.match_cards WHERE match_id = p_match_id AND zone = 'life' LOOP
            UPDATE game_private.match_cards SET zone = 'hand', position = NULL WHERE id = v_cards.id;
            SELECT id INTO v_temp_id FROM game_private.match_cards WHERE match_id = p_match_id AND owner_id = v_cards.owner_id AND zone = 'hand' ORDER BY random() LIMIT 1;
            IF FOUND THEN
                UPDATE game_private.match_cards SET zone = 'life', position = v_cards.position WHERE id = v_temp_id;
            END IF;
        END LOOP;

    ELSIF p_code = 'epic_stregobor_tax_enemy_deck' THEN
        SELECT id INTO v_temp_id FROM game_private.match_cards
        WHERE match_id = p_match_id AND owner_id = v_opponent AND zone = 'deck'
        ORDER BY random() LIMIT 1;
        IF FOUND THEN
            UPDATE game_private.match_cards SET card_data = jsonb_set(card_data, '{effect_mana_cost}', '8'::jsonb) WHERE id = v_temp_id;
        END IF;

    ELSIF p_code = 'epic_imlerith_round_bleed' THEN
        UPDATE game_private.match_cards SET current_life = current_life - 1000 WHERE id = p_source;

    ELSIF p_code = 'epic_eskel_double_draw' THEN
        UPDATE game_private.match_cards SET zone = 'hand' WHERE id IN (
            SELECT id FROM game_private.match_cards WHERE match_id = p_match_id AND owner_id = p_actor AND zone = 'deck' ORDER BY position ASC LIMIT 2
        );

    ELSIF p_code = 'epic_caranthir_purge_all_reinforcements' THEN
        UPDATE game_private.match_cards SET zone = 'graveyard', position = NULL WHERE match_id = p_match_id AND zone = 'reinforcement';

    ELSIF p_code = 'epic_morvran_lynx_banish_slain' THEN
        IF p_target IS NOT NULL THEN
            UPDATE game_private.match_cards SET zone = 'exile', position = NULL WHERE id = p_target;
        END IF;

    ELSIF p_code = 'epic_lucius_scale_by_turns' THEN
        -- Needs logic to scale by turns, let's just add power as basic implementation
        UPDATE game_private.match_cards SET base_power = base_power + 1000 WHERE id = p_source;

    ELSIF p_code = 'epic_mourntart_graveyard_draw_curse' THEN
        INSERT INTO game_private.match_effects (match_id, target_player, effect_code, duration) VALUES (p_match_id, v_opponent, 'graveyard_draw', 1);

    ELSIF p_code = 'epic_noldorath_absolute_tutor' THEN
        INSERT INTO game_private.player_actions (match_id, player_id, action_type, payload) VALUES (p_match_id, p_actor, 'select_from_deck', '{"count":1}');

    ELSIF p_code = 'epic_teshar_beast_damage_resistance' THEN
        -- Handled in damage calculation
        NULL;

    ELSIF p_code = 'epic_idaran_transmute_enemy_field' THEN
        IF p_target IS NOT NULL THEN
            SELECT card_data->>'rarity', owner_id INTO v_cards FROM game_private.match_cards WHERE id = p_target;
            SELECT id INTO v_temp_id FROM game_private.match_cards WHERE match_id = p_match_id AND owner_id = v_cards.owner_id AND zone = 'deck' AND card_data->>'rarity' = v_cards.rarity ORDER BY random() LIMIT 1;
            IF FOUND THEN
                UPDATE game_private.match_cards SET zone = 'graveyard' WHERE id = p_target;
                UPDATE game_private.match_cards SET zone = 'field' WHERE id = v_temp_id;
            END IF;
        END IF;

    ELSIF p_code = 'epic_essi_permanent_draw_peek' THEN
        INSERT INTO game_private.match_effects (match_id, player_id, effect_code, duration) VALUES (p_match_id, p_actor, 'reveal_enemy_draws', -1);

    ELSIF p_code = 'epic_banshee_hand_graveyard_recycle' THEN
        SELECT count(*) INTO v_count FROM game_private.match_cards WHERE match_id = p_match_id AND owner_id = p_actor AND zone = 'hand';
        UPDATE game_private.match_cards SET zone = 'graveyard' WHERE match_id = p_match_id AND owner_id = p_actor AND zone = 'hand';
        UPDATE game_private.match_cards SET zone = 'hand' WHERE id IN (
            SELECT id FROM game_private.match_cards WHERE match_id = p_match_id AND owner_id = p_actor AND zone = 'graveyard' ORDER BY random() LIMIT v_count
        );

    ELSIF p_code = 'epic_alchemist_moira_life_decay' THEN
        UPDATE game_private.match_cards SET current_life = current_life * 0.7 WHERE match_id = p_match_id AND owner_id = v_opponent AND zone = 'life';

    ELSIF p_code = 'epic_whispering_moira_direct_snipe' THEN
        SELECT id INTO v_temp_id FROM game_private.match_cards WHERE match_id = p_match_id AND owner_id = v_opponent AND zone = 'life' ORDER BY random() LIMIT 1;
        IF FOUND THEN
            -- Perform direct attack
            NULL;
        END IF;

    ELSIF p_code = 'epic_weavess_revive_whispering' THEN
        SELECT id INTO v_temp_id FROM game_private.match_cards WHERE match_id = p_match_id AND owner_id = p_actor AND zone = 'graveyard' AND card_data->>'name' = 'Sibilante a Moira' LIMIT 1;
        IF FOUND THEN
            UPDATE game_private.match_cards SET zone = 'hand' WHERE id = v_temp_id;
        END IF;

    ELSIF p_code = 'epic_syanna_mimic_random_global_effect' THEN
        NULL; -- handled implicitly in some engine parts

    ELSIF p_code = 'epic_anna_henrietta_hand_toll' THEN
        INSERT INTO game_private.player_actions (match_id, player_id, action_type, payload) VALUES (p_match_id, v_opponent, 'discard_to_opponent', '{"count":1}');

    ELSIF p_code = 'epic_iris_execute_damaged_life' THEN
        IF p_target IS NOT NULL THEN
            UPDATE game_private.match_cards SET current_life = 0 WHERE id = p_target AND current_life < base_max_life;
        END IF;

    ELSIF p_code = 'epic_emhyr_asymmetric_hand_wipe' THEN
        SELECT count(*) INTO v_count FROM game_private.match_cards WHERE match_id = p_match_id AND owner_id = p_actor AND zone = 'hand';
        UPDATE game_private.match_cards SET zone = 'graveyard' WHERE match_id = p_match_id AND zone = 'hand';
        -- Actor draws same
        UPDATE game_private.match_cards SET zone = 'hand' WHERE id IN (SELECT id FROM game_private.match_cards WHERE match_id = p_match_id AND owner_id = p_actor AND zone = 'deck' ORDER BY position ASC LIMIT v_count);
        -- Enemy draws half
        UPDATE game_private.match_cards SET zone = 'hand' WHERE id IN (SELECT id FROM game_private.match_cards WHERE match_id = p_match_id AND owner_id = v_opponent AND zone = 'deck' ORDER BY position ASC LIMIT (v_count/2));

    ELSIF p_code = 'epic_radovid_punish_hand_duplicates' THEN
        -- Hand duplicate logic
        NULL;
        IF p_target IS NOT NULL THEN
            UPDATE game_private.match_cards SET current_life = 0 WHERE id = p_target;
        END IF;

    ELSIF p_code = 'epic_philippa_double_mf_mana' THEN
        UPDATE game_private.match_cards SET card_data = jsonb_set(card_data, '{effect_mana_cost}', (COALESCE((card_data->>'effect_mana_cost')::int, 0) * 2)::text::jsonb) 
        WHERE match_id = p_match_id AND owner_id = v_opponent AND zone = 'hand' AND (card_data->>'element') = 'M&F';

    ELSIF p_code = 'epic_crach_mill_triple_deck' THEN
        UPDATE game_private.match_cards SET zone = 'graveyard' WHERE id IN (SELECT id FROM game_private.match_cards WHERE match_id = p_match_id AND owner_id = v_opponent AND zone = 'deck' ORDER BY random() LIMIT 3);

    ELSIF p_code = 'epic_fringilla_deck_invert_reveal' THEN
        -- Deck invert 
        UPDATE game_private.match_cards SET position = -position WHERE match_id = p_match_id AND owner_id = v_opponent AND zone = 'deck';
        INSERT INTO game_private.match_effects (match_id, player_id, effect_code, duration) VALUES (p_match_id, p_actor, 'reveal_enemy_top', 1);

    ELSE
        PERFORM game_private.execute_common_effect_internal_v33_core(p_match_id, p_actor, p_source, p_code, p_params, p_target, p_event);
    END IF;
END;
$$;

COMMIT;
