-- Trade Marketing Migration
CREATE TABLE IF NOT EXISTS public.trade_listings (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    seller_user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    card_id uuid NOT NULL REFERENCES public.cards(id) ON DELETE CASCADE,
    status text NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'completed', 'cancelled')),
    seller_ip text NOT NULL,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now()
);

-- Enable RLS
ALTER TABLE public.trade_listings ENABLE ROW LEVEL SECURITY;

-- Select policy: Anyone can see active listings, sellers can see their own listings
CREATE POLICY select_trade_listings ON public.trade_listings
    FOR SELECT USING (true);

-- Insert policy: User must be authenticated and seller_user_id must match auth.uid()
CREATE POLICY insert_trade_listings ON public.trade_listings
    FOR INSERT WITH CHECK (auth.uid() = seller_user_id);

-- Update policy: Sellers can cancel or update their own listings
CREATE POLICY update_trade_listings ON public.trade_listings
    FOR UPDATE USING (auth.uid() = seller_user_id);

-- Helper function to validate user requirements
CREATE OR REPLACE FUNCTION public.check_trade_eligibility(p_user_id uuid)
RETURNS TABLE(is_eligible boolean, reason text)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_avatar_url text;
    v_total_cards integer;
BEGIN
    -- 1. Check avatar
    SELECT avatar_url INTO v_avatar_url FROM public.profiles WHERE id = p_user_id;
    IF v_avatar_url IS NULL OR v_avatar_url = '' THEN
        RETURN QUERY SELECT false, 'O avatar não pode ser o padrão do sistema. Personalize seu perfil!'::text;
        RETURN;
    END IF;

    -- 2. Check card collection total
    SELECT COALESCE(SUM(quantity), 0) INTO v_total_cards FROM public.user_cards WHERE user_id = p_user_id;
    IF v_total_cards < 20 THEN
        RETURN QUERY SELECT false, 'Você precisa ter pelo menos 20 cartas no total na sua coleção para acessar o comércio!'::text;
        RETURN;
    END IF;

    RETURN QUERY SELECT true, 'Eligible'::text;
END;
$$;

-- Create Trade Listing RPC
CREATE OR REPLACE FUNCTION public.create_trade_listing(p_card_id uuid)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_user_id uuid := game_private.require_authenticated();
    v_client_ip text;
    v_eligible boolean;
    v_reason text;
    v_qty integer;
    v_listing_id uuid;
BEGIN
    -- Check eligibility
    SELECT is_eligible, reason INTO v_eligible, v_reason FROM public.check_trade_eligibility(v_user_id);
    IF NOT v_eligible THEN
        RAISE EXCEPTION '%', v_reason;
    END IF;

    -- Verify quantity > 1
    SELECT quantity INTO v_qty FROM public.user_cards WHERE user_id = v_user_id AND card_id = p_card_id;
    IF v_qty IS NULL OR v_qty <= 1 THEN
        RAISE EXCEPTION 'Você só pode anunciar cartas repetidas (quantidade > 1).';
    END IF;

    -- Get IP
    v_client_ip := coalesce(
        current_setting('request.headers', true)::jsonb->>'x-forwarded-for',
        current_setting('request.headers', true)::jsonb->>'cf-connecting-ip',
        '127.0.0.1'
    );

    -- Decrement quantity from free inventory
    UPDATE public.user_cards 
    SET quantity = quantity - 1 
    WHERE user_id = v_user_id AND card_id = p_card_id;

    -- Insert listing
    INSERT INTO public.trade_listings (seller_user_id, card_id, status, seller_ip)
    VALUES (v_user_id, p_card_id, 'active', v_client_ip)
    RETURNING id INTO v_listing_id;

    RETURN v_listing_id;
END;
$$;

-- Cancel Trade Listing RPC
CREATE OR REPLACE FUNCTION public.cancel_trade_listing(p_trade_listing_id uuid)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_user_id uuid := game_private.require_authenticated();
    v_seller_id uuid;
    v_card_id uuid;
    v_status text;
BEGIN
    SELECT seller_user_id, card_id, status INTO v_seller_id, v_card_id, v_status 
    FROM public.trade_listings 
    WHERE id = p_trade_listing_id;

    IF v_seller_id IS NULL THEN
        RAISE EXCEPTION 'Anúncio não encontrado.';
    END IF;

    IF v_seller_id <> v_user_id THEN
        RAISE EXCEPTION 'Apenas o vendedor pode cancelar este anúncio.';
    END IF;

    IF v_status <> 'active' THEN
        RAISE EXCEPTION 'Este anúncio já foi concluído ou cancelado.';
    END IF;

    -- Update status
    UPDATE public.trade_listings 
    SET status = 'cancelled', updated_at = now() 
    WHERE id = p_trade_listing_id;

    -- Restore unit to seller
    INSERT INTO public.user_cards (user_id, card_id, quantity, first_obtained_at, last_obtained_at, is_new)
    VALUES (v_user_id, v_card_id, 1, now(), now(), false)
    ON CONFLICT (user_id, card_id) 
    DO UPDATE SET quantity = public.user_cards.quantity + 1, last_obtained_at = now();

    RETURN true;
END;
$$;

-- Execute Atomic Trade RPC
CREATE OR REPLACE FUNCTION public.execute_card_trade(p_trade_listing_id uuid, p_buyer_offered_card_id uuid)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_buyer_id uuid := game_private.require_authenticated();
    v_buyer_ip text;
    v_eligible boolean;
    v_reason text;
    
    -- Listing info
    v_seller_id uuid;
    v_listed_card_id uuid;
    v_seller_ip text;
    v_status text;
    
    -- Rarity info
    v_listed_rarity text;
    v_offered_rarity text;
    
    -- Buyer inventory info
    v_buyer_offered_qty integer;
BEGIN
    -- Check eligibility of buyer
    SELECT is_eligible, reason INTO v_eligible, v_reason FROM public.check_trade_eligibility(v_buyer_id);
    IF NOT v_eligible THEN
        RAISE EXCEPTION '%', v_reason;
    END IF;

    -- Fetch listing
    SELECT seller_user_id, card_id, seller_ip, status INTO v_seller_id, v_listed_card_id, v_seller_ip, v_status
    FROM public.trade_listings
    WHERE id = p_trade_listing_id;

    IF v_seller_id IS NULL THEN
        RAISE EXCEPTION 'Anúncio não encontrado.';
    END IF;

    IF v_status <> 'active' THEN
        RAISE EXCEPTION 'Este anúncio não está mais ativo.';
    END IF;

    -- Cannot trade with oneself
    IF v_seller_id = v_buyer_id THEN
        RAISE EXCEPTION 'Você não pode realizar trocas com seus próprios anúncios.';
    END IF;

    -- IP/Device matching check (Anti-Smurf)
    v_buyer_ip := coalesce(
        current_setting('request.headers', true)::jsonb->>'x-forwarded-for',
        current_setting('request.headers', true)::jsonb->>'cf-connecting-ip',
        '127.0.0.1'
    );

    IF v_seller_ip = v_buyer_ip THEN
        RAISE EXCEPTION 'Trocas entre contas no mesmo IP/rede recente são estritamente proibidas.';
    END IF;

    -- Check rarities match
    SELECT rarity INTO v_listed_rarity FROM public.cards WHERE id = v_listed_card_id;
    SELECT rarity INTO v_offered_rarity FROM public.cards WHERE id = p_buyer_offered_card_id;

    IF v_listed_rarity IS NULL OR v_offered_rarity IS NULL THEN
        RAISE EXCEPTION 'Uma das cartas especificadas não existe.';
    END IF;

    IF v_listed_rarity <> v_offered_rarity THEN
        RAISE EXCEPTION 'As cartas trocadas devem possuir exatamente a mesma raridade (% vs %).', v_listed_rarity, v_offered_rarity;
    END IF;

    -- Check if buyer has the offered card with qty > 1
    SELECT quantity INTO v_buyer_offered_qty FROM public.user_cards 
    WHERE user_id = v_buyer_id AND card_id = p_buyer_offered_card_id;

    IF v_buyer_offered_qty IS NULL OR v_buyer_offered_qty <= 1 THEN
        RAISE EXCEPTION 'Você só pode oferecer cartas repetidas (quantidade > 1) de sua coleção.';
    END IF;

    -- Perform the trade atomically
    -- 1. Deduct offered card from buyer
    UPDATE public.user_cards 
    SET quantity = quantity - 1 
    WHERE user_id = v_buyer_id AND card_id = p_buyer_offered_card_id;

    -- 2. Add offered card to seller
    INSERT INTO public.user_cards (user_id, card_id, quantity, first_obtained_at, last_obtained_at, is_new)
    VALUES (v_seller_id, p_buyer_offered_card_id, 1, now(), now(), false)
    ON CONFLICT (user_id, card_id) 
    DO UPDATE SET quantity = public.user_cards.quantity + 1, last_obtained_at = now();

    -- 3. Add listed card to buyer (already deducted from seller upon listing creation)
    INSERT INTO public.user_cards (user_id, card_id, quantity, first_obtained_at, last_obtained_at, is_new)
    VALUES (v_buyer_id, v_listed_card_id, 1, now(), now(), false)
    ON CONFLICT (user_id, card_id) 
    DO UPDATE SET quantity = public.user_cards.quantity + 1, last_obtained_at = now();

    -- 4. Mark listing completed
    UPDATE public.trade_listings 
    SET status = 'completed', updated_at = now() 
    WHERE id = p_trade_listing_id;

    RETURN true;
END;
$$;
