-- V2.0: inspeção pública sanitizada, compra inicial correta e IA tática.
-- Execute depois de 202607180024_strict_v2_blocking_engine.sql.
begin;

alter table public.matches add column if not exists second_player_opening_draw_skipped boolean not null default false;

create or replace function game_private.guard_common_card_movement() returns trigger
language plpgsql security definer set search_path='' as $$
declare match_status text;match_turn integer;active_user uuid;skip_done boolean;
begin
 select status,current_turn,active_player_id,second_player_opening_draw_skipped into match_status,match_turn,active_user,skip_done from public.matches where id=old.match_id;
 -- Regra 7: somente o vencedor da iniciativa recebe a oitava carta. A primeira
 -- compra automática do segundo jogador (turno global 2) é consumida sem mover carta.
 if old.zone='deck' and new.zone='hand' and match_turn=2 and active_user=old.owner_user_id and not skip_done then
   update public.matches set second_player_opening_draw_skipped=true where id=old.match_id;
   return old;
 end if;
 if old.zone='deck' and new.zone='hand' and match_status not in('setup','ban_phase') and coalesce(match_turn,0)>=1 and exists(
   select 1 from public.match_cards x join public.match_deck_cards d on d.id=x.match_deck_card_id where x.match_id=old.match_id and x.owner_user_id=old.owner_user_id and x.zone='hand' and d.source_card_id=(select id from public.cards where code='COMMON_000')
 ) then return old;end if;
 if old.zone='graveyard' and new.zone in('hand','life','reinforcement','attacker','leader') and exists(
   select 1 from public.match_cards x join public.match_deck_cards d on d.id=x.match_deck_card_id where x.match_id=old.match_id and x.zone in('life','reinforcement','attacker','leader') and x.current_life>0 and d.source_card_id=(select id from public.cards where code='COMMON_002')
 ) then raise exception 'GRAVEYARD_RETURN_BLOCKED_BY_DUNY';end if;
 if coalesce((old.metadata->>'hand_locked')::boolean,false) and old.zone='hand' and new.zone<>'hand' then
   if new.zone<>'graveyard' or not coalesce((old.metadata->>'allow_overflow_to_graveyard')::boolean,false) then raise exception 'CURSED_HAND_CARD_CANNOT_MOVE';end if;
 end if;
 if coalesce((old.metadata->>'effect_cost_immune')::boolean,false) and (new.metadata->>'mana_cost_delta' is distinct from old.metadata->>'mana_cost_delta' or new.metadata->>'effect_silenced' is distinct from old.metadata->>'effect_silenced') then raise exception 'CARD_EFFECT_AND_COST_ARE_PROTECTED';end if;
 return new;
end $$;

create or replace view public.visible_match_card_details with(security_barrier=true) as
select mc.id as match_card_id,mc.match_id,
 case when mc.owner_user_id=auth.uid() or mc.is_face_up or mc.zone in('life','attacker','leader','graveyard','banished') then mdc.base_power end as base_power,
 case when mc.owner_user_id=auth.uid() or mc.is_face_up or mc.zone in('life','attacker','leader','graveyard','banished') then mdc.base_max_life end as base_max_life,
 case when mc.owner_user_id=auth.uid() or mc.is_face_up or mc.zone in('life','attacker','leader','graveyard','banished') then mdc.effect_mana_cost end as effect_mana_cost,
 case when mc.owner_user_id=auth.uid() or mc.is_face_up or mc.zone in('life','attacker','leader','graveyard','banished') then mdc.element end as element,
 case when mc.owner_user_id=auth.uid() or mc.is_face_up or mc.zone in('life','attacker','leader','graveyard','banished') then mdc.card_type end as card_type,
 case when mc.owner_user_id=auth.uid() or mc.is_face_up or mc.zone in('life','attacker','leader','graveyard','banished') then coalesce(c.is_original_rpg,false) end as is_original_rpg,
 case when mc.owner_user_id=auth.uid() or mc.is_face_up or mc.zone in('life','attacker','leader','graveyard','banished') then (mdc.rarity='collab') end as is_collab
from public.match_cards mc join public.match_deck_cards mdc on mdc.id=mc.match_deck_card_id join public.cards c on c.id=mc.source_card_id
where exists(select 1 from public.match_players mp where mp.match_id=mc.match_id and mp.user_id=auth.uid());
grant select on public.visible_match_card_details to authenticated;

create or replace function public.get_my_turn_usage(p_match_id uuid)
returns table(actions_this_turn integer,paid_effect_used boolean,free_effect_used boolean)
language sql stable security definer set search_path='' as $$
 select mp.actions_this_turn,mp.paid_effect_used_this_turn,mp.free_effect_used_this_turn from public.match_players mp where mp.match_id=p_match_id and mp.user_id=auth.uid()
$$;
revoke all on function public.get_my_turn_usage(uuid) from public,anon;
grant execute on function public.get_my_turn_usage(uuid) to authenticated;

-- Setup tático do Autômato: as três maiores vidas e, depois, as maiores
-- sobrevivências/efeitos defensivos restantes.
create or replace function public.submit_training_setup(p_match_id uuid,p_life_card_ids uuid[],p_reinforcement_card_ids uuid[] default array[]::uuid[],p_expected_version bigint default 0)
returns jsonb language plpgsql security definer set search_path='' as $$
declare human uuid:=game_private.require_authenticated();bot uuid;m public.matches;bot_life uuid[];bot_reinforcement uuid[];all_ids uuid[];version bigint;active uuid;human_roll integer;bot_roll integer;
begin
 select bot_user_id into bot from public.training_matches where match_id=p_match_id and human_user_id=human;if bot is null then raise exception 'NOT_YOUR_TRAINING_MATCH';end if;
 m:=game_private.lock_match_for_action(p_match_id,p_expected_version,array['setup']);
 if cardinality(p_life_card_ids)<>3 or(select count(distinct x)from unnest(p_life_card_ids)x)<>3 then raise exception 'EXACTLY_THREE_DISTINCT_LIFE_CARDS_REQUIRED';end if;
 if coalesce(cardinality(p_reinforcement_card_ids),0)>4 then raise exception 'TOO_MANY_REINFORCEMENTS';end if;
 all_ids:=p_life_card_ids||coalesce(p_reinforcement_card_ids,array[]::uuid[]);if(select count(distinct x)from unnest(all_ids)x)<>cardinality(all_ids)then raise exception 'DUPLICATED_SETUP_CARD';end if;
 if exists(select 1 from unnest(all_ids)x where not exists(select 1 from public.match_cards where id=x and match_id=p_match_id and owner_user_id=human and zone='hand'))then raise exception 'SETUP_CARD_NOT_IN_HAND';end if;
 update public.match_cards mc set zone='life',zone_position=x.ord,is_face_up=true,entered_zone_turn=0 from unnest(p_life_card_ids)with ordinality x(id,ord)where mc.id=x.id;
 update public.match_cards mc set zone='reinforcement',zone_position=x.ord,is_face_up=false,entered_zone_turn=0 from unnest(coalesce(p_reinforcement_card_ids,array[]::uuid[]))with ordinality x(id,ord)where mc.id=x.id;
 select array_agg(id order by maximum_life desc,id)into bot_life from(select id,maximum_life from public.match_cards where match_id=p_match_id and owner_user_id=bot and zone='hand' order by maximum_life desc,id limit 3)q;
 update public.match_cards mc set zone='life',zone_position=x.ord,is_face_up=true,entered_zone_turn=0 from unnest(bot_life)with ordinality x(id,ord)where mc.id=x.id;
 select array_agg(id order by maximum_life desc,id)into bot_reinforcement from(select mc.id,mc.maximum_life from public.match_cards mc where mc.match_id=p_match_id and mc.owner_user_id=bot and mc.zone='hand' order by mc.maximum_life desc,mc.id limit 4)q;
 update public.match_cards mc set zone='reinforcement',zone_position=x.ord,is_face_up=false,entered_zone_turn=0 from unnest(coalesce(bot_reinforcement,array[]::uuid[]))with ordinality x(id,ord)where mc.id=x.id;
 loop human_roll:=floor(random()*20+1)::integer;bot_roll:=floor(random()*20+1)::integer;exit when human_roll<>bot_roll;end loop;active:=case when human_roll>bot_roll then human else bot end;
 update public.match_players set setup_finished=true where match_id=p_match_id;perform game_private.sync_player_hand_mana(p_match_id,human);perform game_private.sync_player_hand_mana(p_match_id,bot);
 update public.matches set status='in_progress',current_turn=1,active_player_id=active,initiative_result=jsonb_build_object('mode','d20','player1',human_roll,'player2',bot_roll,'winner_user_id',active)where id=p_match_id;
 version:=game_private.record_match_action(p_match_id,human,'setup_submitted',jsonb_build_object('player_user_id',human,'life_count',3,'reinforcement_count',cardinality(p_reinforcement_card_ids),'setup_complete',true,'active_player_id',active,'initiative',jsonb_build_object('mode','d20','player1',human_roll,'player2',bot_roll,'winner_user_id',active)),jsonb_build_object('life_card_ids',p_life_card_ids,'reinforcement_card_ids',p_reinforcement_card_ids),p_expected_version);
 return jsonb_build_object('match_started',true,'active_player_id',active,'state_version',version);
end $$;

-- Cada chamada executa uma única decisão: reforçar, invocar ou atacar.
create or replace function public.run_training_bot_turn(p_match_id uuid,p_expected_version bigint)
returns jsonb language plpgsql security definer set search_path='' as $$
declare human uuid:=game_private.require_authenticated();bot uuid;m public.matches;chosen uuid;slot_no integer;version bigint;attack_id uuid;total_power integer;ids uuid[];reinforcement_count integer;
begin
 select bot_user_id into bot from public.training_matches where match_id=p_match_id and human_user_id=human;if bot is null then raise exception 'NOT_YOUR_TRAINING_MATCH';end if;
 select * into m from public.matches where id=p_match_id for update;if not found then raise exception 'MATCH_NOT_FOUND';end if;if m.state_version<>p_expected_version then raise exception 'STALE_MATCH_VERSION';end if;if m.status<>'in_progress' or m.engine_state<>'turn_action' then raise exception 'MATCH_FLOW_IS_BLOCKED';end if;if m.active_player_id<>bot then raise exception 'BOT_IS_NOT_ACTIVE_PLAYER';end if;version:=p_expected_version;
 select count(*)into reinforcement_count from public.match_cards where match_id=p_match_id and controller_user_id=bot and zone='reinforcement' and current_life>0;
 if reinforcement_count<2 and not exists(select 1 from public.match_cards where match_id=p_match_id and controller_user_id=bot and zone='reinforcement' and entered_zone_turn=m.current_turn)then
  select s into slot_no from generate_series(1,4)s where not exists(select 1 from public.match_cards where match_id=p_match_id and controller_user_id=bot and zone='reinforcement' and zone_position=s)order by s limit 1;
  select id into chosen from public.match_cards where match_id=p_match_id and owner_user_id=bot and zone='hand' order by maximum_life desc,current_power desc limit 1 for update;
  if chosen is not null and slot_no is not null then update public.match_cards set zone='reinforcement',zone_position=slot_no,is_face_up=false,entered_zone_turn=m.current_turn where id=chosen;update public.match_players set actions_this_turn=actions_this_turn+1 where match_id=p_match_id and user_id=bot;version:=game_private.record_match_action(p_match_id,bot,'card_played',jsonb_build_object('match_card_id',chosen,'destination_zone','reinforcement','destination_position',slot_no,'training_bot',true),'{}',version);return jsonb_build_object('action','reinforcement_played','state_version',version);end if;
 end if;
 if not exists(select 1 from public.match_cards where match_id=p_match_id and controller_user_id=bot and zone='attacker' and entered_zone_turn=m.current_turn)then
  select s into slot_no from generate_series(1,4)s where not exists(select 1 from public.match_cards where match_id=p_match_id and controller_user_id=bot and zone='attacker' and zone_position=s)order by s limit 1;
  select id into chosen from public.match_cards where match_id=p_match_id and owner_user_id=bot and zone='hand' order by current_power desc,maximum_life desc limit 1 for update;
  if chosen is not null and slot_no is not null then update public.match_cards set zone='attacker',zone_position=slot_no,is_face_up=true,entered_zone_turn=m.current_turn where id=chosen;update public.match_players set actions_this_turn=actions_this_turn+1 where match_id=p_match_id and user_id=bot;version:=game_private.record_match_action(p_match_id,bot,'card_played',jsonb_build_object('match_card_id',chosen,'destination_zone','attacker','destination_position',slot_no,'training_bot',true),'{}',version);return jsonb_build_object('action','attacker_played','state_version',version);end if;
 end if;
 select array_agg(id order by zone_position),sum(current_power)::integer into ids,total_power from public.match_cards where match_id=p_match_id and controller_user_id=bot and zone='attacker' and current_life>0 and can_attack and not has_attacked_this_turn;
 if coalesce(cardinality(ids),0)>0 then insert into public.pending_attacks(match_id,attacker_user_id,defender_user_id,status,is_direct,declared_power,reaction_deadline,declared_state_version)values(p_match_id,bot,human,'awaiting_reaction',false,total_power,now()+interval '20 seconds',version)returning id into attack_id;insert into public.pending_attack_cards(pending_attack_id,match_card_id,attack_position,power_when_declared)select attack_id,x.id,x.ord::integer,(select current_power from public.match_cards where id=x.id)from unnest(ids)with ordinality x(id,ord);update public.match_cards set metadata=metadata||jsonb_build_object('locked_for_pending_attack',attack_id)where id=any(ids);update public.match_players set actions_this_turn=actions_this_turn+1 where match_id=p_match_id and user_id=bot;version:=game_private.record_match_action(p_match_id,bot,'attack_declared',jsonb_build_object('pending_attack_id',attack_id,'attacker_user_id',bot,'defender_user_id',human,'attacker_card_ids',to_jsonb(ids),'total_power',total_power,'is_direct',false,'training_bot',true),'{}',version);update public.pending_attacks set declared_state_version=version where id=attack_id;return jsonb_build_object('action','attack_declared','state_version',version,'pending_attack_id',attack_id);end if;
 return game_private.change_active_turn(p_match_id,bot,coalesce((select actions_this_turn=0 from public.match_players where match_id=p_match_id and user_id=bot),true),version);
end $$;

revoke all on function public.submit_training_setup(uuid,uuid[],uuid[],bigint),public.run_training_bot_turn(uuid,bigint) from public,anon;
grant execute on function public.submit_training_setup(uuid,uuid[],uuid[],bigint),public.run_training_bot_turn(uuid,bigint) to authenticated;
notify pgrst,'reload schema';
commit;
