-- Feed Realtime sanitizado: views não participam de postgres_changes e a tabela
-- match_actions contém payload_private. Este espelho publica somente payload_public.
create table if not exists public.match_action_feed(
  action_id bigint primary key references public.match_actions(id) on delete cascade,
  match_id uuid not null references public.matches(id) on delete cascade,
  sequence_number bigint not null,
  actor_user_id uuid references public.profiles(id) on delete set null,
  action_type text not null,
  payload_public jsonb not null default '{}'::jsonb,
  state_version_before bigint not null,
  state_version_after bigint not null,
  created_at timestamptz not null,
  unique(match_id,sequence_number)
);
create index if not exists match_action_feed_match_sequence_idx on public.match_action_feed(match_id,sequence_number);
alter table public.match_action_feed enable row level security;
drop policy if exists match_action_feed_participant_read on public.match_action_feed;
create policy match_action_feed_participant_read on public.match_action_feed for select to authenticated
using(game_private.is_match_participant(match_id,auth.uid()));

create or replace function game_private.publish_match_action() returns trigger
language plpgsql security definer set search_path='' as $$ begin
  insert into public.match_action_feed(action_id,match_id,sequence_number,actor_user_id,action_type,
    payload_public,state_version_before,state_version_after,created_at)
  values(new.id,new.match_id,new.sequence_number,new.actor_user_id,new.action_type,new.payload_public,
    new.state_version_before,new.state_version_after,new.created_at)
  on conflict(action_id) do update set payload_public=excluded.payload_public,state_version_after=excluded.state_version_after;
  return new;
end $$;
drop trigger if exists match_actions_publish_safe_feed on public.match_actions;
create trigger match_actions_publish_safe_feed after insert or update of payload_public,state_version_after
on public.match_actions for each row execute function game_private.publish_match_action();

insert into public.match_action_feed(action_id,match_id,sequence_number,actor_user_id,action_type,
  payload_public,state_version_before,state_version_after,created_at)
select id,match_id,sequence_number,actor_user_id,action_type,payload_public,state_version_before,state_version_after,created_at
from public.match_actions on conflict(action_id) do nothing;

create or replace view public.visible_match_card_modifiers with(security_barrier=true) as
select m.id,c.match_id,m.match_card_id,m.modifier_type,m.power_delta,m.max_life_delta,m.current_life_delta,
  m.multiplier,m.starts_on_turn,m.expires_on_turn,m.is_permanent,m.metadata
from public.match_card_modifiers m join public.match_cards c on c.id=m.match_card_id
where game_private.is_match_participant(c.match_id,auth.uid()) and
  (c.owner_user_id=auth.uid() or c.is_face_up or c.zone in('life','attacker','leader','graveyard','banished'));
grant select on public.match_action_feed,public.visible_match_card_modifiers to authenticated;

do $$ begin
 if exists(select 1 from pg_publication where pubname='supabase_realtime') and not exists(
   select 1 from pg_publication_tables where pubname='supabase_realtime' and schemaname='public' and tablename='match_action_feed'
 ) then alter publication supabase_realtime add table public.match_action_feed; end if;
end $$;
alter table public.match_action_feed replica identity full;
notify pgrst,'reload schema';
