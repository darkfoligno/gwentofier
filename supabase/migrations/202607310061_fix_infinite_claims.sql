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
BEGIN
    -- Selecionar a carteira para pegar a ultima claim date
    SELECT * INTO v_wallet_record FROM public.player_wallets WHERE user_id = p_user_id FOR UPDATE;
    
    -- Se nao tiver carteira, inicializa com a data de agora e da a recompensa
    IF NOT FOUND THEN
        v_days_missed := 1;
        
        INSERT INTO public.player_wallets (user_id, coins, last_claim_date)
        VALUES (p_user_id, 150, now());
        
        v_coins_reward := 150;
        v_packs_reward := 1;
    ELSE
        -- Tem carteira, verifica a data
        IF v_wallet_record.last_claim_date IS NULL THEN
            v_days_missed := 1;
        ELSE
            -- Conta quantos dias passaram desde a ultima reivindicacao (truncando para o inicio do dia pode ser melhor, mas vou usar o intervalo extraido em dias)
            v_days_missed := EXTRACT(DAY FROM (now() - v_wallet_record.last_claim_date))::integer;
            
            -- Se for o mesmo dia, diff é 0, entao nao ganha
            IF v_days_missed < 1 THEN
                -- Isso arruma o problema visual no frontend disparando um erro real em vez de sucesso = false silencioso.
                -- RAISE EXCEPTION 'Already claimed today';
                RETURN jsonb_build_object('success', false, 'error', 'Already claimed today');
            END IF;
        END IF;

        v_coins_reward := v_days_missed * 150;
        v_packs_reward := v_days_missed * 1;

        UPDATE public.player_wallets SET 
            coins = coins + v_coins_reward, 
            last_claim_date = now() 
        WHERE user_id = p_user_id;
    END IF;

    -- Conceder Pacotes Diários
    INSERT INTO public.user_pack_balances (user_id, pack_type_id, quantity)
    SELECT p_user_id, id, v_packs_reward FROM public.pack_types WHERE code = 'daily_pack'
    ON CONFLICT (user_id, pack_type_id) DO UPDATE SET quantity = user_pack_balances.quantity + v_packs_reward;

    RETURN jsonb_build_object(
        'success', true, 
        'coins_reward', v_coins_reward, 
        'packs_reward', v_packs_reward, 
        'days_accumulated', v_days_missed
    );
END;
$$;

COMMIT;
