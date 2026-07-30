-- Update snapshot_deck to support generic system-generated decks
CREATE OR REPLACE FUNCTION game_private.snapshot_deck(p_match_id uuid, p_controller_user_id uuid, p_deck_id uuid)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
    v_match_deck_id uuid;
    v_row record;
    v_copy integer;
    v_effects jsonb;
BEGIN
    IF p_deck_id = '00000000-0000-0000-0000-000000000000'::uuid THEN
        INSERT INTO public.match_decks(match_id, user_id, source_deck_id, total_cards, golden_cards_count)
        VALUES (p_match_id, p_controller_user_id, NULL, 40, 4)
        RETURNING id INTO v_match_deck_id;

        FOR v_row IN
            SELECT c.id as card_id, c.version, c.name, coalesce(c.image_url, '') as image_url,
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
            FROM public.cards c
            WHERE c.is_active = true
            ORDER BY random()
            LIMIT 40
        LOOP
            INSERT INTO public.match_deck_cards(
                match_deck_id, source_card_id, card_version, card_name, image_url, element, rarity, card_type,
                is_golden, base_power, base_max_life, effect_mana_cost, tier, leader_cooldown,
                effect_definition, copy_number
            ) VALUES (
                v_match_deck_id, v_row.card_id, v_row.version, v_row.name, v_row.image_url, v_row.element,
                v_row.rarity, v_row.card_type, v_row.is_golden, v_row.base_power, v_row.base_max_life,
                v_row.effect_mana_cost, v_row.tier, v_row.leader_cooldown, v_row.effect_definition,
                1
            );
        END LOOP;
    ELSE
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
    END IF;

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
$function$;
