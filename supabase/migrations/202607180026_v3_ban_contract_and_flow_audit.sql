-- V3.0: contrato completo e estritamente filtrado para o banimento.
begin;
create or replace function public.get_match_ban_candidates(p_match_id uuid)
returns jsonb language plpgsql security definer set search_path='' as $$
declare actor uuid:=game_private.require_authenticated();opponent uuid;result jsonb;
begin
 if not exists(select 1 from public.match_players where match_id=p_match_id and user_id=actor)then raise exception 'NOT_A_MATCH_PLAYER';end if;
 select user_id into opponent from public.match_players where match_id=p_match_id and user_id<>actor order by player_number limit 1;if opponent is null then raise exception 'OPPONENT_NOT_FOUND';end if;
 with candidates as(
  select mdc.source_card_id,max(mdc.card_name)name,max(mdc.image_url)image_url,max(mdc.rarity)rarity,max(mdc.card_type)card_type,max(mdc.element)element,max(mdc.base_power)base_power,max(mdc.base_max_life)base_max_life,max(mdc.effect_mana_cost)effect_mana_cost,max(c.effect_text)effect_text,bool_or(mdc.is_golden)is_golden,count(*)::integer copy_count,
   max(case mdc.rarity when 'collab' then 5 when 'legendary' then 4 when 'epic' then 3 when 'rare' then 2 else 1 end)rarity_rank
  from public.match_decks md join public.match_deck_cards mdc on mdc.match_deck_id=md.id join public.cards c on c.id=mdc.source_card_id
  where md.match_id=p_match_id and md.user_id=opponent and not exists(select 1 from public.match_bans mb where mb.match_id=p_match_id and mb.banned_by_user_id=actor and mb.source_card_id=mdc.source_card_id)
  group by mdc.source_card_id
 ),highest as(select max(rarity_rank)rank from candidates)
 select coalesce(jsonb_agg(jsonb_build_object('card_id',c.source_card_id,'name',c.name,'image_url',c.image_url,'rarity',c.rarity,'card_type',c.card_type,'element',c.element,'base_power',c.base_power,'base_max_life',c.base_max_life,'effect_mana_cost',c.effect_mana_cost,'effect_text',c.effect_text,'is_golden',c.is_golden,'copy_count',c.copy_count)order by c.name),'[]'::jsonb)into result from candidates c cross join highest h where c.rarity_rank=h.rank;
 return result;
end $$;
revoke all on function public.get_match_ban_candidates(uuid) from public,anon;
grant execute on function public.get_match_ban_candidates(uuid) to authenticated;
notify pgrst,'reload schema';
commit;
