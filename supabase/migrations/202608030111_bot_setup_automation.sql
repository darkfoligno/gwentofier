BEGIN;

-- 1. Atualiza public.submit_match_setup para automatizar o Bot em partidas de treino
CREATE OR REPLACE FUNCTION public.submit_match_setup(
    p_match_id uuid,
    p_life_card_ids uuid[],
    p_reinforcement_card_ids uuid[] default array[]::uuid[],
    p_leader_card_id uuid default null,
    p_expected_version bigint default 0
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    v_user_id uuid := game_private.require_authenticated();
    v_match public.matches;
    v_ready boolean;
    v_new_version bigint;
    v_all_ids uuid[];
    v_distinct_count integer;
    v_total_selected integer;
    v_p1 uuid;
    v_p2 uuid;
    v_first uuid;
    v_bot_life uuid[];
    v_card uuid;
    v_reinforcement_count integer := 0;
BEGIN
    v_match := game_private.lock_match_for_action(p_match_id, p_expected_version, array['setup']);
    
    IF EXISTS(SELECT 1 FROM public.match_players WHERE match_id = p_match_id AND user_id = v_user_id AND setup_finished = true) THEN
        RAISE EXCEPTION 'SETUP_ALREADY_SUBMITTED';
    END IF;

    -- OBRIGATÓRIO: EXATAMENTE 3 CARTAS DE VIDA (V38)
    IF coalesce(cardinality(p_life_card_ids), 0) <> 3 THEN 
        RAISE EXCEPTION 'EXACT_LIFE_CARDS_REQUIRED'; 
    END IF;

    -- Validação de duplicatas
    v_all_ids := p_life_card_ids || coalesce(p_reinforcement_card_ids, array[]::uuid[]);
    v_total_selected := cardinality(v_all_ids);
    
    SELECT count(distinct u.id)::integer INTO v_distinct_count FROM unnest(v_all_ids) AS u(id);
    IF v_distinct_count <> v_total_selected THEN
        RAISE EXCEPTION 'DUPLICATED_SETUP_CARD';
    END IF;

    -- Verifica se estão na mão
    IF EXISTS(
        SELECT 1 FROM unnest(v_all_ids) AS selected(id)
        WHERE NOT EXISTS(
            SELECT 1 FROM public.match_cards mc
            WHERE mc.id = selected.id AND mc.match_id = p_match_id AND mc.owner_user_id = v_user_id AND mc.zone = 'hand'
        )
    ) THEN 
        RAISE EXCEPTION 'SETUP_CARD_NOT_IN_HAND'; 
    END IF;

    -- Posicionar vidas do humano
    FOR i IN 1..cardinality(p_life_card_ids) LOOP
        UPDATE public.match_cards SET zone = 'life', zone_position = i, is_face_up = true
        WHERE id = p_life_card_ids[i] AND match_id = p_match_id;
    END LOOP;

    -- Posicionar reforços do humano (ocultos)
    IF p_reinforcement_card_ids IS NOT NULL THEN
        FOR i IN 1..cardinality(p_reinforcement_card_ids) LOOP
            UPDATE public.match_cards SET zone = 'reinforcement', zone_position = i, is_face_up = false
            WHERE id = p_reinforcement_card_ids[i] AND match_id = p_match_id;
        END LOOP;
    END IF;

    UPDATE public.match_players SET setup_finished = true WHERE match_id = p_match_id AND user_id = v_user_id;

    -- Se for Modo Treino, aloca automaticamente as cartas do Bot
    IF EXISTS(SELECT 1 FROM public.training_matches WHERE match_id = p_match_id) THEN
        SELECT bot_user_id INTO v_p2 FROM public.training_matches WHERE match_id = p_match_id;
        
        -- Seleciona as 3 primeiras cartas da mão do bot
        SELECT array_agg(q.id) INTO v_bot_life FROM (
            SELECT mc.id FROM public.match_cards mc 
            WHERE mc.match_id = p_match_id AND mc.owner_user_id = v_p2 AND mc.zone = 'hand' 
            ORDER BY mc.id LIMIT 3
        ) q;
        
        -- Atualiza as cartas do bot para a zona life
        IF cardinality(v_bot_life) = 3 THEN
            FOR i IN 1..3 LOOP
                UPDATE public.match_cards SET zone = 'life', zone_position = i, is_face_up = true
                WHERE id = v_bot_life[i] AND match_id = p_match_id;
            END LOOP;
        END IF;
        
        -- Aloca 1 reforço opcional para o bot (4ª carta da mão)
        SELECT mc.id INTO v_card FROM public.match_cards mc
        WHERE mc.match_id = p_match_id AND mc.owner_user_id = v_p2 AND mc.zone = 'hand'
          AND mc.id NOT IN (SELECT * FROM unnest(v_bot_life))
        ORDER BY mc.id LIMIT 1;
        
        IF v_card IS NOT NULL THEN
            UPDATE public.match_cards SET zone = 'reinforcement', zone_position = 1, is_face_up = false
            WHERE id = v_card AND match_id = p_match_id;
            v_reinforcement_count := 1;
        END IF;
        
        UPDATE public.match_players SET setup_finished = true WHERE match_id = p_match_id AND user_id = v_p2;
    END IF;

    SELECT count(*) = 2 INTO v_ready FROM public.match_players WHERE match_id = p_match_id AND setup_finished = true;

    IF v_ready THEN
        -- RNG da Moeda 3D
        SELECT user_id INTO v_p1 FROM public.match_players WHERE match_id = p_match_id AND player_number = 1;
        SELECT user_id INTO v_p2 FROM public.match_players WHERE match_id = p_match_id AND player_number = 2;
        
        IF random() <= 0.5 THEN
            v_first := v_p1;
        ELSE
            v_first := v_p2;
        END IF;

        UPDATE public.matches 
        SET status = 'initiative', 
            initiative_result = jsonb_build_object('coin_flip', true, 'first_player', v_first),
            active_player_id = v_first
        WHERE id = p_match_id;
    END IF;

    PERFORM game_private.recalculate_match_public_state(p_match_id);

    v_new_version := game_private.record_match_action(
        p_match_id, v_user_id, 'setup_submitted',
        jsonb_build_object('life_cards', p_life_card_ids, 'reinforcement_cards', p_reinforcement_card_ids, 'all_ready', v_ready, 'bot_reinforcement_count', v_reinforcement_count),
        '{}'::jsonb, p_expected_version
    );

    RETURN jsonb_build_object('all_ready', v_ready, 'state_version', v_new_version);
END;
$$;

-- 2. Atualiza public.submit_training_setup para alinhar com o mesmo fluxo de iniciativa
CREATE OR REPLACE FUNCTION public.submit_training_setup(
  p_match_id uuid,
  p_life_card_ids uuid[],
  p_reinforcement_card_ids uuid[] default array[]::uuid[],
  p_expected_version bigint default 0
)
RETURNS jsonb 
LANGUAGE plpgsql 
SECURITY DEFINER 
SET search_path = '' 
AS $$
DECLARE
  v_human uuid := game_private.require_authenticated();
  v_bot uuid;
  v_match public.matches;
  v_bot_life uuid[];
  v_bot_reinforcement uuid[];
  v_all uuid[];
  v_version bigint;
  v_active uuid;
  v_human_roll integer;
  v_bot_roll integer;
  v_reinforcement_count integer;
  v_setup_roll double precision;
BEGIN
  SELECT tm.bot_user_id INTO v_bot FROM public.training_matches tm WHERE tm.match_id = p_match_id AND tm.human_user_id = v_human;
  IF v_bot IS NULL THEN 
      RAISE EXCEPTION 'NOT_YOUR_TRAINING_MATCH'; 
  END IF;
  
  v_match := game_private.lock_match_for_action(p_match_id, p_expected_version, array['setup']);
  
  IF cardinality(p_life_card_ids) <> 3 OR (SELECT count(distinct x) FROM unnest(p_life_card_ids) x) <> 3 THEN 
      RAISE EXCEPTION 'EXACTLY_THREE_DISTINCT_LIFE_CARDS_REQUIRED'; 
  END IF;
  
  IF coalesce(cardinality(p_reinforcement_card_ids), 0) > 4 THEN 
      RAISE EXCEPTION 'TOO_MANY_REINFORCEMENTS'; 
  END IF;
  
  v_all := p_life_card_ids || coalesce(p_reinforcement_card_ids, array[]::uuid[]);
  IF (SELECT count(distinct x) FROM unnest(v_all) x) <> cardinality(v_all) THEN 
      RAISE EXCEPTION 'DUPLICATED_SETUP_CARD'; 
  END IF;
  
  IF EXISTS(SELECT 1 FROM unnest(v_all) x WHERE NOT EXISTS(SELECT 1 FROM public.match_cards mc WHERE mc.id = x and mc.match_id = p_match_id and mc.owner_user_id = v_human and mc.zone = 'hand')) THEN 
      RAISE EXCEPTION 'SETUP_CARD_NOT_IN_HAND'; 
  END IF;
  
  -- Aloca cartas do humano
  UPDATE public.match_cards mc SET zone = 'life', zone_position = x.ord, is_face_up = true, entered_zone_turn = 0 
  FROM unnest(p_life_card_ids) WITH ORDINALITY x(id,ord) WHERE mc.id = x.id;
  
  UPDATE public.match_cards mc SET zone = 'reinforcement', zone_position = x.ord, is_face_up = false, entered_zone_turn = 0 
  FROM unnest(coalesce(p_reinforcement_card_ids, array[]::uuid[])) WITH ORDINALITY x(id,ord) WHERE mc.id = x.id;

  -- Aloca cartas do bot
  SELECT array_agg(q.id order by q.maximum_life desc, q.id) INTO v_bot_life FROM (
      SELECT mc.id, mc.maximum_life FROM public.match_cards mc 
      WHERE mc.match_id = p_match_id AND mc.owner_user_id = v_bot AND mc.zone = 'hand' 
      ORDER BY mc.maximum_life desc, mc.id LIMIT 3
  ) q;
  
  UPDATE public.match_cards mc SET zone = 'life', zone_position = x.ord, is_face_up = true, entered_zone_turn = 0 
  FROM unnest(v_bot_life) WITH ORDINALITY x(id,ord) WHERE mc.id = x.id;
  
  v_setup_roll := random();
  v_reinforcement_count := CASE WHEN v_setup_roll < 0.30 THEN 1 WHEN v_setup_roll < 0.80 THEN 2 ELSE 3 END;
  
  SELECT array_agg(q.id order by q.maximum_life desc, q.id) INTO v_bot_reinforcement FROM (
      SELECT mc.id, mc.maximum_life FROM public.match_cards mc 
      WHERE mc.match_id = p_match_id AND mc.owner_user_id = v_bot AND mc.zone = 'hand' 
      ORDER BY mc.maximum_life desc, mc.id LIMIT v_reinforcement_count
  ) q;
  
  UPDATE public.match_cards mc SET zone = 'reinforcement', zone_position = x.ord, is_face_up = false, entered_zone_turn = 0 
  FROM unnest(coalesce(v_bot_reinforcement, array[]::uuid[])) WITH ORDINALITY x(id,ord) WHERE mc.id = x.id;

  -- Moeda do D20 / Iniciativa
  LOOP 
      v_human_roll := floor(random()*20+1)::integer; 
      v_bot_roll := floor(random()*20+1)::integer; 
      EXIT WHEN v_human_roll <> v_bot_roll; 
  END LOOP;
  v_active := CASE WHEN v_human_roll > v_bot_roll THEN v_human ELSE v_bot END;
  
  UPDATE public.match_players SET setup_finished = true WHERE match_id = p_match_id;
  PERFORM game_private.sync_player_hand_mana(p_match_id, v_human); 
  PERFORM game_private.sync_player_hand_mana(p_match_id, v_bot);
  
  -- Transiciona para status = 'initiative' para rodar a animação 3D da moeda no front-end
  UPDATE public.matches 
  SET status = 'initiative', 
      initiative_result = jsonb_build_object('coin_flip', true, 'first_player', v_active, 'player1', v_human_roll, 'player2', v_bot_roll, 'winner_user_id', v_active),
      active_player_id = v_active 
  WHERE id = p_match_id;
  
  v_version := game_private.record_match_action(
      p_match_id, v_human, 'setup_submitted',
      jsonb_build_object(
          'player_user_id', v_human, 
          'life_count', 3, 
          'reinforcement_count', cardinality(p_reinforcement_card_ids), 
          'bot_reinforcement_count', v_reinforcement_count, 
          'setup_complete', true, 
          'active_player_id', v_active, 
          'initiative', jsonb_build_object('mode', 'd20', 'player1', v_human_roll, 'player2', v_bot_roll, 'winner_user_id', v_active)
      ),
      jsonb_build_object('life_card_ids', p_life_card_ids, 'reinforcement_card_ids', p_reinforcement_card_ids), 
      p_expected_version
  );
  
  RETURN jsonb_build_object('match_started', true, 'active_player_id', v_active, 'state_version', v_version, 'bot_reinforcement_count', v_reinforcement_count);
END;
$$;

COMMIT;
