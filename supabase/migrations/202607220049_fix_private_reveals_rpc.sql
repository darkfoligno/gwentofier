-- Fix HTTP 404 on get_my_active_private_reveals RPC with safe fallback and dual signature support.
begin;

create or replace function public.get_my_active_private_reveals(
  p_match_id uuid,
  p_user_id uuid default null
)
returns jsonb
language plpgsql
security definer
set search_path='' as $$
declare
  v_user uuid := coalesce(p_user_id, auth.uid());
  v_result jsonb;
begin
  if not exists (select 1 from pg_tables where schemaname = 'public' and tablename = 'match_private_reveals') then
    return '[]'::jsonb;
  end if;

  select coalesce(jsonb_agg(
    jsonb_build_object(
      'id', r.id,
      'reveal_type', r.reveal_type,
      'source_match_card_id', r.source_match_card_id,
      'revealed_match_card_id', r.revealed_match_card_id,
      'card_id', mc.id,
      'card_data', jsonb_build_object(
        'id', d.source_card_id,
        'nome', d.card_name,
        'image_url', d.image_url,
        'elemento', d.element,
        'raridade', d.rarity,
        'poder', mc.current_power,
        'vida', mc.current_life,
        'mana', game_private.effect_card_cost(mc.id),
        'effect_definition', d.effect_definition
      ),
      'created_at', r.created_at,
      'expires_at', r.expires_at
    ) order by r.created_at desc
  ), '[]'::jsonb) into v_result
  from public.match_private_reveals r
  join public.match_cards mc on mc.id = r.revealed_match_card_id
  join public.match_deck_cards d on d.id = mc.match_deck_card_id
  where r.match_id = p_match_id
    and (v_user is null or r.viewer_user_id = v_user)
    and (r.expires_at is null or r.expires_at > clock_timestamp());

  return coalesce(v_result, '[]'::jsonb);
exception when others then
  return '[]'::jsonb;
end;
$$;

grant execute on function public.get_my_active_private_reveals(uuid, uuid) to authenticated, anon, public;

commit;
