create or replace function game_private.effect_card_cost(p_match_card_id uuid) returns integer language sql stable security definer set search_path='' as $$
 select greatest(0,mdc.effect_mana_cost+coalesce((mc.metadata->>'mana_cost_delta')::integer,0)) from public.match_cards mc join public.match_deck_cards mdc on mdc.id=mc.match_deck_card_id where mc.id=p_match_card_id
$$;

create or replace function game_private.assert_common_effect_source(p_match_id uuid,p_actor uuid,p_source uuid,p_expected_version bigint,p_allow_opponent_turn boolean default false) returns public.match_cards
language plpgsql security definer set search_path='' as $$ declare m public.matches; c public.match_cards; begin
 select * into m from public.matches where id=p_match_id for update;
 if not found then raise exception 'MATCH_NOT_FOUND'; end if;
 if m.state_version<>p_expected_version then raise exception 'STALE_MATCH_VERSION'; end if;
 if m.status<>'in_progress' then raise exception 'INVALID_MATCH_STATUS'; end if;
 if not p_allow_opponent_turn and m.active_player_id<>p_actor then raise exception 'NOT_YOUR_TURN'; end if;
 select * into c from public.match_cards where id=p_source and match_id=p_match_id and controller_user_id=p_actor and current_life>0 and zone in('hand','life','reinforcement','attacker','leader') for update;
 if not found then raise exception 'EFFECT_SOURCE_NOT_AVAILABLE'; end if;
 if coalesce((c.metadata->>'effect_silenced')::boolean,false) then raise exception 'EFFECT_IS_SILENCED'; end if;
 return c;
end $$;

create or replace function game_private.assert_no_global_effect_lock(p_match_id uuid,p_actor uuid,p_source uuid) returns void language plpgsql security definer set search_path='' as $$
declare rarity text; begin
 select d.rarity into rarity from public.match_cards c join public.match_deck_cards d on d.id=c.match_deck_card_id where c.id=p_source;
 if rarity='legendary' and exists(select 1 from public.match_runtime_effects where match_id=p_match_id and active and effect_code='common_jarl_lock_legendary_effects' and target_user_id=p_actor) then raise exception 'LEGENDARY_EFFECTS_LOCKED_BY_JARL'; end if;
end $$;

create or replace function game_private.pay_common_effect_cost(p_match_id uuid,p_actor uuid,p_cost integer) returns void
language plpgsql security definer set search_path='' as $$ begin
 update public.match_players set mana_available=mana_available-p_cost,mana_spent_this_turn=mana_spent_this_turn+p_cost,actions_this_turn=actions_this_turn+1
 where match_id=p_match_id and user_id=p_actor and mana_available>=p_cost;
 if not found then raise exception 'INSUFFICIENT_MANA'; end if;
end $$;

create or replace function game_private.move_card_checked(p_card_id uuid,p_zone text,p_position integer default null,p_face_up boolean default true) returns void
language plpgsql security definer set search_path='' as $$ begin
 if p_zone not in('deck','hand','life','reinforcement','attacker','leader','graveyard','banished','temporary') then raise exception 'INVALID_DESTINATION_ZONE'; end if;
 update public.match_cards set zone=p_zone,zone_position=p_position,is_face_up=p_face_up,is_destroyed=(p_zone='graveyard'),current_life=case when p_zone='graveyard' then 0 else current_life end where id=p_card_id;
 if not found then raise exception 'CARD_NOT_FOUND'; end if;
end $$;
