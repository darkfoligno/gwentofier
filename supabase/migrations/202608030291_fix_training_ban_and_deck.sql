-- Migration 202608030291_fix_training_ban_and_deck.sql
-- Corrige a restrição match_bans_category_check e a regra de exatamente 5 cartas lendárias para o Bot de Treino

BEGIN;

-- 1. Sobrescreve start_training_match para enforcar o limite estrito de exatamente 5 lendárias e 35 outras
CREATE OR REPLACE FUNCTION public.start_training_match(p_deck_id text DEFAULT NULL::text)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $$
DECLARE
    v_user_id uuid := game_private.require_authenticated();
    v_bot_id uuid := '00000000-0000-4000-8000-000000000071'::uuid;
    v_match_id uuid;
    v_rule_id uuid;
    v_player_match_deck_id uuid;
    v_bot_match_deck_id uuid;
    v_card record;
    v_position integer;
    v_deck_uuid uuid;
BEGIN
    SELECT id INTO v_rule_id FROM public.game_rule_versions WHERE is_active = true;

    INSERT INTO public.matches(
        rule_version_id, match_type, created_by,
        requires_bans, is_private, status, current_turn, active_player_id
    )
    VALUES (
        v_rule_id, 'training', v_user_id,
        true, true, 'ban_phase', 0, v_user_id
    )
    RETURNING id INTO v_match_id;

    INSERT INTO public.match_players(match_id, user_id, player_number, original_deck_id)
    VALUES (v_match_id, v_user_id, 1, NULL);

    INSERT INTO public.match_players(match_id, user_id, player_number, original_deck_id)
    VALUES (v_match_id, v_bot_id, 2, NULL);

    -- Humano: 40 cartas
    IF p_deck_id = 'SYSTEM_GENERATED' OR p_deck_id IS NULL THEN
        INSERT INTO public.match_decks(match_id, user_id, source_deck_id, total_cards, golden_cards_count)
        VALUES (v_match_id, v_user_id, NULL, 40, 4)
        RETURNING id INTO v_player_match_deck_id;

        v_position := 0;
        FOR v_card IN (
            SELECT c.*,
                   coalesce((select jsonb_agg(jsonb_build_object('effect_order', ce.effect_order, 'trigger_type', ce.trigger_type, 'effect_code', ce.effect_code, 'target_mode', ce.target_mode, 'parameters', ce.parameters, 'priority', ce.priority, 'is_reaction', ce.is_reaction, 'once_per_turn', ce.once_per_turn) order by ce.effect_order) from public.card_effects ce where ce.card_id = c.id and ce.is_active = true), '[]'::jsonb) as effect_definition
            FROM public.cards c WHERE c.is_active = true ORDER BY random() LIMIT 40
        ) LOOP
            v_position := v_position + 1;
            INSERT INTO public.match_deck_cards(
                match_deck_id, source_card_id, card_version, card_name, image_url, element, rarity, card_type, is_golden, base_power, base_max_life, effect_mana_cost, tier, leader_cooldown, effect_definition, copy_number, initial_deck_position
            ) VALUES (
                v_player_match_deck_id, v_card.id, v_card.version, v_card.name, coalesce(v_card.image_url, ''), coalesce(v_card.element, 'Neutro'), v_card.rarity, v_card.card_type, v_card.is_golden, coalesce(v_card.base_power, 0), coalesce(v_card.base_max_life, 0), coalesce(v_card.effect_mana_cost, 0), coalesce(v_card.tier, 1), coalesce(v_card.leader_cooldown, 0), coalesce(v_card.effect_definition, '[]'::jsonb), 1, v_position
            );
        END LOOP;
    ELSE
        v_deck_uuid := p_deck_id::uuid;
        UPDATE public.match_players SET original_deck_id = v_deck_uuid WHERE match_id = v_match_id AND user_id = v_user_id;
        PERFORM game_private.snapshot_deck(v_match_id, v_user_id, v_deck_uuid);
    END IF;

    -- Bot: Exatamente 5 lendárias e 35 outras raridades
    INSERT INTO public.match_decks(match_id, user_id, source_deck_id, total_cards, golden_cards_count)
    VALUES (v_match_id, v_bot_id, NULL, 40, 5)
    RETURNING id INTO v_bot_match_deck_id;

    v_position := 0;
    -- 5 lendárias
    FOR v_card IN (
        SELECT c.*,
               coalesce((select jsonb_agg(jsonb_build_object('effect_order', ce.effect_order, 'trigger_type', ce.trigger_type, 'effect_code', ce.effect_code, 'target_mode', ce.target_mode, 'parameters', ce.parameters, 'priority', ce.priority, 'is_reaction', ce.is_reaction, 'once_per_turn', ce.once_per_turn) order by ce.effect_order) from public.card_effects ce where ce.card_id = c.id and ce.is_active = true), '[]'::jsonb) as effect_definition
        FROM public.cards c WHERE c.is_active = true AND c.card_type = 'normal' AND c.rarity = 'legendary' ORDER BY random() LIMIT 5
    ) LOOP
        v_position := v_position + 1;
        INSERT INTO public.match_deck_cards(
            match_deck_id, source_card_id, card_version, card_name, image_url, element, rarity, card_type, is_golden, base_power, base_max_life, effect_mana_cost, tier, leader_cooldown, effect_definition, copy_number, initial_deck_position
        ) VALUES (
            v_bot_match_deck_id, v_card.id, v_card.version, v_card.name, coalesce(v_card.image_url, ''), coalesce(v_card.element, 'Neutro'), v_card.rarity, v_card.card_type, v_card.is_golden, coalesce(v_card.base_power, 0), coalesce(v_card.base_max_life, 0), coalesce(v_card.effect_mana_cost, 0), coalesce(v_card.tier, 1), coalesce(v_card.leader_cooldown, 0), coalesce(v_card.effect_definition, '[]'::jsonb), 1, v_position
        );
    END LOOP;

    -- 35 outras
    FOR v_card IN (
        SELECT c.*,
               coalesce((select jsonb_agg(jsonb_build_object('effect_order', ce.effect_order, 'trigger_type', ce.trigger_type, 'effect_code', ce.effect_code, 'target_mode', ce.target_mode, 'parameters', ce.parameters, 'priority', ce.priority, 'is_reaction', ce.is_reaction, 'once_per_turn', ce.once_per_turn) order by ce.effect_order) from public.card_effects ce where ce.card_id = c.id and ce.is_active = true), '[]'::jsonb) as effect_definition
        FROM public.cards c WHERE c.is_active = true AND c.card_type = 'normal' AND c.rarity IN ('common', 'rare', 'epic') ORDER BY random() LIMIT 35
    ) LOOP
        v_position := v_position + 1;
        INSERT INTO public.match_deck_cards(
            match_deck_id, source_card_id, card_version, card_name, image_url, element, rarity, card_type, is_golden, base_power, base_max_life, effect_mana_cost, tier, leader_cooldown, effect_definition, copy_number, initial_deck_position
        ) VALUES (
            v_bot_match_deck_id, v_card.id, v_card.version, v_card.name, coalesce(v_card.image_url, ''), coalesce(v_card.element, 'Neutro'), v_card.rarity, v_card.card_type, v_card.is_golden, coalesce(v_card.base_power, 0), coalesce(v_card.base_max_life, 0), coalesce(v_card.effect_mana_cost, 0), coalesce(v_card.tier, 1), coalesce(v_card.leader_cooldown, 0), coalesce(v_card.effect_definition, '[]'::jsonb), 1, v_position
        );
    END LOOP;

    -- Popular match_cards para o player e para o bot
    IF p_deck_id = 'SYSTEM_GENERATED' OR p_deck_id IS NULL THEN
        INSERT INTO public.match_cards(match_id, owner_user_id, controller_user_id, match_deck_card_id, source_card_id, zone, zone_position, is_face_up, base_power, base_max_life, current_power, maximum_power, current_life, maximum_life)
        SELECT v_match_id, v_user_id, v_user_id, mdc.id, mdc.source_card_id, 'deck', mdc.initial_deck_position, false, mdc.base_power, mdc.base_max_life, mdc.base_power, mdc.base_power, mdc.base_max_life, mdc.base_max_life
        FROM public.match_deck_cards mdc WHERE mdc.match_deck_id = v_player_match_deck_id;
    END IF;

    INSERT INTO public.match_cards(match_id, owner_user_id, controller_user_id, match_deck_card_id, source_card_id, zone, zone_position, is_face_up, base_power, base_max_life, current_power, maximum_power, current_life, maximum_life)
    SELECT v_match_id, v_bot_id, v_bot_id, mdc.id, mdc.source_card_id, 'deck', mdc.initial_deck_position, false, mdc.base_power, mdc.base_max_life, mdc.base_power, mdc.base_power, mdc.base_max_life, mdc.base_max_life
    FROM public.match_deck_cards mdc WHERE mdc.match_deck_id = v_bot_match_deck_id;

    INSERT INTO public.match_public_states(match_id, player1_user_id, player1_username, player2_user_id, player2_username)
    SELECT v_match_id, p1.id, p1.username, p2.id, p2.username
    FROM public.profiles p1, public.profiles p2
    WHERE p1.id = v_user_id AND p2.id = v_bot_id;

    RETURN v_match_id;
END;
$$;

-- 2. Sobrescreve submit_match_ban para usar categorias válidas para o bot
CREATE OR REPLACE FUNCTION public.submit_match_ban(p_match_id uuid, p_source_card_id uuid, p_ban_category text, p_expected_version bigint DEFAULT NULL::bigint)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $$
DECLARE
    v_user_id uuid := auth.uid();
    v_target_id uuid;
    v_bot_id uuid := '00000000-0000-4000-8000-000000000071'::uuid;
    v_match_type text;
    v_player_legendary_card_id uuid;
    v_valid_category text;
BEGIN
    SELECT match_type INTO v_match_type FROM public.matches WHERE id = p_match_id;

    SELECT user_id INTO v_target_id FROM public.match_players
    WHERE match_id = p_match_id AND user_id <> v_user_id LIMIT 1;
    
    IF v_target_id IS NULL THEN 
        RAISE EXCEPTION 'OPPONENT_NOT_FOUND'; 
    END IF;

    -- Normaliza categoria do ban para respeitar match_bans_category_check
    v_valid_category := coalesce(p_ban_category, 'rare');
    IF v_valid_category NOT IN ('rare', 'epic', 'legendary', 'collab', 'leader', 'legendary_golden', 'highest_rarity') THEN
        v_valid_category := 'rare';
    END IF;

    IF p_source_card_id IS NULL THEN
        INSERT INTO public.match_bans(match_id, banned_by_user_id, target_user_id, source_card_id, ban_category, is_skipped)
        VALUES (p_match_id, v_user_id, v_target_id, null, v_valid_category, true);
    ELSE
        INSERT INTO public.match_bans(match_id, banned_by_user_id, target_user_id, source_card_id, ban_category, is_skipped)
        VALUES (p_match_id, v_user_id, v_target_id, p_source_card_id, v_valid_category, false);

        UPDATE public.match_cards
        SET zone = 'banished', is_face_up = true
        WHERE id = (
            SELECT id FROM public.match_cards 
            WHERE match_id = p_match_id AND owner_user_id = v_target_id AND source_card_id = p_source_card_id AND zone = 'deck'
            LIMIT 1
        );
    END IF;

    -- Automação de banimento do bot em treino e campanha
    IF v_target_id = v_bot_id AND NOT EXISTS (SELECT 1 FROM public.match_bans WHERE match_id = p_match_id AND banned_by_user_id = v_bot_id) THEN
        -- Sorteia uma carta aleatória do deck do humano para banir
        SELECT mc.id INTO v_player_legendary_card_id
        FROM public.match_cards mc
        WHERE mc.match_id = p_match_id AND mc.owner_user_id = v_user_id AND mc.zone = 'deck'
        ORDER BY random() LIMIT 1;
        
        IF v_player_legendary_card_id IS NOT NULL THEN
            UPDATE public.match_cards SET zone = 'banished', is_face_up = true WHERE id = v_player_legendary_card_id;
            
            INSERT INTO public.match_bans(match_id, banned_by_user_id, target_user_id, source_card_id, ban_category, is_skipped)
            VALUES (p_match_id, v_bot_id, v_user_id, (SELECT source_card_id FROM public.match_cards WHERE id = v_player_legendary_card_id), v_valid_category, false);
        ELSE
            INSERT INTO public.match_bans(match_id, banned_by_user_id, target_user_id, source_card_id, ban_category, is_skipped)
            VALUES (p_match_id, v_bot_id, v_user_id, null, v_valid_category, true);
        END IF;
    END IF;

    IF (SELECT count(*) FROM public.match_bans WHERE match_id = p_match_id) >= 2 THEN
        UPDATE public.matches SET status = 'setup' WHERE id = p_match_id;
        PERFORM game_private.deal_initial_hands(p_match_id);
        RETURN jsonb_build_object('ban_phase_complete', true);
    END IF;

    RETURN jsonb_build_object('ban_phase_complete', false);
END;
$$;

COMMIT;
