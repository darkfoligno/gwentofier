BEGIN;

-- 1. Corrige o resgate diário de login para dar 4 cartas aleatórias
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
    v_results jsonb := '[]'::jsonb;
    v_card record;
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

    SELECT * INTO v_pack FROM public.pack_types WHERE code = 'daily_pack' FOR SHARE;
    IF v_pack.id IS NULL THEN
        RAISE EXCEPTION 'DAILY_PACK_NOT_FOUND';
    END IF;

    -- Registra abertura do pacote
    INSERT INTO public.pack_openings(
        user_id, pack_type_id, idempotency_key,
        coins_spent, source_type
    )
    VALUES (
        p_user_id, v_pack.id, gen_random_uuid(),
        0, 'daily_reward'
    )
    RETURNING id INTO v_opening_id;

    -- Seleciona exatamente 4 cartas ativas aleatórias
    v_slot := 0;
    FOR v_card IN (
        SELECT id, name, image_url, rarity, is_golden
        FROM public.cards
        WHERE is_active = true
        ORDER BY random()
        LIMIT 4
    ) LOOP
        v_slot := v_slot + 1;
        
        INSERT INTO public.pack_opening_results(
            opening_id, result_order, card_id, drop_rule_id
        )
        VALUES (v_opening_id, v_slot, v_card.id, null);

        PERFORM game_private.adjust_inventory(
            p_user_id, v_card.id, 1, 'promotion', v_opening_id, null, 'Recompensa Diária Automática'
        );

        v_results := v_results || jsonb_build_array(
            jsonb_build_object(
                'order', v_slot,
                'card_id', v_card.id,
                'name', v_card.name,
                'image_url', v_card.image_url,
                'rarity', v_card.rarity,
                'is_golden', v_card.is_golden
            )
        );
    END LOOP;

    RETURN jsonb_build_object(
        'success', true, 
        'coins_reward', v_coins_reward, 
        'packs_reward', v_packs_reward, 
        'days_accumulated', v_days_missed,
        'cards', v_results
    );
END;
$$;

-- 2. Atualiza a RPC submit_match_ban para tratar Modo Treino de forma isolada/síncrona (Opção A)
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

    -- PILAR 2: SEPARAÇÃO TOTAL DO MODO TREINO (OPÇÃO A)
    IF v_match.match_type = 'training' THEN
        -- Insere compulsoriamente e de forma síncrona o banimento do Bot na mesma transação!
        INSERT INTO public.match_bans(match_id, banned_by_user_id, target_user_id, source_card_id, ban_category, is_skipped)
        VALUES (p_match_id, '00000000-0000-4000-8000-000000000071'::uuid, v_user_id, null, v_clean_category, true)
        ON CONFLICT DO NOTHING;
        
        -- Força a conclusão imediata para avançar para as 7 cartas da mão
        PERFORM game_private.deal_initial_hands(p_match_id);
        
        v_new_version := game_private.record_match_action(
            p_match_id, v_user_id, 'card_banned',
            jsonb_build_object('target_user_id', v_target_id, 'category', v_clean_category,
                'source_card_id', p_source_card_id, 'skipped', p_source_card_id IS NULL,
                'ban_phase_complete', true),
            '{}'::jsonb, p_expected_version
        );
        RETURN jsonb_build_object('ban_phase_complete', true, 'state_version', v_new_version);
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
