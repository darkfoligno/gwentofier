-- Keep "end turn" distinct from "pass turn": ending requires at least one action.
create or replace function public.end_turn(p_match_id uuid, p_expected_version bigint) returns jsonb
language plpgsql security definer set search_path='' as $$
declare v_user_id uuid := game_private.require_authenticated(); v_actions integer;
begin
  select actions_this_turn into v_actions from public.match_players where match_id=p_match_id and user_id=v_user_id;
  if coalesce(v_actions,0)=0 then raise exception 'ACTION_REQUIRED_BEFORE_END_TURN'; end if;
  return game_private.change_active_turn(p_match_id,v_user_id,false,p_expected_version);
end $$;
revoke all on function public.end_turn(uuid,bigint) from public,anon;
grant execute on function public.end_turn(uuid,bigint) to authenticated;
