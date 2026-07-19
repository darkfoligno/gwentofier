-- V4.0: Regra 8 inviolável e payload público fiel à compra real.
begin;

create or replace function public.end_turn(p_match_id uuid,p_expected_version bigint)
returns jsonb language plpgsql security definer set search_path='' as $$
declare actor uuid:=game_private.require_authenticated();attackers uuid[];
begin
 select array_agg(id order by zone_position)into attackers from public.match_cards
 where match_id=p_match_id and controller_user_id=actor and zone='attacker' and current_life>0 and can_attack and not has_attacked_this_turn;
 if coalesce(cardinality(attackers),0)>0 then
  return public.declare_attack(p_match_id,attackers,false,p_expected_version)||jsonb_build_object('automatic_attack',true);
 end if;
 return game_private.change_active_turn(p_match_id,actor,false,p_expected_version);
end $$;

create or replace function public.rescue_training_bot_turn(p_match_id uuid,p_expected_version bigint)
returns jsonb language plpgsql security definer set search_path='' as $$
declare human uuid:=game_private.require_authenticated();bot uuid;m public.matches;
begin
 select bot_user_id into bot from public.training_matches where match_id=p_match_id and human_user_id=human;if bot is null then raise exception 'NOT_YOUR_TRAINING_MATCH';end if;
 select * into m from public.matches where id=p_match_id for update;if not found then raise exception 'MATCH_NOT_FOUND';end if;if m.state_version<>p_expected_version then raise exception 'STALE_MATCH_VERSION';end if;if m.status<>'in_progress' then raise exception 'INVALID_MATCH_STATUS';end if;
 if m.active_player_id<>bot then return jsonb_build_object('rescued',false,'reason','BOT_TURN_ALREADY_FINISHED','state_version',m.state_version);end if;
 return public.run_training_bot_turn(p_match_id,p_expected_version)||jsonb_build_object('rescued',true);
end $$;

create or replace function game_private.correct_public_turn_draw_payload()returns trigger
language plpgsql security definer set search_path='' as $$
begin
 if new.action_type='turn_ended' and coalesce((new.payload_public->>'new_turn')::integer,0)=2 then
  new.payload_public:=new.payload_public||jsonb_build_object('next_player_drew_card',false,'opening_second_player_without_draw',true);
 end if;
 return new;
end $$;
drop trigger if exists match_actions_correct_turn_draw_payload on public.match_actions;
create trigger match_actions_correct_turn_draw_payload before insert on public.match_actions for each row execute function game_private.correct_public_turn_draw_payload();

revoke all on function public.end_turn(uuid,bigint),public.rescue_training_bot_turn(uuid,bigint) from public,anon;
grant execute on function public.end_turn(uuid,bigint),public.rescue_training_bot_turn(uuid,bigint) to authenticated;
notify pgrst,'reload schema';
commit;
