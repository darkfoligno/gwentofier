-- COMMON_000 bloqueia compras normais somente a partir do turno 1. A distribuição
-- inicial no setup/turno 0 jamais pode abortar o banimento ou a preparação.
create or replace function game_private.guard_common_card_movement() returns trigger
language plpgsql security definer set search_path='' as $$
declare match_status text; match_turn integer;
begin
 select status,current_turn into match_status,match_turn from public.matches where id=old.match_id;
 if old.zone='deck' and new.zone='hand'
    and match_status not in('setup','ban_phase') and coalesce(match_turn,0)>=1
    and exists(
      select 1 from public.match_cards x join public.match_deck_cards d on d.id=x.match_deck_card_id
      where x.match_id=old.match_id and x.owner_user_id=old.owner_user_id and x.zone='hand'
        and d.source_card_id=(select id from public.cards where code='COMMON_000')
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
notify pgrst,'reload schema';
