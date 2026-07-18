create or replace view public.visible_match_card_effects with(security_barrier=true) as
select mc.id match_card_id,mc.match_id,
 case when mc.owner_user_id=auth.uid() or mc.is_face_up or mc.zone in('life','attacker','leader','graveyard','banished') then mdc.element end element,
 case when mc.owner_user_id=auth.uid() or mc.is_face_up or mc.zone in('life','attacker','leader','graveyard','banished') then mdc.effect_mana_cost end effect_mana_cost,
 case when mc.owner_user_id=auth.uid() or mc.is_face_up or mc.zone in('life','attacker','leader','graveyard','banished') then mdc.effect_definition end effect_definition
from public.match_cards mc join public.match_deck_cards mdc on mdc.id=mc.match_deck_card_id
where exists(select 1 from public.match_players mp where mp.match_id=mc.match_id and mp.user_id=auth.uid());
grant select on public.visible_match_card_effects to authenticated;
grant execute on function public.activate_card_effect_v2(uuid,uuid,integer,uuid,bigint) to authenticated;
grant execute on function public.get_my_pending_effect_choice(uuid) to authenticated;

do $$ begin
 if exists(select 1 from pg_publication where pubname='supabase_realtime') and not exists(select 1 from pg_publication_tables where pubname='supabase_realtime' and schemaname='public' and tablename='pending_effect_choices') then alter publication supabase_realtime add table public.pending_effect_choices; end if;
end $$;
alter table public.pending_effect_choices replica identity full;

create or replace function public.cleanup_expired_effect_choices() returns integer language plpgsql security definer set search_path='' as $$ declare n integer; begin
 update public.pending_effect_choices set status='expired' where status='pending' and expires_at<=now(); get diagnostics n=row_count; return n;
end $$;
revoke all on function public.cleanup_expired_effect_choices() from public,anon,authenticated;
