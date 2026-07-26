BEGIN;

-- 1. Drop constraints depending on initial_deck_position
ALTER TABLE public.match_deck_cards DROP CONSTRAINT IF EXISTS match_deck_cards_match_deck_id_initial_deck_position_key CASCADE;

-- 2. Drop the column initial_deck_position from match_deck_cards
ALTER TABLE public.match_deck_cards DROP COLUMN IF EXISTS initial_deck_position CASCADE;

-- 3. Recreate game_private.snapshot_deck without initial_deck_position
CREATE OR REPLACE FUNCTION game_private.snapshot_deck(
    p_match_id uuid,
    p_controller_user_id uuid,
    p_deck_id uuid
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    v_match_deck_id uuid;
    v_row record;
    v_copy integer;
    v_effects jsonb;
BEGIN
    INSERT INTO public.match_decks(match_id, user_id, source_deck_id, total_cards, golden_cards_count)
    SELECT p_match_id, p_controller_user_id, p_deck_id, d.total_cards, d.golden_cards_count
    FROM public.decks d
    WHERE d.id = p_deck_id
    RETURNING id INTO v_match_deck_id;

    FOR v_row IN
        SELECT dc.card_id, dc.quantity, c.version, c.name, coalesce(c.image_url, '') as image_url,
               coalesce(c.element, 'Neutro') as element, c.rarity, c.card_type, c.is_golden,
               coalesce(c.base_power, 0) as base_power, coalesce(c.base_max_life, 0) as base_max_life,
               coalesce(c.effect_mana_cost, 0) as effect_mana_cost, coalesce(c.tier, 1) as tier,
               coalesce(c.leader_cooldown, 0) as leader_cooldown,
               coalesce(
                   (
                       SELECT jsonb_agg(
                           jsonb_build_object(
                               'effect_order', ce.effect_order,
                               'trigger_type', ce.trigger_type,
                               'effect_code', ce.effect_code,
                               'target_mode', ce.target_mode,
                               'parameters', ce.parameters,
                               'priority', ce.priority,
                               'is_reaction', ce.is_reaction,
                               'once_per_turn', ce.once_per_turn
                           ) ORDER BY ce.effect_order
                       )
                       FROM public.card_effects ce
                       WHERE ce.card_id = c.id
                         AND ce.is_active = true
                   ),
                   '[]'::jsonb
               ) as effect_definition
        FROM public.deck_cards dc
        JOIN public.cards c ON c.id = dc.card_id
        WHERE dc.deck_id = p_deck_id
        ORDER BY c.id
    LOOP
        FOR v_copy IN 1..v_row.quantity LOOP
            INSERT INTO public.match_deck_cards(
                match_deck_id, source_card_id, card_version, card_name, image_url, element, rarity, card_type,
                is_golden, base_power, base_max_life, effect_mana_cost, tier, leader_cooldown,
                effect_definition, copy_number
            ) VALUES (
                v_match_deck_id, v_row.card_id, v_row.version, v_row.name, v_row.image_url, v_row.element,
                v_row.rarity, v_row.card_type, v_row.is_golden, v_row.base_power, v_row.base_max_life,
                v_row.effect_mana_cost, v_row.tier, v_row.leader_cooldown, v_row.effect_definition,
                v_copy
            );
        END LOOP;
    END LOOP;

    INSERT INTO public.match_cards(
        match_id, owner_user_id, controller_user_id, match_deck_card_id, source_card_id,
        zone, zone_position, is_face_up, base_power, base_max_life,
        current_power, maximum_power, current_life, maximum_life
    )
    SELECT p_match_id, p_controller_user_id, p_controller_user_id, mdc.id, mdc.source_card_id,
           'deck', row_number() over (order by random()), false, mdc.base_power, mdc.base_max_life,
           mdc.base_power, mdc.base_power, mdc.base_max_life, mdc.base_max_life
    FROM public.match_deck_cards mdc 
    WHERE mdc.match_deck_id = v_match_deck_id;

    RETURN v_match_deck_id;
END;
$$;

-- 4. Recreate game_private.snapshot_boss_deck without initial_deck_position
CREATE OR REPLACE FUNCTION game_private.snapshot_boss_deck(
    p_match_id uuid,
    p_controller_user_id uuid,
    p_boss_id uuid
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    v_match_deck_id uuid;
    v_total integer;
    v_copy integer;
    v_row record;
END;
$$;

CREATE OR REPLACE FUNCTION game_private.snapshot_boss_deck(
    p_match_id uuid,
    p_controller_user_id uuid,
    p_boss_id uuid
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    v_match_deck_id uuid;
    v_total integer;
    v_copy integer;
    v_row record;
BEGIN
    SELECT coalesce(sum(quantity),0)::integer INTO v_total
    FROM public.campaign_boss_deck_cards WHERE boss_id=p_boss_id;
    IF v_total=0 THEN RAISE EXCEPTION 'BOSS_DECK_EMPTY'; END IF;

    INSERT INTO public.match_decks(match_id, user_id, source_deck_id, leader_card_id, total_cards, golden_cards_count)
    SELECT p_match_id, p_controller_user_id, null,
           (SELECT cbd.card_id FROM public.campaign_boss_deck_cards cbd
            JOIN public.cards lc ON lc.id=cbd.card_id
            WHERE cbd.boss_id=p_boss_id AND lc.card_type='leader' LIMIT 1),
           v_total,
           coalesce(sum(CASE WHEN c.is_golden THEN cbd.quantity ELSE 0 END),0)::integer
    FROM public.campaign_boss_deck_cards cbd
    JOIN public.cards c ON c.id=cbd.card_id
    WHERE cbd.boss_id=p_boss_id
    RETURNING id INTO v_match_deck_id;

    FOR v_row IN
        SELECT cbd.card_id, cbd.quantity, c.*,
            coalesce((SELECT jsonb_agg(jsonb_build_object(
                'effect_order',ce.effect_order,'trigger_type',ce.trigger_type,
                'effect_code',ce.effect_code,'target_mode',ce.target_mode,
                'parameters',ce.parameters,'priority',ce.priority,
                'is_reaction',ce.is_reaction,'once_per_turn',ce.once_per_turn
            ) ORDER BY ce.effect_order)
            FROM public.card_effects ce WHERE ce.card_id=c.id AND ce.is_active=true),'[]'::jsonb) effect_definition
        FROM public.campaign_boss_deck_cards cbd
        JOIN public.cards c ON c.id=cbd.card_id
        WHERE cbd.boss_id=p_boss_id AND c.is_active=true
    LOOP
        FOR v_copy IN 1..v_row.quantity LOOP
            INSERT INTO public.match_deck_cards(
                match_deck_id,source_card_id,card_version,card_name,image_url,element,rarity,card_type,
                is_golden,base_power,base_max_life,effect_mana_cost,tier,leader_cooldown,
                effect_definition,copy_number
            ) VALUES(
                v_match_deck_id,v_row.card_id,v_row.version,v_row.name,v_row.image_url,v_row.element,
                v_row.rarity,v_row.card_type,v_row.is_golden,v_row.base_power,v_row.base_max_life,
                v_row.effect_mana_cost,v_row.tier,v_row.leader_cooldown,v_row.effect_definition,
                v_copy
            );
        END LOOP;
    END LOOP;

    INSERT INTO public.match_cards(
        match_id,owner_user_id,controller_user_id,match_deck_card_id,source_card_id,
        zone,zone_position,is_face_up,base_power,base_max_life,
        current_power,maximum_power,current_life,maximum_life
    )
    SELECT p_match_id,p_controller_user_id,p_controller_user_id,mdc.id,mdc.source_card_id,
           'deck',row_number() over (order by random()),false,mdc.base_power,mdc.base_max_life,
           mdc.base_power,mdc.base_power,mdc.base_max_life,mdc.base_max_life
    FROM public.match_deck_cards mdc 
    WHERE mdc.match_deck_id=v_match_deck_id;

    RETURN v_match_deck_id;
END;
$$;

-- 5. Recreate public.start_training_match without initial_deck_position
CREATE OR REPLACE FUNCTION public.start_training_match(
    p_deck_id text
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    v_user_id uuid := game_private.require_authenticated();
    v_bot_id uuid := '00000000-0000-4000-8000-000000000071'::uuid;
    v_match_id uuid;
    v_player_match_deck_id uuid;
    v_bot_match_deck_id uuid;
    v_deck_uuid uuid;
    v_card record;
BEGIN
    -- Criar a partida
    INSERT INTO public.matches(status, match_type, current_turn, rule_version_id)
    SELECT 'ban_phase', 'training', 0, grv.id
    FROM public.game_rule_versions grv
    ORDER BY grv.version DESC LIMIT 1
    RETURNING id INTO v_match_id;

    -- Inserir os jogadores
    INSERT INTO public.match_players(match_id, user_id, player_number, original_deck_id)
    VALUES 
        (v_match_id, v_user_id, 1, NULL),
        (v_match_id, v_bot_id, 2, NULL);

    -- Setup dos decks
    IF p_deck_id = 'SYSTEM_GENERATED' OR p_deck_id IS NULL THEN
        INSERT INTO public.match_decks(match_id, user_id, source_deck_id, total_cards, golden_cards_count)
        VALUES (v_match_id, v_user_id, NULL, 40, 4)
        RETURNING id INTO v_player_match_deck_id;

        FOR v_card IN (
            SELECT c.*,
                   coalesce((select jsonb_agg(jsonb_build_object('effect_order', ce.effect_order, 'trigger_type', ce.trigger_type, 'effect_code', ce.effect_code, 'target_mode', ce.target_mode, 'parameters', ce.parameters, 'priority', ce.priority, 'is_reaction', ce.is_reaction, 'once_per_turn', ce.once_per_turn) order by ce.effect_order) from public.card_effects ce where ce.card_id = c.id and ce.is_active = true), '[]'::jsonb) as effect_definition
            FROM public.cards c WHERE c.is_active = true ORDER BY random() LIMIT 40
        ) LOOP
            INSERT INTO public.match_deck_cards(
                match_deck_id, source_card_id, card_version, card_name, image_url, element, rarity, card_type, is_golden, base_power, base_max_life, effect_mana_cost, tier, leader_cooldown, effect_definition, copy_number
            ) VALUES (
                v_player_match_deck_id, v_card.id, v_card.version, v_card.name, coalesce(v_card.image_url, ''), coalesce(v_card.element, 'Neutro'), v_card.rarity, v_card.card_type, v_card.is_golden, coalesce(v_card.base_power, 0), coalesce(v_card.base_max_life, 0), coalesce(v_card.effect_mana_cost, 0), coalesce(v_card.tier, 1), coalesce(v_card.leader_cooldown, 0), coalesce(v_card.effect_definition, '[]'::jsonb), 1
            );
        END LOOP;
    ELSE
        v_deck_uuid := p_deck_id::uuid;
        UPDATE public.match_players SET original_deck_id = v_deck_uuid WHERE match_id = v_match_id AND user_id = v_user_id;
        PERFORM game_private.snapshot_deck(v_match_id, v_user_id, v_deck_uuid);
    END IF;

    -- Deck do Bot
    INSERT INTO public.match_decks(match_id, user_id, source_deck_id, total_cards, golden_cards_count)
    VALUES (v_match_id, v_bot_id, NULL, 40, 4)
    RETURNING id INTO v_bot_match_deck_id;

    FOR v_card IN (
        SELECT c.*,
               coalesce((select jsonb_agg(jsonb_build_object('effect_order', ce.effect_order, 'trigger_type', ce.trigger_type, 'effect_code', ce.effect_code, 'target_mode', ce.target_mode, 'parameters', ce.parameters, 'priority', ce.priority, 'is_reaction', ce.is_reaction, 'once_per_turn', ce.once_per_turn) order by ce.effect_order) from public.card_effects ce where ce.card_id = c.id and ce.is_active = true), '[]'::jsonb) as effect_definition
        FROM public.cards c WHERE c.is_active = true ORDER BY random() LIMIT 40
    ) LOOP
        INSERT INTO public.match_deck_cards(
            match_deck_id, source_card_id, card_version, card_name, image_url, element, rarity, card_type, is_golden, base_power, base_max_life, effect_mana_cost, tier, leader_cooldown, effect_definition, copy_number
        ) VALUES (
            v_bot_match_deck_id, v_card.id, v_card.version, v_card.name, coalesce(v_card.image_url, ''), coalesce(v_card.element, 'Neutro'), v_card.rarity, v_card.card_type, v_card.is_golden, coalesce(v_card.base_power, 0), coalesce(v_card.base_max_life, 0), coalesce(v_card.effect_mana_cost, 0), coalesce(v_card.tier, 1), coalesce(v_card.leader_cooldown, 0), coalesce(v_card.effect_definition, '[]'::jsonb), 1
        );
    END LOOP;

    -- Popular match_cards para o player e para o bot
    IF p_deck_id = 'SYSTEM_GENERATED' OR p_deck_id IS NULL THEN
        INSERT INTO public.match_cards(match_id, owner_user_id, controller_user_id, match_deck_card_id, source_card_id, zone, zone_position, is_face_up, base_power, base_max_life, current_power, maximum_power, current_life, maximum_life)
        SELECT v_match_id, v_user_id, v_user_id, mdc.id, mdc.source_card_id, 'deck', row_number() over (order by random()), false, mdc.base_power, mdc.base_max_life, mdc.base_power, mdc.base_power, mdc.base_max_life, mdc.base_max_life
        FROM public.match_deck_cards mdc WHERE mdc.match_deck_id = v_player_match_deck_id;
    END IF;

    INSERT INTO public.match_cards(match_id, owner_user_id, controller_user_id, match_deck_card_id, source_card_id, zone, zone_position, is_face_up, base_power, base_max_life, current_power, maximum_power, current_life, maximum_life)
    SELECT v_match_id, v_bot_id, v_bot_id, mdc.id, mdc.source_card_id, 'deck', row_number() over (order by random()), false, mdc.base_power, mdc.base_max_life, mdc.base_power, mdc.base_power, mdc.base_max_life, mdc.base_max_life
    FROM public.match_deck_cards mdc WHERE mdc.match_deck_id = v_bot_match_deck_id;

    INSERT INTO public.match_public_states(match_id, player1_user_id, player1_username, player2_user_id, player2_username)
    SELECT v_match_id, p1.id, p1.username, p2.id, p2.username
    FROM public.profiles p1, public.profiles p2
    WHERE p1.id = v_user_id AND p2.id = v_bot_id;

    RETURN v_match_id;
END;
$$;

COMMIT;
