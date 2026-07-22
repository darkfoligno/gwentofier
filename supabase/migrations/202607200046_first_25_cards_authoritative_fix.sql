-- Lote autoritativo 1/3: fidelidade integral das cartas COMMON_001..COMMON_025.
-- A mesma engine atende Arena PvP, treino contra o Autômato e laboratório.
begin;

-- ---------------------------------------------------------------------------
-- 1. Contrato dos gatilhos. Ataques condicionais passam a ser preparados pelo
-- jogador antes do combate; efeitos verdadeiramente automáticos não abrem um
-- prompt enganoso. Troll e Berseker possuem a mesma mecânica nos dois contextos
-- permitidos: ação própria (ordem 1) e reação defensiva (ordem 2).
-- ---------------------------------------------------------------------------
with contract(code,trigger_type,effect_code,target_mode,parameters,is_reaction,once_per_turn) as (values
 ('COMMON_001','on_discard','common_draw_three_common','none','{"amount":3,"rarity":"common","automatic":true}'::jsonb,false,false),
 ('COMMON_002','passive','common_graveyard_return_lock','none','{"required_zone":"life","persistent_after_activation":true}'::jsonb,false,false),
 ('COMMON_003','passive','common_javali_attack_rules','none','{"require_nonempty_all_common_hand":true,"suppress_reinforcement_reveal":true,"suppress_reinforcement_reaction":true}'::jsonb,false,false),
 ('COMMON_004','manual','common_erinia_exchange','none','{"random_own_discard":true}',false,true),
 ('COMMON_005','manual','common_endriuga_scaled_damage','enemy','{"amount_per_reinforcement":500,"required_target_zone":"life","mana_cost":2}',false,true),
 ('COMMON_006','manual','common_henselt_attack_all_life','none','{"mana_cost":7,"allowed_source_zones":["attacker"],"requires_enemy_reinforcement_count":0,"maximum_targets":3}',false,true),
 ('COMMON_007','manual','common_day_wraith_direct_attack','none','{"mana_cost":2,"allowed_source_zones":["attacker"],"minimum_graveyard_count":5,"ignore_reinforcement":true}',false,true),
 ('COMMON_008','on_destroyed','common_night_wraith_silence_hand','enemy_random','{"required_old_zone":"reinforcement","mana_cost":1}',true,true),
 ('COMMON_009','on_destroyed','common_keira_replace_life','none','{"required_old_zone":"life","rarity":"common","mana_cost":3}',false,true),
 ('COMMON_010','on_destroyed','common_ghoul_group_revive','graveyard','{"required_old_zone":"reinforcement","requires_matching_reinforcement":true,"mana_cost":2}',false,true),
 ('COMMON_011','reaction','common_elemental_prevent_damage','self','{"allowed_source_zones":["life","reinforcement"],"attacker_element":"M&F","mana_cost":3}',true,true),
 ('COMMON_012','manual','common_troll_discard_draw','none','{"allowed_source_zones":["life","reinforcement","attacker"],"draw":2,"mana_cost":2}',false,true),
 ('COMMON_013','manual','common_berserker_copy_stats','none','{"allowed_source_zones":["attacker","reinforcement"]}',false,true),
 ('COMMON_014','reaction','common_gargoyle_cancel_single_attack','self','{"allowed_source_zones":["life","reinforcement"],"attacker_count":1,"mana_cost":2}',true,true),
 ('COMMON_015','manual','common_puero_destroy_random_legendary','none','{"rarity":"legendary","both_sides":true,"mana_cost":3}',false,true),
 ('COMMON_016','on_destroyed','common_necrophage_destroy_hand','enemy_random','{"old_zones":["reinforcement","life"],"requires_attack_damage":true,"power_below_source_life":true,"mana_cost":2}',false,true),
 ('COMMON_017','manual','common_fairy_extra_draw','none','{"allowed_source_zones":["life","reinforcement"],"amount":1,"pay_once":true,"mana_cost":2}',false,true),
 ('COMMON_018','on_destroyed','common_shani_redeploy_life','self','{"required_old_zone":"reinforcement","replace_lower_life":true,"restore_full_life":true,"mana_cost":4}',false,true),
 ('COMMON_019','on_destroyed','common_barghest_overkill_to_deck','self','{"minimum_overkill_ratio":3,"requires_attack_damage":true,"mana_cost":2}',false,true),
 ('COMMON_020','on_discard','common_barroso_purge_enemy_hand','all_enemies','{"automatic":true,"also_trigger_on_stolen_or_destroyed_from_hand":true}',false,false),
 ('COMMON_021','on_attack_resolved','common_atrocious_ghoul_draw_epic','none','{"required_zone":"reinforcement","must_survive":true,"rarity":"epic","mana_cost":3}',false,true),
 ('COMMON_022','manual','common_panther_direct_life','none','{"allowed_source_zones":["attacker"],"requires_hand_advantage":true,"mana_cost":4,"ignore_reinforcement":true}',false,true),
 ('COMMON_023','manual','common_beggar_king_destroy_life','none','{"allowed_source_zones":["hand"],"require_only_card_in_hand":true,"random_enemy_life":true}',false,true),
 ('COMMON_024','manual','common_cleaver_discard_for_direct','enemy','{"allowed_source_zones":["attacker"],"discard_cost":3,"chosen_discard":true,"chosen_enemy_life":true,"ignore_reinforcement":true}',false,true),
 ('COMMON_025','manual','common_lugos_next_civil_double_power','none','{"element":"Cívil","multiplier":2,"inspect_and_draw_top":true}',false,true)
)
update public.card_effects ce set trigger_type=c.trigger_type,effect_code=c.effect_code,target_mode=c.target_mode,
 parameters=c.parameters,is_reaction=c.is_reaction,once_per_turn=c.once_per_turn,is_active=true,updated_at=clock_timestamp()
from contract c join public.cards card on card.code=c.code
where ce.card_id=card.id and ce.effect_order=1;

-- Segunda entrada apenas para as duas cartas que também podem responder durante
-- o turno inimigo. O limite pago/gratuito continua sendo aplicado pelo motor.
insert into public.card_effects(card_id,effect_order,trigger_type,effect_code,target_mode,parameters,priority,is_reaction,once_per_turn,is_active)
select c.id,2,'reaction',x.effect_code,'none',x.parameters,10,true,true,true
from public.cards c cross join lateral (values
 (case c.code when 'COMMON_012' then 'common_troll_discard_draw' when 'COMMON_013' then 'common_berserker_copy_stats' end,
  case c.code when 'COMMON_012' then '{"allowed_source_zones":["life","reinforcement"],"draw":2,"mana_cost":2}'::jsonb
       else '{"allowed_source_zones":["reinforcement"]}'::jsonb end)
) x(effect_code,parameters)
where c.code in('COMMON_012','COMMON_013')
on conflict(card_id,effect_order) do update set trigger_type=excluded.trigger_type,effect_code=excluded.effect_code,
 target_mode=excluded.target_mode,parameters=excluded.parameters,priority=excluded.priority,is_reaction=true,
 once_per_turn=true,is_active=true,updated_at=clock_timestamp();

-- Sincroniza snapshots de partidas já criadas, além das partidas futuras.
update public.match_deck_cards mdc set effect_definition=coalesce((
 select jsonb_agg(jsonb_build_object('effect_order',ce.effect_order,'trigger_type',ce.trigger_type,
  'effect_code',ce.effect_code,'target_mode',ce.target_mode,'parameters',ce.parameters,'priority',ce.priority,
  'is_reaction',ce.is_reaction,'once_per_turn',ce.once_per_turn,'is_active',ce.is_active) order by ce.effect_order)
 from public.card_effects ce where ce.card_id=mdc.source_card_id and ce.is_active
),'[]'::jsonb)
where exists(select 1 from public.cards c where c.id=mdc.source_card_id and c.code between 'COMMON_001' and 'COMMON_025');

-- ---------------------------------------------------------------------------
-- 2. Executor especializado do primeiro lote. O núcleo anterior é preservado
-- para todas as demais cartas.
-- ---------------------------------------------------------------------------
do $$ begin
 if to_regprocedure('game_private.execute_common_effect_internal_v24_core(uuid,uuid,uuid,text,jsonb,uuid,jsonb)') is null then
  alter function game_private.execute_common_effect_internal(uuid,uuid,uuid,text,jsonb,uuid,jsonb)
    rename to execute_common_effect_internal_v24_core;
 end if;
end $$;

-- ---------------------------------------------------------------------------
-- 3. Eventos: preserva a identidade do dono anterior em roubo, transporta o
-- poder bruto do golpe e não oferece gatilhos cuja condição já falhou.
-- ---------------------------------------------------------------------------
create or replace function game_private.v25_trigger_is_eligible(
 p_code text,p_source uuid,p_event jsonb
) returns boolean language plpgsql stable security definer set search_path='' as $$
declare s public.match_cards;v_name text;
begin
 select mc.* into s from public.match_cards mc where mc.id=p_source;
 if not found then return false;end if;
 if p_code='common_night_wraith_silence_hand' then return p_event->>'old_zone'='reinforcement';end if;
 if p_code='common_keira_replace_life' then return p_event->>'old_zone'='life';end if;
 if p_code='common_ghoul_group_revive' then
  select d.card_name into v_name from public.match_deck_cards d where d.id=s.match_deck_card_id;
  return p_event->>'old_zone'='reinforcement' and exists(select 1 from public.match_cards mc join public.match_deck_cards d on d.id=mc.match_deck_card_id where mc.match_id=s.match_id and mc.owner_user_id=s.owner_user_id and mc.zone='reinforcement' and mc.current_life>0 and d.card_name=v_name);
 end if;
 if p_code='common_necrophage_destroy_hand' then return p_event->>'old_zone' in('reinforcement','life') and coalesce((p_event->>'incoming_attack_power')::integer,0)>0;end if;
 if p_code='common_shani_redeploy_life' then return p_event->>'old_zone'='reinforcement' and exists(select 1 from public.match_cards mc where mc.match_id=s.match_id and mc.controller_user_id=s.owner_user_id and mc.zone='life' and mc.current_life>0 and mc.current_life<s.maximum_life);end if;
 if p_code='common_barghest_overkill_to_deck' then return coalesce((p_event->>'incoming_attack_power')::integer,0)>=s.maximum_life*3;end if;
 if p_code='common_atrocious_ghoul_draw_epic' then return s.zone='reinforcement' and s.current_life>0;end if;
 return true;
end $$;

create or replace function game_private.queue_card_zone_events()
returns trigger language plpgsql security definer set search_path='' as $$
declare ev text;actor uuid;chain uuid:=gen_random_uuid();v_code text;v_payload jsonb;
begin
 if pg_trigger_depth()>8 then return new;end if;
 actor:=coalesce((select m.active_player_id from public.matches m where m.id=new.match_id),new.controller_user_id);
 select c.code into v_code from public.cards c where c.id=new.source_card_id;
 if v_code='COMMON_020' and coalesce((new.metadata->>'v25_barroso_resolved')::boolean,false) then return new;end if;
 if old.zone='deck' and new.zone='hand' then ev:='on_draw';
 elsif old.zone='hand' and new.zone='graveyard' then ev:='on_discard';
 elsif old.zone='hand' and new.zone in('life','reinforcement','attacker','leader') then ev:='on_play';
 elsif old.zone in('life','reinforcement','attacker','leader') and new.zone in('graveyard','banished') then ev:='on_destroyed';
 elsif old.is_face_up=false and new.is_face_up=true then ev:='on_revealed';
 elsif v_code='COMMON_020' and old.zone='hand' and new.zone='hand' and old.owner_user_id<>new.owner_user_id then ev:='on_discard';
 end if;
 if ev is not null then
  v_payload:=jsonb_build_object('old_zone',old.zone,'new_zone',new.zone,'old_position',old.zone_position,
   'damage_taken',greatest(0,old.current_life-new.current_life),'incoming_attack_power',coalesce((new.metadata->>'v25_incoming_attack_power')::integer,0),
   'original_owner_user_id',old.owner_user_id,'new_owner_user_id',new.owner_user_id,
   'hand_exit_cause',case when old.owner_user_id<>new.owner_user_id then 'stolen' when new.zone='graveyard' and old.current_life>0 then 'destroyed_or_discarded' else 'zone_change' end);
  perform game_private.queue_match_effect_event(new.match_id,ev,actor,new.id,null,v_payload,chain,0);
 end if;
 return new;
end $$;
drop trigger if exists match_cards_queue_effect_events on public.match_cards;
create trigger match_cards_queue_effect_events after update of zone,is_face_up,current_life,owner_user_id on public.match_cards
for each row when(old is distinct from new) execute function game_private.queue_card_zone_events();

create or replace function game_private.process_one_effect_event(p_event_id bigint)
returns void language plpgsql security definer set search_path='' as $$
declare v_event public.match_effect_events;v_effect record;v_owner uuid;v_cost integer;v_result jsonb;v_turn integer;v_description text;
begin
 select mee.* into v_event from public.match_effect_events mee where mee.id=p_event_id and mee.status='pending' for update skip locked;
 if not found then return;end if;
 update public.match_effect_events set status='processing' where id=v_event.id;
 v_owner:=coalesce(nullif(v_event.payload->>'original_owner_user_id','')::uuid,(select mc.owner_user_id from public.match_cards mc where mc.id=v_event.source_match_card_id));
 select m.current_turn into v_turn from public.matches m where m.id=v_event.match_id;
 for v_effect in select * from game_private.card_snapshot_effects(v_event.source_match_card_id,v_event.event_type) loop
  begin
   if v_effect.once_per_turn and exists(select 1 from public.match_effect_uses meu where meu.match_id=v_event.match_id and meu.match_card_id=v_event.source_match_card_id and meu.effect_order=v_effect.effect_order and meu.turn_number=v_turn) then continue;end if;
   if not game_private.v25_trigger_is_eligible(v_effect.effect_code,v_event.source_match_card_id,v_event.payload) then
    insert into public.match_effect_execution_log(match_id,event_id,source_match_card_id,card_effect_id,effect_code,result)
     values(v_event.match_id,v_event.id,v_event.source_match_card_id,v_effect.effect_id,v_effect.effect_code,jsonb_build_object('skipped',true,'reason','TRIGGER_CONDITION_NOT_MET','event',v_event.payload));
    continue;
   end if;
   v_cost:=greatest(0,coalesce((v_effect.parameters->>'mana_cost')::integer,game_private.effect_card_cost(v_event.source_match_card_id),0));
   select coalesce(c.effect_text,'') into v_description from public.match_cards mc join public.cards c on c.id=mc.source_card_id where mc.id=v_event.source_match_card_id;
   if v_event.event_type='passive' or v_effect.effect_code in('common_draw_three_common','common_barroso_purge_enemy_hand') then
    v_result:=game_private.execute_common_effect_internal(v_event.match_id,v_owner,v_event.source_match_card_id,v_effect.effect_code,v_effect.parameters,v_event.target_match_card_id,v_event.payload);
    insert into public.match_effect_uses(match_id,match_card_id,actor_user_id,effect_order,turn_number,is_reaction,mana_spent)
     values(v_event.match_id,v_event.source_match_card_id,v_owner,v_effect.effect_order,v_turn,v_effect.is_reaction,0) on conflict do nothing;
    insert into public.match_effect_execution_log(match_id,event_id,source_match_card_id,card_effect_id,effect_code,result)
     values(v_event.match_id,v_event.id,v_event.source_match_card_id,v_effect.effect_id,v_effect.effect_code,coalesce(v_result,'{}'::jsonb)||jsonb_build_object('automatic',true));
   else
    insert into public.pending_card_triggers(match_id,owner_user_id,source_match_card_id,event_id,effect_order,effect_code,trigger_type,target_mode,mana_cost,description,event_payload,expected_state_version)
     values(v_event.match_id,v_owner,v_event.source_match_card_id,v_event.id,v_effect.effect_order,v_effect.effect_code,v_event.event_type,v_effect.target_mode,v_cost,v_description,v_event.payload,(select m.state_version from public.matches m where m.id=v_event.match_id))
     on conflict(event_id,effect_order) do nothing;
   end if;
  exception when others then
   insert into public.match_effect_execution_log(match_id,event_id,source_match_card_id,card_effect_id,effect_code,result)
    values(v_event.match_id,v_event.id,v_event.source_match_card_id,v_effect.effect_id,v_effect.effect_code,jsonb_build_object('failed',true,'sqlstate',sqlstate,'message',sqlerrm));
  end;
 end loop;
 update public.match_effect_events set status='resolved',resolved_at=clock_timestamp() where id=v_event.id;
 perform game_private.refresh_match_engine_state(v_event.match_id);
exception when others then
 update public.match_effect_events set status='failed',error_message=sqlstate||': '||sqlerrm,resolved_at=clock_timestamp() where id=p_event_id;
end $$;

-- Duny é armado ao entrar como Vida e permanece ativo durante toda a partida.
create or replace function game_private.activate_duny_life_lock_v25()
returns trigger language plpgsql security definer set search_path='' as $$
begin
 if old.zone is distinct from 'life' and new.zone='life' and exists(select 1 from public.cards c where c.id=new.source_card_id and c.code='COMMON_002')
  and not exists(select 1 from public.match_runtime_effects rt where rt.match_id=new.match_id and rt.effect_code='common_graveyard_return_lock' and rt.active) then
  insert into public.match_runtime_effects(match_id,owner_user_id,source_match_card_id,effect_code,scope,payload,starts_on_turn)
   values(new.match_id,new.owner_user_id,new.id,'common_graveyard_return_lock','match',jsonb_build_object('activated_from_zone','life','persistent',true),(select m.current_turn from public.matches m where m.id=new.match_id));
 end if;
 return new;
end $$;
drop trigger if exists match_cards_activate_duny_v25 on public.match_cards;
create trigger match_cards_activate_duny_v25 after update of zone on public.match_cards for each row execute function game_private.activate_duny_life_lock_v25();
insert into public.match_runtime_effects(match_id,owner_user_id,source_match_card_id,effect_code,scope,payload,starts_on_turn)
select mc.match_id,mc.owner_user_id,mc.id,'common_graveyard_return_lock','match',jsonb_build_object('activated_from_zone','life','persistent',true),m.current_turn
from public.match_cards mc join public.cards c on c.id=mc.source_card_id join public.matches m on m.id=mc.match_id
where c.code='COMMON_002' and mc.zone='life' and mc.current_life>0
 and not exists(select 1 from public.match_runtime_effects rt where rt.match_id=mc.match_id and rt.effect_code='common_graveyard_return_lock' and rt.active);

create or replace function game_private.guard_common_card_movement()
returns trigger language plpgsql security definer set search_path='' as $$
begin
 if old.zone='deck' and new.zone='hand' and exists(select 1 from public.match_cards x join public.match_deck_cards d on d.id=x.match_deck_card_id where x.match_id=old.match_id and x.owner_user_id=old.owner_user_id and x.zone='hand' and d.source_card_id=(select id from public.cards where code='COMMON_000')) then raise exception 'DRAW_BLOCKED_BY_COMMON_000';end if;
 if exists(select 1 from public.match_runtime_effects rt where rt.match_id=old.match_id and rt.effect_code='common_graveyard_return_lock' and rt.active)
  and ((old.zone='graveyard' and new.zone in('hand','life','reinforcement','attacker','leader')) or (old.zone in('life','reinforcement','attacker','leader') and new.zone='hand')) then raise exception 'RETURN_BLOCKED_BY_DUNY';end if;
 if coalesce((old.metadata->>'hand_locked')::boolean,false) and old.zone='hand' and new.zone<>'hand' then
  if new.zone<>'graveyard' or not coalesce((old.metadata->>'allow_overflow_to_graveyard')::boolean,false) then raise exception 'CURSED_HAND_CARD_CANNOT_MOVE';end if;
 end if;
 if coalesce((old.metadata->>'effect_cost_immune')::boolean,false) and (new.metadata->>'mana_cost_delta' is distinct from old.metadata->>'mana_cost_delta' or new.metadata->>'effect_silenced' is distinct from old.metadata->>'effect_silenced') then raise exception 'CARD_EFFECT_AND_COST_ARE_PROTECTED';end if;
 return new;
end $$;

-- Javali não pode sequer sair da mão para ataque se houver carta não comum.
create or replace function game_private.guard_javali_play_v25()
returns trigger language plpgsql security definer set search_path='' as $$
begin
 if old.zone='hand' and new.zone='attacker' and exists(select 1 from public.cards c where c.id=new.source_card_id and c.code='COMMON_003') then
  if exists(select 1 from public.match_cards mc join public.match_deck_cards d on d.id=mc.match_deck_card_id where mc.match_id=old.match_id and mc.owner_user_id=old.owner_user_id and mc.zone='hand' and d.rarity<>'common') then raise exception 'JAVALI_REQUIRES_COMMON_ONLY_HAND';end if;
 end if;
 return new;
end $$;
drop trigger if exists match_cards_guard_javali_play_v25 on public.match_cards;
create trigger match_cards_guard_javali_play_v25 before update of zone on public.match_cards for each row execute function game_private.guard_javali_play_v25();

create or replace function game_private.restore_henselt_power_v25()
returns trigger language plpgsql security definer set search_path='' as $$
begin
 if old.zone='attacker' and new.zone<>'attacker' and old.metadata->>'v25_saved_power' is not null then
  new.current_power:=(old.metadata->>'v25_saved_power')::integer;
  new.metadata:=new.metadata-'v25_skip_normal_attack'-'v25_saved_power';
 end if;
 return new;
end $$;
drop trigger if exists match_cards_restore_henselt_power_v25 on public.match_cards;
create trigger match_cards_restore_henselt_power_v25 before update of zone on public.match_cards for each row execute function game_private.restore_henselt_power_v25();

-- Fada: o custo é pago uma única vez; o saque extra ocorre automaticamente no
-- início de cada turno do dono enquanto a própria instância continuar em campo.
create or replace function game_private.consume_fairy_turn_draw_v25()
returns trigger language plpgsql security definer set search_path='' as $$
declare rt record;v_draw jsonb;
begin
 if new.action_type not in('turn_ended','turn_passed_without_action','turn_passed') then return new;end if;
 for rt in select r.* from public.match_runtime_effects r join public.match_cards mc on mc.id=r.source_match_card_id
  where r.match_id=new.match_id and r.effect_code='common_fairy_extra_draw' and r.active
   and r.owner_user_id=nullif(new.payload_public->>'active_player_id','')::uuid and mc.zone in('life','reinforcement','attacker','leader') and mc.current_life>0 for update of r loop
  v_draw:=game_private.draw_internal(new.match_id,rt.owner_user_id,1);
  insert into public.match_effect_execution_log(match_id,source_match_card_id,effect_code,result)
   values(new.match_id,rt.source_match_card_id,rt.effect_code,jsonb_build_object('automatic_turn_draw',true,'drawn',v_draw,'turn',new.payload_public->>'new_turn'));
 end loop;
 update public.match_runtime_effects r set active=false,consumed_at=clock_timestamp()
  where r.match_id=new.match_id and r.effect_code='common_fairy_extra_draw' and r.active
   and not exists(select 1 from public.match_cards mc where mc.id=r.source_match_card_id and mc.zone in('life','reinforcement','attacker','leader') and mc.current_life>0);
 return new;
end $$;
drop trigger if exists match_actions_fairy_turn_draw_v25 on public.match_actions;
create trigger match_actions_fairy_turn_draw_v25 after insert on public.match_actions for each row execute function game_private.consume_fairy_turn_draw_v25();

-- ---------------------------------------------------------------------------
-- 4. Preparação e declaração de ataque. Aparição, Pantera e Cutelo só recebem
-- ataque direto depois da ativação válida; Henselt não golpeia uma quarta vez.
-- ---------------------------------------------------------------------------
create or replace function game_private.enforce_common_attack_rules()
returns trigger language plpgsql security definer set search_path='' as $$
declare v_attack public.pending_attacks;v_actor uuid;v_code text;v_hand integer;v_common integer;v_power integer;
begin
 select pa.* into v_attack from public.pending_attacks pa where pa.id=new.pending_attack_id for update;
 v_actor:=v_attack.attacker_user_id;
 select c.code into v_code from public.match_cards mc join public.cards c on c.id=mc.source_card_id where mc.id=new.match_card_id;
 if v_code='COMMON_003' then
  select count(*),count(*) filter(where d.rarity='common') into v_hand,v_common from public.match_cards mc join public.match_deck_cards d on d.id=mc.match_deck_card_id where mc.match_id=v_attack.match_id and mc.owner_user_id=v_actor and mc.zone='hand';
  if v_hand=0 or v_hand<>v_common then raise exception 'JAVALI_REQUIRES_NONEMPTY_COMMON_ONLY_HAND';end if;
  update public.pending_attacks set result=coalesce(result,'{}'::jsonb)||jsonb_build_object('suppress_reinforcement_reveal',true,'suppress_reinforcement_reaction',true,'source_card_id',new.match_card_id),reaction_deadline=clock_timestamp() where id=v_attack.id;
 elsif v_code='COMMON_048' then
  if (select count(*) from public.match_cards mc where mc.match_id=v_attack.match_id and mc.owner_user_id=v_actor and mc.zone='hand' and game_private.effect_card_cost(mc.id)>0)=0 then update public.pending_attacks set is_direct=true,result=result||'{"direct_effect":"COMMON_048"}'::jsonb where id=v_attack.id;end if;
 elsif v_code='COMMON_056' then
  if exists(select 1 from public.match_cards mc join public.match_deck_cards d on d.id=mc.match_deck_card_id where mc.match_id=v_attack.match_id and mc.owner_user_id=v_actor and mc.zone='life' and mc.current_life>0 and d.element='Bestiário') then update public.pending_attacks set is_direct=true,result=result||'{"direct_effect":"COMMON_056"}'::jsonb where id=v_attack.id;end if;
 elsif v_code='COMMON_057' then
  if exists(select 1 from public.match_runtime_effects rt where rt.match_id=v_attack.match_id and rt.source_match_card_id=new.match_card_id and rt.effect_code='common_harpy_absorb_and_attack' and rt.active) then
   select coalesce(sum(mc.current_power),0) into v_power from public.match_cards mc join public.match_deck_cards d on d.id=mc.match_deck_card_id where mc.match_id=v_attack.match_id and mc.owner_user_id=v_actor and mc.zone='deck' and d.card_name='Harpia';
   update public.pending_attack_cards set power_when_declared=power_when_declared+v_power where pending_attack_id=v_attack.id and match_card_id=new.match_card_id;
   update public.pending_attacks set declared_power=declared_power+v_power,is_direct=true,result=result||jsonb_build_object('force_farthest_life',true,'direct_effect','COMMON_057') where id=v_attack.id;
   update public.match_runtime_effects set active=false,consumed_at=clock_timestamp() where match_id=v_attack.match_id and source_match_card_id=new.match_card_id and effect_code='common_harpy_absorb_and_attack' and active;
  end if;
 end if;
 return new;
end $$;

do $$ begin
 if to_regprocedure('public.declare_attack_v24_core(uuid,uuid[],boolean,bigint)') is null then
  alter function public.declare_attack(uuid,uuid[],boolean,bigint) rename to declare_attack_v24_core;
 end if;
end $$;
revoke all on function public.declare_attack_v24_core(uuid,uuid[],boolean,bigint) from public,anon,authenticated;

create or replace function public.declare_attack(
 p_match_id uuid,p_attacker_card_ids uuid[],p_is_direct boolean default false,p_expected_version bigint default 0
) returns jsonb language plpgsql security definer set search_path='' as $$
declare v_actor uuid:=game_private.require_authenticated();v_ids uuid[];v_source uuid;v_runtime public.match_runtime_effects;v_result jsonb;v_attack uuid;v_direct boolean:=p_is_direct;
begin
 select coalesce(array_agg(x.id order by x.ord),'{}'::uuid[]) into v_ids from(
  select mc.id,u.ord from unnest(coalesce(p_attacker_card_ids,'{}'::uuid[])) with ordinality u(id,ord)
  join public.match_cards mc on mc.id=u.id and mc.match_id=p_match_id and mc.controller_user_id=v_actor and mc.zone='attacker' and mc.current_life>0
  where not coalesce((mc.metadata->>'v25_skip_normal_attack')::boolean,false)
 )x;
 select rt.* into v_runtime from public.match_runtime_effects rt
  where rt.match_id=p_match_id and rt.owner_user_id=v_actor and rt.source_match_card_id=any(coalesce(p_attacker_card_ids,'{}'::uuid[])) and rt.active
   and rt.effect_code in('common_day_wraith_direct_attack','common_panther_direct_life','common_cleaver_discard_for_direct')
  order by rt.created_at limit 1 for update;
 if found then v_ids:=array[v_runtime.source_match_card_id];v_direct:=true;v_source:=v_runtime.source_match_card_id;end if;
 if cardinality(v_ids)=0 then return game_private.change_active_turn(p_match_id,v_actor,false,p_expected_version)||jsonb_build_object('attack_skipped_after_effect',true);end if;
 v_result:=public.declare_attack_v24_core(p_match_id,v_ids,v_direct,p_expected_version);
 v_attack:=(v_result->>'pending_attack_id')::uuid;
 if v_runtime.id is not null then
  update public.pending_attacks set result=coalesce(result,'{}'::jsonb)||jsonb_build_object('prepared_effect',v_runtime.effect_code,'prepared_source_card_id',v_source,
    'forced_life_target_id',v_runtime.target_match_card_id) where id=v_attack;
  update public.match_runtime_effects set active=false,consumed_at=clock_timestamp() where id=v_runtime.id;
 end if;
 return v_result||jsonb_build_object('effective_attacker_card_ids',v_ids,'prepared_direct_effect',v_runtime.effect_code);
end $$;

-- ---------------------------------------------------------------------------
-- 5. Resolvedor: usa o poder declarado (logo respeita cancelamentos), mantém
-- reforço oculto no ataque do Javali e entrega HP final no contrato dos gatilhos.
-- ---------------------------------------------------------------------------
create or replace function game_private.resolve_pending_attack_internal(
 p_pending_attack_id uuid,p_actor_user_id uuid,p_expected_version bigint
) returns jsonb language plpgsql security definer set search_path='' as $$
declare
 v_attack public.pending_attacks;v_match public.matches;v_card record;v_life_card public.match_cards;
 v_total_power integer;v_remaining_damage integer;v_card_life_before integer;v_damage_result jsonb;
 v_reinforcement_results jsonb:='[]'::jsonb;v_life_result jsonb:=null;v_attacker_ids uuid[];
 v_life_remaining integer;v_match_finished boolean:=false;v_new_version bigint;v_suppress_reveal boolean:=false;v_forced_life uuid;
begin
 select * into v_attack from public.pending_attacks where id=p_pending_attack_id for update;
 if not found then raise exception 'PENDING_ATTACK_NOT_FOUND';end if;
 select * into v_match from public.matches where id=v_attack.match_id for update;
 if v_match.state_version<>p_expected_version then raise exception 'STALE_MATCH_VERSION';end if;
 if v_match.status<>'in_progress' then raise exception 'INVALID_MATCH_STATUS';end if;
 if v_attack.status not in('awaiting_reaction','reaction_used','reaction_declined') then raise exception 'ATTACK_CANNOT_BE_RESOLVED';end if;
 if v_attack.status='awaiting_reaction' and v_attack.reaction_deadline>clock_timestamp() then raise exception 'REACTION_WINDOW_STILL_OPEN';end if;
 update public.pending_attacks set status='resolving' where id=p_pending_attack_id;
 select array_agg(pac.match_card_id order by pac.attack_position) into v_attacker_ids
  from public.pending_attack_cards pac join public.match_cards mc on mc.id=pac.match_card_id
  where pac.pending_attack_id=p_pending_attack_id and mc.match_id=v_attack.match_id and mc.controller_user_id=v_attack.attacker_user_id and mc.zone='attacker' and mc.current_life>0;
 if coalesce(cardinality(v_attacker_ids),0)=0 then raise exception 'NO_VALID_ATTACKERS_REMAIN';end if;
 v_total_power:=greatest(0,v_attack.declared_power);
 v_remaining_damage:=v_total_power;
 v_suppress_reveal:=coalesce((v_attack.result->>'suppress_reinforcement_reveal')::boolean,false);
 v_forced_life:=nullif(v_attack.result->>'forced_life_target_id','')::uuid;

 if not v_attack.is_direct then
  for v_card in select * from public.match_cards where match_id=v_attack.match_id and controller_user_id=v_attack.defender_user_id and zone='reinforcement' and current_life>0 order by zone_position for update loop
   exit when v_remaining_damage<=0;
   if not v_suppress_reveal then update public.match_cards set is_face_up=true where id=v_card.id;end if;
   v_card_life_before:=v_card.current_life;
   update public.match_cards set metadata=metadata||jsonb_build_object('v25_incoming_attack_power',v_remaining_damage) where id=v_card.id;
   v_damage_result:=game_private.apply_damage_internal(v_attack.match_id,v_card.id,v_remaining_damage,v_match.current_turn);
   v_remaining_damage:=greatest(0,v_remaining_damage-v_card_life_before);
   v_reinforcement_results:=v_reinforcement_results||jsonb_build_array(jsonb_build_object('card_id',v_card.id,'position',v_card.zone_position,
    'life_before',v_card_life_before,'damage_received',least(v_card_life_before,(v_damage_result->>'maximum_life')::integer+v_remaining_damage),
    'final_hp',coalesce((v_damage_result->>'current_life')::integer,0),'result',v_damage_result,'remaining_damage',v_remaining_damage,'reveal_suppressed',v_suppress_reveal));
   if not coalesce((v_damage_result->>'destroyed')::boolean,false) then v_remaining_damage:=0;exit;end if;
  end loop;
 end if;

 if v_remaining_damage>0 then
  if v_forced_life is not null then
   select * into v_life_card from public.match_cards where id=v_forced_life and match_id=v_attack.match_id and controller_user_id=v_attack.defender_user_id and zone='life' and current_life>0 for update;
  end if;
  if not found or v_forced_life is null then
   select * into v_life_card from public.match_cards where match_id=v_attack.match_id and controller_user_id=v_attack.defender_user_id and zone='life' and current_life>0
    order by case when coalesce((v_attack.result->>'force_farthest_life')::boolean,false) then zone_position end desc,zone_position asc limit 1 for update;
  end if;
  if found then
   v_card_life_before:=v_life_card.current_life;
   update public.match_cards set metadata=metadata||jsonb_build_object('v25_incoming_attack_power',v_remaining_damage) where id=v_life_card.id;
   v_damage_result:=game_private.apply_damage_internal(v_attack.match_id,v_life_card.id,v_remaining_damage,v_match.current_turn);
   v_life_result:=jsonb_build_object('card_id',v_life_card.id,'position',v_life_card.zone_position,'life_before',v_card_life_before,
    'damage_received',least(v_remaining_damage,v_card_life_before),'discarded_overflow',greatest(0,v_remaining_damage-v_card_life_before),
    'final_hp',coalesce((v_damage_result->>'current_life')::integer,0),'result',v_damage_result);
   if coalesce((v_damage_result->>'destroyed')::boolean,false) then
    update public.match_players set destroyed_life_count=destroyed_life_count+1 where match_id=v_attack.match_id and user_id=v_attack.defender_user_id;
    update public.match_players set life_destroyed_this_turn=true where match_id=v_attack.match_id and user_id=v_attack.attacker_user_id;
   end if;
   v_remaining_damage:=0;
  end if;
 end if;

 update public.match_cards set zone='graveyard',zone_position=null,is_face_up=true,has_attacked_this_turn=true,
  current_power=case when metadata->>'v25_saved_power' is not null then (metadata->>'v25_saved_power')::integer else current_power end,
  metadata=metadata-'locked_for_pending_attack'-'v25_skip_normal_attack'-'v25_saved_power' where id=any(v_attacker_ids);
 select count(*)::integer into v_life_remaining from public.match_cards where match_id=v_attack.match_id and controller_user_id=v_attack.defender_user_id and zone='life' and current_life>0;
 v_match_finished:=v_life_remaining=0;
 update public.pending_attacks set status='resolved',resolved_power=v_total_power,damage_remaining_after_resolution=v_remaining_damage,resolved_at=clock_timestamp(),
  result=coalesce(v_attack.result,'{}'::jsonb)||jsonb_build_object('attackers',v_attacker_ids,'total_power',v_total_power,'reinforcements',v_reinforcement_results,
   'life',v_life_result,'defender_life_remaining',v_life_remaining,'match_finished',v_match_finished) where id=p_pending_attack_id;
 v_new_version:=game_private.record_match_action(v_attack.match_id,p_actor_user_id,'attack_resolved',jsonb_build_object('pending_attack_id',p_pending_attack_id,
  'attacker_user_id',v_attack.attacker_user_id,'defender_user_id',v_attack.defender_user_id,'attacker_card_ids',v_attacker_ids,'total_power',v_total_power,
  'is_direct',v_attack.is_direct,'reinforcements',v_reinforcement_results,'life',v_life_result,'defender_life_remaining',v_life_remaining,
  'match_finished',v_match_finished,'effect_contract',v_attack.result),'{}'::jsonb,p_expected_version);
 update public.pending_attacks set resolved_state_version=v_new_version where id=p_pending_attack_id;
 if v_match_finished then perform game_private.finish_match(v_attack.match_id,v_attack.attacker_user_id,'all_life_cards_destroyed');end if;
 return jsonb_build_object('pending_attack_id',p_pending_attack_id,'attackers',v_attacker_ids,'total_power',v_total_power,'reinforcements',v_reinforcement_results,
  'life',v_life_result,'defender_life_remaining',v_life_remaining,'match_finished',v_match_finished,'winner_id',case when v_match_finished then v_attack.attacker_user_id else null end,'state_version',v_new_version);
end $$;



create or replace function game_private.execute_common_effect_internal(
 p_match_id uuid,p_actor uuid,p_source uuid,p_code text,p_params jsonb,
 p_target uuid default null,p_event jsonb default '{}'
) returns jsonb language plpgsql security definer set search_path='' as $$
declare
 s public.match_cards;t public.match_cards;pa public.pending_attacks;opp uuid;turn_no integer;v_id uuid;v_other uuid;
 v_ids uuid[]:='{}'::uuid[];v_count integer:=0;v_amount integer:=0;v_result jsonb:='{}'::jsonb;v_damage jsonb:='{}'::jsonb;
 v_name text;v_zone text;v_incoming integer:=0;v_life integer:=0;v_before integer:=0;v_runtime uuid;
begin
 select mc.* into s from public.match_cards mc where mc.id=p_source and mc.match_id=p_match_id for update;
 if not found then raise exception 'EFFECT_SOURCE_NOT_FOUND';end if;
 select m.current_turn into turn_no from public.matches m where m.id=p_match_id;
 select mp.user_id into opp from public.match_players mp where mp.match_id=p_match_id and mp.user_id<>p_actor order by mp.player_number limit 1;
 select d.card_name into v_name from public.match_deck_cards d where d.id=s.match_deck_card_id;

 if p_code='common_draw_three_common' then
  select coalesce(array_agg(q.id),'{}'::uuid[]) into v_ids from(
   select mc.id from public.match_cards mc join public.match_deck_cards d on d.id=mc.match_deck_card_id
   where mc.match_id=p_match_id and mc.owner_user_id=p_actor and mc.zone='deck' and d.rarity='common'
   order by mc.zone_position limit 3)q;
  foreach v_id in array v_ids loop perform game_private.move_card_checked(v_id,'hand',null,false);end loop;
  return jsonb_build_object('drawn_common_card_ids',v_ids,'drawn_count',cardinality(v_ids),'automatic',true);

 elsif p_code='common_graveyard_return_lock' then
  return jsonb_build_object('persistent_lock',true,'activated_from_life',true);

 elsif p_code='common_javali_attack_rules' then
  return jsonb_build_object('automatic_attack_rule',true);

 elsif p_code='common_erinia_exchange' then
  if s.zone not in('life','reinforcement','attacker') then raise exception 'ERINIA_MUST_BE_ON_FIELD';end if;
  select mc.id into v_id from public.match_cards mc join public.match_deck_cards d on d.id=mc.match_deck_card_id
   where mc.match_id=p_match_id and mc.owner_user_id=opp and mc.zone='hand'
   order by case d.rarity when 'common' then 1 when 'rare' then 2 when 'epic' then 3 when 'legendary' then 4 else 5 end,random() limit 1 for update of mc;
  if v_id is null then raise exception 'OPPONENT_HAND_EMPTY';end if;
  select mc.id into v_other from public.match_cards mc where mc.match_id=p_match_id and mc.owner_user_id=p_actor and mc.zone='hand' order by random() limit 1 for update;
  if v_other is null then raise exception 'OWN_HAND_DISCARD_REQUIRED';end if;
  update public.match_cards set owner_user_id=p_actor,controller_user_id=p_actor,zone_position=null,is_face_up=false where id=v_id;
  perform game_private.move_card_checked(v_other,'graveyard',null,true);
  return jsonb_build_object('stolen_card_id',v_id,'randomly_discarded_card_id',v_other);

 elsif p_code='common_endriuga_scaled_damage' then
  if s.zone not in('life','reinforcement','attacker') then raise exception 'ENDRIUGA_MUST_BE_ON_FIELD';end if;
  select mc.* into t from public.match_cards mc where mc.id=p_target and mc.match_id=p_match_id and mc.controller_user_id=opp and mc.zone='life' and mc.current_life>0 for update;
  if not found then raise exception 'ENDRIUGA_REQUIRES_ENEMY_LIFE_TARGET';end if;
  select count(*)::integer into v_count from public.match_cards mc where mc.match_id=p_match_id and mc.controller_user_id=opp and mc.zone='reinforcement' and mc.current_life>0;
  v_amount:=v_count*500;
  v_result:=game_private.apply_damage_internal(p_match_id,t.id,v_amount,turn_no);
  if coalesce((v_result->>'destroyed')::boolean,false) then update public.match_players set destroyed_life_count=destroyed_life_count+1 where match_id=p_match_id and user_id=opp;update public.match_players set life_destroyed_this_turn=true where match_id=p_match_id and user_id=p_actor;end if;
  return jsonb_build_object('target_card_id',t.id,'enemy_reinforcement_count',v_count,'poison_damage',v_amount,'damage_result',v_result);

 elsif p_code='common_henselt_attack_all_life' then
  if s.zone<>'attacker' then raise exception 'HENSELT_MUST_BE_IN_ATTACK_FIELD';end if;
  if exists(select 1 from public.match_cards mc where mc.match_id=p_match_id and mc.controller_user_id=opp and mc.zone='reinforcement' and mc.current_life>0) then raise exception 'ENEMY_HAS_REINFORCEMENTS';end if;
  v_result:='{}'::jsonb;
  for v_id in select mc.id from public.match_cards mc where mc.match_id=p_match_id and mc.controller_user_id=opp and mc.zone='life' and mc.current_life>0 order by mc.zone_position limit 3 loop
   v_damage:=game_private.apply_damage_internal(p_match_id,v_id,s.current_power,turn_no);
   v_result:=v_result||jsonb_build_object(v_id::text,v_damage);
   if coalesce((v_damage->>'destroyed')::boolean,false) then
    update public.match_players set destroyed_life_count=destroyed_life_count+1 where match_id=p_match_id and user_id=opp;
    update public.match_players set life_destroyed_this_turn=true where match_id=p_match_id and user_id=p_actor;
   end if;
  end loop;
  update public.match_cards set metadata=metadata||jsonb_build_object('v25_skip_normal_attack',true,'v25_saved_power',s.current_power),current_power=0 where id=s.id;
  return jsonb_build_object('attacked_all_life',true,'power_per_target',s.current_power,'targets',v_result);

 elsif p_code in('common_day_wraith_direct_attack','common_panther_direct_life') then
  if s.zone<>'attacker' then raise exception 'DIRECT_EFFECT_REQUIRES_ATTACK_FIELD';end if;
  if p_code='common_day_wraith_direct_attack' then
   select count(*)::integer into v_count from public.match_cards mc where mc.match_id=p_match_id and mc.owner_user_id=p_actor and mc.zone='graveyard';
   if v_count<5 then raise exception 'DAY_WRAITH_REQUIRES_FIVE_GRAVEYARD_CARDS';end if;
  else
   if (select count(*) from public.match_cards where match_id=p_match_id and owner_user_id=p_actor and zone='hand') <=
      (select count(*) from public.match_cards where match_id=p_match_id and owner_user_id=opp and zone='hand') then raise exception 'PANTHER_REQUIRES_HAND_ADVANTAGE';end if;
  end if;
  insert into public.match_runtime_effects(match_id,owner_user_id,source_match_card_id,effect_code,scope,payload,starts_on_turn,expires_on_turn)
  values(p_match_id,p_actor,p_source,p_code,'card',jsonb_build_object('prepared',true),turn_no,turn_no) returning id into v_runtime;
  return jsonb_build_object('direct_attack_prepared',true,'runtime_effect_id',v_runtime);

 elsif p_code='common_night_wraith_silence_hand' then
  if p_event->>'old_zone'<>'reinforcement' then raise exception 'NIGHT_WRAITH_MUST_DIE_AS_REINFORCEMENT';end if;
  select mc.id into v_id from public.match_cards mc where mc.match_id=p_match_id and mc.owner_user_id=opp and mc.zone='hand' order by random() limit 1 for update;
  if v_id is null then raise exception 'OPPONENT_HAND_EMPTY';end if;
  update public.match_cards set metadata=metadata||jsonb_build_object('effect_silenced',true,'silenced_by',p_source) where id=v_id;
  return jsonb_build_object('silenced_hand_card_id',v_id,'permanent',true);

 elsif p_code='common_keira_replace_life' then
  if p_event->>'old_zone'<>'life' then raise exception 'KEIRA_MUST_DIE_AS_LIFE';end if;
  select mc.id into v_id from public.match_cards mc join public.match_deck_cards d on d.id=mc.match_deck_card_id
   where mc.match_id=p_match_id and mc.owner_user_id=p_actor and mc.zone='deck' and d.rarity='common' order by random() limit 1 for update of mc;
  if v_id is null then raise exception 'NO_COMMON_DEFENSE_IN_DECK';end if;
  perform game_private.move_card_checked(v_id,'life',coalesce((p_event->>'old_position')::integer,1),true);
  return jsonb_build_object('replacement_card_id',v_id,'life_slot',(p_event->>'old_position')::integer);

 elsif p_code='common_ghoul_group_revive' then
  if p_event->>'old_zone'<>'reinforcement' then raise exception 'GHOUL_MUST_DIE_AS_REINFORCEMENT';end if;
  if not exists(select 1 from public.match_cards mc join public.match_deck_cards d on d.id=mc.match_deck_card_id
    where mc.match_id=p_match_id and mc.owner_user_id=p_actor and mc.zone='reinforcement' and mc.current_life>0 and d.card_name=v_name) then raise exception 'MATCHING_GHOUL_REINFORCEMENT_REQUIRED';end if;
  if not exists(select 1 from public.match_cards mc where mc.id=p_target and mc.match_id=p_match_id and mc.owner_user_id=p_actor and mc.zone='graveyard' and mc.id<>p_source) then raise exception 'VALID_GRAVEYARD_TARGET_REQUIRED';end if;
  perform game_private.move_card_checked(p_target,'hand',null,false);
  return jsonb_build_object('returned_card_id',p_target,'matching_reinforcement_confirmed',true);

 elsif p_code in('common_elemental_prevent_damage','common_gargoyle_cancel_single_attack') then
  if s.zone not in('life','reinforcement') then raise exception 'DEFENSIVE_REACTION_SOURCE_REQUIRED';end if;
  select x.* into pa from public.pending_attacks x where x.match_id=p_match_id and x.defender_user_id=p_actor and x.status='awaiting_reaction' order by x.created_at desc limit 1 for update;
  if not found then raise exception 'NO_PENDING_ATTACK_FOR_REACTION';end if;
  if p_code='common_gargoyle_cancel_single_attack' and (select count(*) from public.pending_attack_cards where pending_attack_id=pa.id)<>1 then raise exception 'REACTION_REQUIRES_SINGLE_ATTACKER';end if;
  if p_code='common_elemental_prevent_damage' then
   if not exists(select 1 from public.pending_attack_cards pac join public.match_cards mc on mc.id=pac.match_card_id join public.match_deck_cards d on d.id=mc.match_deck_card_id where pac.pending_attack_id=pa.id and d.element='M&F') then raise exception 'ATTACKER_IS_NOT_M_AND_F';end if;
   if pa.is_direct and s.zone='reinforcement' then raise exception 'ELEMENTAL_IS_NOT_REACHED_BY_ATTACK';end if;
   select coalesce(sum(mc.current_life),0)::integer into v_before from public.match_cards mc
    where mc.match_id=p_match_id and mc.controller_user_id=p_actor and mc.current_life>0 and
     ((not pa.is_direct and s.zone='reinforcement' and mc.zone='reinforcement' and mc.zone_position<s.zone_position)
      or (s.zone='life' and ((not pa.is_direct and mc.zone='reinforcement') or (mc.zone='life' and mc.zone_position<s.zone_position))));
   if pa.declared_power<=v_before then raise exception 'ELEMENTAL_IS_NOT_REACHED_BY_ATTACK';end if;
  end if;
  update public.pending_attacks set declared_power=0,status='reaction_used',reaction_completed_at=clock_timestamp(),result=coalesce(result,'{}'::jsonb)||jsonb_build_object('damage_cancelled_by',p_code,'source_card_id',p_source,'original_power',pa.declared_power) where id=pa.id;
  return jsonb_build_object('pending_attack_id',pa.id,'damage_cancelled',true,'cancelled_power',pa.declared_power);

 elsif p_code='common_troll_discard_draw' then
  if s.zone not in('life','reinforcement','attacker') then raise exception 'TROLL_MUST_BE_ON_FIELD';end if;
  select coalesce(array_agg(mc.id),'{}'::uuid[]) into v_ids from public.match_cards mc where mc.match_id=p_match_id and mc.owner_user_id=p_actor and mc.zone='hand';
  foreach v_id in array v_ids loop perform game_private.move_card_checked(v_id,'graveyard',null,true);end loop;
  v_result:=game_private.draw_internal(p_match_id,p_actor,2);
  update public.pending_attacks set status='reaction_used',reaction_completed_at=clock_timestamp(),result=coalesce(result,'{}'::jsonb)||jsonb_build_object('reaction_effect',p_code,'source_card_id',p_source)
   where match_id=p_match_id and defender_user_id=p_actor and status='awaiting_reaction';
  return jsonb_build_object('discarded_hand_ids',v_ids,'drawn',v_result);

 elsif p_code='common_berserker_copy_stats' then
  if s.zone not in('attacker','reinforcement') then raise exception 'BERSERKER_REQUIRES_ATTACK_OR_REINFORCEMENT';end if;
  select mc.* into t from public.match_cards mc where mc.match_id=p_match_id and mc.owner_user_id=opp and mc.zone='graveyard' order by random() limit 1;
  if not found then raise exception 'OPPONENT_GRAVEYARD_EMPTY';end if;
  update public.match_cards set base_power=t.base_power,maximum_power=t.maximum_power,current_power=t.current_power,
   base_max_life=t.base_max_life,maximum_life=t.maximum_life,current_life=t.current_life,
   metadata=metadata||jsonb_build_object('copied_from',t.id) where id=p_source;
  update public.pending_attacks set status='reaction_used',reaction_completed_at=clock_timestamp(),result=coalesce(result,'{}'::jsonb)||jsonb_build_object('reaction_effect',p_code,'source_card_id',p_source)
   where match_id=p_match_id and defender_user_id=p_actor and status='awaiting_reaction';
  return jsonb_build_object('copied_card_id',t.id,'copied_power',t.current_power,'copied_life',t.current_life);

 elsif p_code='common_puero_destroy_random_legendary' then
  select mc.* into t from public.match_cards mc join public.match_deck_cards d on d.id=mc.match_deck_card_id
   where mc.match_id=p_match_id and mc.zone in('life','reinforcement','attacker','leader') and mc.current_life>0 and d.rarity='legendary' order by random() limit 1;
  if not found then raise exception 'NO_LEGENDARY_ON_FIELD';end if;v_id:=t.id;
  v_result:=game_private.apply_damage_internal(p_match_id,v_id,20000,turn_no);
  if t.zone='life' and coalesce((v_result->>'destroyed')::boolean,false) then update public.match_players set destroyed_life_count=destroyed_life_count+1 where match_id=p_match_id and user_id=t.controller_user_id;update public.match_players set life_destroyed_this_turn=true where match_id=p_match_id and user_id=p_actor;end if;
  return jsonb_build_object('random_legendary_id',v_id,'damage_result',v_result);

 elsif p_code='common_necrophage_destroy_hand' then
  if p_event->>'old_zone' not in('reinforcement','life') or coalesce((p_event->>'incoming_attack_power')::integer,0)<=0 then raise exception 'NECROPHAGE_REQUIRES_ATTACK_DESTRUCTION_FROM_FIELD';end if;
  select mc.id into v_id from public.match_cards mc where mc.match_id=p_match_id and mc.owner_user_id=opp and mc.zone='hand' and mc.current_power<s.maximum_life order by random() limit 1 for update;
  if v_id is null then raise exception 'NO_ELIGIBLE_ENEMY_HAND_CARD';end if;
  perform game_private.move_card_checked(v_id,'graveyard',null,true);
  return jsonb_build_object('destroyed_enemy_hand_card_id',v_id,'power_limit',s.maximum_life);

 elsif p_code='common_fairy_extra_draw' then
  if s.zone not in('life','reinforcement') then raise exception 'FAIRY_MUST_BE_ON_FIELD';end if;
  if exists(select 1 from public.match_runtime_effects rt where rt.match_id=p_match_id and rt.source_match_card_id=p_source and rt.effect_code=p_code and rt.active) then raise exception 'FAIRY_EFFECT_ALREADY_ACTIVE';end if;
  insert into public.match_runtime_effects(match_id,owner_user_id,source_match_card_id,effect_code,scope,payload,starts_on_turn)
   values(p_match_id,p_actor,p_source,p_code,'player',jsonb_build_object('extra_draw',1,'paid_once',true),turn_no) returning id into v_runtime;
  return jsonb_build_object('persistent_extra_draw',true,'runtime_effect_id',v_runtime);

 elsif p_code='common_shani_redeploy_life' then
  if p_event->>'old_zone'<>'reinforcement' then raise exception 'SHANI_MUST_DIE_AS_REINFORCEMENT';end if;
  select mc.id,mc.zone_position into v_id,v_count from public.match_cards mc where mc.match_id=p_match_id and mc.controller_user_id=p_actor and mc.zone='life' and mc.current_life>0 and mc.current_life<s.maximum_life order by random() limit 1 for update;
  if v_id is null then raise exception 'NO_LOWER_LIFE_CARD_TO_REPLACE';end if;
  perform game_private.move_card_checked(v_id,'graveyard',null,true);
  update public.match_cards set zone='life',zone_position=v_count,is_destroyed=false,current_life=maximum_life,is_face_up=true where id=p_source;
  return jsonb_build_object('replaced_life_card_id',v_id,'life_slot',v_count,'restored_life',s.maximum_life);

 elsif p_code='common_barghest_overkill_to_deck' then
  v_incoming:=coalesce((p_event->>'incoming_attack_power')::integer,0);
  if v_incoming<s.maximum_life*3 then raise exception 'BARGHEST_REQUIRES_TRIPLE_LIFE_ATTACK';end if;
  select coalesce(max(mc.zone_position),0)+1 into v_count from public.match_cards mc where mc.match_id=p_match_id and mc.owner_user_id=p_actor and mc.zone='deck';
  update public.match_cards set zone='deck',zone_position=floor(random()*greatest(v_count,1)+1)::integer,is_face_up=false,is_destroyed=false,current_life=maximum_life,
   metadata=metadata-'v25_incoming_attack_power' where id=p_source;
  return jsonb_build_object('returned_to_deck',true,'incoming_attack_power',v_incoming,'required_power',s.maximum_life*3);

 elsif p_code='common_barroso_purge_enemy_hand' then
  select coalesce(array_agg(mc.id),'{}'::uuid[]) into v_ids from public.match_cards mc where mc.match_id=p_match_id and mc.owner_user_id=opp and mc.zone='hand' and mc.id<>p_source;
  foreach v_id in array v_ids loop perform game_private.move_card_checked(v_id,'graveyard',null,true);end loop;
  if s.owner_user_id=opp and s.zone='hand' then
   update public.match_cards set metadata=metadata||jsonb_build_object('v25_barroso_resolved',true) where id=p_source;
   perform game_private.move_card_checked(p_source,'graveyard',null,true);
   v_ids:=array_append(v_ids,p_source);
  end if;
  return jsonb_build_object('purged_enemy_hand_ids',v_ids,'automatic',true,'trigger_cause',p_event->>'hand_exit_cause');

 elsif p_code='common_atrocious_ghoul_draw_epic' then
  if s.zone<>'reinforcement' or s.current_life<=0 then raise exception 'ATROCIOUS_GHOUL_MUST_SURVIVE_AS_REINFORCEMENT';end if;
  select mc.id into v_id from public.match_cards mc join public.match_deck_cards d on d.id=mc.match_deck_card_id
   where mc.match_id=p_match_id and mc.owner_user_id=p_actor and mc.zone='deck' and d.rarity='epic' order by random() limit 1 for update of mc;
  if v_id is null then raise exception 'NO_EPIC_CARD_IN_DECK';end if;
  perform game_private.move_card_checked(v_id,'hand',null,false);
  return jsonb_build_object('drawn_epic_card_id',v_id,'survived_life',s.current_life);

 elsif p_code='common_beggar_king_destroy_life' then
  if s.zone<>'hand' or (select count(*) from public.match_cards where match_id=p_match_id and owner_user_id=p_actor and zone='hand')<>1 then raise exception 'SOURCE_MUST_BE_ONLY_HAND_CARD';end if;
  select mc.id into v_id from public.match_cards mc where mc.match_id=p_match_id and mc.controller_user_id=opp and mc.zone='life' and mc.current_life>0 order by random() limit 1 for update;
  if v_id is null then raise exception 'NO_ENEMY_LIFE_CARD';end if;
  v_result:=game_private.apply_damage_internal(p_match_id,v_id,20000,turn_no);
  update public.match_players set destroyed_life_count=destroyed_life_count+1 where match_id=p_match_id and user_id=opp;
  update public.match_players set life_destroyed_this_turn=true where match_id=p_match_id and user_id=p_actor;
  return jsonb_build_object('random_destroyed_life_id',v_id,'damage_result',v_result);

 elsif p_code='common_cleaver_discard_for_direct' then
  if s.zone<>'attacker' then raise exception 'CLEAVER_MUST_BE_IN_ATTACK_FIELD';end if;
  if not exists(select 1 from public.match_cards mc where mc.id=p_target and mc.match_id=p_match_id and mc.controller_user_id=opp and mc.zone='life' and mc.current_life>0) then raise exception 'CLEAVER_REQUIRES_ENEMY_LIFE_TARGET';end if;
  select coalesce(array_agg(mc.id),'{}'::uuid[]) into v_ids from public.match_cards mc where mc.match_id=p_match_id and mc.owner_user_id=p_actor and mc.zone='hand';
  if cardinality(v_ids)<3 then raise exception 'CLEAVER_REQUIRES_THREE_HAND_CARDS';end if;
  insert into public.pending_effect_choices(match_id,actor_user_id,source_match_card_id,effect_order,effect_code,choice_type,min_choices,max_choices,candidate_ids,public_prompt,private_context,expected_state_version)
   values(p_match_id,p_actor,p_source,1,p_code,'hand_card',3,3,v_ids,'Escolha exatamente 3 cartas da sua mão para descartar.',jsonb_build_object('target_life_card_id',p_target),(select state_version from public.matches where id=p_match_id));
  return jsonb_build_object('choice_pending',true,'discard_candidates',cardinality(v_ids),'target_life_card_id',p_target);

 elsif p_code='common_lugos_next_civil_double_power' then
  select mc.* into t from public.match_cards mc where mc.match_id=p_match_id and mc.owner_user_id=p_actor and mc.zone='deck' order by mc.zone_position limit 1 for update;
  if not found then raise exception 'DECK_EMPTY';end if;
  select d.element into v_zone from public.match_deck_cards d where d.id=t.match_deck_card_id;
  if lower(replace(v_zone,'í','i'))<>'civil' then return jsonb_build_object('top_card_id',t.id,'top_card_element',v_zone,'drawn',false,'power_doubled',false);end if;
  update public.match_cards set base_power=least(20000,base_power*2),maximum_power=least(20000,maximum_power*2),current_power=least(20000,current_power*2),
   metadata=metadata||jsonb_build_object('permanent_power_doubled_by',p_source) where id=t.id;
  perform game_private.move_card_checked(t.id,'hand',null,false);
  return jsonb_build_object('top_card_id',t.id,'top_card_element',v_zone,'drawn',true,'power_before',t.current_power,'power_after',least(20000,t.current_power*2),'power_doubled',true);
 end if;

 return game_private.execute_common_effect_internal_v24_core(p_match_id,p_actor,p_source,p_code,p_params,p_target,p_event);
end $$;

-- ---------------------------------------------------------------------------
-- 6. Escolha composta do Cutelo: alvo de Vida na ativação e exatamente três
-- descartes escolhidos pelo jogador antes de preparar o ataque direto.
-- ---------------------------------------------------------------------------
create or replace function game_private.assert_effect_choice(p_choice_id uuid,p_selected_ids uuid[],p_expected_version bigint)
returns public.pending_effect_choices language plpgsql security definer set search_path='' as $$
declare v public.pending_effect_choices;v_current bigint;
begin
 select * into v from public.pending_effect_choices where id=p_choice_id and actor_user_id=auth.uid() and status='pending' for update;
 if not found then raise exception 'EFFECT_CHOICE_NOT_FOUND';end if;
 if v.expires_at<=clock_timestamp() then update public.pending_effect_choices set status='expired' where id=v.id;raise exception 'EFFECT_CHOICE_EXPIRED';end if;
 select m.state_version into v_current from public.matches m where m.id=v.match_id for update;
 if v_current<>p_expected_version then raise exception 'STALE_MATCH_VERSION';end if;
 if cardinality(coalesce(p_selected_ids,'{}'::uuid[]))<v.min_choices or cardinality(coalesce(p_selected_ids,'{}'::uuid[]))>v.max_choices then raise exception 'INVALID_EFFECT_CHOICE_COUNT';end if;
 if (select count(distinct x) from unnest(coalesce(p_selected_ids,'{}'::uuid[]))x)<>cardinality(coalesce(p_selected_ids,'{}'::uuid[])) then raise exception 'DUPLICATED_EFFECT_CHOICE';end if;
 if exists(select 1 from unnest(coalesce(p_selected_ids,'{}'::uuid[]))x where not x=any(v.candidate_ids)) then raise exception 'INVALID_EFFECT_CHOICE';end if;
 return v;
end $$;

do $$ begin
 if to_regprocedure('public.submit_effect_choice_v24_core(uuid,uuid[],bigint)') is null then
  alter function public.submit_effect_choice(uuid,uuid[],bigint) rename to submit_effect_choice_v24_core;
 end if;
end $$;
revoke all on function public.submit_effect_choice_v24_core(uuid,uuid[],bigint) from public,anon,authenticated;

create or replace function public.submit_effect_choice(p_choice_id uuid,p_selected_ids uuid[],p_expected_version bigint)
returns jsonb language plpgsql security definer set search_path='' as $$
declare c public.pending_effect_choices;actor uuid:=game_private.require_authenticated();v_id uuid;v_target uuid;v_version bigint;v_turn integer;v_runtime uuid;
begin
 select * into c from public.pending_effect_choices where id=p_choice_id and actor_user_id=actor and status='pending';
 if not found then raise exception 'EFFECT_CHOICE_NOT_FOUND';end if;
 if c.effect_code<>'common_cleaver_discard_for_direct' then return public.submit_effect_choice_v24_core(p_choice_id,p_selected_ids,p_expected_version);end if;
 c:=game_private.assert_effect_choice(p_choice_id,p_selected_ids,p_expected_version);
 v_target:=nullif(c.private_context->>'target_life_card_id','')::uuid;
 if not exists(select 1 from public.match_cards mc join public.match_players mp on mp.match_id=mc.match_id and mp.user_id=mc.controller_user_id
   where mc.id=v_target and mc.match_id=c.match_id and mc.zone='life' and mc.current_life>0 and mc.controller_user_id<>actor) then raise exception 'CLEAVER_TARGET_NO_LONGER_AVAILABLE';end if;
 foreach v_id in array p_selected_ids loop
  if not exists(select 1 from public.match_cards mc where mc.id=v_id and mc.match_id=c.match_id and mc.owner_user_id=actor and mc.zone='hand') then raise exception 'CLEAVER_DISCARD_NO_LONGER_IN_HAND';end if;
  perform game_private.move_card_checked(v_id,'graveyard',null,true);
 end loop;
 select m.current_turn into v_turn from public.matches m where m.id=c.match_id;
 insert into public.match_runtime_effects(match_id,owner_user_id,source_match_card_id,effect_code,scope,target_match_card_id,payload,starts_on_turn,expires_on_turn)
  values(c.match_id,actor,c.source_match_card_id,c.effect_code,'card',v_target,jsonb_build_object('chosen_discard_ids',p_selected_ids,'chosen_target_life_id',v_target),v_turn,v_turn) returning id into v_runtime;
 update public.pending_effect_choices set status='resolved' where id=c.id;
 v_version:=game_private.record_match_action(c.match_id,actor,'effect_choice_resolved',jsonb_build_object('choice_id',c.id,'effect_code',c.effect_code,
  'source_card_id',c.source_match_card_id,'chosen_discard_ids',p_selected_ids,'chosen_target_life_id',v_target,'runtime_effect_id',v_runtime),'{}'::jsonb,p_expected_version);
 return jsonb_build_object('state_version',v_version,'discarded_card_ids',p_selected_ids,'target_life_card_id',v_target,'direct_attack_prepared',true);
end $$;

-- Instalação defensiva: garante que todas as funções continuem privadas e que
-- somente jogadores autenticados acessem as fachadas públicas.
revoke all on function game_private.execute_common_effect_internal(uuid,uuid,uuid,text,jsonb,uuid,jsonb),
 game_private.v25_trigger_is_eligible(text,uuid,jsonb),game_private.resolve_pending_attack_internal(uuid,uuid,bigint) from public,anon,authenticated;
revoke all on function public.declare_attack(uuid,uuid[],boolean,bigint),public.submit_effect_choice(uuid,uuid[],bigint) from public,anon;
grant execute on function public.declare_attack(uuid,uuid[],boolean,bigint),public.submit_effect_choice(uuid,uuid[],bigint) to authenticated;

-- ---------------------------------------------------------------------------
-- 7. Laboratório: apenas prepara as peças particulares que mudaram neste lote;
-- a execução continua passando pelas mesmas RPCs e handlers usados no PvP.
-- ---------------------------------------------------------------------------
do $$ begin
 if to_regprocedure('public.setup_sandbox_match_v25_core(varchar)') is null then
  alter function public.setup_sandbox_match(varchar) rename to setup_sandbox_match_v25_core;
 end if;
end $$;
revoke all on function public.setup_sandbox_match_v25_core(varchar) from public,anon,authenticated;

create or replace function public.setup_sandbox_match(p_card_id varchar)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_actor uuid:=game_private.require_authenticated();v_result jsonb;v_match uuid;v_code text;v_id uuid;v_source uuid;
begin
 v_result:=public.setup_sandbox_match_v25_core(p_card_id);
 if not coalesce((v_result->>'success')::boolean,false) then return v_result;end if;
 v_match:=(v_result->>'match_id')::uuid;v_code:=v_result->>'card_code';
 select mc.id into v_source from public.match_cards mc where mc.match_id=v_match and mc.owner_user_id=v_actor and coalesce((mc.metadata->>'sandbox_card')::boolean,false) limit 1;
 if v_code='COMMON_003' then
  update public.sandbox_matches set action_type='declare_attack',objective='Encerre o turno com Javali no Campo de Ataque: a mão comum deve ser validada e o reforço atingido não pode ser revelado nem reagir.' where match_id=v_match;
  v_result:=v_result||jsonb_build_object('action_type','declare_attack','objective','Encerre o turno com Javali no Campo de Ataque: a mão comum deve ser validada e o reforço atingido não pode ser revelado nem reagir.');
 elsif v_code='COMMON_010' then
  select mc.id into v_id from public.match_cards mc join public.match_deck_cards d on d.id=mc.match_deck_card_id
   where mc.match_id=v_match and mc.owner_user_id=v_actor and mc.zone='graveyard' and d.card_name=(select d2.card_name from public.match_cards s join public.match_deck_cards d2 on d2.id=s.match_deck_card_id where s.id=v_source)
   order by mc.id limit 1;
  update public.match_cards set zone='reinforcement',zone_position=2,is_face_up=false,is_destroyed=false,current_life=greatest(1,maximum_life) where id=v_id;
 elsif v_code='COMMON_025' then
  select mc.id into v_id from public.match_cards mc where mc.match_id=v_match and mc.owner_user_id=v_actor and mc.zone='deck' order by mc.zone_position limit 1;
  perform game_private.lab_morph_card_v20(v_id,'Cívil do Topo para Lugos','common','Cívil',1200,1600,0);
  update public.sandbox_matches set action_type='activate_effect',objective='Ative Lugos: a carta Cívil do topo deve ser comprada imediatamente com Poder permanente de 1200 para 2400.' where match_id=v_match;
  v_result:=v_result||jsonb_build_object('action_type','activate_effect','objective','Ative Lugos: a carta Cívil do topo deve ser comprada imediatamente com Poder permanente de 1200 para 2400.');
 end if;
 update public.sandbox_matches set state_before=game_private.lab_snapshot_v20(v_match,v_actor) where match_id=v_match;
 perform game_private.recalculate_match_public_state(v_match);
 return v_result;
end $$;

do $$ begin
 if to_regprocedure('public.begin_sandbox_opponent_action_v25_core(uuid)') is null then
  alter function public.begin_sandbox_opponent_action(uuid) rename to begin_sandbox_opponent_action_v25_core;
 end if;
end $$;
revoke all on function public.begin_sandbox_opponent_action_v25_core(uuid) from public,anon,authenticated;
create or replace function public.begin_sandbox_opponent_action(p_match_id uuid)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_actor uuid:=game_private.require_authenticated();v_code text;v_source public.match_cards;v_power integer;
begin
 select s.card_code into v_code from public.sandbox_matches s where s.match_id=p_match_id and s.owner_user_id=v_actor;
 if v_code is null then raise exception 'LAB_MATCH_NOT_FOUND';end if;
 select mc.* into v_source from public.match_cards mc where mc.match_id=p_match_id and mc.owner_user_id=v_actor and coalesce((mc.metadata->>'sandbox_card')::boolean,false) limit 1 for update;
 if v_code in('COMMON_008','COMMON_009','COMMON_010','COMMON_016','COMMON_018','COMMON_019') then
  v_power:=case when v_code='COMMON_019' then greatest(6000,v_source.maximum_life*3) else greatest(2500,v_source.maximum_life+500) end;
  update public.match_cards set metadata=metadata||jsonb_build_object('v25_incoming_attack_power',v_power) where id=v_source.id;
 end if;
 return public.begin_sandbox_opponent_action_v25_core(p_match_id);
end $$;

revoke all on function public.setup_sandbox_match(varchar),public.begin_sandbox_opponent_action(uuid) from public,anon;
grant execute on function public.setup_sandbox_match(varchar),public.begin_sandbox_opponent_action(uuid) to authenticated;

do $$ begin
 if to_regprocedure('public.get_sandbox_test_report_v25_core(uuid)') is null then
  alter function public.get_sandbox_test_report(uuid) rename to get_sandbox_test_report_v25_core;
 end if;
end $$;
revoke all on function public.get_sandbox_test_report_v25_core(uuid) from public,anon,authenticated;
create or replace function public.get_sandbox_test_report(p_match_id uuid)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_actor uuid:=game_private.require_authenticated();v_result jsonb;v_code text;v_ok boolean:=false;
begin
 v_result:=public.get_sandbox_test_report_v25_core(p_match_id);
 select s.card_code into v_code from public.sandbox_matches s where s.match_id=p_match_id and s.owner_user_id=v_actor;
 if v_code='COMMON_003' then
  v_ok:=exists(select 1 from public.pending_attacks pa where pa.match_id=p_match_id and coalesce((pa.result->>'suppress_reinforcement_reveal')::boolean,false) and coalesce((pa.result->>'suppress_reinforcement_reaction')::boolean,false));
 elsif v_code='COMMON_017' then
  v_ok:=exists(select 1 from public.match_runtime_effects rt where rt.match_id=p_match_id and rt.owner_user_id=v_actor and rt.effect_code='common_fairy_extra_draw' and rt.active);
 elsif v_code='COMMON_025' then
  v_ok:=exists(select 1 from public.match_cards mc where mc.match_id=p_match_id and mc.owner_user_id=v_actor and mc.zone='hand' and mc.metadata ? 'permanent_power_doubled_by' and mc.current_power=2400)
   and exists(select 1 from public.match_actions a where a.match_id=p_match_id and a.action_type='effect_activated' and a.payload_public->>'effect_code'='common_lugos_next_civil_double_power');
 else return v_result;end if;
 update public.sandbox_matches set status=case when v_ok then 'review_success' else 'review_failed' end,state_after=game_private.lab_snapshot_v20(p_match_id,v_actor),
  proof=coalesce(proof,'{}'::jsonb)||jsonb_build_object('v25_contract_verified',v_ok,'card_code',v_code) where match_id=p_match_id;
 return v_result||jsonb_build_object('approved',v_ok,'status',case when v_ok then 'review_success' else 'review_failed' end,
  'after',game_private.lab_snapshot_v20(p_match_id,v_actor),'v25_contract_verified',true);
end $$;
revoke all on function public.get_sandbox_test_report(uuid) from public,anon;
grant execute on function public.get_sandbox_test_report(uuid) to authenticated;

do $$ begin
 if exists(select 1 from pg_publication where pubname='supabase_realtime') and not exists(
  select 1 from pg_publication_tables where pubname='supabase_realtime' and schemaname='public' and tablename='match_effect_execution_log'
 ) then alter publication supabase_realtime add table public.match_effect_execution_log;end if;
end $$;
alter table public.match_effect_execution_log replica identity full;

notify pgrst,'reload schema';
commit;
