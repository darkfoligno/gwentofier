-- Corrige recursão de RLS e cria partidas de treino autoritativas com dois
-- snapshots de 40 cartas sorteadas do catálogo ativo (repetições permitidas).

create or replace function game_private.is_match_participant(p_match_id uuid, p_user_id uuid default auth.uid())
returns boolean language sql stable security definer set search_path='' as $$
  select exists(select 1 from public.match_players where match_id=p_match_id and user_id=p_user_id)
$$;
revoke all on function game_private.is_match_participant(uuid,uuid) from public,anon;
grant execute on function game_private.is_match_participant(uuid,uuid) to authenticated;

drop policy if exists matches_participant_or_waiting_read on public.matches;
create policy matches_participant_or_waiting_read on public.matches for select to authenticated using(
  public.is_admin() or (status='waiting' and not is_private) or game_private.is_match_participant(id,auth.uid())
);
drop policy if exists match_public_states_participant_read on public.match_public_states;
create policy match_public_states_participant_read on public.match_public_states for select to authenticated using(
  public.is_admin() or game_private.is_match_participant(match_id,auth.uid())
);
drop policy if exists match_players_participant_read on public.match_players;
create policy match_players_participant_read on public.match_players for select to authenticated using(
  public.is_admin() or game_private.is_match_participant(match_id,auth.uid())
);
drop policy if exists match_bans_participant_read on public.match_bans;
create policy match_bans_participant_read on public.match_bans for select to authenticated using(
  public.is_admin() or game_private.is_match_participant(match_id,auth.uid())
);

create table if not exists public.training_matches(
  match_id uuid primary key references public.matches(id) on delete cascade,
  human_user_id uuid not null references public.profiles(id) on delete cascade,
  bot_user_id uuid not null references public.profiles(id) on delete restrict,
  difficulty text not null default 'normal' check(difficulty in('random','normal')),
  created_at timestamptz not null default now()
);
alter table public.training_matches enable row level security;
drop policy if exists training_matches_owner_read on public.training_matches;
create policy training_matches_owner_read on public.training_matches for select to authenticated using(human_user_id=auth.uid());

-- Conta técnica sem login. Ela só existe para satisfazer a identidade referencial
-- do segundo participante; nenhuma sessão ou senha é exposta ao cliente.
do $$
declare bot constant uuid := '00000000-0000-4000-8000-000000000071';
begin
  if not exists(select 1 from auth.users where id=bot) then
    insert into auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,
      raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,email_change,
      email_change_token_new,recovery_token)
    values('00000000-0000-0000-0000-000000000000',bot,'authenticated','authenticated',
      'ofieri-training-bot@local.invalid','',now(),'{"provider":"email","providers":["email"],"is_bot":true}',
      '{"username":"Autômato de Ofier"}',now(),now(),'','','','');
  end if;
  insert into public.profiles(id,username) values(bot,'Autômato de Ofier')
  on conflict(id) do update set username=excluded.username;
end $$;

create or replace function game_private.snapshot_random_training_deck(
  p_match_id uuid,p_user_id uuid,p_size integer
) returns uuid language plpgsql security definer set search_path='' as $$
declare deck_id uuid;
begin
  if p_size<>40 then raise exception 'TRAINING_DECK_SIZE_MUST_BE_40'; end if;
  if not exists(select 1 from public.cards where is_active) then raise exception 'CARD_CATALOG_EMPTY'; end if;
  insert into public.match_decks(match_id,user_id,total_cards,golden_cards_count)
  values(p_match_id,p_user_id,p_size,0) returning id into deck_id;

  insert into public.match_deck_cards(match_deck_id,source_card_id,card_version,card_name,image_url,
    element,rarity,card_type,is_golden,base_power,base_max_life,effect_mana_cost,tier,
    leader_cooldown,effect_definition,copy_number,initial_deck_position)
  select deck_id,c.id,c.version,c.name,c.image_url,c.element,c.rarity,c.card_type,c.is_golden,
    c.base_power,c.base_max_life,c.effect_mana_cost,c.tier,c.leader_cooldown,
    coalesce((select jsonb_agg(jsonb_build_object('effect_order',e.effect_order,'trigger_type',e.trigger_type,
      'effect_code',e.effect_code,'target_mode',e.target_mode,'parameters',e.parameters,'priority',e.priority,
      'is_reaction',e.is_reaction,'once_per_turn',e.once_per_turn) order by e.effect_order)
      from public.card_effects e where e.card_id=c.id and e.is_active),'[]'::jsonb),
    gs.n,gs.n
  from generate_series(1,p_size) gs(n)
  cross join lateral(select x.* from public.cards x where x.is_active and x.card_type='normal'
    order by md5(x.id::text||gs.n::text||random()::text) limit 1)c;

  insert into public.match_cards(match_id,owner_user_id,controller_user_id,match_deck_card_id,
    source_card_id,zone,zone_position,is_face_up,base_power,base_max_life,current_power,
    maximum_power,current_life,maximum_life)
  select p_match_id,p_user_id,p_user_id,d.id,d.source_card_id,'deck',d.initial_deck_position,false,
    d.base_power,d.base_max_life,d.base_power,d.base_power,d.base_max_life,d.base_max_life
  from public.match_deck_cards d where d.match_deck_id=deck_id;
  return deck_id;
end $$;

create or replace function public.create_training_match(p_deck_size integer default 40)
returns jsonb language plpgsql security definer set search_path='' as $$
declare human uuid:=game_private.require_authenticated(); bot constant uuid:='00000000-0000-4000-8000-000000000071';
  mid uuid; rule_id uuid; human_life uuid[]; bot_life uuid[];
begin
  if p_deck_size<>40 then raise exception 'TRAINING_DECK_SIZE_MUST_BE_40'; end if;
  select id into rule_id from public.game_rule_versions where is_active order by created_at desc limit 1;
  if rule_id is null then raise exception 'ACTIVE_GAME_RULE_VERSION_REQUIRED'; end if;
  insert into public.matches(rule_version_id,match_type,status,created_by,requires_bans,is_private,
    started_at,expires_at,current_turn,active_player_id)
  values(rule_id,'friendly','setup',human,false,true,now(),now()+interval '8 hours',0,human)
  returning id into mid;
  insert into public.match_players(match_id,user_id,player_number)
  values(mid,human,1),(mid,bot,2);
  perform game_private.snapshot_random_training_deck(mid,human,p_deck_size);
  perform game_private.snapshot_random_training_deck(mid,bot,p_deck_size);
  insert into public.match_public_states(match_id,player1_user_id,player2_user_id,player1_username,
    player2_username,player1_avatar_url,player2_avatar_url)
  select mid,human,bot,p1.username,p2.username,p1.avatar_url,p2.avatar_url
  from public.profiles p1 cross join public.profiles p2 where p1.id=human and p2.id=bot;
  insert into public.training_matches(match_id,human_user_id,bot_user_id) values(mid,human,bot);
  perform game_private.deal_initial_hands(mid);

  select array_agg(id order by zone_position) into human_life from
    (select id,zone_position from public.match_cards where match_id=mid and owner_user_id=human and zone='hand' order by zone_position limit 3)q;
  select array_agg(id order by zone_position) into bot_life from
    (select id,zone_position from public.match_cards where match_id=mid and owner_user_id=bot and zone='hand' order by zone_position limit 3)q;
  update public.match_cards mc set zone='life',zone_position=x.ord,is_face_up=true
    from unnest(human_life) with ordinality x(id,ord) where mc.id=x.id;
  update public.match_cards mc set zone='life',zone_position=x.ord,is_face_up=true
    from unnest(bot_life) with ordinality x(id,ord) where mc.id=x.id;
  update public.match_players set setup_finished=true,mana_snapshot=4,mana_available=4 where match_id=mid;
  update public.matches set status='in_progress',current_turn=1,active_player_id=human,state_version=1 where id=mid;
  perform game_private.recalculate_match_public_state(mid);
  return jsonb_build_object('match_id',mid,'bot_user_id',bot,'deck_size',p_deck_size,'status','in_progress');
end $$;
revoke all on function public.create_training_match(integer) from public,anon;
grant execute on function public.create_training_match(integer) to authenticated;
notify pgrst,'reload schema';
