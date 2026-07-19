-- Engine V5.0: o relógio e o quadro pós-impacto são definidos pelo servidor.
begin;

update public.game_rule_versions
set reaction_window_seconds = 30
where version_name = 'ofieri-1.0';

create or replace function game_private.enforce_reaction_deadline_v5()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  new.reaction_deadline := clock_timestamp() +
    case
      when exists (
        select 1 from public.training_matches tm where tm.match_id = new.match_id
      ) then interval '45 seconds'
      else interval '30 seconds'
    end;
  return new;
end;
$$;

drop trigger if exists pending_attacks_reaction_deadline_v5 on public.pending_attacks;
create trigger pending_attacks_reaction_deadline_v5
before insert on public.pending_attacks
for each row execute function game_private.enforce_reaction_deadline_v5();

create or replace function game_private.capture_resolved_board_v5()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_board jsonb;
begin
  if new.status = 'resolved' and old.status is distinct from 'resolved' then
    select coalesce(jsonb_agg(
      jsonb_build_object(
        'id', mc.id,
        'owner_user_id', mc.owner_user_id,
        'controller_user_id', mc.controller_user_id,
        'zone', mc.zone,
        'zone_position', mc.zone_position,
        'is_face_up', mc.is_face_up,
        'is_destroyed', mc.is_destroyed,
        'current_power', case when mc.is_face_up or mc.zone in ('attacker','life','graveyard','banished') then mc.current_power else null end,
        'maximum_power', case when mc.is_face_up or mc.zone in ('attacker','life','graveyard','banished') then mc.maximum_power else null end,
        'current_life', case when mc.is_face_up or mc.zone in ('attacker','life','graveyard','banished') then mc.current_life else null end,
        'maximum_life', case when mc.is_face_up or mc.zone in ('attacker','life','graveyard','banished') then mc.maximum_life else null end
      ) order by mc.controller_user_id, mc.zone, mc.zone_position nulls last, mc.id
    ), '[]'::jsonb)
    into v_board
    from public.match_cards mc
    where mc.match_id = new.match_id
      and mc.zone in ('attacker','reinforcement','life','graveyard','banished');

    new.result := coalesce(new.result, '{}'::jsonb) || jsonb_build_object(
      'board_after', v_board,
      'board_after_state_version', new.resolved_state_version,
      'board_after_captured_at', clock_timestamp()
    );
  end if;
  return new;
end;
$$;

drop trigger if exists pending_attacks_capture_resolved_board_v5 on public.pending_attacks;
create trigger pending_attacks_capture_resolved_board_v5
before update of status on public.pending_attacks
for each row execute function game_private.capture_resolved_board_v5();

notify pgrst, 'reload schema';
commit;
