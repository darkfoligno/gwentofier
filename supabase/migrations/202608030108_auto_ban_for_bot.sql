BEGIN;

-- 1. Força o pacote diário a entregar 4 cartas
UPDATE public.pack_types 
SET cards_per_pack = 4 
WHERE code = 'daily_pack';

-- 2. Atualiza a RPC submit_match_ban para auto-injetar banimentos do Bot
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
    v_clean_category text;
BEGIN
    v_match := game_private.lock_match_for_action(p_match_id, p_expected_version, array['ban_phase']);
    
    v_clean_category := lower(trim(coalesce(p_ban_category, '')));
    
    IF v_clean_category NOT IN ('rare','epic','legendary','collab','leader') THEN
        RAISE EXCEPTION 'INVALID_BAN_CATEGORY';
    END IF;

    SELECT user_id INTO v_target_id FROM public.match_players
    WHERE match_id=p_match_id AND user_id<>v_user_id;
    IF v_target_id IS NULL THEN RAISE EXCEPTION 'OPPONENT_NOT_FOUND'; END IF;
    
    IF EXISTS(SELECT 1 FROM public.match_bans WHERE match_id=p_match_id AND banned_by_user_id=v_user_id AND ban_category=v_clean_category) THEN
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
          AND CASE v_clean_category
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
        ) VALUES (p_match_id, v_user_id, v_target_id, null, v_clean_category, true);
    ELSE
        IF NOT v_valid THEN RAISE EXCEPTION 'CARD_NOT_VALID_FOR_BAN_CATEGORY'; END IF;
        INSERT INTO public.match_bans(
            match_id, banned_by_user_id, target_user_id, source_card_id, ban_category, is_skipped
        ) VALUES (p_match_id, v_user_id, v_target_id, p_source_card_id, v_clean_category, false);

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

    -- INTERVENÇÃO V43: SE O ALVO É O BOT DO TREINO, INJETA OS BANIMENTOS FALTANTES DO BOT COMO PULADOS
    IF v_target_id = '00000000-0000-4000-8000-000000000071' THEN
        INSERT INTO public.match_bans (match_id, banned_by_user_id, target_user_id, source_card_id, ban_category, is_skipped)
        SELECT p_match_id, v_target_id, v_user_id, null, cat, true
        FROM unnest(array['rare','epic','legendary','collab','leader']) AS cat
        WHERE cat NOT IN (
            SELECT ban_category FROM public.match_bans 
            WHERE match_id=p_match_id AND banned_by_user_id=v_target_id
        )
        ON CONFLICT DO NOTHING;
    END IF;

    SELECT count(*)=10 INTO v_complete
    FROM public.match_bans WHERE match_id=p_match_id;
    
    IF v_complete THEN
        PERFORM game_private.deal_initial_hands(p_match_id);
    END IF;

    v_new_version := game_private.record_match_action(
        p_match_id, v_user_id, 'card_banned',
        jsonb_build_object('target_user_id', v_target_id, 'category', v_clean_category,
            'source_card_id', p_source_card_id, 'skipped', p_source_card_id IS NULL,
            'ban_phase_complete', v_complete),
        '{}'::jsonb, p_expected_version
    );
    RETURN jsonb_build_object('ban_phase_complete', v_complete, 'state_version', v_new_version);
END;
$$;

COMMIT;
