BEGIN;

CREATE OR REPLACE FUNCTION public.start_training_match(p_deck_id text DEFAULT NULL)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    v_user_id uuid := game_private.require_authenticated();
    v_bot_id uuid := '00000000-0000-0000-0000-000000000000'::uuid;
    v_match_id uuid;
    v_rule_id uuid;
    v_player_match_deck_id uuid;
    v_bot_match_deck_id uuid;
    v_card record;
    v_position integer;
    v_deck_uuid uuid;
BEGIN
    INSERT INTO public.profiles (id, username, email)
    VALUES (v_bot_id, 'O Autômato de Ofier', 'bot@gwentofier.local')
    ON CONFLICT (id) DO NOTHING;

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
            INSERT INTO public.match_deck_cards(match_deck_id, source_card_id, card_version, card_name, image_url, element, rarity, card_type, is_golden, base_power, base_max_life, effect_mana_cost, tier, leader_cooldown, effect_definition, copy_number, initial_deck_position)
            VALUES (v_player_match_deck_id, v_card.id, 1, v_card.name, coalesce(v_card.image_url, ''), v_card.element, v_card.rarity, v_card.card_type, v_card.is_golden, coalesce(v_card.base_power, 0), coalesce(v_card.base_max_life, 0), coalesce(v_card.effect_mana_cost, 0), coalesce(v_card.tier, 0), coalesce(v_card.leader_cooldown, 0), coalesce(v_card.effect_definition, '[]'::jsonb), 1, v_position);
            v_position := v_position + 1;
        END LOOP;
    ELSE
        v_deck_uuid := p_deck_id::uuid;
        UPDATE public.match_players SET original_deck_id = v_deck_uuid WHERE match_id = v_match_id AND user_id = v_user_id;
        PERFORM game_private.snapshot_deck(v_match_id, v_user_id, v_deck_uuid);
    END IF;

    INSERT INTO public.match_decks(match_id, user_id, source_deck_id, total_cards, golden_cards_count)
    VALUES (v_match_id, v_bot_id, NULL, 40, 4)
    RETURNING id INTO v_bot_match_deck_id;

    v_position := 0;
    FOR v_card IN (
        SELECT c.*,
               coalesce((select jsonb_agg(jsonb_build_object('effect_order', ce.effect_order, 'trigger_type', ce.trigger_type, 'effect_code', ce.effect_code, 'target_mode', ce.target_mode, 'parameters', ce.parameters, 'priority', ce.priority, 'is_reaction', ce.is_reaction, 'once_per_turn', ce.once_per_turn) order by ce.effect_order) from public.card_effects ce where ce.card_id = c.id and ce.is_active = true), '[]'::jsonb) as effect_definition
        FROM public.cards c WHERE c.is_active = true ORDER BY random() LIMIT 40
    ) LOOP
        INSERT INTO public.match_deck_cards(match_deck_id, source_card_id, card_version, card_name, image_url, element, rarity, card_type, is_golden, base_power, base_max_life, effect_mana_cost, tier, leader_cooldown, effect_definition, copy_number, initial_deck_position)
        VALUES (v_bot_match_deck_id, v_card.id, 1, v_card.name, coalesce(v_card.image_url, ''), v_card.element, v_card.rarity, v_card.card_type, v_card.is_golden, coalesce(v_card.base_power, 0), coalesce(v_card.base_max_life, 0), coalesce(v_card.effect_mana_cost, 0), coalesce(v_card.tier, 0), coalesce(v_card.leader_cooldown, 0), coalesce(v_card.effect_definition, '[]'::jsonb), 1, v_position);
        v_position := v_position + 1;
    END LOOP;

    INSERT INTO public.match_public_states(match_id, player1_user_id, player1_username, player2_user_id, player2_username)
    SELECT v_match_id, p1.id, p1.username, p2.id, p2.username
    FROM public.profiles p1, public.profiles p2
    WHERE p1.id = v_user_id AND p2.id = v_bot_id;

    RETURN v_match_id;
END;
$$;

COMMIT;
