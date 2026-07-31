-- Migration 202608030280_fix_geralt_and_geels.sql
-- Corrige o efeito de Geralt de Rivia (LEGENDARY_022) para comprar a carta do topo imediatamente
-- Corrige o efeito de Ge'els (LEGENDARY_002) para trocar a posição de duas cartas da mesma linha no tabuleiro de forma aleatória a partir de um único alvo

BEGIN;

-- 1. Renomear e criar a nova função execute_common_effect_internal (Chain of Responsibility)
ALTER FUNCTION game_private.execute_common_effect_internal(uuid,uuid,uuid,text,jsonb,uuid,jsonb) RENAME TO execute_common_effect_internal_v38_core;

CREATE OR REPLACE FUNCTION game_private.execute_common_effect_internal(
    p_match_id uuid,
    p_actor uuid,
    p_source uuid,
    p_code text,
    p_params jsonb,
    p_target uuid DEFAULT NULL::uuid,
    p_event jsonb DEFAULT NULL::jsonb
)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path = ''
AS $$
DECLARE
    v_ids uuid[];
    v_id uuid;
    v_id2 uuid;
    v_pos integer;
    v_turn integer;
    v_damage jsonb;
    v_result jsonb;
    v_roll integer;
    v_opp_hand jsonb;
    v_opp_grave jsonb;
    v_opponent_id uuid;
    s public.match_cards;
    t public.match_cards;
    opp uuid;
BEGIN
    SELECT * INTO s FROM public.match_cards WHERE id = p_source AND match_id = p_match_id;
    SELECT user_id INTO opp FROM public.match_players WHERE match_id = p_match_id AND user_id != p_actor LIMIT 1;
    SELECT current_turn INTO v_turn FROM public.matches WHERE id = p_match_id;

    IF p_code = 'leg_geralt_double_scry_draw' THEN
        -- Geralt simplesmente compra 1 carta imediatamente do deck
        v_result := game_private.draw_internal(p_match_id, p_actor, 1);
        RETURN jsonb_build_object('success', true, 'drawn_cards', v_result, 'message', 'Geralt comprou a carta do topo do deck imediatamente.');

    ELSIF p_code = 'leg_geels_double_surgical_swap' THEN
        IF p_target IS NULL THEN
            RAISE EXCEPTION 'GEELS_REQUIRES_TARGET_CARD';
        END IF;
        
        SELECT * INTO t FROM public.match_cards WHERE id = p_target AND match_id = p_match_id;
        IF NOT FOUND THEN
            RAISE EXCEPTION 'GEELS_TARGET_CARD_NOT_FOUND';
        END IF;

        -- Sorteia outra carta do mesmo jogador na mesma zona
        SELECT * INTO s FROM public.match_cards
        WHERE match_id = p_match_id
          AND owner_user_id = t.owner_user_id
          AND zone = t.zone
          AND id != t.id
        ORDER BY random() LIMIT 1 FOR UPDATE;

        IF NOT FOUND THEN
            RAISE EXCEPTION 'Nenhuma outra carta disponível na mesma zona para trocar.';
        END IF;

        v_pos := t.zone_position;
        UPDATE public.match_cards SET zone_position = s.zone_position WHERE id = t.id;
        UPDATE public.match_cards SET zone_position = v_pos WHERE id = s.id;

        RETURN jsonb_build_object('success', true, 'swapped_card_1', t.id, 'swapped_card_2', s.id, 'zone', t.zone, 'message', 'Ge''els trocou duas cartas de posição.');

    ELSE
        RETURN game_private.execute_common_effect_internal_v38_core(p_match_id, p_actor, p_source, p_code, p_params, p_target, p_event);
    END IF;
END;
$$;

COMMIT;
