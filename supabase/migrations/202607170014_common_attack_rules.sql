create or replace function game_private.enforce_common_attack_rules() returns trigger language plpgsql security definer set search_path='' as $$
declare pa public.pending_attacks; actor uuid; code text; hand_count integer; common_count integer; power_sum integer; cid uuid; begin
 select * into pa from public.pending_attacks where id=new.pending_attack_id for update;
 actor:=pa.attacker_user_id;
 select c.code into code from public.match_cards mc join public.cards c on c.id=mc.source_card_id where mc.id=new.match_card_id;
 if code='COMMON_003' then
  select count(*),count(*) filter(where d.rarity='common') into hand_count,common_count from public.match_cards mc join public.match_deck_cards d on d.id=mc.match_deck_card_id where mc.match_id=pa.match_id and mc.owner_user_id=actor and mc.zone='hand';
  if hand_count=0 or hand_count<>common_count then raise exception 'JAVALI_REQUIRES_NONEMPTY_COMMON_ONLY_HAND'; end if;
  update public.pending_attacks set result=result||'{"suppress_reinforcement_reveal":true,"suppress_reinforcement_reaction":true}' where id=pa.id;
 elsif code='COMMON_007' and pa.is_direct then
  if (select count(*) from public.match_cards where match_id=pa.match_id and owner_user_id=actor and zone='graveyard')<5 then raise exception 'DAY_WRAITH_REQUIRES_FIVE_GRAVEYARD_CARDS'; end if;
 elsif code='COMMON_022' and pa.is_direct then
  if (select count(*) from public.match_cards where match_id=pa.match_id and owner_user_id=actor and zone='hand') <= (select count(*) from public.match_cards where match_id=pa.match_id and owner_user_id=pa.defender_user_id and zone='hand') then raise exception 'PANTHER_REQUIRES_HAND_ADVANTAGE'; end if;
 elsif code='COMMON_024' and pa.is_direct then
  if (select count(*) from public.match_cards where match_id=pa.match_id and owner_user_id=actor and zone='hand')<3 then raise exception 'CLEAVER_REQUIRES_THREE_DISCARDS'; end if;
  for cid in select id from public.match_cards where match_id=pa.match_id and owner_user_id=actor and zone='hand' order by random() limit 3 loop perform game_private.move_card_checked(cid,'graveyard',null,true); end loop;
 elsif code='COMMON_048' and pa.is_direct then
  if (select count(*) from public.match_cards mc where mc.match_id=pa.match_id and mc.owner_user_id=actor and mc.zone='hand' and game_private.effect_card_cost(mc.id)>0)>0 then raise exception 'VES_REQUIRES_NO_OTHER_PAID_HAND_CARD'; end if;
 elsif code='COMMON_056' and pa.is_direct then
  if not exists(select 1 from public.match_cards mc join public.match_deck_cards d on d.id=mc.match_deck_card_id where mc.match_id=pa.match_id and mc.owner_user_id=actor and mc.zone='life' and mc.current_life>0 and d.element='Bestiário') then raise exception 'WILD_DOG_REQUIRES_ACTIVE_BESTIARY_LIFE'; end if;
 elsif code='COMMON_057' then
  select coalesce(sum(mc.current_power),0) into power_sum from public.match_cards mc join public.match_deck_cards d on d.id=mc.match_deck_card_id where mc.match_id=pa.match_id and mc.owner_user_id=actor and mc.zone='deck' and d.card_name='Harpia';
  update public.pending_attack_cards set power_when_declared=power_when_declared+power_sum where pending_attack_id=pa.id and match_card_id=new.match_card_id;
  update public.pending_attacks set declared_power=declared_power+power_sum,result=result||'{"force_farthest_life":true}' where id=pa.id;
 end if;
 return new;
end $$;
drop trigger if exists pending_attack_cards_common_rules on public.pending_attack_cards;
create trigger pending_attack_cards_common_rules after insert on public.pending_attack_cards for each row execute function game_private.enforce_common_attack_rules();
