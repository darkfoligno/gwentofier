-- Lote autoritativo 2/3: cartas COMMON_026..COMMON_050 (COMMON_033 permanece
-- intacta porque não integra a lista enviada para este lote).
-- Depende de 202607200046_first_25_cards_authoritative_fix.sql.
begin;

with contract(code,trigger_type,effect_code,target_mode,parameters,is_reaction,once_per_turn) as (values
 ('COMMON_026','on_destroyed','common_nekker_next_turn_mana','none','{"required_old_zone":"reinforcement","requires_matching_card_in_hand":true,"amount":1,"mana_cost":2}'::jsonb,true,true),
 ('COMMON_027','on_destroyed','common_drowner_mill','enemy_hand','{"required_old_zone":"reinforcement","opponent_choice":true,"amount":1}'::jsonb,true,true),
 ('COMMON_028','on_attack_resolved','common_wolf_buff_deck','deck','{"target_name":"Lobo","multiplier":2,"requires_life_hit":true,"requires_no_enemy_reinforcements":true}'::jsonb,false,true),
 ('COMMON_029','on_attack_resolved','common_bear_promote_to_life','self','{"required_zone":"reinforcement","must_survive":true,"replace_lower_life":true,"life_multiplier":2,"mana_cost":2}'::jsonb,true,true),
 ('COMMON_030','manual','common_winkler_silence_elf','enemy','{"element":"Elfica","permanent":true,"mana_cost":4}'::jsonb,false,true),
 ('COMMON_031','reaction','common_baltazar_cancel_direct','none','{"allowed_source_zones":["hand","life","reinforcement"],"requires_direct_effect_attack":true,"random_discard":1,"mana_cost":3}'::jsonb,true,true),
 ('COMMON_032','on_destroyed','common_general_reduce_max_mana','none','{"required_old_zone":"reinforcement","simultaneous_friendly_element":"Cívil","permanent_max_mana_delta":-1,"mana_cost":3}'::jsonb,true,true),
 ('COMMON_034','manual','common_dilion_reduce_deck_cost','none','{"all_own_deck":true,"amount":-1,"minimum_cost":0,"mana_cost":4}'::jsonb,false,true),
 ('COMMON_035','manual','common_reynold_forced_dwarf_attack','none','{"name_contains":"Anão","random_enemy_life":true,"no_dwarf_reynolds_to_graveyard":true,"failed_attack_reynolds_to_banished":true,"mana_cost":1}'::jsonb,false,true),
 ('COMMON_036','manual','common_tamara_choose_rare','deck','{"rarity":"rare","player_choice":true,"mana_cost":4}'::jsonb,false,true),
 ('COMMON_037','manual','common_jarl_lock_legendary_effects','none','{"required_zone":"life","rarity":"legendary","until_source_destroyed":true,"mana_cost":3}'::jsonb,false,true),
 ('COMMON_038','manual','common_halmar_coin_attack','none','{"always_attack_random_enemy_life":true,"self_backfire_chance":45,"self_targets":2}'::jsonb,false,true),
 ('COMMON_039','manual','common_dudu_copy_hand_effect','none','{"source":"opponent_hand","random":true,"copied_cost_delta":2}'::jsonb,false,true),
 ('COMMON_040','manual','common_thaler_steal_deck_to_graveyard','none','{"random_opponent_deck":true,"transfer_to_own_graveyard":true,"mana_cost":1}'::jsonb,false,true),
 ('COMMON_041','manual','common_vivaldi_mutual_tutor','deck','{"choice_both_players":true,"cost_delta":2,"mana_cost":1}'::jsonb,false,true),
 ('COMMON_042','manual','common_casimir_destroy_life','enemy','{"requires_enemy_deck_smaller":true,"random_enemy_life":true,"mana_cost":4}'::jsonb,false,true),
 ('COMMON_043','manual','common_hattori_discard_next_discount','none','{"random_discard":1,"next_draw_discount_equals_discarded_cost":true,"mana_cost":3}'::jsonb,false,true),
 ('COMMON_044','manual','common_milton_return_turn_end','self','{"return_instead_of_destroyed":true}'::jsonb,false,true),
 ('COMMON_045','manual','common_sile_tutor_highest_mana','none','{"element":"M&F","highest_mana":true,"random_tie":true,"mana_cost":3}'::jsonb,false,true),
 ('COMMON_046','on_attack_resolved','common_gaetan_purge_hand','none','{"must_attack_alone":true,"exactly_one_enemy_reinforcement":true,"target_element":"Witcher","must_destroy":true,"mana_cost":3}'::jsonb,false,true),
 ('COMMON_047','manual','common_tomira_full_heal','ally','{"required_zone":"life","must_be_damaged":true,"restore_to_maximum":true,"mana_cost":4}'::jsonb,false,true),
 ('COMMON_048','manual','common_ves_direct_random','none','{"allowed_source_zones":["attacker"],"only_positive_mana_card_in_hand":true,"random_enemy_life":true,"ignore_reinforcement":true,"mana_cost":3}'::jsonb,false,true),
 ('COMMON_049','on_destroyed','common_kiyan_protect_deck_card','deck','{"old_zones":["reinforcement","life"],"element":"M&F","player_choice":true,"protect_mana_and_effect":true,"mana_cost":2}'::jsonb,true,true),
 ('COMMON_050','manual','common_corine_peek_hand','none','{"random_opponent_hand":true,"private_to_actor":true,"mana_cost":2}'::jsonb,false,true)
)
update public.card_effects ce set trigger_type=c.trigger_type,effect_code=c.effect_code,target_mode=c.target_mode,
 parameters=c.parameters,is_reaction=c.is_reaction,once_per_turn=c.once_per_turn,is_active=true,updated_at=clock_timestamp()
from contract c join public.cards card on card.code=c.code where ce.card_id=card.id and ce.effect_order=1;

update public.match_deck_cards mdc set effect_definition=coalesce((select jsonb_agg(jsonb_build_object(
 'effect_order',ce.effect_order,'trigger_type',ce.trigger_type,'effect_code',ce.effect_code,'target_mode',ce.target_mode,
 'parameters',ce.parameters,'priority',ce.priority,'is_reaction',ce.is_reaction,'once_per_turn',ce.once_per_turn,'is_active',ce.is_active)
 order by ce.effect_order) from public.card_effects ce where ce.card_id=mdc.source_card_id and ce.is_active),'[]'::jsonb)
where exists(select 1 from public.cards c where c.id=mdc.source_card_id and c.code between 'COMMON_026' and 'COMMON_050' and c.code<>'COMMON_033');

do $$ begin
 if to_regprocedure('game_private.execute_common_effect_internal_v26_core(uuid,uuid,uuid,text,jsonb,uuid,jsonb)') is null then
  alter function game_private.execute_common_effect_internal(uuid,uuid,uuid,text,jsonb,uuid,jsonb) rename to execute_common_effect_internal_v26_core;
 end if;
end $$;

create or replace function game_private.execute_common_effect_internal(
 p_match_id uuid,p_actor uuid,p_source uuid,p_code text,p_params jsonb,p_target uuid default null,p_event jsonb default '{}'
) returns jsonb language plpgsql security definer set search_path='' as $$
declare s public.match_cards;t public.match_cards;opp uuid;v_turn integer;v_id uuid;v_id2 uuid;v_slot integer;v_count integer;v_cost integer;
 v_roll integer;v_ids uuid[]:='{}'::uuid[];v_result jsonb:='{}'::jsonb;v_damage jsonb;v_effect jsonb;v_runtime uuid;
begin
 select mc.* into s from public.match_cards mc where mc.id=p_source and mc.match_id=p_match_id for update;if not found then raise exception 'EFFECT_SOURCE_NOT_FOUND';end if;
 select m.current_turn into v_turn from public.matches m where m.id=p_match_id;
 select mp.user_id into opp from public.match_players mp where mp.match_id=p_match_id and mp.user_id<>p_actor order by mp.player_number limit 1;

 if p_code='common_nekker_next_turn_mana' then
  if p_event->>'old_zone'<>'reinforcement' then raise exception 'NEKKER_MUST_DIE_AS_REINFORCEMENT';end if;
  if not exists(select 1 from public.match_cards mc join public.match_deck_cards d on d.id=mc.match_deck_card_id where mc.match_id=p_match_id and mc.owner_user_id=p_actor and mc.zone='hand' and mc.id<>p_source and lower(d.card_name)=lower('Nekker')) then raise exception 'ANOTHER_NEKKER_REQUIRED_IN_HAND';end if;
  insert into public.match_runtime_effects(match_id,owner_user_id,source_match_card_id,effect_code,scope,target_user_id,payload,starts_on_turn)
   values(p_match_id,p_actor,p_source,p_code,'next_turn',p_actor,jsonb_build_object('amount',1,'verified_matching_nekker_in_hand',true),v_turn) returning id into v_runtime;
  return jsonb_build_object('next_turn_mana',1,'runtime_effect_id',v_runtime,'condition','matching_nekker_in_hand');

 elsif p_code='common_drowner_mill' then
  if p_event->>'old_zone'<>'reinforcement' then raise exception 'DROWNER_MUST_DIE_AS_REINFORCEMENT';end if;
  select coalesce(array_agg(mc.id),'{}'::uuid[]) into v_ids from public.match_cards mc where mc.match_id=p_match_id and mc.owner_user_id=opp and mc.zone='hand';
  if cardinality(v_ids)=0 then raise exception 'OPPONENT_HAND_EMPTY';end if;
  insert into public.pending_effect_choices(match_id,actor_user_id,source_match_card_id,effect_order,effect_code,choice_type,min_choices,max_choices,candidate_ids,public_prompt,private_context,expected_state_version)
   values(p_match_id,opp,p_source,1,p_code,'hand_card',1,1,v_ids,'Afogador foi destruído: escolha 1 carta da sua mão para enviar ao cemitério.',jsonb_build_object('effect_owner_user_id',p_actor),(select m.state_version from public.matches m where m.id=p_match_id));
  return jsonb_build_object('opponent_choice_pending',true,'candidate_count',cardinality(v_ids));

 elsif p_code='common_wolf_buff_deck' then
  if jsonb_typeof(p_event->'life')<>'object' then raise exception 'WOLF_MUST_REACH_ENEMY_LIFE_CARD';end if;
  if exists(select 1 from public.match_cards mc where mc.match_id=p_match_id and mc.controller_user_id=opp and mc.zone='reinforcement' and mc.current_life>0) then raise exception 'WOLF_REQUIRES_NO_ENEMY_REINFORCEMENTS';end if;
  update public.match_cards mc set base_power=least(20000,mc.base_power*2),maximum_power=least(20000,mc.maximum_power*2),current_power=least(20000,mc.current_power*2),metadata=metadata||jsonb_build_object('permanent_wolf_double',true)
   from public.match_deck_cards d where d.id=mc.match_deck_card_id and mc.match_id=p_match_id and mc.owner_user_id=p_actor and mc.zone='deck' and lower(d.card_name)=lower('Lobo');
  get diagnostics v_count=row_count;return jsonb_build_object('life_reached',true,'doubled_wolves_in_deck',v_count,'multiplier',2);

 elsif p_code='common_winkler_silence_elf' then
  if not exists(select 1 from public.match_cards mc join public.match_deck_cards d on d.id=mc.match_deck_card_id where mc.id=p_target and mc.match_id=p_match_id and mc.controller_user_id=opp and mc.zone in('life','reinforcement','attacker','leader') and mc.current_life>0 and lower(d.element)=lower('Elfica')) then raise exception 'WINKLER_REQUIRES_ENEMY_ELFICA_ON_FIELD';end if;
  update public.match_cards set metadata=metadata||jsonb_build_object('effect_silenced',true,'permanently_silenced_by',p_source) where id=p_target;
  return jsonb_build_object('silenced_card_id',p_target,'element','Elfica','permanent',true);

 elsif p_code='common_general_reduce_max_mana' then
  if p_event->>'old_zone'<>'reinforcement' then raise exception 'GENERAL_MUST_DIE_AS_REINFORCEMENT';end if;
  if not exists(select 1 from public.match_cards mc join public.match_deck_cards d on d.id=mc.match_deck_card_id where mc.match_id=p_match_id and mc.owner_user_id=p_actor and mc.id<>p_source and mc.zone='graveyard' and d.element='Cívil' and mc.updated_at>=clock_timestamp()-interval '8 seconds') then raise exception 'SIMULTANEOUS_CIVIL_REINFORCEMENT_REQUIRED';end if;
  update public.match_players set mana_available=greatest(0,mana_available-1),mana_snapshot=greatest(0,mana_snapshot-1) where match_id=p_match_id and user_id=opp;
  insert into public.match_runtime_effects(match_id,owner_user_id,source_match_card_id,effect_code,scope,target_user_id,payload,starts_on_turn)
   values(p_match_id,p_actor,p_source,'common_general_permanent_max_mana_penalty','match',opp,jsonb_build_object('penalty',1),v_turn) returning id into v_runtime;
  return jsonb_build_object('target_user_id',opp,'permanent_max_mana_delta',-1,'runtime_effect_id',v_runtime);

 elsif p_code='common_dilion_reduce_deck_cost' then
  update public.match_cards set metadata=jsonb_set(metadata,'{mana_cost_delta}',to_jsonb(coalesce((metadata->>'mana_cost_delta')::integer,0)-1)) where match_id=p_match_id and owner_user_id=p_actor and zone='deck';
  get diagnostics v_count=row_count;return jsonb_build_object('affected_deck_cards',v_count,'mana_cost_delta',-1,'minimum_effective_cost',0);

 elsif p_code='common_reynold_forced_dwarf_attack' then
  select mc.* into t from public.match_cards mc join public.match_deck_cards d on d.id=mc.match_deck_card_id where mc.match_id=p_match_id and mc.owner_user_id=p_actor and mc.zone='deck' and d.card_name ilike '%Anão%' order by random() limit 1 for update of mc;
  if not found then
   select coalesce(array_agg(mc.id),'{}'::uuid[]) into v_ids from public.match_cards mc join public.match_deck_cards d on d.id=mc.match_deck_card_id where mc.match_id=p_match_id and mc.owner_user_id=p_actor and mc.zone='deck' and lower(d.card_name)=lower('Reynold Longmes');
   foreach v_id in array v_ids loop perform game_private.move_card_checked(v_id,'graveyard',null,true);end loop;
   return jsonb_build_object('dwarf_found',false,'reynolds_sent_to_graveyard',v_ids);
  end if;
  select mc.id into v_id from public.match_cards mc where mc.match_id=p_match_id and mc.controller_user_id=opp and mc.zone='life' and mc.current_life>0 order by random() limit 1 for update;
  if v_id is null then raise exception 'NO_ENEMY_LIFE_CARD';end if;
  v_damage:=game_private.apply_damage_internal(p_match_id,v_id,t.current_power,v_turn);
  if not coalesce((v_damage->>'destroyed')::boolean,false) then update public.match_cards mc set zone='banished',zone_position=null,is_face_up=true from public.match_deck_cards d where d.id=mc.match_deck_card_id and mc.match_id=p_match_id and mc.owner_user_id=p_actor and mc.zone='deck' and lower(d.card_name)=lower('Reynold Longmes');end if;
  return jsonb_build_object('dwarf_found',true,'dwarf_card_id',t.id,'random_life_target_id',v_id,'damage',v_damage,'reynolds_banished_on_failure',not coalesce((v_damage->>'destroyed')::boolean,false));

 elsif p_code='common_jarl_lock_legendary_effects' then
  if s.zone<>'life' or s.current_life<=0 then raise exception 'JARL_MUST_BE_ACTIVE_LIFE_CARD';end if;
  insert into public.match_runtime_effects(match_id,owner_user_id,source_match_card_id,effect_code,scope,target_user_id,payload,starts_on_turn)
   values(p_match_id,p_actor,p_source,p_code,'match',opp,jsonb_build_object('until_source_destroyed',true),v_turn) returning id into v_runtime;
  return jsonb_build_object('legendary_effects_locked_for',opp,'until_source_destroyed',true,'runtime_effect_id',v_runtime);

 elsif p_code='common_halmar_coin_attack' then
  select mc.id into v_id from public.match_cards mc where mc.match_id=p_match_id and mc.controller_user_id=opp and mc.zone='life' and mc.current_life>0 order by random() limit 1 for update;
  if v_id is null then raise exception 'NO_ENEMY_LIFE_CARD';end if;
  v_damage:=game_private.apply_damage_internal(p_match_id,v_id,s.current_power,v_turn);v_roll:=floor(random()*100+1)::integer;
  if v_roll<=45 then
   for v_id2 in select mc.id from public.match_cards mc where mc.match_id=p_match_id and mc.controller_user_id=p_actor and mc.zone='life' and mc.current_life>0 order by random() limit 2 loop
    v_result:=v_result||jsonb_build_object(v_id2::text,game_private.apply_damage_internal(p_match_id,v_id2,s.current_power,v_turn));v_ids:=array_append(v_ids,v_id2);
   end loop;
  end if;
  return jsonb_build_object('enemy_target_id',v_id,'enemy_damage',v_damage,'roll_1_to_100',v_roll,'backfire',v_roll<=45,'self_target_ids',v_ids,'self_damage_results',v_result);

 elsif p_code='common_dudu_copy_hand_effect' then
  select mc,d.effect_definition,d.effect_mana_cost into t,v_effect,v_cost from public.match_cards mc join public.match_deck_cards d on d.id=mc.match_deck_card_id where mc.match_id=p_match_id and mc.owner_user_id=opp and mc.zone='hand' and jsonb_array_length(coalesce(d.effect_definition,'[]'::jsonb))>0 order by random() limit 1;
  if not found then raise exception 'NO_OPPONENT_HAND_EFFECT_TO_COPY';end if;
  v_effect:=jsonb_build_array((v_effect->0)||jsonb_build_object('effect_order',1,'parameters',coalesce(v_effect->0->'parameters','{}'::jsonb)||jsonb_build_object('mana_cost',greatest(0,coalesce((v_effect->0->'parameters'->>'mana_cost')::integer,v_cost,0)+2))));
  update public.match_deck_cards set effect_definition=v_effect,effect_mana_cost=greatest(0,coalesce((v_effect->0->'parameters'->>'mana_cost')::integer,2)) where id=s.match_deck_card_id;
  update public.match_cards set metadata=metadata||jsonb_build_object('copied_from_match_card_id',t.id,'copied_effect_definition',v_effect,'copied_cost_delta',2) where id=p_source;
  insert into public.match_runtime_effects(match_id,owner_user_id,source_match_card_id,effect_code,scope,target_match_card_id,payload,starts_on_turn)
   values(p_match_id,p_actor,p_source,'common_dudu_copied_effect','card',t.id,jsonb_build_object('copied_effect_definition',v_effect,'cost_delta',2),v_turn) returning id into v_runtime;
  return jsonb_build_object('copied_match_card_id',t.id,'copied_effect_definition',v_effect,'copied_cost_delta',2,'runtime_effect_id',v_runtime);

 elsif p_code='common_thaler_steal_deck_to_graveyard' then
  select mc.id into v_id from public.match_cards mc where mc.match_id=p_match_id and mc.owner_user_id=opp and mc.zone='deck' order by random() limit 1 for update;
  if v_id is null then raise exception 'OPPONENT_DECK_EMPTY';end if;
  update public.match_cards set owner_user_id=p_actor,controller_user_id=p_actor,zone='graveyard',zone_position=null,is_face_up=true,is_destroyed=true,current_life=0 where id=v_id;
  return jsonb_build_object('stolen_card_id',v_id,'destination','actor_graveyard');

 elsif p_code='common_casimir_destroy_life' then
  if (select count(*) from public.match_cards where match_id=p_match_id and owner_user_id=opp and zone='deck') >= (select count(*) from public.match_cards where match_id=p_match_id and owner_user_id=p_actor and zone='deck') then raise exception 'ENEMY_DECK_NOT_SMALLER';end if;
  select mc.id into v_id from public.match_cards mc where mc.match_id=p_match_id and mc.controller_user_id=opp and mc.zone='life' and mc.current_life>0 order by random() limit 1 for update;
  if v_id is null then raise exception 'NO_ENEMY_LIFE_CARD';end if;v_damage:=game_private.apply_damage_internal(p_match_id,v_id,20000,v_turn);
  return jsonb_build_object('random_destroyed_life_id',v_id,'damage',v_damage);

 elsif p_code='common_hattori_discard_next_discount' then
  select mc.id into v_id from public.match_cards mc where mc.match_id=p_match_id and mc.owner_user_id=p_actor and mc.zone='hand' and mc.id<>p_source order by random() limit 1 for update;
  if v_id is null then raise exception 'NO_CARD_TO_DISCARD';end if;v_cost:=game_private.effect_card_cost(v_id);perform game_private.move_card_checked(v_id,'graveyard',null,true);
  insert into public.match_runtime_effects(match_id,owner_user_id,source_match_card_id,effect_code,scope,target_user_id,payload,starts_on_turn)
   values(p_match_id,p_actor,p_source,p_code,'next_draw',p_actor,jsonb_build_object('discount',v_cost,'discarded_card_id',v_id),v_turn) returning id into v_runtime;
  return jsonb_build_object('randomly_discarded_card_id',v_id,'saved_discount',v_cost,'runtime_effect_id',v_runtime);

 elsif p_code='common_milton_return_turn_end' then
  insert into public.match_runtime_effects(match_id,owner_user_id,source_match_card_id,effect_code,scope,payload,starts_on_turn,expires_on_turn)
   values(p_match_id,p_actor,p_source,p_code,'turn_end',jsonb_build_object('return_even_from_graveyard',true),v_turn,v_turn) returning id into v_runtime;
  return jsonb_build_object('return_at_turn_end',true,'runtime_effect_id',v_runtime);

 elsif p_code='common_sile_tutor_highest_mana' then
  select mc.id into v_id from public.match_cards mc join public.match_deck_cards d on d.id=mc.match_deck_card_id where mc.match_id=p_match_id and mc.owner_user_id=p_actor and mc.zone='deck' and d.element='M&F' order by game_private.effect_card_cost(mc.id) desc,random() limit 1 for update of mc;
  if v_id is null then raise exception 'NO_M_AND_F_CARD_IN_DECK';end if;v_cost:=game_private.effect_card_cost(v_id);perform game_private.move_card_checked(v_id,'hand',null,false);
  return jsonb_build_object('drawn_card_id',v_id,'highest_mana_cost',v_cost,'element','M&F');

 elsif p_code='common_gaetan_purge_hand' then
  if jsonb_array_length(coalesce(p_event->'attacker_card_ids','[]'::jsonb))<>1 then raise exception 'GAETAN_MUST_ATTACK_ALONE';end if;
  if jsonb_array_length(coalesce(p_event->'reinforcements','[]'::jsonb))<>1 then raise exception 'GAETAN_REQUIRES_EXACTLY_ONE_ENEMY_REINFORCEMENT';end if;
  if not exists(select 1 from jsonb_array_elements(coalesce(p_event->'reinforcements','[]'::jsonb))x(value) where x.value->>'element'='Witcher' and coalesce((x.value->>'final_hp')::integer,1)=0) then raise exception 'GAETAN_MUST_DESTROY_THE_ONLY_WITCHER_REINFORCEMENT';end if;
  select coalesce(array_agg(mc.id),'{}'::uuid[]) into v_ids from public.match_cards mc where mc.match_id=p_match_id and mc.owner_user_id=opp and mc.zone='hand';
  foreach v_id in array v_ids loop perform game_private.move_card_checked(v_id,'graveyard',null,true);end loop;
  return jsonb_build_object('gaetan_attacked_alone',true,'witcher_reinforcement_destroyed',true,'purged_enemy_hand_ids',v_ids);

 elsif p_code='common_tomira_full_heal' then
  select mc.* into t from public.match_cards mc where mc.id=p_target and mc.match_id=p_match_id and mc.controller_user_id=p_actor and mc.zone='life' and mc.current_life>0 and mc.current_life<mc.maximum_life for update;
  if not found then raise exception 'TOMIRA_REQUIRES_DAMAGED_OWN_LIFE_CARD';end if;update public.match_cards set current_life=maximum_life where id=t.id;
  return jsonb_build_object('healed_card_id',t.id,'life_before',t.current_life,'life_after',t.maximum_life,'healed_amount',t.maximum_life-t.current_life);

 elsif p_code='common_ves_direct_random' then
  if s.zone<>'attacker' then raise exception 'VES_MUST_BE_IN_ATTACK_FIELD';end if;
  if exists(select 1 from public.match_cards mc where mc.match_id=p_match_id and mc.owner_user_id=p_actor and mc.zone='hand' and mc.id<>p_source and game_private.effect_card_cost(mc.id)>0) then raise exception 'VES_MUST_BE_ONLY_POSITIVE_MANA_CARD_IN_HAND';end if;
  insert into public.match_runtime_effects(match_id,owner_user_id,source_match_card_id,effect_code,scope,payload,starts_on_turn,expires_on_turn)
   values(p_match_id,p_actor,p_source,p_code,'card',jsonb_build_object('ignore_reinforcement',true,'random_enemy_life',true),v_turn,v_turn) returning id into v_runtime;
  return jsonb_build_object('direct_attack_prepared',true,'random_enemy_life',true,'runtime_effect_id',v_runtime);

 elsif p_code='common_kiyan_protect_deck_card' then
  if p_event->>'old_zone' not in('reinforcement','life') then raise exception 'KIYAN_MUST_DIE_FROM_LIFE_OR_REINFORCEMENT';end if;
  select coalesce(array_agg(mc.id),'{}'::uuid[]) into v_ids from public.match_cards mc join public.match_deck_cards d on d.id=mc.match_deck_card_id where mc.match_id=p_match_id and mc.owner_user_id=p_actor and mc.zone='deck' and d.element='M&F';
  if cardinality(v_ids)=0 then raise exception 'NO_M_AND_F_CARD_IN_DECK';end if;
  insert into public.pending_effect_choices(match_id,actor_user_id,source_match_card_id,effect_order,effect_code,choice_type,min_choices,max_choices,candidate_ids,public_prompt,private_context,expected_state_version)
   values(p_match_id,p_actor,p_source,1,p_code,'deck_card',1,1,v_ids,'Escolha uma carta M&F do seu deck para torná-la imune a alterações de mana e efeito.',jsonb_build_object('protection','effect_and_mana'),(select m.state_version from public.matches m where m.id=p_match_id));
  return jsonb_build_object('choice_pending',true,'candidate_count',cardinality(v_ids));

 elsif p_code='common_corine_peek_hand' then
  select mc.id into v_id from public.match_cards mc where mc.match_id=p_match_id and mc.owner_user_id=opp and mc.zone='hand' order by random() limit 1;
  if v_id is null then raise exception 'OPPONENT_HAND_EMPTY';end if;
  insert into public.match_private_reveals(match_id,viewer_user_id,source_match_card_id,revealed_match_card_id,reveal_type) values(p_match_id,p_actor,p_source,v_id,'opponent_hand');
  return jsonb_build_object('private_reveal_created',true,'revealed_match_card_id',v_id,'viewer_user_id',p_actor);
 end if;
 return game_private.execute_common_effect_internal_v26_core(p_match_id,p_actor,p_source,p_code,p_params,p_target,p_event);
end $$;

-- Escolhas que pertencem ao oponente (Afogador) ou ao dono do gatilho (Kiyan).
do $$ begin
 if to_regprocedure('public.submit_effect_choice_v26_core(uuid,uuid[],bigint)') is null then alter function public.submit_effect_choice(uuid,uuid[],bigint) rename to submit_effect_choice_v26_core;end if;
end $$;
revoke all on function public.submit_effect_choice_v26_core(uuid,uuid[],bigint) from public,anon,authenticated;
create or replace function public.submit_effect_choice(p_choice_id uuid,p_selected_ids uuid[],p_expected_version bigint)
returns jsonb language plpgsql security definer set search_path='' as $$
declare c public.pending_effect_choices;actor uuid:=game_private.require_authenticated();v_id uuid;v_version bigint;v_owner uuid;
begin
 select * into c from public.pending_effect_choices where id=p_choice_id and actor_user_id=actor and status='pending';if not found then raise exception 'EFFECT_CHOICE_NOT_FOUND';end if;
 if c.effect_code not in('common_drowner_mill','common_kiyan_protect_deck_card') then return public.submit_effect_choice_v26_core(p_choice_id,p_selected_ids,p_expected_version);end if;
 c:=game_private.assert_effect_choice(p_choice_id,p_selected_ids,p_expected_version);v_id:=p_selected_ids[1];
 if c.effect_code='common_drowner_mill' then
  if not exists(select 1 from public.match_cards where id=v_id and match_id=c.match_id and owner_user_id=actor and zone='hand') then raise exception 'SELECTED_CARD_NO_LONGER_IN_HAND';end if;
  perform game_private.move_card_checked(v_id,'graveyard',null,true);
 elsif c.effect_code='common_kiyan_protect_deck_card' then
  v_owner:=actor;
  if not exists(select 1 from public.match_cards mc join public.match_deck_cards d on d.id=mc.match_deck_card_id where mc.id=v_id and mc.match_id=c.match_id and mc.owner_user_id=v_owner and mc.zone='deck' and d.element='M&F') then raise exception 'SELECTED_M_AND_F_CARD_NO_LONGER_AVAILABLE';end if;
  update public.match_cards set metadata=metadata||jsonb_build_object('effect_cost_immune',true,'protected_by_kiyan',c.source_match_card_id) where id=v_id;
 end if;
 update public.pending_effect_choices set status='resolved' where id=c.id;
 v_version:=game_private.record_match_action(c.match_id,actor,'effect_choice_resolved',jsonb_build_object('choice_id',c.id,'effect_code',c.effect_code,'selected_card_id',v_id,'source_card_id',c.source_match_card_id),'{}'::jsonb,p_expected_version);
 return jsonb_build_object('state_version',v_version,'selected_card_id',v_id,'effect_code',c.effect_code,'resolved',true);
end $$;

-- Persistências: desconto do próximo saque, retorno real de Milton, término do
-- bloqueio de Jarl e penalidade permanente do General.
create or replace function game_private.v27_card_transition_runtime()
returns trigger language plpgsql security definer set search_path='' as $$
declare rt public.match_runtime_effects;v_discount integer;
begin
 if old.zone='deck' and new.zone='hand' then
  select r.* into rt from public.match_runtime_effects r where r.match_id=new.match_id and r.owner_user_id=new.owner_user_id and r.effect_code='common_hattori_discard_next_discount' and r.active order by r.created_at limit 1 for update;
  if found then v_discount:=coalesce((rt.payload->>'discount')::integer,0);new.metadata:=jsonb_set(new.metadata,'{mana_cost_delta}',to_jsonb(coalesce((new.metadata->>'mana_cost_delta')::integer,0)-v_discount));update public.match_runtime_effects set active=false,consumed_at=clock_timestamp(),target_match_card_id=new.id where id=rt.id;end if;
 end if;
 if old.zone='life' and new.zone in('graveyard','banished') then update public.match_runtime_effects set active=false,consumed_at=clock_timestamp() where match_id=new.match_id and source_match_card_id=new.id and effect_code='common_jarl_lock_legendary_effects' and active;end if;
 return new;
end $$;
drop trigger if exists match_cards_v27_transition_runtime on public.match_cards;
create trigger match_cards_v27_transition_runtime before update of zone on public.match_cards for each row execute function game_private.v27_card_transition_runtime();

create or replace function game_private.v27_turn_runtime()
returns trigger language plpgsql security definer set search_path='' as $$
declare rt record;v_next uuid;
begin
 if new.action_type not in('turn_ended','turn_passed_without_action','turn_passed') then return new;end if;
 select active_player_id into v_next from public.matches where id=new.match_id;
 for rt in select r.* from public.match_runtime_effects r where r.match_id=new.match_id and r.effect_code='common_milton_return_turn_end' and r.active and r.owner_user_id=new.actor_user_id for update loop
  if (select count(*) from public.match_cards where match_id=new.match_id and owner_user_id=rt.owner_user_id and zone='hand')<10 then update public.match_cards set zone='hand',zone_position=null,is_face_up=false,is_destroyed=false,current_life=greatest(1,maximum_life) where id=rt.source_match_card_id and zone<>'banished';end if;
  update public.match_runtime_effects set active=false,consumed_at=clock_timestamp() where id=rt.id;
 end loop;
 update public.match_players mp set mana_available=greatest(0,mp.mana_available-q.penalty),mana_snapshot=greatest(0,mp.mana_snapshot-q.penalty)
 from(select target_user_id,sum(coalesce((payload->>'penalty')::integer,1))::integer penalty from public.match_runtime_effects where match_id=new.match_id and effect_code='common_general_permanent_max_mana_penalty' and active group by target_user_id)q
 where mp.match_id=new.match_id and mp.user_id=q.target_user_id and mp.user_id=v_next;
 return new;
end $$;
drop trigger if exists match_actions_v27_turn_runtime on public.match_actions;
create trigger match_actions_v27_turn_runtime after insert on public.match_actions for each row execute function game_private.v27_turn_runtime();

-- Corrige as consequências de ataque que não dependem do cliente.
-- A ponte V10 antiga também tratava Lobo/Gaetan com regras permissivas; ela
-- permanece responsável somente por Guillaume (COMMON_051), fora deste lote.
create or replace function game_private.resolve_v10_attack_followups()
returns trigger language plpgsql security definer set search_path='' as $$
declare v_ids uuid[];v_attacker uuid;v_code text;v_defender uuid;v_destroyed boolean;v_card uuid;
begin
 if new.action_type<>'attack_resolved' then return new;end if;
 select coalesce(array_agg(value::uuid),'{}'::uuid[]) into v_ids from jsonb_array_elements_text(coalesce(new.payload_public->'attacker_card_ids','[]'::jsonb));
 if cardinality(v_ids)=0 and new.payload_public->>'attacker_card_id' is not null then v_ids:=array[(new.payload_public->>'attacker_card_id')::uuid];end if;
 v_defender:=nullif(new.payload_public->>'defender_user_id','')::uuid;
 select exists(select 1 from jsonb_array_elements(coalesce(new.payload_public->'reinforcements','[]'::jsonb))x(value) where coalesce((x.value->>'final_hp')::integer,1)=0)
  or coalesce((new.payload_public->'life'->>'final_hp')::integer,1)=0 into v_destroyed;
 foreach v_attacker in array v_ids loop
  select c.code into v_code from public.match_cards mc join public.cards c on c.id=mc.source_card_id where mc.id=v_attacker;
  if cardinality(v_ids)=1 and v_code='COMMON_051' and v_destroyed then
   select mc.id into v_card from public.match_cards mc join public.match_deck_cards d on d.id=mc.match_deck_card_id where mc.match_id=new.match_id and mc.owner_user_id=v_defender and mc.zone='deck' and d.rarity in('common','rare') order by random() limit 1;
   if v_card is not null then perform game_private.move_card_checked(v_card,'graveyard',null,true);end if;
  end if;
 end loop;return new;
end $$;

create or replace function game_private.v27_second_batch_attack_followups()
returns trigger language plpgsql security definer set search_path='' as $$
begin
 return new;
end $$;
drop trigger if exists match_actions_v27_second_batch_followups on public.match_actions;
create trigger match_actions_v27_second_batch_followups after insert on public.match_actions for each row execute function game_private.v27_second_batch_attack_followups();

-- Ves só ignora reforços depois de sua ativação deliberada.
do $$ begin if to_regprocedure('public.declare_attack_v26_core(uuid,uuid[],boolean,bigint)') is null then alter function public.declare_attack(uuid,uuid[],boolean,bigint) rename to declare_attack_v26_core;end if;end $$;
revoke all on function public.declare_attack_v26_core(uuid,uuid[],boolean,bigint) from public,anon,authenticated;
create or replace function public.declare_attack(p_match_id uuid,p_attacker_card_ids uuid[],p_is_direct boolean default false,p_expected_version bigint default 0)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_actor uuid:=game_private.require_authenticated();rt public.match_runtime_effects;v_result jsonb;v_attack uuid;
begin
 select r.* into rt from public.match_runtime_effects r where r.match_id=p_match_id and r.owner_user_id=v_actor and r.source_match_card_id=any(coalesce(p_attacker_card_ids,'{}'::uuid[])) and r.effect_code='common_ves_direct_random' and r.active order by r.created_at limit 1 for update;
 if found then
  v_result:=public.declare_attack_v26_core(p_match_id,array[rt.source_match_card_id],true,p_expected_version);v_attack:=(v_result->>'pending_attack_id')::uuid;
  update public.pending_attacks set result=coalesce(result,'{}'::jsonb)||jsonb_build_object('prepared_effect',rt.effect_code,'random_enemy_life',true,'ignore_reinforcement',true) where id=v_attack;
  update public.match_runtime_effects set active=false,consumed_at=clock_timestamp() where id=rt.id;return v_result||jsonb_build_object('prepared_direct_effect',rt.effect_code);
 end if;
 return public.declare_attack_v26_core(p_match_id,p_attacker_card_ids,p_is_direct,p_expected_version);
end $$;

-- Leitura privada para Corine: nunca expõe a carta ao adversário nem ao estado público.
create or replace function public.get_my_active_private_reveals(p_match_id uuid)
returns table(id uuid,reveal_type text,source_match_card_id uuid,revealed_match_card_id uuid,card_data jsonb,created_at timestamptz)
language sql stable security definer set search_path='' as $$
 select r.id,r.reveal_type,r.source_match_card_id,r.revealed_match_card_id,jsonb_build_object('id',d.source_card_id,'nome',d.card_name,'image_url',d.image_url,'elemento',d.element,'raridade',d.rarity,'poder',mc.current_power,'vida',mc.current_life,'mana',game_private.effect_card_cost(mc.id),'effect_definition',d.effect_definition),r.created_at
 from public.match_private_reveals r join public.match_cards mc on mc.id=r.revealed_match_card_id join public.match_deck_cards d on d.id=mc.match_deck_card_id
 where r.match_id=p_match_id and r.viewer_user_id=auth.uid() and r.expires_at>clock_timestamp() order by r.created_at desc limit 5
$$;

-- Cenários individuais que exigem uma composição mais estrita que o gerador
-- geral do laboratório já oferece para este lote.
do $$ begin if to_regprocedure('public.setup_sandbox_match_v27_core(varchar)') is null then alter function public.setup_sandbox_match(varchar) rename to setup_sandbox_match_v27_core;end if;end $$;
revoke all on function public.setup_sandbox_match_v27_core(varchar) from public,anon,authenticated;
create or replace function public.setup_sandbox_match(p_card_id varchar)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_actor uuid:=game_private.require_authenticated();v_result jsonb;v_match uuid;v_code text;v_source uuid;v_aux uuid;v_bot uuid;
begin
 v_result:=public.setup_sandbox_match_v27_core(p_card_id);if not coalesce((v_result->>'success')::boolean,false) then return v_result;end if;
 v_match:=(v_result->>'match_id')::uuid;v_code:=v_result->>'card_code';
 select mc.id into v_source from public.match_cards mc where mc.match_id=v_match and mc.owner_user_id=v_actor and coalesce((mc.metadata->>'sandbox_card')::boolean,false) limit 1;
 select mp.user_id into v_bot from public.match_players mp where mp.match_id=v_match and mp.user_id<>v_actor order by mp.player_number limit 1;
 if v_code='COMMON_026' then
  select mc.id into v_aux from public.match_cards mc join public.match_deck_cards d on d.id=mc.match_deck_card_id where mc.match_id=v_match and mc.owner_user_id=v_actor and mc.id<>v_source and d.card_name='Nekker' order by mc.zone_position limit 1;
  update public.match_cards set zone='hand',zone_position=null,is_face_up=false,is_destroyed=false,current_life=greatest(1,maximum_life) where id=v_aux;
  update public.sandbox_matches set objective='Deixe Nekker ser destruído como Reforço, aceite o gatilho e avance: outro Nekker permanece na mão e a próxima reserva recebe +1 Mana.' where match_id=v_match;
  v_result:=v_result||jsonb_build_object('objective','Deixe Nekker ser destruído como Reforço, aceite o gatilho e avance: outro Nekker permanece na mão e a próxima reserva recebe +1 Mana.');
 elsif v_code='COMMON_032' then
  update public.match_cards set updated_at=clock_timestamp() where match_id=v_match and owner_user_id=v_actor and zone='reinforcement';
 elsif v_code='COMMON_046' then
  update public.match_cards set zone='deck',zone_position=900+coalesce(zone_position,0),is_face_up=false where match_id=v_match and owner_user_id=v_bot and zone='reinforcement';
  select mc.id into v_aux from public.match_cards mc where mc.match_id=v_match and mc.owner_user_id=v_bot and mc.zone='deck' order by mc.zone_position limit 1;
  perform game_private.lab_morph_card_v20(v_aux,'Witcher de Prova','common','Witcher',500,1000,1);
  update public.match_cards set zone='reinforcement',zone_position=1,is_face_up=false,current_life=1000,maximum_life=1000 where id=v_aux;
  update public.sandbox_matches set objective='Ataque somente com Gaetan, destrua o único Reforço Witcher e então aceite o gatilho para enviar toda a mão rival ao cemitério.' where match_id=v_match;
  v_result:=v_result||jsonb_build_object('objective','Ataque somente com Gaetan, destrua o único Reforço Witcher e então aceite o gatilho para enviar toda a mão rival ao cemitério.');
 end if;
 update public.sandbox_matches set state_before=game_private.lab_snapshot_v20(v_match,v_actor) where match_id=v_match;
 perform game_private.recalculate_match_public_state(v_match);return v_result;
end $$;

-- No laboratório o Autômato decide o descarte imposto pelo Afogador sem usar
-- auth.uid(); no PvP a escolha continua obrigatoriamente com o jogador rival.
create or replace function game_private.v27_resolve_sandbox_bot_choice()
returns trigger language plpgsql security definer set search_path='' as $$
declare v_owner uuid;v_selected uuid;
begin
 if new.effect_code<>'common_drowner_mill' or not exists(select 1 from public.sandbox_matches s where s.match_id=new.match_id) then return new;end if;
 select s.owner_user_id into v_owner from public.sandbox_matches s where s.match_id=new.match_id;
 if new.actor_user_id=v_owner then return new;end if;v_selected:=new.candidate_ids[1];
 if v_selected is not null then perform game_private.move_card_checked(v_selected,'graveyard',null,true);end if;
 update public.pending_effect_choices set status='resolved' where id=new.id;
 insert into public.match_effect_execution_log(match_id,source_match_card_id,effect_code,result) values(new.match_id,new.source_match_card_id,new.effect_code,jsonb_build_object('sandbox_bot_choice',true,'discarded_card_id',v_selected));
 return new;
end $$;
drop trigger if exists pending_effect_choices_v27_sandbox_bot on public.pending_effect_choices;
create trigger pending_effect_choices_v27_sandbox_bot after insert on public.pending_effect_choices for each row execute function game_private.v27_resolve_sandbox_bot_choice();

revoke all on function game_private.execute_common_effect_internal(uuid,uuid,uuid,text,jsonb,uuid,jsonb),game_private.v27_card_transition_runtime(),game_private.v27_turn_runtime(),game_private.v27_second_batch_attack_followups() from public,anon,authenticated;
revoke all on function public.submit_effect_choice(uuid,uuid[],bigint),public.declare_attack(uuid,uuid[],boolean,bigint),public.get_my_active_private_reveals(uuid) from public,anon;
revoke all on function public.setup_sandbox_match(varchar),game_private.v27_resolve_sandbox_bot_choice() from public,anon,authenticated;
grant execute on function public.submit_effect_choice(uuid,uuid[],bigint),public.declare_attack(uuid,uuid[],boolean,bigint),public.get_my_active_private_reveals(uuid),public.setup_sandbox_match(varchar) to authenticated;

notify pgrst,'reload schema';
commit;
