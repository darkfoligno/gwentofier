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

CREATE OR REPLACE FUNCTION game_private.add_sandbox_card(
    p_match_id uuid,
    p_match_deck_id uuid,
    p_owner_id uuid,
    p_card public.cards,
    p_zone text,
    p_pos integer,
    p_face_up boolean,
    p_custom_power integer DEFAULT NULL,
    p_custom_max_life integer DEFAULT NULL,
    p_custom_current_life integer DEFAULT NULL
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_mdc_id uuid;
    v_base_power integer;
    v_base_max_life integer;
    v_current_life integer;
BEGIN
    v_base_power := coalesce(p_custom_power, p_card.base_power, 0);
    v_base_max_life := coalesce(p_custom_max_life, p_card.base_max_life, 0);
    v_current_life := coalesce(p_custom_current_life, v_base_max_life);

    INSERT INTO public.match_deck_cards(
        match_deck_id, source_card_id, card_version, card_name, image_url, element, rarity, card_type, is_golden, base_power, base_max_life, effect_mana_cost, tier, leader_cooldown, effect_definition, copy_number
    ) VALUES (
        p_match_deck_id, p_card.id, coalesce(p_card.version, 1), p_card.name, coalesce(p_card.image_url, ''), coalesce(p_card.element, 'Neutro'), p_card.rarity, p_card.card_type, p_card.is_golden, v_base_power, v_base_max_life, coalesce(p_card.effect_mana_cost, 0), 1, 0,
        coalesce((select jsonb_agg(jsonb_build_object('effect_order', ce.effect_order, 'trigger_type', ce.trigger_type, 'effect_code', ce.effect_code, 'target_mode', ce.target_mode, 'parameters', ce.parameters, 'priority', ce.priority, 'is_reaction', ce.is_reaction, 'once_per_turn', ce.once_per_turn) order by ce.effect_order) from public.card_effects ce where ce.card_id = p_card.id and ce.is_active = true), '[]'::jsonb), 1
    ) RETURNING id INTO v_mdc_id;

    INSERT INTO public.match_cards(
        match_id, owner_user_id, controller_user_id, match_deck_card_id, source_card_id, zone, zone_position, is_face_up, base_power, base_max_life, current_power, maximum_power, current_life, maximum_life
    ) VALUES (
        p_match_id, p_owner_id, p_owner_id, v_mdc_id, p_card.id, p_zone, p_pos, p_face_up, v_base_power, v_base_max_life, v_base_power, v_base_power, v_current_life, v_base_max_life
    );

    RETURN v_mdc_id;
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
    
    -- Card records
    v_test_card public.cards;
    v_lobo_card public.cards;
    v_shani_card public.cards;
    v_barnabas_card public.cards;
    v_gargula_card public.cards;
    v_erinia_card public.cards;
    v_centopeia_card public.cards;
    v_aracnomorfo_card public.cards;
    v_anabelle_card public.cards;
    v_geralt_card public.cards;
    v_arnaghad_card public.cards;
    
    -- Loop helper
    v_mdc_id uuid;
    v_index integer;
BEGIN
    -- Get active rule version
    SELECT id INTO v_rule_id FROM public.game_rule_versions WHERE is_active = true LIMIT 1;

    -- Fetch the cards
    SELECT * INTO v_test_card FROM public.cards WHERE id = p_test_card_id;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Tested card not found';
    END IF;

    SELECT * INTO v_lobo_card FROM public.cards WHERE id = 'c820fad3-30c4-4b32-9fd5-d13a092e2abc';
    SELECT * INTO v_shani_card FROM public.cards WHERE id = '43f3a065-700b-42df-ab98-c40002b93930';
    SELECT * INTO v_barnabas_card FROM public.cards WHERE id = '49ec623c-387c-48d7-bdfe-ecd83eb363e9';
    SELECT * INTO v_gargula_card FROM public.cards WHERE id = '0b75b24c-138d-4b76-8596-638f5a534946';
    SELECT * INTO v_erinia_card FROM public.cards WHERE id = 'a0a82d31-2094-4256-92b9-8bc58c9ba311';
    SELECT * INTO v_centopeia_card FROM public.cards WHERE id = '65c75b95-f0d6-4e59-8c99-ed628653d45e';
    SELECT * INTO v_aracnomorfo_card FROM public.cards WHERE id = '327b4510-c2e7-4c04-806e-4a11bce1c427';
    SELECT * INTO v_anabelle_card FROM public.cards WHERE id = 'd021ec8f-eeae-4aa4-90ec-e8099a4c15d6';
    SELECT * INTO v_geralt_card FROM public.cards WHERE id = '9f37cb0e-09a0-4117-a258-4a49f6d2540a';
    SELECT * INTO v_arnaghad_card FROM public.cards WHERE id = 'ad411a4a-f9e4-43d1-8177-78285b08fa75';

    -- 1. Create the match directly 'in_progress' at Turno 9, active player is the user, turn_action state
    INSERT INTO public.matches(
        rule_version_id, match_type, created_by,
        requires_bans, is_private, status, current_turn, active_player_id, engine_state, state_version
    )
    VALUES (
        v_rule_id, 'training', v_user_id,
        false, true, 'in_progress', 9, v_user_id, 'turn_action', 1
    )
    RETURNING id INTO v_match_id;

    -- 2. Insert match_players with 10 mana
    INSERT INTO public.match_players(match_id, user_id, player_number, passed_turn, setup_finished, mana_available, mana_snapshot)
    VALUES 
        (v_match_id, v_user_id, 1, false, true, 10, 10),
        (v_match_id, v_bot_id, 2, false, true, 10, 10);

    -- 4. Create decks (Player deck will have 22 cards, Bot deck will have 20 cards)
    INSERT INTO public.match_decks(match_id, user_id, total_cards, golden_cards_count)
    VALUES (v_match_id, v_user_id, 22, 1)
    RETURNING id INTO v_player_match_deck_id;

    INSERT INTO public.match_decks(match_id, user_id, total_cards, golden_cards_count)
    VALUES (v_match_id, v_bot_id, 20, 1)
    RETURNING id INTO v_bot_match_deck_id;

    -- CASE 1: TOMIRA (66d0f400-141a-4591-9c1a-f4400be91bc9)
    IF p_test_card_id = '66d0f400-141a-4591-9c1a-f4400be91bc9' THEN
        -- Public state
        INSERT INTO public.match_public_states(match_id, player1_user_id, player1_username, player2_user_id, player2_username, player1_hand_count, player2_hand_count, player1_deck_count, player2_deck_count, player1_graveyard_count, player2_graveyard_count, player1_life_remaining, player2_life_remaining, player1_mana_available, player2_mana_available)
        SELECT v_match_id, p1.id, p1.username, p2.id, p2.username, 4, 3, 10, 12, 5, 0, 3, 3, 10, 10 FROM public.profiles p1, public.profiles p2 WHERE p1.id = v_user_id AND p2.id = v_bot_id;

        -- Player Hand: Tomira + 3x Lobo
        PERFORM game_private.add_sandbox_card(v_match_id, v_player_match_deck_id, v_user_id, v_test_card, 'hand', 1, true);
        PERFORM game_private.add_sandbox_card(v_match_id, v_player_match_deck_id, v_user_id, v_lobo_card, 'hand', 2, true);
        PERFORM game_private.add_sandbox_card(v_match_id, v_player_match_deck_id, v_user_id, v_lobo_card, 'hand', 3, true);
        PERFORM game_private.add_sandbox_card(v_match_id, v_player_match_deck_id, v_user_id, v_lobo_card, 'hand', 4, true);

        -- Player Life: Slot 1 Shani (Damaged 500/3000), Slot 2 Barnabas (2000), Slot 3 Barnabas (2000)
        PERFORM game_private.add_sandbox_card(v_match_id, v_player_match_deck_id, v_user_id, v_shani_card, 'life', 1, true, null, 3000, 500);
        PERFORM game_private.add_sandbox_card(v_match_id, v_player_match_deck_id, v_user_id, v_barnabas_card, 'life', 2, true, null, 2000, 2000);
        PERFORM game_private.add_sandbox_card(v_match_id, v_player_match_deck_id, v_user_id, v_barnabas_card, 'life', 3, true, null, 2000, 2000);

        -- Player Reinforcement: 1x Lobo
        PERFORM game_private.add_sandbox_card(v_match_id, v_player_match_deck_id, v_user_id, v_lobo_card, 'reinforcement', 1, true);

        -- Player Graveyard: 5x Lobo
        FOR v_index IN 1..5 LOOP
            PERFORM game_private.add_sandbox_card(v_match_id, v_player_match_deck_id, v_user_id, v_lobo_card, 'graveyard', v_index, false);
        END LOOP;

        -- Player Deck: 10x Lobo
        FOR v_index IN 1..10 LOOP
            PERFORM game_private.add_sandbox_card(v_match_id, v_player_match_deck_id, v_user_id, v_lobo_card, 'deck', v_index, false);
        END LOOP;

        -- Bot Life: 3x Barnabas (2000 HP)
        PERFORM game_private.add_sandbox_card(v_match_id, v_bot_match_deck_id, v_bot_id, v_barnabas_card, 'life', 1, true, null, 2000, 2000);
        PERFORM game_private.add_sandbox_card(v_match_id, v_bot_match_deck_id, v_bot_id, v_barnabas_card, 'life', 2, true, null, 2000, 2000);
        PERFORM game_private.add_sandbox_card(v_match_id, v_bot_match_deck_id, v_bot_id, v_barnabas_card, 'life', 3, true, null, 2000, 2000);

        -- Bot Reinforcements: 1x Gargula (2500 HP)
        PERFORM game_private.add_sandbox_card(v_match_id, v_bot_match_deck_id, v_bot_id, v_gargula_card, 'reinforcement', 1, true, null, 2500, 2500);

        -- Bot Hand: 3x Lobo
        PERFORM game_private.add_sandbox_card(v_match_id, v_bot_match_deck_id, v_bot_id, v_lobo_card, 'hand', 1, true);
        PERFORM game_private.add_sandbox_card(v_match_id, v_bot_match_deck_id, v_bot_id, v_lobo_card, 'hand', 2, true);
        PERFORM game_private.add_sandbox_card(v_match_id, v_bot_match_deck_id, v_bot_id, v_lobo_card, 'hand', 3, true);

        -- Bot Deck: 12x Lobo
        FOR v_index IN 1..12 LOOP
            PERFORM game_private.add_sandbox_card(v_match_id, v_bot_match_deck_id, v_bot_id, v_lobo_card, 'deck', v_index, false);
        END LOOP;

    -- CASE 2: PANTERA (cc6cc445-8484-470f-a71e-3e63dbf0008d)
    ELSIF p_test_card_id = 'cc6cc445-8484-470f-a71e-3e63dbf0008d' THEN
        -- Public state: Hand 5 vs 2
        INSERT INTO public.match_public_states(match_id, player1_user_id, player1_username, player2_user_id, player2_username, player1_hand_count, player2_hand_count, player1_deck_count, player2_deck_count, player1_graveyard_count, player2_graveyard_count, player1_life_remaining, player2_life_remaining, player1_mana_available, player2_mana_available)
        SELECT v_match_id, p1.id, p1.username, p2.id, p2.username, 4, 2, 10, 12, 5, 0, 3, 3, 10, 10 FROM public.profiles p1, public.profiles p2 WHERE p1.id = v_user_id AND p2.id = v_bot_id;

        -- Player Hand: Pantera + 3x Lobo
        PERFORM game_private.add_sandbox_card(v_match_id, v_player_match_deck_id, v_user_id, v_test_card, 'hand', 1, true);
        PERFORM game_private.add_sandbox_card(v_match_id, v_player_match_deck_id, v_user_id, v_lobo_card, 'hand', 2, true);
        PERFORM game_private.add_sandbox_card(v_match_id, v_player_match_deck_id, v_user_id, v_lobo_card, 'hand', 3, true);
        PERFORM game_private.add_sandbox_card(v_match_id, v_player_match_deck_id, v_user_id, v_lobo_card, 'hand', 4, true);

        -- Player Life: 3x Barnabas
        PERFORM game_private.add_sandbox_card(v_match_id, v_player_match_deck_id, v_user_id, v_barnabas_card, 'life', 1, true);
        PERFORM game_private.add_sandbox_card(v_match_id, v_player_match_deck_id, v_user_id, v_barnabas_card, 'life', 2, true);
        PERFORM game_private.add_sandbox_card(v_match_id, v_player_match_deck_id, v_user_id, v_barnabas_card, 'life', 3, true);

        -- Player Reinforcement: 1x Lobo
        PERFORM game_private.add_sandbox_card(v_match_id, v_player_match_deck_id, v_user_id, v_lobo_card, 'reinforcement', 1, true);

        -- Player Graveyard: 5x Lobo
        FOR v_index IN 1..5 LOOP
            PERFORM game_private.add_sandbox_card(v_match_id, v_player_match_deck_id, v_user_id, v_lobo_card, 'graveyard', v_index, false);
        END LOOP;

        -- Player Deck: 10x Lobo
        FOR v_index IN 1..10 LOOP
            PERFORM game_private.add_sandbox_card(v_match_id, v_player_match_deck_id, v_user_id, v_lobo_card, 'deck', v_index, false);
        END LOOP;

        -- Bot Life: 3x Barnabas
        PERFORM game_private.add_sandbox_card(v_match_id, v_bot_match_deck_id, v_bot_id, v_barnabas_card, 'life', 1, true);
        PERFORM game_private.add_sandbox_card(v_match_id, v_bot_match_deck_id, v_bot_id, v_barnabas_card, 'life', 2, true);
        PERFORM game_private.add_sandbox_card(v_match_id, v_bot_match_deck_id, v_bot_id, v_barnabas_card, 'life', 3, true);

        -- Bot Reinforcements: 2x Gargula (2500 HP each - defenders)
        PERFORM game_private.add_sandbox_card(v_match_id, v_bot_match_deck_id, v_bot_id, v_gargula_card, 'reinforcement', 1, true, null, 2500, 2500);
        PERFORM game_private.add_sandbox_card(v_match_id, v_bot_match_deck_id, v_bot_id, v_gargula_card, 'reinforcement', 2, true, null, 2500, 2500);

        -- Bot Hand: 2x Lobo (Mão total de 2)
        PERFORM game_private.add_sandbox_card(v_match_id, v_bot_match_deck_id, v_bot_id, v_lobo_card, 'hand', 1, true);
        PERFORM game_private.add_sandbox_card(v_match_id, v_bot_match_deck_id, v_bot_id, v_lobo_card, 'hand', 2, true);

        -- Bot Deck: 12x Lobo
        FOR v_index IN 1..12 LOOP
            PERFORM game_private.add_sandbox_card(v_match_id, v_bot_match_deck_id, v_bot_id, v_lobo_card, 'deck', v_index, false);
        END LOOP;

    -- CASE 3: DIJKISTRA (1c224f7d-52e8-4793-8a38-fe9f30d8bb3b)
    ELSIF p_test_card_id = '1c224f7d-52e8-4793-8a38-fe9f30d8bb3b' THEN
        -- Public state: Hand 3 vs 2
        INSERT INTO public.match_public_states(match_id, player1_user_id, player1_username, player2_user_id, player2_username, player1_hand_count, player2_hand_count, player1_deck_count, player2_deck_count, player1_graveyard_count, player2_graveyard_count, player1_life_remaining, player2_life_remaining, player1_mana_available, player2_mana_available)
        SELECT v_match_id, p1.id, p1.username, p2.id, p2.username, 3, 2, 5, 12, 5, 0, 3, 3, 10, 10 FROM public.profiles p1, public.profiles p2 WHERE p1.id = v_user_id AND p2.id = v_bot_id;

        -- Player Hand: Dijkistra + Erinia + 1 Lobo
        PERFORM game_private.add_sandbox_card(v_match_id, v_player_match_deck_id, v_user_id, v_test_card, 'hand', 1, true);
        PERFORM game_private.add_sandbox_card(v_match_id, v_player_match_deck_id, v_user_id, v_erinia_card, 'hand', 2, true);
        PERFORM game_private.add_sandbox_card(v_match_id, v_player_match_deck_id, v_user_id, v_lobo_card, 'hand', 3, true);

        -- Player Life: 3x Barnabas
        PERFORM game_private.add_sandbox_card(v_match_id, v_player_match_deck_id, v_user_id, v_barnabas_card, 'life', 1, true);
        PERFORM game_private.add_sandbox_card(v_match_id, v_player_match_deck_id, v_user_id, v_barnabas_card, 'life', 2, true);
        PERFORM game_private.add_sandbox_card(v_match_id, v_player_match_deck_id, v_user_id, v_barnabas_card, 'life', 3, true);

        -- Player Reinforcement: 1x Lobo
        PERFORM game_private.add_sandbox_card(v_match_id, v_player_match_deck_id, v_user_id, v_lobo_card, 'reinforcement', 1, true);

        -- Player Graveyard: 5x Lobo
        FOR v_index IN 1..5 LOOP
            PERFORM game_private.add_sandbox_card(v_match_id, v_player_match_deck_id, v_user_id, v_lobo_card, 'graveyard', v_index, false);
        END LOOP;

        -- Player Deck: 5x Lobo (common)
        FOR v_index IN 1..5 LOOP
            PERFORM game_private.add_sandbox_card(v_match_id, v_player_match_deck_id, v_user_id, v_lobo_card, 'deck', v_index, false);
        END LOOP;

        -- Bot Life: 3x Barnabas
        PERFORM game_private.add_sandbox_card(v_match_id, v_bot_match_deck_id, v_bot_id, v_barnabas_card, 'life', 1, true);
        PERFORM game_private.add_sandbox_card(v_match_id, v_bot_match_deck_id, v_bot_id, v_barnabas_card, 'life', 2, true);
        PERFORM game_private.add_sandbox_card(v_match_id, v_bot_match_deck_id, v_bot_id, v_barnabas_card, 'life', 3, true);

        -- Bot Reinforcements: 1x Gargula
        PERFORM game_private.add_sandbox_card(v_match_id, v_bot_match_deck_id, v_bot_id, v_gargula_card, 'reinforcement', 1, true);

        -- Bot Hand: 2x Lobo
        PERFORM game_private.add_sandbox_card(v_match_id, v_bot_match_deck_id, v_bot_id, v_lobo_card, 'hand', 1, true);
        PERFORM game_private.add_sandbox_card(v_match_id, v_bot_match_deck_id, v_bot_id, v_lobo_card, 'hand', 2, true);

        -- Bot Deck: 12x Lobo
        FOR v_index IN 1..12 LOOP
            PERFORM game_private.add_sandbox_card(v_match_id, v_bot_match_deck_id, v_bot_id, v_lobo_card, 'deck', v_index, false);
        END LOOP;

    -- CASE 4: ALPOR (e0ea21e2-0922-4632-951e-b8c67d950087)
    ELSIF p_test_card_id = 'e0ea21e2-0922-4632-951e-b8c67d950087' THEN
        -- Public state
        INSERT INTO public.match_public_states(match_id, player1_user_id, player1_username, player2_user_id, player2_username, player1_hand_count, player2_hand_count, player1_deck_count, player2_deck_count, player1_graveyard_count, player2_graveyard_count, player1_life_remaining, player2_life_remaining, player1_mana_available, player2_mana_available)
        SELECT v_match_id, p1.id, p1.username, p2.id, p2.username, 4, 3, 10, 12, 5, 0, 3, 3, 10, 10 FROM public.profiles p1, public.profiles p2 WHERE p1.id = v_user_id AND p2.id = v_bot_id;

        -- Player Hand: Alpor + 3x Lobo
        PERFORM game_private.add_sandbox_card(v_match_id, v_player_match_deck_id, v_user_id, v_test_card, 'hand', 1, true);
        PERFORM game_private.add_sandbox_card(v_match_id, v_player_match_deck_id, v_user_id, v_lobo_card, 'hand', 2, true);
        PERFORM game_private.add_sandbox_card(v_match_id, v_player_match_deck_id, v_user_id, v_lobo_card, 'hand', 3, true);
        PERFORM game_private.add_sandbox_card(v_match_id, v_player_match_deck_id, v_user_id, v_lobo_card, 'hand', 4, true);

        -- Player Life: 1x Shani (Damaged 1000/3000), 2x Barnabas (2000/2000)
        PERFORM game_private.add_sandbox_card(v_match_id, v_player_match_deck_id, v_user_id, v_shani_card, 'life', 1, true, null, 3000, 1000);
        PERFORM game_private.add_sandbox_card(v_match_id, v_player_match_deck_id, v_user_id, v_barnabas_card, 'life', 2, true, null, 2000, 2000);
        PERFORM game_private.add_sandbox_card(v_match_id, v_player_match_deck_id, v_user_id, v_barnabas_card, 'life', 3, true, null, 2000, 2000);

        -- Player Reinforcement: 1x Lobo
        PERFORM game_private.add_sandbox_card(v_match_id, v_player_match_deck_id, v_user_id, v_lobo_card, 'reinforcement', 1, true);

        -- Player Graveyard: 5x Lobo
        FOR v_index IN 1..5 LOOP
            PERFORM game_private.add_sandbox_card(v_match_id, v_player_match_deck_id, v_user_id, v_lobo_card, 'graveyard', v_index, false);
        END LOOP;

        -- Player Deck: 10x Lobo
        FOR v_index IN 1..10 LOOP
            PERFORM game_private.add_sandbox_card(v_match_id, v_player_match_deck_id, v_user_id, v_lobo_card, 'deck', v_index, false);
        END LOOP;

        -- Bot Life: 3x Barnabas
        PERFORM game_private.add_sandbox_card(v_match_id, v_bot_match_deck_id, v_bot_id, v_barnabas_card, 'life', 1, true);
        PERFORM game_private.add_sandbox_card(v_match_id, v_bot_match_deck_id, v_bot_id, v_barnabas_card, 'life', 2, true);
        PERFORM game_private.add_sandbox_card(v_match_id, v_bot_match_deck_id, v_bot_id, v_barnabas_card, 'life', 3, true);

        -- Bot Reinforcements: 1x Centopeia Gigante (3500 HP - high defense target)
        PERFORM game_private.add_sandbox_card(v_match_id, v_bot_match_deck_id, v_bot_id, v_centopeia_card, 'reinforcement', 1, true, null, 3500, 3500);

        -- Bot Hand: 3x Lobo
        PERFORM game_private.add_sandbox_card(v_match_id, v_bot_match_deck_id, v_bot_id, v_lobo_card, 'hand', 1, true);
        PERFORM game_private.add_sandbox_card(v_match_id, v_bot_match_deck_id, v_bot_id, v_lobo_card, 'hand', 2, true);
        PERFORM game_private.add_sandbox_card(v_match_id, v_bot_match_deck_id, v_bot_id, v_lobo_card, 'hand', 3, true);

        -- Bot Deck: 12x Lobo
        FOR v_index IN 1..12 LOOP
            PERFORM game_private.add_sandbox_card(v_match_id, v_bot_match_deck_id, v_bot_id, v_lobo_card, 'deck', v_index, false);
        END LOOP;

    -- CASE 5: BARÃO SANGUINÁRIO (cb068893-6065-4437-9cdc-0a23dba9d833)
    ELSIF p_test_card_id = 'cb068893-6065-4437-9cdc-0a23dba9d833' THEN
        -- Public state
        INSERT INTO public.match_public_states(match_id, player1_user_id, player1_username, player2_user_id, player2_username, player1_hand_count, player2_hand_count, player1_deck_count, player2_deck_count, player1_graveyard_count, player2_graveyard_count, player1_life_remaining, player2_life_remaining, player1_mana_available, player2_mana_available)
        SELECT v_match_id, p1.id, p1.username, p2.id, p2.username, 4, 3, 10, 12, 5, 0, 3, 3, 10, 10 FROM public.profiles p1, public.profiles p2 WHERE p1.id = v_user_id AND p2.id = v_bot_id;

        -- Player Hand: Barão Sanguinário + 3x Lobo
        PERFORM game_private.add_sandbox_card(v_match_id, v_player_match_deck_id, v_user_id, v_test_card, 'hand', 1, true);
        PERFORM game_private.add_sandbox_card(v_match_id, v_player_match_deck_id, v_user_id, v_lobo_card, 'hand', 2, true);
        PERFORM game_private.add_sandbox_card(v_match_id, v_player_match_deck_id, v_user_id, v_lobo_card, 'hand', 3, true);
        PERFORM game_private.add_sandbox_card(v_match_id, v_player_match_deck_id, v_user_id, v_lobo_card, 'hand', 4, true);

        -- Player Life: 3x Barnabas
        PERFORM game_private.add_sandbox_card(v_match_id, v_player_match_deck_id, v_user_id, v_barnabas_card, 'life', 1, true);
        PERFORM game_private.add_sandbox_card(v_match_id, v_player_match_deck_id, v_user_id, v_barnabas_card, 'life', 2, true);
        PERFORM game_private.add_sandbox_card(v_match_id, v_player_match_deck_id, v_user_id, v_barnabas_card, 'life', 3, true);

        -- Player Reinforcement: 1x Lobo
        PERFORM game_private.add_sandbox_card(v_match_id, v_player_match_deck_id, v_user_id, v_lobo_card, 'reinforcement', 1, true);

        -- Player Graveyard: 5x Lobo
        FOR v_index IN 1..5 LOOP
            PERFORM game_private.add_sandbox_card(v_match_id, v_player_match_deck_id, v_user_id, v_lobo_card, 'graveyard', v_index, false);
        END LOOP;

        -- Player Deck: 10x Lobo
        FOR v_index IN 1..10 LOOP
            PERFORM game_private.add_sandbox_card(v_match_id, v_player_match_deck_id, v_user_id, v_lobo_card, 'deck', v_index, false);
        END LOOP;

        -- Bot Life: 3x Barnabas
        PERFORM game_private.add_sandbox_card(v_match_id, v_bot_match_deck_id, v_bot_id, v_barnabas_card, 'life', 1, true);
        PERFORM game_private.add_sandbox_card(v_match_id, v_bot_match_deck_id, v_bot_id, v_barnabas_card, 'life', 2, true);
        PERFORM game_private.add_sandbox_card(v_match_id, v_bot_match_deck_id, v_bot_id, v_barnabas_card, 'life', 3, true);

        -- Bot Reinforcements: 2x Gargula
        PERFORM game_private.add_sandbox_card(v_match_id, v_bot_match_deck_id, v_bot_id, v_gargula_card, 'reinforcement', 1, true);
        PERFORM game_private.add_sandbox_card(v_match_id, v_bot_match_deck_id, v_bot_id, v_gargula_card, 'reinforcement', 2, true);

        -- Bot Hand: 3x Lobo
        PERFORM game_private.add_sandbox_card(v_match_id, v_bot_match_deck_id, v_bot_id, v_lobo_card, 'hand', 1, true);
        PERFORM game_private.add_sandbox_card(v_match_id, v_bot_match_deck_id, v_bot_id, v_lobo_card, 'hand', 2, true);
        PERFORM game_private.add_sandbox_card(v_match_id, v_bot_match_deck_id, v_bot_id, v_lobo_card, 'hand', 3, true);

        -- Bot Deck: 4x Aracnomorfo (Bestiario, ATK 3100) + 8x Lobo
        FOR v_index IN 1..4 LOOP
            PERFORM game_private.add_sandbox_card(v_match_id, v_bot_match_deck_id, v_bot_id, v_aracnomorfo_card, 'deck', v_index, false, 3100);
        END LOOP;
        FOR v_index IN 5..12 LOOP
            PERFORM game_private.add_sandbox_card(v_match_id, v_bot_match_deck_id, v_bot_id, v_lobo_card, 'deck', v_index, false);
        END LOOP;

    -- CASE 6: EKIMMU (be85f335-f299-4094-af13-ae6c7c0230a1)
    ELSIF p_test_card_id = 'be85f335-f299-4094-af13-ae6c7c0230a1' THEN
        -- Public state
        INSERT INTO public.match_public_states(match_id, player1_user_id, player1_username, player2_user_id, player2_username, player1_hand_count, player2_hand_count, player1_deck_count, player2_deck_count, player1_graveyard_count, player2_graveyard_count, player1_life_remaining, player2_life_remaining, player1_mana_available, player2_mana_available)
        SELECT v_match_id, p1.id, p1.username, p2.id, p2.username, 4, 3, 10, 12, 5, 0, 3, 3, 10, 10 FROM public.profiles p1, public.profiles p2 WHERE p1.id = v_user_id AND p2.id = v_bot_id;

        -- Player Hand: Ekimmu (ATK 3000, HP 4000) + 3x Lobo
        PERFORM game_private.add_sandbox_card(v_match_id, v_player_match_deck_id, v_user_id, v_test_card, 'hand', 1, true, 3000, 4000);
        PERFORM game_private.add_sandbox_card(v_match_id, v_player_match_deck_id, v_user_id, v_lobo_card, 'hand', 2, true);
        PERFORM game_private.add_sandbox_card(v_match_id, v_player_match_deck_id, v_user_id, v_lobo_card, 'hand', 3, true);
        PERFORM game_private.add_sandbox_card(v_match_id, v_player_match_deck_id, v_user_id, v_lobo_card, 'hand', 4, true);

        -- Player Life: 3x Barnabas
        PERFORM game_private.add_sandbox_card(v_match_id, v_player_match_deck_id, v_user_id, v_barnabas_card, 'life', 1, true);
        PERFORM game_private.add_sandbox_card(v_match_id, v_player_match_deck_id, v_user_id, v_barnabas_card, 'life', 2, true);
        PERFORM game_private.add_sandbox_card(v_match_id, v_player_match_deck_id, v_user_id, v_barnabas_card, 'life', 3, true);

        -- Player Reinforcement: 1x Lobo
        PERFORM game_private.add_sandbox_card(v_match_id, v_player_match_deck_id, v_user_id, v_lobo_card, 'reinforcement', 1, true);

        -- Player Graveyard: 5x Lobo
        FOR v_index IN 1..5 LOOP
            PERFORM game_private.add_sandbox_card(v_match_id, v_player_match_deck_id, v_user_id, v_lobo_card, 'graveyard', v_index, false);
        END LOOP;

        -- Player Deck: 10x Lobo
        FOR v_index IN 1..10 LOOP
            PERFORM game_private.add_sandbox_card(v_match_id, v_player_match_deck_id, v_user_id, v_lobo_card, 'deck', v_index, false);
        END LOOP;

        -- Bot Hand: 3x Anabelle (ATK 2000, HP 2500)
        PERFORM game_private.add_sandbox_card(v_match_id, v_bot_match_deck_id, v_bot_id, v_anabelle_card, 'hand', 1, true, 2000, 2500);
        PERFORM game_private.add_sandbox_card(v_match_id, v_bot_match_deck_id, v_bot_id, v_anabelle_card, 'hand', 2, true, 2000, 2500);
        PERFORM game_private.add_sandbox_card(v_match_id, v_bot_match_deck_id, v_bot_id, v_anabelle_card, 'hand', 3, true, 2000, 2500);

        -- Bot Life: 3x Barnabas
        PERFORM game_private.add_sandbox_card(v_match_id, v_bot_match_deck_id, v_bot_id, v_barnabas_card, 'life', 1, true);
        PERFORM game_private.add_sandbox_card(v_match_id, v_bot_match_deck_id, v_bot_id, v_barnabas_card, 'life', 2, true);
        PERFORM game_private.add_sandbox_card(v_match_id, v_bot_match_deck_id, v_bot_id, v_barnabas_card, 'life', 3, true);

        -- Bot Reinforcement: 1x Gargula
        PERFORM game_private.add_sandbox_card(v_match_id, v_bot_match_deck_id, v_bot_id, v_gargula_card, 'reinforcement', 1, true);

        -- Bot Deck: 12x Lobo
        FOR v_index IN 1..12 LOOP
            PERFORM game_private.add_sandbox_card(v_match_id, v_bot_match_deck_id, v_bot_id, v_lobo_card, 'deck', v_index, false);
        END LOOP;

    -- CASE 7: FEITIÇEIRA FRINGILLA (7b11c636-7ec8-46aa-917a-d47ff19b456f)
    ELSIF p_test_card_id = '7b11c636-7ec8-46aa-917a-d47ff19b456f' THEN
        -- Public state
        INSERT INTO public.match_public_states(match_id, player1_user_id, player1_username, player2_user_id, player2_username, player1_hand_count, player2_hand_count, player1_deck_count, player2_deck_count, player1_graveyard_count, player2_graveyard_count, player1_life_remaining, player2_life_remaining, player1_mana_available, player2_mana_available)
        SELECT v_match_id, p1.id, p1.username, p2.id, p2.username, 4, 3, 10, 5, 5, 0, 3, 3, 10, 10 FROM public.profiles p1, public.profiles p2 WHERE p1.id = v_user_id AND p2.id = v_bot_id;

        -- Player Hand: Fringilla + 3x Lobo
        PERFORM game_private.add_sandbox_card(v_match_id, v_player_match_deck_id, v_user_id, v_test_card, 'hand', 1, true);
        PERFORM game_private.add_sandbox_card(v_match_id, v_player_match_deck_id, v_user_id, v_lobo_card, 'hand', 2, true);
        PERFORM game_private.add_sandbox_card(v_match_id, v_player_match_deck_id, v_user_id, v_lobo_card, 'hand', 3, true);
        PERFORM game_private.add_sandbox_card(v_match_id, v_player_match_deck_id, v_user_id, v_lobo_card, 'hand', 4, true);

        -- Player Life: 3x Barnabas
        PERFORM game_private.add_sandbox_card(v_match_id, v_player_match_deck_id, v_user_id, v_barnabas_card, 'life', 1, true);
        PERFORM game_private.add_sandbox_card(v_match_id, v_player_match_deck_id, v_user_id, v_barnabas_card, 'life', 2, true);
        PERFORM game_private.add_sandbox_card(v_match_id, v_player_match_deck_id, v_user_id, v_barnabas_card, 'life', 3, true);

        -- Player Reinforcement: 1x Lobo
        PERFORM game_private.add_sandbox_card(v_match_id, v_player_match_deck_id, v_user_id, v_lobo_card, 'reinforcement', 1, true);

        -- Player Graveyard: 5x Lobo
        FOR v_index IN 1..5 LOOP
            PERFORM game_private.add_sandbox_card(v_match_id, v_player_match_deck_id, v_user_id, v_lobo_card, 'graveyard', v_index, false);
        END LOOP;

        -- Player Deck: 10x Lobo
        FOR v_index IN 1..10 LOOP
            PERFORM game_private.add_sandbox_card(v_match_id, v_player_match_deck_id, v_user_id, v_lobo_card, 'deck', v_index, false);
        END LOOP;

        -- Bot Life: 3x Barnabas
        PERFORM game_private.add_sandbox_card(v_match_id, v_bot_match_deck_id, v_bot_id, v_barnabas_card, 'life', 1, true);
        PERFORM game_private.add_sandbox_card(v_match_id, v_bot_match_deck_id, v_bot_id, v_barnabas_card, 'life', 2, true);
        PERFORM game_private.add_sandbox_card(v_match_id, v_bot_match_deck_id, v_bot_id, v_barnabas_card, 'life', 3, true);

        -- Bot Reinforcement: 1x Gargula
        PERFORM game_private.add_sandbox_card(v_match_id, v_bot_match_deck_id, v_bot_id, v_gargula_card, 'reinforcement', 1, true);

        -- Bot Hand: 3x Lobo
        PERFORM game_private.add_sandbox_card(v_match_id, v_bot_match_deck_id, v_bot_id, v_lobo_card, 'hand', 1, true);
        PERFORM game_private.add_sandbox_card(v_match_id, v_bot_match_deck_id, v_bot_id, v_lobo_card, 'hand', 2, true);
        PERFORM game_private.add_sandbox_card(v_match_id, v_bot_match_deck_id, v_bot_id, v_lobo_card, 'hand', 3, true);

        -- Bot Deck: 4x Lobo (pos 1..4) + 1x Geralt de Rivia (pos 5 - bottom)
        FOR v_index IN 1..4 LOOP
            PERFORM game_private.add_sandbox_card(v_match_id, v_bot_match_deck_id, v_bot_id, v_lobo_card, 'deck', v_index, false);
        END LOOP;
        PERFORM game_private.add_sandbox_card(v_match_id, v_bot_match_deck_id, v_bot_id, v_geralt_card, 'deck', 5, false);

    -- CASE 8: LISANDRO VANDERBASTER (a28fa8e8-ab19-4fc7-809d-b8246bf01652)
    ELSIF p_test_card_id = 'a28fa8e8-ab19-4fc7-809d-b8246bf01652' THEN
        -- Public state
        INSERT INTO public.match_public_states(match_id, player1_user_id, player1_username, player2_user_id, player2_username, player1_hand_count, player2_hand_count, player1_deck_count, player2_deck_count, player1_graveyard_count, player2_graveyard_count, player1_life_remaining, player2_life_remaining, player1_mana_available, player2_mana_available)
        SELECT v_match_id, p1.id, p1.username, p2.id, p2.username, 4, 3, 10, 12, 5, 0, 3, 3, 10, 10 FROM public.profiles p1, public.profiles p2 WHERE p1.id = v_user_id AND p2.id = v_bot_id;

        -- Player Hand: Lisandro (ATK: 3000) + 3x Lobo
        PERFORM game_private.add_sandbox_card(v_match_id, v_player_match_deck_id, v_user_id, v_test_card, 'hand', 1, true, 3000);
        PERFORM game_private.add_sandbox_card(v_match_id, v_player_match_deck_id, v_user_id, v_lobo_card, 'hand', 2, true);
        PERFORM game_private.add_sandbox_card(v_match_id, v_player_match_deck_id, v_user_id, v_lobo_card, 'hand', 3, true);
        PERFORM game_private.add_sandbox_card(v_match_id, v_player_match_deck_id, v_user_id, v_lobo_card, 'hand', 4, true);

        -- Player Life: 3x Barnabas
        PERFORM game_private.add_sandbox_card(v_match_id, v_player_match_deck_id, v_user_id, v_barnabas_card, 'life', 1, true);
        PERFORM game_private.add_sandbox_card(v_match_id, v_player_match_deck_id, v_user_id, v_barnabas_card, 'life', 2, true);
        PERFORM game_private.add_sandbox_card(v_match_id, v_player_match_deck_id, v_user_id, v_barnabas_card, 'life', 3, true);

        -- Player Reinforcement: 1x Lobo
        PERFORM game_private.add_sandbox_card(v_match_id, v_player_match_deck_id, v_user_id, v_lobo_card, 'reinforcement', 1, true);

        -- Player Graveyard: 5x Lobo
        FOR v_index IN 1..5 LOOP
            PERFORM game_private.add_sandbox_card(v_match_id, v_player_match_deck_id, v_user_id, v_lobo_card, 'graveyard', v_index, false);
        END LOOP;

        -- Player Deck: 10x Lobo
        FOR v_index IN 1..10 LOOP
            PERFORM game_private.add_sandbox_card(v_match_id, v_player_match_deck_id, v_user_id, v_lobo_card, 'deck', v_index, false);
        END LOOP;

        -- Bot Life: 3x Barnabas (2000 HP each - vulnerable to Lisandro 3000 ATK)
        PERFORM game_private.add_sandbox_card(v_match_id, v_bot_match_deck_id, v_bot_id, v_barnabas_card, 'life', 1, true, null, 2000, 2000);
        PERFORM game_private.add_sandbox_card(v_match_id, v_bot_match_deck_id, v_bot_id, v_barnabas_card, 'life', 2, true, null, 2000, 2000);
        PERFORM game_private.add_sandbox_card(v_match_id, v_bot_match_deck_id, v_bot_id, v_barnabas_card, 'life', 3, true, null, 2000, 2000);

        -- Bot Reinforcements: 2x Arnaghad (4000 HP each - blockers)
        PERFORM game_private.add_sandbox_card(v_match_id, v_bot_match_deck_id, v_bot_id, v_arnaghad_card, 'reinforcement', 1, true, null, 4000, 4000);
        PERFORM game_private.add_sandbox_card(v_match_id, v_bot_match_deck_id, v_bot_id, v_arnaghad_card, 'reinforcement', 2, true, null, 4000, 4000);

        -- Bot Hand: 3x Lobo
        PERFORM game_private.add_sandbox_card(v_match_id, v_bot_match_deck_id, v_bot_id, v_lobo_card, 'hand', 1, true);
        PERFORM game_private.add_sandbox_card(v_match_id, v_bot_match_deck_id, v_bot_id, v_lobo_card, 'hand', 2, true);
        PERFORM game_private.add_sandbox_card(v_match_id, v_bot_match_deck_id, v_bot_id, v_lobo_card, 'hand', 3, true);

        -- Bot Deck: 12x Lobo
        FOR v_index IN 1..12 LOOP
            PERFORM game_private.add_sandbox_card(v_match_id, v_bot_match_deck_id, v_bot_id, v_lobo_card, 'deck', v_index, false);
        END LOOP;

    -- CASE 9: GAUNTER O'DIMM (7258635f-0be9-47ba-8257-6c4ae95067f0)
    ELSIF p_test_card_id = '7258635f-0be9-47ba-8257-6c4ae95067f0' THEN
        -- Public state
        INSERT INTO public.match_public_states(match_id, player1_user_id, player1_username, player2_user_id, player2_username, player1_hand_count, player2_hand_count, player1_deck_count, player2_deck_count, player1_graveyard_count, player2_graveyard_count, player1_life_remaining, player2_life_remaining, player1_mana_available, player2_mana_available)
        SELECT v_match_id, p1.id, p1.username, p2.id, p2.username, 4, 3, 10, 12, 5, 0, 3, 3, 10, 10 FROM public.profiles p1, public.profiles p2 WHERE p1.id = v_user_id AND p2.id = v_bot_id;

        -- Player Hand: Gaunter + 3x Lobo
        PERFORM game_private.add_sandbox_card(v_match_id, v_player_match_deck_id, v_user_id, v_test_card, 'hand', 1, true);
        PERFORM game_private.add_sandbox_card(v_match_id, v_player_match_deck_id, v_user_id, v_lobo_card, 'hand', 2, true);
        PERFORM game_private.add_sandbox_card(v_match_id, v_player_match_deck_id, v_user_id, v_lobo_card, 'hand', 3, true);
        PERFORM game_private.add_sandbox_card(v_match_id, v_player_match_deck_id, v_user_id, v_lobo_card, 'hand', 4, true);

        -- Player Life: 3x Barnabas
        PERFORM game_private.add_sandbox_card(v_match_id, v_player_match_deck_id, v_user_id, v_barnabas_card, 'life', 1, true);
        PERFORM game_private.add_sandbox_card(v_match_id, v_player_match_deck_id, v_user_id, v_barnabas_card, 'life', 2, true);
        PERFORM game_private.add_sandbox_card(v_match_id, v_player_match_deck_id, v_user_id, v_barnabas_card, 'life', 3, true);

        -- Player Reinforcement: 1x Lobo
        PERFORM game_private.add_sandbox_card(v_match_id, v_player_match_deck_id, v_user_id, v_lobo_card, 'reinforcement', 1, true);

        -- Player Graveyard: 5x Lobo
        FOR v_index IN 1..5 LOOP
            PERFORM game_private.add_sandbox_card(v_match_id, v_player_match_deck_id, v_user_id, v_lobo_card, 'graveyard', v_index, false);
        END LOOP;

        -- Player Deck: 10x Lobo
        FOR v_index IN 1..10 LOOP
            PERFORM game_private.add_sandbox_card(v_match_id, v_player_match_deck_id, v_user_id, v_lobo_card, 'deck', v_index, false);
        END LOOP;

        -- Bot Life: 3x Anabelle (2500 HP each - full board)
        PERFORM game_private.add_sandbox_card(v_match_id, v_bot_match_deck_id, v_bot_id, v_anabelle_card, 'life', 1, true, null, 2500, 2500);
        PERFORM game_private.add_sandbox_card(v_match_id, v_bot_match_deck_id, v_bot_id, v_anabelle_card, 'life', 2, true, null, 2500, 2500);
        PERFORM game_private.add_sandbox_card(v_match_id, v_bot_match_deck_id, v_bot_id, v_anabelle_card, 'life', 3, true, null, 2500, 2500);

        -- Bot Reinforcements: 3x Gargula (2500 HP each - full board)
        PERFORM game_private.add_sandbox_card(v_match_id, v_bot_match_deck_id, v_bot_id, v_gargula_card, 'reinforcement', 1, true, null, 2500, 2500);
        PERFORM game_private.add_sandbox_card(v_match_id, v_bot_match_deck_id, v_bot_id, v_gargula_card, 'reinforcement', 2, true, null, 2500, 2500);
        PERFORM game_private.add_sandbox_card(v_match_id, v_bot_match_deck_id, v_bot_id, v_gargula_card, 'reinforcement', 3, true, null, 2500, 2500);

        -- Bot Hand: 3x Lobo
        PERFORM game_private.add_sandbox_card(v_match_id, v_bot_match_deck_id, v_bot_id, v_lobo_card, 'hand', 1, true);
        PERFORM game_private.add_sandbox_card(v_match_id, v_bot_match_deck_id, v_bot_id, v_lobo_card, 'hand', 2, true);
        PERFORM game_private.add_sandbox_card(v_match_id, v_bot_match_deck_id, v_bot_id, v_lobo_card, 'hand', 3, true);

        -- Bot Deck: 12x Lobo
        FOR v_index IN 1..12 LOOP
            PERFORM game_private.add_sandbox_card(v_match_id, v_bot_match_deck_id, v_bot_id, v_lobo_card, 'deck', v_index, false);
        END LOOP;

    -- CASE 10: DANDELION (44ea442e-cfb3-4cdb-a8b9-66fdc84b1ddd)
    ELSIF p_test_card_id = '44ea442e-cfb3-4cdb-a8b9-66fdc84b1ddd' THEN
        -- Public state
        INSERT INTO public.match_public_states(match_id, player1_user_id, player1_username, player2_user_id, player2_username, player1_hand_count, player2_hand_count, player1_deck_count, player2_deck_count, player1_graveyard_count, player2_graveyard_count, player1_life_remaining, player2_life_remaining, player1_mana_available, player2_mana_available)
        SELECT v_match_id, p1.id, p1.username, p2.id, p2.username, 4, 2, 10, 12, 5, 0, 3, 3, 10, 10 FROM public.profiles p1, public.profiles p2 WHERE p1.id = v_user_id AND p2.id = v_bot_id;

        -- Player Hand: Dandelion + 3x Lobo (Mana: 0, ATK: 1000 - weak cards)
        PERFORM game_private.add_sandbox_card(v_match_id, v_player_match_deck_id, v_user_id, v_test_card, 'hand', 1, true);
        PERFORM game_private.add_sandbox_card(v_match_id, v_player_match_deck_id, v_user_id, v_lobo_card, 'hand', 2, true);
        PERFORM game_private.add_sandbox_card(v_match_id, v_player_match_deck_id, v_user_id, v_lobo_card, 'hand', 3, true);
        PERFORM game_private.add_sandbox_card(v_match_id, v_player_match_deck_id, v_user_id, v_lobo_card, 'hand', 4, true);

        -- Player Life: 3x Barnabas
        PERFORM game_private.add_sandbox_card(v_match_id, v_player_match_deck_id, v_user_id, v_barnabas_card, 'life', 1, true);
        PERFORM game_private.add_sandbox_card(v_match_id, v_player_match_deck_id, v_user_id, v_barnabas_card, 'life', 2, true);
        PERFORM game_private.add_sandbox_card(v_match_id, v_player_match_deck_id, v_user_id, v_barnabas_card, 'life', 3, true);

        -- Player Reinforcement: 1x Lobo
        PERFORM game_private.add_sandbox_card(v_match_id, v_player_match_deck_id, v_user_id, v_lobo_card, 'reinforcement', 1, true);

        -- Player Graveyard: 5x Lobo
        FOR v_index IN 1..5 LOOP
            PERFORM game_private.add_sandbox_card(v_match_id, v_player_match_deck_id, v_user_id, v_lobo_card, 'graveyard', v_index, false);
        END LOOP;

        -- Player Deck: 10x Lobo
        FOR v_index IN 1..10 LOOP
            PERFORM game_private.add_sandbox_card(v_match_id, v_player_match_deck_id, v_user_id, v_lobo_card, 'deck', v_index, false);
        END LOOP;

        -- Bot Hand: 2x Geralt de Rivia (ATK: 5000, HP: 3000 - strong cards)
        PERFORM game_private.add_sandbox_card(v_match_id, v_bot_match_deck_id, v_bot_id, v_geralt_card, 'hand', 1, true, 5000, 3000);
        PERFORM game_private.add_sandbox_card(v_match_id, v_bot_match_deck_id, v_bot_id, v_geralt_card, 'hand', 2, true, 5000, 3000);

        -- Bot Life: 3x Barnabas
        PERFORM game_private.add_sandbox_card(v_match_id, v_bot_match_deck_id, v_bot_id, v_barnabas_card, 'life', 1, true);
        PERFORM game_private.add_sandbox_card(v_match_id, v_bot_match_deck_id, v_bot_id, v_barnabas_card, 'life', 2, true);
        PERFORM game_private.add_sandbox_card(v_match_id, v_bot_match_deck_id, v_bot_id, v_barnabas_card, 'life', 3, true);

        -- Bot Reinforcement: 1x Gargula
        PERFORM game_private.add_sandbox_card(v_match_id, v_bot_match_deck_id, v_bot_id, v_gargula_card, 'reinforcement', 1, true);

        -- Bot Deck: 12x Lobo
        FOR v_index IN 1..12 LOOP
            PERFORM game_private.add_sandbox_card(v_match_id, v_bot_match_deck_id, v_bot_id, v_lobo_card, 'deck', v_index, false);
        END LOOP;

    -- FALLBACK: Generic initialization
    ELSE
        -- Public state
        INSERT INTO public.match_public_states(match_id, player1_user_id, player1_username, player2_user_id, player2_username, player1_hand_count, player2_hand_count, player1_deck_count, player2_deck_count, player1_graveyard_count, player2_graveyard_count, player1_life_remaining, player2_life_remaining, player1_mana_available, player2_mana_available)
        SELECT v_match_id, p1.id, p1.username, p2.id, p2.username, 3, 3, 10, 12, 5, 0, 3, 3, 10, 10 FROM public.profiles p1, public.profiles p2 WHERE p1.id = v_user_id AND p2.id = v_bot_id;

        -- Player Hand: Tested card + 2x Lobo
        PERFORM game_private.add_sandbox_card(v_match_id, v_player_match_deck_id, v_user_id, v_test_card, 'hand', 1, true);
        PERFORM game_private.add_sandbox_card(v_match_id, v_player_match_deck_id, v_user_id, v_lobo_card, 'hand', 2, true);
        PERFORM game_private.add_sandbox_card(v_match_id, v_player_match_deck_id, v_user_id, v_lobo_card, 'hand', 3, true);

        -- Player Life: 3x Barnabas
        PERFORM game_private.add_sandbox_card(v_match_id, v_player_match_deck_id, v_user_id, v_barnabas_card, 'life', 1, true);
        PERFORM game_private.add_sandbox_card(v_match_id, v_player_match_deck_id, v_user_id, v_barnabas_card, 'life', 2, true);
        PERFORM game_private.add_sandbox_card(v_match_id, v_player_match_deck_id, v_user_id, v_barnabas_card, 'life', 3, true);

        -- Player Reinforcement: 1x Lobo
        PERFORM game_private.add_sandbox_card(v_match_id, v_player_match_deck_id, v_user_id, v_lobo_card, 'reinforcement', 1, true);

        -- Player Graveyard: 5x Lobo
        FOR v_index IN 1..5 LOOP
            PERFORM game_private.add_sandbox_card(v_match_id, v_player_match_deck_id, v_user_id, v_lobo_card, 'graveyard', v_index, false);
        END LOOP;

        -- Player Deck: 10x Lobo
        FOR v_index IN 1..10 LOOP
            PERFORM game_private.add_sandbox_card(v_match_id, v_player_match_deck_id, v_user_id, v_lobo_card, 'deck', v_index, false);
        END LOOP;

        -- Bot Life: 3x Barnabas
        PERFORM game_private.add_sandbox_card(v_match_id, v_bot_match_deck_id, v_bot_id, v_barnabas_card, 'life', 1, true);
        PERFORM game_private.add_sandbox_card(v_match_id, v_bot_match_deck_id, v_bot_id, v_barnabas_card, 'life', 2, true);
        PERFORM game_private.add_sandbox_card(v_match_id, v_bot_match_deck_id, v_bot_id, v_barnabas_card, 'life', 3, true);

        -- Bot Reinforcement: 2x Gargula
        PERFORM game_private.add_sandbox_card(v_match_id, v_bot_match_deck_id, v_bot_id, v_gargula_card, 'reinforcement', 1, true);
        PERFORM game_private.add_sandbox_card(v_match_id, v_bot_match_deck_id, v_bot_id, v_gargula_card, 'reinforcement', 2, true);

        -- Bot Hand: 3x Lobo
        PERFORM game_private.add_sandbox_card(v_match_id, v_bot_match_deck_id, v_bot_id, v_lobo_card, 'hand', 1, true);
        PERFORM game_private.add_sandbox_card(v_match_id, v_bot_match_deck_id, v_bot_id, v_lobo_card, 'hand', 2, true);
        PERFORM game_private.add_sandbox_card(v_match_id, v_bot_match_deck_id, v_bot_id, v_lobo_card, 'hand', 3, true);

        -- Bot Deck: 12x Lobo
        FOR v_index IN 1..12 LOOP
            PERFORM game_private.add_sandbox_card(v_match_id, v_bot_match_deck_id, v_bot_id, v_lobo_card, 'deck', v_index, false);
        END LOOP;
    END IF;

    -- 7. Insert this match into training_matches with correct human_user_id and bot_user_id
    INSERT INTO public.training_matches(match_id, human_user_id, bot_user_id, difficulty, created_at)
    VALUES (v_match_id, v_user_id, v_bot_id, 'normal', now());

    RETURN v_match_id;
END;
$$;
