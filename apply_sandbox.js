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

    -- Register match in sandbox_matches
    INSERT INTO public.sandbox_matches (match_id) VALUES (v_match_id);

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

    -- Populate tmp_sandbox_cards based on tested card ID
    IF p_test_card_id = '66d0f400-141a-4591-9c1a-f4400be91bc9'::uuid THEN
        -- 1. Tomira Setup
        INSERT INTO tmp_sandbox_cards (owner_id, deck_id, card_id, zone, pos, face_up, c_power, c_life) VALUES
        -- PLAYER
        (v_user_id, v_player_match_deck_id, v_shani_id, 'life', 1, true, null, 500),
        (v_user_id, v_player_match_deck_id, v_barnabas_id, 'life', 2, true, null, 2000),
        (v_user_id, v_player_match_deck_id, v_barnabas_id, 'life', 3, true, null, 2000),
        (v_user_id, v_player_match_deck_id, '66d0f400-141a-4591-9c1a-f4400be91bc9'::uuid, 'reinforcement', 1, true, null, null), -- Tomira
        (v_user_id, v_player_match_deck_id, v_lobo_id, 'hand', 1, true, null, null),
        (v_user_id, v_player_match_deck_id, v_lobo_id, 'hand', 2, true, null, null),
        (v_user_id, v_player_match_deck_id, v_lobo_id, 'hand', 3, true, null, null),
        -- Fill deck/graveyard for player
        (v_user_id, v_player_match_deck_id, v_lobo_id, 'graveyard', 1, false, null, null),
        (v_user_id, v_player_match_deck_id, v_lobo_id, 'deck', 1, false, null, null),
        
        -- BOT
        (v_bot_id, v_bot_match_deck_id, v_anabelle_id, 'attacker', 1, true, 2000, 2500),
        (v_bot_id, v_bot_match_deck_id, v_barnabas_id, 'life', 1, true, null, 2000),
        (v_bot_id, v_bot_match_deck_id, v_barnabas_id, 'life', 2, true, null, 2000),
        (v_bot_id, v_bot_match_deck_id, v_barnabas_id, 'life', 3, true, null, 2000),
        -- Fill deck for bot
        (v_bot_id, v_bot_match_deck_id, v_lobo_id, 'deck', 1, false, null, null);

    ELSIF p_test_card_id = 'cc6cc445-8484-470f-a71e-3e63dbf0008d'::uuid THEN
        -- 2. Pantera Setup
        INSERT INTO tmp_sandbox_cards (owner_id, deck_id, card_id, zone, pos, face_up, c_power, c_life) VALUES
        -- PLAYER
        (v_user_id, v_player_match_deck_id, 'cc6cc445-8484-470f-a71e-3e63dbf0008d'::uuid, 'hand', 1, true, null, null), -- Pantera
        (v_user_id, v_player_match_deck_id, v_lobo_id, 'hand', 2, true, null, null),
        (v_user_id, v_player_match_deck_id, v_lobo_id, 'hand', 3, true, null, null),
        (v_user_id, v_player_match_deck_id, v_lobo_id, 'hand', 4, true, null, null),
        (v_user_id, v_player_match_deck_id, v_lobo_id, 'hand', 5, true, null, null),
        (v_user_id, v_player_match_deck_id, v_shani_id, 'life', 1, true, null, null),
        (v_user_id, v_player_match_deck_id, v_barnabas_id, 'life', 2, true, null, null),
        (v_user_id, v_player_match_deck_id, v_barnabas_id, 'life', 3, true, null, null),
        -- Fill deck/graveyard for player
        (v_user_id, v_player_match_deck_id, v_lobo_id, 'deck', 1, false, null, null),
        
        -- BOT
        (v_bot_id, v_bot_match_deck_id, v_lobo_id, 'hand', 1, true, null, null),
        (v_bot_id, v_bot_match_deck_id, v_lobo_id, 'hand', 2, true, null, null),
        (v_bot_id, v_bot_match_deck_id, v_arnaghad_id, 'reinforcement', 1, true, 0, 8000),
        (v_bot_id, v_bot_match_deck_id, v_arnaghad_id, 'reinforcement', 2, true, 0, 8000),
        (v_bot_id, v_bot_match_deck_id, v_barnabas_id, 'life', 1, true, null, null),
        (v_bot_id, v_bot_match_deck_id, v_barnabas_id, 'life', 2, true, null, null),
        (v_bot_id, v_bot_match_deck_id, v_barnabas_id, 'life', 3, true, null, null),
        -- Fill deck for bot
        (v_bot_id, v_bot_match_deck_id, v_lobo_id, 'deck', 1, false, null, null);

    ELSIF p_test_card_id = '1c224f7d-52e8-4793-8a38-fe9f30d8bb3b'::uuid THEN
        -- 3. Dijkistra Setup
        INSERT INTO tmp_sandbox_cards (owner_id, deck_id, card_id, zone, pos, face_up, c_power, c_life) VALUES
        -- PLAYER
        (v_user_id, v_player_match_deck_id, '396784cd-e61b-4f7e-8fba-3757eaca72a4'::uuid, 'attacker', 1, true, null, null), -- Troll
        (v_user_id, v_player_match_deck_id, '1c224f7d-52e8-4793-8a38-fe9f30d8bb3b'::uuid, 'hand', 1, true, null, null), -- Dijkistra
        (v_user_id, v_player_match_deck_id, v_lobo_id, 'hand', 2, true, null, null),
        (v_user_id, v_player_match_deck_id, v_shani_id, 'life', 1, true, null, null),
        (v_user_id, v_player_match_deck_id, v_barnabas_id, 'life', 2, true, null, null),
        (v_user_id, v_player_match_deck_id, v_barnabas_id, 'life', 3, true, null, null),
        -- 5 common cards in deck
        (v_user_id, v_player_match_deck_id, v_lobo_id, 'deck', 1, false, null, null),
        (v_user_id, v_player_match_deck_id, v_lobo_id, 'deck', 2, false, null, null),
        (v_user_id, v_player_match_deck_id, v_lobo_id, 'deck', 3, false, null, null),
        (v_user_id, v_player_match_deck_id, v_lobo_id, 'deck', 4, false, null, null),
        (v_user_id, v_player_match_deck_id, v_lobo_id, 'deck', 5, false, null, null),
        
        -- BOT
        (v_bot_id, v_bot_match_deck_id, v_barnabas_id, 'life', 1, true, null, null),
        (v_bot_id, v_bot_match_deck_id, v_barnabas_id, 'life', 2, true, null, null),
        (v_bot_id, v_bot_match_deck_id, v_barnabas_id, 'life', 3, true, null, null),
        (v_bot_id, v_bot_match_deck_id, v_lobo_id, 'deck', 1, false, null, null);

    ELSIF p_test_card_id = 'e0ea21e2-0922-4632-951e-b8c67d950087'::uuid THEN
        -- 4. Alpor Setup
        INSERT INTO tmp_sandbox_cards (owner_id, deck_id, card_id, zone, pos, face_up, c_power, c_life) VALUES
        -- PLAYER
        (v_user_id, v_player_match_deck_id, 'e0ea21e2-0922-4632-951e-b8c67d950087'::uuid, 'hand', 1, true, null, null), -- Alpor
        (v_user_id, v_player_match_deck_id, v_lobo_id, 'hand', 2, true, null, null),
        (v_user_id, v_player_match_deck_id, v_shani_id, 'life', 1, true, null, 1000),
        (v_user_id, v_player_match_deck_id, v_barnabas_id, 'life', 2, true, null, null),
        (v_user_id, v_player_match_deck_id, v_barnabas_id, 'life', 3, true, null, null),
        -- Fill deck/graveyard for player
        (v_user_id, v_player_match_deck_id, v_lobo_id, 'deck', 1, false, null, null),
        
        -- BOT
        (v_bot_id, v_bot_match_deck_id, v_arnaghad_id, 'reinforcement', 1, true, 0, 4000),
        (v_bot_id, v_bot_match_deck_id, v_barnabas_id, 'life', 1, true, null, null),
        (v_bot_id, v_bot_match_deck_id, v_barnabas_id, 'life', 2, true, null, null),
        (v_bot_id, v_bot_match_deck_id, v_barnabas_id, 'life', 3, true, null, null),
        (v_bot_id, v_bot_match_deck_id, v_lobo_id, 'deck', 1, false, null, null);

    ELSIF p_test_card_id = 'cb068893-6065-4437-9cdc-0a23dba9d833'::uuid THEN
        -- 5. Barão Sanguinário Setup
        INSERT INTO tmp_sandbox_cards (owner_id, deck_id, card_id, zone, pos, face_up, c_power, c_life) VALUES
        -- PLAYER
        (v_user_id, v_player_match_deck_id, 'cb068893-6065-4437-9cdc-0a23dba9d833'::uuid, 'hand', 1, true, null, null), -- Barão Sanguinário
        (v_user_id, v_player_match_deck_id, v_shani_id, 'life', 1, true, null, null),
        (v_user_id, v_player_match_deck_id, v_barnabas_id, 'life', 2, true, null, null),
        (v_user_id, v_player_match_deck_id, v_barnabas_id, 'life', 3, true, null, null),
        (v_user_id, v_player_match_deck_id, v_lobo_id, 'deck', 1, false, null, null),
        
        -- BOT
        (v_bot_id, v_bot_match_deck_id, v_barnabas_id, 'life', 1, true, null, null),
        (v_bot_id, v_bot_match_deck_id, v_barnabas_id, 'life', 2, true, null, null),
        (v_bot_id, v_bot_match_deck_id, v_barnabas_id, 'life', 3, true, null, null),
        -- 5 Bestiário cards in bot's deck
        (v_bot_id, v_bot_match_deck_id, '06fa0fe8-eabb-4c46-92b9-2a17479a34b4'::uuid, 'deck', 1, false, 3200, 3200), -- Aparição Noturna
        (v_bot_id, v_bot_match_deck_id, 'a0a82d31-2094-4256-92b9-8bc58c9ba311'::uuid, 'deck', 2, false, 2000, 2000), -- Erinia
        (v_bot_id, v_bot_match_deck_id, '335646dc-6b0d-4f87-bb2e-f44ce9b675c2'::uuid, 'deck', 3, false, 1500, 2000), -- ArqueGriffo
        (v_bot_id, v_bot_match_deck_id, 'e1574966-b7b6-4fa0-86d1-757813ac6d5b'::uuid, 'deck', 4, false, 1200, 2500), -- Sylvano
        (v_bot_id, v_bot_match_deck_id, '0717c4bc-24e5-4852-8fea-9502ce19d70a'::uuid, 'deck', 5, false, 1000, 1500); -- Aparição Diurna

    ELSE
        -- Fallback default layout
        INSERT INTO tmp_sandbox_cards (owner_id, deck_id, card_id, zone, pos, face_up, c_power, c_life) VALUES
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
    END IF;

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
        false, 0, 0, true, false, false, false, false, 0, '{}'::jsonb
    FROM numbered_tmp t
    JOIN numbered_mdc m ON m.rn = t.rn
    JOIN public.cards c ON c.id = t.card_id;

    -- 6. Recalculate hand/deck/graveyard counts in public state based on inserted cards
    UPDATE public.match_public_states
    SET player1_hand_count = (select count(*)::integer from public.match_cards where match_id = v_match_id and owner_user_id = v_user_id and zone = 'hand'),
        player2_hand_count = (select count(*)::integer from public.match_cards where match_id = v_match_id and owner_user_id = v_bot_id and zone = 'hand'),
        player1_deck_count = (select count(*)::integer from public.match_cards where match_id = v_match_id and owner_user_id = v_user_id and zone = 'deck'),
        player2_deck_count = (select count(*)::integer from public.match_cards where match_id = v_match_id and owner_user_id = v_bot_id and zone = 'deck'),
        player1_graveyard_count = (select count(*)::integer from public.match_cards where match_id = v_match_id and owner_user_id = v_user_id and zone = 'graveyard'),
        player2_graveyard_count = (select count(*)::integer from public.match_cards where match_id = v_match_id and owner_user_id = v_bot_id and zone = 'graveyard')
    WHERE match_id = v_match_id;

    -- 7. Insert this match into training_matches
    INSERT INTO public.training_matches(match_id, human_user_id, bot_user_id, difficulty, created_at)
    VALUES (v_match_id, v_user_id, v_bot_id, 'normal', now());

    -- 8. If testing Tomira, configure the opponent's turn and pending attack immediately!
    IF p_test_card_id = '66d0f400-141a-4591-9c1a-f4400be91bc9'::uuid THEN
        DECLARE
            v_attack_id uuid;
            v_attacker_id uuid;
            v_deadline timestamp with time zone := clock_timestamp() + interval '5 minutes';
        BEGIN
            -- Update match state to reaction_window with Bot as active player
            UPDATE public.matches 
            SET active_player_id = v_bot_id, 
                engine_state = 'reaction_window' 
            WHERE id = v_match_id;

            -- Find the Bot's attacker card ID
            SELECT id INTO v_attacker_id 
            FROM public.match_cards 
            WHERE match_id = v_match_id 
              AND owner_user_id = v_bot_id 
              AND zone = 'attacker' 
            LIMIT 1;

            -- Insert the pending attack
            INSERT INTO public.pending_attacks (
                match_id, attacker_user_id, defender_user_id, status, is_direct, declared_power, reaction_deadline, declared_state_version
            )
            VALUES (
                v_match_id, v_bot_id, v_user_id, 'awaiting_reaction', false, 2000, v_deadline, 1
            ) RETURNING id INTO v_attack_id;

            -- Link attacker card to the pending attack
            INSERT INTO public.pending_attack_cards (
                pending_attack_id, match_card_id, attack_position, power_when_declared
            )
            VALUES (
                v_attack_id, v_attacker_id, 1, 2000
            );

            -- Lock the attacker card in metadata
            UPDATE public.match_cards 
            SET metadata = metadata || jsonb_build_object('locked_for_pending_attack', v_attack_id)
            WHERE id = v_attacker_id;
        END;
    END IF;

    -- Make sure all cards have can_attack = true by default in the sandbox
    UPDATE public.match_cards SET can_attack = true WHERE match_id = v_match_id;

    RETURN v_match_id;
END;
$$;`;

    content = content.substring(0, startIndex) + newFunction + '\n';
    fs.writeFileSync('D:/card-game-ui/supabase/migrations/202608030140_laboratorio_ofieri.sql', content);
    console.log('Success');
}
