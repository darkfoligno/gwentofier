BEGIN;

CREATE OR REPLACE FUNCTION public.generate_system_deck()
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_user_id uuid := game_private.require_authenticated();
    v_deck_id uuid;
    v_card_id uuid;
    v_count integer := 0;
BEGIN
    -- Check if already has the system deck
    SELECT id INTO v_deck_id
    FROM public.decks
    WHERE user_id = v_user_id AND name = 'Deck Padrão do Sistema (V38)'
    LIMIT 1;

    IF v_deck_id IS NOT NULL THEN
        RETURN v_deck_id;
    END IF;

    INSERT INTO public.decks (user_id, name, is_valid)
    VALUES (v_user_id, 'Deck Padrão do Sistema (V38)', true)
    RETURNING id INTO v_deck_id;

    -- Add 30 common/basic cards to the deck
    -- We select 30 unique cards for simplicity, or 3 copies of 10 common cards
    FOR v_card_id IN 
        SELECT id FROM public.cards WHERE rarity = 'common' AND is_active = true LIMIT 10
    LOOP
        INSERT INTO public.deck_cards (deck_id, card_id, quantity)
        VALUES (v_deck_id, v_card_id, 3);
        
        -- Also ensure the user has these in their inventory so the deck is valid
        INSERT INTO public.user_inventories (user_id, card_id, quantity)
        VALUES (v_user_id, v_card_id, 3)
        ON CONFLICT (user_id, card_id) DO UPDATE SET quantity = GREATEST(user_inventories.quantity, 3);
    END LOOP;

    RETURN v_deck_id;
END;
$$;

COMMIT;
