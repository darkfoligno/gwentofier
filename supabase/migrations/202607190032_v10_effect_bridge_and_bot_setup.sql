-- V10.0: fecha a ponte de efeitos de ataque e humaniza a montagem do Autômato.
begin;

create or replace function game_private.bridge_match_action_effects()
returns trigger language plpgsql security definer set search_path='' as $$
declare
  v_active uuid;
  v_card record;
  v_card_id uuid;
  v_target_id uuid;
  v_target jsonb;
begin
  if new.action_type in ('turn_ended','turn_passed_without_action','turn_passed') then
    for v_card in select mc.id from public.match_cards mc where mc.match_id=new.match_id and mc.controller_user_id=new.actor_user_id and mc.zone in('life','reinforcement','attacker','leader') and mc.current_life>0 loop
      perform game_private.queue_match_effect_event(new.match_id,'on_turn_end',new.actor_user_id,v_card.id,null,new.payload_public);
    end loop;
    select m.active_player_id into v_active from public.matches m where m.id=new.match_id;
    for v_card in select mc.id from public.match_cards mc where mc.match_id=new.match_id and mc.controller_user_id=v_active and mc.zone in('life','reinforcement','attacker','leader') and mc.current_life>0 loop
      perform game_private.queue_match_effect_event(new.match_id,'on_turn_start',v_active,v_card.id,null,new.payload_public);
    end loop;
  elsif new.action_type='attack_declared' then
    for v_card_id in select value::uuid from jsonb_array_elements_text(coalesce(new.payload_public->'attacker_card_ids','[]'::jsonb)) loop
      perform game_private.queue_match_effect_event(new.match_id,'on_attack_declared',new.actor_user_id,v_card_id,null,new.payload_public);
    end loop;
  elsif new.action_type='attack_resolved' then
    -- O payload autoritativo é plural. A versão antiga esperava attacker_card_id e
    -- deixava todos os efeitos on_attack_resolved sem despacho.
    for v_card_id in select value::uuid from jsonb_array_elements_text(coalesce(new.payload_public->'attacker_card_ids','[]'::jsonb)) loop
      perform game_private.queue_match_effect_event(new.match_id,'on_attack_resolved',new.actor_user_id,v_card_id,null,new.payload_public);
    end loop;
    if new.payload_public->>'attacker_card_id' is not null and new.payload_public->'attacker_card_ids' is null then
      perform game_private.queue_match_effect_event(new.match_id,'on_attack_resolved',new.actor_user_id,(new.payload_public->>'attacker_card_id')::uuid,(new.payload_public->>'target_card_id')::uuid,new.payload_public);
    end if;
    -- Reforços/vidas sobreviventes atingidos também recebem seu evento defensivo.
    for v_target in
      select value from jsonb_array_elements(coalesce(new.payload_public->'reinforcements','[]'::jsonb))
      union all
      select new.payload_public->'life' where jsonb_typeof(new.payload_public->'life')='object'
    loop
      v_target_id:=coalesce((v_target->>'card_id')::uuid,(v_target->>'target_card_id')::uuid);
      if v_target_id is not null and coalesce((v_target->>'final_hp')::integer,0)>0 then
        perform game_private.queue_match_effect_event(new.match_id,'on_attack_resolved',new.actor_user_id,v_target_id,null,new.payload_public);
      end if;
    end loop;
  end if;
  perform game_private.process_match_effect_queue(new.match_id);
  return new;
end $$;

create or replace function game_private.enforce_common_attack_rules()
returns trigger language plpgsql security definer set search_path='' as $$
declare
  v_attack public.pending_attacks;
  v_actor uuid;
  v_code text;
  v_hand integer;
  v_common integer;
  v_power integer;
  v_card_id uuid;
begin
  select pa.* into v_attack from public.pending_attacks pa where pa.id=new.pending_attack_id for update;
  v_actor:=v_attack.attacker_user_id;
  select c.code into v_code from public.match_cards mc join public.cards c on c.id=mc.source_card_id where mc.id=new.match_card_id;

  if v_code='COMMON_003' then
    select count(*),count(*) filter(where d.rarity='common') into v_hand,v_common
    from public.match_cards mc join public.match_deck_cards d on d.id=mc.match_deck_card_id
    where mc.match_id=v_attack.match_id and mc.owner_user_id=v_actor and mc.zone='hand';
    if v_hand=0 or v_hand<>v_common then raise exception 'JAVALI_REQUIRES_NONEMPTY_COMMON_ONLY_HAND'; end if;
    update public.pending_attacks set result=result||'{"suppress_reinforcement_reveal":true,"suppress_reinforcement_reaction":true}' where id=v_attack.id;
  elsif v_code='COMMON_007' then
    if (select count(*) from public.match_cards where match_id=v_attack.match_id and owner_user_id=v_actor and zone='graveyard')>=5 then
      update public.pending_attacks set is_direct=true,result=result||'{"direct_effect":"COMMON_007"}' where id=v_attack.id;
    end if;
  elsif v_code='COMMON_022' then
    if (select count(*) from public.match_cards where match_id=v_attack.match_id and owner_user_id=v_actor and zone='hand') >
       (select count(*) from public.match_cards where match_id=v_attack.match_id and owner_user_id=v_attack.defender_user_id and zone='hand') then
      update public.pending_attacks set is_direct=true,result=result||'{"direct_effect":"COMMON_022"}' where id=v_attack.id;
    end if;
  elsif v_code='COMMON_024' then
    if (select count(*) from public.match_cards where match_id=v_attack.match_id and owner_user_id=v_actor and zone='hand')>=3 then
      for v_card_id in select id from public.match_cards where match_id=v_attack.match_id and owner_user_id=v_actor and zone='hand' order by random() limit 3 loop
        perform game_private.move_card_checked(v_card_id,'graveyard',null,true);
      end loop;
      update public.pending_attacks set is_direct=true,result=result||'{"direct_effect":"COMMON_024","discarded":3}' where id=v_attack.id;
    end if;
  elsif v_code='COMMON_048' then
    if (select count(*) from public.match_cards mc where mc.match_id=v_attack.match_id and mc.owner_user_id=v_actor and mc.zone='hand' and game_private.effect_card_cost(mc.id)>0)=0 then
      update public.pending_attacks set is_direct=true,result=result||'{"direct_effect":"COMMON_048"}' where id=v_attack.id;
    end if;
  elsif v_code='COMMON_056' then
    if exists(select 1 from public.match_cards mc join public.match_deck_cards d on d.id=mc.match_deck_card_id where mc.match_id=v_attack.match_id and mc.owner_user_id=v_actor and mc.zone='life' and mc.current_life>0 and d.element='Bestiário') then
      update public.pending_attacks set is_direct=true,result=result||'{"direct_effect":"COMMON_056"}' where id=v_attack.id;
    end if;
  elsif v_code='COMMON_057' then
    if exists(select 1 from public.match_runtime_effects rt where rt.match_id=v_attack.match_id and rt.source_match_card_id=new.match_card_id and rt.effect_code='common_harpy_absorb_and_attack' and rt.active) then
      select coalesce(sum(mc.current_power),0) into v_power from public.match_cards mc join public.match_deck_cards d on d.id=mc.match_deck_card_id where mc.match_id=v_attack.match_id and mc.owner_user_id=v_actor and mc.zone='deck' and d.card_name='Harpia';
      update public.pending_attack_cards set power_when_declared=power_when_declared+v_power where pending_attack_id=v_attack.id and match_card_id=new.match_card_id;
      update public.pending_attacks set declared_power=declared_power+v_power,is_direct=true,result=result||'{"force_farthest_life":true,"direct_effect":"COMMON_057"}' where id=v_attack.id;
      update public.match_runtime_effects set active=false,consumed_at=clock_timestamp() where match_id=v_attack.match_id and source_match_card_id=new.match_card_id and effect_code='common_harpy_absorb_and_attack' and active;
    end if;
  end if;
  return new;
end $$;

create or replace function public.submit_training_setup(
  p_match_id uuid,
  p_life_card_ids uuid[],
  p_reinforcement_card_ids uuid[] default array[]::uuid[],
  p_expected_version bigint default 0
)
returns jsonb language plpgsql security definer set search_path='' as $$
declare
  v_human uuid:=game_private.require_authenticated(); v_bot uuid; v_match public.matches;
  v_bot_life uuid[]; v_bot_reinforcement uuid[]; v_all uuid[]; v_version bigint; v_active uuid;
  v_human_roll integer; v_bot_roll integer; v_reinforcement_count integer; v_setup_roll double precision;
begin
  select tm.bot_user_id into v_bot from public.training_matches tm where tm.match_id=p_match_id and tm.human_user_id=v_human;
  if v_bot is null then raise exception 'NOT_YOUR_TRAINING_MATCH'; end if;
  v_match:=game_private.lock_match_for_action(p_match_id,p_expected_version,array['setup']);
  if cardinality(p_life_card_ids)<>3 or (select count(distinct x) from unnest(p_life_card_ids) x)<>3 then raise exception 'EXACTLY_THREE_DISTINCT_LIFE_CARDS_REQUIRED'; end if;
  if coalesce(cardinality(p_reinforcement_card_ids),0)>4 then raise exception 'TOO_MANY_REINFORCEMENTS'; end if;
  v_all:=p_life_card_ids||coalesce(p_reinforcement_card_ids,array[]::uuid[]);
  if (select count(distinct x) from unnest(v_all) x)<>cardinality(v_all) then raise exception 'DUPLICATED_SETUP_CARD'; end if;
  if exists(select 1 from unnest(v_all) x where not exists(select 1 from public.match_cards mc where mc.id=x and mc.match_id=p_match_id and mc.owner_user_id=v_human and mc.zone='hand')) then raise exception 'SETUP_CARD_NOT_IN_HAND'; end if;
  update public.match_cards mc set zone='life',zone_position=x.ord,is_face_up=true,entered_zone_turn=0 from unnest(p_life_card_ids) with ordinality x(id,ord) where mc.id=x.id;
  update public.match_cards mc set zone='reinforcement',zone_position=x.ord,is_face_up=false,entered_zone_turn=0 from unnest(coalesce(p_reinforcement_card_ids,array[]::uuid[])) with ordinality x(id,ord) where mc.id=x.id;

  select array_agg(q.id order by q.maximum_life desc,q.id) into v_bot_life from (select mc.id,mc.maximum_life from public.match_cards mc where mc.match_id=p_match_id and mc.owner_user_id=v_bot and mc.zone='hand' order by mc.maximum_life desc,mc.id limit 3) q;
  update public.match_cards mc set zone='life',zone_position=x.ord,is_face_up=true,entered_zone_turn=0 from unnest(v_bot_life) with ordinality x(id,ord) where mc.id=x.id;
  -- Distribuição pedida: 1=30%, 2=50%, 3=20%; nunca ocupa os quatro slots.
  v_setup_roll:=random();
  v_reinforcement_count:=case when v_setup_roll<0.30 then 1 when v_setup_roll<0.80 then 2 else 3 end;
  select array_agg(q.id order by q.maximum_life desc,q.id) into v_bot_reinforcement from (select mc.id,mc.maximum_life from public.match_cards mc where mc.match_id=p_match_id and mc.owner_user_id=v_bot and mc.zone='hand' order by mc.maximum_life desc,mc.id limit v_reinforcement_count) q;
  update public.match_cards mc set zone='reinforcement',zone_position=x.ord,is_face_up=false,entered_zone_turn=0 from unnest(coalesce(v_bot_reinforcement,array[]::uuid[])) with ordinality x(id,ord) where mc.id=x.id;

  loop v_human_roll:=floor(random()*20+1)::integer; v_bot_roll:=floor(random()*20+1)::integer; exit when v_human_roll<>v_bot_roll; end loop;
  v_active:=case when v_human_roll>v_bot_roll then v_human else v_bot end;
  update public.match_players set setup_finished=true where match_id=p_match_id;
  perform game_private.sync_player_hand_mana(p_match_id,v_human); perform game_private.sync_player_hand_mana(p_match_id,v_bot);
  update public.matches set status='in_progress',current_turn=1,active_player_id=v_active,initiative_result=jsonb_build_object('mode','d20','player1',v_human_roll,'player2',v_bot_roll,'winner_user_id',v_active) where id=p_match_id;
  v_version:=game_private.record_match_action(p_match_id,v_human,'setup_submitted',jsonb_build_object('player_user_id',v_human,'life_count',3,'reinforcement_count',cardinality(p_reinforcement_card_ids),'bot_reinforcement_count',v_reinforcement_count,'setup_complete',true,'active_player_id',v_active,'initiative',jsonb_build_object('mode','d20','player1',v_human_roll,'player2',v_bot_roll,'winner_user_id',v_active)),jsonb_build_object('life_card_ids',p_life_card_ids,'reinforcement_card_ids',p_reinforcement_card_ids),p_expected_version);
  return jsonb_build_object('match_started',true,'active_player_id',v_active,'state_version',v_version,'bot_reinforcement_count',v_reinforcement_count);
end $$;

-- Consumidores que não são uma ação imediata: o runtime existe até o evento
-- exato ocorrer, sem depender do cliente para aplicar a consequência.
create or replace function game_private.consume_v10_card_transition_effects()
returns trigger language plpgsql security definer set search_path='' as $$
declare v_runtime public.match_runtime_effects; v_skjall uuid; v_name text;
begin
  if old.zone='deck' and new.zone='hand' then
    select rt.* into v_runtime from public.match_runtime_effects rt
    where rt.match_id=new.match_id and rt.owner_user_id=new.owner_user_id and rt.active
      and rt.effect_code='common_lugos_next_civil_double_power'
      and exists(select 1 from public.match_deck_cards d where d.id=new.match_deck_card_id and d.element='Cívil')
    order by rt.created_at limit 1 for update;
    if found then
      new.base_power:=least(20000,new.base_power*2); new.maximum_power:=least(20000,new.maximum_power*2); new.current_power:=least(20000,new.current_power*2);
      update public.match_runtime_effects set active=false,consumed_at=clock_timestamp() where id=v_runtime.id;
    end if;
  end if;
  if old.zone in('life','reinforcement','attacker','leader') and new.zone in('graveyard','banished') then
    select d.card_name into v_name from public.match_deck_cards d where d.id=new.match_deck_card_id;
    if v_name ilike '%Ciri%' then
      select mc.id into v_skjall from public.match_cards mc join public.cards c on c.id=mc.source_card_id
      where mc.match_id=new.match_id and mc.owner_user_id=new.owner_user_id and mc.zone='deck' and c.code='COMMON_066'
      order by mc.zone_position limit 1;
      if v_skjall is not null then
        update public.match_cards set zone='graveyard',zone_position=null,is_face_up=true,is_destroyed=true,current_life=0 where id=v_skjall;
        new.zone:='hand'; new.zone_position:=null; new.is_face_up:=false; new.is_destroyed:=false; new.current_life:=greatest(1,new.maximum_life);
      end if;
    end if;
  end if;
  return new;
end $$;
drop trigger if exists match_cards_consume_v10_transition_effects on public.match_cards;
create trigger match_cards_consume_v10_transition_effects before update of zone on public.match_cards for each row execute function game_private.consume_v10_card_transition_effects();

create or replace function game_private.consume_v10_runtime_insert()
returns trigger language plpgsql security definer set search_path='' as $$
declare v_card uuid; v_slot integer;
begin
  if new.effect_code='common_general_reduce_max_mana' then
    update public.match_players set mana_available=greatest(0,mana_available-1),mana_snapshot=greatest(0,mana_snapshot-1) where match_id=new.match_id and user_id=new.target_user_id;
    new.active:=false; new.consumed_at:=clock_timestamp();
  elsif new.effect_code='common_kiyan_protect_deck_card' then
    select mc.id into v_card from public.match_cards mc join public.match_deck_cards d on d.id=mc.match_deck_card_id where mc.match_id=new.match_id and mc.owner_user_id=new.owner_user_id and mc.zone='deck' and d.element='M&F' order by random() limit 1;
    if v_card is not null then update public.match_cards set metadata=metadata||'{"effect_cost_immune":true}' where id=v_card; end if;
    new.target_match_card_id:=v_card; new.active:=false; new.consumed_at:=clock_timestamp();
  elsif new.effect_code='common_reynold_forced_dwarf_attack' then
    select mc.id into v_card from public.match_cards mc join public.match_deck_cards d on d.id=mc.match_deck_card_id where mc.match_id=new.match_id and mc.owner_user_id=new.owner_user_id and mc.zone='deck' and (d.card_name ilike '%Anão%' or d.effect_definition::text ilike '%Anão%') order by random() limit 1;
    select gs into v_slot from generate_series(1,4) gs where not exists(select 1 from public.match_cards mc where mc.match_id=new.match_id and mc.controller_user_id=new.owner_user_id and mc.zone='attacker' and mc.zone_position=gs) order by gs limit 1;
    if v_card is null or v_slot is null then
      update public.match_cards set zone='banished',zone_position=null,is_face_up=true where id=new.source_match_card_id;
    else
      update public.match_cards set zone='attacker',zone_position=v_slot,is_face_up=true where id=v_card;
    end if;
    new.target_match_card_id:=v_card; new.active:=false; new.consumed_at:=clock_timestamp();
  end if;
  return new;
end $$;
drop trigger if exists match_runtime_effects_consume_v10 on public.match_runtime_effects;
create trigger match_runtime_effects_consume_v10 before insert on public.match_runtime_effects for each row execute function game_private.consume_v10_runtime_insert();

create or replace function game_private.resolve_v10_attack_followups()
returns trigger language plpgsql security definer set search_path='' as $$
declare v_ids uuid[]; v_attacker uuid; v_code text; v_defender uuid; v_destroyed boolean; v_witcher_destroyed boolean; v_card uuid;
begin
  if new.action_type<>'attack_resolved' then return new; end if;
  select coalesce(array_agg(value::uuid),'{}') into v_ids from jsonb_array_elements_text(coalesce(new.payload_public->'attacker_card_ids','[]'::jsonb));
  if cardinality(v_ids)=0 and new.payload_public->>'attacker_card_id' is not null then v_ids:=array[(new.payload_public->>'attacker_card_id')::uuid]; end if;
  v_defender:=(new.payload_public->>'defender_user_id')::uuid;
  select exists(select 1 from jsonb_array_elements(coalesce(new.payload_public->'reinforcements','[]'::jsonb)) x(value) where coalesce((x.value->>'final_hp')::integer,1)=0) or coalesce((new.payload_public->'life'->>'final_hp')::integer,1)=0 into v_destroyed;
  select exists(select 1 from jsonb_array_elements(coalesce(new.payload_public->'reinforcements','[]'::jsonb)) x(value) where coalesce((x.value->>'final_hp')::integer,1)=0 and x.value->>'element'='Witcher') or (coalesce((new.payload_public->'life'->>'final_hp')::integer,1)=0 and new.payload_public->'life'->>'element'='Witcher') into v_witcher_destroyed;
  foreach v_attacker in array v_ids loop
    select c.code into v_code from public.match_cards mc join public.cards c on c.id=mc.source_card_id where mc.id=v_attacker;
    if v_code='COMMON_028' and new.payload_public->'life' is not null then
      update public.match_cards mc set base_power=least(20000,mc.base_power*2),maximum_power=least(20000,mc.maximum_power*2),current_power=least(20000,mc.current_power*2)
      from public.match_deck_cards d where d.id=mc.match_deck_card_id and mc.match_id=new.match_id and mc.owner_user_id=new.actor_user_id and mc.zone='deck' and d.card_name='Lobo';
    elsif cardinality(v_ids)=1 and v_code='COMMON_046' and v_witcher_destroyed then
      update public.match_cards set zone='graveyard',zone_position=null,is_face_up=true,is_destroyed=true,current_life=0 where match_id=new.match_id and owner_user_id=v_defender and zone='hand';
    elsif cardinality(v_ids)=1 and v_code='COMMON_051' and v_destroyed then
      select mc.id into v_card from public.match_cards mc join public.match_deck_cards d on d.id=mc.match_deck_card_id where mc.match_id=new.match_id and mc.owner_user_id=v_defender and mc.zone='deck' and d.rarity in('common','rare') order by random() limit 1;
      if v_card is not null then perform game_private.move_card_checked(v_card,'graveyard',null,true); end if;
    end if;
  end loop;
  return new;
end $$;
drop trigger if exists match_actions_v10_attack_followups on public.match_actions;
create trigger match_actions_v10_attack_followups after insert on public.match_actions for each row execute function game_private.resolve_v10_attack_followups();

revoke all on function public.submit_training_setup(uuid,uuid[],uuid[],bigint) from public,anon;
grant execute on function public.submit_training_setup(uuid,uuid[],uuid[],bigint) to authenticated;
notify pgrst,'reload schema';
commit;
