-- ============================================================================
-- GWENT OFIERI — ENGINE DE COMBATE, MIGRAÇÕES 1 A 9
-- Arquivo consolidado das consultas executadas no Supabase.
-- Pré-requisito: gwent_ofieri_supabase_final.sql
-- Inclui as versões corrigidas dos blocos 4, 5, 8 e 9.
-- ============================================================================



-- ============================================================================
-- 1. NOVAS COLUNAS, REGRAS E TABELAS DA ENGINE DE COMBATE
-- ============================================================================

begin;

alter table public.game_rule_versions
    add column if not exists reaction_window_seconds integer not null default 20;

alter table public.game_rule_versions
    drop constraint if exists game_rule_versions_reaction_window_check;

alter table public.game_rule_versions
    add constraint game_rule_versions_reaction_window_check
    check (reaction_window_seconds between 5 and 120);

alter table public.match_players
    add column if not exists paid_effect_used_this_turn boolean not null default false,
    add column if not exists free_effect_used_this_turn boolean not null default false;

update public.game_rule_versions
set replacement_defense_losses_required = 1,
    replacement_defense_before_turn = 4,
    ban_categories = '["legendary_golden"]'::jsonb,
    reaction_window_seconds = 20,
    rules = coalesce(rules, '{}'::jsonb)
        || jsonb_build_object(
            'normal_attack_overflows_reinforcements', true,
            'normal_attack_never_overflows_between_life_cards', true,
            'reinforcements_are_face_down', true,
            'reinforcements_reveal_only_when_hit', true,
            'active_player_paid_effect_limit', 1,
            'active_player_free_effect_limit', 1,
            'defender_reaction_limit', 1,
            'ban_only_one_golden_legendary', true
        )
where is_active = true;

alter table public.match_bans
    drop constraint if exists match_bans_category_check;

alter table public.match_bans
    add constraint match_bans_category_check
    check (
        ban_category in (
            'rare',
            'epic',
            'legendary',
            'collab',
            'leader',
            'legendary_golden'
        )
    );

create table if not exists public.pending_attacks (
    id uuid primary key default gen_random_uuid(),
    match_id uuid not null references public.matches(id) on delete cascade,
    attacker_user_id uuid not null references public.profiles(id) on delete restrict,
    defender_user_id uuid not null references public.profiles(id) on delete restrict,
    status text not null default 'awaiting_reaction',
    is_direct boolean not null default false,
    declared_power integer not null default 0,
    resolved_power integer,
    damage_remaining_after_resolution integer,
    reaction_deadline timestamptz not null,
    reaction_completed_at timestamptz,
    resolved_at timestamptz,
    declared_state_version bigint not null,
    resolved_state_version bigint,
    result jsonb not null default '{}'::jsonb,
    created_at timestamptz not null default now(),
    constraint pending_attacks_status_check check (
        status in (
            'awaiting_reaction',
            'reaction_used',
            'reaction_declined',
            'resolving',
            'resolved',
            'cancelled',
            'expired'
        )
    ),
    constraint pending_attacks_players_check check (
        attacker_user_id <> defender_user_id
    ),
    constraint pending_attacks_power_check check (
        declared_power >= 0
        and (resolved_power is null or resolved_power >= 0)
        and (
            damage_remaining_after_resolution is null
            or damage_remaining_after_resolution >= 0
        )
    )
);

create table if not exists public.pending_attack_cards (
    pending_attack_id uuid not null
        references public.pending_attacks(id) on delete cascade,
    match_card_id uuid not null
        references public.match_cards(id) on delete cascade,
    attack_position integer not null,
    power_when_declared integer not null,
    primary key (pending_attack_id, match_card_id),
    unique (pending_attack_id, attack_position),
    constraint pending_attack_cards_position_check check (attack_position >= 1),
    constraint pending_attack_cards_power_check check (power_when_declared >= 0)
);

create unique index if not exists pending_attacks_one_active_per_match_uidx
    on public.pending_attacks(match_id)
    where status in (
        'awaiting_reaction',
        'reaction_used',
        'reaction_declined',
        'resolving'
    );

create index if not exists pending_attacks_match_idx
    on public.pending_attacks(match_id, created_at desc);

create index if not exists pending_attacks_deadline_idx
    on public.pending_attacks(reaction_deadline)
    where status = 'awaiting_reaction';

create index if not exists pending_attack_cards_attack_idx
    on public.pending_attack_cards(pending_attack_id, attack_position);

alter table public.pending_attacks enable row level security;
alter table public.pending_attack_cards enable row level security;

drop policy if exists pending_attacks_participant_read on public.pending_attacks;

create policy pending_attacks_participant_read
on public.pending_attacks
for select
to authenticated
using (
    public.is_admin()
    or attacker_user_id = auth.uid()
    or defender_user_id = auth.uid()
);

drop policy if exists pending_attack_cards_participant_read
on public.pending_attack_cards;

create policy pending_attack_cards_participant_read
on public.pending_attack_cards
for select
to authenticated
using (
    public.is_admin()
    or exists (
        select 1
        from public.pending_attacks pa
        where pa.id = pending_attack_cards.pending_attack_id
          and (
              pa.attacker_user_id = auth.uid()
              or pa.defender_user_id = auth.uid()
          )
    )
);

revoke insert, update, delete, truncate, references, trigger
on public.pending_attacks, public.pending_attack_cards
from anon, authenticated;

grant select
on public.pending_attacks, public.pending_attack_cards
to authenticated;

grant all
on public.pending_attacks, public.pending_attack_cards
to service_role;

do $$
begin
    if not exists (
        select 1
        from pg_publication_tables
        where pubname = 'supabase_realtime'
          and schemaname = 'public'
          and tablename = 'pending_attacks'
    ) then
        alter publication supabase_realtime add table public.pending_attacks;
    end if;
end
$$;

alter table public.pending_attacks replica identity full;

commit;


-- ============================================================================
-- 2. BANIMENTO DE UMA ÚNICA CARTA LENDÁRIA DOURADA
-- ============================================================================

begin;

create or replace function public.get_match_ban_candidates(p_match_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
    v_user_id uuid := game_private.require_authenticated();
    v_target_id uuid;
    v_result jsonb;
begin
    if not exists (
        select 1 from public.match_players
        where match_id = p_match_id and user_id = v_user_id
    ) then
        raise exception 'NOT_A_MATCH_PLAYER';
    end if;

    select user_id into v_target_id
    from public.match_players
    where match_id = p_match_id and user_id <> v_user_id
    order by player_number
    limit 1;

    if v_target_id is null then
        raise exception 'OPPONENT_NOT_FOUND';
    end if;

    select coalesce(
        jsonb_agg(
            jsonb_build_object(
                'card_id', candidates.source_card_id,
                'name', candidates.card_name,
                'image_url', candidates.image_url,
                'rarity', candidates.rarity,
                'is_golden', candidates.is_golden,
                'copy_count', candidates.copy_count
            )
            order by candidates.card_name
        ),
        '[]'::jsonb
    )
    into v_result
    from (
        select
            mdc.source_card_id,
            max(mdc.card_name) as card_name,
            max(mdc.image_url) as image_url,
            max(mdc.rarity) as rarity,
            bool_or(mdc.is_golden) as is_golden,
            count(*)::integer as copy_count
        from public.match_decks md
        join public.match_deck_cards mdc on mdc.match_deck_id = md.id
        where md.match_id = p_match_id
          and md.user_id = v_target_id
          and mdc.rarity = 'legendary'
          and mdc.is_golden = true
          and not exists (
              select 1
              from public.match_bans mb
              where mb.match_id = p_match_id
                and mb.banned_by_user_id = v_user_id
          )
        group by mdc.source_card_id
    ) candidates;

    return v_result;
end;
$$;

create or replace function public.submit_match_ban(
    p_match_id uuid,
    p_source_card_id uuid,
    p_ban_category text default 'legendary_golden',
    p_expected_version bigint default 0
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
    v_user_id uuid := game_private.require_authenticated();
    v_match public.matches;
    v_target_id uuid;
    v_candidate_exists boolean;
    v_all_complete boolean;
    v_player_count integer;
    v_ban_count integer;
    v_new_version bigint;
begin
    v_match := game_private.lock_match_for_action(
        p_match_id, p_expected_version, array['ban_phase']
    );

    if p_ban_category <> 'legendary_golden' then
        raise exception 'ONLY_GOLDEN_LEGENDARY_BAN_IS_ALLOWED';
    end if;

    if exists (
        select 1 from public.match_bans
        where match_id = p_match_id and banned_by_user_id = v_user_id
    ) then
        raise exception 'BAN_ALREADY_SUBMITTED';
    end if;

    select user_id into v_target_id
    from public.match_players
    where match_id = p_match_id and user_id <> v_user_id
    order by player_number
    limit 1;

    if v_target_id is null then
        raise exception 'OPPONENT_NOT_FOUND';
    end if;

    select exists (
        select 1
        from public.match_decks md
        join public.match_deck_cards mdc on mdc.match_deck_id = md.id
        where md.match_id = p_match_id
          and md.user_id = v_target_id
          and mdc.rarity = 'legendary'
          and mdc.is_golden = true
    ) into v_candidate_exists;

    if not v_candidate_exists then
        if p_source_card_id is not null then
            raise exception 'NO_GOLDEN_LEGENDARY_AVAILABLE';
        end if;

        insert into public.match_bans (
            match_id, banned_by_user_id, target_user_id,
            source_card_id, ban_category, is_skipped
        )
        values (
            p_match_id, v_user_id, v_target_id,
            null, 'legendary_golden', true
        );
    else
        if p_source_card_id is null then
            raise exception 'BAN_SELECTION_REQUIRED';
        end if;

        if not exists (
            select 1
            from public.match_decks md
            join public.match_deck_cards mdc on mdc.match_deck_id = md.id
            where md.match_id = p_match_id
              and md.user_id = v_target_id
              and mdc.source_card_id = p_source_card_id
              and mdc.rarity = 'legendary'
              and mdc.is_golden = true
        ) then
            raise exception 'INVALID_GOLDEN_LEGENDARY_CARD';
        end if;

        insert into public.match_bans (
            match_id, banned_by_user_id, target_user_id,
            source_card_id, ban_category, is_skipped
        )
        values (
            p_match_id, v_user_id, v_target_id,
            p_source_card_id, 'legendary_golden', false
        );

        update public.match_cards
        set zone = 'banished', zone_position = null, is_face_up = true
        where match_id = p_match_id
          and owner_user_id = v_target_id
          and source_card_id = p_source_card_id
          and zone = 'deck';
    end if;

    select count(*) into v_player_count
    from public.match_players where match_id = p_match_id;

    select count(*) into v_ban_count
    from public.match_bans where match_id = p_match_id;

    v_all_complete := (v_player_count = 2 and v_ban_count = 2);

    v_new_version := game_private.record_match_action(
        p_match_id,
        v_user_id,
        'card_banned',
        jsonb_build_object(
            'target_user_id', v_target_id,
            'category', 'legendary_golden',
            'source_card_id', p_source_card_id,
            'skipped', p_source_card_id is null,
            'ban_phase_complete', v_all_complete
        ),
        '{}'::jsonb,
        p_expected_version
    );

    if v_all_complete then
        perform game_private.deal_initial_hands(p_match_id);
    end if;

    return jsonb_build_object(
        'ban_phase_complete', v_all_complete,
        'state_version', v_new_version
    );
end;
$$;

revoke all on function public.get_match_ban_candidates(uuid) from public, anon;
revoke all on function public.submit_match_ban(uuid,uuid,text,bigint) from public, anon;
grant execute on function public.get_match_ban_candidates(uuid) to authenticated;
grant execute on function public.submit_match_ban(uuid,uuid,text,bigint) to authenticated;

commit;


-- ============================================================================
-- 3. LIMITES DE EFEITOS E REAÇÃO
-- ============================================================================

begin;

create or replace function game_private.validate_match_effect_use()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
    v_pending public.pending_attacks;
begin
    if new.is_reaction then
        select *
        into v_pending
        from public.pending_attacks
        where match_id = new.match_id
          and defender_user_id = new.actor_user_id
          and status = 'awaiting_reaction'
          and reaction_deadline > now()
        order by created_at desc
        limit 1
        for update;

        if not found then
            raise exception 'NO_OPEN_REACTION_WINDOW';
        end if;

        if exists (
            select 1
            from public.match_effect_uses meu
            where meu.match_id = new.match_id
              and meu.actor_user_id = new.actor_user_id
              and meu.turn_number = new.turn_number
              and meu.is_reaction = true
        ) then
            raise exception 'REACTION_ALREADY_USED';
        end if;

        update public.match_players
        set reaction_used_this_opponent_turn = true
        where match_id = new.match_id and user_id = new.actor_user_id;

        update public.pending_attacks
        set status = 'reaction_used', reaction_completed_at = now()
        where id = v_pending.id;

        return new;
    end if;

    if new.mana_spent = 0 then
        if exists (
            select 1
            from public.match_effect_uses meu
            where meu.match_id = new.match_id
              and meu.actor_user_id = new.actor_user_id
              and meu.turn_number = new.turn_number
              and meu.is_reaction = false
              and meu.mana_spent = 0
        ) then
            raise exception 'FREE_EFFECT_ALREADY_USED_THIS_TURN';
        end if;

        update public.match_players
        set free_effect_used_this_turn = true
        where match_id = new.match_id and user_id = new.actor_user_id;
    else
        if exists (
            select 1
            from public.match_effect_uses meu
            where meu.match_id = new.match_id
              and meu.actor_user_id = new.actor_user_id
              and meu.turn_number = new.turn_number
              and meu.is_reaction = false
              and meu.mana_spent > 0
        ) then
            raise exception 'PAID_EFFECT_ALREADY_USED_THIS_TURN';
        end if;

        update public.match_players
        set paid_effect_used_this_turn = true
        where match_id = new.match_id and user_id = new.actor_user_id;
    end if;

    return new;
end;
$$;

drop trigger if exists validate_match_effect_use_trigger
on public.match_effect_uses;

create trigger validate_match_effect_use_trigger
before insert on public.match_effect_uses
for each row
execute function game_private.validate_match_effect_use();

commit;


-- ============================================================================
-- 4. COMPRA AUTOMÁTICA DO PRIMEIRO TURNO E DETERIORAÇÃO DO TURNO 8
-- ============================================================================

begin;

drop trigger if exists draw_first_turn_card_trigger
on public.matches;

drop function if exists game_private.draw_first_turn_card();

drop function if exists game_private.apply_match_deterioration(uuid, integer);

create function game_private.apply_match_deterioration(
    p_match_id uuid,
    p_turn integer
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
    v_start_turn integer;
    v_mode text;
begin
    select
        grv.deterioration_start_turn,
        grv.deterioration_mode
    into
        v_start_turn,
        v_mode
    from public.matches m
    join public.game_rule_versions grv
      on grv.id = m.rule_version_id
    where m.id = p_match_id;

    if not found then
        raise exception 'MATCH_OR_RULE_VERSION_NOT_FOUND';
    end if;

    if p_turn <> v_start_turn
       or v_mode <> 'halve_life_once' then
        return;
    end if;

    update public.match_cards
    set
        maximum_life = greatest(
            1,
            floor(maximum_life * 0.5)::integer
        ),
        current_life = least(
            current_life,
            greatest(
                1,
                floor(maximum_life * 0.5)::integer
            )
        )
    where match_id = p_match_id
      and zone in (
          'deck',
          'hand',
          'life',
          'reinforcement',
          'attacker',
          'leader',
          'graveyard',
          'temporary'
      );

    perform game_private.recalculate_match_public_state(p_match_id);
end;
$$;

create function game_private.draw_first_turn_card()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
    if new.status = 'in_progress'
       and new.current_turn = 1
       and new.active_player_id is not null
       and (
            old.status is distinct from 'in_progress'
            or old.current_turn is distinct from 1
            or old.active_player_id is distinct from new.active_player_id
       )
    then
        perform game_private.draw_internal(
            new.id,
            new.active_player_id,
            1
        );

        update public.match_players
        set
            mana_spent_this_turn = 0,
            actions_this_turn = 0,
            paid_effect_used_this_turn = false,
            free_effect_used_this_turn = false,
            reaction_used_this_opponent_turn = false,
            life_destroyed_this_turn = false,
            passed_turn = false
        where match_id = new.id
          and user_id = new.active_player_id;

        perform game_private.recalculate_match_public_state(new.id);
    end if;

    return new;
end;
$$;

create trigger draw_first_turn_card_trigger
after update of status, current_turn, active_player_id
on public.matches
for each row
execute function game_private.draw_first_turn_card();

commit;


-- ============================================================================
-- 5. DECLARAÇÃO DE ATAQUE EM GRUPO E JANELA DE REAÇÃO
-- ============================================================================

begin;

drop function if exists public.declare_attack(
    uuid,
    uuid,
    uuid,
    boolean,
    bigint
);

drop function if exists public.declare_attack(
    uuid,
    uuid[],
    boolean,
    bigint
);

drop function if exists public.decline_attack_reaction(
    uuid,
    bigint
);

create function public.declare_attack(
    p_match_id uuid,
    p_attacker_card_ids uuid[],
    p_is_direct boolean default false,
    p_expected_version bigint default 0
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
    v_user_id uuid := game_private.require_authenticated();
    v_match public.matches;
    v_defender_user_id uuid;
    v_attack_id uuid;
    v_total_power integer;
    v_max_attackers integer;
    v_reaction_seconds integer;
    v_count integer;
    v_distinct_count integer;
    v_new_version bigint;
    v_direct_allowed boolean := false;
    v_deadline timestamptz;
begin
    v_match := game_private.lock_match_for_action(
        p_match_id,
        p_expected_version,
        array['in_progress']
    );

    if v_match.active_player_id <> v_user_id then
        raise exception 'NOT_YOUR_TURN';
    end if;

    if exists (
        select 1
        from public.pending_attacks
        where match_id = p_match_id
          and status in (
              'awaiting_reaction',
              'reaction_used',
              'reaction_declined',
              'resolving'
          )
    ) then
        raise exception 'ANOTHER_ATTACK_IS_PENDING';
    end if;

    v_count := coalesce(cardinality(p_attacker_card_ids), 0);

    if v_count < 1 then
        raise exception 'AT_LEAST_ONE_ATTACKER_REQUIRED';
    end if;

    select count(distinct selected.card_id)
    into v_distinct_count
    from unnest(p_attacker_card_ids) as selected(card_id);

    if v_distinct_count <> v_count then
        raise exception 'DUPLICATED_ATTACKER';
    end if;

    select
        grv.max_cards_declared_per_attack,
        grv.reaction_window_seconds
    into
        v_max_attackers,
        v_reaction_seconds
    from public.game_rule_versions grv
    where grv.id = v_match.rule_version_id;

    if v_count > v_max_attackers then
        raise exception 'TOO_MANY_ATTACKERS';
    end if;

    if exists (
        select 1
        from unnest(p_attacker_card_ids) as selected(card_id)
        where not exists (
            select 1
            from public.match_cards mc
            where mc.id = selected.card_id
              and mc.match_id = p_match_id
              and mc.controller_user_id = v_user_id
              and mc.zone = 'attacker'
              and mc.current_life > 0
              and mc.can_attack = true
              and mc.has_attacked_this_turn = false
        )
    ) then
        raise exception 'INVALID_ATTACKER_SELECTION';
    end if;

    if p_is_direct then
        if v_count <> 1 then
            raise exception 'DIRECT_ATTACK_REQUIRES_ONE_ATTACKER';
        end if;

        select exists (
            select 1
            from public.match_cards mc
            join public.match_deck_cards mdc
              on mdc.id = mc.match_deck_card_id
            cross join lateral jsonb_array_elements(
                coalesce(mdc.effect_definition, '[]'::jsonb)
            ) as effect(value)
            where mc.id = p_attacker_card_ids[1]
              and (
                  effect.value ->> 'effect_code'
                      in ('direct_attack', 'attack_direct')
                  or coalesce(
                      (
                          effect.value
                          -> 'parameters'
                          ->> 'ignore_reinforcement'
                      )::boolean,
                      false
                  )
              )
        )
        into v_direct_allowed;

        if not v_direct_allowed then
            raise exception 'ATTACKER_HAS_NO_DIRECT_ATTACK_EFFECT';
        end if;
    end if;

    select mp.user_id
    into v_defender_user_id
    from public.match_players mp
    where mp.match_id = p_match_id
      and mp.user_id <> v_user_id
    order by mp.player_number
    limit 1;

    if v_defender_user_id is null then
        raise exception 'OPPONENT_NOT_FOUND';
    end if;

    select coalesce(sum(mc.current_power), 0)::integer
    into v_total_power
    from public.match_cards mc
    where mc.id = any(p_attacker_card_ids);

    v_deadline := now() + make_interval(
        secs => v_reaction_seconds
    );

    insert into public.pending_attacks (
        match_id,
        attacker_user_id,
        defender_user_id,
        status,
        is_direct,
        declared_power,
        reaction_deadline,
        declared_state_version
    )
    values (
        p_match_id,
        v_user_id,
        v_defender_user_id,
        'awaiting_reaction',
        p_is_direct,
        v_total_power,
        v_deadline,
        p_expected_version
    )
    returning id into v_attack_id;

    insert into public.pending_attack_cards (
        pending_attack_id,
        match_card_id,
        attack_position,
        power_when_declared
    )
    select
        v_attack_id,
        selected.card_id,
        selected.position::integer,
        mc.current_power
    from unnest(p_attacker_card_ids)
        with ordinality as selected(card_id, position)
    join public.match_cards mc
      on mc.id = selected.card_id;

    update public.match_cards
    set metadata = metadata || jsonb_build_object(
        'locked_for_pending_attack',
        v_attack_id
    )
    where id = any(p_attacker_card_ids);

    update public.match_players
    set actions_this_turn = actions_this_turn + 1
    where match_id = p_match_id
      and user_id = v_user_id;

    v_new_version := game_private.record_match_action(
        p_match_id,
        v_user_id,
        'attack_declared',
        jsonb_build_object(
            'pending_attack_id', v_attack_id,
            'attacker_user_id', v_user_id,
            'defender_user_id', v_defender_user_id,
            'attacker_card_ids', to_jsonb(p_attacker_card_ids),
            'total_power', v_total_power,
            'is_direct', p_is_direct,
            'reaction_deadline', v_deadline
        ),
        '{}'::jsonb,
        p_expected_version
    );

    update public.pending_attacks
    set declared_state_version = v_new_version
    where id = v_attack_id;

    perform game_private.recalculate_match_public_state(p_match_id);

    return jsonb_build_object(
        'pending_attack_id', v_attack_id,
        'total_power', v_total_power,
        'reaction_deadline', v_deadline,
        'state_version', v_new_version
    );
end;
$$;

create function public.decline_attack_reaction(
    p_pending_attack_id uuid,
    p_expected_version bigint
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
    v_user_id uuid := game_private.require_authenticated();
    v_attack public.pending_attacks;
    v_new_version bigint;
begin
    select *
    into v_attack
    from public.pending_attacks
    where id = p_pending_attack_id
    for update;

    if not found then
        raise exception 'PENDING_ATTACK_NOT_FOUND';
    end if;

    perform game_private.lock_match_for_action(
        v_attack.match_id,
        p_expected_version,
        array['in_progress']
    );

    if v_attack.defender_user_id <> v_user_id then
        raise exception 'ONLY_DEFENDER_MAY_DECLINE_REACTION';
    end if;

    if v_attack.status <> 'awaiting_reaction' then
        raise exception 'REACTION_WINDOW_NOT_OPEN';
    end if;

    update public.pending_attacks
    set
        status = 'reaction_declined',
        reaction_completed_at = now()
    where id = p_pending_attack_id;

    v_new_version := game_private.record_match_action(
        v_attack.match_id,
        v_user_id,
        'reaction_declined',
        jsonb_build_object(
            'pending_attack_id',
            p_pending_attack_id
        ),
        '{}'::jsonb,
        p_expected_version
    );

    return jsonb_build_object(
        'pending_attack_id', p_pending_attack_id,
        'status', 'reaction_declined',
        'state_version', v_new_version
    );
end;
$$;

revoke all
on function public.declare_attack(
    uuid,
    uuid[],
    boolean,
    bigint
)
from public, anon;

revoke all
on function public.decline_attack_reaction(
    uuid,
    bigint
)
from public, anon;

grant execute
on function public.declare_attack(
    uuid,
    uuid[],
    boolean,
    bigint
)
to authenticated;

grant execute
on function public.decline_attack_reaction(
    uuid,
    bigint
)
to authenticated;

commit;


-- ============================================================================
-- 6. RESOLUÇÃO DO ATAQUE, REFORÇOS EM ORDEM E DANO EXCEDENTE
-- ============================================================================

begin;

create or replace function game_private.resolve_pending_attack_internal(
    p_pending_attack_id uuid,
    p_actor_user_id uuid,
    p_expected_version bigint
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
    v_attack public.pending_attacks;
    v_match public.matches;
    v_card record;
    v_life_card public.match_cards;
    v_total_power integer;
    v_remaining_damage integer;
    v_card_life_before integer;
    v_damage_result jsonb;
    v_reinforcement_results jsonb := '[]'::jsonb;
    v_life_result jsonb := null;
    v_attacker_ids uuid[];
    v_life_remaining integer;
    v_match_finished boolean := false;
    v_new_version bigint;
begin
    select * into v_attack
    from public.pending_attacks
    where id = p_pending_attack_id
    for update;

    if not found then raise exception 'PENDING_ATTACK_NOT_FOUND'; end if;

    select * into v_match
    from public.matches
    where id = v_attack.match_id
    for update;

    if v_match.state_version <> p_expected_version then
        raise exception 'STALE_MATCH_VERSION';
    end if;

    if v_match.status <> 'in_progress' then
        raise exception 'INVALID_MATCH_STATUS';
    end if;

    if v_attack.status not in (
        'awaiting_reaction', 'reaction_used', 'reaction_declined'
    ) then
        raise exception 'ATTACK_CANNOT_BE_RESOLVED';
    end if;

    if v_attack.status = 'awaiting_reaction'
       and v_attack.reaction_deadline > now() then
        raise exception 'REACTION_WINDOW_STILL_OPEN';
    end if;

    update public.pending_attacks
    set status = 'resolving'
    where id = p_pending_attack_id;

    select
        array_agg(pac.match_card_id order by pac.attack_position),
        coalesce(sum(mc.current_power), 0)::integer
    into v_attacker_ids, v_total_power
    from public.pending_attack_cards pac
    join public.match_cards mc on mc.id = pac.match_card_id
    where pac.pending_attack_id = p_pending_attack_id
      and mc.match_id = v_attack.match_id
      and mc.controller_user_id = v_attack.attacker_user_id
      and mc.zone = 'attacker'
      and mc.current_life > 0;

    if coalesce(cardinality(v_attacker_ids), 0) = 0 then
        raise exception 'NO_VALID_ATTACKERS_REMAIN';
    end if;

    v_remaining_damage := v_total_power;

    if not v_attack.is_direct then
        for v_card in
            select *
            from public.match_cards
            where match_id = v_attack.match_id
              and controller_user_id = v_attack.defender_user_id
              and zone = 'reinforcement'
              and current_life > 0
            order by zone_position
            for update
        loop
            exit when v_remaining_damage <= 0;

            update public.match_cards
            set is_face_up = true
            where id = v_card.id;

            v_card_life_before := v_card.current_life;

            v_damage_result := game_private.apply_damage_internal(
                v_attack.match_id,
                v_card.id,
                v_remaining_damage,
                v_match.current_turn
            );

            v_remaining_damage := greatest(
                0, v_remaining_damage - v_card_life_before
            );

            v_reinforcement_results :=
                v_reinforcement_results || jsonb_build_array(
                    jsonb_build_object(
                        'card_id', v_card.id,
                        'position', v_card.zone_position,
                        'life_before', v_card_life_before,
                        'result', v_damage_result,
                        'remaining_damage', v_remaining_damage
                    )
                );

            if coalesce(
                (v_damage_result ->> 'destroyed')::boolean, false
            ) = false then
                v_remaining_damage := 0;
                exit;
            end if;
        end loop;
    end if;

    if v_remaining_damage > 0 then
        select * into v_life_card
        from public.match_cards
        where match_id = v_attack.match_id
          and controller_user_id = v_attack.defender_user_id
          and zone = 'life'
          and current_life > 0
        order by zone_position
        limit 1
        for update;

        if found then
            v_card_life_before := v_life_card.current_life;

            v_damage_result := game_private.apply_damage_internal(
                v_attack.match_id,
                v_life_card.id,
                v_remaining_damage,
                v_match.current_turn
            );

            v_life_result := jsonb_build_object(
                'card_id', v_life_card.id,
                'position', v_life_card.zone_position,
                'life_before', v_card_life_before,
                'damage_received', least(v_remaining_damage, v_card_life_before),
                'discarded_overflow', greatest(
                    0, v_remaining_damage - v_card_life_before
                ),
                'result', v_damage_result
            );

            if coalesce(
                (v_damage_result ->> 'destroyed')::boolean, false
            ) then
                update public.match_players
                set destroyed_life_count = destroyed_life_count + 1
                where match_id = v_attack.match_id
                  and user_id = v_attack.defender_user_id;

                update public.match_players
                set life_destroyed_this_turn = true
                where match_id = v_attack.match_id
                  and user_id = v_attack.attacker_user_id;
            end if;

            v_remaining_damage := 0;
        end if;
    end if;

    update public.match_cards
    set zone = 'graveyard',
        zone_position = null,
        is_face_up = true,
        has_attacked_this_turn = true,
        metadata = metadata - 'locked_for_pending_attack'
    where id = any(v_attacker_ids);

    select count(*)::integer into v_life_remaining
    from public.match_cards
    where match_id = v_attack.match_id
      and controller_user_id = v_attack.defender_user_id
      and zone = 'life'
      and current_life > 0;

    v_match_finished := v_life_remaining = 0;

    update public.pending_attacks
    set status = 'resolved',
        resolved_power = v_total_power,
        damage_remaining_after_resolution = v_remaining_damage,
        resolved_at = now(),
        result = jsonb_build_object(
            'attackers', v_attacker_ids,
            'total_power', v_total_power,
            'reinforcements', v_reinforcement_results,
            'life', v_life_result,
            'defender_life_remaining', v_life_remaining,
            'match_finished', v_match_finished
        )
    where id = p_pending_attack_id;

    v_new_version := game_private.record_match_action(
        v_attack.match_id,
        p_actor_user_id,
        'attack_resolved',
        jsonb_build_object(
            'pending_attack_id', p_pending_attack_id,
            'attacker_user_id', v_attack.attacker_user_id,
            'defender_user_id', v_attack.defender_user_id,
            'attacker_card_ids', v_attacker_ids,
            'total_power', v_total_power,
            'is_direct', v_attack.is_direct,
            'reinforcements', v_reinforcement_results,
            'life', v_life_result,
            'defender_life_remaining', v_life_remaining,
            'match_finished', v_match_finished
        ),
        '{}'::jsonb,
        p_expected_version
    );

    update public.pending_attacks
    set resolved_state_version = v_new_version
    where id = p_pending_attack_id;

    if v_match_finished then
        perform game_private.finish_match(
            v_attack.match_id,
            v_attack.attacker_user_id,
            'all_life_cards_destroyed'
        );
    end if;

    return jsonb_build_object(
        'pending_attack_id', p_pending_attack_id,
        'attackers', v_attacker_ids,
        'total_power', v_total_power,
        'reinforcements', v_reinforcement_results,
        'life', v_life_result,
        'defender_life_remaining', v_life_remaining,
        'match_finished', v_match_finished,
        'winner_id',
            case when v_match_finished
                 then v_attack.attacker_user_id
                 else null end,
        'state_version', v_new_version
    );
end;
$$;

create or replace function public.resolve_pending_attack(
    p_pending_attack_id uuid,
    p_expected_version bigint
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
    v_user_id uuid := game_private.require_authenticated();
    v_attack public.pending_attacks;
begin
    select * into v_attack
    from public.pending_attacks
    where id = p_pending_attack_id;

    if not found then raise exception 'PENDING_ATTACK_NOT_FOUND'; end if;

    if v_user_id not in (
        v_attack.attacker_user_id,
        v_attack.defender_user_id
    ) then
        raise exception 'NOT_A_MATCH_PLAYER';
    end if;

    return game_private.resolve_pending_attack_internal(
        p_pending_attack_id,
        v_user_id,
        p_expected_version
    );
end;
$$;

revoke all on function public.resolve_pending_attack(uuid,bigint)
from public, anon;

grant execute on function public.resolve_pending_attack(uuid,bigint)
to authenticated;

commit;


-- ============================================================================
-- 7. ENCERRAR TURNO E PASSAR SEM REALIZAR AÇÕES
-- ============================================================================

begin;

create or replace function game_private.change_active_turn(
    p_match_id uuid,
    p_user_id uuid,
    p_pass_without_action boolean,
    p_expected_version bigint
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
    v_match public.matches;
    v_next_user_id uuid;
    v_new_turn integer;
    v_actions integer;
    v_new_version bigint;
    v_player1_id uuid;
    v_player2_id uuid;
    v_player1_life integer;
    v_player2_life integer;
    v_winner_id uuid;
begin
    select * into v_match
    from public.matches
    where id = p_match_id
    for update;

    if not found then raise exception 'MATCH_NOT_FOUND'; end if;
    if v_match.state_version <> p_expected_version then
        raise exception 'STALE_MATCH_VERSION';
    end if;
    if v_match.status <> 'in_progress' then
        raise exception 'INVALID_MATCH_STATUS';
    end if;
    if v_match.active_player_id <> p_user_id then
        raise exception 'NOT_YOUR_TURN';
    end if;

    if exists (
        select 1
        from public.pending_attacks
        where match_id = p_match_id
          and status in (
              'awaiting_reaction',
              'reaction_used',
              'reaction_declined',
              'resolving'
          )
    ) then
        raise exception 'PENDING_ATTACK_MUST_BE_RESOLVED';
    end if;

    select actions_this_turn into v_actions
    from public.match_players
    where match_id = p_match_id and user_id = p_user_id
    for update;

    if p_pass_without_action and coalesce(v_actions, 0) <> 0 then
        raise exception 'CANNOT_PASS_AFTER_ACTION';
    end if;

    if p_pass_without_action then
        perform game_private.draw_internal(p_match_id, p_user_id, 1);
    end if;

    select user_id into v_next_user_id
    from public.match_players
    where match_id = p_match_id and user_id <> p_user_id
    order by player_number
    limit 1;

    if v_next_user_id is null then raise exception 'OPPONENT_NOT_FOUND'; end if;

    update public.match_cards
    set zone = 'graveyard',
        zone_position = null,
        is_face_up = true,
        has_attacked_this_turn = true,
        metadata = metadata - 'locked_for_pending_attack'
    where match_id = p_match_id
      and controller_user_id = p_user_id
      and zone = 'attacker';

    update public.match_cards
    set has_attacked_this_turn = false
    where match_id = p_match_id;

    v_new_turn := v_match.current_turn + 1;

    perform game_private.apply_match_deterioration(p_match_id, v_new_turn);

    select user_id into v_player1_id
    from public.match_players
    where match_id = p_match_id and player_number = 1;

    select user_id into v_player2_id
    from public.match_players
    where match_id = p_match_id and player_number = 2;

    select count(*)::integer into v_player1_life
    from public.match_cards
    where match_id = p_match_id
      and controller_user_id = v_player1_id
      and zone = 'life'
      and current_life > 0;

    select count(*)::integer into v_player2_life
    from public.match_cards
    where match_id = p_match_id
      and controller_user_id = v_player2_id
      and zone = 'life'
      and current_life > 0;

    if v_player1_life = 0 or v_player2_life = 0 then
        v_winner_id := case
            when v_player1_life > 0 then v_player1_id
            when v_player2_life > 0 then v_player2_id
            else null
        end;

        v_new_version := game_private.record_match_action(
            p_match_id,
            p_user_id,
            'deterioration_resolved',
            jsonb_build_object(
                'turn', v_new_turn,
                'winner_id', v_winner_id
            ),
            '{}'::jsonb,
            p_expected_version
        );

        perform game_private.finish_match(
            p_match_id,
            v_winner_id,
            'life_destroyed_by_turn_8_deterioration'
        );

        return jsonb_build_object(
            'match_finished', true,
            'winner_id', v_winner_id,
            'state_version', v_new_version
        );
    end if;

    update public.match_players
    set reaction_used_this_opponent_turn = false,
        passed_turn = (
            user_id = p_user_id and p_pass_without_action
        ),
        mana_spent_this_turn = case
            when user_id = v_next_user_id then 0
            else mana_spent_this_turn end,
        actions_this_turn = case
            when user_id = v_next_user_id then 0
            else actions_this_turn end,
        life_destroyed_this_turn = case
            when user_id = v_next_user_id then false
            else life_destroyed_this_turn end,
        paid_effect_used_this_turn = case
            when user_id = v_next_user_id then false
            else paid_effect_used_this_turn end,
        free_effect_used_this_turn = case
            when user_id = v_next_user_id then false
            else free_effect_used_this_turn end
    where match_id = p_match_id;

    update public.matches
    set current_turn = v_new_turn,
        active_player_id = v_next_user_id
    where id = p_match_id;

    perform game_private.draw_internal(p_match_id, v_next_user_id, 1);

    v_new_version := game_private.record_match_action(
        p_match_id,
        p_user_id,
        case
            when p_pass_without_action
            then 'turn_passed_without_action'
            else 'turn_ended'
        end,
        jsonb_build_object(
            'previous_player_id', p_user_id,
            'new_turn', v_new_turn,
            'active_player_id', v_next_user_id,
            'pass_without_action', p_pass_without_action,
            'next_player_drew_card', true,
            'passing_player_drew_card', p_pass_without_action
        ),
        '{}'::jsonb,
        p_expected_version
    );

    return jsonb_build_object(
        'match_finished', false,
        'new_turn', v_new_turn,
        'active_player_id', v_next_user_id,
        'state_version', v_new_version
    );
end;
$$;

create or replace function public.end_turn(
    p_match_id uuid,
    p_expected_version bigint
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
    v_user_id uuid := game_private.require_authenticated();
begin
    return game_private.change_active_turn(
        p_match_id, v_user_id, false, p_expected_version
    );
end;
$$;

create or replace function public.pass_without_action(
    p_match_id uuid,
    p_expected_version bigint
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
    v_user_id uuid := game_private.require_authenticated();
begin
    return game_private.change_active_turn(
        p_match_id, v_user_id, true, p_expected_version
    );
end;
$$;

revoke all on function public.pass_turn(uuid,bigint)
from public, anon, authenticated;

revoke all on function public.end_turn(uuid,bigint)
from public, anon;

revoke all on function public.pass_without_action(uuid,bigint)
from public, anon;

grant execute on function public.end_turn(uuid,bigint)
to authenticated;

grant execute on function public.pass_without_action(uuid,bigint)
to authenticated;

commit;


-- ============================================================================
-- 8. REPOSIÇÃO DE CARTA DE VIDA APÓS UMA DESTRUIÇÃO ANTES DO TURNO 4
-- ============================================================================

begin;

drop function if exists public.replace_early_life_card(
    uuid,
    uuid,
    integer,
    bigint
);

update public.game_rule_versions
set replacement_defense_losses_required = 1,
    replacement_defense_before_turn = 4
where is_active = true;

create function public.replace_early_life_card(
    p_match_id uuid,
    p_match_card_id uuid,
    p_life_position integer,
    p_expected_version bigint
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
    v_user_id uuid := game_private.require_authenticated();
    v_match public.matches;
    v_card public.match_cards;
    v_card_data public.match_deck_cards;
    v_player public.match_players;
    v_life_slots integer;
    v_before_turn integer;
    v_losses_required integer;
    v_new_version bigint;
begin
    v_match := game_private.lock_match_for_action(
        p_match_id, p_expected_version, array['in_progress']
    );

    select * into v_player
    from public.match_players
    where match_id = p_match_id and user_id = v_user_id
    for update;

    if not found then raise exception 'NOT_A_MATCH_PLAYER'; end if;

    select
        life_slots,
        replacement_defense_before_turn,
        replacement_defense_losses_required
    into
        v_life_slots,
        v_before_turn,
        v_losses_required
    from public.game_rule_versions
    where id = v_match.rule_version_id;

    if v_match.current_turn >= v_before_turn then
        raise exception 'DEFENSE_REPLACEMENT_WINDOW_CLOSED';
    end if;

    if v_player.defense_replacement_used then
        raise exception 'DEFENSE_REPLACEMENT_ALREADY_USED';
    end if;

    if v_player.destroyed_life_count < v_losses_required then
        raise exception 'NOT_ENOUGH_DESTROYED_LIFE_CARDS';
    end if;

    if p_life_position is null
       or p_life_position < 1
       or p_life_position > v_life_slots then
        raise exception 'INVALID_LIFE_POSITION';
    end if;

    if exists (
        select 1 from public.match_cards
        where match_id = p_match_id
          and controller_user_id = v_user_id
          and zone = 'life'
          and zone_position = p_life_position
          and current_life > 0
    ) then
        raise exception 'LIFE_SLOT_ALREADY_OCCUPIED';
    end if;

    select * into v_card
    from public.match_cards
    where id = p_match_card_id
      and match_id = p_match_id
      and owner_user_id = v_user_id
      and controller_user_id = v_user_id
      and zone = 'hand'
    for update;

    if not found then raise exception 'CARD_NOT_IN_YOUR_HAND'; end if;

    select * into v_card_data
    from public.match_deck_cards
    where id = v_card.match_deck_card_id;

    if not found then raise exception 'MATCH_CARD_SNAPSHOT_NOT_FOUND'; end if;

    if v_card_data.card_type = 'leader' then
        raise exception 'LEADER_CANNOT_BE_LIFE_CARD';
    end if;

    if v_card_data.rarity = 'legendary'
       and exists (
            select 1
            from public.match_cards mc
            join public.match_deck_cards mdc
              on mdc.id = mc.match_deck_card_id
            where mc.match_id = p_match_id
              and mc.controller_user_id = v_user_id
              and mc.zone in ('life','reinforcement','attacker')
              and mc.current_life > 0
              and mdc.rarity = 'legendary'
       ) then
        raise exception 'LEGENDARY_FIELD_LIMIT_REACHED';
    end if;

    update public.match_cards
    set zone = 'life',
        zone_position = p_life_position,
        is_face_up = true,
        entered_zone_turn = v_match.current_turn,
        is_destroyed = false,
        destroyed_at_turn = null,
        current_life = greatest(1, current_life)
    where id = p_match_card_id;

    update public.match_players
    set defense_replacement_used = true,
        actions_this_turn = actions_this_turn + case
            when v_match.active_player_id = v_user_id then 1
            else 0 end
    where match_id = p_match_id and user_id = v_user_id;

    v_new_version := game_private.record_match_action(
        p_match_id,
        v_user_id,
        'early_life_card_replaced',
        jsonb_build_object(
            'player_user_id', v_user_id,
            'card_id', p_match_card_id,
            'life_position', p_life_position
        ),
        '{}'::jsonb,
        p_expected_version
    );

    perform game_private.recalculate_match_public_state(p_match_id);

    return jsonb_build_object(
        'card_id', p_match_card_id,
        'life_position', p_life_position,
        'state_version', v_new_version
    );
end;
$$;

revoke all on function public.replace_early_life_card(
    uuid, uuid, integer, bigint
) from public, anon;

grant execute on function public.replace_early_life_card(
    uuid, uuid, integer, bigint
) to authenticated;

commit;


-- ============================================================================
-- 9. CRON PARA RESOLVER ATAQUES COM TEMPO DE REAÇÃO EXPIRADO
-- ============================================================================

begin;

drop function if exists public.resolve_expired_pending_attacks();

create function public.resolve_expired_pending_attacks()
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
    v_attack record;
    v_resolved integer := 0;
    v_failed integer := 0;
begin
    for v_attack in
        select
            pa.id,
            pa.attacker_user_id,
            m.state_version
        from public.pending_attacks pa
        join public.matches m on m.id = pa.match_id
        where pa.status = 'awaiting_reaction'
          and pa.reaction_deadline <= now()
          and m.status = 'in_progress'
        order by pa.reaction_deadline
        for update of pa skip locked
    loop
        begin
            perform game_private.resolve_pending_attack_internal(
                v_attack.id,
                v_attack.attacker_user_id,
                v_attack.state_version
            );
            v_resolved := v_resolved + 1;
        exception
            when others then
                v_failed := v_failed + 1;
                update public.pending_attacks
                set result = coalesce(result, '{}'::jsonb)
                    || jsonb_build_object(
                        'last_resolution_error', sqlerrm,
                        'last_resolution_attempt_at', now()
                    )
                where id = v_attack.id;
        end;
    end loop;

    return jsonb_build_object(
        'resolved', v_resolved,
        'failed', v_failed,
        'ran_at', now()
    );
end;
$$;

revoke all on function public.resolve_expired_pending_attacks()
from public, anon, authenticated;

grant execute on function public.resolve_expired_pending_attacks()
to service_role;

do $$
declare
    v_job_id bigint;
begin
    if to_regnamespace('cron') is null
       or to_regclass('cron.job') is null then
        raise notice 'PG_CRON_NOT_AVAILABLE';
        return;
    end if;

    select jobid into v_job_id
    from cron.job
    where jobname = 'resolve-expired-card-attacks'
    limit 1;

    if v_job_id is not null then
        perform cron.unschedule(v_job_id);
    end if;

    perform cron.schedule(
        'resolve-expired-card-attacks',
        '* * * * *',
        'select public.resolve_expired_pending_attacks();'
    );
end;
$$;

commit;
