-- Escolhas autoritativas exigidas por efeitos compostos. Nenhuma informação
-- privada é publicada em match_public_states ou visible_match_actions.
create table if not exists public.pending_effect_choices (
 id uuid primary key default gen_random_uuid(), match_id uuid not null references public.matches(id) on delete cascade,
 actor_user_id uuid not null references public.profiles(id), source_match_card_id uuid not null references public.match_cards(id) on delete cascade,
 effect_order integer not null, effect_code text not null, choice_type text not null check(choice_type in('field_card','hand_card','deck_card','graveyard_card','slot','confirm','opponent_choice')),
 min_choices integer not null default 1, max_choices integer not null default 1, candidate_ids uuid[] not null default '{}',
 public_prompt text not null, private_context jsonb not null default '{}', status text not null default 'pending' check(status in('pending','submitted','resolved','cancelled','expired')),
 expected_state_version bigint not null, expires_at timestamptz not null default(now()+interval '45 seconds'), created_at timestamptz not null default now(),
 check(min_choices>=0 and max_choices>=min_choices)
);
create unique index if not exists pending_effect_choice_one_idx on public.pending_effect_choices(match_id,actor_user_id) where status='pending';
alter table public.pending_effect_choices enable row level security;
drop policy if exists pending_effect_choices_actor_read on public.pending_effect_choices;
create policy pending_effect_choices_actor_read on public.pending_effect_choices for select to authenticated using(actor_user_id=auth.uid());

create or replace function public.get_my_pending_effect_choice(p_match_id uuid) returns table(id uuid,effect_code text,choice_type text,min_choices integer,max_choices integer,candidate_ids uuid[],public_prompt text,expires_at timestamptz,expected_state_version bigint)
language sql stable security definer set search_path='' as $$
 select c.id,c.effect_code,c.choice_type,c.min_choices,c.max_choices,c.candidate_ids,c.public_prompt,c.expires_at,c.expected_state_version
 from public.pending_effect_choices c where c.match_id=p_match_id and c.actor_user_id=auth.uid() and c.status='pending' and c.expires_at>now() order by c.created_at desc limit 1
$$;

create or replace function game_private.assert_effect_choice(p_choice_id uuid,p_selected_ids uuid[],p_expected_version bigint) returns public.pending_effect_choices
language plpgsql security definer set search_path='' as $$ declare v public.pending_effect_choices; begin
 select * into v from public.pending_effect_choices where id=p_choice_id and actor_user_id=auth.uid() and status='pending' for update;
 if not found then raise exception 'EFFECT_CHOICE_NOT_FOUND'; end if;
 if v.expires_at<=now() then update public.pending_effect_choices set status='expired' where id=v.id; raise exception 'EFFECT_CHOICE_EXPIRED'; end if;
 if v.expected_state_version<>p_expected_version then raise exception 'STALE_MATCH_VERSION'; end if;
 if cardinality(coalesce(p_selected_ids,'{}'))<v.min_choices or cardinality(coalesce(p_selected_ids,'{}'))>v.max_choices then raise exception 'INVALID_EFFECT_CHOICE_COUNT'; end if;
 if exists(select 1 from unnest(coalesce(p_selected_ids,'{}')) x where not x=any(v.candidate_ids)) then raise exception 'INVALID_EFFECT_CHOICE'; end if;
 return v;
end $$;

revoke all on public.pending_effect_choices from anon,authenticated;
grant execute on function public.get_my_pending_effect_choice(uuid) to authenticated;

create or replace function public.submit_effect_choice(p_choice_id uuid,p_selected_ids uuid[],p_expected_version bigint) returns jsonb language plpgsql security definer set search_path='' as $$
declare c public.pending_effect_choices; actor uuid:=game_private.require_authenticated(); selected uuid; new_version bigint; result jsonb:='{}'; begin
 c:=game_private.assert_effect_choice(p_choice_id,p_selected_ids,p_expected_version); selected:=p_selected_ids[1];
 if c.effect_code='common_vivaldi_mutual_tutor' then
  update public.match_cards set zone='hand',zone_position=null,is_face_up=false,metadata=jsonb_set(metadata,'{mana_cost_delta}',to_jsonb(coalesce((metadata->>'mana_cost_delta')::integer,0)+coalesce((c.private_context->>'cost_delta')::integer,2))) where id=selected and match_id=c.match_id and owner_user_id=actor and zone='deck';
  if not found then raise exception 'SELECTED_CARD_NO_LONGER_AVAILABLE'; end if;
  result:=jsonb_build_object('drawn_card_id',selected,'mana_cost_delta',2);
 else raise exception 'UNSUPPORTED_EFFECT_CHOICE: %',c.effect_code; end if;
 update public.pending_effect_choices set status='resolved' where id=c.id;
 new_version:=game_private.record_match_action(c.match_id,actor,'effect_choice_resolved',jsonb_build_object('choice_id',c.id,'effect_code',c.effect_code,'result',result),'{}',p_expected_version);
 return result||jsonb_build_object('state_version',new_version);
end $$;
revoke all on function public.submit_effect_choice(uuid,uuid[],bigint) from public,anon;
grant execute on function public.submit_effect_choice(uuid,uuid[],bigint) to authenticated;
