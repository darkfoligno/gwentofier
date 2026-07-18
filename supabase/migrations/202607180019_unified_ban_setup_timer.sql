-- Fluxo compartilhado por treino e PvP: maior raridade -> setup com 7 cartas -> turno cronometrado.
alter table public.match_bans drop constraint if exists match_bans_category_check;
alter table public.match_bans add constraint match_bans_category_check check(
  ban_category in('rare','epic','legendary','collab','leader','legendary_golden','highest_rarity')
);
alter table public.matches add column if not exists turn_deadline timestamptz;

create or replace function game_private.require_standard_match_ban() returns trigger language plpgsql set search_path='' as $$
begin
  if new.match_type in('friendly','ranked') then new.requires_bans:=true; end if;
  return new;
end $$;
drop trigger if exists matches_require_standard_ban on public.matches;
create trigger matches_require_standard_ban before insert or update of requires_bans on public.matches
for each row execute function game_private.require_standard_match_ban();

create or replace function game_private.set_turn_deadline() returns trigger language plpgsql set search_path='' as $$
begin
  if new.status='in_progress' and (tg_op='INSERT' or old.status is distinct from new.status or old.active_player_id is distinct from new.active_player_id) then
    new.turn_deadline:=clock_timestamp()+interval '3 minutes';
  elsif new.status<>'in_progress' then new.turn_deadline:=null; end if;
  return new;
end $$;
drop trigger if exists matches_set_turn_deadline on public.matches;
create trigger matches_set_turn_deadline before insert or update of status,active_player_id on public.matches
for each row execute function game_private.set_turn_deadline();

create or replace view public.visible_match_card_effects with(security_barrier=true) as
select mc.id match_card_id,mc.match_id,
 case when mc.owner_user_id=auth.uid() or mc.is_face_up or mc.zone in('life','attacker','leader','graveyard','banished') then mdc.element end element,
 case when mc.owner_user_id=auth.uid() or mc.is_face_up or mc.zone in('life','attacker','leader','graveyard','banished') then mdc.effect_mana_cost end effect_mana_cost,
 case when mc.owner_user_id=auth.uid() or mc.is_face_up or mc.zone in('life','attacker','leader','graveyard','banished') then c.effect_text end effect_text,
 case when mc.owner_user_id=auth.uid() or mc.is_face_up or mc.zone in('life','attacker','leader','graveyard','banished') then mdc.effect_definition end effect_definition
from public.match_cards mc join public.match_deck_cards mdc on mdc.id=mc.match_deck_card_id
join public.cards c on c.id=mc.source_card_id
where game_private.is_match_participant(mc.match_id,auth.uid());
grant select on public.visible_match_card_effects to authenticated;

create or replace function public.get_match_ban_candidates(p_match_id uuid) returns jsonb
language plpgsql security definer set search_path='' as $$
declare actor uuid:=game_private.require_authenticated(); opponent uuid; answer jsonb;
begin
  if not game_private.is_match_participant(p_match_id,actor) then raise exception 'NOT_A_MATCH_PLAYER'; end if;
  select user_id into opponent from public.match_players where match_id=p_match_id and user_id<>actor order by player_number limit 1;
  select coalesce(jsonb_agg(jsonb_build_object('card_id',q.source_card_id,'name',q.card_name,
    'image_url',q.image_url,'rarity',q.rarity,'is_golden',q.is_golden,'copy_count',q.copy_count)
    order by q.card_name),'[]'::jsonb) into answer
  from(
    select d.source_card_id,max(d.card_name)card_name,max(d.image_url)image_url,max(d.rarity)rarity,
      bool_or(d.is_golden)is_golden,count(*)::integer copy_count
    from public.match_decks md join public.match_deck_cards d on d.match_deck_id=md.id
    where md.match_id=p_match_id and md.user_id=opponent
      and case d.rarity when 'legendary' then 4 when 'epic' then 3 when 'rare' then 2 else 1 end =
        (select max(case x.rarity when 'legendary' then 4 when 'epic' then 3 when 'rare' then 2 else 1 end)
         from public.match_decks md2 join public.match_deck_cards x on x.match_deck_id=md2.id
         where md2.match_id=p_match_id and md2.user_id=opponent)
    group by d.source_card_id
  )q;
  return answer;
end $$;

create or replace function public.submit_match_ban(p_match_id uuid,p_source_card_id uuid,
  p_ban_category text default 'highest_rarity',p_expected_version bigint default 0) returns jsonb
language plpgsql security definer set search_path='' as $$
declare actor uuid:=game_private.require_authenticated(); opponent uuid; m public.matches; max_rank integer;
  chosen_rank integer; complete boolean; version bigint; bot uuid; bot_pick uuid;
begin
  m:=game_private.lock_match_for_action(p_match_id,p_expected_version,array['ban_phase']);
  if p_ban_category<>'highest_rarity' then raise exception 'ONLY_HIGHEST_RARITY_BAN_IS_ALLOWED'; end if;
  if exists(select 1 from public.match_bans where match_id=p_match_id and banned_by_user_id=actor) then raise exception 'BAN_ALREADY_SUBMITTED'; end if;
  select user_id into opponent from public.match_players where match_id=p_match_id and user_id<>actor order by player_number limit 1;
  select max(case d.rarity when 'legendary' then 4 when 'epic' then 3 when 'rare' then 2 else 1 end) into max_rank
  from public.match_decks md join public.match_deck_cards d on d.match_deck_id=md.id where md.match_id=p_match_id and md.user_id=opponent;
  select case d.rarity when 'legendary' then 4 when 'epic' then 3 when 'rare' then 2 else 1 end into chosen_rank
  from public.match_decks md join public.match_deck_cards d on d.match_deck_id=md.id
  where md.match_id=p_match_id and md.user_id=opponent and d.source_card_id=p_source_card_id limit 1;
  if chosen_rank is null or chosen_rank<>max_rank then raise exception 'CARD_IS_NOT_FROM_HIGHEST_AVAILABLE_RARITY'; end if;
  insert into public.match_bans(match_id,banned_by_user_id,target_user_id,source_card_id,ban_category,is_skipped)
  values(p_match_id,actor,opponent,p_source_card_id,'highest_rarity',false);
  update public.match_cards set zone='banished',zone_position=null,is_face_up=true
  where match_id=p_match_id and owner_user_id=opponent and source_card_id=p_source_card_id and zone='deck';
  version:=game_private.record_match_action(p_match_id,actor,'card_banned',jsonb_build_object(
    'target_user_id',opponent,'source_card_id',p_source_card_id,'category','highest_rarity'),'{ }',p_expected_version);

  select tm.bot_user_id into bot from public.training_matches tm where tm.match_id=p_match_id and tm.human_user_id=actor;
  if bot is not null and not exists(select 1 from public.match_bans where match_id=p_match_id and banned_by_user_id=bot) then
    select d.source_card_id into bot_pick from public.match_decks md join public.match_deck_cards d on d.match_deck_id=md.id
    where md.match_id=p_match_id and md.user_id=actor and
      case d.rarity when 'legendary' then 4 when 'epic' then 3 when 'rare' then 2 else 1 end=
      (select max(case x.rarity when 'legendary' then 4 when 'epic' then 3 when 'rare' then 2 else 1 end)
       from public.match_decks md2 join public.match_deck_cards x on x.match_deck_id=md2.id where md2.match_id=p_match_id and md2.user_id=actor)
    order by random() limit 1;
    insert into public.match_bans(match_id,banned_by_user_id,target_user_id,source_card_id,ban_category,is_skipped)
    values(p_match_id,bot,actor,bot_pick,'highest_rarity',false);
    update public.match_cards set zone='banished',zone_position=null,is_face_up=true
    where match_id=p_match_id and owner_user_id=actor and source_card_id=bot_pick and zone='deck';
  end if;
  select count(*)=2 into complete from public.match_bans where match_id=p_match_id;
  if complete then perform game_private.deal_initial_hands(p_match_id); end if;
  return jsonb_build_object('ban_phase_complete',complete,'state_version',version,'bot_banned_card_id',bot_pick);
end $$;

-- Substitui a versão de atalho da migração 017: agora começa obrigatoriamente no banimento.
create or replace function public.create_training_match(p_deck_size integer default 40) returns jsonb
language plpgsql security definer set search_path='' as $$
declare human uuid:=game_private.require_authenticated(); bot constant uuid:='00000000-0000-4000-8000-000000000071'; mid uuid; rule_id uuid;
begin
  if p_deck_size<>40 then raise exception 'TRAINING_DECK_SIZE_MUST_BE_40'; end if;
  select id into rule_id from public.game_rule_versions where is_active order by created_at desc limit 1;
  if rule_id is null then raise exception 'ACTIVE_GAME_RULE_VERSION_REQUIRED'; end if;
  insert into public.matches(rule_version_id,match_type,status,created_by,requires_bans,is_private,started_at,expires_at,current_turn)
  values(rule_id,'friendly','ban_phase',human,true,true,now(),now()+interval '8 hours',0) returning id into mid;
  insert into public.match_players(match_id,user_id,player_number) values(mid,human,1),(mid,bot,2);
  perform game_private.snapshot_random_training_deck(mid,human,40);
  perform game_private.snapshot_random_training_deck(mid,bot,40);
  insert into public.match_public_states(match_id,player1_user_id,player2_user_id,player1_username,player2_username,player1_avatar_url,player2_avatar_url)
  select mid,human,bot,p1.username,p2.username,p1.avatar_url,p2.avatar_url from public.profiles p1 cross join public.profiles p2 where p1.id=human and p2.id=bot;
  insert into public.training_matches(match_id,human_user_id,bot_user_id) values(mid,human,bot);
  perform game_private.recalculate_match_public_state(mid);
  return jsonb_build_object('match_id',mid,'bot_user_id',bot,'deck_size',40,'status','ban_phase');
end $$;

create or replace function public.submit_training_setup(p_match_id uuid,p_life_card_ids uuid[],p_expected_version bigint)
returns jsonb language plpgsql security definer set search_path='' as $$
declare human uuid:=game_private.require_authenticated(); bot uuid; m public.matches; bot_life uuid[]; version bigint; active uuid;
begin
  select bot_user_id into bot from public.training_matches where match_id=p_match_id and human_user_id=human;
  if bot is null then raise exception 'NOT_YOUR_TRAINING_MATCH'; end if;
  m:=game_private.lock_match_for_action(p_match_id,p_expected_version,array['setup']);
  if cardinality(p_life_card_ids)<>3 or (select count(distinct x) from unnest(p_life_card_ids)x)<>3 then raise exception 'EXACTLY_THREE_DISTINCT_LIFE_CARDS_REQUIRED'; end if;
  if exists(select 1 from unnest(p_life_card_ids)x where not exists(select 1 from public.match_cards where id=x and match_id=p_match_id and owner_user_id=human and zone='hand')) then raise exception 'SETUP_CARD_NOT_IN_HAND'; end if;
  update public.match_cards mc set zone='life',zone_position=x.ord,is_face_up=true,entered_zone_turn=0 from unnest(p_life_card_ids)with ordinality x(id,ord) where mc.id=x.id;
  select array_agg(id order by zone_position) into bot_life from(select id,zone_position from public.match_cards where match_id=p_match_id and owner_user_id=bot and zone='hand' order by random() limit 3)q;
  update public.match_cards mc set zone='life',zone_position=x.ord,is_face_up=true,entered_zone_turn=0 from unnest(bot_life)with ordinality x(id,ord) where mc.id=x.id;
  update public.match_players set setup_finished=true,mana_snapshot=4,mana_available=4 where match_id=p_match_id;
  active:=human;
  update public.matches set status='in_progress',current_turn=1,active_player_id=active where id=p_match_id;
  version:=game_private.record_match_action(p_match_id,human,'setup_submitted',jsonb_build_object('setup_complete',true,'active_player_id',active),jsonb_build_object('life_card_ids',p_life_card_ids),p_expected_version);
  return jsonb_build_object('match_started',true,'active_player_id',active,'state_version',version);
end $$;

create or replace function public.expire_match_turn(p_match_id uuid,p_expected_version bigint) returns jsonb
language plpgsql security definer set search_path='' as $$
declare requester uuid:=game_private.require_authenticated(); m public.matches;
begin
  if not game_private.is_match_participant(p_match_id,requester) then raise exception 'NOT_A_MATCH_PLAYER'; end if;
  select * into m from public.matches where id=p_match_id for update;
  if m.state_version<>p_expected_version then raise exception 'STALE_MATCH_VERSION'; end if;
  if m.turn_deadline is null or clock_timestamp()<m.turn_deadline then raise exception 'TURN_DEADLINE_NOT_REACHED'; end if;
  return game_private.change_active_turn(p_match_id,m.active_player_id,false,p_expected_version);
end $$;
revoke all on function public.submit_training_setup(uuid,uuid[],bigint) from public,anon;
revoke all on function public.expire_match_turn(uuid,bigint) from public,anon;
grant execute on function public.submit_training_setup(uuid,uuid[],bigint) to authenticated;
grant execute on function public.expire_match_turn(uuid,bigint) to authenticated;
notify pgrst,'reload schema';
