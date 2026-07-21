-- Laboratório autoritativo: usa matches/match_cards e os mesmos handlers da Arena.
begin;

alter table public.sandbox_matches add column if not exists card_code text;
alter table public.sandbox_matches add column if not exists effect_code text;
alter table public.sandbox_matches add column if not exists turn_owner text not null default 'player' check(turn_owner in('player','opponent'));
alter table public.sandbox_matches add column if not exists source_zone text;
alter table public.sandbox_matches add column if not exists action_type text;
alter table public.sandbox_matches add column if not exists status text not null default 'waiting_action' check(status in('waiting_action','resolving','review_success','review_failed','finished'));
alter table public.sandbox_matches add column if not exists state_before jsonb;
alter table public.sandbox_matches add column if not exists state_after jsonb;
alter table public.sandbox_matches add column if not exists proof jsonb;
alter table public.sandbox_matches add column if not exists finished_at timestamptz;

create or replace function game_private.lab_snapshot_v20(p_match_id uuid,p_actor uuid)
returns jsonb language sql security definer set search_path='' as $$
 select jsonb_build_object(
  'turn',(select current_turn from public.matches where id=p_match_id),
  'active_player_id',(select active_player_id from public.matches where id=p_match_id),
  'player_mana',(select mana_available from public.match_players where match_id=p_match_id and user_id=p_actor),
  'opponent_mana',(select mana_available from public.match_players where match_id=p_match_id and user_id<>p_actor order by player_number limit 1),
  'cards',coalesce((select jsonb_agg(jsonb_build_object('id',mc.id,'owner_id',mc.owner_user_id,'name',d.card_name,'zone',mc.zone,'position',mc.zone_position,'power',mc.current_power,'life',mc.current_life,'max_life',mc.maximum_life,'rarity',d.rarity,'element',d.element,'mana_cost',greatest(0,d.effect_mana_cost+coalesce((mc.metadata->>'mana_cost_delta')::integer,0)),'destroyed',mc.is_destroyed,'metadata',mc.metadata) order by mc.owner_user_id,mc.zone,mc.zone_position nulls last,mc.id) from public.match_cards mc join public.match_deck_cards d on d.id=mc.match_deck_card_id where mc.match_id=p_match_id),'[]'::jsonb),
  'runtime_effects',coalesce((select jsonb_agg(jsonb_build_object('effect_code',r.effect_code,'active',r.active,'payload',r.payload)) from public.match_runtime_effects r where r.match_id=p_match_id),'[]'::jsonb),
  'private_reveals',coalesce((select count(*) from public.match_private_reveals r where r.match_id=p_match_id and r.viewer_user_id=p_actor),0)
 )
$$;

create or replace function game_private.lab_morph_card_v20(p_match_card_id uuid,p_name text,p_rarity text,p_element text,p_power integer,p_life integer,p_mana integer)
returns void language plpgsql security definer set search_path='' as $$
begin
 update public.match_deck_cards d set card_name=p_name,rarity=p_rarity,element=p_element,base_power=p_power,base_max_life=greatest(1,p_life),effect_mana_cost=greatest(0,p_mana) from public.match_cards mc where mc.id=p_match_card_id and d.id=mc.match_deck_card_id;
 update public.match_cards set base_power=p_power,maximum_power=p_power,current_power=p_power,base_max_life=greatest(1,p_life),maximum_life=greatest(1,p_life),current_life=greatest(1,p_life),is_destroyed=false where id=p_match_card_id;
end $$;

do $$ begin
 if to_regprocedure('public.setup_sandbox_match_v15_core(varchar)') is null then
  alter function public.setup_sandbox_match(varchar) rename to setup_sandbox_match_v15_core;
 end if;
end $$;
revoke all on function public.setup_sandbox_match_v15_core(varchar) from public,anon,authenticated;

create or replace function public.setup_sandbox_match(p_card_id varchar)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_actor uuid:=game_private.require_authenticated();v_bot constant uuid:='00000000-0000-4000-8000-000000000071';v_base jsonb;v_match uuid;v_card public.cards;v_effect public.card_effects;v_source uuid;v_deck_card uuid;v_zone text;v_turn_owner text;v_action text;v_cost integer;v_effects jsonb;v_row record;v_i integer:=0;v_aux uuid;v_objective text;
begin
 select c.* into v_card from public.cards c where c.is_active and (c.id::text=trim(p_card_id) or lower(c.code)=lower(trim(p_card_id)) or lower(c.name)=lower(trim(p_card_id))) order by c.name limit 1;
 if not found then return jsonb_build_object('success',false,'reason','LAB_CARD_NOT_FOUND');end if;
 select e.* into v_effect from public.card_effects e where e.card_id=v_card.id and e.is_active order by e.effect_order limit 1;
 if not found then return jsonb_build_object('success',false,'reason','LAB_EFFECT_NOT_FOUND');end if;
 v_base:=public.setup_sandbox_match_v15_core(v_card.code);if not coalesce((v_base->>'success')::boolean,false) then return v_base;end if;v_match:=(v_base->>'match_id')::uuid;
 select mc.id,mc.match_deck_card_id into v_source,v_deck_card from public.match_cards mc where mc.match_id=v_match and mc.owner_user_id=v_actor and coalesce((mc.metadata->>'sandbox_card')::boolean,false) limit 1 for update;
 select coalesce(jsonb_agg(jsonb_build_object('effect_order',e.effect_order,'trigger_type',e.trigger_type,'effect_code',e.effect_code,'target_mode',e.target_mode,'parameters',e.parameters,'priority',e.priority,'is_reaction',e.is_reaction,'once_per_turn',e.once_per_turn,'is_active',e.is_active) order by e.effect_order),'[]') into v_effects from public.card_effects e where e.card_id=v_card.id and e.is_active;
 update public.match_deck_cards set effect_mana_cost=v_card.effect_mana_cost,effect_definition=v_effects where id=v_deck_card;
 update public.match_cards set metadata=(metadata-'mana_cost_delta')||jsonb_build_object('sandbox_card',true,'lab_test_code',v_card.code),current_power=v_card.base_power,maximum_power=v_card.base_power,base_power=v_card.base_power,current_life=greatest(1,v_card.base_max_life),maximum_life=greatest(1,v_card.base_max_life),base_max_life=greatest(1,v_card.base_max_life),is_destroyed=false,is_face_up=true where id=v_source;
 v_cost:=greatest(0,coalesce((v_effect.parameters->>'mana_cost')::integer,v_card.effect_mana_cost,0));
 v_zone:=case
  when v_card.code='COMMON_000' then 'hand'
  when v_card.code in('COMMON_001','COMMON_020','COMMON_023','COMMON_031','COMMON_064') then 'hand'
  when v_card.code='COMMON_066' then 'deck'
  when v_card.code in('COMMON_002','COMMON_009','COMMON_037','COMMON_054','COMMON_055') then 'life'
  when v_card.code in('COMMON_008','COMMON_010','COMMON_011','COMMON_014','COMMON_016','COMMON_017','COMMON_018','COMMON_019','COMMON_021','COMMON_026','COMMON_027','COMMON_029','COMMON_032','COMMON_033','COMMON_049','COMMON_058','COMMON_067') then 'reinforcement'
  else 'attacker' end;
 v_turn_owner:=case when v_effect.trigger_type in('on_destroyed','reaction','on_reaction','on_attacked','on_damage_received') or v_card.code in('COMMON_020','COMMON_021','COMMON_029','COMMON_066') then 'opponent' else 'player' end;
 v_action:=case
  when v_card.code='COMMON_066' then 'destroy'
  when v_card.code in('COMMON_021','COMMON_029') then 'scripted_opponent_attack'
  when v_effect.trigger_type in('on_destroyed','reaction','on_reaction','on_attacked','on_damage_received') then 'scripted_opponent_attack'
  when v_effect.trigger_type='on_turn_start' then 'advance_turn'
  when v_effect.trigger_type='on_discard' then 'scripted_discard'
  when v_effect.trigger_type='passive' then 'attempt_blocked_action'
  when v_card.code in('COMMON_025','COMMON_041','COMMON_043') then 'scripted_continuation'
  when v_effect.trigger_type like 'on_attack%' then 'declare_attack'
  else 'activate_effect' end;
 update public.match_cards mc set zone='deck',zone_position=1000+q.pos,is_face_up=false,is_destroyed=false from(select x.id,row_number() over(order by x.id) pos from public.match_cards x where x.match_id=v_match and x.owner_user_id=v_actor and x.id<>v_source and x.zone not in('life'))q where mc.id=q.id;
 update public.match_cards set zone=v_zone,zone_position=case when v_zone in('life','reinforcement','attacker') then 1 else null end,is_face_up=v_zone<>'deck',is_destroyed=false where id=v_source;
 update public.match_players set mana_available=v_cost,mana_snapshot=v_cost,mana_spent_this_turn=0,paid_effect_used_this_turn=false,free_effect_used_this_turn=false,setup_finished=true where match_id=v_match and user_id=v_actor;
 update public.matches set status='in_progress',engine_state='turn_action',current_turn=3,active_player_id=case when v_turn_owner='opponent' then v_bot else v_actor end,turn_deadline=clock_timestamp()+interval '30 minutes' where id=v_match;

 -- Condições individuais que alteram quantidades, atributos ou históricos.
 if v_card.code='COMMON_005' then
  update public.match_cards set zone='reinforcement',zone_position=q.pos,is_face_up=true from(select id,row_number()over(order by id)pos from public.match_cards where match_id=v_match and owner_user_id=v_bot and id<>v_source limit 3)q where match_cards.id=q.id;
 elsif v_card.code in('COMMON_006','COMMON_038','COMMON_059') then
  update public.match_cards set zone='graveyard',zone_position=null,is_destroyed=true,current_life=0 where match_id=v_match and owner_user_id=v_bot and zone='reinforcement';
 elsif v_card.code='COMMON_002' then
  update public.match_cards set zone='graveyard',zone_position=null,is_face_up=true,is_destroyed=true,current_life=0 where id=(select id from public.match_cards where match_id=v_match and owner_user_id=v_actor and id<>v_source and zone='deck' order by zone_position limit 1);
 elsif v_card.code='COMMON_003' then
  update public.match_cards set zone='hand',zone_position=null,is_face_up=false where id in(select id from public.match_cards where match_id=v_match and owner_user_id=v_actor and id<>v_source and zone='deck' order by zone_position limit 2);
 elsif v_card.code='COMMON_007' then
  update public.match_cards set zone='graveyard',zone_position=null,is_face_up=true,is_destroyed=true,current_life=0 where id in(select id from public.match_cards where match_id=v_match and owner_user_id=v_actor and id<>v_source order by id limit 5);
 elsif v_card.code='COMMON_010' then
  update public.match_cards set zone='graveyard',zone_position=null,is_face_up=true,is_destroyed=true,current_life=0 where id in(select id from public.match_cards where match_id=v_match and owner_user_id=v_actor and id<>v_source order by id limit 2);
 elsif v_card.code='COMMON_013' then
  select id into v_aux from public.match_cards where match_id=v_match and owner_user_id=v_bot and zone='deck' order by id limit 1;update public.match_cards set zone='graveyard',zone_position=null,is_face_up=true,is_destroyed=true,current_power=2400,maximum_power=2400,current_life=3200,maximum_life=3200 where id=v_aux;
 elsif v_card.code='COMMON_017' then null;
 elsif v_card.code='COMMON_022' then
  update public.match_cards set zone='hand',zone_position=null,is_face_up=false where id in(select id from public.match_cards where match_id=v_match and owner_user_id=v_actor and id<>v_source order by id limit 4);update public.match_cards set zone='deck',zone_position=900+zone_position where match_id=v_match and owner_user_id=v_bot and zone='hand' and id not in(select id from public.match_cards where match_id=v_match and owner_user_id=v_bot and zone='hand' order by id limit 2);
 elsif v_card.code='COMMON_023' then
  update public.match_cards set zone='deck',zone_position=900+coalesce(zone_position,0) where match_id=v_match and owner_user_id=v_actor and zone='hand' and id<>v_source;
 elsif v_card.code='COMMON_024' then
  update public.match_cards set zone='hand',zone_position=null,is_face_up=false where id in(select id from public.match_cards where match_id=v_match and owner_user_id=v_actor and id<>v_source order by id limit 3);
 elsif v_card.code in('COMMON_026','COMMON_057') then
  for v_row in select mc.id,mc.match_deck_card_id from public.match_cards mc where mc.match_id=v_match and mc.owner_user_id=v_actor and mc.id<>v_source and mc.zone='deck' order by mc.zone_position limit case when v_card.code='COMMON_057' then 10 else 1 end loop
   if v_card.code='COMMON_057' then update public.match_deck_cards set source_card_id=v_card.id,card_name=v_card.name,image_url=v_card.image_url,element=v_card.element,rarity=v_card.rarity,base_power=v_card.base_power,base_max_life=v_card.base_max_life,effect_mana_cost=v_card.effect_mana_cost,effect_definition=v_effects where id=v_row.match_deck_card_id;update public.match_cards set source_card_id=v_card.id,base_power=200,maximum_power=200,current_power=200,base_max_life=100,maximum_life=100,current_life=100 where id=v_row.id;end if;
  end loop;
 elsif v_card.code='COMMON_027' then
  update public.match_cards set zone='temporary',zone_position=null where id in(select id from public.match_cards where match_id=v_match and owner_user_id=v_bot and zone='deck' order by zone_position offset 3);
 elsif v_card.code='COMMON_032' then
  update public.match_cards set zone='reinforcement',zone_position=2,is_face_up=true where id=(select id from public.match_cards where match_id=v_match and owner_user_id=v_actor and id<>v_source and zone='deck' order by zone_position limit 1);
 elsif v_card.code='COMMON_033' then
  update public.match_cards set zone='graveyard',zone_position=null,is_destroyed=true,current_life=0,is_face_up=true where id in(select id from public.match_cards where match_id=v_match and owner_user_id=v_actor and id<>v_source order by id limit 3);
 elsif v_card.code='COMMON_042' then
  update public.match_cards set zone='temporary',zone_position=null where id in(select id from public.match_cards where match_id=v_match and owner_user_id=v_bot and zone='deck' order by zone_position offset 2);update public.match_cards set zone='deck',zone_position=900+coalesce(zone_position,0) where id in(select id from public.match_cards where match_id=v_match and owner_user_id=v_actor and zone='temporary' limit 5);
 elsif v_card.code='COMMON_047' then
  update public.match_cards set current_life=500,maximum_life=2500,base_max_life=2500 where id=(select id from public.match_cards where match_id=v_match and owner_user_id=v_actor and zone='life' order by zone_position limit 1);
 elsif v_card.code='COMMON_051' then
  update public.match_cards set current_life=1000,maximum_life=1000,base_max_life=1000 where match_id=v_match and owner_user_id=v_bot and zone='reinforcement';update public.match_cards set zone='temporary',zone_position=null where id in(select id from public.match_cards where match_id=v_match and owner_user_id=v_bot and zone='deck' order by zone_position offset 5);
 elsif v_card.code='COMMON_055' then update public.match_players set passed_turn=true where match_id=v_match and user_id=v_bot;
 elsif v_card.code='COMMON_060' then update public.match_players set destroyed_life_count=1 where match_id=v_match and user_id=v_actor;
 elsif v_card.code='COMMON_062' then
  update public.match_cards set current_life=2500,maximum_life=2500 where id=(select id from public.match_cards where match_id=v_match and owner_user_id=v_bot and zone='life' order by zone_position limit 1);update public.match_cards set current_life=500,maximum_life=2500 where id=(select id from public.match_cards where match_id=v_match and owner_user_id=v_actor and zone='life' order by zone_position limit 1);
 elsif v_card.code='COMMON_070' then update public.match_cards set zone='graveyard',zone_position=null,is_destroyed=true,current_life=0 where match_id=v_match and owner_user_id=v_bot and zone='reinforcement';
 end if;
 -- Peças auxiliares individualizadas: snapshots locais, sem tocar no catálogo.
 if v_card.code in('COMMON_004','COMMON_012','COMMON_024','COMMON_031','COMMON_043','COMMON_048','COMMON_063','COMMON_065') then update public.match_cards set zone='hand',zone_position=null,is_face_up=false where id in(select id from public.match_cards where match_id=v_match and owner_user_id=v_actor and id<>v_source and zone='deck' order by zone_position limit case when v_card.code='COMMON_024' then 3 else 2 end);end if;
 if v_card.code in('COMMON_004','COMMON_008','COMMON_016','COMMON_020','COMMON_039','COMMON_048','COMMON_050','COMMON_061','COMMON_063','COMMON_065','COMMON_068') then update public.match_cards set zone='hand',zone_position=null,is_face_up=false where id in(select id from public.match_cards where match_id=v_match and owner_user_id=v_bot and zone='deck' order by zone_position limit 3);end if;
 if v_card.code='COMMON_011' then select id into v_aux from public.match_cards where match_id=v_match and owner_user_id=v_bot and zone='deck' order by zone_position limit 1;perform game_private.lab_morph_card_v20(v_aux,'Executor M&F','rare','M&F',3000,1800,0);end if;
 if v_card.code='COMMON_010' then for v_aux in select id from public.match_cards where match_id=v_match and owner_user_id=v_actor and zone='graveyard' order by id limit 2 loop perform game_private.lab_morph_card_v20(v_aux,v_card.name,'common','Bestiário',900,1,0);update public.match_cards set zone='graveyard',is_destroyed=true,current_life=0 where id=v_aux;end loop;end if;
 if v_card.code='COMMON_015' then select id into v_aux from public.match_cards where match_id=v_match and owner_user_id=v_bot and zone='life' order by zone_position limit 1;perform game_private.lab_morph_card_v20(v_aux,'Lendária de Prova','legendary','Cívil',900,1500,4);end if;
 if v_card.code='COMMON_018' then select id into v_aux from public.match_cards where match_id=v_match and owner_user_id=v_actor and zone='life' order by zone_position limit 1;update public.match_cards set current_life=500,maximum_life=1500,base_max_life=1500 where id=v_aux;end if;
 if v_card.code='COMMON_021' then select id into v_aux from public.match_cards where match_id=v_match and owner_user_id=v_actor and zone='deck' order by zone_position limit 1;perform game_private.lab_morph_card_v20(v_aux,'Épica Tutelada','epic','Cívil',1400,1800,3);end if;
 if v_card.code='COMMON_026' then select id into v_aux from public.match_cards where match_id=v_match and owner_user_id=v_actor and zone='deck' and id<>v_source order by zone_position limit 1;perform game_private.lab_morph_card_v20(v_aux,'Nekker','common','Bestiário',1000,2500,2);end if;
 if v_card.code='COMMON_028' then for v_aux in select id from public.match_cards where match_id=v_match and owner_user_id=v_actor and zone='deck' order by zone_position limit 2 loop perform game_private.lab_morph_card_v20(v_aux,'Lobo','common','Bestiário',1000,1,0);end loop;end if;
 if v_card.code='COMMON_029' then select id into v_aux from public.match_cards where match_id=v_match and owner_user_id=v_actor and zone='life' order by zone_position limit 1;update public.match_cards set current_life=1000,maximum_life=1000,base_max_life=1000 where id=v_aux;end if;
 if v_card.code='COMMON_030' then select id into v_aux from public.match_cards where match_id=v_match and owner_user_id=v_bot and zone='life' order by zone_position limit 1;perform game_private.lab_morph_card_v20(v_aux,'Elfica de Prova','common','Elfica',1200,1800,3);end if;
 if v_card.code='COMMON_033' then for v_aux in select id from public.match_cards where match_id=v_match and owner_user_id=v_actor and zone='graveyard' order by id limit 3 loop perform game_private.lab_morph_card_v20(v_aux,'Totem','common','Cívil',0,1,0);end loop;select id into v_aux from public.match_cards where match_id=v_match and owner_user_id=v_actor and zone='deck' order by zone_position limit 1;perform game_private.lab_morph_card_v20(v_aux,'Liche','common','M&F',1300,1300,3);
  update public.match_cards set is_destroyed=true,current_life=0 where match_id=v_match and owner_user_id=v_actor and zone='graveyard';
 end if;
 if v_card.code='COMMON_034' then for v_row in select id from public.match_cards where match_id=v_match and owner_user_id=v_actor and zone='deck' order by zone_position limit 3 loop v_i:=v_i+1;perform game_private.lab_morph_card_v20(v_row.id,'Custo de Prova '||v_i,'common','Cívil',800,1200,case v_i when 1 then 1 when 2 then 2 else 4 end);end loop;end if;
 if v_card.code='COMMON_032' then select id into v_aux from public.match_cards where match_id=v_match and owner_user_id=v_actor and zone='reinforcement' and id<>v_source order by zone_position limit 1;perform game_private.lab_morph_card_v20(v_aux,'Civil de Escolta','common','Cívil',700,900,0);end if;
 if v_card.code='COMMON_035' then select id into v_aux from public.match_cards where match_id=v_match and owner_user_id=v_actor and zone='deck' order by zone_position limit 1;perform game_private.lab_morph_card_v20(v_aux,'Anão de Prova','common','Cívil',2200,1300,0);select id into v_aux from public.match_cards where match_id=v_match and owner_user_id=v_bot and zone='life' order by current_life,zone_position limit 1;update public.match_cards set current_life=1000,maximum_life=1000,base_max_life=1000 where id=v_aux;end if;
 if v_card.code='COMMON_036' then select id into v_aux from public.match_cards where match_id=v_match and owner_user_id=v_actor and zone='deck' order by zone_position limit 1;perform game_private.lab_morph_card_v20(v_aux,'Rara Escolhível','rare','Cívil',1300,1700,3);end if;
 if v_card.code='COMMON_037' then select id into v_aux from public.match_cards where match_id=v_match and owner_user_id=v_bot and zone='attacker' order by id limit 1;if v_aux is null then select id into v_aux from public.match_cards where match_id=v_match and owner_user_id=v_bot and zone='deck' order by zone_position limit 1;update public.match_cards set zone='attacker',zone_position=1,is_face_up=true where id=v_aux;end if;perform game_private.lab_morph_card_v20(v_aux,'Lendária Bloqueada','legendary','Cívil',1800,2200,4);end if;
 if v_card.code='COMMON_045' then for v_row in select id from public.match_cards where match_id=v_match and owner_user_id=v_actor and zone='deck' order by zone_position limit 3 loop v_i:=v_i+1;perform game_private.lab_morph_card_v20(v_row.id,'M&F Custo '||v_i,'common','M&F',800+v_i*100,1200,v_i*2-1);end loop;end if;
 if v_card.code='COMMON_046' then select id into v_aux from public.match_cards where match_id=v_match and owner_user_id=v_bot and zone='reinforcement' order by zone_position limit 1;perform game_private.lab_morph_card_v20(v_aux,'Witcher de Prova','common','Witcher',500,1000,1);end if;
 if v_card.code='COMMON_049' then select id into v_aux from public.match_cards where match_id=v_match and owner_user_id=v_actor and zone='deck' order by zone_position limit 1;perform game_private.lab_morph_card_v20(v_aux,'M&F Protegida','common','M&F',1300,1700,4);end if;
 if v_card.code='COMMON_048' then for v_aux in select id from public.match_cards where match_id=v_match and owner_user_id=v_actor and zone='hand' and id<>v_source loop update public.match_deck_cards d set effect_mana_cost=0 from public.match_cards mc where mc.id=v_aux and d.id=mc.match_deck_card_id;update public.match_cards set metadata=metadata-'mana_cost_delta' where id=v_aux;end loop;end if;
 if v_card.code='COMMON_054' then select id into v_aux from public.match_cards where match_id=v_match and owner_user_id=v_actor and zone='deck' order by zone_position limit 1;perform game_private.lab_morph_card_v20(v_aux,'Épica Revivida','epic','Vampiro',1600,1900,4);update public.match_cards set zone='graveyard',zone_position=null,is_face_up=true,is_destroyed=true,current_life=0 where id=v_aux;end if;
 if v_card.code='COMMON_053' then
  select id into v_aux from public.match_cards where match_id=v_match and owner_user_id=v_actor and zone='life' order by zone_position limit 1;perform game_private.lab_morph_card_v20(v_aux,'Vida Épica Aliada','epic','Cívil',1100,1900,3);
  select id into v_aux from public.match_cards where match_id=v_match and owner_user_id=v_bot and zone='life' order by zone_position limit 1;perform game_private.lab_morph_card_v20(v_aux,'Vida Lendária Rival','legendary','Cívil',1200,2100,4);
  select id into v_aux from public.match_cards where match_id=v_match and owner_user_id=v_actor and zone='deck' order by zone_position limit 1;perform game_private.lab_morph_card_v20(v_aux,'Comum Substituta Aliada','common','Cívil',700,1300,0);
  select id into v_aux from public.match_cards where match_id=v_match and owner_user_id=v_bot and zone='deck' order by zone_position limit 1;perform game_private.lab_morph_card_v20(v_aux,'Comum Substituta Rival','common','Cívil',750,1350,0);
 end if;
 if v_card.code='COMMON_056' then select id into v_aux from public.match_cards where match_id=v_match and owner_user_id=v_actor and zone='life' order by zone_position limit 1;perform game_private.lab_morph_card_v20(v_aux,'Vida Bestiário','common','Bestiário',600,1800,0);end if;
 if v_card.code='COMMON_058' then select id into v_aux from public.match_cards where match_id=v_match and owner_user_id=v_actor and zone='deck' order by zone_position limit 1;perform game_private.lab_morph_card_v20(v_aux,'Chorabashe','common','Bestiário',900,1400,2);end if;
 if v_card.code='COMMON_059' then for v_row in select id from public.match_cards where match_id=v_match and owner_user_id=v_actor and zone='deck' order by zone_position limit 10 loop perform game_private.lab_morph_card_v20(v_row.id,'Witcher de Desconto','common','Witcher',800,1200,0);end loop;update public.match_players set mana_available=5,mana_snapshot=5 where match_id=v_match and user_id=v_actor;end if;
 if v_card.code='COMMON_061' then for v_row in select id from public.match_cards where match_id=v_match and owner_user_id=v_bot and zone='hand' order by id limit 3 loop v_i:=v_i+1;perform game_private.lab_morph_card_v20(v_row.id,'Carta Rival Custo '||v_i,'common','Cívil',900,1300,case when v_i=3 then 5 else v_i end);end loop;end if;
 if v_card.code='COMMON_064' then select id into v_aux from public.match_cards where match_id=v_match and owner_user_id=v_bot and zone='deck' order by zone_position limit 1;perform game_private.lab_morph_card_v20(v_aux,'Bestiário Copiado','rare','Bestiário',1800,2600,3);update public.match_cards set zone='graveyard',zone_position=null,is_face_up=true,is_destroyed=true,current_life=0 where id=v_aux;end if;
 if v_card.code='COMMON_066' then select id into v_aux from public.match_cards where match_id=v_match and owner_user_id=v_actor and zone='life' order by zone_position limit 1;perform game_private.lab_morph_card_v20(v_aux,'Ciri de Prova','rare','Witcher',1600,2200,3);end if;
 if v_card.code='COMMON_071' then select id into v_aux from public.match_cards where match_id=v_match and owner_user_id=v_bot and zone='life' order by zone_position limit 1;perform game_private.lab_morph_card_v20(v_aux,'Witcher Alvo','common','Witcher',1200,1700,2);end if;
 -- Passivas precisam estar presentes antes da tentativa observável; a regra
 -- continua sendo aplicada pelos mesmos guards/transitions usados no duelo.
 if v_card.code in('COMMON_000','COMMON_002','COMMON_066') then
  perform game_private.execute_common_effect_internal(v_match,v_actor,v_source,v_effect.effect_code,coalesce(v_effect.parameters,'{}'::jsonb),null,jsonb_build_object('sandbox_setup',true));
 end if;
 v_objective:=v_card.effect_text;
 update public.sandbox_matches set card_code=v_card.code,effect_code=v_effect.effect_code,turn_owner=v_turn_owner,source_zone=v_zone,action_type=v_action,status='waiting_action',objective=v_objective,state_before=game_private.lab_snapshot_v20(v_match,v_actor),state_after=null,proof=null where match_id=v_match;
 perform game_private.recalculate_match_public_state(v_match);
 return jsonb_build_object('success',true,'match_id',v_match,'card_id',v_card.id,'card_code',v_card.code,'effect_code',v_effect.effect_code,'turn_owner',v_turn_owner,'source_zone',v_zone,'action_type',v_action,'objective',v_objective);
exception when others then return jsonb_build_object('success',false,'reason',sqlerrm,'error_code',sqlstate);end $$;

create or replace function public.begin_sandbox_opponent_action(p_match_id uuid)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_actor uuid:=game_private.require_authenticated();v_lab public.sandbox_matches;v_source public.match_cards;v_bot uuid;v_attacker uuid;v_pending uuid;v_version bigint;v_aux uuid;v_event bigint;
begin
 select s.* into v_lab from public.sandbox_matches s where s.match_id=p_match_id and s.owner_user_id=v_actor for update;if not found then raise exception 'LAB_MATCH_NOT_FOUND';end if;
 if v_lab.status<>'waiting_action' or v_lab.action_type not in('scripted_opponent_attack','scripted_discard','attempt_blocked_action','advance_turn','destroy','scripted_continuation') then raise exception 'LAB_SCRIPTED_ACTION_NOT_AVAILABLE';end if;
 select * into v_source from public.match_cards where match_id=p_match_id and owner_user_id=v_actor and coalesce((metadata->>'sandbox_card')::boolean,false) limit 1 for update;
 select user_id into v_bot from public.match_players where match_id=p_match_id and user_id<>v_actor order by player_number limit 1;
 if v_lab.action_type='scripted_discard' then
  perform game_private.move_card_checked(v_source.id,'graveyard',null,true);v_version:=game_private.record_match_action(p_match_id,v_bot,'sandbox_scripted_discard',jsonb_build_object('target_card_id',v_source.id,'effect_code',v_lab.effect_code),'{}',0);perform game_private.recalculate_match_public_state(p_match_id);return jsonb_build_object('success',true,'event','scripted_discard','state_version',v_version);
 elsif v_lab.action_type='attempt_blocked_action' and v_lab.card_code='COMMON_000' then
  begin perform game_private.draw_internal(p_match_id,v_actor,1);exception when others then update public.sandbox_matches set proof=jsonb_build_object('blocked_sqlstate',sqlstate,'blocked_message',sqlerrm,'expected','DRAW_BLOCKED_BY_COMMON_000') where match_id=p_match_id;return jsonb_build_object('success',true,'event','draw_blocked','sqlstate',sqlstate,'message',sqlerrm);end;
  update public.sandbox_matches set proof=jsonb_build_object('expected','DRAW_WAS_NOT_BLOCKED') where match_id=p_match_id;return jsonb_build_object('success',false,'event','draw_was_not_blocked');
 elsif v_lab.action_type='attempt_blocked_action' and v_lab.card_code='COMMON_002' then
  select id into v_aux from public.match_cards where match_id=p_match_id and owner_user_id=v_actor and zone='graveyard' order by id limit 1;
  begin perform game_private.move_card_checked(v_aux,'hand',null,false);exception when others then update public.sandbox_matches set proof=jsonb_build_object('blocked_sqlstate',sqlstate,'blocked_message',sqlerrm,'expected','GRAVEYARD_RETURN_BLOCKED') where match_id=p_match_id;return jsonb_build_object('success',true,'event','graveyard_return_blocked','sqlstate',sqlstate,'message',sqlerrm);end;
  update public.sandbox_matches set proof=jsonb_build_object('expected','GRAVEYARD_RETURN_WAS_NOT_BLOCKED') where match_id=p_match_id;return jsonb_build_object('success',false,'event','graveyard_return_was_not_blocked');
 elsif v_lab.action_type='scripted_continuation' and v_lab.card_code in('COMMON_025','COMMON_043') then
  if not exists(select 1 from public.match_runtime_effects r where r.match_id=p_match_id and r.owner_user_id=v_actor and r.effect_code=v_lab.effect_code) then raise exception 'ACTIVATE_CARD_EFFECT_BEFORE_CONTINUATION';end if;
  perform game_private.draw_internal(p_match_id,v_actor,1);perform game_private.recalculate_match_public_state(p_match_id);
  return jsonb_build_object('success',true,'event','scripted_followup_draw');
 elsif v_lab.action_type='scripted_continuation' and v_lab.card_code='COMMON_041' then
  select p.id into v_aux from public.pending_effect_choices p where p.match_id=p_match_id and p.actor_user_id=v_bot and p.status='pending' order by p.created_at limit 1 for update;
  if v_aux is null then raise exception 'ACTIVATE_VIVALDI_BEFORE_OPPONENT_CHOICE';end if;
  update public.match_cards set zone='hand',zone_position=null,is_face_up=false,metadata=jsonb_set(metadata,'{mana_cost_delta}',to_jsonb(coalesce((metadata->>'mana_cost_delta')::integer,0)+2))
  where id=(select candidate_ids[1] from public.pending_effect_choices where id=v_aux) and match_id=p_match_id and owner_user_id=v_bot and zone='deck';
  update public.pending_effect_choices set status='resolved' where id=v_aux;
  v_version:=game_private.record_match_action(p_match_id,v_bot,'effect_choice_resolved',jsonb_build_object('choice_id',v_aux,'effect_code',v_lab.effect_code,'sandbox_prepared_choice',true),'{}',0);
  perform game_private.recalculate_match_public_state(p_match_id);return jsonb_build_object('success',true,'event','opponent_choice_resolved','state_version',v_version);
 elsif v_lab.action_type='advance_turn' then
  v_event:=game_private.queue_match_effect_event(p_match_id,'on_turn_start',v_actor,v_source.id,null,jsonb_build_object('sandbox',true));perform game_private.process_one_effect_event(v_event);perform game_private.recalculate_match_public_state(p_match_id);return jsonb_build_object('success',true,'event','turn_start_triggered','event_id',v_event);
 elsif v_lab.action_type='destroy' and v_lab.card_code='COMMON_066' then
  select mc.id into v_aux from public.match_cards mc join public.match_deck_cards d on d.id=mc.match_deck_card_id where mc.match_id=p_match_id and mc.owner_user_id=v_actor and mc.zone in('life','reinforcement','attacker') and d.card_name like '%Ciri%' order by mc.id limit 1;perform game_private.apply_damage_internal(p_match_id,v_aux,20000,(select current_turn from public.matches where id=p_match_id));perform game_private.recalculate_match_public_state(p_match_id);return jsonb_build_object('success',true,'event','ciri_destruction_attempted','target_card_id',v_aux);
 end if;
 select id into v_attacker from public.match_cards where match_id=p_match_id and owner_user_id=v_bot and zone='deck' order by zone_position limit 1 for update;
 update public.match_cards set zone='attacker',zone_position=1,is_face_up=true,
  current_power=case when v_lab.card_code='COMMON_019' then greatest(6000,v_source.maximum_life*3) else greatest(2500,v_source.maximum_life+500) end,
  maximum_power=case when v_lab.card_code='COMMON_019' then greatest(6000,v_source.maximum_life*3) else greatest(2500,v_source.maximum_life+500) end,
  base_power=case when v_lab.card_code='COMMON_019' then greatest(6000,v_source.maximum_life*3) else greatest(2500,v_source.maximum_life+500) end where id=v_attacker;
 update public.sandbox_matches set status='resolving' where match_id=p_match_id;
 if v_lab.effect_code in('common_elemental_prevent_damage','common_gargoyle_cancel_single_attack','common_baltazar_cancel_direct') then
  insert into public.pending_attacks(match_id,attacker_user_id,defender_user_id,status,is_direct,declared_power,reaction_deadline,declared_state_version,result) values(p_match_id,v_bot,v_actor,'awaiting_reaction',v_lab.effect_code='common_baltazar_cancel_direct',(select current_power from public.match_cards where id=v_attacker),clock_timestamp()+interval '5 minutes',(select state_version from public.matches where id=p_match_id),jsonb_build_object('sandbox',true)) returning id into v_pending;
  insert into public.pending_attack_cards(pending_attack_id,match_card_id,attack_position,power_when_declared) select v_pending,v_attacker,1,current_power from public.match_cards where id=v_attacker;
  update public.matches set engine_state='reaction_window' where id=p_match_id;
  return jsonb_build_object('success',true,'pending_attack_id',v_pending,'event','reaction_window_opened');
 end if;
 if v_lab.card_code in('COMMON_021','COMMON_029') then
  perform game_private.apply_damage_internal(p_match_id,v_source.id,500,(select current_turn from public.matches where id=p_match_id));
  v_event:=game_private.queue_match_effect_event(p_match_id,'on_attack_resolved',v_bot,v_source.id,v_attacker,jsonb_build_object('sandbox',true,'target_survived',true,'damage',500));
  perform game_private.process_one_effect_event(v_event);
 elsif v_lab.card_code='COMMON_032' then
  for v_aux in select id from public.match_cards where match_id=p_match_id and owner_user_id=v_actor and zone='reinforcement' order by zone_position limit 2 loop
   perform game_private.apply_damage_internal(p_match_id,v_aux,20000,(select current_turn from public.matches where id=p_match_id));
  end loop;
 else
  perform game_private.apply_damage_internal(p_match_id,v_source.id,case when v_lab.card_code='COMMON_019' then greatest(6000,v_source.maximum_life*3) else greatest(2500,v_source.maximum_life+500) end,(select current_turn from public.matches where id=p_match_id));
 end if;
 v_version:=game_private.record_match_action(p_match_id,v_bot,'sandbox_opponent_attack',jsonb_build_object('attacker_card_id',v_attacker,'target_card_id',v_source.id,'effect_code',v_lab.effect_code,'scripted_outcome',case when v_lab.card_code in('COMMON_021','COMMON_029') then 'survived' when v_lab.card_code='COMMON_032' then 'simultaneous_pair' else 'destroyed' end),'{}',0);
 perform game_private.recalculate_match_public_state(p_match_id);
 return jsonb_build_object('success',true,'event','scripted_opponent_attack','state_version',v_version);
end $$;

create or replace function public.get_sandbox_test_report(p_match_id uuid)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_actor uuid:=game_private.require_authenticated();v_lab public.sandbox_matches;v_after jsonb;v_before jsonb;v_effect_log jsonb;v_success boolean:=false;v_cards_changed boolean;v_runtime_changed boolean;v_reveals_changed boolean;v_effect_logged boolean;v_effect_action boolean;v_attack_action boolean;
begin
 select s.* into v_lab from public.sandbox_matches s where s.match_id=p_match_id and s.owner_user_id=v_actor for update;if not found then raise exception 'LAB_MATCH_NOT_FOUND';end if;
 v_before:=v_lab.state_before;v_after:=game_private.lab_snapshot_v20(p_match_id,v_actor);
 select coalesce(jsonb_agg(jsonb_build_object('effect_code',l.effect_code,'result',l.result,'created_at',l.created_at) order by l.id),'[]') into v_effect_log from public.match_effect_execution_log l where l.match_id=p_match_id and l.effect_code=v_lab.effect_code;
 v_cards_changed:=coalesce(v_before->'cards','[]') is distinct from coalesce(v_after->'cards','[]');
 v_runtime_changed:=coalesce(v_before->'runtime_effects','[]') is distinct from coalesce(v_after->'runtime_effects','[]');
 v_reveals_changed:=coalesce((v_before->>'private_reveals')::integer,0)<>coalesce((v_after->>'private_reveals')::integer,0);
 v_effect_logged:=jsonb_array_length(v_effect_log)>0;
 v_effect_action:=exists(select 1 from public.match_actions a where a.match_id=p_match_id and a.action_type='effect_activated' and a.payload_public->>'effect_code'=v_lab.effect_code);
 v_attack_action:=exists(select 1 from public.match_actions a where a.match_id=p_match_id and a.action_type='attack_resolved');
 -- Sem ELSE permissivo: cada carta declara a natureza mínima da prova aceita.
 v_success:=case v_lab.card_code
  when 'COMMON_000' then coalesce(v_lab.proof->>'expected','')='DRAW_BLOCKED_BY_COMMON_000'
  when 'COMMON_001' then v_effect_logged and v_cards_changed
  when 'COMMON_002' then coalesce(v_lab.proof->>'expected','')='GRAVEYARD_RETURN_BLOCKED'
  when 'COMMON_003' then v_attack_action and v_runtime_changed
  when 'COMMON_004' then v_effect_action and v_cards_changed
  when 'COMMON_005' then v_effect_action and v_cards_changed
  when 'COMMON_006' then v_effect_action and v_cards_changed
  when 'COMMON_007' then v_attack_action and v_cards_changed
  when 'COMMON_008' then v_effect_logged and v_cards_changed
  when 'COMMON_009' then v_effect_logged and v_cards_changed
  when 'COMMON_010' then v_effect_logged and v_cards_changed
  when 'COMMON_011' then v_effect_action and exists(select 1 from public.pending_attacks p where p.match_id=p_match_id and p.result ? 'damage_cancelled_by')
  when 'COMMON_012' then v_effect_action and v_cards_changed
  when 'COMMON_013' then v_effect_action and v_cards_changed
  when 'COMMON_014' then v_effect_action and exists(select 1 from public.pending_attacks p where p.match_id=p_match_id and p.result ? 'damage_cancelled_by')
  when 'COMMON_015' then v_effect_action and v_cards_changed
  when 'COMMON_016' then v_effect_logged and v_cards_changed
  when 'COMMON_017' then v_effect_logged and v_cards_changed
  when 'COMMON_018' then v_effect_logged and v_cards_changed
  when 'COMMON_019' then v_effect_logged and v_cards_changed
  when 'COMMON_020' then v_effect_logged and v_cards_changed
  when 'COMMON_021' then v_effect_logged and v_cards_changed
  when 'COMMON_022' then v_attack_action and v_cards_changed
  when 'COMMON_023' then v_effect_action and v_cards_changed
  when 'COMMON_024' then v_attack_action and v_cards_changed
  when 'COMMON_025' then v_effect_action and v_runtime_changed and v_cards_changed
    and exists(select 1 from public.match_cards mc join public.match_deck_cards d on d.id=mc.match_deck_card_id where mc.match_id=p_match_id and mc.owner_user_id=v_actor and mc.zone='hand' and d.element='Cívil' and mc.current_power>d.base_power)
  when 'COMMON_026' then v_effect_logged and v_runtime_changed
  when 'COMMON_027' then v_effect_logged and v_cards_changed
  when 'COMMON_028' then v_attack_action and v_cards_changed
  when 'COMMON_029' then v_effect_logged and v_cards_changed
  when 'COMMON_030' then v_effect_action and v_cards_changed
  when 'COMMON_031' then v_effect_action and exists(select 1 from public.pending_attacks p where p.match_id=p_match_id and p.result ? 'damage_cancelled_by')
  when 'COMMON_032' then v_effect_logged and v_cards_changed
  when 'COMMON_033' then v_effect_logged and v_cards_changed
  when 'COMMON_034' then v_effect_action and v_cards_changed
  when 'COMMON_035' then v_effect_action and v_cards_changed
    and exists(select 1 from public.match_effect_execution_log l where l.match_id=p_match_id and l.effect_code='common_reynold_forced_dwarf_attack' and coalesce((l.result->'damage'->>'destroyed')::boolean,false))
  when 'COMMON_036' then v_effect_action and v_cards_changed
  when 'COMMON_037' then v_effect_action and v_runtime_changed
  when 'COMMON_038' then v_effect_action and v_cards_changed
  when 'COMMON_039' then v_effect_action and v_runtime_changed
  when 'COMMON_040' then v_effect_action and v_cards_changed
  when 'COMMON_041' then v_effect_action and v_cards_changed
    and not exists(select 1 from public.pending_effect_choices p where p.match_id=p_match_id and p.effect_code='common_vivaldi_mutual_tutor' and p.status='pending')
    and exists(select 1 from public.match_actions a where a.match_id=p_match_id and a.action_type='effect_choice_resolved' and a.payload_public->>'effect_code'='common_vivaldi_mutual_tutor')
  when 'COMMON_042' then v_effect_action and v_cards_changed
  when 'COMMON_043' then v_effect_action and v_runtime_changed and v_cards_changed
  when 'COMMON_044' then v_effect_action and v_runtime_changed and v_cards_changed
  when 'COMMON_045' then v_effect_action and v_cards_changed and exists(select 1 from public.match_cards mc join public.match_deck_cards d on d.id=mc.match_deck_card_id where mc.match_id=p_match_id and mc.owner_user_id=v_actor and mc.zone='hand' and d.card_name='M&F Custo 3')
  when 'COMMON_046' then v_attack_action and v_cards_changed
  when 'COMMON_047' then v_effect_action and v_cards_changed
  when 'COMMON_048' then v_attack_action and v_cards_changed
  when 'COMMON_049' then v_effect_logged and v_runtime_changed
  when 'COMMON_050' then v_effect_action and v_reveals_changed
  when 'COMMON_051' then v_attack_action and v_cards_changed
  when 'COMMON_052' then v_effect_action and v_cards_changed
    and not exists(select 1 from public.match_cards mc join public.match_deck_cards d on d.id=mc.match_deck_card_id where mc.match_id=p_match_id and mc.zone='hand' and d.card_name<>'Aparição Noturna')
  when 'COMMON_053' then v_effect_action and v_cards_changed
    and exists(select 1 from public.match_cards mc join public.match_deck_cards d on d.id=mc.match_deck_card_id where mc.match_id=p_match_id and mc.owner_user_id=v_actor and mc.zone='life' and d.card_name='Comum Substituta Aliada')
    and exists(select 1 from public.match_cards mc join public.match_deck_cards d on d.id=mc.match_deck_card_id where mc.match_id=p_match_id and mc.owner_user_id<>v_actor and mc.zone='life' and d.card_name='Comum Substituta Rival')
  when 'COMMON_054' then v_effect_action and v_cards_changed
  when 'COMMON_055' then v_effect_action and v_cards_changed
  when 'COMMON_056' then v_attack_action and v_cards_changed
  when 'COMMON_057' then v_effect_action and v_attack_action and v_cards_changed
    and not exists(select 1 from public.match_cards mc join public.match_deck_cards d on d.id=mc.match_deck_card_id where mc.match_id=p_match_id and mc.owner_user_id=v_actor and mc.zone='deck' and d.card_name='Harpia')
  when 'COMMON_058' then v_effect_logged and v_cards_changed
  when 'COMMON_059' then v_effect_action and v_cards_changed
  when 'COMMON_060' then v_effect_action and v_cards_changed
  when 'COMMON_061' then v_effect_action and v_cards_changed
  when 'COMMON_062' then v_effect_action and v_cards_changed
  when 'COMMON_063' then v_effect_action and v_cards_changed and v_runtime_changed
  when 'COMMON_064' then v_effect_action and v_cards_changed
  when 'COMMON_065' then v_effect_action and v_cards_changed
  when 'COMMON_066' then v_cards_changed
    and exists(select 1 from public.match_cards mc join public.cards c on c.id=mc.source_card_id where mc.match_id=p_match_id and mc.owner_user_id=v_actor and c.code='COMMON_066' and mc.zone='graveyard')
    and exists(select 1 from public.match_cards mc join public.match_deck_cards d on d.id=mc.match_deck_card_id where mc.match_id=p_match_id and mc.owner_user_id=v_actor and d.card_name like '%Ciri%' and mc.zone='hand')
  when 'COMMON_067' then v_effect_logged and v_cards_changed
  when 'COMMON_068' then v_effect_action and v_cards_changed
  when 'COMMON_069' then v_effect_action and v_reveals_changed
  when 'COMMON_070' then v_effect_action and v_cards_changed
  when 'COMMON_071' then v_effect_action and v_cards_changed
  else false end;
 update public.sandbox_matches set state_after=v_after,proof=jsonb_build_object('prepared_action_proof',v_lab.proof,'effect_execution_log',v_effect_log,'before',v_before,'after',v_after),status=case when v_success then 'review_success' else 'review_failed' end where match_id=p_match_id;
 return jsonb_build_object('success',true,'approved',v_success,'status',case when v_success then 'review_success' else 'review_failed' end,'card_code',v_lab.card_code,'effect_code',v_lab.effect_code,'prepared_action_proof',v_lab.proof,'before',v_before,'after',v_after,'effect_execution_log',v_effect_log);
end $$;

create or replace function public.finish_sandbox_test(p_match_id uuid)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_actor uuid:=game_private.require_authenticated();v_status text;
begin
 update public.sandbox_matches set status='finished',finished_at=clock_timestamp() where match_id=p_match_id and owner_user_id=v_actor and status in('review_success','review_failed') returning status into v_status;
 if v_status is null then raise exception 'LAB_REPORT_MUST_BE_REVIEWED_BEFORE_FINISH';end if;
 update public.matches set status='finished',engine_state='finished',finish_reason='sandbox_test_finished',turn_deadline=null where id=p_match_id;
 return jsonb_build_object('success',true,'status','finished');
end $$;

revoke all on function public.setup_sandbox_match(varchar),public.begin_sandbox_opponent_action(uuid),public.get_sandbox_test_report(uuid),public.finish_sandbox_test(uuid) from public,anon;
grant execute on function public.setup_sandbox_match(varchar),public.begin_sandbox_opponent_action(uuid),public.get_sandbox_test_report(uuid),public.finish_sandbox_test(uuid) to authenticated;
notify pgrst,'reload schema';
commit;
