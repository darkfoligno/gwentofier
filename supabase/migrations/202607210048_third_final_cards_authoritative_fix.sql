-- Lote autoritativo 3/3: cartas COMMON_051..COMMON_071 (Fechamento integral das 72 cartas autoritativas).
-- Depende de 202607210047_second_25_cards_authoritative_fix.sql.
begin;

with contract(code,trigger_type,effect_code,target_mode,parameters,is_reaction,once_per_turn) as (values
 ('COMMON_051','on_attack_resolved','common_guillaume_destroy_deck','none','{"must_attack_alone":true,"required_target_zone":"reinforcement","mana_cost":0}'::jsonb,false,true),
 ('COMMON_052','manual','common_anabelle_transform_hands','none','{"target_card":"Aparição Noturna","mana_cost":5}'::jsonb,false,true),
 ('COMMON_053','manual','common_vlodimir_replace_highest_life','none','{"replace_both_players":true,"target_rarity":"common","mana_cost":2}'::jsonb,false,true),
 ('COMMON_054','manual','common_joachim_revive_epic','graveyard','{"rarity":"epic","required_zone":"life","mana_cost":2}'::jsonb,false,true),
 ('COMMON_055','manual','common_gerd_double_life','self','{"required_zone":"life","multiplier":2,"mana_cost":2}'::jsonb,false,true),
 ('COMMON_056','manual','common_wild_dog_direct_life','enemy','{"require_friendly_bestiary_life":true,"ignore_reinforcement":true,"mana_cost":1}'::jsonb,false,true),
 ('COMMON_057','manual','common_harpy_absorb_and_attack','none','{"allowed_source_zones":["attacker"],"max_absorb":10,"ignore_reinforcement":true,"mana_cost":3}'::jsonb,false,true),
 ('COMMON_058','on_destroyed','common_cow_tutor_chorabashe','none','{"required_old_zone":"reinforcement","target_name":"Chorabashe","mana_cost":3}'::jsonb,true,true),
 ('COMMON_059','manual','common_child_ciri_attack_all_life','none','{"allowed_source_zones":["attacker"],"base_mana_cost":15,"discount_per_witcher_in_deck":1,"damage":1500}'::jsonb,false,true),
 ('COMMON_060','manual','common_barnabas_draw','none','{"requires_destroyed_life":true,"amount":1,"mana_cost":0}'::jsonb,false,true),
 ('COMMON_061','manual','common_eveline_steal_highest_mana','none','{"steal_highest_mana":true,"mana_cost":5}'::jsonb,false,true),
 ('COMMON_062','manual','common_nenneke_nonlethal_steal','none','{"min_enemy_life":1001,"steal_amount":1000,"non_lethal":true,"mana_cost":4}'::jsonb,false,true),
 ('COMMON_063','manual','common_carpeado_zero_hand_costs','none','{"zero_both_hands":true,"duration":"until_next_turn","mana_cost":4}'::jsonb,false,true),
 ('COMMON_064','manual','common_marlene_transform','none','{"allowed_source_zones":["hand","life"],"element":"Bestiário","source_opponent_graveyard":true,"mana_cost":2}'::jsonb,false,true),
 ('COMMON_065','manual','common_anna_increase_hand_costs','none','{"increase_both_hands":1,"mana_cost":2}'::jsonb,false,true),
 ('COMMON_066','passive','common_skjall_substitute_ciri','none','{"protect_ciri":true}'::jsonb,false,false),
 ('COMMON_067','on_destroyed','common_morkvarg_curse_hand','none','{"required_old_zone":"reinforcement","max_hand_morkvargs":4,"mana_cost":4}'::jsonb,true,true),
 ('COMMON_068','manual','common_udalryk_discard_coin_life','none','{"random_opponent_discard":1,"backfire_chance":35,"replace_friendly_life":true,"mana_cost":0}'::jsonb,false,true),
 ('COMMON_069','manual','common_ida_peek_deck','none','{"peek_top":2,"opponent_deck":true,"mana_cost":4}'::jsonb,false,true),
 ('COMMON_070','manual','common_arena_master_destroy_life','none','{"requires_no_enemy_reinforcements":true,"target_rarity":"common","mana_cost":6}'::jsonb,false,true),
 ('COMMON_071','manual','common_mabel_destroy_witcher','none','{"target_element":"Witcher","destroy_random":true,"mana_cost":2}'::jsonb,false,true)
)
update public.card_effects ce set trigger_type=c.trigger_type,effect_code=c.effect_code,target_mode=c.target_mode,
 parameters=c.parameters,is_reaction=c.is_reaction,once_per_turn=c.once_per_turn,is_active=true,updated_at=clock_timestamp()
from contract c join public.cards card on card.code=c.code where ce.card_id=card.id and ce.effect_order=1;

update public.match_deck_cards mdc set effect_definition=coalesce((select jsonb_agg(jsonb_build_object(
 'effect_order',ce.effect_order,'trigger_type',ce.trigger_type,'effect_code',ce.effect_code,'target_mode',ce.target_mode,
 'parameters',ce.parameters,'priority',ce.priority,'is_reaction',ce.is_reaction,'once_per_turn',ce.once_per_turn,'is_active',ce.is_active)
 order by ce.effect_order) from public.card_effects ce where ce.card_id=mdc.source_card_id and ce.is_active),'[]'::jsonb)
where exists(select 1 from public.cards c where c.id=mdc.source_card_id and c.code between 'COMMON_051' and 'COMMON_071');

do $$ begin
 if to_regprocedure('game_private.execute_common_effect_internal_v27_core(uuid,uuid,uuid,text,jsonb,uuid,jsonb)') is null then
  alter function game_private.execute_common_effect_internal(uuid,uuid,uuid,text,jsonb,uuid,jsonb) rename to execute_common_effect_internal_v27_core;
 end if;
end $$;

create or replace function game_private.execute_common_effect_internal(
 p_match_id uuid,p_actor uuid,p_source uuid,p_code text,p_params jsonb,p_target uuid default null,p_event jsonb default '{}'
) returns jsonb language plpgsql security definer set search_path='' as $$
declare s public.match_cards;t public.match_cards;opp uuid;v_turn integer;v_id uuid;v_id2 uuid;v_slot integer;v_count integer;v_cost integer;
 v_roll integer;v_ids uuid[]:='{}'::uuid[];v_result jsonb:='{}'::jsonb;v_damage jsonb;v_zone text;v_target_owner uuid;
 v_count_actor integer;v_count_opp integer;v_card_id uuid;v_deck_card_id uuid;
begin
 select mc.* into s from public.match_cards mc where mc.id=p_source and mc.match_id=p_match_id for update;if not found then raise exception 'EFFECT_SOURCE_NOT_FOUND';end if;
 select m.current_turn into v_turn from public.matches m where m.id=p_match_id;
 select mp.user_id into opp from public.match_players mp where mp.match_id=p_match_id and mp.user_id<>p_actor order by mp.player_number limit 1;

 if p_code='common_guillaume_destroy_deck' then
  if p_event->>'life' is not null then raise exception 'GUILLAUME_MUST_ATTACK_REINFORCEMENT';end if;
  select mc.id into v_id from public.match_cards mc join public.match_deck_cards d on d.id=mc.match_deck_card_id where mc.match_id=p_match_id and mc.owner_user_id=opp and mc.zone='deck' and d.rarity in('common','rare') order by random() limit 1;
  if v_id is not null then perform game_private.move_card_checked(v_id,'graveyard',null,true);end if;
  return jsonb_build_object('milled_card_id',v_id,'target_user_id',opp);

 elsif p_code='common_anabelle_transform_hands' then
  select c.id into v_card_id from public.cards c where c.code='COMMON_008' and c.is_active order by c.version desc limit 1;
  if v_card_id is null then raise exception 'NIGHT_WRAITH_CATALOG_CARD_REQUIRED';end if;

  select count(*) into v_count_actor from public.match_cards mc where mc.match_id=p_match_id and mc.owner_user_id=p_actor and mc.zone='hand';
  select count(*) into v_count_opp from public.match_cards mc where mc.match_id=p_match_id and mc.owner_user_id=opp and mc.zone='hand';

  -- Discard current hands to graveyard
  for t in select mc.id from public.match_cards mc where mc.match_id=p_match_id and mc.owner_user_id=p_actor and mc.zone='hand' loop
   perform game_private.move_card_checked(t.id,'graveyard',null,true);
  end loop;
  for t in select mc.id from public.match_cards mc where mc.match_id=p_match_id and mc.owner_user_id=opp and mc.zone='hand' loop
   perform game_private.move_card_checked(t.id,'graveyard',null,true);
  end loop;

  -- Create spawned Night Wraith cards for actor
  for i in 1..v_count_actor loop
   insert into public.match_deck_cards(match_id,owner_user_id,source_card_id,card_name,rarity,element,type,base_mana_cost,base_power,base_max_life,effect_definition)
   select p_match_id,p_actor,c.id,c.name,c.rarity,c.element,c.type,c.base_mana_cost,c.base_power,c.base_max_life,
    coalesce((select jsonb_agg(jsonb_build_object('effect_order',ce.effect_order,'trigger_type',ce.trigger_type,'effect_code',ce.effect_code,'target_mode',ce.target_mode,'parameters',ce.parameters,'priority',ce.priority,'is_reaction',ce.is_reaction,'once_per_turn',ce.once_per_turn,'is_active',ce.is_active) order by ce.effect_order) from public.card_effects ce where ce.card_id=c.id and ce.is_active),'[]'::jsonb)
   from public.cards c where c.id=v_card_id returning id into v_deck_card_id;

   insert into public.match_cards(match_id,owner_user_id,controller_user_id,source_card_id,match_deck_card_id,zone,is_face_up,base_power,maximum_power,current_power,base_max_life,maximum_life,current_life,metadata)
   select p_match_id,p_actor,p_actor,v_card_id,v_deck_card_id,'hand',true,d.base_power,d.base_power,d.base_power,d.base_max_life,d.base_max_life,d.base_max_life,jsonb_build_object('spawned_by_anabelle',true)
   from public.match_deck_cards d where d.id=v_deck_card_id;
  end loop;

  -- Create spawned Night Wraith cards for opponent
  for i in 1..v_count_opp loop
   insert into public.match_deck_cards(match_id,owner_user_id,source_card_id,card_name,rarity,element,type,base_mana_cost,base_power,base_max_life,effect_definition)
   select p_match_id,opp,c.id,c.name,c.rarity,c.element,c.type,c.base_mana_cost,c.base_power,c.base_max_life,
    coalesce((select jsonb_agg(jsonb_build_object('effect_order',ce.effect_order,'trigger_type',ce.trigger_type,'effect_code',ce.effect_code,'target_mode',ce.target_mode,'parameters',ce.parameters,'priority',ce.priority,'is_reaction',ce.is_reaction,'once_per_turn',ce.once_per_turn,'is_active',ce.is_active) order by ce.effect_order) from public.card_effects ce where ce.card_id=c.id and ce.is_active),'[]'::jsonb)
   from public.cards c where c.id=v_card_id returning id into v_deck_card_id;

   insert into public.match_cards(match_id,owner_user_id,controller_user_id,source_card_id,match_deck_card_id,zone,is_face_up,base_power,maximum_power,current_power,base_max_life,maximum_life,current_life,metadata)
   select p_match_id,opp,opp,v_card_id,v_deck_card_id,'hand',true,d.base_power,d.base_power,d.base_power,d.base_max_life,d.base_max_life,d.base_max_life,jsonb_build_object('spawned_by_anabelle',true)
   from public.match_deck_cards d where d.id=v_deck_card_id;
  end loop;

  return jsonb_build_object('actor_drawn_night_wraiths',v_count_actor,'opp_drawn_night_wraiths',v_count_opp,'transformed',true);

 elsif p_code='common_vlodimir_replace_highest_life' then
  for v_target_owner in select unnest(array[p_actor,opp]) loop
   select mc.id,mc.zone_position into v_id,v_slot from public.match_cards mc join public.match_deck_cards d on d.id=mc.match_deck_card_id where mc.match_id=p_match_id and mc.owner_user_id=v_target_owner and mc.zone='life' and mc.current_life>0 order by case d.rarity when 'legendary' then 4 when 'epic' then 3 when 'rare' then 2 else 1 end desc,random() limit 1;
   if v_id is null then continue;end if;

   select mc.id into v_id2 from public.match_cards mc join public.match_deck_cards d on d.id=mc.match_deck_card_id where mc.match_id=p_match_id and mc.owner_user_id=v_target_owner and mc.zone='deck' order by case d.rarity when 'common' then 1 when 'rare' then 2 when 'epic' then 3 else 4 end,random() limit 1;
   if v_id2 is not null then
    perform game_private.move_card_checked(v_id,'graveyard',null,true);
    update public.match_cards set zone='life',zone_position=v_slot,is_face_up=true,is_destroyed=false,current_life=maximum_life where id=v_id2;
   end if;
  end loop;
  return jsonb_build_object('replaced_highest_life_both_players',true);

 elsif p_code='common_joachim_revive_epic' then
  select mc.id into v_id from public.match_cards mc join public.match_deck_cards d on d.id=mc.match_deck_card_id where mc.match_id=p_match_id and mc.owner_user_id=p_actor and mc.zone='graveyard' and d.rarity='epic' order by random() limit 1;
  if v_id is null then raise exception 'NO_EPIC_CARD_IN_GRAVEYARD';end if;
  perform game_private.move_card_checked(v_id,'hand',null,false);
  return jsonb_build_object('revived_epic_card_id',v_id);

 elsif p_code='common_gerd_double_life' then
  if s.zone<>'life' then raise exception 'GERD_MUST_BE_IN_LIFE_ZONE';end if;
  update public.match_cards set maximum_life=least(20000,maximum_life*2),current_life=least(20000,current_life*2) where id=p_source;
  return jsonb_build_object('doubled_life_card_id',p_source,'multiplier',2);

 elsif p_code='common_wild_dog_direct_life' then
  if not exists(select 1 from public.match_cards mc join public.match_deck_cards d on d.id=mc.match_deck_card_id where mc.match_id=p_match_id and mc.owner_user_id=p_actor and mc.zone='life' and mc.current_life>0 and d.element='Bestiário') then
   raise exception 'BESTIARY_LIFE_CARD_REQUIRED';
  end if;
  if p_target is null or not exists(select 1 from public.match_cards mc where mc.id=p_target and mc.match_id=p_match_id and mc.controller_user_id=opp and mc.zone='life' and mc.current_life>0) then
   select mc.id into p_target from public.match_cards mc where mc.match_id=p_match_id and mc.controller_user_id=opp and mc.zone='life' and mc.current_life>0 order by random() limit 1;
   if p_target is null then raise exception 'NO_ENEMY_LIFE_CARD_AVAILABLE';end if;
  end if;
  v_damage:=game_private.apply_damage_internal(p_match_id,p_target,1300,v_turn);
  return jsonb_build_object('direct_attack_life_card_id',p_target,'damage_result',v_damage);

 elsif p_code='common_harpy_absorb_and_attack' then
  select count(*) into v_count from public.match_cards mc join public.match_deck_cards d on d.id=mc.match_deck_card_id where mc.match_id=p_match_id and mc.owner_user_id=p_actor and mc.zone='deck' and d.card_name='Harpia';
  v_count:=least(10,v_count);
  update public.match_cards set zone='graveyard',zone_position=null where id in(
   select mc.id from public.match_cards mc join public.match_deck_cards d on d.id=mc.match_deck_card_id where mc.match_id=p_match_id and mc.owner_user_id=p_actor and mc.zone='deck' and d.card_name='Harpia' limit v_count
  );
  select mc.id into p_target from public.match_cards mc where mc.match_id=p_match_id and mc.controller_user_id=opp and mc.zone='life' and mc.current_life>0 order by mc.zone_position desc limit 1;
  if p_target is not null then
   v_damage:=game_private.apply_damage_internal(p_match_id,p_target,200+(v_count*200),v_turn);
  end if;
  return jsonb_build_object('absorbed_harpies',v_count,'total_power',200+(v_count*200),'target_life_card_id',p_target);

 elsif p_code='common_cow_tutor_chorabashe' then
  if p_event->>'old_zone'<>'reinforcement' then raise exception 'COW_MUST_DIE_AS_REINFORCEMENT';end if;
  select mc.id into v_id from public.match_cards mc join public.match_deck_cards d on d.id=mc.match_deck_card_id where mc.match_id=p_match_id and mc.owner_user_id=p_actor and mc.zone in('deck','graveyard') and d.card_name='Chorabashe' order by case mc.zone when 'deck' then 1 else 2 end limit 1;
  if v_id is null then raise exception 'CHORABASHE_NOT_FOUND';end if;
  perform game_private.move_card_checked(v_id,'hand',null,false);
  return jsonb_build_object('tutored_chorabashe_id',v_id);

 elsif p_code='common_child_ciri_attack_all_life' then
  select count(*) into v_count from public.match_cards mc join public.match_deck_cards d on d.id=mc.match_deck_card_id where mc.match_id=p_match_id and mc.owner_user_id=p_actor and mc.zone='deck' and (d.element='Witcher' or d.card_name ilike '%witcher%');
  v_ids:='{}'::uuid[];
  for t in select mc.id from public.match_cards mc where mc.match_id=p_match_id and mc.controller_user_id=opp and mc.zone='life' and mc.current_life>0 loop
   v_damage:=game_private.apply_damage_internal(p_match_id,t.id,1500,v_turn);
   v_ids:=array_append(v_ids,t.id);
  end loop;
  return jsonb_build_object('attacked_life_cards',v_ids,'witcher_deck_count',v_count,'effective_mana_cost',greatest(0,15-v_count));

 elsif p_code='common_barnabas_draw' then
  select count(*) into v_count from public.match_cards mc where mc.match_id=p_match_id and mc.owner_user_id=p_actor and mc.zone='life' and mc.current_life>0;
  if v_count>=3 then
   if not exists(select 1 from public.match_cards mc join public.match_deck_cards d on d.id=mc.match_deck_card_id where mc.match_id=p_match_id and mc.owner_user_id=p_actor and mc.zone='graveyard' and coalesce((mc.metadata->>'was_life_card')::boolean,false)=true) then
    raise exception 'NO_LIFE_CARD_DESTROYED_YET';
   end if;
  end if;
  select mc.id into v_id from public.match_cards mc where mc.match_id=p_match_id and mc.owner_user_id=p_actor and mc.zone='deck' order by mc.zone_position asc,mc.created_at asc limit 1;
  if v_id is null then raise exception 'DECK_EMPTY';end if;
  perform game_private.move_card_checked(v_id,'hand',null,false);
  return jsonb_build_object('drawn_card_id',v_id,'condition_passed',true);

 elsif p_code='common_eveline_steal_highest_mana' then
  select mc.id into v_id from public.match_cards mc where mc.match_id=p_match_id and mc.owner_user_id=opp and mc.zone='hand' order by game_private.effect_card_cost(mc.id) desc,random() limit 1;
  if v_id is null then raise exception 'OPPONENT_HAND_EMPTY';end if;
  update public.match_cards set owner_user_id=p_actor,controller_user_id=p_actor where id=v_id;
  return jsonb_build_object('stolen_card_id',v_id,'stolen_from',opp);

 elsif p_code='common_nenneke_nonlethal_steal' then
  select mc.id into v_id from public.match_cards mc where mc.match_id=p_match_id and mc.owner_user_id=opp and mc.zone='life' and mc.current_life>=1001 order by random() limit 1;
  if v_id is null then raise exception 'NO_ENEMY_LIFE_CARD_ABOVE_1000';end if;
  update public.match_cards set current_life=current_life-1000 where id=v_id;

  select mc.id into v_id2 from public.match_cards mc where mc.match_id=p_match_id and mc.owner_user_id=p_actor and mc.zone='life' and mc.current_life>0 order by random() limit 1;
  if v_id2 is not null then
   update public.match_cards set current_life=current_life+1000,maximum_life=greatest(maximum_life,current_life+1000) where id=v_id2;
  end if;
  return jsonb_build_object('reduced_enemy_life_id',v_id,'healed_friendly_life_id',v_id2,'life_transferred',1000);

 elsif p_code='common_carpeado_zero_hand_costs' then
  update public.match_cards set metadata=metadata||jsonb_build_object('previous_mana_cost_delta',coalesce((metadata->>'mana_cost_delta')::integer,0),'mana_cost_delta',-game_private.effect_card_cost(id)) where match_id=p_match_id and zone='hand';
  get diagnostics v_count=row_count;
  insert into public.match_runtime_effects(match_id,owner_user_id,source_match_card_id,effect_code,scope,payload,starts_on_turn)
   values(p_match_id,p_actor,p_source,p_code,'match',jsonb_build_object('restore_on_each_next_turn',true),v_turn);
  return jsonb_build_object('zeroed_hand_cards',v_count);

 elsif p_code='common_marlene_transform' then
  select mc.zone into v_zone from public.match_cards mc where mc.id=p_source;
  if v_zone not in('hand','life') then raise exception 'MARLENE_ZONE_MUST_BE_HAND_OR_LIFE';end if;
  select mc.* into t from public.match_cards mc join public.match_deck_cards d on d.id=mc.match_deck_card_id where mc.match_id=p_match_id and mc.owner_user_id=opp and mc.zone='graveyard' and d.element='Bestiário' order by random() limit 1;
  if not found then raise exception 'NO_OPPONENT_BESTIARY_IN_GRAVEYARD';end if;
  update public.match_cards set source_card_id=t.source_card_id,match_deck_card_id=t.match_deck_card_id,base_power=t.base_power,maximum_power=t.maximum_power,current_power=t.maximum_power,base_max_life=t.base_max_life,maximum_life=t.maximum_life,current_life=t.maximum_life,metadata=metadata||jsonb_build_object('transformed_from',p_source) where id=p_source;
  return jsonb_build_object('transformed_to_match_deck_card_id',t.match_deck_card_id);

 elsif p_code='common_anna_increase_hand_costs' then
  update public.match_cards set metadata=jsonb_set(metadata,'{mana_cost_delta}',to_jsonb(coalesce((metadata->>'mana_cost_delta')::integer,0)+1)) where match_id=p_match_id and zone='hand';
  get diagnostics v_count=row_count;
  return jsonb_build_object('affected_hand_cards',v_count,'mana_cost_delta',+1);

 elsif p_code='common_morkvarg_curse_hand' then
  if p_event->>'old_zone'<>'reinforcement' then raise exception 'MORKVARG_MUST_DIE_AS_REINFORCEMENT';end if;
  select count(*) into v_count from public.match_cards mc join public.match_deck_cards d on d.id=mc.match_deck_card_id where mc.match_id=p_match_id and mc.owner_user_id=opp and mc.zone='hand' and d.card_name='Morkvarg';
  if v_count<4 then
   update public.match_cards set owner_user_id=opp,controller_user_id=opp,zone='hand',zone_position=99,is_face_up=false,is_destroyed=false,current_life=1,metadata=metadata||'{"hand_locked":true,"unplayable":true}'::jsonb where id=p_source;
   return jsonb_build_object('morkvarg_cursed_hand',true,'target_user_id',opp,'morkvarg_count',v_count+1);
  else
   perform game_private.move_card_checked(p_source,'graveyard',null,true);
   return jsonb_build_object('morkvarg_limit_reached',true,'sent_to_graveyard',true);
  end if;

 elsif p_code='common_udalryk_discard_coin_life' then
  select mc.id into v_id from public.match_cards mc where mc.match_id=p_match_id and mc.owner_user_id=opp and mc.zone='hand' order by random() limit 1;
  if v_id is null then raise exception 'OPPONENT_HAND_EMPTY';end if;
  perform game_private.move_card_checked(v_id,'graveyard',null,true);

  v_roll:=floor(random()*100)+1;
  if v_roll<=35 then
   select mc.id,mc.zone_position into v_id2,v_slot from public.match_cards mc where mc.match_id=p_match_id and mc.owner_user_id=p_actor and mc.zone='life' and mc.current_life>0 order by random() limit 1;
   if v_id2 is not null then
    perform game_private.move_card_checked(v_id2,'graveyard',null,true);
    update public.match_cards set zone='life',zone_position=v_slot,is_face_up=true,is_destroyed=false,current_life=maximum_life where id=p_source;
   end if;
   return jsonb_build_object('discarded_opponent_hand',v_id,'roll',v_roll,'backfire',true,'replaced_life_card_id',v_id2);
  else
   return jsonb_build_object('discarded_opponent_hand',v_id,'roll',v_roll,'backfire',false);
  end if;

 elsif p_code='common_ida_peek_deck' then
  select array_agg(mc.id) into v_ids from (
   select mc.id from public.match_cards mc where mc.match_id=p_match_id and mc.owner_user_id=opp and mc.zone='deck' order by mc.zone_position asc,mc.created_at asc limit 2
  ) mc;
  if cardinality(v_ids)=0 then raise exception 'OPPONENT_DECK_EMPTY';end if;
  foreach v_id in array v_ids loop
   insert into public.match_private_reveals(match_id,viewer_user_id,source_match_card_id,revealed_match_card_id,reveal_type)
   values(p_match_id,p_actor,p_source,v_id,'opponent_deck');
  end loop;
  return jsonb_build_object('private_reveal_created',true,'revealed_match_card_ids',v_ids,'viewer_user_id',p_actor);

 elsif p_code='common_arena_master_destroy_life' then
  if exists(select 1 from public.match_cards mc where mc.match_id=p_match_id and mc.controller_user_id=opp and mc.zone='reinforcement' and mc.current_life>0) then
   raise exception 'ENEMY_HAS_REINFORCEMENTS';
  end if;
  select mc.id into v_id from public.match_cards mc join public.match_deck_cards d on d.id=mc.match_deck_card_id where mc.match_id=p_match_id and mc.controller_user_id=opp and mc.zone='life' and mc.current_life>0 and d.rarity='common' order by random() limit 1;
  if v_id is null then raise exception 'NO_ELIGIBLE_COMMON_LIFE_CARD';end if;
  v_damage:=game_private.apply_damage_internal(p_match_id,v_id,20000,v_turn);
  return jsonb_build_object('destroyed_common_life_card_id',v_id,'damage_result',v_damage);

 elsif p_code='common_mabel_destroy_witcher' then
  select mc.id into v_id from public.match_cards mc join public.match_deck_cards d on d.id=mc.match_deck_card_id where mc.match_id=p_match_id and mc.controller_user_id=opp and mc.zone in('life','reinforcement','attacker','leader') and mc.current_life>0 and (d.element='Witcher' or d.card_name ilike '%witcher%') order by random() limit 1;
  if v_id is null then raise exception 'NO_ELIGIBLE_WITCHER_ON_FIELD';end if;
  v_damage:=game_private.apply_damage_internal(p_match_id,v_id,20000,v_turn);
  return jsonb_build_object('destroyed_witcher_card_id',v_id,'damage_result',v_damage);

 end if;

 return game_private.execute_common_effect_internal_v27_core(p_match_id,p_actor,p_source,p_code,p_params,p_target,p_event);
end $$;

-- Atualização de activate_card_effect_v2 com suporte a cálculo dinâmico de mana para Ciri criança
create or replace function public.activate_card_effect_v2(p_match_id uuid,p_source_card_id uuid,p_effect_order integer default 1,p_target_card_id uuid default null,p_expected_version bigint default 0)
returns jsonb language plpgsql security definer set search_path='' as $$
declare actor uuid:=game_private.require_authenticated();src public.match_cards;def jsonb;code text;params jsonb;trig text;reaction boolean;cost integer;result jsonb;new_version bigint;v_witchers integer;
begin
 select * into src from game_private.assert_common_effect_source(p_match_id,actor,p_source_card_id,p_expected_version,true);
 select x into def from public.match_deck_cards d cross join lateral jsonb_array_elements(d.effect_definition) x where d.id=src.match_deck_card_id and (x->>'effect_order')::integer=p_effect_order;
 if def is null then raise exception 'EFFECT_NOT_FOUND';end if;
 code:=def->>'effect_code';if code not like 'common_%' then return public.activate_match_effect(p_match_id,p_source_card_id,p_effect_order,p_target_card_id,p_expected_version);end if;
 perform game_private.assert_no_global_effect_lock(p_match_id,actor,p_source_card_id);
 trig:=def->>'trigger_type';reaction:=coalesce((def->>'is_reaction')::boolean,false);
 if trig not in('manual','reaction') then raise exception 'EFFECT_IS_AUTOMATIC: %',trig;end if;
 if reaction and (select active_player_id from public.matches where id=p_match_id)=actor then raise exception 'REACTION_ONLY_ON_OPPONENT_TURN';end if;
 if reaction and not exists(select 1 from public.pending_attacks where match_id=p_match_id and defender_user_id=actor and status='awaiting_reaction') then raise exception 'NO_PENDING_ATTACK_FOR_REACTION';end if;
 if not reaction and (select active_player_id from public.matches where id=p_match_id)<>actor then raise exception 'NOT_YOUR_TURN';end if;
 params:=coalesce(def->'parameters','{}');
 if code='common_child_ciri_attack_all_life' then
  select count(*) into v_witchers from public.match_cards mc join public.match_deck_cards d on d.id=mc.match_deck_card_id where mc.match_id=p_match_id and mc.owner_user_id=actor and mc.zone='deck' and (d.element='Witcher' or d.card_name ilike '%witcher%');
  cost:=greatest(0,15-v_witchers);
 else
  cost:=coalesce((params->>'mana_cost')::integer,game_private.effect_card_cost(p_source_card_id),0);
 end if;
 if coalesce((def->>'once_per_turn')::boolean,false) and exists(select 1 from public.match_effect_uses where match_id=p_match_id and match_card_id=p_source_card_id and effect_order=p_effect_order and turn_number=(select current_turn from public.matches where id=p_match_id)) then raise exception 'EFFECT_ALREADY_USED_THIS_TURN';end if;
 perform game_private.pay_common_effect_cost(p_match_id,actor,cost);
 result:=game_private.execute_common_effect_internal(p_match_id,actor,p_source_card_id,code,params,p_target_card_id,'{}');
 insert into public.match_effect_uses(match_id,match_card_id,actor_user_id,effect_order,turn_number,is_reaction,mana_spent) values(p_match_id,p_source_card_id,actor,p_effect_order,(select current_turn from public.matches where id=p_match_id),reaction,cost);
 new_version:=game_private.record_match_action(p_match_id,actor,'effect_activated',jsonb_build_object('source_card_id',p_source_card_id,'effect_order',p_effect_order,'effect_code',code,'target_card_id',p_target_card_id,'mana_spent',cost,'result',result),'{}',p_expected_version);
 return result||jsonb_build_object('state_version',new_version,'mana_spent',cost);
end $$;
revoke all on function public.activate_card_effect_v2(uuid,uuid,integer,uuid,bigint) from public,anon;
grant execute on function public.activate_card_effect_v2(uuid,uuid,integer,uuid,bigint) to authenticated;

commit;
