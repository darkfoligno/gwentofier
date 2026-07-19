-- V9.0: bot tático preserva pelo menos duas cartas/mana, salvo abate letal.
begin;

create or replace function public.run_training_bot_turn(
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
begin
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

  -- Primeiro estabelece uma linha de blefe/proteção, sem romper a reserva de 2.
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

  -- Apenas uma linha atacante de cada vez; uma exceção de reserva existe para letal.
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
$$;

-- Uma conjuração é um ato público: publica somente a ficha da carta que acabou
-- de ser revelada pelo próprio efeito, sem expor o restante da mão.
create or replace function game_private.enrich_effect_showcase_v9()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_card jsonb;
begin
  if new.action_type = 'effect_activated' then
    select jsonb_build_object(
      'id', mc.id,
      'name', mdc.card_name,
      'image_url', mdc.image_url,
      'element', mdc.element,
      'rarity', mdc.rarity,
      'card_type', mdc.card_type,
      'power', mc.current_power,
      'life', mc.current_life,
      'mana', mdc.effect_mana_cost,
      'effect_text', coalesce(c.effect_text,'')
    ) into v_card
    from public.match_cards mc
    join public.match_deck_cards mdc on mdc.id=mc.match_deck_card_id
    join public.cards c on c.id=mdc.source_card_id
    where mc.id=(new.payload_public->>'source_card_id')::uuid
      and mc.match_id=new.match_id;
    new.payload_public := new.payload_public || jsonb_build_object('effect_card',coalesce(v_card,'{}'::jsonb));
  end if;
  return new;
end;
$$;

drop trigger if exists match_actions_enrich_effect_showcase_v9 on public.match_actions;
create trigger match_actions_enrich_effect_showcase_v9
before insert on public.match_actions
for each row execute function game_private.enrich_effect_showcase_v9();

revoke all on function public.run_training_bot_turn(uuid,bigint) from public,anon;
grant execute on function public.run_training_bot_turn(uuid,bigint) to authenticated;
notify pgrst,'reload schema';
commit;
