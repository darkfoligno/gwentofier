const fs = require('fs');
let content = fs.readFileSync('D:/card-game-ui/supabase/migrations/202608030140_laboratorio_ofieri.sql', 'utf8');

const startIndex = content.indexOf('CREATE OR REPLACE FUNCTION public.start_lab_sandbox');
if (startIndex !== -1) {
    const newFunction = `CREATE OR REPLACE FUNCTION public.start_lab_sandbox(p_test_card_id uuid)
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
    
    -- Loop helper
    v_index integer;
BEGIN
    -- Get active rule version
    SELECT id INTO v_rule_id FROM public.game_rule_versions WHERE is_active = true LIMIT 1;

    -- Fetch the cards
    IF NOT EXISTS(SELECT 1 FROM public.cards WHERE id = p_test_card_id) THEN
        RAISE EXCEPTION 'Tested card not found';
    END IF;

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

    -- 5. Public state
    INSERT INTO public.match_public_states(match_id, player1_user_id, player1_username, player2_user_id, player2_username, player1_hand_count, player2_hand_count, player1_deck_count, player2_deck_count, player1_graveyard_count, player2_graveyard_count, player1_life_remaining, player2_life_remaining, player1_mana_available, player2_mana_available)
    SELECT v_match_id, p1.id, p1.username, p2.id, p2.username, 4, 3, 10, 10, 5, 0, 3, 3, 10, 10 FROM public.profiles p1, public.profiles p2 WHERE p1.id = v_user_id AND p2.id = v_bot_id;

    -- ==========================================
    -- PLAYER 1: TESTER
    -- ==========================================
    -- Hand: Tested card + 3x Lobo
    PERFORM game_private.add_sandbox_card(v_match_id, v_player_match_deck_id, v_user_id, v_test_id, 'hand', 1, true);
    PERFORM game_private.add_sandbox_card(v_match_id, v_player_match_deck_id, v_user_id, v_lobo_id, 'hand', 2, true);
    PERFORM game_private.add_sandbox_card(v_match_id, v_player_match_deck_id, v_user_id, v_lobo_id, 'hand', 3, true);
    PERFORM game_private.add_sandbox_card(v_match_id, v_player_match_deck_id, v_user_id, v_lobo_id, 'hand', 4, true);

    -- Life: 1x Shani (Damaged 1000/3000), 2x Barnabas (Intact 2000/2000)
    PERFORM game_private.add_sandbox_card(v_match_id, v_player_match_deck_id, v_user_id, v_shani_id, 'life', 1, true, null, 3000, 1000);
    PERFORM game_private.add_sandbox_card(v_match_id, v_player_match_deck_id, v_user_id, v_barnabas_id, 'life', 2, true, null, 2000, 2000);
    PERFORM game_private.add_sandbox_card(v_match_id, v_player_match_deck_id, v_user_id, v_barnabas_id, 'life', 3, true, null, 2000, 2000);

    -- Reinforcement: 1x Lobo
    PERFORM game_private.add_sandbox_card(v_match_id, v_player_match_deck_id, v_user_id, v_lobo_id, 'reinforcement', 1, true);

    -- Graveyard: 5x Lobo
    FOR v_index IN 1..5 LOOP
        PERFORM game_private.add_sandbox_card(v_match_id, v_player_match_deck_id, v_user_id, v_lobo_id, 'graveyard', v_index, false);
    END LOOP;

    -- Deck: 10x Lobo
    FOR v_index IN 1..10 LOOP
        PERFORM game_private.add_sandbox_card(v_match_id, v_player_match_deck_id, v_user_id, v_lobo_id, 'deck', v_index, false);
    END LOOP;

    -- ==========================================
    -- PLAYER 2: BOT (UNIVERSAL BOARD)
    -- ==========================================
    -- Hand: 3x Anabelle (High defense target, 2000/2500)
    PERFORM game_private.add_sandbox_card(v_match_id, v_bot_match_deck_id, v_bot_id, v_anabelle_id, 'hand', 1, true, 2000, 2500);
    PERFORM game_private.add_sandbox_card(v_match_id, v_bot_match_deck_id, v_bot_id, v_anabelle_id, 'hand', 2, true, 2000, 2500);
    PERFORM game_private.add_sandbox_card(v_match_id, v_bot_match_deck_id, v_bot_id, v_anabelle_id, 'hand', 3, true, 2000, 2500);

    -- Life: 3x Barnabas (Intact 2000/2000)
    PERFORM game_private.add_sandbox_card(v_match_id, v_bot_match_deck_id, v_bot_id, v_barnabas_id, 'life', 1, true, null, 2000, 2000);
    PERFORM game_private.add_sandbox_card(v_match_id, v_bot_match_deck_id, v_bot_id, v_barnabas_id, 'life', 2, true, null, 2000, 2000);
    PERFORM game_private.add_sandbox_card(v_match_id, v_bot_match_deck_id, v_bot_id, v_barnabas_id, 'life', 3, true, null, 2000, 2000);

    -- Reinforcement: 1x Aracnomorfo (Bestiario, 3100 HP), 1x Arnaghad (Witcher, 4000 HP)
    PERFORM game_private.add_sandbox_card(v_match_id, v_bot_match_deck_id, v_bot_id, v_aracnomorfo_id, 'reinforcement', 1, true, null, 3100, 3100);
    PERFORM game_private.add_sandbox_card(v_match_id, v_bot_match_deck_id, v_bot_id, v_arnaghad_id, 'reinforcement', 2, true, null, 4000, 4000);

    -- Deck: 10 Cards total (6x Lobo, 3x Aracnomorfo, 1x Geralt at bottom)
    FOR v_index IN 1..6 LOOP
        PERFORM game_private.add_sandbox_card(v_match_id, v_bot_match_deck_id, v_bot_id, v_lobo_id, 'deck', v_index, false);
    END LOOP;
    PERFORM game_private.add_sandbox_card(v_match_id, v_bot_match_deck_id, v_bot_id, v_aracnomorfo_id, 'deck', 7, false);
    PERFORM game_private.add_sandbox_card(v_match_id, v_bot_match_deck_id, v_bot_id, v_aracnomorfo_id, 'deck', 8, false);
    PERFORM game_private.add_sandbox_card(v_match_id, v_bot_match_deck_id, v_bot_id, v_aracnomorfo_id, 'deck', 9, false);
    PERFORM game_private.add_sandbox_card(v_match_id, v_bot_match_deck_id, v_bot_id, v_geralt_id, 'deck', 10, false);

    -- 7. Insert this match into training_matches
    INSERT INTO public.training_matches(match_id, human_user_id, bot_user_id, difficulty, created_at)
    VALUES (v_match_id, v_user_id, v_bot_id, 'normal', now());

    RETURN v_match_id;
END;
$$;`;

    content = content.substring(0, startIndex) + newFunction + '\n';
    fs.writeFileSync('D:/card-game-ui/supabase/migrations/202608030140_laboratorio_ofieri.sql', content);
    console.log('Success');
}
