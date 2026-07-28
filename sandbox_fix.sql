CREATE OR REPLACE FUNCTION public.start_lab_sandbox(p_test_card_id uuid)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_user_id uuid := game_private.require_authenticated();
    v_bot_id uuid := '00000000-0000-4000-8000-000000000071'::uuid;
    v_match_id uuid;
    v_rule_id uuid;
    v_player_match_deck_id uuid;
    v_bot_match_deck_id uuid;
    
    -- Card IDs
    v_test_id uuid := p_test_card_id;
    v_lobo_id uuid := 'c820fad3-30c4-4b32-9fd5-d13a092e2abc';
    v_shani_id uuid := '43f3a065-700b-42df-ab98-c40002b93930';
    v_barnabas_id uuid := '49ec623c-387c-48d7-bdfe-ecd83eb363e9';
    v_gargula_id uuid := '0b75b24c-138d-4b76-8596-638f5a534946';
    v_aracnomorfo_id uuid := '327b4510-c2e7-4c04-806e-4a11bce1c427';
    v_anabelle_id uuid := 'd021ec8f-eeae-4aa4-90ec-e8099a4c15d6';
    v_geralt_id uuid := '9f37cb0e-09a0-4117-a258-4a49f6d2540a';
    v_arnaghad_id uuid := 'ad411a4a-f9e4-43d1-8177-78285b08fa75';
BEGIN
    SELECT id INTO v_rule_id FROM public.game_rule_versions WHERE is_active = true LIMIT 1;
    IF NOT EXISTS(SELECT 1 FROM public.cards WHERE id = p_test_card_id) THEN
        RAISE EXCEPTION 'Tested card not found';
    END IF;

    -- 1. Create match
    INSERT INTO public.matches(
        rule_version_id, match_type, created_by,
        requires_bans, is_private, status, current_turn, active_player_id, engine_state, state_version
    )
    VALUES (
        v_rule_id, 'training', v_user_id,
        false, true, 'in_progress', 9, v_user_id, 'turn_action', 1
    )
    RETURNING id INTO v_match_id;

    -- 2. Players
    INSERT INTO public.match_players(match_id, user_id, player_number, passed_turn, setup_finished, mana_available, mana_snapshot)
    VALUES 
        (v_match_id, v_user_id, 1, false, true, 10, 10),
        (v_match_id, v_bot_id, 2, false, true, 10, 10);

    -- 3. Decks
    INSERT INTO public.match_decks(match_id, user_id, total_cards, golden_cards_count)
    VALUES (v_match_id, v_user_id, 22, 1) RETURNING id INTO v_player_match_deck_id;

    INSERT INTO public.match_decks(match_id, user_id, total_cards, golden_cards_count)
    VALUES (v_match_id, v_bot_id, 20, 1) RETURNING id INTO v_bot_match_deck_id;

    -- 4. Public state
    INSERT INTO public.match_public_states(match_id, player1_user_id, player1_username, player2_user_id, player2_username, player1_hand_count, player2_hand_count, player1_deck_count, player2_deck_count, player1_graveyard_count, player2_graveyard_count, player1_life_remaining, player2_life_remaining, player1_mana_available, player2_mana_available)
    SELECT v_match_id, p1.id, p1.username, p2.id, p2.username, 4, 3, 10, 10, 5, 0, 3, 3, 10, 10 FROM public.profiles p1, public.profiles p2 WHERE p1.id = v_user_id AND p2.id = v_bot_id;

    -- 5. Helper table for direct insert
    CREATE TEMP TABLE tmp_sandbox_cards (
        idx serial,
        owner_id uuid,
        deck_id uuid,
        card_id uuid,
        zone text,
        pos integer,
        face_up boolean,
        c_power integer,
        c_life integer
    ) ON COMMIT DROP;

    INSERT INTO tmp_sandbox_cards (owner_id, deck_id, card_id, zone, pos, face_up, c_power, c_life) VALUES
    -- PLAYER 1
    (v_user_id, v_player_match_deck_id, v_test_id, 'hand', 1, true, null, null),
    (v_user_id, v_player_match_deck_id, v_lobo_id, 'hand', 2, true, null, null),
    (v_user_id, v_player_match_deck_id, v_lobo_id, 'hand', 3, true, null, null),
    (v_user_id, v_player_match_deck_id, v_lobo_id, 'hand', 4, true, null, null),
    (v_user_id, v_player_match_deck_id, v_shani_id, 'life', 1, true, null, 1000),
    (v_user_id, v_player_match_deck_id, v_barnabas_id, 'life', 2, true, null, null),
    (v_user_id, v_player_match_deck_id, v_barnabas_id, 'life', 3, true, null, null),
    (v_user_id, v_player_match_deck_id, v_lobo_id, 'reinforcement', 1, true, null, null),
    (v_user_id, v_player_match_deck_id, v_lobo_id, 'graveyard', 1, false, null, null),
    (v_user_id, v_player_match_deck_id, v_lobo_id, 'graveyard', 2, false, null, null),
    (v_user_id, v_player_match_deck_id, v_lobo_id, 'graveyard', 3, false, null, null),
    (v_user_id, v_player_match_deck_id, v_lobo_id, 'graveyard', 4, false, null, null),
    (v_user_id, v_player_match_deck_id, v_lobo_id, 'graveyard', 5, false, null, null),
    (v_user_id, v_player_match_deck_id, v_lobo_id, 'deck', 1, false, null, null),
    (v_user_id, v_player_match_deck_id, v_lobo_id, 'deck', 2, false, null, null),
    (v_user_id, v_player_match_deck_id, v_lobo_id, 'deck', 3, false, null, null),
    (v_user_id, v_player_match_deck_id, v_lobo_id, 'deck', 4, false, null, null),
    (v_user_id, v_player_match_deck_id, v_lobo_id, 'deck', 5, false, null, null),
    (v_user_id, v_player_match_deck_id, v_lobo_id, 'deck', 6, false, null, null),
    (v_user_id, v_player_match_deck_id, v_lobo_id, 'deck', 7, false, null, null),
    (v_user_id, v_player_match_deck_id, v_lobo_id, 'deck', 8, false, null, null),
    (v_user_id, v_player_match_deck_id, v_lobo_id, 'deck', 9, false, null, null),
    (v_user_id, v_player_match_deck_id, v_lobo_id, 'deck', 10, false, null, null),
    
    -- BOT
    (v_bot_id, v_bot_match_deck_id, v_anabelle_id, 'hand', 1, true, 2000, 2500),
    (v_bot_id, v_bot_match_deck_id, v_anabelle_id, 'hand', 2, true, 2000, 2500),
    (v_bot_id, v_bot_match_deck_id, v_anabelle_id, 'hand', 3, true, 2000, 2500),
    (v_bot_id, v_bot_match_deck_id, v_barnabas_id, 'life', 1, true, null, null),
    (v_bot_id, v_bot_match_deck_id, v_barnabas_id, 'life', 2, true, null, null),
    (v_bot_id, v_bot_match_deck_id, v_barnabas_id, 'life', 3, true, null, null),
    (v_bot_id, v_bot_match_deck_id, v_aracnomorfo_id, 'reinforcement', 1, true, null, null),
    (v_bot_id, v_bot_match_deck_id, v_arnaghad_id, 'reinforcement', 2, true, null, null),
    (v_bot_id, v_bot_match_deck_id, v_lobo_id, 'deck', 1, false, null, null),
    (v_bot_id, v_bot_match_deck_id, v_lobo_id, 'deck', 2, false, null, null),
    (v_bot_id, v_bot_match_deck_id, v_lobo_id, 'deck', 3, false, null, null),
    (v_bot_id, v_bot_match_deck_id, v_lobo_id, 'deck', 4, false, null, null),
    (v_bot_id, v_bot_match_deck_id, v_lobo_id, 'deck', 5, false, null, null),
    (v_bot_id, v_bot_match_deck_id, v_lobo_id, 'deck', 6, false, null, null),
    (v_bot_id, v_bot_match_deck_id, v_aracnomorfo_id, 'deck', 7, false, null, null),
    (v_bot_id, v_bot_match_deck_id, v_aracnomorfo_id, 'deck', 8, false, null, null),
    (v_bot_id, v_bot_match_deck_id, v_aracnomorfo_id, 'deck', 9, false, null, null),
    (v_bot_id, v_bot_match_deck_id, v_geralt_id, 'deck', 10, false, null, null);

    -- DIRECT INSERT match_deck_cards
    WITH inserted_mdc AS (
        INSERT INTO public.match_deck_cards(
            match_deck_id, source_card_id, card_version, card_name, image_url, element, rarity, card_type, is_golden, base_power, base_max_life, effect_mana_cost, tier, leader_cooldown, effect_definition, copy_number
        )
        SELECT 
            t.deck_id, c.id, coalesce(c.version, 1), c.name, coalesce(c.image_url, ''), coalesce(c.element, 'Neutro'), c.rarity, c.card_type, c.is_golden, coalesce(t.c_power, c.base_power, 0), coalesce(t.c_life, c.base_max_life, 0), coalesce(c.effect_mana_cost, 0), 1, 0,
            coalesce((select jsonb_agg(jsonb_build_object('effect_order', ce.effect_order, 'trigger_type', ce.trigger_type, 'effect_code', ce.effect_code, 'target_mode', ce.target_mode, 'parameters', ce.parameters, 'priority', ce.priority, 'is_reaction', ce.is_reaction, 'once_per_turn', ce.once_per_turn) order by ce.effect_order) from public.card_effects ce where ce.card_id = c.id and ce.is_active = true), '[]'::jsonb), 1
        FROM tmp_sandbox_cards t
        JOIN public.cards c ON c.id = t.card_id
        ORDER BY t.idx
        RETURNING id, match_deck_id, source_card_id
    ),
    -- DIRECT INSERT match_cards
    numbered_mdc AS (
        SELECT id, row_number() over() as rn FROM inserted_mdc
    ),
    numbered_tmp AS (
        SELECT *, row_number() over(order by idx) as rn FROM tmp_sandbox_cards
    )
    INSERT INTO public.match_cards(
        match_id, owner_user_id, controller_user_id, match_deck_card_id, source_card_id, zone, zone_position, is_face_up, base_power, base_max_life, current_power, maximum_power, current_life, maximum_life, is_revealed_to_owner, damage_taken_total, healing_received_total, can_attack, has_attacked_this_turn, is_destroyed, is_summoned, is_token, entered_zone_turn, metadata
    )
    SELECT 
        v_match_id, t.owner_id, t.owner_id, m.id, t.card_id, t.zone, t.pos, t.face_up, 
        coalesce(t.c_power, c.base_power, 0), coalesce(t.c_life, c.base_max_life, 0), 
        coalesce(t.c_power, c.base_power, 0), coalesce(t.c_power, c.base_power, 0), 
        coalesce(t.c_life, coalesce(t.c_power, c.base_max_life, 0)), coalesce(t.c_life, coalesce(t.c_power, c.base_max_life, 0)),
        false, 0, 0, false, false, false, false, false, 0, '{}'::jsonb
    FROM numbered_tmp t
    JOIN numbered_mdc m ON m.rn = t.rn
    JOIN public.cards c ON c.id = t.card_id;

    -- 6. Insert this match into training_matches
    INSERT INTO public.training_matches(match_id, human_user_id, bot_user_id, difficulty, created_at)
    VALUES (v_match_id, v_user_id, v_bot_id, 'normal', now());

    RETURN v_match_id;
END;
$$;
