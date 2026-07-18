-- Turno básico e autoritativo do bot de treino. O cliente apenas solicita a
-- execução; seleção, dano, versionamento, compra e troca de turno ocorrem no banco.
create or replace function public.run_training_bot_turn(p_match_id uuid,p_expected_version bigint)
returns jsonb language plpgsql security definer set search_path='' as $$
declare human uuid:=game_private.require_authenticated(); bot uuid; m public.matches;
  played uuid; attacker uuid; target uuid; slot_no integer; power integer; version bigint; damage jsonb:='{}'; turn_result jsonb;
begin
  select tm.bot_user_id into bot from public.training_matches tm
  where tm.match_id=p_match_id and tm.human_user_id=human;
  if bot is null then raise exception 'NOT_YOUR_TRAINING_MATCH'; end if;
  select * into m from public.matches where id=p_match_id for update;
  if not found then raise exception 'MATCH_NOT_FOUND'; end if;
  if m.state_version<>p_expected_version then raise exception 'STALE_MATCH_VERSION'; end if;
  if m.status<>'in_progress' then raise exception 'INVALID_MATCH_STATUS'; end if;
  if m.active_player_id<>bot then raise exception 'BOT_IS_NOT_ACTIVE_PLAYER'; end if;

  select s into slot_no from generate_series(1,4)s
  where not exists(select 1 from public.match_cards where match_id=p_match_id and controller_user_id=bot and zone='attacker' and zone_position=s)
  order by s limit 1;
  if slot_no is not null then
    select mc.id into played from public.match_cards mc
    where mc.match_id=p_match_id and mc.owner_user_id=bot and mc.zone='hand'
    order by random() limit 1 for update;
  end if;
  version:=p_expected_version;
  if played is not null then
    update public.match_cards set zone='attacker',zone_position=slot_no,is_face_up=true,
      entered_zone_turn=m.current_turn where id=played;
    update public.match_players set actions_this_turn=actions_this_turn+1 where match_id=p_match_id and user_id=bot;
    version:=game_private.record_match_action(p_match_id,bot,'card_played',
      jsonb_build_object('match_card_id',played,'destination_zone','attacker','destination_position',slot_no,'training_bot',true),
      '{}'::jsonb,version);
  end if;

  select id,current_power into attacker,power from public.match_cards
  where match_id=p_match_id and controller_user_id=bot and zone='attacker' and current_life>0
    and can_attack and not has_attacked_this_turn order by random() limit 1 for update;
  select id into target from public.match_cards where match_id=p_match_id and controller_user_id=human
    and zone='life' and current_life>0 order by random() limit 1 for update;
  if attacker is not null and target is not null then
    damage:=game_private.apply_damage_internal(p_match_id,target,greatest(power,0),m.current_turn);
    update public.match_cards set has_attacked_this_turn=true where id=attacker;
    update public.match_players set actions_this_turn=actions_this_turn+1 where match_id=p_match_id and user_id=bot;
    version:=game_private.record_match_action(p_match_id,bot,'attack_resolved',
      jsonb_build_object('attacker_card_id',attacker,'target_card_id',target,'training_bot',true,'damage',damage),
      '{}'::jsonb,version);
  end if;

  turn_result:=game_private.change_active_turn(p_match_id,bot,false,version);
  return jsonb_build_object('played_card_id',played,'attacker_card_id',attacker,
    'target_card_id',target,'damage',damage,'turn',turn_result);
end $$;
revoke all on function public.run_training_bot_turn(uuid,bigint) from public,anon;
grant execute on function public.run_training_bot_turn(uuid,bigint) to authenticated;
notify pgrst,'reload schema';
