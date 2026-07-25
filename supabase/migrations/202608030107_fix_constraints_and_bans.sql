BEGIN;

-- 1. Corrige o envio do source_type em claim_daily_login_reward
-- Substituindo 'daily_reward' (não suportado em inventory_transactions) por 'promotion'
CREATE OR REPLACE FUNCTION claim_daily_login_reward(p_user_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_wallet_record record;
    v_days_missed integer;
    v_coins_reward integer;
    v_packs_reward integer;
    v_pack public.pack_types;
    v_opening_id uuid;
    v_slot integer;
    v_rule_id uuid;
    v_card_id uuid;
    v_results jsonb := '[]'::jsonb;
    p integer;
BEGIN
    SELECT * INTO v_wallet_record FROM public.player_wallets WHERE user_id = p_user_id FOR UPDATE;
    
    IF NOT FOUND THEN
        v_days_missed := 1;
        INSERT INTO public.player_wallets (user_id, coins, last_claim_date) VALUES (p_user_id, 150, now());
        v_coins_reward := 150;
        v_packs_reward := 1;
    ELSE
        IF v_wallet_record.last_claim_date IS NULL THEN
            v_days_missed := 1;
        ELSE
            IF v_wallet_record.last_claim_date::date >= CURRENT_DATE THEN
                RETURN jsonb_build_object('success', false, 'error', 'Already claimed today');
            END IF;
            
            v_days_missed := (CURRENT_DATE - v_wallet_record.last_claim_date::date)::integer;
            IF v_days_missed < 1 THEN v_days_missed := 1; END IF;
        END IF;

        v_coins_reward := v_days_missed * 150;
        v_packs_reward := v_days_missed * 1;
        UPDATE public.player_wallets SET coins = coins + v_coins_reward, last_claim_date = now() WHERE user_id = p_user_id;
    END IF;

    -- Em vez de guardar o pacote, ABRIR OS PACOTES IMEDIATAMENTE (Pilar 1)
    SELECT * INTO v_pack FROM public.pack_types WHERE code = 'daily_pack' FOR SHARE;
    
    IF v_pack.id IS NOT NULL THEN
        FOR p IN 1..v_packs_reward LOOP
            INSERT INTO public.pack_openings(
                user_id, pack_type_id, idempotency_key,
                coins_spent, source_type
            )
            VALUES (
                p_user_id, v_pack.id, gen_random_uuid(),
                0, 'daily_reward'
            )
            RETURNING id INTO v_opening_id;

            FOR v_slot IN 1..v_pack.cards_per_pack LOOP
                SELECT r.id INTO v_rule_id
                FROM public.pack_drop_rules r
                WHERE r.pack_type_id = v_pack.id AND r.slot_number = v_slot
                ORDER BY (-ln(greatest(random(), 0.000000000001)) / r.weight::numeric) asc
                LIMIT 1;

                IF v_rule_id IS NOT NULL THEN
                    v_card_id := game_private.pick_card_for_rule(v_rule_id);

                    INSERT INTO public.pack_opening_results(
                        opening_id, result_order, card_id, drop_rule_id
                    )
                    VALUES (v_opening_id, v_slot, v_card_id, v_rule_id);

                    PERFORM game_private.adjust_inventory(
                        p_user_id, v_card_id, 1, 'promotion', v_opening_id, null, 'Recompensa Diária Automática'
                    );

                    v_results := v_results || jsonb_build_array(
                        (
                            SELECT jsonb_build_object(
                                'order', v_slot,
                                'card_id', c.id,
                                'name', c.name,
                                'image_url', c.image_url,
                                'rarity', c.rarity,
                                'is_golden', c.is_golden
                            )
                            FROM public.cards c
                            WHERE c.id = v_card_id
                        )
                    );
                END IF;
            END LOOP;
        END LOOP;
    END IF;

    RETURN jsonb_build_object(
        'success', true, 
        'coins_reward', v_coins_reward, 
        'packs_reward', v_packs_reward, 
        'days_accumulated', v_days_missed,
        'cards', v_results
    );
END;
$$;

-- 2. Refatorando submit_match_ban para tratar p_ban_category (lower/trim)
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
