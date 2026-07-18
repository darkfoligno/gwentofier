-- Um bloqueio de compra é uma regra de jogo, não uma falha transacional. A carta
-- permanece no deck e o encerramento do turno continua normalmente.
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
    ) then return old; end if;
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

create or replace function public.rescue_training_bot_turn(p_match_id uuid,p_expected_version bigint)
returns jsonb language plpgsql security definer set search_path='' as $$
declare human uuid:=game_private.require_authenticated(); bot uuid; m public.matches;
begin
 select bot_user_id into bot from public.training_matches where match_id=p_match_id and human_user_id=human;
 if bot is null then raise exception 'NOT_YOUR_TRAINING_MATCH'; end if;
 select * into m from public.matches where id=p_match_id for update;
 if not found then raise exception 'MATCH_NOT_FOUND'; end if;
 if m.state_version<>p_expected_version then raise exception 'STALE_MATCH_VERSION'; end if;
 if m.status<>'in_progress' then raise exception 'INVALID_MATCH_STATUS'; end if;
 if m.active_player_id<>bot then return jsonb_build_object('rescued',false,'reason','BOT_TURN_ALREADY_FINISHED','state_version',m.state_version); end if;
 return game_private.change_active_turn(p_match_id,bot,
   coalesce((select actions_this_turn=0 from public.match_players where match_id=p_match_id and user_id=bot),true),p_expected_version)
   ||jsonb_build_object('rescued',true);
end $$;
revoke all on function public.rescue_training_bot_turn(uuid,bigint) from public,anon;
grant execute on function public.rescue_training_bot_turn(uuid,bigint) to authenticated;
notify pgrst,'reload schema';
