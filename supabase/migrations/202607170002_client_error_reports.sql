create table if not exists public.client_error_reports (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references public.profiles(id) on delete set null,
  match_id uuid references public.matches(id) on delete set null,
  area text not null check (char_length(area) between 1 and 80),
  operation text not null check (char_length(operation) between 1 and 120),
  error_code text,
  error_message text not null,
  error_details text,
  client_context jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  resolved_at timestamptz,
  resolved_by uuid references public.profiles(id) on delete set null
);
alter table public.client_error_reports enable row level security;
drop policy if exists client_error_reports_admin_read on public.client_error_reports;
create policy client_error_reports_admin_read on public.client_error_reports for select to authenticated using (exists(select 1 from public.user_roles where user_id=auth.uid() and role in ('game_master','admin')));

create or replace function public.report_client_error(p_area text, p_operation text, p_error_code text, p_error_message text, p_error_details text default null, p_match_id uuid default null, p_client_context jsonb default '{}'::jsonb) returns uuid language plpgsql security definer set search_path=public,pg_temp as $$
declare v_id uuid;
begin
  if auth.uid() is null then raise exception 'authentication required' using errcode='28000'; end if;
  insert into public.client_error_reports(user_id,match_id,area,operation,error_code,error_message,error_details,client_context)
  values(auth.uid(),p_match_id,left(p_area,80),left(p_operation,120),left(p_error_code,120),left(p_error_message,2000),left(p_error_details,4000),coalesce(p_client_context,'{}'::jsonb)) returning id into v_id;
  return v_id;
end $$;
revoke all on public.client_error_reports from anon,authenticated;
grant execute on function public.report_client_error(text,text,text,text,text,uuid,jsonb) to authenticated;
