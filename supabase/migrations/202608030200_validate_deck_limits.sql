-- Update validate_deck to enforce maximum 5 legendary cards
CREATE OR REPLACE FUNCTION public.validate_deck(p_deck_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
    v_owner uuid;
    v_total integer;
    v_golden integer;
    v_legendary integer;
    v_leader uuid;
    v_min integer;
    v_max integer;
    v_errors jsonb := '[]'::jsonb;
begin
    select d.user_id, d.leader_card_id
    into v_owner, v_leader
    from public.decks d
    where d.id = p_deck_id
    for update;

    if not found then
        raise exception 'DECK_NOT_FOUND';
    end if;

    select grv.minimum_deck_cards, grv.maximum_deck_cards
    into v_min, v_max
    from public.game_rule_versions grv
    where grv.is_active = true;

    select
        coalesce(sum(dc.quantity), 0)::integer,
        coalesce(sum(case when c.is_golden then dc.quantity else 0 end), 0)::integer,
        coalesce(sum(case when c.rarity = 'legendary' then dc.quantity else 0 end), 0)::integer
    into v_total, v_golden, v_legendary
    from public.deck_cards dc
    join public.cards c on c.id = dc.card_id
    where dc.deck_id = p_deck_id;

    if v_total < v_min then
        v_errors := v_errors || jsonb_build_array(
            jsonb_build_object('code','DECK_TOO_SMALL','minimum',v_min,'current',v_total)
        );
    end if;

    if v_total > v_max then
        v_errors := v_errors || jsonb_build_array(
            jsonb_build_object('code','DECK_TOO_LARGE','maximum',v_max,'current',v_total)
        );
    end if;

    if v_legendary > 5 then
        v_errors := v_errors || jsonb_build_array(
            jsonb_build_object('code','TOO_MANY_LEGENDARY_CARDS','maximum',5,'current',v_legendary)
        );
    end if;

    if exists (
        select 1
        from public.deck_cards dc
        left join public.user_cards uc
          on uc.user_id = v_owner
         and uc.card_id = dc.card_id
        where dc.deck_id = p_deck_id
          and coalesce(uc.quantity,0) < dc.quantity
    ) then
        v_errors := v_errors || jsonb_build_array(
            jsonb_build_object('code','CARDS_NOT_OWNED')
        );
    end if;

    if exists (
        select 1
        from public.deck_cards dc
        join public.cards c on c.id = dc.card_id
        where dc.deck_id = p_deck_id
          and c.is_active = false
    ) then
        v_errors := v_errors || jsonb_build_array(
            jsonb_build_object('code','INACTIVE_CARD_IN_DECK')
        );
    end if;

    if v_leader is not null and not exists (
        select 1
        from public.cards c
        join public.user_cards uc
          on uc.card_id = c.id
         and uc.user_id = v_owner
         and uc.quantity > 0
        where c.id = v_leader
          and c.card_type = 'leader'
          and c.is_active = true
    ) then
        v_errors := v_errors || jsonb_build_array(
            jsonb_build_object('code','INVALID_OR_UNOWNED_LEADER')
        );
    end if;

    update public.decks
    set total_cards = v_total,
        golden_cards_count = v_golden,
        validation_errors = v_errors,
        is_valid = (jsonb_array_length(v_errors) = 0)
    where id = p_deck_id;

    return jsonb_build_object(
        'is_valid', jsonb_array_length(v_errors) = 0,
        'total_cards', v_total,
        'golden_cards_count', v_golden,
        'errors', v_errors
    );
end;
$function$;
