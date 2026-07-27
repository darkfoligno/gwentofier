-- Migration to implement card recycling and database function for Gwentofier
CREATE OR REPLACE FUNCTION public.recycle_user_cards(p_card_ids uuid[])
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_user_id uuid;
    v_total_coins bigint := 0;
    v_card_id uuid;
    v_rarity text;
    v_coins_gained bigint;
    v_count integer := 0;
BEGIN
    v_user_id := auth.uid();
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'User not authenticated';
    END IF;

    FOREACH v_card_id IN ARRAY p_card_ids LOOP
        SELECT rarity INTO v_rarity FROM public.cards WHERE id = v_card_id;
        
        IF v_rarity = 'common' THEN
            v_coins_gained := 10;
        ELSIF v_rarity = 'rare' THEN
            v_coins_gained := 25;
        ELSIF v_rarity = 'epic' THEN
            v_coins_gained := 100;
        ELSIF v_rarity = 'legendary' THEN
            v_coins_gained := 250;
        ELSE
            v_coins_gained := 0;
        END IF;

        IF EXISTS(SELECT 1 FROM public.user_cards WHERE user_id = v_user_id AND card_id = v_card_id AND quantity > 0) THEN
            UPDATE public.user_cards 
            SET quantity = quantity - 1 
            WHERE user_id = v_user_id AND card_id = v_card_id;
            
            v_total_coins := v_total_coins + v_coins_gained;
            v_count := v_count + 1;
        END IF;
    END LOOP;

    IF v_total_coins > 0 THEN
        INSERT INTO public.player_wallets (user_id, coins, updated_at)
        VALUES (v_user_id, v_total_coins, now())
        ON CONFLICT (user_id) 
        DO UPDATE SET coins = public.player_wallets.coins + EXCLUDED.coins, updated_at = now();
    END IF;

    RETURN jsonb_build_object(
        'success', true,
        'cards_recycled', v_count,
        'coins_gained', v_total_coins
    );
END;
$$;

CREATE OR REPLACE FUNCTION public.get_card_owners(p_card_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_res jsonb;
BEGIN
    SELECT coalesce(jsonb_agg(jsonb_build_object(
        'username', coalesce(p.username, 'Duelista Anônimo'),
        'quantity', uc.quantity
    )), '[]'::jsonb) INTO v_res
    FROM public.user_cards uc
    JOIN public.profiles p ON p.id = uc.user_id
    WHERE uc.card_id = p_card_id AND uc.quantity > 0
    ORDER BY uc.quantity DESC, p.username ASC
    LIMIT 10;
    
    RETURN v_res;
END;
$$;
