-- Migration to implement the Laboratório Ofieri card testing tables and RPC functions
CREATE TABLE IF NOT EXISTS public.user_card_lab_rewards (
    user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    card_id uuid NOT NULL REFERENCES public.cards(id) ON DELETE CASCADE,
    claimed_at timestamp with time zone DEFAULT now() NOT NULL,
    PRIMARY KEY (user_id, card_id)
);

ALTER TABLE public.user_card_lab_rewards ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Allow users to read their own lab rewards"
    ON public.user_card_lab_rewards
    FOR SELECT
    TO authenticated
    USING (auth.uid() = user_id);

CREATE OR REPLACE FUNCTION public.claim_lab_reward(p_card_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_user_id uuid;
    v_already_claimed boolean := false;
BEGIN
    v_user_id := auth.uid();
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'User not authenticated';
    END IF;

    IF NOT EXISTS(SELECT 1 FROM public.cards WHERE id = p_card_id) THEN
        RAISE EXCEPTION 'Card does not exist';
    END IF;

    SELECT EXISTS(
        SELECT 1 FROM public.user_card_lab_rewards 
        WHERE user_id = v_user_id AND card_id = p_card_id
    ) INTO v_already_claimed;

    IF v_already_claimed THEN
        RETURN jsonb_build_object(
            'success', true,
            'reward', 0,
            'first_time', false
        );
    ELSE
        INSERT INTO public.user_card_lab_rewards(user_id, card_id, claimed_at)
        VALUES(v_user_id, p_card_id, now());

        INSERT INTO public.player_wallets (user_id, coins, updated_at)
        VALUES (v_user_id, 25, now())
        ON CONFLICT (user_id) 
        DO UPDATE SET coins = public.player_wallets.coins + EXCLUDED.coins, updated_at = now();

        RETURN jsonb_build_object(
            'success', true,
            'reward', 25,
            'first_time', true
        );
    END IF;
END;
$$;

CREATE OR REPLACE FUNCTION public.get_user_claimed_lab_cards()
RETURNS uuid[]
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_user_id uuid;
    v_res uuid[];
BEGIN
    v_user_id := auth.uid();
    IF v_user_id IS NULL THEN
        RETURN '{}'::uuid[];
    END IF;

    SELECT array_agg(card_id) INTO v_res
    FROM public.user_card_lab_rewards
    WHERE user_id = v_user_id;

    RETURN coalesce(v_res, '{}'::uuid[]);
END;
$$;

CREATE OR REPLACE FUNCTION public.start_lab_match(p_test_card_id uuid)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_match_id uuid;
    v_user_id uuid := game_private.require_authenticated();
    v_card_record record;
    v_mdc_id uuid;
BEGIN
    SELECT * INTO v_card_record FROM public.cards WHERE id = p_test_card_id;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Card not found';
    END IF;

    SELECT start_training_match('SYSTEM_GENERATED') INTO v_match_id;

    SELECT id INTO v_mdc_id 
    FROM public.match_cards 
    WHERE match_id = v_match_id AND owner_user_id = v_user_id 
    LIMIT 1;

    UPDATE public.match_deck_cards mdc
    SET 
        source_card_id = v_card_record.id,
        card_version = v_card_record.version,
        card_name = v_card_record.name,
        image_url = coalesce(v_card_record.image_url, ''),
        element = coalesce(v_card_record.element, 'Neutro'),
        rarity = v_card_record.rarity,
        card_type = v_card_record.card_type,
        is_golden = v_card_record.is_golden,
        base_power = coalesce(v_card_record.base_power, 0),
        base_max_life = coalesce(v_card_record.base_max_life, 0),
        effect_mana_cost = coalesce(v_card_record.effect_mana_cost, 0),
        effect_definition = coalesce(
            (select jsonb_agg(jsonb_build_object('effect_order', ce.effect_order, 'trigger_type', ce.trigger_type, 'effect_code', ce.effect_code, 'target_mode', ce.target_mode, 'parameters', ce.parameters, 'priority', ce.priority, 'is_reaction', ce.is_reaction, 'once_per_turn', ce.once_per_turn) order by ce.effect_order) 
             from public.card_effects ce 
             where ce.card_id = v_card_record.id and ce.is_active = true), 
            '[]'::jsonb
        )
    WHERE id = (SELECT match_deck_card_id FROM public.match_cards WHERE id = v_mdc_id);

    UPDATE public.match_cards
    SET 
        source_card_id = v_card_record.id,
        zone = 'hand',
        zone_position = 99,
        is_face_up = true,
        base_power = coalesce(v_card_record.base_power, 0),
        base_max_life = coalesce(v_card_record.base_max_life, 0),
        current_power = coalesce(v_card_record.base_power, 0),
        maximum_power = coalesce(v_card_record.base_power, 0),
        current_life = coalesce(v_card_record.base_max_life, 0),
        maximum_life = coalesce(v_card_record.base_max_life, 0)
    WHERE id = v_mdc_id;

    UPDATE public.match_players 
    SET mana_available = 15, mana_snapshot = 15 
    WHERE match_id = v_match_id AND user_id = v_user_id;

    RETURN v_match_id;
END;
$$;

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
    
    -- Tested card record
    v_test_card record;
    
    -- Generic card templates
    v_generic_card record;
    v_bestiary_card record;
    v_witcher_card record;
    
    v_mdc_id uuid;
BEGIN
    -- Get active rule version
    SELECT id INTO v_rule_id FROM public.game_rule_versions WHERE is_active = true LIMIT 1;

    -- Fetch the tested card
    SELECT * INTO v_test_card FROM public.cards WHERE id = p_test_card_id;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Tested card not found';
    END IF;

    -- Fetch some generic templates
    SELECT * INTO v_generic_card FROM public.cards WHERE is_active = true AND rarity = 'common' AND id <> p_test_card_id LIMIT 1;
    
    SELECT * INTO v_bestiary_card FROM public.cards WHERE is_active = true AND element = 'Bestiário' AND id <> p_test_card_id LIMIT 1;
    IF v_bestiary_card.id IS NULL THEN
        v_bestiary_card := v_generic_card;
    END IF;
    
    SELECT * INTO v_witcher_card FROM public.cards WHERE is_active = true AND element = 'Witcher' AND id <> p_test_card_id LIMIT 1;
    IF v_witcher_card.id IS NULL THEN
        v_witcher_card := v_generic_card;
    END IF;

    -- 1. Create the match directly 'in_progress' at turn 1, active player is the user, turn_action state
    INSERT INTO public.matches(
        rule_version_id, match_type, created_by,
        requires_bans, is_private, status, current_turn, active_player_id, engine_state, state_version
    )
    VALUES (
        v_rule_id, 'training', v_user_id,
        false, true, 'in_progress', 1, v_user_id, 'turn_action', 1
    )
    RETURNING id INTO v_match_id;

    -- 2. Insert match_players with 10 mana
    INSERT INTO public.match_players(match_id, user_id, player_number, passed_turn, setup_finished, mana_available, mana_snapshot)
    VALUES 
        (v_match_id, v_user_id, 1, false, true, 10, 10),
        (v_match_id, v_bot_id, 2, false, true, 10, 10);

    -- 3. Create public state
    INSERT INTO public.match_public_states(
        match_id, player1_user_id, player1_username, player2_user_id, player2_username,
        player1_hand_count, player2_hand_count, player1_deck_count, player2_deck_count,
        player1_graveyard_count, player2_graveyard_count, player1_life_remaining, player2_life_remaining,
        player1_mana_available, player2_mana_available
    )
    SELECT v_match_id, p1.id, p1.username, p2.id, p2.username,
           3, 0, 15, 15,
           0, 0, 3, 3,
           10, 10
    FROM public.profiles p1, public.profiles p2
    WHERE p1.id = v_user_id AND p2.id = v_bot_id;

    -- 4. Create decks
    INSERT INTO public.match_decks(match_id, user_id, total_cards, golden_cards_count)
    VALUES (v_match_id, v_user_id, 22, 1)
    RETURNING id INTO v_player_match_deck_id;

    INSERT INTO public.match_decks(match_id, user_id, total_cards, golden_cards_count)
    VALUES (v_match_id, v_bot_id, 20, 1)
    RETURNING id INTO v_bot_match_deck_id;

    -- 5. Helper function or loop to insert match_deck_cards and match_cards
    
    -- Player Hand: Tested card
    INSERT INTO public.match_deck_cards(
        match_deck_id, source_card_id, card_version, card_name, image_url, element, rarity, card_type, is_golden, base_power, base_max_life, effect_mana_cost, tier, leader_cooldown, effect_definition, copy_number
    ) VALUES (
        v_player_match_deck_id, v_test_card.id, coalesce(v_test_card.version, 1), v_test_card.name, coalesce(v_test_card.image_url, ''), coalesce(v_test_card.element, 'Neutro'), v_test_card.rarity, v_test_card.card_type, v_test_card.is_golden, coalesce(v_test_card.base_power, 0), coalesce(v_test_card.base_max_life, 0), coalesce(v_test_card.effect_mana_cost, 0), 1, coalesce(v_test_card.leader_cooldown, 0),
        coalesce((select jsonb_agg(jsonb_build_object('effect_order', ce.effect_order, 'trigger_type', ce.trigger_type, 'effect_code', ce.effect_code, 'target_mode', ce.target_mode, 'parameters', ce.parameters, 'priority', ce.priority, 'is_reaction', ce.is_reaction, 'once_per_turn', ce.once_per_turn) order by ce.effect_order) from public.card_effects ce where ce.card_id = v_test_card.id and ce.is_active = true), '[]'::jsonb), 1
    ) RETURNING id INTO v_mdc_id;

    INSERT INTO public.match_cards(match_id, owner_user_id, controller_user_id, match_deck_card_id, source_card_id, zone, zone_position, is_face_up, base_power, base_max_life, current_power, maximum_power, current_life, maximum_life)
    VALUES (v_match_id, v_user_id, v_user_id, v_mdc_id, v_test_card.id, 'hand', 1, true, v_test_card.base_power, v_test_card.base_max_life, v_test_card.base_power, v_test_card.base_power, v_test_card.base_max_life, v_test_card.base_max_life);

    -- Player Hand: 2 generic cards
    FOR i IN 1..2 LOOP
        INSERT INTO public.match_deck_cards(
            match_deck_id, source_card_id, card_version, card_name, image_url, element, rarity, card_type, is_golden, base_power, base_max_life, effect_mana_cost, tier, leader_cooldown, effect_definition, copy_number
        ) VALUES (
            v_player_match_deck_id, v_generic_card.id, coalesce(v_generic_card.version, 1), v_generic_card.name, coalesce(v_generic_card.image_url, ''), coalesce(v_generic_card.element, 'Neutro'), v_generic_card.rarity, v_generic_card.card_type, v_generic_card.is_golden, coalesce(v_generic_card.base_power, 0), coalesce(v_generic_card.base_max_life, 0), coalesce(v_generic_card.effect_mana_cost, 0), 1, coalesce(v_generic_card.leader_cooldown, 0), '[]'::jsonb, 1
        ) RETURNING id INTO v_mdc_id;

        INSERT INTO public.match_cards(match_id, owner_user_id, controller_user_id, match_deck_card_id, source_card_id, zone, zone_position, is_face_up, base_power, base_max_life, current_power, maximum_power, current_life, maximum_life)
        VALUES (v_match_id, v_user_id, v_user_id, v_mdc_id, v_generic_card.id, 'hand', i + 1, true, v_generic_card.base_power, v_generic_card.base_max_life, v_generic_card.base_power, v_generic_card.base_power, v_generic_card.base_max_life, v_generic_card.base_max_life);
    END LOOP;

    -- Player Field: 3 life cards
    FOR i IN 1..3 LOOP
        INSERT INTO public.match_deck_cards(
            match_deck_id, source_card_id, card_version, card_name, image_url, element, rarity, card_type, is_golden, base_power, base_max_life, effect_mana_cost, tier, leader_cooldown, effect_definition, copy_number
        ) VALUES (
            v_player_match_deck_id, v_generic_card.id, coalesce(v_generic_card.version, 1), v_generic_card.name, coalesce(v_generic_card.image_url, ''), coalesce(v_generic_card.element, 'Neutro'), v_generic_card.rarity, v_generic_card.card_type, v_generic_card.is_golden, coalesce(v_generic_card.base_power, 0), coalesce(v_generic_card.base_max_life, 0), coalesce(v_generic_card.effect_mana_cost, 0), 1, coalesce(v_generic_card.leader_cooldown, 0), '[]'::jsonb, 1
        ) RETURNING id INTO v_mdc_id;

        INSERT INTO public.match_cards(match_id, owner_user_id, controller_user_id, match_deck_card_id, source_card_id, zone, zone_position, is_face_up, base_power, base_max_life, current_power, maximum_power, current_life, maximum_life)
        VALUES (v_match_id, v_user_id, v_user_id, v_mdc_id, v_generic_card.id, 'life', i, true, v_generic_card.base_power, v_generic_card.base_max_life, v_generic_card.base_power, v_generic_card.base_power, v_generic_card.base_max_life, v_generic_card.base_max_life);
    END LOOP;

    -- Player Field: 1 reinforcement card
    INSERT INTO public.match_deck_cards(
        match_deck_id, source_card_id, card_version, card_name, image_url, element, rarity, card_type, is_golden, base_power, base_max_life, effect_mana_cost, tier, leader_cooldown, effect_definition, copy_number
    ) VALUES (
        v_player_match_deck_id, v_generic_card.id, coalesce(v_generic_card.version, 1), v_generic_card.name, coalesce(v_generic_card.image_url, ''), coalesce(v_generic_card.element, 'Neutro'), v_generic_card.rarity, v_generic_card.card_type, v_generic_card.is_golden, coalesce(v_generic_card.base_power, 0), coalesce(v_generic_card.base_max_life, 0), coalesce(v_generic_card.effect_mana_cost, 0), 1, coalesce(v_generic_card.leader_cooldown, 0), '[]'::jsonb, 1
    ) RETURNING id INTO v_mdc_id;

    INSERT INTO public.match_cards(match_id, owner_user_id, controller_user_id, match_deck_card_id, source_card_id, zone, zone_position, is_face_up, base_power, base_max_life, current_power, maximum_power, current_life, maximum_life)
    VALUES (v_match_id, v_user_id, v_user_id, v_mdc_id, v_generic_card.id, 'reinforcement', 1, true, v_generic_card.base_power, v_generic_card.base_max_life, v_generic_card.base_power, v_generic_card.base_power, v_generic_card.base_max_life, v_generic_card.base_max_life);

    -- Player Deck: 15 cards
    FOR i IN 1..15 LOOP
        INSERT INTO public.match_deck_cards(
            match_deck_id, source_card_id, card_version, card_name, image_url, element, rarity, card_type, is_golden, base_power, base_max_life, effect_mana_cost, tier, leader_cooldown, effect_definition, copy_number
        ) VALUES (
            v_player_match_deck_id, v_generic_card.id, coalesce(v_generic_card.version, 1), v_generic_card.name, coalesce(v_generic_card.image_url, ''), coalesce(v_generic_card.element, 'Neutro'), v_generic_card.rarity, v_generic_card.card_type, v_generic_card.is_golden, coalesce(v_generic_card.base_power, 0), coalesce(v_generic_card.base_max_life, 0), coalesce(v_generic_card.effect_mana_cost, 0), 1, coalesce(v_generic_card.leader_cooldown, 0), '[]'::jsonb, 1
        ) RETURNING id INTO v_mdc_id;

        INSERT INTO public.match_cards(match_id, owner_user_id, controller_user_id, match_deck_card_id, source_card_id, zone, zone_position, is_face_up, base_power, base_max_life, current_power, maximum_power, current_life, maximum_life)
        VALUES (v_match_id, v_user_id, v_user_id, v_mdc_id, v_generic_card.id, 'deck', i, false, v_generic_card.base_power, v_generic_card.base_max_life, v_generic_card.base_power, v_generic_card.base_power, v_generic_card.base_max_life, v_generic_card.base_max_life);
    END LOOP;

    -- Bot Field: 3 life cards
    FOR i IN 1..3 LOOP
        INSERT INTO public.match_deck_cards(
            match_deck_id, source_card_id, card_version, card_name, image_url, element, rarity, card_type, is_golden, base_power, base_max_life, effect_mana_cost, tier, leader_cooldown, effect_definition, copy_number
        ) VALUES (
            v_bot_match_deck_id, v_generic_card.id, coalesce(v_generic_card.version, 1), v_generic_card.name, coalesce(v_generic_card.image_url, ''), coalesce(v_generic_card.element, 'Neutro'), v_bot_match_deck_id, v_generic_card.rarity, v_generic_card.card_type, v_generic_card.is_golden, coalesce(v_generic_card.base_power, 0), coalesce(v_generic_card.base_max_life, 0), coalesce(v_generic_card.effect_mana_cost, 0), 1, coalesce(v_generic_card.leader_cooldown, 0), '[]'::jsonb, 1
        ) RETURNING id INTO v_mdc_id;

        INSERT INTO public.match_cards(match_id, owner_user_id, controller_user_id, match_deck_card_id, source_card_id, zone, zone_position, is_face_up, base_power, base_max_life, current_power, maximum_power, current_life, maximum_life)
        VALUES (v_match_id, v_bot_id, v_bot_id, v_mdc_id, v_generic_card.id, 'life', i, true, v_generic_card.base_power, v_generic_card.base_max_life, v_generic_card.base_power, v_generic_card.base_power, v_generic_card.base_max_life, v_generic_card.base_max_life);
    END LOOP;

    -- Bot Field: 2 reinforcement cards (Bestiary & Witcher)
    -- Reinforcement 1: Bestiary
    INSERT INTO public.match_deck_cards(
        match_deck_id, source_card_id, card_version, card_name, image_url, element, rarity, card_type, is_golden, base_power, base_max_life, effect_mana_cost, tier, leader_cooldown, effect_definition, copy_number
    ) VALUES (
        v_bot_match_deck_id, v_bestiary_card.id, coalesce(v_bestiary_card.version, 1), v_bestiary_card.name, coalesce(v_bestiary_card.image_url, ''), coalesce(v_bestiary_card.element, 'Neutro'), v_bestiary_card.rarity, v_bestiary_card.card_type, v_bestiary_card.is_golden, coalesce(v_bestiary_card.base_power, 0), coalesce(v_bestiary_card.base_max_life, 0), coalesce(v_bestiary_card.effect_mana_cost, 0), 1, coalesce(v_bestiary_card.leader_cooldown, 0), '[]'::jsonb, 1
    ) RETURNING id INTO v_mdc_id;

    INSERT INTO public.match_cards(match_id, owner_user_id, controller_user_id, match_deck_card_id, source_card_id, zone, zone_position, is_face_up, base_power, base_max_life, current_power, maximum_power, current_life, maximum_life)
    VALUES (v_match_id, v_bot_id, v_bot_id, v_mdc_id, v_bestiary_card.id, 'reinforcement', 1, true, v_bestiary_card.base_power, v_bestiary_card.base_max_life, v_bestiary_card.base_power, v_bestiary_card.base_power, v_bestiary_card.base_max_life, v_bestiary_card.base_max_life);

    -- Reinforcement 2: Witcher
    INSERT INTO public.match_deck_cards(
        match_deck_id, source_card_id, card_version, card_name, image_url, element, rarity, card_type, is_golden, base_power, base_max_life, effect_mana_cost, tier, leader_cooldown, effect_definition, copy_number
    ) VALUES (
        v_bot_match_deck_id, v_witcher_card.id, coalesce(v_witcher_card.version, 1), v_witcher_card.name, coalesce(v_witcher_card.image_url, ''), coalesce(v_witcher_card.element, 'Neutro'), v_witcher_card.rarity, v_witcher_card.card_type, v_witcher_card.is_golden, coalesce(v_witcher_card.base_power, 0), coalesce(v_witcher_card.base_max_life, 0), coalesce(v_witcher_card.effect_mana_cost, 0), 1, coalesce(v_witcher_card.leader_cooldown, 0), '[]'::jsonb, 1
    ) RETURNING id INTO v_mdc_id;

    INSERT INTO public.match_cards(match_id, owner_user_id, controller_user_id, match_deck_card_id, source_card_id, zone, zone_position, is_face_up, base_power, base_max_life, current_power, maximum_power, current_life, maximum_life)
    VALUES (v_match_id, v_bot_id, v_bot_id, v_mdc_id, v_witcher_card.id, 'reinforcement', 2, true, v_witcher_card.base_power, v_witcher_card.base_max_life, v_witcher_card.base_power, v_witcher_card.base_power, v_witcher_card.base_max_life, v_witcher_card.base_max_life);

    -- Bot Deck: 15 cards
    FOR i IN 1..15 LOOP
        INSERT INTO public.match_deck_cards(
            match_deck_id, source_card_id, card_version, card_name, image_url, element, rarity, card_type, is_golden, base_power, base_max_life, effect_mana_cost, tier, leader_cooldown, effect_definition, copy_number
        ) VALUES (
            v_bot_match_deck_id, v_generic_card.id, coalesce(v_generic_card.version, 1), v_generic_card.name, coalesce(v_generic_card.image_url, ''), coalesce(v_generic_card.element, 'Neutro'), v_generic_card.rarity, v_generic_card.card_type, v_generic_card.is_golden, coalesce(v_generic_card.base_power, 0), coalesce(v_generic_card.base_max_life, 0), coalesce(v_generic_card.effect_mana_cost, 0), 1, coalesce(v_generic_card.leader_cooldown, 0), '[]'::jsonb, 1
        ) RETURNING id INTO v_mdc_id;

        INSERT INTO public.match_cards(match_id, owner_user_id, controller_user_id, match_deck_card_id, source_card_id, zone, zone_position, is_face_up, base_power, base_max_life, current_power, maximum_power, current_life, maximum_life)
        VALUES (v_match_id, v_bot_id, v_bot_id, v_mdc_id, v_generic_card.id, 'deck', i, false, v_generic_card.base_power, v_generic_card.base_max_life, v_generic_card.base_power, v_generic_card.base_power, v_generic_card.base_max_life, v_generic_card.base_max_life);
    END LOOP;

    -- 6. Insert this match into training_matches so it triggers training bot logic
    INSERT INTO public.training_matches(match_id, created_at)
    VALUES (v_match_id, now());

    RETURN v_match_id;
END;
$$;
