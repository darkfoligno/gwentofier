-- Migration 202607310062_compensation_wipe.sql
-- Compensação global para todos os jogadores devido ao wipe de inventário do Alfa.
-- Adiciona 500 Moedas de Ofier e 1 Pacote Diário para cada jogador.

BEGIN;

DO $$
DECLARE
    v_user record;
    v_daily_pack_id uuid;
BEGIN
    -- Obter o ID do pacote diário
    SELECT id INTO v_daily_pack_id FROM public.pack_types WHERE code = 'daily_pack' AND is_active = true;

    FOR v_user IN SELECT user_id FROM public.player_wallets LOOP
        
        -- 1. Injetar 500 moedas de Ofier de forma transacional
        PERFORM game_private.adjust_wallet(
            v_user.user_id,
            500,
            'admin', -- transaction_type restrito
            'promotion',
            NULL,
            gen_random_uuid(),
            'Compensação pelo reset do Lançamento Alfa'
        );

        -- 2. Conceder 1 Pacote Diário
        IF v_daily_pack_id IS NOT NULL THEN
            INSERT INTO public.user_pack_balances (user_id, pack_type_id, quantity)
            VALUES (v_user.user_id, v_daily_pack_id, 1)
            ON CONFLICT (user_id, pack_type_id) 
            DO UPDATE SET 
                quantity = public.user_pack_balances.quantity + 1,
                updated_at = now();
        END IF;
        
    END LOOP;
END $$;

COMMIT;
