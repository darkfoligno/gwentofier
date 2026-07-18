create or replace function game_private.guard_common_card_movement() returns trigger language plpgsql security definer set search_path='' as $$
begin
 if old.zone='deck' and new.zone='hand' and exists(
  select 1 from public.match_cards x join public.match_deck_cards d on d.id=x.match_deck_card_id
  where x.match_id=old.match_id and x.owner_user_id=old.owner_user_id and x.zone='hand' and d.source_card_id=(select id from public.cards where code='COMMON_000')
 ) then raise exception 'DRAW_BLOCKED_BY_COMMON_000'; end if;
 if old.zone='graveyard' and new.zone in('hand','life','reinforcement','attacker','leader') and exists(
  select 1 from public.match_cards x join public.match_deck_cards d on d.id=x.match_deck_card_id
  where x.match_id=old.match_id and x.zone in('life','reinforcement','attacker','leader') and x.current_life>0 and d.source_card_id=(select id from public.cards where code='COMMON_002')
 ) then raise exception 'GRAVEYARD_RETURN_BLOCKED_BY_DUNY'; end if;
 if coalesce((old.metadata->>'hand_locked')::boolean,false) and old.zone='hand' and new.zone<>'hand' then
  if new.zone<>'graveyard' or not coalesce((old.metadata->>'allow_overflow_to_graveyard')::boolean,false) then raise exception 'CURSED_HAND_CARD_CANNOT_MOVE'; end if;
 end if;
 if coalesce((old.metadata->>'effect_cost_immune')::boolean,false) then
  if new.metadata->>'mana_cost_delta' is distinct from old.metadata->>'mana_cost_delta' or new.metadata->>'effect_silenced' is distinct from old.metadata->>'effect_silenced' then raise exception 'CARD_EFFECT_AND_COST_ARE_PROTECTED'; end if;
 end if;
 return new;
end $$;
drop trigger if exists match_cards_common_movement_guard on public.match_cards;
create trigger match_cards_common_movement_guard before update of zone,metadata on public.match_cards for each row execute function game_private.guard_common_card_movement();

create or replace function game_private.consume_turn_runtime_effects() returns trigger language plpgsql security definer set search_path='' as $$
declare rt record; next_actor uuid; begin
 if new.action_type not in('turn_ended','turn_passed_without_action','turn_passed') then return new; end if;
 select active_player_id into next_actor from public.matches where id=new.match_id;
 for rt in select * from public.match_runtime_effects where match_id=new.match_id and active and (expires_on_turn is null or expires_on_turn<=coalesce((new.payload_public->>'new_turn')::integer,starts_on_turn)) for update loop
  if rt.effect_code='common_milton_return_turn_end' then
   if (select count(*) from public.match_cards where match_id=new.match_id and owner_user_id=rt.owner_user_id and zone='hand')<10 then update public.match_cards set zone='hand',zone_position=null,is_face_up=false where id=rt.source_match_card_id and zone not in('graveyard','banished'); end if;
  elsif rt.effect_code='common_nekker_next_turn_mana' and next_actor=rt.owner_user_id then
   update public.match_players set mana_available=mana_available+coalesce((rt.payload->>'amount')::integer,1),mana_snapshot=mana_snapshot+coalesce((rt.payload->>'amount')::integer,1) where match_id=new.match_id and user_id=rt.owner_user_id;
  elsif rt.scope='next_turn' and next_actor=rt.owner_user_id then null;
  else continue;
  end if;
  update public.match_runtime_effects set active=false,consumed_at=now() where id=rt.id;
 end loop;
 update public.match_runtime_effects set active=false,consumed_at=coalesce(consumed_at,now()) where match_id=new.match_id and active and expires_on_turn is not null and expires_on_turn<coalesce((new.payload_public->>'new_turn')::integer,0);
 return new;
end $$;
drop trigger if exists match_actions_consume_runtime_effects on public.match_actions;
create trigger match_actions_consume_runtime_effects after insert on public.match_actions for each row execute function game_private.consume_turn_runtime_effects();

-- Bloqueios globais de ativação são verificados antes do RPC v2.
create or replace function game_private.assert_no_global_effect_lock(p_match_id uuid,p_actor uuid,p_source uuid) returns void language plpgsql security definer set search_path='' as $$
declare rarity text; begin
 select d.rarity into rarity from public.match_cards c join public.match_deck_cards d on d.id=c.match_deck_card_id where c.id=p_source;
 if rarity='legendary' and exists(select 1 from public.match_runtime_effects where match_id=p_match_id and active and effect_code='common_jarl_lock_legendary_effects' and target_user_id=p_actor) then raise exception 'LEGENDARY_EFFECTS_LOCKED_BY_JARL'; end if;
end $$;
