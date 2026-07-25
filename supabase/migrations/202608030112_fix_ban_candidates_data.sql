BEGIN;

CREATE OR REPLACE FUNCTION public.get_match_ban_candidates(p_match_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    v_user_id uuid := game_private.require_authenticated();
    v_target_id uuid;
    v_result jsonb;
END;
$$;

CREATE OR REPLACE FUNCTION public.get_match_ban_candidates(p_match_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    v_user_id uuid := game_private.require_authenticated();
    v_target_id uuid;
    v_result jsonb;
BEGIN
    IF NOT EXISTS(SELECT 1 FROM public.match_players WHERE match_id=p_match_id AND user_id=v_user_id) THEN
        RAISE EXCEPTION 'NOT_A_MATCH_PLAYER';
    END IF;
    SELECT user_id INTO v_target_id FROM public.match_players
    WHERE match_id=p_match_id AND user_id<>v_user_id;
    IF v_target_id IS NULL THEN RAISE EXCEPTION 'OPPONENT_NOT_FOUND'; END IF;

    SELECT coalesce(jsonb_agg(jsonb_build_object(
        'card_id', x.source_card_id, 'name', x.card_name, 'image_url', x.image_url,
        'rarity', x.rarity, 'card_type', x.card_type, 'is_golden', x.is_golden,
        'copy_count', x.copy_count, 'categories', x.categories,
        'base_power', x.base_power, 'base_max_life', x.base_max_life,
        'effect_text', x.effect_text, 'effect_mana_cost', x.effect_mana_cost
    ) ORDER BY 
        CASE x.rarity 
            WHEN 'legendary' THEN 1 
            WHEN 'epic' THEN 2 
            WHEN 'rare' THEN 3 
            ELSE 4 
        END, x.card_name), '[]'::jsonb)
    INTO v_result
    FROM (
        SELECT mc.source_card_id, max(mdc.card_name) card_name, max(mdc.image_url) image_url,
               max(mdc.rarity) rarity, max(mdc.card_type) card_type,
               bool_or(mdc.is_golden) is_golden, count(*) copy_count,
               max(mdc.base_power) base_power, max(mdc.base_max_life) base_max_life,
               max(c.effect_text) effect_text, max(mdc.effect_mana_cost) effect_mana_cost,
               array_remove(array[
                    CASE WHEN max(mdc.rarity)='rare' THEN 'rare' END,
                    CASE WHEN max(mdc.rarity)='epic' THEN 'epic' END,
                    CASE WHEN max(mdc.rarity)='legendary' THEN 'legendary' END,
                    CASE WHEN bool_or(coalesce(cs.is_collab,false)) THEN 'collab' END,
                    CASE WHEN max(mdc.card_type)='leader' THEN 'leader' END
               ], null) categories
        FROM public.match_cards mc
        JOIN public.match_deck_cards mdc ON mdc.id = mc.match_deck_card_id
        JOIN public.cards c ON c.id = mc.source_card_id
        LEFT JOIN public.card_sets cs ON cs.id = c.set_id
        WHERE mc.match_id = p_match_id 
          AND mc.owner_user_id = v_target_id
          AND mc.zone = 'deck'
          AND NOT EXISTS(
              SELECT 1 FROM public.match_bans mb
              WHERE mb.match_id = p_match_id 
                AND mb.banned_by_user_id = v_user_id
                AND mb.source_card_id = mc.source_card_id
          )
        GROUP BY mc.source_card_id
    ) x;
    
    RETURN v_result;
END;
$$;

COMMIT;
