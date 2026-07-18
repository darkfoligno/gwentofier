create or replace function game_private.queue_card_zone_events() returns trigger language plpgsql security definer set search_path='' as $$
declare ev text; actor uuid; chain uuid:=gen_random_uuid(); begin
 if pg_trigger_depth()>8 then return new; end if;
 actor:=coalesce((select active_player_id from public.matches where id=new.match_id),new.controller_user_id);
 if old.zone='deck' and new.zone='hand' then ev:='on_draw';
 elsif old.zone='hand' and new.zone='graveyard' then ev:='on_discard';
 elsif old.zone='hand' and new.zone in('life','reinforcement','attacker','leader') then ev:='on_play';
 elsif old.zone in('life','reinforcement','attacker','leader') and new.zone in('graveyard','banished') then ev:='on_destroyed';
 elsif old.is_face_up=false and new.is_face_up=true then ev:='on_revealed'; end if;
 if ev is not null then perform game_private.queue_match_effect_event(new.match_id,ev,actor,new.id,null,jsonb_build_object('old_zone',old.zone,'new_zone',new.zone,'old_position',old.zone_position,'damage_taken',greatest(0,old.current_life-new.current_life)),chain,0); end if;
 return new;
end $$;
drop trigger if exists match_cards_queue_effect_events on public.match_cards;
create trigger match_cards_queue_effect_events after update of zone,is_face_up,current_life on public.match_cards for each row when(old is distinct from new) execute function game_private.queue_card_zone_events();

create or replace function game_private.process_one_effect_event(p_event_id bigint) returns void language plpgsql security definer set search_path='' as $$
declare ev public.match_effect_events; e record; source_owner uuid; cost integer; r jsonb; turn_no integer; begin
 select * into ev from public.match_effect_events where id=p_event_id and status='pending' for update skip locked; if not found then return; end if;
 update public.match_effect_events set status='processing' where id=ev.id;
 select owner_user_id into source_owner from public.match_cards where id=ev.source_match_card_id;
 select current_turn into turn_no from public.matches where id=ev.match_id;
 for e in select * from game_private.card_snapshot_effects(ev.source_match_card_id,ev.event_type) loop
  begin
   if e.once_per_turn and exists(select 1 from public.match_effect_uses where match_id=ev.match_id and match_card_id=ev.source_match_card_id and effect_order=e.effect_order and turn_number=turn_no) then continue; end if;
   cost:=coalesce((e.parameters->>'mana_cost')::integer,game_private.effect_card_cost(ev.source_match_card_id),0);
   if cost>0 then update public.match_players set mana_available=mana_available-cost,mana_spent_this_turn=mana_spent_this_turn+cost where match_id=ev.match_id and user_id=source_owner and mana_available>=cost; if not found then raise exception 'INSUFFICIENT_MANA_FOR_AUTOMATIC_EFFECT'; end if; end if;
   if e.effect_code like 'common_%' then r:=game_private.execute_common_effect_internal(ev.match_id,source_owner,ev.source_match_card_id,e.effect_code,e.parameters,ev.target_match_card_id,ev.payload);
   else r:=jsonb_build_object('delegated_base_effect',e.effect_code); end if;
   insert into public.match_effect_uses(match_id,match_card_id,actor_user_id,effect_order,turn_number,is_reaction,mana_spent) values(ev.match_id,ev.source_match_card_id,source_owner,e.effect_order,turn_no,e.is_reaction,cost) on conflict do nothing;
   insert into public.match_effect_execution_log(match_id,event_id,source_match_card_id,card_effect_id,effect_code,result) values(ev.match_id,ev.id,ev.source_match_card_id,e.effect_id,e.effect_code,coalesce(r,'{}'));
  exception when others then
   insert into public.match_effect_execution_log(match_id,event_id,source_match_card_id,card_effect_id,effect_code,result) values(ev.match_id,ev.id,ev.source_match_card_id,e.effect_id,e.effect_code,jsonb_build_object('failed',true,'sqlstate',sqlstate,'message',sqlerrm));
  end;
 end loop;
 update public.match_effect_events set status='resolved',resolved_at=now() where id=ev.id;
exception when others then update public.match_effect_events set status='failed',error_message=sqlstate||': '||sqlerrm,resolved_at=now() where id=p_event_id; end $$;

create or replace function game_private.process_match_effect_queue(p_match_id uuid) returns integer language plpgsql security definer set search_path='' as $$
declare eid bigint; processed integer:=0; begin
 loop
  select id into eid from public.match_effect_events where match_id=p_match_id and status='pending' order by id limit 1;
  exit when eid is null or processed>=128;
  perform game_private.process_one_effect_event(eid); processed:=processed+1; eid:=null;
 end loop;
 if processed>=128 and exists(select 1 from public.match_effect_events where match_id=p_match_id and status='pending') then raise exception 'EFFECT_EVENT_LIMIT_EXCEEDED'; end if;
 return processed;
end $$;

create or replace function game_private.bridge_match_action_effects() returns trigger language plpgsql security definer set search_path='' as $$
declare active_id uuid; mc record; trigger_name text; begin
 if new.action_type in('turn_ended','turn_passed_without_action','turn_passed') then
  trigger_name:='on_turn_end';
  for mc in select id,controller_user_id from public.match_cards where match_id=new.match_id and controller_user_id=new.actor_user_id and zone in('life','reinforcement','attacker','leader') and current_life>0 loop perform game_private.queue_match_effect_event(new.match_id,trigger_name,new.actor_user_id,mc.id,null,new.payload_public); end loop;
  select active_player_id into active_id from public.matches where id=new.match_id;
  for mc in select id,controller_user_id from public.match_cards where match_id=new.match_id and controller_user_id=active_id and zone in('life','reinforcement','attacker','leader') and current_life>0 loop perform game_private.queue_match_effect_event(new.match_id,'on_turn_start',active_id,mc.id,null,new.payload_public); end loop;
 elsif new.action_type='attack_declared' then
  for mc in select value::uuid id from jsonb_array_elements_text(coalesce(new.payload_public->'attacker_card_ids','[]'::jsonb)) value loop perform game_private.queue_match_effect_event(new.match_id,'on_attack_declared',new.actor_user_id,mc.id,null,new.payload_public); end loop;
 elsif new.action_type='attack_resolved' then
  if new.payload_public->>'attacker_card_id' is not null then perform game_private.queue_match_effect_event(new.match_id,'on_attack_resolved',new.actor_user_id,(new.payload_public->>'attacker_card_id')::uuid,(new.payload_public->>'target_card_id')::uuid,new.payload_public); end if;
 end if;
 perform game_private.process_match_effect_queue(new.match_id); return new;
end $$;
drop trigger if exists match_actions_bridge_effects on public.match_actions;
create trigger match_actions_bridge_effects after insert on public.match_actions for each row when(new.action_type<>'effect_activated') execute function game_private.bridge_match_action_effects();
