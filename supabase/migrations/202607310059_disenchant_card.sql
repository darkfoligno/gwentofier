-- Migration 202607310059_disenchant_card.sql
BEGIN;

CREATE OR REPLACE FUNCTION disenchant_card(p_user_id uuid, p_card_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_qty integer;
    v_rarity text;
    v_coin_gain integer;
BEGIN
    SELECT quantity INTO v_qty FROM public.user_cards WHERE user_id = p_user_id AND card_id = p_card_id FOR UPDATE;
    IF v_qty IS NULL OR v_qty < 1 THEN
        RETURN jsonb_build_object('success', false, 'error', 'Você não possui esta carta.');
    END IF;

    SELECT rarity INTO v_rarity FROM public.cards WHERE id = p_card_id;
    IF v_rarity = 'common' THEN v_coin_gain := 10;
    ELSIF v_rarity = 'rare' THEN v_coin_gain := 30;
    ELSIF v_rarity = 'epic' THEN v_coin_gain := 100;
    ELSIF v_rarity = 'legendary' THEN v_coin_gain := 300;
    ELSE v_coin_gain := 0;
    END IF;

    IF v_qty = 1 THEN
        DELETE FROM public.user_cards WHERE user_id = p_user_id AND card_id = p_card_id;
    ELSE
        UPDATE public.user_cards SET quantity = quantity - 1 WHERE user_id = p_user_id AND card_id = p_card_id;
    END IF;

    UPDATE public.player_wallets SET coins = coins + v_coin_gain WHERE user_id = p_user_id;

    RETURN jsonb_build_object('success', true, 'coins_gained', v_coin_gain);
END;
$$;

COMMIT;
