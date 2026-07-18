-- Executor dos efeitos comuns. Chamado por ativação manual e pelo despachante automático.
create or replace function game_private.execute_common_effect_internal(
 p_match_id uuid,p_actor uuid,p_source uuid,p_code text,p_params jsonb,
 p_target uuid default null,p_event jsonb default '{}'
) returns jsonb language plpgsql security definer set search_path='' as $$
declare
 s public.match_cards; t public.match_cards; opp uuid; turn_no integer; amount integer:=coalesce((p_params->>'amount')::integer,0);
 ids uuid[]:='{}'; picked uuid; n integer; result jsonb:='{}'; drawn jsonb:='[]'::jsonb; target_owner uuid; source_name text; target_name text;
begin
 select * into s from public.match_cards where id=p_source and match_id=p_match_id for update;
 if not found then raise exception 'EFFECT_SOURCE_NOT_FOUND'; end if;
 select current_turn into turn_no from public.matches where id=p_match_id;
 select user_id into opp from public.match_players where match_id=p_match_id and user_id<>p_actor order by player_number limit 1;
 select card_name into source_name from public.match_deck_cards where id=s.match_deck_card_id;

 if p_code in('common_elemental_prevent_damage','common_gargoyle_cancel_single_attack','common_baltazar_cancel_direct') then
  select pa.id into picked from public.pending_attacks pa where pa.match_id=p_match_id and pa.defender_user_id=p_actor and pa.status='awaiting_reaction' order by pa.created_at desc limit 1 for update;
  if picked is null then raise exception 'NO_PENDING_ATTACK_FOR_REACTION'; end if;
  if p_code='common_elemental_prevent_damage' and not exists(select 1 from public.pending_attack_cards pac join public.match_cards mc on mc.id=pac.match_card_id join public.match_deck_cards d on d.id=mc.match_deck_card_id where pac.pending_attack_id=picked and d.element='M&F') then raise exception 'ATTACKER_IS_NOT_M_AND_F'; end if;
  if p_code='common_gargoyle_cancel_single_attack' and (select count(*) from public.pending_attack_cards where pending_attack_id=picked)<>1 then raise exception 'REACTION_REQUIRES_SINGLE_ATTACKER'; end if;
  if p_code='common_baltazar_cancel_direct' then
   if not (select is_direct from public.pending_attacks where id=picked) then raise exception 'REACTION_REQUIRES_DIRECT_ATTACK'; end if;
   select id into p_target from public.match_cards where match_id=p_match_id and owner_user_id=p_actor and zone='hand' order by random() limit 1; if p_target is null then raise exception 'DISCARD_REQUIRED'; end if; perform game_private.move_card_checked(p_target,'graveyard',null,true);
  end if;
  update public.pending_attacks set declared_power=0,result=result||jsonb_build_object('damage_cancelled_by',p_code,'source_card_id',p_source) where id=picked;
  return jsonb_build_object('effect_code',p_code,'pending_attack_id',picked,'damage_cancelled',true);
 end if;

 -- Efeitos persistentes/adiados são consumidos pelas pontes 011/012.
 if p_code in (
  'common_block_draw_in_hand','common_graveyard_return_lock','common_javali_attack_rules','common_day_wraith_direct_attack',
  'common_elemental_prevent_damage','common_gargoyle_cancel_single_attack','common_panther_direct_life','common_cleaver_discard_for_direct',
  'common_lugos_next_civil_double_power','common_nekker_next_turn_mana','common_wolf_buff_deck','common_baltazar_cancel_direct',
  'common_general_reduce_max_mana','common_reynold_forced_dwarf_attack','common_jarl_lock_legendary_effects','common_gaetan_purge_hand',
  'common_ves_direct_random','common_kiyan_protect_deck_card','common_guillaume_destroy_deck','common_wild_dog_direct_life',
  'common_harpy_absorb_and_attack','common_child_ciri_attack_all_life','common_skjall_substitute_ciri'
 ) then
  insert into public.match_runtime_effects(match_id,owner_user_id,source_match_card_id,effect_code,scope,target_user_id,payload,starts_on_turn,expires_on_turn)
  values(p_match_id,p_actor,p_source,p_code,
   case when p_code like '%next_%' then 'next_turn' when p_code like '%attack%' or p_code like '%direct%' then 'card' else 'match' end,
   case when p_code in('common_general_reduce_max_mana','common_jarl_lock_legendary_effects') then opp else p_actor end,
   coalesce(p_params,'{}')||coalesce(p_event,'{}'),turn_no,
   case when p_code in('common_javali_attack_rules','common_day_wraith_direct_attack','common_panther_direct_life','common_cleaver_discard_for_direct','common_ves_direct_random','common_wild_dog_direct_life','common_harpy_absorb_and_attack','common_child_ciri_attack_all_life') then turn_no else null end);
  return jsonb_build_object('runtime_effect',p_code);
 end if;

 if p_code='common_draw_three_common' then
  select coalesce(array_agg(id),'{}') into ids from (select mc.id from public.match_cards mc join public.match_deck_cards d on d.id=mc.match_deck_card_id where mc.match_id=p_match_id and mc.owner_user_id=p_actor and mc.zone='deck' and d.rarity='common' order by mc.zone_position limit 3) q;
  foreach picked in array ids loop perform game_private.move_card_checked(picked,'hand',null,false); end loop;
 elsif p_code='common_erinia_exchange' then
  select mc.id into picked from public.match_cards mc join public.match_deck_cards d on d.id=mc.match_deck_card_id where mc.match_id=p_match_id and mc.owner_user_id=opp and mc.zone='hand' order by case d.rarity when 'common' then 1 when 'rare' then 2 when 'epic' then 3 else 4 end,random() limit 1;
  if picked is null or p_target is null then raise exception 'TARGET_REQUIRED'; end if;
  if not exists(select 1 from public.match_cards where id=p_target and owner_user_id=p_actor and zone='hand') then raise exception 'OWN_HAND_DISCARD_REQUIRED'; end if;
  update public.match_cards set owner_user_id=p_actor,controller_user_id=p_actor where id=picked;
  perform game_private.move_card_checked(p_target,'graveyard',null,true); ids:=array[picked,p_target];
 elsif p_code='common_endriuga_scaled_damage' then
  if p_target is null then raise exception 'TARGET_REQUIRED'; end if;
  select count(*) into n from public.match_cards where match_id=p_match_id and controller_user_id=opp and zone='reinforcement' and current_life>0;
  result:=game_private.apply_damage_internal(p_match_id,p_target,n*coalesce((p_params->>'amount_per_reinforcement')::integer,500),turn_no);
 elsif p_code='common_henselt_attack_all_life' then
  if exists(select 1 from public.match_cards where match_id=p_match_id and controller_user_id=opp and zone='reinforcement' and current_life>0) then raise exception 'ENEMY_HAS_REINFORCEMENTS'; end if;
  for picked in select id from public.match_cards where match_id=p_match_id and controller_user_id=opp and zone='life' and current_life>0 order by zone_position limit 3 loop result:=result||jsonb_build_object(picked::text,game_private.apply_damage_internal(p_match_id,picked,s.current_power,turn_no)); end loop;
 elsif p_code in('common_night_wraith_silence_hand','common_necrophage_destroy_hand') then
  select mc.id into picked from public.match_cards mc where mc.match_id=p_match_id and mc.owner_user_id=opp and mc.zone='hand' and (p_code='common_night_wraith_silence_hand' or mc.current_power<s.maximum_life) order by random() limit 1;
  if picked is not null then if p_code='common_night_wraith_silence_hand' then update public.match_cards set metadata=metadata||'{"effect_silenced":true}' where id=picked; else perform game_private.move_card_checked(picked,'graveyard',null,true); end if; end if;
 elsif p_code='common_keira_replace_life' then
  select mc.id into picked from public.match_cards mc join public.match_deck_cards d on d.id=mc.match_deck_card_id where mc.match_id=p_match_id and mc.owner_user_id=p_actor and mc.zone='deck' and d.rarity='common' order by random() limit 1;
  if picked is not null then perform game_private.move_card_checked(picked,'life',coalesce((p_event->>'old_position')::integer,1),true); end if;
 elsif p_code='common_ghoul_group_revive' then
  if (select count(*) from public.match_cards mc join public.match_deck_cards d on d.id=mc.match_deck_card_id where mc.match_id=p_match_id and mc.owner_user_id=p_actor and mc.zone='graveyard' and d.card_name=source_name)<2 then raise exception 'SECOND_GHOUL_REQUIRED'; end if;
  if p_target is null then raise exception 'GRAVEYARD_TARGET_REQUIRED'; end if; perform game_private.move_card_checked(p_target,'hand',null,false);
 elsif p_code='common_troll_discard_draw' then
  update public.match_cards set zone='graveyard',zone_position=null,is_face_up=true,is_destroyed=true,current_life=0 where match_id=p_match_id and owner_user_id=p_actor and zone='hand' and id<>p_source;
  drawn:=game_private.draw_internal(p_match_id,p_actor,2);
 elsif p_code='common_berserker_copy_stats' then
  select mc.* into t from public.match_cards mc where mc.match_id=p_match_id and mc.owner_user_id=opp and mc.zone='graveyard' order by random() limit 1;
  if not found then raise exception 'OPPONENT_GRAVEYARD_EMPTY'; end if;
  update public.match_cards set base_power=t.base_power,maximum_power=t.maximum_power,current_power=t.current_power,base_max_life=t.base_max_life,maximum_life=t.maximum_life,current_life=t.current_life where id=p_source;
 elsif p_code='common_puero_destroy_random_legendary' then
  select mc.id into picked from public.match_cards mc join public.match_deck_cards d on d.id=mc.match_deck_card_id where mc.match_id=p_match_id and mc.zone in('life','reinforcement','attacker','leader') and mc.current_life>0 and d.rarity='legendary' order by random() limit 1;
  if picked is null then raise exception 'NO_LEGENDARY_ON_FIELD'; end if; result:=game_private.apply_damage_internal(p_match_id,picked,20000,turn_no);
 elsif p_code='common_fairy_extra_draw' then drawn:=game_private.draw_internal(p_match_id,p_actor,1);
 elsif p_code='common_shani_redeploy_life' then
  select gs into n from generate_series(1,3) gs where not exists(select 1 from public.match_cards where match_id=p_match_id and controller_user_id=p_actor and zone='life' and zone_position=gs and current_life>0) order by random() limit 1;
  if n is null then raise exception 'NO_ELIGIBLE_LIFE_SLOT'; end if; update public.match_cards set zone='life',zone_position=n,is_destroyed=false,current_life=maximum_life,is_face_up=true where id=p_source;
 elsif p_code='common_barghest_overkill_to_deck' then perform game_private.move_card_checked(p_source,'deck',999,false);
 elsif p_code='common_barroso_purge_enemy_hand' then update public.match_cards set zone='graveyard',zone_position=null,is_face_up=true,is_destroyed=true,current_life=0 where match_id=p_match_id and owner_user_id=opp and zone='hand';
 elsif p_code='common_atrocious_ghoul_draw_epic' then
  select mc.id into picked from public.match_cards mc join public.match_deck_cards d on d.id=mc.match_deck_card_id where mc.match_id=p_match_id and mc.owner_user_id=p_actor and mc.zone='deck' and d.rarity='epic' order by random() limit 1; if picked is not null then perform game_private.move_card_checked(picked,'hand',null,false); end if;
 elsif p_code='common_beggar_king_destroy_life' then
  if (select count(*) from public.match_cards where match_id=p_match_id and owner_user_id=p_actor and zone='hand')<>1 then raise exception 'SOURCE_MUST_BE_ONLY_HAND_CARD'; end if; result:=game_private.apply_damage_internal(p_match_id,p_target,20000,turn_no);
 elsif p_code in('common_winkler_silence_elf','common_jarl_lock_legendary_effects') then update public.match_cards set metadata=metadata||'{"effect_silenced":true}' where id=p_target;
 elsif p_code='common_drowner_mill' then select id into picked from public.match_cards where match_id=p_match_id and owner_user_id=opp and zone='deck' order by zone_position limit 1; if picked is not null then perform game_private.move_card_checked(picked,'graveyard',null,true); end if;
 elsif p_code in('common_dilion_reduce_deck_cost','common_anna_increase_hand_costs') then
  update public.match_cards set metadata=jsonb_set(metadata,'{mana_cost_delta}',to_jsonb(coalesce((metadata->>'mana_cost_delta')::integer,0)+case when p_code='common_dilion_reduce_deck_cost' then -1 else 1 end)) where match_id=p_match_id and ((p_code='common_dilion_reduce_deck_cost' and owner_user_id=p_actor and zone='deck') or (p_code='common_anna_increase_hand_costs' and zone='hand'));
 elsif p_code in('common_tamara_choose_rare','common_sile_tutor_highest_mana') then
  if p_target is null or not exists(select 1 from public.match_cards mc join public.match_deck_cards d on d.id=mc.match_deck_card_id where mc.id=p_target and mc.owner_user_id=p_actor and mc.zone='deck' and ((p_code='common_tamara_choose_rare' and d.rarity='rare') or (p_code='common_sile_tutor_highest_mana' and d.element='M&F'))) then raise exception 'INVALID_DECK_TARGET'; end if; perform game_private.move_card_checked(p_target,'hand',null,false);
 elsif p_code='common_halmar_coin_attack' then
  if floor(random()*100)<45 then for picked in select id from public.match_cards where match_id=p_match_id and controller_user_id=p_actor and zone='life' and current_life>0 order by random() limit 2 loop result:=result||jsonb_build_object(picked::text,game_private.apply_damage_internal(p_match_id,picked,s.current_power,turn_no)); end loop; else select id into picked from public.match_cards where match_id=p_match_id and controller_user_id=opp and zone='life' and current_life>0 order by random() limit 1; result:=game_private.apply_damage_internal(p_match_id,picked,s.current_power,turn_no); end if;
 elsif p_code='common_thaler_steal_deck_to_graveyard' then select id into picked from public.match_cards where match_id=p_match_id and owner_user_id=opp and zone='deck' order by random() limit 1; update public.match_cards set owner_user_id=p_actor,controller_user_id=p_actor,zone='graveyard',zone_position=null,is_face_up=true where id=picked;
 elsif p_code='common_casimir_destroy_life' then
  if (select count(*) from public.match_cards where match_id=p_match_id and owner_user_id=opp and zone='deck') >= (select count(*) from public.match_cards where match_id=p_match_id and owner_user_id=p_actor and zone='deck') then raise exception 'ENEMY_DECK_NOT_SMALLER'; end if; result:=game_private.apply_damage_internal(p_match_id,p_target,20000,turn_no);
 elsif p_code='common_milton_return_turn_end' then insert into public.match_runtime_effects(match_id,owner_user_id,source_match_card_id,effect_code,scope,payload,starts_on_turn,expires_on_turn) values(p_match_id,p_actor,p_source,p_code,'turn_end','{}',turn_no,turn_no);
 elsif p_code='common_tomira_full_heal' then update public.match_cards set current_life=maximum_life where id=p_target and controller_user_id=p_actor and zone='life' and current_life>0;
 elsif p_code='common_corine_peek_hand' then select id into picked from public.match_cards where match_id=p_match_id and owner_user_id=opp and zone='hand' order by random() limit 1; insert into public.match_private_reveals(match_id,viewer_user_id,source_match_card_id,revealed_match_card_id,reveal_type) values(p_match_id,p_actor,p_source,picked,'opponent_hand');
 elsif p_code='common_joachim_revive_epic' then select mc.id into picked from public.match_cards mc join public.match_deck_cards d on d.id=mc.match_deck_card_id where mc.match_id=p_match_id and mc.owner_user_id=p_actor and mc.zone='graveyard' and d.rarity='epic' order by random() limit 1; if picked is not null then perform game_private.move_card_checked(picked,'hand',null,false); end if;
 elsif p_code='common_gerd_double_life' then if not exists(select 1 from public.match_players where match_id=p_match_id and user_id=opp and passed_turn) then raise exception 'OPPONENT_NEVER_PASSED'; end if; update public.match_cards set maximum_life=least(20000,maximum_life*2),current_life=least(20000,current_life*2) where id=p_source and zone='life';
 elsif p_code='common_barnabas_draw' then if not exists(select 1 from public.match_players where match_id=p_match_id and user_id=p_actor and destroyed_life_count>0) then raise exception 'NO_LIFE_CARD_WAS_DESTROYED'; end if; drawn:=game_private.draw_internal(p_match_id,p_actor,1);
 elsif p_code='common_nenneke_nonlethal_steal' then
  select * into t from public.match_cards where match_id=p_match_id and controller_user_id=opp and zone='life' and current_life>1000 order by random() limit 1; if not found then raise exception 'NO_NONLETHAL_TARGET_MANA_WASTED'; end if; update public.match_cards set current_life=current_life-1000 where id=t.id; select id into picked from public.match_cards where match_id=p_match_id and controller_user_id=p_actor and zone='life' and current_life>0 order by random() limit 1; update public.match_cards set current_life=least(maximum_life,current_life+1000) where id=picked;
 elsif p_code='common_ida_peek_deck' then for picked in select id from public.match_cards where match_id=p_match_id and owner_user_id=opp and zone='deck' order by zone_position limit 2 loop insert into public.match_private_reveals(match_id,viewer_user_id,source_match_card_id,revealed_match_card_id,reveal_type) values(p_match_id,p_actor,p_source,picked,'opponent_deck_top'); end loop;
 elsif p_code='common_bear_promote_to_life' then
  if s.zone<>'reinforcement' or s.current_life<=0 then raise exception 'BEAR_MUST_SURVIVE_AS_REINFORCEMENT'; end if;
  select id,zone_position into picked,n from public.match_cards where match_id=p_match_id and controller_user_id=p_actor and zone='life' and current_life<s.current_life*2 order by current_life,random() limit 1;
  if picked is null then raise exception 'NO_LOWER_LIFE_CARD'; end if; perform game_private.move_card_checked(picked,'graveyard',null,true); update public.match_cards set maximum_life=least(20000,maximum_life*2),current_life=least(20000,current_life*2),zone='life',zone_position=n,is_face_up=true where id=p_source;
 elsif p_code='common_totem_tutor_liches' then
  if (select count(*) from public.match_cards mc join public.match_deck_cards d on d.id=mc.match_deck_card_id where mc.match_id=p_match_id and mc.owner_user_id=p_actor and mc.zone='graveyard' and d.card_name='Totem')<4 then raise exception 'FOUR_TOTEMS_REQUIRED'; end if;
  update public.match_cards mc set zone='hand',zone_position=null,is_face_up=false,metadata=jsonb_set(mc.metadata,'{mana_cost_delta}',to_jsonb(-game_private.effect_card_cost(mc.id))) from public.match_deck_cards d where d.id=mc.match_deck_card_id and mc.match_id=p_match_id and mc.owner_user_id=p_actor and mc.zone='deck' and d.card_name in('Liche','Liche Ancião');
 elsif p_code='common_dudu_copy_hand_effect' then
  select mc.* into t from public.match_cards mc join public.match_deck_cards d on d.id=mc.match_deck_card_id where mc.match_id=p_match_id and mc.owner_user_id=opp and mc.zone='hand' and jsonb_array_length(d.effect_definition)>0 order by random() limit 1;
  if not found then raise exception 'NO_EFFECT_TO_COPY'; end if;
  insert into public.match_runtime_effects(match_id,owner_user_id,source_match_card_id,effect_code,scope,target_match_card_id,payload,starts_on_turn,expires_on_turn) select p_match_id,p_actor,p_source,'common_dudu_copied_effect','card',p_target,jsonb_build_object('copied_match_card_id',t.id,'cost_delta',2),turn_no,turn_no;
 elsif p_code='common_vivaldi_mutual_tutor' then
  if p_target is null or not exists(select 1 from public.match_cards where id=p_target and owner_user_id=p_actor and zone='deck') then raise exception 'OWN_DECK_CHOICE_REQUIRED'; end if;
  update public.match_cards set zone='hand',zone_position=null,is_face_up=false,metadata=jsonb_set(metadata,'{mana_cost_delta}',to_jsonb(coalesce((metadata->>'mana_cost_delta')::integer,0)+2)) where id=p_target;
  select coalesce(array_agg(id),'{}') into ids from public.match_cards where match_id=p_match_id and owner_user_id=opp and zone='deck';
  insert into public.pending_effect_choices(match_id,actor_user_id,source_match_card_id,effect_order,effect_code,choice_type,candidate_ids,public_prompt,private_context,expected_state_version) values(p_match_id,opp,p_source,1,p_code,'deck_card',ids,'Escolha uma carta do seu deck para comprar com custo +2.',jsonb_build_object('cost_delta',2),(select state_version from public.matches where id=p_match_id));
 elsif p_code='common_hattori_discard_next_discount' then
  select id into picked from public.match_cards where match_id=p_match_id and owner_user_id=p_actor and zone='hand' and id<>p_source order by random() limit 1; if picked is null then raise exception 'NO_CARD_TO_DISCARD'; end if;
  n:=game_private.effect_card_cost(picked); perform game_private.move_card_checked(picked,'graveyard',null,true); insert into public.match_runtime_effects(match_id,owner_user_id,source_match_card_id,effect_code,scope,target_user_id,payload,starts_on_turn) values(p_match_id,p_actor,p_source,p_code,'next_draw',p_actor,jsonb_build_object('discount',n),turn_no);
 elsif p_code='common_eveline_steal_highest_mana' then
  select mc.id into picked from public.match_cards mc where mc.match_id=p_match_id and mc.owner_user_id=opp and mc.zone='hand' order by game_private.effect_card_cost(mc.id) desc,random() limit 1; if picked is null then raise exception 'OPPONENT_HAND_EMPTY'; end if; update public.match_cards set owner_user_id=p_actor,controller_user_id=p_actor where id=picked;
 elsif p_code='common_anabelle_transform_hands' then
  select id into picked from public.cards where name='Aparição Noturna' and is_active order by version desc limit 1; if picked is null then raise exception 'NIGHT_WRAITH_CATALOG_CARD_REQUIRED'; end if;
  update public.match_cards mc set source_card_id=picked,metadata=metadata||jsonb_build_object('transformed_to_card_id',picked) where mc.match_id=p_match_id and mc.zone='hand';
 elsif p_code='common_vlodimir_replace_highest_life' then
  for target_owner in select unnest(array[p_actor,opp]) loop
   select mc.id,mc.zone_position into picked,n from public.match_cards mc join public.match_deck_cards d on d.id=mc.match_deck_card_id where mc.match_id=p_match_id and mc.owner_user_id=target_owner and mc.zone='life' order by case d.rarity when 'legendary' then 4 when 'epic' then 3 when 'rare' then 2 else 1 end desc,random() limit 1; if picked is null then continue; end if;
   select mc.id into p_target from public.match_cards mc join public.match_deck_cards d on d.id=mc.match_deck_card_id where mc.match_id=p_match_id and mc.owner_user_id=target_owner and mc.zone='deck' order by case d.rarity when 'common' then 1 when 'rare' then 2 when 'epic' then 3 else 4 end,random() limit 1;
   if p_target is not null then update public.match_cards set zone='deck',zone_position=999,is_face_up=false where id=picked; update public.match_cards set zone='life',zone_position=n,is_face_up=true where id=p_target; end if;
  end loop;
 elsif p_code='common_cow_tutor_chorabashe' then
  select mc.id into picked from public.match_cards mc join public.match_deck_cards d on d.id=mc.match_deck_card_id where mc.match_id=p_match_id and mc.owner_user_id=p_actor and mc.zone in('deck','graveyard') and d.card_name='Chorabashe' order by case mc.zone when 'deck' then 1 else 2 end limit 1; if picked is null then raise exception 'CHORABASHE_NOT_FOUND'; end if; perform game_private.move_card_checked(picked,'hand',null,false);
 elsif p_code='common_carpeado_zero_hand_costs' then
  update public.match_cards set metadata=metadata||jsonb_build_object('previous_mana_cost_delta',coalesce((metadata->>'mana_cost_delta')::integer,0),'mana_cost_delta',-game_private.effect_card_cost(id)) where match_id=p_match_id and zone='hand';
  insert into public.match_runtime_effects(match_id,owner_user_id,source_match_card_id,effect_code,scope,payload,starts_on_turn) values(p_match_id,p_actor,p_source,p_code,'match',jsonb_build_object('restore_on_each_next_turn',true),turn_no);
 elsif p_code='common_marlene_transform' then
  select mc.* into t from public.match_cards mc join public.match_deck_cards d on d.id=mc.match_deck_card_id where mc.match_id=p_match_id and mc.owner_user_id=opp and mc.zone='graveyard' and d.element='Bestiário' order by random() limit 1; if not found then raise exception 'NO_OPPONENT_BESTIARY_IN_GRAVEYARD'; end if;
  update public.match_cards set source_card_id=t.source_card_id,match_deck_card_id=t.match_deck_card_id,base_power=t.base_power,maximum_power=t.maximum_power,current_power=t.maximum_power,base_max_life=t.base_max_life,maximum_life=t.maximum_life,current_life=t.maximum_life,metadata=metadata||jsonb_build_object('transformed_from',p_source) where id=p_source;
 elsif p_code='common_morkvarg_curse_hand' then
  if (select count(*) from public.match_cards mc join public.match_deck_cards d on d.id=mc.match_deck_card_id where mc.match_id=p_match_id and mc.owner_user_id=opp and mc.zone='hand' and d.card_name='Morkvarg')>=4 then update public.match_cards set owner_user_id=opp,controller_user_id=opp,zone='graveyard',zone_position=null,is_face_up=true where id=p_source; else update public.match_cards set owner_user_id=opp,controller_user_id=opp,zone='hand',zone_position=null,is_face_up=false,is_destroyed=false,current_life=1,metadata=metadata||'{"hand_locked":true}' where id=p_source; end if;
 elsif p_code='common_udalryk_discard_coin_life' then
  select id into picked from public.match_cards where match_id=p_match_id and owner_user_id=opp and zone='hand' order by random() limit 1; if picked is not null then perform game_private.move_card_checked(picked,'graveyard',null,true); end if;
  if floor(random()*100)<35 then select id,zone_position into picked,n from public.match_cards where match_id=p_match_id and owner_user_id=p_actor and zone='life' order by random() limit 1; if picked is not null then perform game_private.move_card_checked(picked,'graveyard',null,true); update public.match_cards set zone='life',zone_position=n,is_face_up=true where id=p_source; end if; end if;
 elsif p_code in('common_arena_master_destroy_life','common_mabel_destroy_witcher') then
  if p_code='common_arena_master_destroy_life' and exists(select 1 from public.match_cards where match_id=p_match_id and controller_user_id=opp and zone='reinforcement' and current_life>0) then raise exception 'ENEMY_HAS_REINFORCEMENTS'; end if;
  select mc.id into picked from public.match_cards mc join public.match_deck_cards d on d.id=mc.match_deck_card_id where mc.match_id=p_match_id and mc.controller_user_id=opp and mc.current_life>0 and (case when p_code='common_arena_master_destroy_life' then mc.zone='life' and d.rarity='common' else mc.zone in('life','reinforcement','attacker','leader') and d.element='Witcher' end) order by random() limit 1;
  if picked is null then raise exception 'NO_ELIGIBLE_TARGET'; end if; result:=game_private.apply_damage_internal(p_match_id,picked,20000,turn_no);
 else
  -- Os compostos restantes são instalados como runtime e resolvidos pelas pontes.
  insert into public.match_runtime_effects(match_id,owner_user_id,source_match_card_id,effect_code,scope,target_user_id,target_match_card_id,payload,starts_on_turn)
  values(p_match_id,p_actor,p_source,p_code,'match',opp,p_target,coalesce(p_params,'{}')||coalesce(p_event,'{}'),turn_no);
  result:=jsonb_build_object('runtime_effect',p_code);
 end if;
 return jsonb_build_object('effect_code',p_code,'affected_ids',ids,'drawn',drawn,'result',result);
end $$;

create or replace function public.activate_card_effect_v2(p_match_id uuid,p_source_card_id uuid,p_effect_order integer default 1,p_target_card_id uuid default null,p_expected_version bigint default 0)
returns jsonb language plpgsql security definer set search_path='' as $$
declare actor uuid:=game_private.require_authenticated(); src public.match_cards; def jsonb; code text; params jsonb; trig text; reaction boolean; cost integer; result jsonb; new_version bigint;
begin
 select * into src from game_private.assert_common_effect_source(p_match_id,actor,p_source_card_id,p_expected_version,true);
 select x into def from public.match_deck_cards d cross join lateral jsonb_array_elements(d.effect_definition) x where d.id=src.match_deck_card_id and (x->>'effect_order')::integer=p_effect_order;
 if def is null then raise exception 'EFFECT_NOT_FOUND'; end if;
 code:=def->>'effect_code'; if code not like 'common_%' then return public.activate_match_effect(p_match_id,p_source_card_id,p_effect_order,p_target_card_id,p_expected_version); end if;
 perform game_private.assert_no_global_effect_lock(p_match_id,actor,p_source_card_id);
 trig:=def->>'trigger_type'; reaction:=coalesce((def->>'is_reaction')::boolean,false);
 if trig not in('manual','reaction') then raise exception 'EFFECT_IS_AUTOMATIC: %',trig; end if;
 if reaction and (select active_player_id from public.matches where id=p_match_id)=actor then raise exception 'REACTION_ONLY_ON_OPPONENT_TURN'; end if;
 if reaction and not exists(select 1 from public.pending_attacks where match_id=p_match_id and defender_user_id=actor and status='awaiting_reaction') then raise exception 'NO_PENDING_ATTACK_FOR_REACTION'; end if;
 if not reaction and (select active_player_id from public.matches where id=p_match_id)<>actor then raise exception 'NOT_YOUR_TURN'; end if;
 params:=coalesce(def->'parameters','{}'); cost:=coalesce((params->>'mana_cost')::integer,game_private.effect_card_cost(p_source_card_id),0);
 if coalesce((def->>'once_per_turn')::boolean,false) and exists(select 1 from public.match_effect_uses where match_id=p_match_id and match_card_id=p_source_card_id and effect_order=p_effect_order and turn_number=(select current_turn from public.matches where id=p_match_id)) then raise exception 'EFFECT_ALREADY_USED_THIS_TURN'; end if;
 perform game_private.pay_common_effect_cost(p_match_id,actor,cost);
 result:=game_private.execute_common_effect_internal(p_match_id,actor,p_source_card_id,code,params,p_target_card_id,'{}');
 insert into public.match_effect_uses(match_id,match_card_id,actor_user_id,effect_order,turn_number,is_reaction,mana_spent) values(p_match_id,p_source_card_id,actor,p_effect_order,(select current_turn from public.matches where id=p_match_id),reaction,cost);
 new_version:=game_private.record_match_action(p_match_id,actor,'effect_activated',jsonb_build_object('source_card_id',p_source_card_id,'effect_order',p_effect_order,'effect_code',code,'target_card_id',p_target_card_id,'mana_spent',cost,'result',result),'{}',p_expected_version);
 return result||jsonb_build_object('state_version',new_version,'mana_spent',cost);
end $$;
revoke all on function public.activate_card_effect_v2(uuid,uuid,integer,uuid,bigint) from public,anon;
grant execute on function public.activate_card_effect_v2(uuid,uuid,integer,uuid,bigint) to authenticated;
