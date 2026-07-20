-- V14.0: fachada estável de gatilhos, recall autoritativo e payloads narrativos.
begin;

alter table public.pending_card_triggers add column if not exists resolution_action text;
alter table public.pending_card_triggers drop constraint if exists pending_card_triggers_status_check;
alter table public.pending_card_triggers add constraint pending_card_triggers_status_check check(status in('pending','activated','declined','resolved','expired','failed'));

drop function if exists public.resolve_pending_card_trigger(uuid,varchar);
create function public.resolve_pending_card_trigger(p_trigger_id uuid,p_action varchar)
returns jsonb language plpgsql security definer set search_path='' as $$
declare
  v_trigger_id uuid:=p_trigger_id;
  v_status text;
  v_card_id uuid;
  v_match_id uuid;
  v_state_version bigint;
  v_action text:=lower(trim(coalesce(p_action,'')));
  v_core_result jsonb;
begin
  if v_trigger_id is null or v_action not in('activate','decline') then
    return jsonb_build_object('success',false,'trigger_id',v_trigger_id,'action_taken',null,'error','INVALID_TRIGGER_ACTION');
  end if;
  select pt.status,pt.source_match_card_id,pt.match_id
  into v_status,v_card_id,v_match_id
  from public.pending_card_triggers as pt
  where pt.id=v_trigger_id and pt.owner_user_id=auth.uid() for update;
  if v_match_id is null then return jsonb_build_object('success',false,'trigger_id',v_trigger_id,'action_taken',v_action,'error','PENDING_TRIGGER_NOT_FOUND'); end if;
  if v_status<>'pending' then return jsonb_build_object('success',false,'trigger_id',v_trigger_id,'action_taken',v_action,'error','PENDING_TRIGGER_ALREADY_RESOLVED'); end if;
  select m.state_version into v_state_version from public.matches as m where m.id=v_match_id for update;
  v_core_result:=public.resolve_pending_card_trigger(v_trigger_id,v_action='activate',null,v_state_version);
  update public.pending_card_triggers as pt
  set status='resolved',resolution_action=v_action,resolved_at=coalesce(pt.resolved_at,clock_timestamp())
  where pt.id=v_trigger_id;
  perform game_private.refresh_match_engine_state(v_match_id);
  return jsonb_build_object('success',true,'trigger_id',v_trigger_id,'action_taken',v_action,'card_id',v_card_id,'result',coalesce(v_core_result,'{}'::jsonb));
exception when others then
  return jsonb_build_object('success',false,'trigger_id',v_trigger_id,'action_taken',v_action,'error_code',sqlstate,'error_message',sqlerrm);
end $$;

create or replace function public.recall_match_card(p_match_id uuid,p_match_card_id uuid,p_expected_version bigint)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_actor uuid:=game_private.require_authenticated();v_match public.matches;v_card public.match_cards;v_version bigint;
begin
  select m.* into v_match from public.matches as m where m.id=p_match_id for update;
  if not found then raise exception 'MATCH_NOT_FOUND';end if;
  if v_match.state_version<>p_expected_version then raise exception 'STALE_MATCH_VERSION';end if;
  if v_match.status<>'in_progress' or v_match.engine_state<>'turn_action' then raise exception 'RECALL_COMBAT_ALREADY_STARTED';end if;
  if v_match.active_player_id<>v_actor then raise exception 'NOT_YOUR_TURN';end if;
  select mc.* into v_card from public.match_cards as mc where mc.id=p_match_card_id and mc.match_id=p_match_id and mc.owner_user_id=v_actor for update;
  if not found then raise exception 'CARD_NOT_FOUND';end if;
  if v_card.zone not in('attacker','reinforcement') then raise exception 'RECALL_INVALID_ZONE';end if;
  if v_card.entered_zone_turn<>v_match.current_turn or v_card.has_attacked_this_turn then raise exception 'RECALL_WINDOW_CLOSED';end if;
  update public.match_cards as mc set zone='hand',zone_position=null,is_face_up=false,entered_zone_turn=0 where mc.id=p_match_card_id;
  update public.match_players as mp set actions_this_turn=greatest(0,mp.actions_this_turn-1) where mp.match_id=p_match_id and mp.user_id=v_actor;
  perform game_private.sync_player_hand_mana(p_match_id,v_actor);
  v_version:=game_private.record_match_action(p_match_id,v_actor,'card_recalled',jsonb_build_object('match_card_id',p_match_card_id,'from_zone',v_card.zone,'mana_refunded',1),'{}'::jsonb,p_expected_version);
  return jsonb_build_object('success',true,'match_card_id',p_match_card_id,'state_version',v_version,'mana_refunded',1);
end $$;

create or replace function game_private.enrich_action_card_metadata_v14()
returns trigger language plpgsql security definer set search_path='' as $$
declare v_name text;v_element text;v_rarity text;v_atk integer;v_hp integer;v_zone_label text;v_match_card uuid;v_source_card uuid;
begin
  if new.action_type in('card_played','card_recalled') then
    v_match_card:=nullif(coalesce(new.payload_public->>'match_card_id',new.payload_public->>'card_id'),'')::uuid;
    select d.card_name,d.element,d.rarity,mc.current_power,mc.current_life into v_name,v_element,v_rarity,v_atk,v_hp
    from public.match_cards as mc join public.match_deck_cards as d on d.id=mc.match_deck_card_id where mc.id=v_match_card and mc.match_id=new.match_id;
    v_zone_label:=case new.payload_public->>'destination_zone' when 'attacker' then 'Campo de Ataque' when 'reinforcement' then 'Campo de Reforço' when 'hand' then 'Mão' else coalesce(new.payload_public->>'from_zone','Zona Tática') end;
  elsif new.action_type='card_banned' then
    v_source_card:=nullif(new.payload_public->>'source_card_id','')::uuid;
    select c.name,c.element,c.rarity,c.base_power,c.base_max_life into v_name,v_element,v_rarity,v_atk,v_hp from public.cards as c where c.id=v_source_card;
    v_zone_label:='Zona de Banimento';
  else return new;end if;
  new.payload_public:=new.payload_public||jsonb_build_object('card_name',coalesce(v_name,'Unidade misteriosa nas areias'),'element',coalesce(v_element,'Oculto'),'rarity',coalesce(v_rarity,'desconhecida'),'atk',coalesce(v_atk,0),'hp',coalesce(v_hp,0),'target_zone_label',v_zone_label);
  return new;
end $$;
drop trigger if exists match_actions_enrich_card_metadata_v14 on public.match_actions;
create trigger match_actions_enrich_card_metadata_v14 before insert on public.match_actions for each row execute function game_private.enrich_action_card_metadata_v14();

create or replace view public.visible_match_cards with(security_barrier=true) as
select mc.id,mc.match_id,mc.owner_user_id,mc.controller_user_id,mc.source_card_id,
 case when mc.owner_user_id=auth.uid() or mc.is_face_up or mc.zone in('life','attacker','leader','graveyard','banished') then d.card_name end as card_name,
 case when mc.owner_user_id=auth.uid() or mc.is_face_up or mc.zone in('life','attacker','leader','graveyard','banished') then d.image_url end as image_url,
 case when mc.owner_user_id=auth.uid() or mc.is_face_up or mc.zone in('life','attacker','leader','graveyard','banished') then d.rarity end as rarity,
 case when mc.owner_user_id=auth.uid() or mc.is_face_up or mc.zone in('life','attacker','leader','graveyard','banished') then mc.current_power end as current_power,
 case when mc.owner_user_id=auth.uid() or mc.is_face_up or mc.zone in('life','attacker','leader','graveyard','banished') then mc.maximum_power end as maximum_power,
 case when mc.owner_user_id=auth.uid() or mc.is_face_up or mc.zone in('life','attacker','leader','graveyard','banished') then mc.current_life end as current_life,
 case when mc.owner_user_id=auth.uid() or mc.is_face_up or mc.zone in('life','attacker','leader','graveyard','banished') then mc.maximum_life end as maximum_life,
 mc.zone,case when mc.owner_user_id=auth.uid() or mc.is_face_up or mc.zone in('life','attacker','leader','graveyard','banished') then mc.zone_position end as zone_position,
 mc.is_face_up,mc.is_destroyed,mc.has_attacked_this_turn,mc.entered_zone_turn
from public.match_cards as mc join public.match_deck_cards as d on d.id=mc.match_deck_card_id
where exists(select 1 from public.match_players as mp where mp.match_id=mc.match_id and mp.user_id=auth.uid());
grant select on public.visible_match_cards to authenticated;

revoke all on function public.resolve_pending_card_trigger(uuid,varchar),public.recall_match_card(uuid,uuid,bigint) from public,anon;
grant execute on function public.resolve_pending_card_trigger(uuid,varchar),public.recall_match_card(uuid,uuid,bigint) to authenticated;
notify pgrst,'reload schema';
commit;
