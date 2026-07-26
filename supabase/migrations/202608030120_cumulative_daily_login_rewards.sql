-- Migration: 202608030120_cumulative_daily_login_rewards.sql
-- Description: Implement cumulative daily login reward calculations (400 coins per missed day) retroactively.

CREATE OR REPLACE FUNCTION public.claim_daily_login_reward(p_user_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
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
    -- Locks user wallet record for update
    SELECT * INTO v_wallet_record FROM public.player_wallets WHERE user_id = p_user_id FOR UPDATE;
    
    IF NOT FOUND THEN
        -- First claim on the account
        v_days_missed := 1;
        v_coins_reward := (150 * v_days_missed) + (250 * v_days_missed);
        v_packs_reward := 1;
        INSERT INTO public.player_wallets (user_id, coins, last_claim_date) VALUES (p_user_id, v_coins_reward, now());
    ELSE
        IF v_wallet_record.last_claim_date IS NULL THEN
            v_days_missed := 1;
        ELSE
            -- Enforce once-per-day restriction
            IF v_wallet_record.last_claim_date::date >= CURRENT_DATE THEN
                RETURN jsonb_build_object('success', false, 'error', 'Already claimed today');
            END IF;
            
            -- Calculate cumulative missed days
            v_days_missed := GREATEST(1, (CURRENT_DATE - v_wallet_record.last_claim_date::date)::integer);
        END IF;

        -- Formula: (150 base + 250 bonus) = 400 coins per missed day
        v_coins_reward := (150 * v_days_missed) + (250 * v_days_missed);
        v_packs_reward := v_days_missed * 1;
        
        UPDATE public.player_wallets 
        SET coins = coins + v_coins_reward, last_claim_date = now() 
        WHERE user_id = p_user_id;
    END IF;

    -- Fetch the configured daily pack type
    SELECT * INTO v_pack FROM public.pack_types WHERE code = 'daily_pack' FOR SHARE;
    IF v_pack.id IS NULL THEN
        -- Fallback if not configured
        SELECT * INTO v_pack FROM public.pack_types WHERE is_active = true LIMIT 1;
    END IF;

    IF v_pack.id IS NOT NULL THEN
        -- Register a pack opening
        INSERT INTO public.pack_openings(
            user_id, pack_type_id, idempotency_key,
            coins_spent, source_type
        )
        VALUES (
            p_user_id, v_pack.id, gen_random_uuid(),
            0, 'daily_reward'
        )
        RETURNING id INTO v_opening_id;

        -- Select exactly 4 active cards randomly
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
    END IF;

    RETURN jsonb_build_object(
        'success', true, 
        'dias_resgatados', v_days_missed,
        'days_accumulated', v_days_missed,
        'moedas_base', (150 * v_days_missed),
        'moedas_bonus', (250 * v_days_missed),
        'total_moedas', v_coins_reward,
        'coins_reward', v_coins_reward, 
        'packs_reward', v_packs_reward, 
        'cards', v_results
    );
END;
$$;
