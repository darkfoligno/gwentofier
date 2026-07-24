CREATE OR REPLACE FUNCTION public.get_match_ban_candidates(p_match_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    v_user_id uuid := game_private.require_authenticated();
    v_target_id uuid;
    v_result jsonb;
BEGIN
    IF NOT EXISTS(SELECT 1 FROM public.match_players WHERE match_id=p_match_id AND user_id=v_user_id) THEN
        RAISE EXCEPTION 'NOT_A_MATCH_PLAYER';
    END IF;
    SELECT user_id INTO v_target_id FROM public.match_players
    WHERE match_id=p_match_id AND user_id<>v_user_id;
    IF v_target_id IS NULL THEN RAISE EXCEPTION 'OPPONENT_NOT_FOUND'; END IF;

    SELECT coalesce(jsonb_agg(jsonb_build_object(
        'card_id', x.source_card_id, 'name', x.card_name, 'image_url', x.image_url,
        'rarity', x.rarity, 'card_type', x.card_type, 'is_golden', x.is_golden,
        'copy_count', x.copy_count, 'categories', x.categories
    ) ORDER BY 
        CASE x.rarity 
            WHEN 'legendary' THEN 1 
            WHEN 'epic' THEN 2 
            WHEN 'rare' THEN 3 
            ELSE 4 
        END, x.card_name), '[]'::jsonb)
    INTO v_result
    FROM (
        SELECT mc.source_card_id, max(mdc.card_name) card_name, max(mdc.image_url) image_url,
               max(mdc.rarity) rarity, max(mdc.card_type) card_type,
               bool_or(mdc.is_golden) is_golden, count(*) copy_count,
               array_remove(array[
                    CASE WHEN max(mdc.rarity)='rare' THEN 'rare' END,
                    CASE WHEN max(mdc.rarity)='epic' THEN 'epic' END,
                    CASE WHEN max(mdc.rarity)='legendary' THEN 'legendary' END,
                    CASE WHEN bool_or(coalesce(cs.is_collab,false)) THEN 'collab' END,
                    CASE WHEN max(mdc.card_type)='leader' THEN 'leader' END
               ], null) categories
        FROM public.match_cards mc
        JOIN public.match_deck_cards mdc ON mdc.id = mc.match_deck_card_id
        JOIN public.cards c ON c.id = mc.source_card_id
        LEFT JOIN public.card_sets cs ON cs.id = c.set_id
        WHERE mc.match_id = p_match_id 
          AND mc.owner_user_id = v_target_id
          AND mc.zone = 'deck'
          AND NOT EXISTS(
              SELECT 1 FROM public.match_bans mb
              WHERE mb.match_id = p_match_id 
                AND mb.banned_by_user_id = v_user_id
                AND mb.source_card_id = mc.source_card_id
          )
        GROUP BY mc.source_card_id
    ) x;
    
    RETURN v_result;
END;
$$;

CREATE OR REPLACE FUNCTION public.submit_match_ban(
    p_match_id uuid,
    p_source_card_id uuid,
    p_ban_category text,
    p_expected_version bigint
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    v_user_id uuid := game_private.require_authenticated();
    v_match public.matches;
    v_target_id uuid;
    v_valid boolean;
    v_complete boolean;
    v_new_version bigint;
BEGIN
    v_match := game_private.lock_match_for_action(p_match_id, p_expected_version, array['ban_phase']);
    IF p_ban_category NOT IN ('rare','epic','legendary','collab','leader') THEN
        RAISE EXCEPTION 'INVALID_BAN_CATEGORY';
    END IF;
    SELECT user_id INTO v_target_id FROM public.match_players
    WHERE match_id=p_match_id AND user_id<>v_user_id;
    IF v_target_id IS NULL THEN RAISE EXCEPTION 'OPPONENT_NOT_FOUND'; END IF;
    IF EXISTS(SELECT 1 FROM public.match_bans WHERE match_id=p_match_id AND banned_by_user_id=v_user_id AND ban_category=p_ban_category) THEN
        RAISE EXCEPTION 'BAN_CATEGORY_ALREADY_SUBMITTED';
    END IF;

    SELECT EXISTS(
        SELECT 1
        FROM public.match_cards mc
        JOIN public.match_deck_cards mdc ON mdc.id = mc.match_deck_card_id
        JOIN public.cards c ON c.id = mc.source_card_id
        LEFT JOIN public.card_sets cs ON cs.id = c.set_id
        WHERE mc.match_id = p_match_id 
          AND mc.owner_user_id = v_target_id
          AND mc.zone = 'deck'
          AND NOT EXISTS(
              SELECT 1 FROM public.match_bans mb
              WHERE mb.match_id = p_match_id 
                AND mb.banned_by_user_id = v_user_id
                AND mb.source_card_id = mc.source_card_id
          )
          AND (p_source_card_id IS NULL OR mc.source_card_id = p_source_card_id)
          AND CASE p_ban_category
                WHEN 'rare' THEN mdc.rarity='rare'
                WHEN 'epic' THEN mdc.rarity='epic'
                WHEN 'legendary' THEN mdc.rarity='legendary'
                WHEN 'leader' THEN mdc.card_type='leader'
                WHEN 'collab' THEN coalesce(cs.is_collab,false)
              END
    ) INTO v_valid;

    IF p_source_card_id IS NULL THEN
        IF v_valid THEN RAISE EXCEPTION 'BAN_CANNOT_BE_SKIPPED_WHEN_CANDIDATE_EXISTS'; END IF;
        INSERT INTO public.match_bans(
            match_id, banned_by_user_id, target_user_id, source_card_id, ban_category, is_skipped
        ) VALUES (p_match_id, v_user_id, v_target_id, null, p_ban_category, true);
    ELSE
        IF NOT v_valid THEN RAISE EXCEPTION 'CARD_NOT_VALID_FOR_BAN_CATEGORY'; END IF;
        INSERT INTO public.match_bans(
            match_id, banned_by_user_id, target_user_id, source_card_id, ban_category, is_skipped
        ) VALUES (p_match_id, v_user_id, v_target_id, p_source_card_id, p_ban_category, false);

        UPDATE public.match_cards
        SET zone='banished', zone_position=null, is_face_up=true
        WHERE id = (
            SELECT id FROM public.match_cards 
            WHERE match_id=p_match_id 
              AND owner_user_id=v_target_id
              AND source_card_id=p_source_card_id 
              AND zone='deck'
            LIMIT 1
        );
    END IF;

    SELECT count(*)=10 INTO v_complete
    FROM public.match_bans WHERE match_id=p_match_id;
    
    IF v_complete THEN
        PERFORM game_private.deal_initial_hands(p_match_id);
    END IF;

    v_new_version := game_private.record_match_action(
        p_match_id, v_user_id, 'card_banned',
        jsonb_build_object('target_user_id', v_target_id, 'category', p_ban_category,
            'source_card_id', p_source_card_id, 'skipped', p_source_card_id IS NULL,
            'ban_phase_complete', v_complete),
        '{}'::jsonb, p_expected_version
    );
    RETURN jsonb_build_object('ban_phase_complete', v_complete, 'state_version', v_new_version);
END;
$$;
