-- V8.0: remove colisões PL/pgSQL, amplia gatilhos defensivos e evita soft-lock do bot.
begin;

-- O executor possui mais de setenta handlers. Recompilamos a definição instalada
-- trocando exclusivamente a variável local conflitante; a coluna pa.result fica
-- sempre qualificada e nenhuma regra de carta é duplicada ou descartada.
do $migration$
declare
  v_definition text;
begin
  select pg_get_functiondef(
    'game_private.execute_common_effect_internal(uuid,uuid,uuid,text,jsonb,uuid,jsonb)'::regprocedure
  ) into v_definition;

  v_definition := replace(v_definition, ' result jsonb:=''{}'';', ' v_result jsonb:=''{}'';');
  v_definition := replace(v_definition, 'result:=', 'v_result:=');
  v_definition := replace(v_definition, 'result||', 'v_result||');
  v_definition := replace(v_definition,
    'update public.pending_attacks set declared_power=0,result=v_result||',
    'update public.pending_attacks pa set declared_power=0,result=pa.result||'
  );
  v_definition := replace(v_definition, '''result'',result)', '''result'',v_result)');
  execute v_definition;
end;
$migration$;

create or replace function public.activate_card_effect_v2(
  p_match_id uuid,
  p_source_card_id uuid,
  p_effect_order integer default 1,
  p_target_card_id uuid default null,
  p_expected_version bigint default 0
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor_id uuid := game_private.require_authenticated();
  v_source_card public.match_cards;
  v_effect_definition jsonb;
  v_effect_code text;
  v_effect_parameters jsonb;
  v_trigger_type text;
  v_is_reaction boolean;
  v_mana_cost integer;
  v_result jsonb;
  v_new_version bigint;
  v_match public.matches;
  v_hand_count integer;
begin
  select m.* into v_match
  from public.matches m
  where m.id = p_match_id
  for update;
  if not found then raise exception 'MATCH_NOT_FOUND'; end if;
  if v_match.state_version <> p_expected_version then raise exception 'STALE_MATCH_VERSION'; end if;

  select effect_source.* into v_source_card
  from game_private.assert_common_effect_source(
    p_match_id, v_actor_id, p_source_card_id, p_expected_version, true
  ) effect_source;

  select effect_item.value into v_effect_definition
  from public.match_deck_cards mdc
  cross join lateral jsonb_array_elements(mdc.effect_definition) effect_item(value)
  where mdc.id = v_source_card.match_deck_card_id
    and (effect_item.value->>'effect_order')::integer = p_effect_order;
  if v_effect_definition is null then raise exception 'EFFECT_NOT_FOUND'; end if;

  v_effect_code := v_effect_definition->>'effect_code';
  if v_effect_code not like 'common_%' then
    return public.activate_match_effect(
      p_match_id, p_source_card_id, p_effect_order, p_target_card_id, p_expected_version
    );
  end if;

  perform game_private.assert_no_global_effect_lock(p_match_id, v_actor_id, p_source_card_id);
  v_trigger_type := v_effect_definition->>'trigger_type';
  v_is_reaction := coalesce((v_effect_definition->>'is_reaction')::boolean, false)
    or v_trigger_type in ('reaction','on_reaction','on_attacked','on_damage_received');

  if v_trigger_type <> 'manual' and not v_is_reaction then
    raise exception 'EFFECT_IS_AUTOMATIC: %', v_trigger_type;
  end if;

  if v_is_reaction then
    if v_source_card.owner_user_id <> v_actor_id
       or v_source_card.zone not in ('hand','life','reinforcement') then
      raise exception 'INVALID_REACTION_SOURCE_ZONE';
    end if;
    if v_match.active_player_id = v_actor_id then raise exception 'REACTION_ONLY_ON_OPPONENT_TURN'; end if;
    if not exists(
      select 1 from public.pending_attacks pa
      where pa.match_id = p_match_id
        and pa.defender_user_id = v_actor_id
        and pa.status = 'awaiting_reaction'
        and pa.reaction_deadline > clock_timestamp()
    ) then raise exception 'NO_OPEN_REACTION_WINDOW'; end if;
  else
    if v_match.engine_state <> 'turn_action' then raise exception 'MATCH_FLOW_IS_BLOCKED'; end if;
    if v_match.active_player_id <> v_actor_id then raise exception 'NOT_YOUR_TURN'; end if;
  end if;

  v_effect_parameters := coalesce(v_effect_definition->'parameters', '{}'::jsonb);
  v_mana_cost := greatest(0, coalesce(
    (v_effect_parameters->>'mana_cost')::integer,
    game_private.effect_card_cost(p_source_card_id), 0
  ));
  select count(*)::integer into v_hand_count
  from public.match_cards mc
  where mc.match_id = p_match_id and mc.owner_user_id = v_actor_id and mc.zone = 'hand';
  if v_hand_count < v_mana_cost then raise exception 'INSUFFICIENT_MANA'; end if;

  if coalesce((v_effect_definition->>'once_per_turn')::boolean, false) and exists(
    select 1 from public.match_effect_uses meu
    where meu.match_id = p_match_id
      and meu.match_card_id = p_source_card_id
      and meu.effect_order = p_effect_order
      and meu.turn_number = v_match.current_turn
  ) then raise exception 'EFFECT_ALREADY_USED_THIS_TURN'; end if;

  perform game_private.pay_common_effect_cost(p_match_id, v_actor_id, v_mana_cost);
  v_result := game_private.execute_common_effect_internal(
    p_match_id, v_actor_id, p_source_card_id, v_effect_code,
    v_effect_parameters, p_target_card_id, '{}'::jsonb
  );

  insert into public.match_effect_uses(
    match_id, match_card_id, actor_user_id, effect_order,
    turn_number, is_reaction, mana_spent
  ) values (
    p_match_id, p_source_card_id, v_actor_id, p_effect_order,
    v_match.current_turn, v_is_reaction, v_mana_cost
  );

  v_new_version := game_private.record_match_action(
    p_match_id, v_actor_id, 'effect_activated',
    jsonb_build_object(
      'source_card_id', p_source_card_id,
      'effect_order', p_effect_order,
      'effect_code', v_effect_code,
      'target_card_id', p_target_card_id,
      'mana_spent', v_mana_cost,
      'is_reaction', v_is_reaction,
      'result', v_result
    ), '{}'::jsonb, p_expected_version
  );
  return v_result || jsonb_build_object('state_version', v_new_version, 'mana_spent', v_mana_cost);
end;
$$;

create or replace function public.rescue_training_bot_turn(
  p_match_id uuid,
  p_expected_version bigint
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_human_id uuid := game_private.require_authenticated();
  v_bot_id uuid;
  v_match public.matches;
  v_failure_state text;
  v_failure_message text;
begin
  select tm.bot_user_id into v_bot_id
  from public.training_matches tm
  where tm.match_id = p_match_id and tm.human_user_id = v_human_id;
  if v_bot_id is null then raise exception 'NOT_YOUR_TRAINING_MATCH'; end if;

  select m.* into v_match from public.matches m where m.id = p_match_id for update;
  if not found then raise exception 'MATCH_NOT_FOUND'; end if;
  if v_match.state_version <> p_expected_version then raise exception 'STALE_MATCH_VERSION'; end if;
  if v_match.status <> 'in_progress' then raise exception 'INVALID_MATCH_STATUS'; end if;
  if v_match.active_player_id <> v_bot_id then
    return jsonb_build_object('rescued', false, 'reason', 'BOT_TURN_ALREADY_FINISHED', 'state_version', v_match.state_version);
  end if;

  begin
    return public.run_training_bot_turn(p_match_id, p_expected_version)
      || jsonb_build_object('rescued', true, 'fallback_end_turn', false);
  exception when others then
    get stacked diagnostics v_failure_state = returned_sqlstate, v_failure_message = message_text;
    select m.* into v_match from public.matches m where m.id = p_match_id for update;
    if v_match.active_player_id = v_bot_id and v_match.state_version = p_expected_version then
      return game_private.change_active_turn(p_match_id, v_bot_id, false, p_expected_version)
        || jsonb_build_object(
          'rescued', true,
          'fallback_end_turn', true,
          'bot_error_code', v_failure_state,
          'bot_error_message', v_failure_message
        );
    end if;
    return jsonb_build_object(
      'rescued', false,
      'reason', 'MATCH_ALREADY_ADVANCED',
      'state_version', v_match.state_version
    );
  end;
end;
$$;

revoke all on function public.activate_card_effect_v2(uuid,uuid,integer,uuid,bigint),
  public.rescue_training_bot_turn(uuid,bigint) from public, anon;
grant execute on function public.activate_card_effect_v2(uuid,uuid,integer,uuid,bigint),
  public.rescue_training_bot_turn(uuid,bigint) to authenticated;

notify pgrst, 'reload schema';
commit;
