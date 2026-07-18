-- Runtime autoritativo para efeitos compostos das cartas comuns.
create table if not exists public.match_runtime_effects (
 id uuid primary key default gen_random_uuid(), match_id uuid not null references public.matches(id) on delete cascade,
 owner_user_id uuid not null references public.profiles(id), source_match_card_id uuid references public.match_cards(id) on delete cascade,
 effect_code text not null, scope text not null check(scope in('card','player','match','next_draw','next_turn','turn_end')),
 target_user_id uuid references public.profiles(id), target_match_card_id uuid references public.match_cards(id) on delete cascade,
 payload jsonb not null default '{}', starts_on_turn integer not null, expires_on_turn integer, active boolean not null default true,
 consumed_at timestamptz, created_at timestamptz not null default now()
);
create index if not exists match_runtime_effects_active_idx on public.match_runtime_effects(match_id,effect_code) where active;

create table if not exists public.match_private_reveals (
 id uuid primary key default gen_random_uuid(), match_id uuid not null references public.matches(id) on delete cascade,
 viewer_user_id uuid not null references public.profiles(id) on delete cascade, source_match_card_id uuid references public.match_cards(id) on delete set null,
 revealed_match_card_id uuid not null references public.match_cards(id) on delete cascade, reveal_type text not null,
 expires_at timestamptz not null default (now()+interval '30 seconds'), created_at timestamptz not null default now()
);
alter table public.match_private_reveals enable row level security;
drop policy if exists match_private_reveals_viewer_read on public.match_private_reveals;
create policy match_private_reveals_viewer_read on public.match_private_reveals for select to authenticated using(viewer_user_id=auth.uid() and expires_at>now());

create table if not exists public.match_effect_events (
 id bigint generated always as identity primary key, chain_id uuid not null, match_id uuid not null references public.matches(id) on delete cascade,
 event_type text not null, actor_user_id uuid references public.profiles(id), source_match_card_id uuid references public.match_cards(id) on delete set null,
 target_match_card_id uuid references public.match_cards(id) on delete set null, payload jsonb not null default '{}', depth integer not null default 0,
 status text not null default 'pending' check(status in('pending','processing','resolved','failed','skipped')),
 error_message text, created_at timestamptz not null default now(), resolved_at timestamptz,
 check(depth between 0 and 32)
);
create index if not exists match_effect_events_pending_idx on public.match_effect_events(match_id,status,id);

create table if not exists public.match_effect_execution_log (
 id bigint generated always as identity primary key, match_id uuid not null references public.matches(id) on delete cascade,
 event_id bigint references public.match_effect_events(id) on delete set null, source_match_card_id uuid references public.match_cards(id) on delete set null,
 card_effect_id uuid references public.card_effects(id) on delete set null, effect_code text not null, result jsonb not null default '{}',
 created_at timestamptz not null default now()
);

alter table public.match_runtime_effects enable row level security;
alter table public.match_effect_events enable row level security;
alter table public.match_effect_execution_log enable row level security;
drop policy if exists runtime_effects_participant_read on public.match_runtime_effects;
create policy runtime_effects_participant_read on public.match_runtime_effects for select to authenticated using(exists(select 1 from public.match_players mp where mp.match_id=match_runtime_effects.match_id and mp.user_id=auth.uid()));
drop policy if exists effect_log_participant_read on public.match_effect_execution_log;
create policy effect_log_participant_read on public.match_effect_execution_log for select to authenticated using(exists(select 1 from public.match_players mp where mp.match_id=match_effect_execution_log.match_id and mp.user_id=auth.uid()));

create or replace function game_private.queue_match_effect_event(p_match_id uuid,p_event_type text,p_actor_user_id uuid,p_source_match_card_id uuid default null,p_target_match_card_id uuid default null,p_payload jsonb default '{}',p_chain_id uuid default gen_random_uuid(),p_depth integer default 0) returns bigint
language plpgsql security definer set search_path='' as $$ declare v_id bigint; begin
 if p_depth>32 then raise exception 'EFFECT_CHAIN_DEPTH_EXCEEDED'; end if;
 insert into public.match_effect_events(chain_id,match_id,event_type,actor_user_id,source_match_card_id,target_match_card_id,payload,depth)
 values(p_chain_id,p_match_id,p_event_type,p_actor_user_id,p_source_match_card_id,p_target_match_card_id,coalesce(p_payload,'{}'),p_depth) returning id into v_id;
 return v_id;
end $$;

create or replace function game_private.card_snapshot_effects(p_match_card_id uuid,p_trigger_type text) returns table(effect_id uuid,effect_order integer,effect_code text,target_mode text,parameters jsonb,is_reaction boolean,once_per_turn boolean)
language sql stable security definer set search_path='' as $$
 select null::uuid,(x->>'effect_order')::integer,x->>'effect_code',x->>'target_mode',coalesce(x->'parameters','{}'::jsonb),coalesce((x->>'is_reaction')::boolean,false),coalesce((x->>'once_per_turn')::boolean,false)
 from public.match_cards mc join public.match_deck_cards mdc on mdc.id=mc.match_deck_card_id cross join lateral jsonb_array_elements(mdc.effect_definition) x
 where mc.id=p_match_card_id and x->>'trigger_type'=p_trigger_type and coalesce((x->>'is_active')::boolean,true)
 order by coalesce((x->>'priority')::integer,0) desc,(x->>'effect_order')::integer;
$$;

revoke all on public.match_runtime_effects,public.match_effect_events,public.match_effect_execution_log,public.match_private_reveals from anon;
grant select on public.match_runtime_effects,public.match_effect_execution_log,public.match_private_reveals to authenticated;
