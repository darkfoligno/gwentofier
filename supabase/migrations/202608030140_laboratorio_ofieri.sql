-- Migration to implement the Laboratório Ofieri card testing tables and RPC functions
CREATE TABLE IF NOT EXISTS public.user_card_lab_rewards (
    user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    card_id uuid NOT NULL REFERENCES public.cards(id) ON DELETE CASCADE,
    claimed_at timestamp with time zone DEFAULT now() NOT NULL,
    PRIMARY KEY (user_id, card_id)
);

ALTER TABLE public.user_card_lab_rewards ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Allow users to read their own lab rewards"
    ON public.user_card_lab_rewards
    FOR SELECT
    TO authenticated
    USING (auth.uid() = user_id);

CREATE OR REPLACE FUNCTION public.claim_lab_reward(p_card_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_user_id uuid;
    v_already_claimed boolean := false;
BEGIN
    v_user_id := auth.uid();
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'User not authenticated';
    END IF;

    IF NOT EXISTS(SELECT 1 FROM public.cards WHERE id = p_card_id) THEN
        RAISE EXCEPTION 'Card does not exist';
    END IF;

    SELECT EXISTS(
        SELECT 1 FROM public.user_card_lab_rewards 
        WHERE user_id = v_user_id AND card_id = p_card_id
    ) INTO v_already_claimed;

    IF v_already_claimed THEN
        RETURN jsonb_build_object(
            'success', true,
            'reward', 0,
            'first_time', false
        );
    ELSE
        INSERT INTO public.user_card_lab_rewards(user_id, card_id, claimed_at)
        VALUES(v_user_id, p_card_id, now());

        INSERT INTO public.player_wallets (user_id, coins, updated_at)
        VALUES (v_user_id, 25, now())
        ON CONFLICT (user_id) 
        DO UPDATE SET coins = public.player_wallets.coins + EXCLUDED.coins, updated_at = now();

        RETURN jsonb_build_object(
            'success', true,
            'reward', 25,
            'first_time', true
        );
    END IF;
END;
$$;

CREATE OR REPLACE FUNCTION public.get_user_claimed_lab_cards()
RETURNS uuid[]
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_user_id uuid;
    v_res uuid[];
BEGIN
    v_user_id := auth.uid();
    IF v_user_id IS NULL THEN
        RETURN '{}'::uuid[];
    END IF;

    SELECT array_agg(card_id) INTO v_res
    FROM public.user_card_lab_rewards
    WHERE user_id = v_user_id;

    RETURN coalesce(v_res, '{}'::uuid[]);
END;
$$;

CREATE OR REPLACE FUNCTION public.start_lab_match(p_test_card_id uuid)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_match_id uuid;
    v_user_id uuid := game_private.require_authenticated();
    v_card_record record;
    v_mdc_id uuid;
BEGIN
    SELECT * INTO v_card_record FROM public.cards WHERE id = p_test_card_id;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Card not found';
    END IF;

    SELECT start_training_match('SYSTEM_GENERATED') INTO v_match_id;

    SELECT id INTO v_mdc_id 
    FROM public.match_cards 
    WHERE match_id = v_match_id AND owner_user_id = v_user_id 
    LIMIT 1;

    UPDATE public.match_deck_cards mdc
    SET 
        source_card_id = v_card_record.id,
        card_version = v_card_record.version,
        card_name = v_card_record.name,
        image_url = coalesce(v_card_record.image_url, ''),
        element = coalesce(v_card_record.element, 'Neutro'),
        rarity = v_card_record.rarity,
        card_type = v_card_record.card_type,
        is_golden = v_card_record.is_golden,
        base_power = coalesce(v_card_record.base_power, 0),
        base_max_life = coalesce(v_card_record.base_max_life, 0),
        effect_mana_cost = coalesce(v_card_record.effect_mana_cost, 0),
        effect_definition = coalesce(
            (select jsonb_agg(jsonb_build_object('effect_order', ce.effect_order, 'trigger_type', ce.trigger_type, 'effect_code', ce.effect_code, 'target_mode', ce.target_mode, 'parameters', ce.parameters, 'priority', ce.priority, 'is_reaction', ce.is_reaction, 'once_per_turn', ce.once_per_turn) order by ce.effect_order) 
             from public.card_effects ce 
             where ce.card_id = v_card_record.id and ce.is_active = true), 
            '[]'::jsonb
        )
    WHERE id = (SELECT match_deck_card_id FROM public.match_cards WHERE id = v_mdc_id);

    UPDATE public.match_cards
    SET 
        source_card_id = v_card_record.id,
        zone = 'hand',
        zone_position = 99,
        is_face_up = true,
        base_power = coalesce(v_card_record.base_power, 0),
        base_max_life = coalesce(v_card_record.base_max_life, 0),
        current_power = coalesce(v_card_record.base_power, 0),
        maximum_power = coalesce(v_card_record.base_power, 0),
        current_life = coalesce(v_card_record.base_max_life, 0),
        maximum_life = coalesce(v_card_record.base_max_life, 0)
    WHERE id = v_mdc_id;

    UPDATE public.match_players 
    SET mana_available = 15, mana_snapshot = 15 
    WHERE match_id = v_match_id AND user_id = v_user_id;

    RETURN v_match_id;
END;
$$;
