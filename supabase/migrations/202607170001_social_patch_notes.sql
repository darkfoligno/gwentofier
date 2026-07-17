-- Social lobby and owner-managed weekly patch notes.
-- Apply through the normal Supabase migration workflow; the client never writes these tables directly.

create table if not exists public.friend_requests (
  id uuid primary key default gen_random_uuid(),
  sender_user_id uuid not null references public.profiles(id) on delete cascade,
  recipient_user_id uuid not null references public.profiles(id) on delete cascade,
  status text not null default 'pending' check (status in ('pending','accepted','declined','cancelled')),
  created_at timestamptz not null default now(),
  responded_at timestamptz,
  check (sender_user_id <> recipient_user_id)
);
create unique index if not exists friend_requests_one_pending_idx on public.friend_requests(sender_user_id, recipient_user_id) where status = 'pending';

create table if not exists public.friendships (
  user_id uuid not null references public.profiles(id) on delete cascade,
  friend_user_id uuid not null references public.profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (user_id, friend_user_id),
  check (user_id <> friend_user_id)
);

create table if not exists public.patch_notes (
  id uuid primary key default gen_random_uuid(),
  version text not null check (char_length(version) between 1 and 40),
  title text not null check (char_length(title) between 3 and 120),
  body text not null check (char_length(body) between 3 and 20000),
  is_published boolean not null default true,
  published_at timestamptz not null default now(),
  created_by uuid not null references public.profiles(id),
  created_at timestamptz not null default now()
);

alter table public.friend_requests enable row level security;
alter table public.friendships enable row level security;
alter table public.patch_notes enable row level security;
drop policy if exists friend_requests_participant_read on public.friend_requests;
create policy friend_requests_participant_read on public.friend_requests for select to authenticated using (auth.uid() in (sender_user_id, recipient_user_id));
drop policy if exists friendships_own_read on public.friendships;
create policy friendships_own_read on public.friendships for select to authenticated using (auth.uid() = user_id);
drop policy if exists patch_notes_published_read on public.patch_notes;
create policy patch_notes_published_read on public.patch_notes for select to authenticated using (is_published);

create or replace function public.send_friend_request(p_username text) returns uuid language plpgsql security definer set search_path = public, pg_temp as $$
declare v_me uuid := auth.uid(); v_to uuid; v_id uuid;
begin
  if v_me is null then raise exception 'authentication required' using errcode='28000'; end if;
  select id into v_to from public.profiles where lower(username)=lower(trim(p_username));
  if v_to is null then raise exception 'Jogador não encontrado.'; end if;
  if v_to=v_me then raise exception 'Você não pode convidar a si mesmo.'; end if;
  if exists(select 1 from public.friendships where user_id=v_me and friend_user_id=v_to) then raise exception 'Este jogador já está em seus contatos.'; end if;
  if exists(select 1 from public.friend_requests where sender_user_id=v_to and recipient_user_id=v_me and status='pending') then raise exception 'Este jogador já enviou um convite a você.'; end if;
  insert into public.friend_requests(sender_user_id,recipient_user_id) values(v_me,v_to) returning id into v_id;
  return v_id;
end $$;

create or replace function public.respond_friend_request(p_request_id uuid, p_accept boolean) returns void language plpgsql security definer set search_path = public, pg_temp as $$
declare v_me uuid := auth.uid(); v_sender uuid;
begin
  update public.friend_requests set status=case when p_accept then 'accepted' else 'declined' end, responded_at=now()
  where id=p_request_id and recipient_user_id=v_me and status='pending' returning sender_user_id into v_sender;
  if v_sender is null then raise exception 'Convite pendente não encontrado.'; end if;
  if p_accept then insert into public.friendships(user_id,friend_user_id) values(v_me,v_sender),(v_sender,v_me) on conflict do nothing; end if;
end $$;

create or replace function public.get_my_social_connections() returns jsonb language sql stable security definer set search_path = public, pg_temp as $$
  select coalesce(jsonb_agg(row_data order by row_data->>'username'),'[]'::jsonb) from (
    select jsonb_build_object('user_id',p.id,'username',p.username,'avatar_url',p.avatar_url,'status','accepted','direction','friend') row_data from public.friendships f join public.profiles p on p.id=f.friend_user_id where f.user_id=auth.uid()
    union all
    select jsonb_build_object('request_id',r.id,'user_id',p.id,'username',p.username,'avatar_url',p.avatar_url,'status',r.status,'direction',case when r.recipient_user_id=auth.uid() then 'received' else 'sent' end) from public.friend_requests r join public.profiles p on p.id=case when r.recipient_user_id=auth.uid() then r.sender_user_id else r.recipient_user_id end where auth.uid() in (r.sender_user_id,r.recipient_user_id) and r.status='pending'
  ) s
$$;

create or replace function public.publish_patch_note(p_version text, p_title text, p_body text) returns uuid language plpgsql security definer set search_path = public, pg_temp as $$
declare v_me uuid := auth.uid(); v_id uuid;
begin
  if not exists(select 1 from public.user_roles where user_id=v_me and role in ('content_editor','game_master','admin')) then raise exception 'Somente o proprietário ou editor pode publicar atualizações.' using errcode='42501'; end if;
  insert into public.patch_notes(version,title,body,created_by) values(trim(p_version),trim(p_title),trim(p_body),v_me) returning id into v_id;
  return v_id;
end $$;

revoke all on public.friend_requests, public.friendships, public.patch_notes from anon;
grant select on public.friend_requests, public.friendships, public.patch_notes to authenticated;
grant execute on function public.send_friend_request(text), public.respond_friend_request(uuid,boolean), public.get_my_social_connections(), public.publish_patch_note(text,text,text) to authenticated;
