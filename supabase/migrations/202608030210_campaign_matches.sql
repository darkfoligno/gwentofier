-- Campaign Mode Database and AI Implementation
-- Rei dos Mendigos Boss Match

-- 1. Campaign match bot turn execution
CREATE OR REPLACE FUNCTION public.run_campaign_bot_turn(p_match_id uuid, p_expected_version bigint)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
  v_human_id uuid := game_private.require_authenticated();
  v_bot_id uuid := '00000000-0000-4000-8000-000000000071'::uuid;
  v_match public.matches;
  v_chosen_card_id uuid;
  v_slot integer;
  v_version bigint := p_expected_version;
  v_pending_attack_id uuid;
  v_total_power integer;
  v_attacker_ids uuid[];
  v_reinforcement_count integer;
  v_hand_count integer;
  v_human_reinforcements integer;
  v_human_life_count integer;
  v_last_life_hp integer;
  v_existing_attack_power integer;
  v_best_hand_power integer;
  v_lethal_opportunity boolean := false;
  v_failure_state text;
  v_failure_message text;
  v_card_to_play record;
  v_mana_avail integer;
BEGIN
  SELECT m.* INTO v_match FROM public.matches m WHERE m.id = p_match_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'MATCH_NOT_FOUND'; END IF;
  IF v_match.state_version <> p_expected_version THEN RAISE EXCEPTION 'STALE_MATCH_VERSION'; END IF;
  IF v_match.status <> 'in_progress' OR v_match.engine_state <> 'turn_action' THEN RAISE EXCEPTION 'MATCH_FLOW_IS_BLOCKED'; END IF;
  IF v_match.active_player_id <> v_bot_id THEN RAISE EXCEPTION 'BOT_IS_NOT_ACTIVE_PLAYER'; END IF;

  SELECT count(*)::integer INTO v_hand_count
  FROM public.match_cards mc
  WHERE mc.match_id = p_match_id AND mc.owner_user_id = v_bot_id AND mc.zone = 'hand';

  SELECT mana_available INTO v_mana_avail FROM public.match_players WHERE match_id = p_match_id AND user_id = v_bot_id;

  -- Regra A & D: Play cards from hand
  -- We exclude "Rei dos Mendigos" (a5dcdb5a-92d9-42ef-89ef-1ccbbecada40) unless it is the last card in hand
  SELECT mc.* INTO v_card_to_play
  FROM public.match_cards mc
  WHERE mc.match_id = p_match_id 
    AND mc.owner_user_id = v_bot_id 
    AND mc.zone = 'hand'
    AND (v_hand_count = 1 OR mc.source_card_id <> 'a5dcdb5a-92d9-42ef-89ef-1ccbbecada40'::uuid)
  ORDER BY mc.current_power DESC, mc.id ASC
  LIMIT 1;

  IF v_card_to_play IS NOT NULL THEN
      SELECT count(*)::integer INTO v_reinforcement_count
      FROM public.match_cards mc
      WHERE mc.match_id = p_match_id AND mc.controller_user_id = v_bot_id
        AND mc.zone = 'reinforcement' AND mc.current_life > 0;

      IF v_reinforcement_count < 4 THEN
          SELECT gs.slot INTO v_slot FROM generate_series(1,4) gs(slot)
          WHERE NOT EXISTS(
            SELECT 1 FROM public.match_cards mc WHERE mc.match_id = p_match_id
              AND mc.controller_user_id = v_bot_id AND mc.zone = 'reinforcement' AND mc.zone_position = gs.slot
          ) ORDER BY gs.slot LIMIT 1;

          IF v_slot IS NOT NULL THEN
              UPDATE public.match_cards SET zone='reinforcement', zone_position=v_slot, is_face_up=false, entered_zone_turn=v_match.current_turn WHERE id=v_card_to_play.id;
              UPDATE public.match_players SET actions_this_turn=actions_this_turn+1 WHERE match_id=p_match_id AND user_id=v_bot_id;
              v_version := game_private.record_match_action(p_match_id,v_bot_id,'card_played',jsonb_build_object('match_card_id',v_card_to_play.id,'destination_zone','reinforcement','destination_position',v_slot,'campaign_bot',true,'hand_retained',v_hand_count-1),'{}'::jsonb,v_version);
              RETURN jsonb_build_object('action','reinforcement_played','state_version',v_version,'hand_retained',v_hand_count-1);
          END IF;
      ELSE
          SELECT gs.slot INTO v_slot FROM generate_series(1,4) gs(slot)
          WHERE NOT EXISTS(
            SELECT 1 FROM public.match_cards mc WHERE mc.match_id = p_match_id
              AND mc.controller_user_id = v_bot_id AND mc.zone = 'attacker' AND mc.zone_position = gs.slot
          ) ORDER BY gs.slot LIMIT 1;

          IF v_slot IS NOT NULL THEN
              UPDATE public.match_cards SET zone='attacker', zone_position=v_slot, is_face_up=true, entered_zone_turn=v_match.current_turn WHERE id=v_card_to_play.id;
              UPDATE public.match_players SET actions_this_turn=actions_this_turn+1 WHERE match_id=p_match_id AND user_id=v_bot_id;
              v_version := game_private.record_match_action(p_match_id,v_bot_id,'card_played',jsonb_build_object('match_card_id',v_card_to_play.id,'destination_zone','attacker','destination_position',v_slot,'campaign_bot',true,'hand_retained',v_hand_count-1),'{}'::jsonb,v_version);
              RETURN jsonb_build_object('action','attacker_played','state_version',v_version,'hand_retained',v_hand_count-1);
          END IF;
      END IF;
  END IF;

  -- Attack logic
  SELECT array_agg(mc.id ORDER BY mc.zone_position), sum(mc.current_power)::integer
  INTO v_attacker_ids, v_total_power
  from public.match_cards mc
  where mc.match_id=p_match_id and mc.controller_user_id=v_bot_id and mc.zone='attacker'
    and mc.current_life>0 and mc.can_attack and not mc.has_attacked_this_turn;

  IF coalesce(cardinality(v_attacker_ids),0)>0 THEN
    SELECT count(*)::integer, max(mc.current_life)::integer
    INTO v_human_life_count, v_last_life_hp
    FROM public.match_cards mc
    WHERE mc.match_id = p_match_id AND mc.controller_user_id = v_human_id
      AND mc.zone = 'life' AND mc.current_life > 0;

    INSERT INTO public.pending_attacks(match_id,attacker_user_id,defender_user_id,status,is_direct,declared_power,reaction_deadline,declared_state_version)
    VALUES (p_match_id,v_bot_id,v_human_id,'awaiting_reaction',false,v_total_power,clock_timestamp()+interval '45 seconds',v_version)
    RETURNING id INTO v_pending_attack_id;
    
    INSERT INTO public.pending_attack_cards(pending_attack_id,match_card_id,attack_position,power_when_declared)
    SELECT v_pending_attack_id, attack_card.id, attack_card.ordinality::integer,
      (select mc.current_power from public.match_cards mc where mc.id=attack_card.id)
    from unnest(v_attacker_ids) with ordinality attack_card(id,ordinality);
    
    UPDATE public.match_cards mc set metadata=mc.metadata||jsonb_build_object('locked_for_pending_attack',v_pending_attack_id) where mc.id=any(v_attacker_ids);
    UPDATE public.match_players mp set actions_this_turn=mp.actions_this_turn+1 where mp.match_id=p_match_id and mp.user_id=v_bot_id;
    v_version := game_private.record_match_action(p_match_id,v_bot_id,'attack_declared',jsonb_build_object('pending_attack_id',v_pending_attack_id,'attacker_user_id',v_bot_id,'defender_user_id',v_human_id,'attacker_card_ids',to_jsonb(v_attacker_ids),'total_power',v_total_power,'is_direct',false,'campaign_bot',true),'{}'::jsonb,v_version);
    UPDATE public.pending_attacks pa set declared_state_version=v_version where pa.id=v_pending_attack_id;
    RETURN jsonb_build_object('action','attack_declared','state_version',v_version,'pending_attack_id',v_pending_attack_id);
  END IF;

  RETURN game_private.change_active_turn(p_match_id,v_bot_id,
    coalesce((select mp.actions_this_turn=0 from public.match_players mp where mp.match_id=p_match_id and mp.user_id=v_bot_id),true),v_version)
    ||jsonb_build_object('action','mana_preserved','hand_retained',v_hand_count);

EXCEPTION WHEN OTHERS THEN
  GET STACKED DIAGNOSTICS v_failure_state=returned_sqlstate, v_failure_message=message_text;
  SELECT m.* INTO v_match from public.matches m where m.id=p_match_id for update;
  IF v_match.active_player_id=v_bot_id and v_match.state_version=p_expected_version THEN
    return game_private.change_active_turn(p_match_id,v_bot_id,false,p_expected_version)
      ||jsonb_build_object('action','safe_fallback_end_turn','bot_error_code',v_failure_state,'bot_error_message',v_failure_message);
  END IF;
  RAISE;
END;
$function$;


-- 2. Campaign match bot reaction execution (Baltazar direct attack block)
CREATE OR REPLACE FUNCTION public.auto_resolve_campaign_attack(p_match_id uuid, p_expected_version bigint)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
  human uuid := game_private.require_authenticated();
  bot uuid := '00000000-0000-4000-8000-000000000071'::uuid;
  pa public.pending_attacks;
  version bigint;
  resolved jsonb;
  turn_result jsonb;
  v_has_baltazar boolean;
  v_discard_card_id uuid;
BEGIN
  SELECT bot_user_id INTO bot FROM public.training_matches WHERE match_id=p_match_id and human_user_id=human;
  IF bot IS NULL THEN RAISE EXCEPTION 'NOT_YOUR_TRAINING_MATCH'; END IF;

  SELECT * INTO pa FROM public.pending_attacks 
  WHERE match_id=p_match_id and attacker_user_id=human and defender_user_id=bot and status='awaiting_reaction' 
  ORDER BY created_at DESC LIMIT 1 FOR UPDATE;
  
  IF NOT FOUND THEN RAISE EXCEPTION 'TRAINING_PENDING_ATTACK_NOT_FOUND'; END IF;

  -- Regra C: Check if direct attack and bot has Baltazar (468273d5-a91a-4401-ad34-9e1ed222a63e)
  SELECT EXISTS(
      SELECT 1 FROM public.match_cards 
      WHERE match_id = p_match_id AND owner_user_id = bot AND source_card_id = '468273d5-a91a-4401-ad34-9e1ed222a63e'::uuid AND zone IN ('hand', 'reinforcement', 'attacker')
  ) INTO v_has_baltazar;

  IF pa.is_direct = true AND v_has_baltazar = true AND (
      SELECT count(*) FROM public.match_cards WHERE match_id = p_match_id AND owner_user_id = bot AND zone = 'hand'
  ) >= 1 THEN
      SELECT id INTO v_discard_card_id
      FROM public.match_cards
      WHERE match_id = p_match_id AND owner_user_id = bot AND zone = 'hand'
      ORDER BY CASE WHEN source_card_id = 'a5dcdb5a-92d9-42ef-89ef-1ccbbecada40'::uuid THEN 1 ELSE 0 END, random()
      LIMIT 1;

      IF v_discard_card_id IS NOT NULL THEN
          UPDATE public.match_cards SET zone = 'graveyard' WHERE id = v_discard_card_id;

          UPDATE public.pending_attacks SET status='cancelled', reaction_completed_at=now() WHERE id=pa.id;
          
          UPDATE public.match_cards 
          SET metadata = metadata - 'locked_for_pending_attack'
          WHERE match_id = p_match_id AND (metadata->>'locked_for_pending_attack')::uuid = pa.id;

          version:=game_private.record_match_action(p_match_id,bot,'reaction_used',jsonb_build_object('pending_attack_id',pa.id,'campaign_bot',true,'baltazar_reaction',true,'discarded_card_id',v_discard_card_id),'{}',p_expected_version);
          
          turn_result:=game_private.change_active_turn(p_match_id,human,false,version);
          RETURN jsonb_build_object('success', true, 'match_finished', false, 'state_version', version, 'turn', turn_result, 'message', 'Baltazar cancelou o ataque.');
      END IF;
  END IF;

  UPDATE public.pending_attacks SET status='reaction_declined',reaction_completed_at=now() WHERE id=pa.id;
  version:=game_private.record_match_action(p_match_id,bot,'reaction_declined',jsonb_build_object('pending_attack_id',pa.id,'campaign_bot',true),'{}',p_expected_version);
  resolved:=game_private.resolve_pending_attack_internal(pa.id,bot,version);
  version:=(resolved->>'state_version')::bigint;
  IF NOT coalesce((resolved->>'match_finished')::boolean,false) THEN turn_result:=game_private.change_active_turn(p_match_id,human,false,version); END IF;
  RETURN resolved||jsonb_build_object('turn',turn_result);
END $function$;


-- 3. Campaign match initialization function
CREATE OR REPLACE FUNCTION public.start_campaign_match(p_deck_id uuid)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
    v_user_id uuid := game_private.require_authenticated();
    v_bot_id uuid := '00000000-0000-4000-8000-000000000071'::uuid;
    v_match_id uuid;
    v_rule_id uuid;
    v_player_match_deck_id uuid;
    v_bot_match_deck_id uuid;
    v_card record;
    v_position integer;
    v_cards_list uuid[] := ARRAY[
        -- 6x Rei dos Mendigos (a5dcdb5a-92d9-42ef-89ef-1ccbbecada40)
        'a5dcdb5a-92d9-42ef-89ef-1ccbbecada40'::uuid, 'a5dcdb5a-92d9-42ef-89ef-1ccbbecada40'::uuid, 'a5dcdb5a-92d9-42ef-89ef-1ccbbecada40'::uuid, 'a5dcdb5a-92d9-42ef-89ef-1ccbbecada40'::uuid, 'a5dcdb5a-92d9-42ef-89ef-1ccbbecada40'::uuid, 'a5dcdb5a-92d9-42ef-89ef-1ccbbecada40'::uuid,
        -- 6x Troll (396784cd-e61b-4f7e-8fba-3757eaca72a4)
        '396784cd-e61b-4f7e-8fba-3757eaca72a4'::uuid, '396784cd-e61b-4f7e-8fba-3757eaca72a4'::uuid, '396784cd-e61b-4f7e-8fba-3757eaca72a4'::uuid, '396784cd-e61b-4f7e-8fba-3757eaca72a4'::uuid, '396784cd-e61b-4f7e-8fba-3757eaca72a4'::uuid, '396784cd-e61b-4f7e-8fba-3757eaca72a4'::uuid,
        -- 6x Barroso (c8f31e9d-0931-454a-b025-d3a9e076e04b)
        'c8f31e9d-0931-454a-b025-d3a9e076e04b'::uuid, 'c8f31e9d-0931-454a-b025-d3a9e076e04b'::uuid, 'c8f31e9d-0931-454a-b025-d3a9e076e04b'::uuid, 'c8f31e9d-0931-454a-b025-d3a9e076e04b'::uuid, 'c8f31e9d-0931-454a-b025-d3a9e076e04b'::uuid, 'c8f31e9d-0931-454a-b025-d3a9e076e04b'::uuid,
        -- 4x Baltazar (468273d5-a91a-4401-ad34-9e1ed222a63e)
        '468273d5-a91a-4401-ad34-9e1ed222a63e'::uuid, '468273d5-a91a-4401-ad34-9e1ed222a63e'::uuid, '468273d5-a91a-4401-ad34-9e1ed222a63e'::uuid, '468273d5-a91a-4401-ad34-9e1ed222a63e'::uuid,
        -- 4x Cutelo (e1f3727a-c9ae-46ef-accd-d30bab2e39a3)
        'e1f3727a-c9ae-46ef-accd-d30bab2e39a3'::uuid, 'e1f3727a-c9ae-46ef-accd-d30bab2e39a3'::uuid, 'e1f3727a-c9ae-46ef-accd-d30bab2e39a3'::uuid, 'e1f3727a-c9ae-46ef-accd-d30bab2e39a3'::uuid,
        -- 4x Erinia (a0a82d31-2094-4256-92b9-8bc58c9ba311)
        'a0a82d31-2094-4256-92b9-8bc58c9ba311'::uuid, 'a0a82d31-2094-4256-92b9-8bc58c9ba311'::uuid, 'a0a82d31-2094-4256-92b9-8bc58c9ba311'::uuid, 'a0a82d31-2094-4256-92b9-8bc58c9ba311'::uuid,
        -- 5x Gaetan (be345ece-e5f6-44da-8bd2-9382744fc868)
        'be345ece-e5f6-44da-8bd2-9382744fc868'::uuid, 'be345ece-e5f6-44da-8bd2-9382744fc868'::uuid, 'be345ece-e5f6-44da-8bd2-9382744fc868'::uuid, 'be345ece-e5f6-44da-8bd2-9382744fc868'::uuid, 'be345ece-e5f6-44da-8bd2-9382744fc868'::uuid,
        -- 4x Hattori o Elfo Ferreiro (126a4c87-38ba-4727-b031-3949d49205cf)
        '126a4c87-38ba-4727-b031-3949d49205cf'::uuid, '126a4c87-38ba-4727-b031-3949d49205cf'::uuid, '126a4c87-38ba-4727-b031-3949d49205cf'::uuid, '126a4c87-38ba-4727-b031-3949d49205cf'::uuid,
        -- 2x Udalryk o Atormentado (58f04ead-dfa9-4fba-b155-76d336beb0d1)
        '58f04ead-dfa9-4fba-b155-76d336beb0d1'::uuid, '58f04ead-dfa9-4fba-b155-76d336beb0d1'::uuid,
        -- 3x Pantera (cc6cc445-8484-470f-a71e-3e63dbf0008d)
        'cc6cc445-8484-470f-a71e-3e63dbf0008d'::uuid, 'cc6cc445-8484-470f-a71e-3e63dbf0008d'::uuid, 'cc6cc445-8484-470f-a71e-3e63dbf0008d'::uuid,
        -- 4x Ves (eb3a66bd-b41a-44b0-a2e4-3205da3a88c8)
        'eb3a66bd-b41a-44b0-a2e4-3205da3a88c8'::uuid, 'eb3a66bd-b41a-44b0-a2e4-3205da3a88c8'::uuid, 'eb3a66bd-b41a-44b0-a2e4-3205da3a88c8'::uuid, 'eb3a66bd-b41a-44b0-a2e4-3205da3a88c8'::uuid,
        -- 1x Kagma o Herói de Mahakan (dd4305b6-5d0f-4b4b-8bd1-bfa84ba67dbf)
        'dd4305b6-5d0f-4b4b-8bd1-bfa84ba67dbf'::uuid
    ];
    v_card_id uuid;
BEGIN
    IF v_user_id <> 'b6cd0821-39ae-451f-a8ca-25694c3e553c'::uuid THEN
        RAISE EXCEPTION 'Acesso negado ao Modo Campanha.';
    END IF;

    SELECT id INTO v_rule_id FROM public.game_rule_versions WHERE is_active = true LIMIT 1;

    INSERT INTO public.matches(
        rule_version_id, match_type, created_by,
        requires_bans, is_private, status, current_turn, active_player_id
    )
    VALUES (
        v_rule_id, 'campaign', v_user_id,
        true, true, 'ban_phase', 0, v_user_id
    )
    RETURNING id INTO v_match_id;

    INSERT INTO public.match_players(match_id, user_id, player_number, original_deck_id)
    VALUES 
        (v_match_id, v_user_id, 1, CASE WHEN p_deck_id = '00000000-0000-0000-0000-000000000000'::uuid OR p_deck_id = '00000000-0000-0000-0000-000000000072'::uuid THEN NULL ELSE p_deck_id END),
        (v_match_id, v_bot_id, 2, NULL);

    IF p_deck_id = '00000000-0000-0000-0000-000000000000'::uuid OR p_deck_id IS NULL THEN
        PERFORM game_private.snapshot_deck(v_match_id, v_user_id, '00000000-0000-0000-0000-000000000000'::uuid);
    ELSE
        PERFORM game_private.snapshot_deck(v_match_id, v_user_id, p_deck_id);
    END IF;

    INSERT INTO public.match_decks(match_id, user_id, source_deck_id, total_cards, golden_cards_count)
    VALUES (v_match_id, v_bot_id, NULL, array_length(v_cards_list, 1), 6)
    RETURNING id INTO v_bot_match_deck_id;

    v_position := 0;
    FOREACH v_card_id IN ARRAY v_cards_list LOOP
        v_position := v_position + 1;
        SELECT c.*,
               coalesce((select jsonb_agg(jsonb_build_object('effect_order', ce.effect_order, 'trigger_type', ce.trigger_type, 'effect_code', ce.effect_code, 'target_mode', ce.target_mode, 'parameters', ce.parameters, 'priority', ce.priority, 'is_reaction', ce.is_reaction, 'once_per_turn', ce.once_per_turn) order by ce.effect_order) from public.card_effects ce where ce.card_id = c.id and ce.is_active = true), '[]'::jsonb) as effect_definition
        INTO v_card
        FROM public.cards c WHERE c.id = v_card_id;

        INSERT INTO public.match_deck_cards(
            match_deck_id, source_card_id, card_version, card_name, image_url, element, rarity, card_type, is_golden, base_power, base_max_life, effect_mana_cost, tier, leader_cooldown, effect_definition, copy_number
        ) VALUES (
            v_bot_match_deck_id, v_card.id, v_card.version, v_card.name, coalesce(v_card.image_url, ''), coalesce(v_card.element, 'Neutro'), v_card.rarity, v_card.card_type, v_card.is_golden, coalesce(v_card.base_power, 0), coalesce(v_card.base_max_life, 0), coalesce(v_card.effect_mana_cost, 0), coalesce(v_card.tier, 1), coalesce(v_card.leader_cooldown, 0), coalesce(v_card.effect_definition, '[]'::jsonb), 1
        );
    END LOOP;

    INSERT INTO public.match_cards(match_id, owner_user_id, controller_user_id, match_deck_card_id, source_card_id, zone, zone_position, is_face_up, base_power, base_max_life, current_power, maximum_power, current_life, maximum_life)
    SELECT v_match_id, v_bot_id, v_bot_id, mdc.id, mdc.source_card_id, 'deck', row_number() over (order by random()), false, mdc.base_power, mdc.base_max_life, mdc.base_power, mdc.base_power, mdc.base_max_life, mdc.base_max_life
    FROM public.match_deck_cards mdc WHERE mdc.match_deck_id = v_bot_match_deck_id;

    INSERT INTO public.training_matches(match_id, human_user_id, bot_user_id)
    VALUES (v_match_id, v_user_id, v_bot_id);

    INSERT INTO public.match_public_states(match_id, player1_user_id, player1_username, player2_user_id, player2_username)
    SELECT v_match_id, p1.id, p1.username, p2.id, 'Rei dos Mendigos (Chefe)'
    FROM public.profiles p1, public.profiles p2
    WHERE p1.id = v_user_id AND p2.id = v_bot_id;

    RETURN v_match_id;
END;
$function$;


-- 4. Route run_training_bot_turn to run_campaign_bot_turn if match_type is campaign
CREATE OR REPLACE FUNCTION public.run_training_bot_turn(p_match_id uuid, p_expected_version bigint)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_human_id uuid := game_private.require_authenticated();
  v_bot_id uuid;
  v_match public.matches;
  v_chosen_card_id uuid;
  v_slot integer;
  v_version bigint := p_expected_version;
  v_pending_attack_id uuid;
  v_total_power integer;
  v_attacker_ids uuid[];
  v_reinforcement_count integer;
  v_hand_count integer;
  v_human_reinforcements integer;
  v_human_life_count integer;
  v_last_life_hp integer;
  v_existing_attack_power integer;
  v_best_hand_power integer;
  v_lethal_opportunity boolean := false;
  v_failure_state text;
  v_failure_message text;
  v_match_type text;
begin
  select match_type into v_match_type from public.matches where id = p_match_id;
  if v_match_type = 'campaign' then
      return public.run_campaign_bot_turn(p_match_id, p_expected_version);
  end if;

  select tm.bot_user_id into v_bot_id
  from public.training_matches tm
  where tm.match_id = p_match_id and tm.human_user_id = v_human_id;
  if v_bot_id is null then raise exception 'NOT_YOUR_TRAINING_MATCH'; end if;

  select m.* into v_match from public.matches m where m.id = p_match_id for update;
  if not found then raise exception 'MATCH_NOT_FOUND'; end if;
  if v_match.state_version <> p_expected_version then raise exception 'STALE_MATCH_VERSION'; end if;
  if v_match.status <> 'in_progress' or v_match.engine_state <> 'turn_action' then raise exception 'MATCH_FLOW_IS_BLOCKED'; end if;
  if v_match.active_player_id <> v_bot_id then raise exception 'BOT_IS_NOT_ACTIVE_PLAYER'; end if;

  select count(*)::integer into v_hand_count
  from public.match_cards mc
  where mc.match_id = p_match_id and mc.owner_user_id = v_bot_id and mc.zone = 'hand';
  select count(*)::integer into v_reinforcement_count
  from public.match_cards mc
  where mc.match_id = p_match_id and mc.controller_user_id = v_bot_id
    and mc.zone = 'reinforcement' and mc.current_life > 0;
  select count(*)::integer into v_human_reinforcements
  from public.match_cards mc
  where mc.match_id = p_match_id and mc.controller_user_id = v_human_id
    and mc.zone = 'reinforcement' and mc.current_life > 0;
  select count(*)::integer, max(mc.current_life)::integer
  into v_human_life_count, v_last_life_hp
  from public.match_cards mc
  where mc.match_id = p_match_id and mc.controller_user_id = v_human_id
    and mc.zone = 'life' and mc.current_life > 0;
  select coalesce(sum(mc.current_power),0)::integer into v_existing_attack_power
  from public.match_cards mc
  where mc.match_id = p_match_id and mc.controller_user_id = v_bot_id
    and mc.zone = 'attacker' and mc.current_life > 0 and mc.can_attack and not mc.has_attacked_this_turn;
  select coalesce(max(mc.current_power),0)::integer into v_best_hand_power
  from public.match_cards mc
  where mc.match_id = p_match_id and mc.owner_user_id = v_bot_id and mc.zone = 'hand';
  v_lethal_opportunity := v_human_reinforcements = 0 and v_human_life_count = 1
    and v_existing_attack_power + v_best_hand_power >= coalesce(v_last_life_hp, 2147483647);

  if v_reinforcement_count < 2 and v_hand_count > 2
     and not exists(
       select 1 from public.match_cards mc where mc.match_id = p_match_id
         and mc.controller_user_id = v_bot_id and mc.zone = 'reinforcement'
         and mc.entered_zone_turn = v_match.current_turn
     ) then
    select gs.slot into v_slot from generate_series(1,4) gs(slot)
    where not exists(
      select 1 from public.match_cards mc where mc.match_id = p_match_id
        and mc.controller_user_id = v_bot_id and mc.zone = 'reinforcement' and mc.zone_position = gs.slot
    ) order by gs.slot limit 1;
    select mc.id into v_chosen_card_id
    from public.match_cards mc
    where mc.match_id = p_match_id and mc.owner_user_id = v_bot_id and mc.zone = 'hand'
    order by mc.maximum_life desc, mc.current_power desc limit 1 for update;
    if v_chosen_card_id is not null and v_slot is not null then
      update public.match_cards mc set zone='reinforcement',zone_position=v_slot,is_face_up=false,entered_zone_turn=v_match.current_turn where mc.id=v_chosen_card_id;
      update public.match_players mp set actions_this_turn=mp.actions_this_turn+1 where mp.match_id=p_match_id and mp.user_id=v_bot_id;
      v_version := game_private.record_match_action(p_match_id,v_bot_id,'card_played',jsonb_build_object('match_card_id',v_chosen_card_id,'destination_zone','reinforcement','destination_position',v_slot,'training_bot',true,'hand_retained',v_hand_count-1),'{}'::jsonb,v_version);
      return jsonb_build_object('action','reinforcement_played','state_version',v_version,'hand_retained',v_hand_count-1);
    end if;
  end if;

  if not exists(
       select 1 from public.match_cards mc where mc.match_id=p_match_id
         and mc.controller_user_id=v_bot_id and mc.zone='attacker' and mc.current_life>0
     ) and (v_hand_count > 2 or v_lethal_opportunity) then
    select gs.slot into v_slot from generate_series(1,4) gs(slot)
    where not exists(
      select 1 from public.match_cards mc where mc.match_id=p_match_id
        and mc.controller_user_id=v_bot_id and mc.zone='attacker' and mc.zone_position=gs.slot
    ) order by gs.slot limit 1;
    select mc.id into v_chosen_card_id
    from public.match_cards mc
    where mc.match_id=p_match_id and mc.owner_user_id=v_bot_id and mc.zone='hand'
    order by mc.current_power desc,mc.maximum_life desc limit 1 for update;
    if v_chosen_card_id is not null and v_slot is not null then
      update public.match_cards mc set zone='attacker',zone_position=v_slot,is_face_up=true,entered_zone_turn=v_match.current_turn where mc.id=v_chosen_card_id;
      update public.match_players mp set actions_this_turn=mp.actions_this_turn+1 where mp.match_id=p_match_id and mp.user_id=v_bot_id;
      v_version := game_private.record_match_action(p_match_id,v_bot_id,'card_played',jsonb_build_object('match_card_id',v_chosen_card_id,'destination_zone','attacker','destination_position',v_slot,'training_bot',true,'lethal_exception',v_lethal_opportunity,'hand_retained',v_hand_count-1),'{}'::jsonb,v_version);
      return jsonb_build_object('action','attacker_played','state_version',v_version,'lethal_exception',v_lethal_opportunity,'hand_retained',v_hand_count-1);
    end if;
  end if;

  select array_agg(mc.id order by mc.zone_position),sum(mc.current_power)::integer
  into v_attacker_ids,v_total_power
  from public.match_cards mc
  where mc.match_id=p_match_id and mc.controller_user_id=v_bot_id and mc.zone='attacker'
    and mc.current_life>0 and mc.can_attack and not mc.has_attacked_this_turn;
  if coalesce(cardinality(v_attacker_ids),0)>0 then
    insert into public.pending_attacks(match_id,attacker_user_id,defender_user_id,status,is_direct,declared_power,reaction_deadline,declared_state_version)
    values(p_match_id,v_bot_id,v_human_id,'awaiting_reaction',false,v_total_power,clock_timestamp()+interval '45 seconds',v_version)
    returning id into v_pending_attack_id;
    insert into public.pending_attack_cards(pending_attack_id,match_card_id,attack_position,power_when_declared)
    select v_pending_attack_id, attack_card.id, attack_card.ordinality::integer,
      (select mc.current_power from public.match_cards mc where mc.id=attack_card.id)
    from unnest(v_attacker_ids) with ordinality attack_card(id,ordinality);
    update public.match_cards mc set metadata=mc.metadata||jsonb_build_object('locked_for_pending_attack',v_pending_attack_id) where mc.id=any(v_attacker_ids);
    update public.match_players mp set actions_this_turn=mp.actions_this_turn+1 where mp.match_id=p_match_id and mp.user_id=v_bot_id;
    v_version := game_private.record_match_action(p_match_id,v_bot_id,'attack_declared',jsonb_build_object('pending_attack_id',v_pending_attack_id,'attacker_user_id',v_bot_id,'defender_user_id',v_human_id,'attacker_card_ids',to_jsonb(v_attacker_ids),'total_power',v_total_power,'is_direct',false,'training_bot',true),'{}'::jsonb,v_version);
    update public.pending_attacks pa set declared_state_version=v_version where pa.id=v_pending_attack_id;
    return jsonb_build_object('action','attack_declared','state_version',v_version,'pending_attack_id',v_pending_attack_id);
  end if;

  return game_private.change_active_turn(p_match_id,v_bot_id,
    coalesce((select mp.actions_this_turn=0 from public.match_players mp where mp.match_id=p_match_id and mp.user_id=v_bot_id),true),v_version)
    ||jsonb_build_object('action','mana_preserved','hand_retained',v_hand_count);
exception when others then
  get stacked diagnostics v_failure_state=returned_sqlstate,v_failure_message=message_text;
  select m.* into v_match from public.matches m where m.id=p_match_id for update;
  if v_match.active_player_id=v_bot_id and v_match.state_version=p_expected_version then
    return game_private.change_active_turn(p_match_id,v_bot_id,false,p_expected_version)
      ||jsonb_build_object('action','safe_fallback_end_turn','bot_error_code',v_failure_state,'bot_error_message',v_failure_message);
  end if;
  raise;
end;
$function$;


-- 5. Route auto_resolve_training_attack to auto_resolve_campaign_attack if match_type is campaign
CREATE OR REPLACE FUNCTION public.auto_resolve_training_attack(p_match_id uuid, p_expected_version bigint)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare 
  human uuid := game_private.require_authenticated(); 
  bot uuid; 
  pa public.pending_attacks; 
  version bigint; 
  resolved jsonb; 
  turn_result jsonb;
  v_match_type text;
begin
  select match_type into v_match_type from public.matches where id = p_match_id;
  if v_match_type = 'campaign' then
      return public.auto_resolve_campaign_attack(p_match_id, p_expected_version);
  end if;

  select bot_user_id into bot from public.training_matches where match_id=p_match_id and human_user_id=human;
  if bot is null then raise exception 'NOT_YOUR_TRAINING_MATCH'; end if;
  select * into pa from public.pending_attacks where match_id=p_match_id and attacker_user_id=human and defender_user_id=bot and status='awaiting_reaction' order by created_at desc limit 1 for update;
  if not found then raise exception 'TRAINING_PENDING_ATTACK_NOT_FOUND'; end if;
  update public.pending_attacks set status='reaction_declined',reaction_completed_at=now() where id=pa.id;
  version:=game_private.record_match_action(p_match_id,bot,'reaction_declined',jsonb_build_object('pending_attack_id',pa.id,'training_bot',true),'{}',p_expected_version);
  resolved:=game_private.resolve_pending_attack_internal(pa.id,bot,version);
  version:=(resolved->>'state_version')::bigint;
  if not coalesce((resolved->>'match_finished')::boolean,false) then turn_result:=game_private.change_active_turn(p_match_id,human,false,version); end if;
  return resolved||jsonb_build_object('turn',turn_result);
end $function$;


-- 6. Update submit_match_ban to handle campaign bans
CREATE OR REPLACE FUNCTION public.submit_match_ban(p_match_id uuid, p_source_card_id uuid, p_ban_category text, p_expected_version bigint DEFAULT NULL::bigint)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
    v_user_id uuid := auth.uid();
    v_target_id uuid;
    v_bot_id uuid := '00000000-0000-4000-8000-000000000071'::uuid;
    v_match_type text;
    v_player_legendary_card_id uuid;
BEGIN
    SELECT match_type INTO v_match_type FROM public.matches WHERE id = p_match_id;

    SELECT user_id INTO v_target_id FROM public.match_players
    WHERE match_id = p_match_id AND user_id <> v_user_id LIMIT 1;
    
    IF v_target_id IS NULL THEN 
        RAISE EXCEPTION 'OPPONENT_NOT_FOUND'; 
    END IF;

    IF p_source_card_id IS NULL THEN
        INSERT INTO public.match_bans(match_id, banned_by_user_id, target_user_id, source_card_id, ban_category, is_skipped)
        VALUES (p_match_id, v_user_id, v_target_id, null, coalesce(p_ban_category, 'rare'), true);
    ELSE
        INSERT INTO public.match_bans(match_id, banned_by_user_id, target_user_id, source_card_id, ban_category, is_skipped)
        VALUES (p_match_id, v_user_id, v_target_id, p_source_card_id, coalesce(p_ban_category, 'rare'), false);

        UPDATE public.match_cards
        SET zone = 'banished', is_face_up = true
        WHERE id = (
            SELECT id FROM public.match_cards 
            WHERE match_id = p_match_id AND owner_user_id = v_target_id AND source_card_id = p_source_card_id AND zone = 'deck'
            LIMIT 1
        );
    END IF;

    -- Campaign / Training auto-ban
    IF v_target_id = v_bot_id AND NOT EXISTS (SELECT 1 FROM public.match_bans WHERE match_id = p_match_id AND banned_by_user_id = v_bot_id) THEN
        IF v_match_type = 'campaign' THEN
            SELECT mc.id INTO v_player_legendary_card_id
            FROM public.match_cards mc
            JOIN public.match_deck_cards mdc ON mdc.id = mc.match_deck_card_id
            WHERE mc.match_id = p_match_id AND mc.owner_user_id = v_user_id AND mc.zone = 'deck' AND mdc.rarity = 'legendary'
            ORDER BY random() LIMIT 1;
            
            IF v_player_legendary_card_id IS NOT NULL THEN
                UPDATE public.match_cards SET zone = 'banished', is_face_up = true WHERE id = v_player_legendary_card_id;
                
                INSERT INTO public.match_bans(match_id, banned_by_user_id, target_user_id, source_card_id, ban_category, is_skipped)
                VALUES (p_match_id, v_bot_id, v_user_id, (SELECT source_card_id FROM public.match_cards WHERE id = v_player_legendary_card_id), 'legendary', false);
            ELSE
                INSERT INTO public.match_bans(match_id, banned_by_user_id, target_user_id, source_card_id, ban_category, is_skipped)
                VALUES (p_match_id, v_bot_id, v_user_id, null, 'legendary', true);
            END IF;
        ELSE
            INSERT INTO public.match_bans(match_id, banned_by_user_id, target_user_id, source_card_id, ban_category, is_skipped)
            VALUES (p_match_id, v_bot_id, v_user_id, null, 'rare', true);
        END IF;
    END IF;

    IF (SELECT count(*) FROM public.match_bans WHERE match_id = p_match_id) >= 2 THEN
        UPDATE public.matches SET status = 'setup' WHERE id = p_match_id;
        PERFORM game_private.deal_initial_hands(p_match_id);
        RETURN jsonb_build_object('ban_phase_complete', true);
    END IF;

    RETURN jsonb_build_object('ban_phase_complete', false);
END;
$function$;


-- 7. Update submit_match_setup to handle campaign setups
CREATE OR REPLACE FUNCTION public.submit_match_setup(p_match_id uuid, p_life_card_ids uuid[], p_reinforcement_card_ids uuid[] DEFAULT '{}'::uuid[], p_leader_card_id uuid DEFAULT NULL::uuid, p_expected_version bigint DEFAULT NULL::bigint)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
    v_user_id uuid := auth.uid();
    v_target_id uuid;
    v_bot_id uuid := '00000000-0000-4000-8000-000000000071'::uuid;
    v_card_id uuid;
    v_pos int := 1;
    v_bot_card record;
    v_first_player uuid;
    v_d1 int;
    v_d2 int;
    v_match_type text;
BEGIN
    SELECT match_type INTO v_match_type FROM public.matches WHERE id = p_match_id;

    SELECT user_id INTO v_target_id FROM public.match_players
    WHERE match_id = p_match_id AND user_id <> v_user_id LIMIT 1;

    IF v_target_id IS NULL THEN
        v_target_id := v_bot_id;
    END IF;

    -- Human setup
    v_pos := 1;
    FOREACH v_card_id IN ARRAY p_life_card_ids LOOP
        UPDATE public.match_cards
        SET zone = 'life', zone_position = v_pos, is_face_up = true
        WHERE match_id = p_match_id 
          AND owner_user_id = v_user_id 
          AND (id = v_card_id OR source_card_id = v_card_id)
          AND zone = 'hand';
        v_pos := v_pos + 1;
    END LOOP;

    IF array_length(p_reinforcement_card_ids, 1) > 0 THEN
        v_pos := 1;
        FOREACH v_card_id IN ARRAY p_reinforcement_card_ids LOOP
            UPDATE public.match_cards
            SET zone = 'reinforcement', zone_position = v_pos, is_face_up = false
            WHERE match_id = p_match_id 
              AND owner_user_id = v_user_id 
              AND (id = v_card_id OR source_card_id = v_card_id)
              AND zone = 'hand';
        v_pos := v_pos + 1;
        END LOOP;
    END IF;

    -- Bot setup
    IF v_target_id = v_bot_id OR NOT EXISTS (SELECT 1 FROM public.profiles WHERE id = v_target_id) THEN
        IF v_match_type = 'campaign' THEN
            v_pos := 1;
            FOR v_bot_card IN (
                SELECT mc.id 
                FROM public.match_cards mc
                JOIN public.match_deck_cards mdc ON mdc.id = mc.match_deck_card_id
                WHERE mc.match_id = p_match_id AND mc.owner_user_id = v_bot_id AND mc.zone = 'hand'
                ORDER BY mdc.base_max_life DESC, mc.id ASC
                LIMIT 3
            ) LOOP
                UPDATE public.match_cards 
                SET zone = 'life', zone_position = v_pos, is_face_up = true 
                WHERE id = v_bot_card.id;
                v_pos := v_pos + 1;
            END LOOP;

            v_pos := 1;
            FOR v_bot_card IN (
                SELECT mc.id 
                FROM public.match_cards mc
                WHERE mc.match_id = p_match_id AND mc.owner_user_id = v_bot_id AND mc.zone = 'hand'
                ORDER BY random()
                LIMIT 2
            ) LOOP
                UPDATE public.match_cards 
                SET zone = 'reinforcement', zone_position = v_pos, is_face_up = false 
                WHERE id = v_bot_card.id;
                v_pos := v_pos + 1;
            END LOOP;
        ELSE
            v_pos := 1;
            FOR v_bot_card IN (
                SELECT id FROM public.match_cards 
                WHERE match_id = p_match_id AND owner_user_id = v_bot_id AND zone = 'hand' 
                ORDER BY id LIMIT 3
            ) LOOP
                UPDATE public.match_cards 
                SET zone = 'life', zone_position = v_pos, is_face_up = true 
                WHERE id = v_bot_card.id;
                v_pos := v_pos + 1;
            END LOOP;

            UPDATE public.match_cards 
            SET zone = 'reinforcement', is_face_up = false, zone_position = 1
            WHERE id = (
                SELECT id FROM public.match_cards 
                WHERE match_id = p_match_id AND owner_user_id = v_bot_id AND zone = 'hand' 
                ORDER BY id LIMIT 1
            );
        END IF;
    END IF;

    -- Initiative
    v_d1 := floor(random() * 20 + 1)::int;
    v_d2 := floor(random() * 20 + 1)::int;
    IF v_d1 >= v_d2 THEN
        v_first_player := v_user_id;
    ELSE
        v_first_player := v_target_id;
    END IF;

    UPDATE public.matches 
    SET status = 'initiative', 
        engine_state = 'lifecycle',
        active_player_id = v_first_player,
        initiative_result = jsonb_build_object(
            'winner_user_id', v_first_player,
            'player1', v_d1,
            'player2', v_d2
        )
    WHERE id = p_match_id;

    RETURN jsonb_build_object('setup_complete', true, 'status', 'initiative');
END;
$function$;
