-- Migration 202607310058_economy_gacha_and_daily_rewards.sql
-- Motor de Gacha, Economia de Retenção Diária e Expurgo de Líderes.

BEGIN;

-- =========================================================================
-- 1. EXPURGO DE LÍDERES
-- =========================================================================
ALTER TABLE IF EXISTS public.decks DROP COLUMN IF EXISTS leader_id;
ALTER TABLE IF EXISTS public.decks DROP COLUMN IF EXISTS leader_card;
ALTER TABLE IF EXISTS public.match_decks DROP COLUMN IF EXISTS leader_id;
ALTER TABLE IF EXISTS public.match_decks DROP COLUMN IF EXISTS leader_card;

-- =========================================================================
-- 2. LOJA E PACOTES (MOTOR GACHA AAA)
-- =========================================================================
DELETE FROM public.pack_types;

INSERT INTO public.pack_types (code, name, description, price_coins, cards_per_pack, is_daily)
VALUES
('ofieri_pack', 'Pacote de Ofieri', 'Concede 4 cartas aleatórias.', 250, 4, false),
('mirage_pack', 'Pacote da Miragem', 'Concede 4 cópias idênticas da mesma carta sorteada.', 500, 4, false),
('zerrikanea_pack', 'Pacote da Zerrikanea', 'Concede 4 cartas de elite (Sem comuns ou raras).', 500, 4, false),
('daily_pack', 'Pacote Diário', 'Recompensa diária', 0, 1, true);

-- Regras de Drop: Ofieri (40% Comum, 40% Rara, 15% Épica, 5% Lendária)
INSERT INTO public.pack_drop_rules (pack_type_id, slot_number, rarity, weight)
SELECT id, slot, rar, w
FROM public.pack_types, 
     unnest(ARRAY[1,2,3,4]) AS slot, 
     unnest(ARRAY['common', 'rare', 'epic', 'legendary']) WITH ORDINALITY AS rarity_arr(rar, o1),
     unnest(ARRAY[40, 40, 15, 5]) WITH ORDINALITY AS weights_arr(w, o2)
WHERE code = 'ofieri_pack' AND o1 = o2;

-- Regras de Drop: Miragem (40, 40, 15, 5)
INSERT INTO public.pack_drop_rules (pack_type_id, slot_number, rarity, weight)
SELECT id, slot, rar, w
FROM public.pack_types, 
     unnest(ARRAY[1,2,3,4]) AS slot, 
     unnest(ARRAY['common', 'rare', 'epic', 'legendary']) WITH ORDINALITY AS rarity_arr(rar, o1),
     unnest(ARRAY[40, 40, 15, 5]) WITH ORDINALITY AS weights_arr(w, o2)
WHERE code = 'mirage_pack' AND o1 = o2;

-- Regras de Drop: Zerrikanea (98% Épica, 2% Lendária)
INSERT INTO public.pack_drop_rules (pack_type_id, slot_number, rarity, weight)
SELECT id, slot, rar, w
FROM public.pack_types, 
     unnest(ARRAY[1,2,3,4]) AS slot, 
     unnest(ARRAY['epic', 'legendary']) WITH ORDINALITY AS rarity_arr(rar, o1),
     unnest(ARRAY[98, 2]) WITH ORDINALITY AS weights_arr(w, o2)
WHERE code = 'zerrikanea_pack' AND o1 = o2;

-- Regras para Pack Diario
INSERT INTO public.pack_drop_rules (pack_type_id, slot_number, rarity, weight)
SELECT id, 1, 'common', 100
FROM public.pack_types WHERE code = 'daily_pack';

-- =========================================================================
-- 3. ECONOMIA DE RETENÇÃO (RECOMPENSA DIÁRIA ACUMULATIVA)
-- =========================================================================
ALTER TABLE public.player_wallets ADD COLUMN IF NOT EXISTS last_claim_date timestamptz;

CREATE OR REPLACE FUNCTION claim_daily_login_reward(p_user_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_last_claim timestamptz;
    v_days_missed integer;
    v_coins_reward integer;
    v_packs_reward integer;
BEGIN
    SELECT last_claim_date INTO v_last_claim FROM public.player_wallets WHERE user_id = p_user_id FOR UPDATE;
    
    IF v_last_claim IS NULL THEN
        v_days_missed := 1;
    ELSE
        v_days_missed := EXTRACT(DAY FROM (now() - v_last_claim))::integer;
        IF v_days_missed < 1 THEN
            RETURN jsonb_build_object('success', false, 'error', 'Already claimed today');
        END IF;
    END IF;

    v_coins_reward := v_days_missed * 150;
    v_packs_reward := v_days_missed * 1;

    UPDATE public.player_wallets SET 
        coins = coins + v_coins_reward, 
        last_claim_date = now() 
    WHERE user_id = p_user_id;

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

-- Trava Anti-Junior: Assegurando que COMMON_013 nunca venha em selects genéricos
-- Em queries de Gacha (que utilizam tabelas ou views de cartas), devemos garantir:
-- A trava pode ser feita logicamente no nível do app, ou excluída de pack drops no futuro.
-- Por enquanto, deixamos documentado que as funções de abrir pacote devem incluir WHERE code != 'COMMON_013'.

COMMIT;
