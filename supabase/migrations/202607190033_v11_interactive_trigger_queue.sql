-- V11.0: gatilhos opcionais e visíveis. Somente passivas permanecem silenciosas.
begin;

create table if not exists public.pending_card_triggers (
  id uuid primary key default gen_random_uuid(),
  match_id uuid not null references public.matches(id) on delete cascade,
  owner_user_id uuid not null references public.profiles(id) on delete cascade,
  source_match_card_id uuid not null references public.match_cards(id) on delete cascade,
  event_id bigint references public.match_effect_events(id) on delete set null,
  effect_order integer not null,
  effect_code text not null,
  trigger_type text not null,
  target_mode text not null default 'none',
  mana_cost integer not null check(mana_cost>=0),
  description text not null default '',
  event_payload jsonb not null default '{}',
  status text not null default 'pending' check(status in('pending','activated','declined','expired','failed')),
  expected_state_version bigint not null,
  expires_at timestamptz not null default(clock_timestamp()+interval '90 seconds'),
  resolved_at timestamptz,
  created_at timestamptz not null default clock_timestamp(),
  unique(event_id,effect_order)
);
create index if not exists pending_card_triggers_match_idx on public.pending_card_triggers(match_id,status,created_at);
alter table public.pending_card_triggers enable row level security;
drop policy if exists pending_card_triggers_owner_read on public.pending_card_triggers;
create policy pending_card_triggers_owner_read on public.pending_card_triggers for select to authenticated using(owner_user_id=auth.uid());
revoke all on public.pending_card_triggers from public,anon,authenticated;
grant select on public.pending_card_triggers to authenticated;

alter table public.matches drop constraint if exists matches_engine_state_check;
alter table public.matches add constraint matches_engine_state_check check (
  engine_state in('lifecycle','ban_phase','setup','turn_action','pending_trigger','reaction_window','resolving','finished')
);

create or replace function game_private.refresh_match_engine_state(p_match_id uuid)
returns void language plpgsql security definer set search_path='' as $$
declare v_next text;
begin
  select case
    when m.status='ban_phase' then 'ban_phase'
    when m.status='setup' then 'setup'
    when m.status='finished' then 'finished'
    when m.status<>'in_progress' then 'lifecycle'
    when exists(select 1 from public.pending_card_triggers pct where pct.match_id=m.id and pct.status='pending' and pct.expires_at>clock_timestamp()) then 'pending_trigger'
    when exists(select 1 from public.pending_attacks pa where pa.match_id=m.id and pa.status='resolving') then 'resolving'
    when exists(select 1 from public.pending_attacks pa where pa.match_id=m.id and pa.status in('awaiting_reaction','reaction_used','reaction_declined')) then 'reaction_window'
    else 'turn_action' end into v_next
  from public.matches m where m.id=p_match_id;
  update public.matches set engine_state=v_next where id=p_match_id and engine_state is distinct from v_next;
end $$;

create or replace function game_private.sync_engine_state_from_card_trigger()
returns trigger language plpgsql security definer set search_path='' as $$
begin perform game_private.refresh_match_engine_state(coalesce(new.match_id,old.match_id)); return coalesce(new,old); end $$;
drop trigger if exists pending_card_triggers_sync_engine_state on public.pending_card_triggers;
create trigger pending_card_triggers_sync_engine_state after insert or update of status or delete on public.pending_card_triggers for each row execute function game_private.sync_engine_state_from_card_trigger();

-- Substitui a automação cega: passivas executam; todo outro gatilho vira uma
-- decisão persistida, visível por Realtime e processada somente após SIM/NÃO.
create or replace function game_private.process_one_effect_event(p_event_id bigint)
returns void language plpgsql security definer set search_path='' as $$
declare
  v_event public.match_effect_events; v_effect record; v_owner uuid; v_cost integer;
  v_result jsonb; v_turn integer; v_description text;
begin
  select mee.* into v_event from public.match_effect_events mee where mee.id=p_event_id and mee.status='pending' for update skip locked;
  if not found then return; end if;
  update public.match_effect_events set status='processing' where id=v_event.id;
  select mc.owner_user_id into v_owner from public.match_cards mc where mc.id=v_event.source_match_card_id;
  select m.current_turn into v_turn from public.matches m where m.id=v_event.match_id;
  for v_effect in select * from game_private.card_snapshot_effects(v_event.source_match_card_id,v_event.event_type) loop
    begin
      if v_effect.once_per_turn and exists(select 1 from public.match_effect_uses meu where meu.match_id=v_event.match_id and meu.match_card_id=v_event.source_match_card_id and meu.effect_order=v_effect.effect_order and meu.turn_number=v_turn) then continue; end if;
      v_cost:=greatest(0,coalesce((v_effect.parameters->>'mana_cost')::integer,game_private.effect_card_cost(v_event.source_match_card_id),0));
      select coalesce(c.effect_text,'') into v_description from public.match_cards mc join public.cards c on c.id=mc.source_card_id where mc.id=v_event.source_match_card_id;
      if v_event.event_type='passive' then
        v_result:=game_private.execute_common_effect_internal(v_event.match_id,v_owner,v_event.source_match_card_id,v_effect.effect_code,v_effect.parameters,v_event.target_match_card_id,v_event.payload);
        insert into public.match_effect_execution_log(match_id,event_id,source_match_card_id,card_effect_id,effect_code,result) values(v_event.match_id,v_event.id,v_event.source_match_card_id,v_effect.effect_id,v_effect.effect_code,coalesce(v_result,'{}'));
      else
        insert into public.pending_card_triggers(match_id,owner_user_id,source_match_card_id,event_id,effect_order,effect_code,trigger_type,target_mode,mana_cost,description,event_payload,expected_state_version)
        values(v_event.match_id,v_owner,v_event.source_match_card_id,v_event.id,v_effect.effect_order,v_effect.effect_code,v_event.event_type,v_effect.target_mode,v_cost,v_description,v_event.payload,(select m.state_version from public.matches m where m.id=v_event.match_id))
        on conflict(event_id,effect_order) do nothing;
      end if;
    exception when others then
      insert into public.match_effect_execution_log(match_id,event_id,source_match_card_id,card_effect_id,effect_code,result) values(v_event.match_id,v_event.id,v_event.source_match_card_id,v_effect.effect_id,v_effect.effect_code,jsonb_build_object('failed',true,'sqlstate',sqlstate,'message',sqlerrm));
    end;
  end loop;
  update public.match_effect_events set status='resolved',resolved_at=clock_timestamp() where id=v_event.id;
  perform game_private.refresh_match_engine_state(v_event.match_id);
exception when others then
  update public.match_effect_events set status='failed',error_message=sqlstate||': '||sqlerrm,resolved_at=clock_timestamp() where id=p_event_id;
end $$;

create or replace function game_private.process_inserted_effect_event_v11()
returns trigger language plpgsql security definer set search_path='' as $$
begin perform game_private.process_one_effect_event(new.id); return new; end $$;
drop trigger if exists match_effect_events_process_v11 on public.match_effect_events;
create trigger match_effect_events_process_v11 after insert on public.match_effect_events for each row execute function game_private.process_inserted_effect_event_v11();

create or replace function public.get_my_pending_card_trigger(p_match_id uuid)
returns table(id uuid,match_id uuid,owner_user_id uuid,source_match_card_id uuid,effect_order integer,effect_code text,trigger_type text,target_mode text,mana_cost integer,description text,expected_state_version bigint,expires_at timestamptz)
language plpgsql security definer set search_path='' as $$
begin
  update public.pending_card_triggers set status='expired',resolved_at=clock_timestamp() where match_id=p_match_id and status='pending' and expires_at<=clock_timestamp();
  perform game_private.refresh_match_engine_state(p_match_id);
  return query select pct.id,pct.match_id,pct.owner_user_id,pct.source_match_card_id,pct.effect_order,pct.effect_code,pct.trigger_type,pct.target_mode,pct.mana_cost,pct.description,pct.expected_state_version,pct.expires_at
  from public.pending_card_triggers pct where pct.match_id=p_match_id and pct.owner_user_id=auth.uid() and pct.status='pending' order by pct.created_at,pct.id limit 1;
end
$$;

create or replace function public.resolve_pending_card_trigger(p_trigger_id uuid,p_activate boolean,p_target_card_id uuid default null,p_expected_version bigint default 0)
returns jsonb language plpgsql security definer set search_path='' as $$
declare
  v_actor uuid:=game_private.require_authenticated(); v_trigger public.pending_card_triggers;
  v_match public.matches; v_source public.match_cards; v_params jsonb; v_result jsonb:='{}'; v_version bigint; v_target uuid:=p_target_card_id;
begin
  select pct.* into v_trigger from public.pending_card_triggers pct where pct.id=p_trigger_id and pct.owner_user_id=v_actor and pct.status='pending' for update;
  if not found then raise exception 'PENDING_TRIGGER_NOT_FOUND'; end if;
  select m.* into v_match from public.matches m where m.id=v_trigger.match_id for update;
  if v_match.state_version<>p_expected_version then raise exception 'STALE_MATCH_VERSION'; end if;
  if v_trigger.expires_at<=clock_timestamp() then
    update public.pending_card_triggers set status='expired',resolved_at=clock_timestamp() where id=v_trigger.id;
    perform game_private.refresh_match_engine_state(v_trigger.match_id); raise exception 'PENDING_TRIGGER_EXPIRED';
  end if;
  if not p_activate then
    update public.pending_card_triggers set status='declined',resolved_at=clock_timestamp() where id=v_trigger.id;
    v_version:=game_private.record_match_action(v_trigger.match_id,v_actor,'effect_trigger_declined',jsonb_build_object('source_card_id',v_trigger.source_match_card_id,'effect_code',v_trigger.effect_code,'trigger_type',v_trigger.trigger_type),'{}'::jsonb,p_expected_version);
    perform game_private.refresh_match_engine_state(v_trigger.match_id);
    return jsonb_build_object('activated',false,'state_version',v_version);
  end if;
  if (select count(*) from public.match_cards mc where mc.match_id=v_trigger.match_id and mc.owner_user_id=v_actor and mc.zone='hand')<v_trigger.mana_cost then raise exception 'INSUFFICIENT_MANA'; end if;
  select mc.* into v_source from public.match_cards mc where mc.id=v_trigger.source_match_card_id and mc.match_id=v_trigger.match_id and mc.owner_user_id=v_actor for update;
  if not found then raise exception 'EFFECT_SOURCE_NOT_FOUND'; end if;
  select coalesce(x.value->'parameters','{}'::jsonb) into v_params from public.match_deck_cards d cross join lateral jsonb_array_elements(d.effect_definition) x(value) where d.id=v_source.match_deck_card_id and (x.value->>'effect_order')::integer=v_trigger.effect_order;
  if v_target is null and v_trigger.target_mode='graveyard' then select mc.id into v_target from public.match_cards mc where mc.match_id=v_trigger.match_id and mc.owner_user_id=v_actor and mc.zone='graveyard' and mc.id<>v_trigger.source_match_card_id order by random() limit 1; end if;
  perform game_private.pay_common_effect_cost(v_trigger.match_id,v_actor,v_trigger.mana_cost);
  v_result:=game_private.execute_common_effect_internal(v_trigger.match_id,v_actor,v_trigger.source_match_card_id,v_trigger.effect_code,coalesce(v_params,'{}'::jsonb),v_target,v_trigger.event_payload);
  insert into public.match_effect_uses(match_id,match_card_id,actor_user_id,effect_order,turn_number,is_reaction,mana_spent) values(v_trigger.match_id,v_trigger.source_match_card_id,v_actor,v_trigger.effect_order,v_match.current_turn,false,v_trigger.mana_cost) on conflict do nothing;
  update public.pending_card_triggers set status='activated',resolved_at=clock_timestamp() where id=v_trigger.id;
  v_version:=game_private.record_match_action(v_trigger.match_id,v_actor,'effect_activated',jsonb_build_object('source_card_id',v_trigger.source_match_card_id,'effect_order',v_trigger.effect_order,'effect_code',v_trigger.effect_code,'trigger_type',v_trigger.trigger_type,'mana_spent',v_trigger.mana_cost,'result',v_result),'{}'::jsonb,p_expected_version);
  perform game_private.refresh_match_engine_state(v_trigger.match_id);
  return v_result||jsonb_build_object('activated',true,'state_version',v_version,'mana_spent',v_trigger.mana_cost);
end $$;

create or replace function public.resolve_training_bot_trigger(p_match_id uuid,p_expected_version bigint)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_human uuid:=game_private.require_authenticated(); v_bot uuid; v_trigger public.pending_card_triggers; v_match public.matches; v_source public.match_cards; v_params jsonb; v_target uuid; v_result jsonb:='{}'; v_version bigint; v_hand integer;
begin
  select tm.bot_user_id into v_bot from public.training_matches tm where tm.match_id=p_match_id and tm.human_user_id=v_human;
  if v_bot is null then raise exception 'NOT_YOUR_TRAINING_MATCH'; end if;
  select m.* into v_match from public.matches m where m.id=p_match_id for update;
  if v_match.state_version<>p_expected_version then raise exception 'STALE_MATCH_VERSION'; end if;
  select pct.* into v_trigger from public.pending_card_triggers pct where pct.match_id=p_match_id and pct.owner_user_id=v_bot and pct.status='pending' order by pct.created_at limit 1 for update;
  if not found then raise exception 'BOT_PENDING_TRIGGER_NOT_FOUND'; end if;
  select count(*)::integer into v_hand from public.match_cards mc where mc.match_id=p_match_id and mc.owner_user_id=v_bot and mc.zone='hand';
  if v_hand-v_trigger.mana_cost<2 then
    update public.pending_card_triggers set status='declined',resolved_at=clock_timestamp() where id=v_trigger.id;
    v_version:=game_private.record_match_action(p_match_id,v_bot,'effect_trigger_declined',jsonb_build_object('source_card_id',v_trigger.source_match_card_id,'effect_code',v_trigger.effect_code,'trigger_type',v_trigger.trigger_type,'training_bot',true,'reason','mana_preservation'),'{}'::jsonb,p_expected_version);
    perform game_private.refresh_match_engine_state(p_match_id); return jsonb_build_object('activated',false,'state_version',v_version);
  end if;
  select mc.* into v_source from public.match_cards mc where mc.id=v_trigger.source_match_card_id for update;
  select coalesce(x.value->'parameters','{}'::jsonb) into v_params from public.match_deck_cards d cross join lateral jsonb_array_elements(d.effect_definition) x(value) where d.id=v_source.match_deck_card_id and (x.value->>'effect_order')::integer=v_trigger.effect_order;
  if v_trigger.target_mode='graveyard' then select mc.id into v_target from public.match_cards mc where mc.match_id=p_match_id and mc.owner_user_id=v_bot and mc.zone='graveyard' and mc.id<>v_trigger.source_match_card_id order by random() limit 1; end if;
  perform game_private.pay_common_effect_cost(p_match_id,v_bot,v_trigger.mana_cost);
  v_result:=game_private.execute_common_effect_internal(p_match_id,v_bot,v_trigger.source_match_card_id,v_trigger.effect_code,coalesce(v_params,'{}'::jsonb),v_target,v_trigger.event_payload);
  insert into public.match_effect_uses(match_id,match_card_id,actor_user_id,effect_order,turn_number,is_reaction,mana_spent) values(p_match_id,v_trigger.source_match_card_id,v_bot,v_trigger.effect_order,v_match.current_turn,false,v_trigger.mana_cost) on conflict do nothing;
  update public.pending_card_triggers set status='activated',resolved_at=clock_timestamp() where id=v_trigger.id;
  v_version:=game_private.record_match_action(p_match_id,v_bot,'effect_activated',jsonb_build_object('source_card_id',v_trigger.source_match_card_id,'effect_code',v_trigger.effect_code,'trigger_type',v_trigger.trigger_type,'mana_spent',v_trigger.mana_cost,'training_bot',true,'result',v_result),'{}'::jsonb,p_expected_version);
  perform game_private.refresh_match_engine_state(p_match_id); return v_result||jsonb_build_object('activated',true,'state_version',v_version);
exception when others then
  if v_trigger.id is not null then
    update public.pending_card_triggers set status='failed',resolved_at=clock_timestamp() where id=v_trigger.id;
    perform game_private.refresh_match_engine_state(p_match_id);
  end if;
  return jsonb_build_object('activated',false,'bot_error_code',sqlstate,'bot_error_message',sqlerrm,'state_version',p_expected_version);
end $$;

revoke all on function public.get_my_pending_card_trigger(uuid),public.resolve_pending_card_trigger(uuid,boolean,uuid,bigint),public.resolve_training_bot_trigger(uuid,bigint) from public,anon;
grant execute on function public.get_my_pending_card_trigger(uuid),public.resolve_pending_card_trigger(uuid,boolean,uuid,bigint),public.resolve_training_bot_trigger(uuid,bigint) to authenticated;

do $$ begin
  if exists(select 1 from pg_publication where pubname='supabase_realtime') and not exists(select 1 from pg_publication_tables where pubname='supabase_realtime' and schemaname='public' and tablename='pending_card_triggers') then
    alter publication supabase_realtime add table public.pending_card_triggers;
  end if;
end $$;
alter table public.pending_card_triggers replica identity full;
notify pgrst,'reload schema';
commit;
