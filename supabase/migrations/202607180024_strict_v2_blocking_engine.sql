-- Motor V2.0: estado bloqueante, mana dinâmica, setup completo e bot sem atalhos.
-- Execute depois de 202607180023_bot_rescue_and_nonfatal_draw_lock.sql.
begin;

alter table public.matches
  add column if not exists engine_state text not null default 'lifecycle';

alter table public.matches drop constraint if exists matches_engine_state_check;
alter table public.matches add constraint matches_engine_state_check check (
  engine_state in ('lifecycle','ban_phase','setup','turn_action','reaction_window','resolving','finished')
);

create or replace function game_private.refresh_match_engine_state(p_match_id uuid)
returns void language plpgsql security definer set search_path='' as $$
declare next_state text;
begin
  select case
    when m.status='ban_phase' then 'ban_phase'
    when m.status='setup' then 'setup'
    when m.status='finished' then 'finished'
    when m.status<>'in_progress' then 'lifecycle'
    when exists(select 1 from public.pending_attacks pa where pa.match_id=m.id and pa.status='resolving') then 'resolving'
    when exists(select 1 from public.pending_attacks pa where pa.match_id=m.id and pa.status in('awaiting_reaction','reaction_used','reaction_declined')) then 'reaction_window'
    else 'turn_action' end
  into next_state from public.matches m where m.id=p_match_id;
  update public.matches set engine_state=next_state where id=p_match_id and engine_state is distinct from next_state;
end $$;

create or replace function game_private.sync_engine_state_from_match() returns trigger
language plpgsql security definer set search_path='' as $$
begin perform game_private.refresh_match_engine_state(new.id); return new; end $$;
drop trigger if exists matches_sync_engine_state on public.matches;
create trigger matches_sync_engine_state after insert or update of status on public.matches
for each row execute function game_private.sync_engine_state_from_match();

create or replace function game_private.sync_engine_state_from_attack() returns trigger
language plpgsql security definer set search_path='' as $$
begin perform game_private.refresh_match_engine_state(coalesce(new.match_id,old.match_id)); return coalesce(new,old); end $$;
drop trigger if exists pending_attacks_sync_engine_state on public.pending_attacks;
create trigger pending_attacks_sync_engine_state after insert or update of status or delete on public.pending_attacks
for each row execute function game_private.sync_engine_state_from_attack();

do $$ declare mid uuid; begin
  for mid in select id from public.matches loop perform game_private.refresh_match_engine_state(mid); end loop;
end $$;

-- Mana V2: é uma projeção autoritativa da quantidade de cartas na mão.
create or replace function game_private.sync_player_hand_mana(p_match_id uuid,p_user_id uuid)
returns void language plpgsql security definer set search_path='' as $$
begin
  update public.match_players mp set
    mana_available=(select count(*)::integer from public.match_cards mc where mc.match_id=p_match_id and mc.owner_user_id=p_user_id and mc.zone='hand'),
    mana_snapshot=(select count(*)::integer from public.match_cards mc where mc.match_id=p_match_id and mc.owner_user_id=p_user_id and mc.zone='hand')
  where mp.match_id=p_match_id and mp.user_id=p_user_id;
end $$;

create or replace function game_private.sync_mana_after_card_movement() returns trigger
language plpgsql security definer set search_path='' as $$
begin
  if old.zone is distinct from new.zone or old.owner_user_id is distinct from new.owner_user_id then
    perform game_private.sync_player_hand_mana(new.match_id,new.owner_user_id);
    if old.owner_user_id is distinct from new.owner_user_id then
      perform game_private.sync_player_hand_mana(old.match_id,old.owner_user_id);
    end if;
  end if;
  return new;
end $$;
drop trigger if exists match_cards_sync_dynamic_mana on public.match_cards;
create trigger match_cards_sync_dynamic_mana after update of zone,owner_user_id on public.match_cards
for each row execute function game_private.sync_mana_after_card_movement();

create or replace function game_private.pay_common_effect_cost(p_match_id uuid,p_actor uuid,p_cost integer)
returns void language plpgsql security definer set search_path='' as $$
declare hand_count integer;
begin
  select count(*)::integer into hand_count from public.match_cards
  where match_id=p_match_id and owner_user_id=p_actor and zone='hand';
  if hand_count < greatest(0,p_cost) then raise exception 'INSUFFICIENT_MANA'; end if;
  update public.match_players set mana_available=hand_count,mana_snapshot=hand_count,
    mana_spent_this_turn=mana_spent_this_turn+greatest(0,p_cost),actions_this_turn=actions_this_turn+1
  where match_id=p_match_id and user_id=p_actor;
  if not found then raise exception 'MATCH_PLAYER_NOT_FOUND'; end if;
end $$;

-- Reação estrita: somente mão, vida ou reforço; uma reação por janela.
create or replace function public.activate_card_effect_v2(p_match_id uuid,p_source_card_id uuid,p_effect_order integer default 1,p_target_card_id uuid default null,p_expected_version bigint default 0)
returns jsonb language plpgsql security definer set search_path='' as $$
declare actor uuid:=game_private.require_authenticated(); src public.match_cards; def jsonb; code text; params jsonb; trig text; reaction boolean; cost integer; result jsonb; new_version bigint; m public.matches;
begin
  select * into m from public.matches where id=p_match_id for update;
  if not found then raise exception 'MATCH_NOT_FOUND'; end if;
  if m.state_version<>p_expected_version then raise exception 'STALE_MATCH_VERSION'; end if;
  select * into src from game_private.assert_common_effect_source(p_match_id,actor,p_source_card_id,p_expected_version,true);
  select x into def from public.match_deck_cards d cross join lateral jsonb_array_elements(d.effect_definition)x
    where d.id=src.match_deck_card_id and (x->>'effect_order')::integer=p_effect_order;
  if def is null then raise exception 'EFFECT_NOT_FOUND'; end if;
  code:=def->>'effect_code';
  if code not like 'common_%' then return public.activate_match_effect(p_match_id,p_source_card_id,p_effect_order,p_target_card_id,p_expected_version); end if;
  perform game_private.assert_no_global_effect_lock(p_match_id,actor,p_source_card_id);
  trig:=def->>'trigger_type'; reaction:=coalesce((def->>'is_reaction')::boolean,false) or trig='reaction';
  if trig not in('manual','reaction') then raise exception 'EFFECT_IS_AUTOMATIC: %',trig; end if;
  if reaction then
    if src.zone not in('hand','life','reinforcement') then raise exception 'INVALID_REACTION_SOURCE_ZONE'; end if;
    if m.active_player_id=actor then raise exception 'REACTION_ONLY_ON_OPPONENT_TURN'; end if;
    if not exists(select 1 from public.pending_attacks where match_id=p_match_id and defender_user_id=actor and status='awaiting_reaction' and reaction_deadline>now()) then raise exception 'NO_OPEN_REACTION_WINDOW'; end if;
  else
    if m.engine_state<>'turn_action' then raise exception 'MATCH_FLOW_IS_BLOCKED'; end if;
    if m.active_player_id<>actor then raise exception 'NOT_YOUR_TURN'; end if;
  end if;
  params:=coalesce(def->'parameters','{}');
  cost:=greatest(0,coalesce((params->>'mana_cost')::integer,game_private.effect_card_cost(p_source_card_id),0));
  if (select count(*) from public.match_cards where match_id=p_match_id and owner_user_id=actor and zone='hand')<cost then raise exception 'INSUFFICIENT_MANA'; end if;
  if coalesce((def->>'once_per_turn')::boolean,false) and exists(select 1 from public.match_effect_uses where match_id=p_match_id and match_card_id=p_source_card_id and effect_order=p_effect_order and turn_number=m.current_turn) then raise exception 'EFFECT_ALREADY_USED_THIS_TURN'; end if;
  perform game_private.pay_common_effect_cost(p_match_id,actor,cost);
  result:=game_private.execute_common_effect_internal(p_match_id,actor,p_source_card_id,code,params,p_target_card_id,'{}');
  insert into public.match_effect_uses(match_id,match_card_id,actor_user_id,effect_order,turn_number,is_reaction,mana_spent)
  values(p_match_id,p_source_card_id,actor,p_effect_order,m.current_turn,reaction,cost);
  new_version:=game_private.record_match_action(p_match_id,actor,'effect_activated',jsonb_build_object('source_card_id',p_source_card_id,'effect_order',p_effect_order,'effect_code',code,'target_card_id',p_target_card_id,'mana_spent',cost,'result',result),'{}',p_expected_version);
  return result||jsonb_build_object('state_version',new_version,'mana_spent',cost);
end $$;

-- Turno 8: somente as zonas definidas pela Regra 20; nunca deteriora duas vezes.
create or replace function game_private.apply_match_deterioration(p_match_id uuid,p_turn integer)
returns void language plpgsql security definer set search_path='' as $$
declare start_turn integer; mode text;
begin
  select grv.deterioration_start_turn,grv.deterioration_mode into start_turn,mode
  from public.matches m join public.game_rule_versions grv on grv.id=m.rule_version_id where m.id=p_match_id;
  if not found then raise exception 'MATCH_OR_RULE_VERSION_NOT_FOUND'; end if;
  if p_turn<>8 or p_turn<>start_turn or mode<>'halve_life_once' then return; end if;
  update public.match_cards set
    maximum_life=greatest(1,floor(maximum_life*0.5)::integer),
    current_life=least(current_life,greatest(1,floor(maximum_life*0.5)::integer)),
    metadata=metadata||jsonb_build_object('turn_8_life_halved',true)
  where match_id=p_match_id and zone in('life','hand','deck','graveyard')
    and not coalesce((metadata->>'turn_8_life_halved')::boolean,false);
  perform game_private.recalculate_match_public_state(p_match_id);
end $$;

-- Setup de treino completo: 3 vidas, até 4 reforços ocultos e iniciativa D20.
drop function if exists public.submit_training_setup(uuid,uuid[],bigint);
create or replace function public.submit_training_setup(p_match_id uuid,p_life_card_ids uuid[],p_reinforcement_card_ids uuid[] default array[]::uuid[],p_expected_version bigint default 0)
returns jsonb language plpgsql security definer set search_path='' as $$
declare human uuid:=game_private.require_authenticated(); bot uuid; m public.matches; bot_life uuid[]; bot_reinforcement uuid[]; all_ids uuid[]; version bigint; active uuid; human_roll integer; bot_roll integer;
begin
  select bot_user_id into bot from public.training_matches where match_id=p_match_id and human_user_id=human;
  if bot is null then raise exception 'NOT_YOUR_TRAINING_MATCH'; end if;
  m:=game_private.lock_match_for_action(p_match_id,p_expected_version,array['setup']);
  if cardinality(p_life_card_ids)<>3 or (select count(distinct x) from unnest(p_life_card_ids)x)<>3 then raise exception 'EXACTLY_THREE_DISTINCT_LIFE_CARDS_REQUIRED'; end if;
  if coalesce(cardinality(p_reinforcement_card_ids),0)>4 then raise exception 'TOO_MANY_REINFORCEMENTS'; end if;
  all_ids:=p_life_card_ids||coalesce(p_reinforcement_card_ids,array[]::uuid[]);
  if (select count(distinct x) from unnest(all_ids)x)<>cardinality(all_ids) then raise exception 'DUPLICATED_SETUP_CARD'; end if;
  if exists(select 1 from unnest(all_ids)x where not exists(select 1 from public.match_cards where id=x and match_id=p_match_id and owner_user_id=human and zone='hand')) then raise exception 'SETUP_CARD_NOT_IN_HAND'; end if;
  update public.match_cards mc set zone='life',zone_position=x.ord,is_face_up=true,entered_zone_turn=0 from unnest(p_life_card_ids)with ordinality x(id,ord) where mc.id=x.id;
  update public.match_cards mc set zone='reinforcement',zone_position=x.ord,is_face_up=false,entered_zone_turn=0 from unnest(coalesce(p_reinforcement_card_ids,array[]::uuid[]))with ordinality x(id,ord) where mc.id=x.id;
  select array_agg(id order by n) into bot_life from(select id,row_number()over()n from public.match_cards where match_id=p_match_id and owner_user_id=bot and zone='hand' order by random() limit 3)q;
  update public.match_cards mc set zone='life',zone_position=x.ord,is_face_up=true,entered_zone_turn=0 from unnest(bot_life)with ordinality x(id,ord) where mc.id=x.id;
  select array_agg(id order by n) into bot_reinforcement from(select id,row_number()over()n from public.match_cards where match_id=p_match_id and owner_user_id=bot and zone='hand' order by random() limit 4)q;
  update public.match_cards mc set zone='reinforcement',zone_position=x.ord,is_face_up=false,entered_zone_turn=0 from unnest(coalesce(bot_reinforcement,array[]::uuid[]))with ordinality x(id,ord) where mc.id=x.id;
  loop human_roll:=floor(random()*20+1)::integer;bot_roll:=floor(random()*20+1)::integer;exit when human_roll<>bot_roll;end loop;
  active:=case when human_roll>bot_roll then human else bot end;
  update public.match_players set setup_finished=true where match_id=p_match_id;
  perform game_private.sync_player_hand_mana(p_match_id,human);perform game_private.sync_player_hand_mana(p_match_id,bot);
  update public.matches set status='in_progress',current_turn=1,active_player_id=active,initiative_result=jsonb_build_object('mode','d20','player1',human_roll,'player2',bot_roll,'winner_user_id',active) where id=p_match_id;
  version:=game_private.record_match_action(p_match_id,human,'setup_submitted',jsonb_build_object('setup_complete',true,'active_player_id',active,'initiative',jsonb_build_object('mode','d20','player1',human_roll,'player2',bot_roll,'winner_user_id',active)),jsonb_build_object('life_card_ids',p_life_card_ids,'reinforcement_card_ids',p_reinforcement_card_ids),p_expected_version);
  return jsonb_build_object('match_started',true,'active_player_id',active,'state_version',version,'initiative',jsonb_build_object('mode','d20','player1',human_roll,'player2',bot_roll,'winner_user_id',active));
end $$;

-- A IA declara combate pela mesma pending_attacks usada no PvP. Não aplica dano direto.
create or replace function public.run_training_bot_turn(p_match_id uuid,p_expected_version bigint)
returns jsonb language plpgsql security definer set search_path='' as $$
declare human uuid:=game_private.require_authenticated();bot uuid;m public.matches;played uuid;attacker uuid;slot_no integer;version bigint;attack_id uuid;power integer;bot_actions integer;
begin
  select bot_user_id into bot from public.training_matches where match_id=p_match_id and human_user_id=human;
  if bot is null then raise exception 'NOT_YOUR_TRAINING_MATCH'; end if;
  select * into m from public.matches where id=p_match_id for update;
  if not found then raise exception 'MATCH_NOT_FOUND';end if;
  if m.state_version<>p_expected_version then raise exception 'STALE_MATCH_VERSION';end if;
  if m.status<>'in_progress' or m.engine_state<>'turn_action' then raise exception 'MATCH_FLOW_IS_BLOCKED';end if;
  if m.active_player_id<>bot then raise exception 'BOT_IS_NOT_ACTIVE_PLAYER';end if;
  select actions_this_turn into bot_actions from public.match_players where match_id=p_match_id and user_id=bot for update;
  select s into slot_no from generate_series(1,4)s where not exists(select 1 from public.match_cards where match_id=p_match_id and controller_user_id=bot and zone='attacker' and zone_position=s) order by s limit 1;
  if coalesce(bot_actions,0)=0 and slot_no is not null then select id into played from public.match_cards where match_id=p_match_id and owner_user_id=bot and zone='hand' order by random() limit 1 for update;end if;
  version:=p_expected_version;
  if played is not null then
    update public.match_cards set zone='attacker',zone_position=slot_no,is_face_up=true,entered_zone_turn=m.current_turn where id=played;
    update public.match_players set actions_this_turn=actions_this_turn+1 where match_id=p_match_id and user_id=bot;
    version:=game_private.record_match_action(p_match_id,bot,'card_played',jsonb_build_object('match_card_id',played,'destination_zone','attacker','destination_position',slot_no,'training_bot',true),'{}',version);
    -- Uma chamada representa exatamente uma ação visual da IA. O cliente só
    -- solicitará o próximo passo depois do Realtime e do intervalo de cadência.
    return jsonb_build_object('action','card_played','played_card_id',played,'state_version',version,'bot_turn_complete',false);
  end if;
  select id,current_power into attacker,power from public.match_cards where match_id=p_match_id and controller_user_id=bot and zone='attacker' and current_life>0 and can_attack and not has_attacked_this_turn order by random() limit 1 for update;
  if attacker is null then return game_private.change_active_turn(p_match_id,bot,coalesce((select actions_this_turn=0 from public.match_players where match_id=p_match_id and user_id=bot),true),version);end if;
  insert into public.pending_attacks(match_id,attacker_user_id,defender_user_id,status,is_direct,declared_power,reaction_deadline,declared_state_version)
  values(p_match_id,bot,human,'awaiting_reaction',false,greatest(power,0),now()+interval '20 seconds',version) returning id into attack_id;
  insert into public.pending_attack_cards(pending_attack_id,match_card_id,attack_position,power_when_declared)values(attack_id,attacker,1,greatest(power,0));
  update public.match_cards set metadata=metadata||jsonb_build_object('locked_for_pending_attack',attack_id) where id=attacker;
  update public.match_players set actions_this_turn=actions_this_turn+1 where match_id=p_match_id and user_id=bot;
  version:=game_private.record_match_action(p_match_id,bot,'attack_declared',jsonb_build_object('pending_attack_id',attack_id,'attacker_user_id',bot,'defender_user_id',human,'attacker_card_ids',jsonb_build_array(attacker),'total_power',greatest(power,0),'is_direct',false,'reaction_deadline',now()+interval '20 seconds','training_bot',true),'{}',version);
  update public.pending_attacks set declared_state_version=version where id=attack_id;
  return jsonb_build_object('pending_attack_id',attack_id,'state_version',version,'awaiting_reaction',true);
end $$;

update public.game_rule_versions set reaction_window_seconds=20 where version_name='ofieri-1.0';

revoke all on function public.submit_training_setup(uuid,uuid[],uuid[],bigint) from public,anon;
revoke all on function public.run_training_bot_turn(uuid,bigint) from public,anon;
grant execute on function public.submit_training_setup(uuid,uuid[],uuid[],bigint) to authenticated;
grant execute on function public.run_training_bot_turn(uuid,bigint) to authenticated;

notify pgrst,'reload schema';
commit;
