BEGIN;

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
                        p_user_id, v_card_id, 1, 'daily_reward', v_opening_id, null, 'Recompensa Diária Automática'
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

COMMIT;
