-- Migration 202608030260_rules_limits_and_enemy_graveyard.sql
-- Implementa Ação 1 (Hand Limit), Ação 2 (Board Limit check), Ação 3 (Heal Cap) e Ação 4 (Enemy Graveyard check constraint)

BEGIN;

-- 1. Alterar check constraint de target_mode na tabela card_effects para incluir 'enemy_graveyard'
ALTER TABLE public.card_effects DROP CONSTRAINT IF EXISTS card_effects_target_check;
ALTER TABLE public.card_effects ADD CONSTRAINT card_effects_target_check CHECK (
    target_mode IN (
        'none','self','ally','enemy','ally_random','enemy_random',
        'all_allies','all_enemies','nearest_life','selected',
        'graveyard','deck','hand','enemy_graveyard'
    )
);

-- 2. Atualizar target_mode no catálogo de cartas para as cartas de roubo do cemitério inimigo
UPDATE public.card_effects ce
SET target_mode = 'enemy_graveyard'
FROM public.cards c
WHERE ce.card_id = c.id
  AND c.name IN ('Hym', 'Súcubo', 'Beann''shie');

-- 3. Redefinir game_private.move_card_checked com travas de limite de mão e de tabuleiro
CREATE OR REPLACE FUNCTION game_private.move_card_checked(
    p_card_id uuid,
    p_zone text,
    p_position integer default null,
    p_face_up boolean default true
) RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE
    v_max_hand integer;
    v_hand_count integer;
    v_board_count integer;
    v_owner uuid;
    v_match uuid;
BEGIN
    IF p_zone NOT IN ('deck','hand','life','reinforcement','attacker','leader','graveyard','banished','temporary') THEN
        RAISE EXCEPTION 'INVALID_DESTINATION_ZONE';
    END IF;

    -- Obter dono e partida da carta
    SELECT owner_user_id, match_id INTO v_owner, v_match 
    FROM public.match_cards 
    WHERE id = p_card_id;

    -- AÇÃO 2: Trava de Limite de Tabuleiro na Ressurreição (Prevenção de Crash)
    IF p_zone IN ('attacker', 'reinforcement') THEN
        SELECT COUNT(*)::integer INTO v_board_count
        FROM public.match_cards
        WHERE match_id = v_match AND owner_user_id = v_owner AND zone = p_zone AND current_life > 0;
        
        IF v_board_count >= 5 THEN
            RAISE EXCEPTION 'Board is full';
        END IF;
    END IF;

    -- AÇÃO 1: Trava de Limite de Mão (maximum_hand_size)
    IF p_zone = 'hand' THEN
        SELECT grv.maximum_hand_size INTO v_max_hand
        FROM public.matches m
        JOIN public.game_rule_versions grv ON grv.id = m.rule_version_id
        WHERE m.id = v_match;

        SELECT COUNT(*)::integer INTO v_hand_count
        FROM public.match_cards
        WHERE match_id = v_match AND owner_user_id = v_owner AND zone = 'hand';

        IF v_hand_count >= COALESCE(v_max_hand, 10) THEN
            -- Redirecionar excesso direto para o cemitério (descarte por mão cheia)
            p_zone := 'graveyard';
            p_position := null;
            p_face_up := true;
        END IF;
    END IF;

    -- Executar a movimentação da carta
    UPDATE public.match_cards 
    SET zone = p_zone, 
        zone_position = p_position, 
        is_face_up = p_face_up, 
        is_destroyed = (p_zone = 'graveyard'), 
        current_life = CASE WHEN p_zone = 'graveyard' THEN 0 ELSE current_life END 
    WHERE id = p_card_id;

    IF NOT FOUND THEN 
        RAISE EXCEPTION 'CARD_NOT_FOUND'; 
    END IF;
END;
$$;

-- 4. Criar gatilho automático de Cap de Cura (Ação 3)
CREATE OR REPLACE FUNCTION game_private.enforce_life_limits_trigger()
RETURNS TRIGGER
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
    -- Se a vida atual está sendo aumentada (cura), garante que não exceda a base de fábrica
    IF NEW.current_life > OLD.current_life THEN
        NEW.current_life := LEAST(NEW.current_life, NEW.base_max_life);
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS enforce_life_limits ON public.match_cards;
CREATE TRIGGER enforce_life_limits
BEFORE UPDATE OF current_life ON public.match_cards
FOR EACH ROW EXECUTE FUNCTION game_private.enforce_life_limits_trigger();

COMMIT;
