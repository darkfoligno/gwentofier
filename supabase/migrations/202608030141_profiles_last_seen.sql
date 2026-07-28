ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS last_seen timestamptz DEFAULT now();

create or replace function public.get_my_social_connections() returns jsonb language sql stable security definer set search_path = public, pg_temp as $$
  select coalesce(jsonb_agg(row_data order by row_data->>'username'),'[]'::jsonb) from (
    select jsonb_build_object('user_id',p.id,'username',p.username,'avatar_url',p.avatar_url,'status','accepted','direction','friend','last_seen',p.last_seen) row_data from public.friendships f join public.profiles p on p.id=f.friend_user_id where f.user_id=auth.uid()
    union all
    select jsonb_build_object('request_id',r.id,'user_id',p.id,'username',p.username,'avatar_url',p.avatar_url,'status',r.status,'direction',case when r.recipient_user_id=auth.uid() then 'received' else 'sent' end,'last_seen',p.last_seen) from public.friend_requests r join public.profiles p on p.id=case when r.recipient_user_id=auth.uid() then r.sender_user_id else r.recipient_user_id end where auth.uid() in (r.sender_user_id,r.recipient_user_id) and r.status='pending'
  ) s
$$;

create or replace function public.update_last_seen() returns void language sql security definer as $$
  update public.profiles set last_seen = now() where id = auth.uid();
$$;
grant execute on function public.update_last_seen() to authenticated;
