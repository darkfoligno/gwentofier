-- Update matchmake_now to support generic system-generated decks
CREATE OR REPLACE FUNCTION public.matchmake_now()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
    v_user_id uuid:=game_private.require_authenticated();
    v_own public.matchmaking_queue;
    v_other public.matchmaking_queue;
    v_match_id uuid;
    v_rule_id uuid;
    v_requires boolean;
begin
    select * into v_own from public.matchmaking_queue
    where user_id=v_user_id and status='searching' and expires_at>now()
    order by joined_at desc limit 1 for update;
    if not found then raise exception 'ACTIVE_QUEUE_ENTRY_NOT_FOUND'; end if;

    select * into v_other from public.matchmaking_queue q
    where q.status='searching' and q.expires_at>now() and q.user_id<>v_user_id
      and q.match_type=v_own.match_type
      and abs(q.rating-v_own.rating)<=case when v_own.match_type='ranked' then 300 else 100000 end
    order by abs(q.rating-v_own.rating),q.joined_at
    limit 1 for update skip locked;

    if not found then return jsonb_build_object('matched',false,'queue_id',v_own.id); end if;
    
    if v_other.deck_id <> '00000000-0000-0000-0000-000000000000'::uuid and not exists(select 1 from public.decks where id=v_other.deck_id and user_id=v_other.user_id and is_valid=true) then
        update public.matchmaking_queue set status='cancelled' where id=v_other.id;
        return jsonb_build_object('matched',false,'queue_id',v_own.id);
    end if;

    select id into v_rule_id from public.game_rule_versions where is_active=true;
    select (v_own.match_type='ranked') or exists(
        select 1 from public.decks d where d.id in(v_own.deck_id,v_other.deck_id) and d.golden_cards_count>=10
    ) into v_requires;

    insert into public.matches(
        rule_version_id,match_type,status,created_by,requires_bans,started_at,expires_at
    ) values(v_rule_id,v_own.match_type,case when v_requires then 'ban_phase' else 'setup' end,
        v_own.user_id,v_requires,now(),now()+interval '4 hours')
    returning id into v_match_id;

    insert into public.match_players(match_id,user_id,player_number,original_deck_id)
    values(v_match_id,v_own.user_id,1,v_own.deck_id),(v_match_id,v_other.user_id,2,v_other.deck_id);
    perform game_private.snapshot_deck(v_match_id,v_own.user_id,v_own.deck_id);
    perform game_private.snapshot_deck(v_match_id,v_other.user_id,v_other.deck_id);

    insert into public.match_public_states(
        match_id,player1_user_id,player2_user_id,player1_username,player2_username,
        player1_avatar_url,player2_avatar_url
    )
    select v_match_id,p1.id,p2.id,p1.username,p2.username,p1.avatar_url,p2.avatar_url
    from public.profiles p1 cross join public.profiles p2
    where p1.id=v_own.user_id and p2.id=v_other.user_id;

    update public.matchmaking_queue set status='matched' where id in(v_own.id,v_other.id);
    if not v_requires then perform game_private.deal_initial_hands(v_match_id);
    else perform game_private.recalculate_match_public_state(v_match_id); end if;

    return jsonb_build_object('matched',true,'match_id',v_match_id,'requires_bans',v_requires);
end;
$function$;
