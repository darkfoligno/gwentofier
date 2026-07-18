-- Iniciativa do treino e conclusão atômica do ataque/turno após a reação.
create or replace function public.submit_training_setup(p_match_id uuid,p_life_card_ids uuid[],p_expected_version bigint)
returns jsonb language plpgsql security definer set search_path='' as $$
declare human uuid:=game_private.require_authenticated(); bot uuid; m public.matches; bot_life uuid[];
  version bigint; active uuid; human_roll integer; bot_roll integer;
begin
  select bot_user_id into bot from public.training_matches where match_id=p_match_id and human_user_id=human;
  if bot is null then raise exception 'NOT_YOUR_TRAINING_MATCH'; end if;
  m:=game_private.lock_match_for_action(p_match_id,p_expected_version,array['setup']);
  if cardinality(p_life_card_ids)<>3 or (select count(distinct x) from unnest(p_life_card_ids)x)<>3 then raise exception 'EXACTLY_THREE_DISTINCT_LIFE_CARDS_REQUIRED'; end if;
  if exists(select 1 from unnest(p_life_card_ids)x where not exists(select 1 from public.match_cards where id=x and match_id=p_match_id and owner_user_id=human and zone='hand')) then raise exception 'SETUP_CARD_NOT_IN_HAND'; end if;
  update public.match_cards mc set zone='life',zone_position=x.ord,is_face_up=true,entered_zone_turn=0 from unnest(p_life_card_ids)with ordinality x(id,ord) where mc.id=x.id;
  select array_agg(id order by zone_position) into bot_life from(select id,zone_position from public.match_cards where match_id=p_match_id and owner_user_id=bot and zone='hand' order by random() limit 3)q;
  update public.match_cards mc set zone='life',zone_position=x.ord,is_face_up=true,entered_zone_turn=0 from unnest(bot_life)with ordinality x(id,ord) where mc.id=x.id;
  loop human_roll:=floor(random()*20+1)::integer; bot_roll:=floor(random()*20+1)::integer; exit when human_roll<>bot_roll; end loop;
  active:=case when human_roll>bot_roll then human else bot end;
  update public.match_players set setup_finished=true,mana_snapshot=4,mana_available=4 where match_id=p_match_id;
  update public.matches set status='in_progress',current_turn=1,active_player_id=active,
    initiative_result=jsonb_build_object('mode','d20','player1',human_roll,'player2',bot_roll,'winner_user_id',active) where id=p_match_id;
  version:=game_private.record_match_action(p_match_id,human,'setup_submitted',jsonb_build_object(
    'setup_complete',true,'active_player_id',active,'initiative',jsonb_build_object('mode','d20','player1',human_roll,'player2',bot_roll)),
    jsonb_build_object('life_card_ids',p_life_card_ids),p_expected_version);
  return jsonb_build_object('match_started',true,'active_player_id',active,'state_version',version,
    'initiative',jsonb_build_object('mode','d20','player1',human_roll,'player2',bot_roll,'winner_user_id',active));
end $$;

create or replace function public.finalize_pending_attack_turn(p_pending_attack_id uuid,p_expected_version bigint)
returns jsonb language plpgsql security definer set search_path='' as $$
declare actor uuid:=game_private.require_authenticated(); pa public.pending_attacks; resolved jsonb; version bigint; turn_result jsonb;
begin
  select * into pa from public.pending_attacks where id=p_pending_attack_id for update;
  if not found then raise exception 'PENDING_ATTACK_NOT_FOUND'; end if;
  if actor not in(pa.attacker_user_id,pa.defender_user_id) then raise exception 'NOT_A_MATCH_PLAYER'; end if;
  resolved:=game_private.resolve_pending_attack_internal(p_pending_attack_id,actor,p_expected_version);
  version:=(resolved->>'state_version')::bigint;
  if not coalesce((resolved->>'match_finished')::boolean,false) then
    turn_result:=game_private.change_active_turn(pa.match_id,pa.attacker_user_id,false,version);
  end if;
  return resolved||jsonb_build_object('turn',turn_result);
end $$;

create or replace function public.auto_resolve_training_attack(p_match_id uuid,p_expected_version bigint)
returns jsonb language plpgsql security definer set search_path='' as $$
declare human uuid:=game_private.require_authenticated(); bot uuid; pa public.pending_attacks; version bigint; resolved jsonb; turn_result jsonb;
begin
  select bot_user_id into bot from public.training_matches where match_id=p_match_id and human_user_id=human;
  if bot is null then raise exception 'NOT_YOUR_TRAINING_MATCH'; end if;
  select * into pa from public.pending_attacks where match_id=p_match_id and attacker_user_id=human and defender_user_id=bot and status='awaiting_reaction' order by created_at desc limit 1 for update;
  if not found then raise exception 'TRAINING_PENDING_ATTACK_NOT_FOUND'; end if;
  update public.pending_attacks set status='reaction_declined',reaction_completed_at=now() where id=pa.id;
  version:=game_private.record_match_action(p_match_id,bot,'reaction_declined',jsonb_build_object('pending_attack_id',pa.id,'training_bot',true),'{}',p_expected_version);
  resolved:=game_private.resolve_pending_attack_internal(pa.id,bot,version);
  version:=(resolved->>'state_version')::bigint;
  if not coalesce((resolved->>'match_finished')::boolean,false) then turn_result:=game_private.change_active_turn(p_match_id,human,false,version); end if;
  return resolved||jsonb_build_object('turn',turn_result);
end $$;
revoke all on function public.finalize_pending_attack_turn(uuid,bigint) from public,anon;
revoke all on function public.auto_resolve_training_attack(uuid,bigint) from public,anon;
grant execute on function public.finalize_pending_attack_turn(uuid,bigint) to authenticated;
grant execute on function public.auto_resolve_training_attack(uuid,bigint) to authenticated;
notify pgrst,'reload schema';
