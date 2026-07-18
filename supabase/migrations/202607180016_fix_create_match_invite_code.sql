-- Corrige create_match em projetos Supabase onde pgcrypto está no schema
-- extensions e gen_random_bytes não fica visível com search_path vazio.
create or replace function public.create_match(
    p_deck_id uuid,
    p_match_type text default 'friendly',
    p_is_private boolean default false
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
    v_user_id uuid := game_private.require_authenticated();
    v_match_id uuid;
    v_rule_id uuid;
    v_golden_count integer;
    v_invite_code text;
begin
    if p_match_type not in ('friendly','ranked','campaign') then
        raise exception 'INVALID_MATCH_TYPE';
    end if;

    if coalesce((select (value #>> '{}')::boolean from public.app_settings where key='maintenance_mode'), false) then
        raise exception 'MAINTENANCE_MODE';
    end if;

    perform public.validate_deck(p_deck_id);

    select golden_cards_count
    into v_golden_count
    from public.decks
    where id = p_deck_id
      and user_id = v_user_id
      and is_valid = true;

    if not found then
        raise exception 'VALID_DECK_REQUIRED';
    end if;

    select id into v_rule_id
    from public.game_rule_versions
    where is_active = true;

    if v_rule_id is null then
        raise exception 'ACTIVE_GAME_RULE_VERSION_REQUIRED';
    end if;

    if p_is_private then
        v_invite_code := upper(substr(replace(gen_random_uuid()::text, '-', ''), 1, 8));
    end if;

    insert into public.matches(
        rule_version_id, match_type, created_by,
        requires_bans, is_private, invite_code
    )
    values (
        v_rule_id, p_match_type, v_user_id,
        (p_match_type = 'ranked' or v_golden_count >= 10),
        p_is_private, v_invite_code
    )
    returning id into v_match_id;

    insert into public.match_players(
        match_id, user_id, player_number, original_deck_id
    )
    values (v_match_id, v_user_id, 1, p_deck_id);

    perform game_private.snapshot_deck(v_match_id, v_user_id, p_deck_id);

    insert into public.match_public_states(
        match_id, player1_user_id, player1_username, player1_avatar_url
    )
    select v_match_id, p.id, p.username, p.avatar_url
    from public.profiles p
    where p.id = v_user_id;

    return v_match_id;
end;
$$;

revoke all on function public.create_match(uuid,text,boolean) from public,anon;
grant execute on function public.create_match(uuid,text,boolean) to authenticated;

-- Força o PostgREST a atualizar a assinatura no cache imediatamente.
notify pgrst, 'reload schema';
