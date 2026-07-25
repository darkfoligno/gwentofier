BEGIN;

-- Atualiza a RPC acknowledge_initiative para ser idempotente e não falhar em chamadas simultâneas/duplicadas
CREATE OR REPLACE FUNCTION public.acknowledge_initiative(p_match_id uuid, p_expected_version bigint default 0)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    v_user_id uuid := game_private.require_authenticated();
    v_match public.matches;
    v_new_version bigint;
BEGIN
    -- Seleciona e tranca a linha do match de forma segura
    SELECT * INTO v_match FROM public.matches WHERE id = p_match_id FOR UPDATE;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'MATCH_NOT_FOUND';
    END IF;
    
    -- Se já foi reconhecido por um dos clientes e está em andamento (in_progress), apenas retorna sucesso de forma idempotente
    IF v_match.status = 'in_progress' THEN
        RETURN jsonb_build_object('success', true, 'state_version', v_match.state_version);
    END IF;
    
    -- Se a partida já passou da iniciativa para qualquer outro status posterior, retorna com sucesso contendo a versão atual
    IF v_match.status NOT IN ('initiative') THEN
        RETURN jsonb_build_object('success', true, 'state_version', v_match.state_version);
    END IF;
    
    -- Começa oficialmente a rodada 1
    UPDATE public.matches SET status = 'in_progress', current_turn = 1 WHERE id = p_match_id;
    
    v_new_version := game_private.record_match_action(
        p_match_id, v_user_id, 'turn_started',
        jsonb_build_object('turn', 1, 'active_player', v_match.active_player_id),
        '{}'::jsonb, p_expected_version
    );

    RETURN jsonb_build_object('success', true, 'state_version', v_new_version);
END;
$$;

COMMIT;
