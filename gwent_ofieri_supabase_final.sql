
-- ============================================================================
-- GWENT OFIERI / CARD GAME ONLINE
-- MIGRAÇÃO DE RECONSTRUÇÃO COMPLETA — SUPABASE / POSTGRES
-- Versão: 2.1.0
--
-- ATENÇÃO:
-- 1) ESTE SCRIPT É DESTRUTIVO PARA AS TABELAS DO JOGO.
-- 2) ELE NÃO APAGA auth.users.
-- 3) ELE REMOVE AS TABELAS/FUNÇÕES/POLÍTICAS CRIADAS PELO SQL ANTIGO.
-- 4) USE PRIMEIRO EM PROJETO DE DESENVOLVIMENTO OU APÓS BACKUP.
-- 5) MANTENHA O BANCO EM UTC. Datas operacionais usam America/Sao_Paulo.
-- ============================================================================

begin;

-- ============================================================================
-- 0. EXTENSÕES
-- ============================================================================

create extension if not exists pgcrypto;

-- pg_cron é útil, mas não deve impedir toda a instalação caso a extensão
-- esteja temporariamente indisponível no projeto/região. A criação do job
-- também é protegida mais abaixo.
do $extension$
begin
    begin
        execute 'create extension if not exists pg_cron';
    exception
        when others then
            raise notice 'pg_cron não pôde ser ativado agora: %', sqlerrm;
    end;
end
$extension$;

-- ============================================================================
-- 1. LIMPEZA SEGURA DO SQL ANTIGO DO GEMINI E DESTA PRÓPRIA MIGRAÇÃO
-- ============================================================================

-- Remove somente as tabelas do jogo da publicação Realtime, sem apagar
-- a publicação inteira nem prejudicar outras tabelas do projeto.
do $$
declare
    v_table text;
begin
    if exists (select 1 from pg_publication where pubname = 'supabase_realtime') then
        foreach v_table in array array[
            'profiles','cards','user_cards','decks','matches','campaign_progress',
            'match_public_states','match_players','match_actions','notifications'
        ]
        loop
            if exists (
                select 1
                from pg_publication_tables
                where pubname = 'supabase_realtime'
                  and schemaname = 'public'
                  and tablename = v_table
            ) then
                execute format(
                    'alter publication supabase_realtime drop table public.%I',
                    v_table
                );
            end if;
        end loop;
    end if;
end
$$;

-- Remove trigger antigo ligado ao Supabase Auth.
drop trigger if exists on_auth_user_created on auth.users;

-- Remove funções antigas e funções desta migração, se existirem.
drop function if exists public.handle_new_user() cascade;
drop function if exists public.update_modified_column() cascade;
drop function if exists public.set_updated_at() cascade;
drop function if exists public.is_admin() cascade;
drop function if exists public.update_my_profile(text,text) cascade;
drop function if exists public.create_deck(text,uuid) cascade;
drop function if exists public.replace_deck_cards(uuid,jsonb) cascade;
drop function if exists public.delete_my_deck(uuid) cascade;
drop function if exists public.claim_daily_reward(uuid) cascade;
drop function if exists public.purchase_and_open_pack(uuid,uuid) cascade;
drop function if exists public.create_match(uuid,text,boolean) cascade;
drop function if exists public.join_match(uuid,uuid) cascade;
drop function if exists public.submit_match_setup(uuid,jsonb,jsonb,uuid) cascade;
drop function if exists public.finish_match_setup(uuid) cascade;
drop function if exists public.ban_match_card(uuid,uuid,text) cascade;
drop function if exists public.pass_turn(uuid,bigint) cascade;
drop function if exists public.surrender_match(uuid,bigint) cascade;
drop function if exists public.cleanup_expired_game_data() cascade;
drop function if exists public.admin_grant_cards(uuid,uuid,integer,text,text) cascade;
drop function if exists public.admin_adjust_coins(uuid,bigint,text,text) cascade;
drop function if exists public.create_starter_inventory(uuid) cascade;
drop function if exists public.recalculate_match_public_state(uuid) cascade;
drop function if exists public.validate_deck(uuid) cascade;
drop function if exists public.apply_card_damage(uuid,uuid,integer,bigint) cascade;
drop function if exists public.heal_match_card(uuid,uuid,integer,bigint) cascade;
drop function if exists public.move_match_card(uuid,uuid,text,smallint,bigint) cascade;
drop function if exists public.draw_match_cards(uuid,smallint,integer,bigint) cascade;
drop function if exists public.declare_attack(uuid,uuid,uuid,bigint) cascade;
drop function if exists public.declare_attack(uuid,uuid,uuid,boolean,bigint) cascade;
drop function if exists public.play_match_card(uuid,uuid,text,integer,bigint) cascade;
drop function if exists public.activate_match_effect(uuid,uuid,integer,uuid,bigint) cascade;
drop function if exists public.replace_early_life_card(uuid,uuid,integer,bigint) cascade;
drop function if exists public.update_deck_metadata(uuid,text,uuid,boolean) cascade;
drop function if exists public.mark_cards_seen(uuid[]) cascade;
drop function if exists public.cancel_waiting_match(uuid,bigint) cascade;
drop function if exists public.mark_notifications_read(uuid) cascade;

-- Remove schema interno e todos os objetos dependentes.
drop schema if exists game_private cascade;

-- Remove views antes das tabelas.
drop view if exists public.my_wallet cascade;
drop view if exists public.my_stats cascade;
drop view if exists public.my_match_cards cascade;
drop view if exists public.visible_match_cards cascade;
drop view if exists public.visible_match_actions cascade;

-- Remove tabelas na ordem inversa de dependências.
drop table if exists public.admin_audit_log cascade;
drop table if exists public.notifications cascade;
drop table if exists public.story_unlocks cascade;
drop table if exists public.story_chapters cascade;
drop table if exists public.campaign_attempts cascade;
drop table if exists public.campaign_progress cascade;
drop table if exists public.campaign_boss_deck_cards cascade;
drop table if exists public.campaign_bosses cascade;
drop table if exists public.match_rewards cascade;
drop table if exists public.match_effect_uses cascade;
drop table if exists public.match_reactions cascade;
drop table if exists public.match_bans cascade;
drop table if exists public.match_actions cascade;
drop table if exists public.match_card_modifiers cascade;
drop table if exists public.match_cards cascade;
drop table if exists public.match_deck_cards cascade;
drop table if exists public.match_decks cascade;
drop table if exists public.match_players cascade;
drop table if exists public.match_public_states cascade;
drop table if exists public.matches cascade;
drop table if exists public.matchmaking_queue cascade;
drop table if exists public.deck_cards cascade;
drop table if exists public.decks cascade;
drop table if exists public.daily_claims cascade;
drop table if exists public.starter_grants cascade;
drop table if exists public.pack_balance_transactions cascade;
drop table if exists public.user_pack_balances cascade;
drop table if exists public.pack_opening_results cascade;
drop table if exists public.pack_openings cascade;
drop table if exists public.pack_drop_rules cascade;
drop table if exists public.pack_types cascade;
drop table if exists public.inventory_transactions cascade;
drop table if exists public.user_cards cascade;
drop table if exists public.wallet_transactions cascade;
drop table if exists public.player_wallets cascade;
drop table if exists public.player_stats cascade;
drop table if exists public.card_effects cascade;
drop table if exists public.cards cascade;
drop table if exists public.card_sets cascade;
drop table if exists public.game_rule_versions cascade;
drop table if exists public.app_settings cascade;
drop table if exists public.user_roles cascade;
drop table if exists public.profiles cascade;

-- Tabelas antigas que podem ter sobrado.
drop table if exists public.campaign_progress cascade;
drop table if exists public.user_cards cascade;
drop table if exists public.cards cascade;
drop table if exists public.decks cascade;
drop table if exists public.matches cascade;
drop table if exists public.profiles cascade;

-- ============================================================================
-- 2. SCHEMA INTERNO NÃO EXPOSTO DIRETAMENTE PELA API
-- ============================================================================

create schema game_private;
revoke all on schema game_private from public, anon, authenticated;
grant usage on schema game_private to service_role;

-- ============================================================================
-- 3. FUNÇÕES UTILITÁRIAS
-- ============================================================================

create or replace function public.set_updated_at()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
    new.updated_at := now();
    return new;
end;
$$;

create or replace function game_private.current_game_date()
returns date
language sql
stable
set search_path = ''
as $$
    select (now() at time zone 'America/Sao_Paulo')::date;
$$;

create or replace function game_private.require_authenticated()
returns uuid
language plpgsql
stable
set search_path = ''
as $$
declare
    v_user_id uuid := auth.uid();
begin
    if v_user_id is null then
        raise exception 'AUTH_REQUIRED' using errcode = '42501';
    end if;
    return v_user_id;
end;
$$;

-- ============================================================================
-- 4. PERFIL, PAPÉIS, CARTEIRA E ESTATÍSTICAS
-- ============================================================================

create table public.profiles (
    id uuid primary key references auth.users(id) on delete cascade,
    username text not null,
    avatar_url text,
    bio text,
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now(),
    constraint profiles_username_length check (char_length(username) between 3 and 24),
    constraint profiles_username_format check (username ~ '^[A-Za-zÀ-ÿ0-9_ -]+$'),
    constraint profiles_bio_length check (bio is null or char_length(bio) <= 300)
);

create unique index profiles_username_ci_uidx
    on public.profiles (lower(username));

create table public.user_roles (
    user_id uuid not null references public.profiles(id) on delete cascade,
    role text not null,
    granted_at timestamptz not null default now(),
    granted_by uuid references public.profiles(id) on delete set null,
    primary key (user_id, role),
    constraint user_roles_role_check
        check (role in ('player','moderator','content_editor','game_master','admin'))
);

create table public.player_wallets (
    user_id uuid primary key references public.profiles(id) on delete cascade,
    coins bigint not null default 150,
    updated_at timestamptz not null default now(),
    constraint player_wallets_coins_nonnegative check (coins >= 0)
);

create table public.player_stats (
    user_id uuid primary key references public.profiles(id) on delete cascade,
    wins integer not null default 0,
    losses integer not null default 0,
    draws integer not null default 0,
    ranked_rating integer not null default 1000,
    campaign_wins integer not null default 0,
    current_win_streak integer not null default 0,
    best_win_streak integer not null default 0,
    last_match_at timestamptz,
    updated_at timestamptz not null default now(),
    constraint player_stats_nonnegative check (
        wins >= 0 and losses >= 0 and draws >= 0
        and campaign_wins >= 0
        and current_win_streak >= 0
        and best_win_streak >= 0
    )
);

create table public.wallet_transactions (
    id uuid primary key default gen_random_uuid(),
    user_id uuid not null references public.profiles(id) on delete cascade,
    amount bigint not null,
    balance_before bigint not null,
    balance_after bigint not null,
    transaction_type text not null,
    reference_type text,
    reference_id uuid,
    idempotency_key uuid,
    description text,
    created_at timestamptz not null default now(),
    constraint wallet_transactions_balance_check check (
        balance_before >= 0
        and balance_after >= 0
        and balance_after = balance_before + amount
    ),
    constraint wallet_transactions_type_check check (
        transaction_type in (
            'initial_balance','match_reward','campaign_reward',
            'pack_purchase','daily_reward','admin_adjustment',
            'refund','promotion'
        )
    )
);

create unique index wallet_transactions_user_idempotency_uidx
    on public.wallet_transactions(user_id, idempotency_key)
    where idempotency_key is not null;

create index wallet_transactions_user_created_idx
    on public.wallet_transactions(user_id, created_at desc);

create or replace function public.is_admin()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
    select exists (
        select 1
        from public.user_roles ur
        where ur.user_id = auth.uid()
          and ur.role = 'admin'
    );
$$;

revoke all on function public.is_admin() from public;
grant execute on function public.is_admin() to anon, authenticated, service_role;

-- ============================================================================
-- 5. CONFIGURAÇÃO E VERSIONAMENTO DAS REGRAS
-- ============================================================================

create table public.app_settings (
    key text primary key,
    value jsonb not null,
    description text,
    updated_at timestamptz not null default now(),
    updated_by uuid references public.profiles(id) on delete set null
);

create table public.game_rule_versions (
    id uuid primary key default gen_random_uuid(),
    version_name text not null unique,
    is_active boolean not null default false,
    minimum_deck_cards integer not null default 40,
    maximum_deck_cards integer not null default 120,
    initial_hand_size integer not null default 7,
    maximum_hand_size integer not null default 10,
    life_slots integer not null default 3,
    reinforcement_slots integer not null default 4,
    attacker_slots integer not null default 4,
    max_cards_declared_per_attack integer not null default 5,
    stat_cap integer not null default 20000,
    deterioration_start_turn integer not null default 8,
    deterioration_mode text not null default 'halve_life_once',
    deterioration_percent numeric(5,2),
    initiative_mode text not null default 'coin_flip',
    replacement_defense_before_turn integer not null default 4,
    replacement_defense_losses_required integer not null default 2,
    leader_swap_cooldown_turns integer not null default 2,
    ban_categories jsonb not null default '["rare","epic","legendary","collab","leader"]'::jsonb,
    rules jsonb not null default '{}'::jsonb,
    created_at timestamptz not null default now(),
    constraint game_rule_versions_deck_limits check (
        minimum_deck_cards >= 1
        and maximum_deck_cards >= minimum_deck_cards
    ),
    constraint game_rule_versions_slots check (
        initial_hand_size >= 1
        and maximum_hand_size >= initial_hand_size
        and life_slots >= 1
        and reinforcement_slots >= 0
        and attacker_slots >= 1
    ),
    constraint game_rule_versions_stat_cap check (stat_cap between 1 and 1000000),
    constraint game_rule_versions_deterioration_mode_check check (
        deterioration_mode in (
            'none','halve_life_once','percent_life_each_turn',
            'percent_power_and_life_each_turn'
        )
    ),
    constraint game_rule_versions_initiative_mode_check check (
        initiative_mode in ('coin_flip','d20')
    )
);

create unique index game_rule_versions_one_active_uidx
    on public.game_rule_versions ((is_active))
    where is_active = true;

insert into public.game_rule_versions (
    version_name,
    is_active,
    minimum_deck_cards,
    maximum_deck_cards,
    initial_hand_size,
    maximum_hand_size,
    life_slots,
    reinforcement_slots,
    attacker_slots,
    max_cards_declared_per_attack,
    stat_cap,
    deterioration_start_turn,
    deterioration_mode,
    deterioration_percent,
    initiative_mode,
    rules
)
values (
    'ofieri-1.0',
    true,
    40,
    120,
    7,
    10,
    3,
    4,
    4,
    5,
    20000,
    8,
    'halve_life_once',
    50,
    'coin_flip',
    jsonb_build_object(
        'direct_attacks_ignore_reinforcements', true,
        'one_reaction_per_opponent_turn', true,
        'random_choice_when_unspecified', true,
        'attacker_goes_to_graveyard_after_attack', true,
        'only_one_life_card_destroyed_per_attack', true,
        'legendary_limit_on_field', 1,
        'golden_deck_ban_threshold', 10
    )
);

insert into public.app_settings(key, value, description)
values
('game_timezone', '"America/Sao_Paulo"'::jsonb, 'Fuso usado para recompensas diárias.'),
('maintenance_mode', 'false'::jsonb, 'Bloqueia novas partidas quando verdadeiro.'),
('daily_pack_no_duel_cards', '4'::jsonb, 'Cartas do pacote diário sem duelos.'),
('daily_pack_duel_cards', '8'::jsonb, 'Cartas do pacote diário em dias com duelo.'),
('daily_makeup_max_days', '30'::jsonb, 'Máximo de dias perdidos convertidos em 2 cartas de recuperação por solicitação.');

-- ============================================================================
-- 6. CATÁLOGO DE CARTAS, COLEÇÕES E EFEITOS
-- ============================================================================

create table public.card_sets (
    id uuid primary key default gen_random_uuid(),
    code text not null unique,
    name text not null,
    description text,
    is_collab boolean not null default false,
    is_active boolean not null default true,
    release_date date,
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now()
);

create table public.cards (
    id uuid primary key default gen_random_uuid(),
    set_id uuid references public.card_sets(id) on delete restrict,
    code text not null unique,
    name text not null,
    image_url text not null,
    element text not null,
    rarity text not null,
    card_type text not null default 'normal',
    is_golden boolean not null default false,
    is_original_rpg boolean not null default false,
    base_power integer not null default 0,
    base_max_life integer not null default 0,
    effect_mana_cost integer not null default 0,
    tier integer not null default 1,
    leader_cooldown integer not null default 0,
    effect_text text,
    lore_text text,
    is_active boolean not null default true,
    version integer not null default 1,
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now(),
    constraint cards_rarity_check check (
        rarity in ('common','rare','epic','legendary')
    ),
    constraint cards_type_check check (
        card_type in ('normal','leader')
    ),
    constraint cards_power_check check (base_power between 0 and 20000),
    constraint cards_life_check check (base_max_life between 1 and 20000),
    constraint cards_mana_check check (effect_mana_cost >= 0),
    constraint cards_tier_check check (tier >= 1),
    constraint cards_cooldown_check check (leader_cooldown >= 0)
);

create index cards_set_idx on public.cards(set_id);
create index cards_active_rarity_idx on public.cards(is_active, rarity);
create index cards_type_idx on public.cards(card_type);
create index cards_golden_idx on public.cards(is_golden) where is_golden = true;
create index cards_original_rpg_idx on public.cards(is_original_rpg) where is_original_rpg = true;

create table public.card_effects (
    id uuid primary key default gen_random_uuid(),
    card_id uuid not null references public.cards(id) on delete cascade,
    effect_order smallint not null default 1,
    trigger_type text not null,
    effect_code text not null,
    target_mode text not null default 'none',
    parameters jsonb not null default '{}'::jsonb,
    priority integer not null default 0,
    is_reaction boolean not null default false,
    once_per_turn boolean not null default false,
    is_active boolean not null default true,
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now(),
    unique(card_id, effect_order),
    constraint card_effects_trigger_check check (
        trigger_type in (
            'passive','on_play','on_attack_declared','on_attack_resolved',
            'on_destroyed','on_revealed','on_turn_start','on_turn_end',
            'on_draw','on_discard','manual','reaction'
        )
    ),
    constraint card_effects_target_check check (
        target_mode in (
            'none','self','ally','enemy','ally_random','enemy_random',
            'all_allies','all_enemies','nearest_life','selected',
            'graveyard','deck','hand'
        )
    )
);

create index card_effects_card_idx on public.card_effects(card_id);

-- ============================================================================
-- 7. INVENTÁRIO E AUDITORIA DE CARTAS
-- ============================================================================

create table public.user_cards (
    user_id uuid not null references public.profiles(id) on delete cascade,
    card_id uuid not null references public.cards(id) on delete restrict,
    quantity integer not null default 0,
    first_obtained_at timestamptz not null default now(),
    last_obtained_at timestamptz not null default now(),
    is_new boolean not null default true,
    primary key (user_id, card_id),
    constraint user_cards_quantity_check check (quantity >= 0)
);

create index user_cards_user_idx on public.user_cards(user_id);
create index user_cards_card_idx on public.user_cards(card_id);

create table public.inventory_transactions (
    id uuid primary key default gen_random_uuid(),
    user_id uuid not null references public.profiles(id) on delete cascade,
    card_id uuid not null references public.cards(id) on delete restrict,
    quantity_delta integer not null,
    quantity_before integer not null,
    quantity_after integer not null,
    source_type text not null,
    source_id uuid,
    idempotency_key uuid,
    description text,
    created_at timestamptz not null default now(),
    constraint inventory_transactions_quantity_check check (
        quantity_before >= 0
        and quantity_after >= 0
        and quantity_after = quantity_before + quantity_delta
    ),
    constraint inventory_transactions_source_check check (
        source_type in (
            'starter_deck','pack_opening','campaign_reward','match_reward',
            'admin_grant','refund','promotion'
        )
    )
);

create unique index inventory_transactions_user_idempotency_uidx
    on public.inventory_transactions(user_id, idempotency_key, card_id)
    where idempotency_key is not null;

create index inventory_transactions_user_created_idx
    on public.inventory_transactions(user_id, created_at desc);

-- ============================================================================
-- 8. PACOTES, GACHA E RECOMPENSA DIÁRIA
-- ============================================================================

create table public.pack_types (
    id uuid primary key default gen_random_uuid(),
    code text not null unique,
    name text not null,
    description text,
    price_coins integer not null,
    cards_per_pack integer not null default 4,
    is_daily boolean not null default false,
    is_active boolean not null default true,
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now(),
    constraint pack_types_price_check check (price_coins >= 0),
    constraint pack_types_cards_check check (cards_per_pack between 1 and 100)
);

create table public.pack_drop_rules (
    id uuid primary key default gen_random_uuid(),
    pack_type_id uuid not null references public.pack_types(id) on delete cascade,
    slot_number integer not null,
    rarity text,
    set_id uuid references public.card_sets(id) on delete restrict,
    card_type text,
    golden_only boolean not null default false,
    collab_only boolean not null default false,
    weight integer not null default 1,
    minimum_roll integer,
    maximum_roll integer,
    created_at timestamptz not null default now(),
    constraint pack_drop_rules_slot_check check (slot_number >= 1),
    constraint pack_drop_rules_rarity_check check (
        rarity is null or rarity in ('common','rare','epic','legendary')
    ),
    constraint pack_drop_rules_type_check check (
        card_type is null or card_type in ('normal','leader')
    ),
    constraint pack_drop_rules_weight_check check (weight > 0),
    constraint pack_drop_rules_roll_check check (
        (minimum_roll is null and maximum_roll is null)
        or (
            minimum_roll is not null
            and maximum_roll is not null
            and minimum_roll <= maximum_roll
        )
    )
);

create index pack_drop_rules_pack_slot_idx
    on public.pack_drop_rules(pack_type_id, slot_number);

create table public.pack_openings (
    id uuid primary key default gen_random_uuid(),
    user_id uuid not null references public.profiles(id) on delete cascade,
    pack_type_id uuid not null references public.pack_types(id) on delete restrict,
    idempotency_key uuid not null,
    coins_spent integer not null default 0,
    source_type text not null,
    opened_at timestamptz not null default now(),
    unique(user_id, idempotency_key),
    constraint pack_openings_source_check check (
        source_type in ('purchase','daily_reward','match_reward','campaign_reward','owned_balance','admin')
    ),
    constraint pack_openings_coins_check check (coins_spent >= 0)
);

create table public.pack_opening_results (
    opening_id uuid not null references public.pack_openings(id) on delete cascade,
    result_order integer not null,
    card_id uuid not null references public.cards(id) on delete restrict,
    drop_rule_id uuid references public.pack_drop_rules(id) on delete set null,
    created_at timestamptz not null default now(),
    primary key (opening_id, result_order),
    constraint pack_opening_results_order_check check (result_order >= 1)
);

create table public.daily_claims (
    id uuid primary key default gen_random_uuid(),
    user_id uuid not null references public.profiles(id) on delete cascade,
    game_date date not null,
    pack_type_id uuid references public.pack_types(id) on delete restrict,
    opening_id uuid references public.pack_openings(id) on delete set null,
    cards_awarded integer not null default 0,
    missed_days_before integer not null default 0,
    claimed_at timestamptz not null default now(),
    unique(user_id, game_date),
    constraint daily_claims_cards_check check (cards_awarded >= 0),
    constraint daily_claims_missed_check check (missed_days_before >= 0)
);

create table public.user_pack_balances (
    user_id uuid not null references public.profiles(id) on delete cascade,
    pack_type_id uuid not null references public.pack_types(id) on delete restrict,
    quantity integer not null default 0,
    updated_at timestamptz not null default now(),
    primary key(user_id, pack_type_id),
    constraint user_pack_balances_quantity_check check (quantity >= 0)
);

create table public.pack_balance_transactions (
    id uuid primary key default gen_random_uuid(),
    user_id uuid not null references public.profiles(id) on delete cascade,
    pack_type_id uuid not null references public.pack_types(id) on delete restrict,
    quantity_delta integer not null,
    quantity_before integer not null,
    quantity_after integer not null,
    source_type text not null,
    source_id uuid,
    idempotency_key uuid,
    description text,
    created_at timestamptz not null default now(),
    constraint pack_balance_transactions_quantity_check check (
        quantity_before >= 0 and quantity_after >= 0
        and quantity_after = quantity_before + quantity_delta
    ),
    constraint pack_balance_transactions_source_check check (
        source_type in ('match_reward','campaign_reward','daily_reward','admin_grant','pack_opening','promotion','refund')
    )
);

create unique index pack_balance_transactions_idempotency_uidx
    on public.pack_balance_transactions(user_id, pack_type_id, idempotency_key)
    where idempotency_key is not null;

-- Tipos oficiais de pacote. As regras abaixo são iniciais e podem ser
-- ajustadas pelo painel administrativo sem alterar a estrutura do banco.
insert into public.pack_types(code, name, description, price_coins, cards_per_pack, is_daily)
values
    ('simple_125', 'Pacote Simples', '4 cartas; predominância comum.', 25, 4, false),
    ('simple_rare_230', 'Pacote Simples e Raro', '4 cartas comuns/raras, pequena chance épica.', 50, 4, false),
    ('universal_500', 'Pacote Universal', '4 cartas de todo o catálogo.', 150, 4, false),
    ('rare_epic_204', 'Pacote Raro e Épico', '4 cartas raras/épicas.', 200, 4, false),
    ('epic_legendary_154', 'Pacote Épico e Lendário', '4 cartas épicas/lendárias.', 350, 4, false),
    ('collab_115', 'Pacote Collab', '4 cartas de coleções colaborativas.', 350, 4, false),
    ('common_reward', 'Pacote Comum de Recompensa', 'Pacote gratuito de cartas comuns.', 0, 4, false),
    ('leader_reward', 'Pacote de Líder', 'Uma carta de líder.', 0, 1, false),
    ('daily_universal', 'Pacote Diário Universal', 'Base de até 8 cartas para recompensa diária.', 0, 8, true)
on conflict (code) do update set
    name = excluded.name,
    description = excluded.description,
    price_coins = excluded.price_coins,
    cards_per_pack = excluded.cards_per_pack,
    is_daily = excluded.is_daily,
    is_active = true;

-- Regras ponderadas iniciais. O algoritmo de seleção usa corrida exponencial,
-- portanto weight realmente representa peso relativo.
insert into public.pack_drop_rules(pack_type_id, slot_number, rarity, card_type, golden_only, collab_only, weight)
select pt.id, gs.slot, r.rarity, r.card_type, false, r.collab_only, r.weight
from public.pack_types pt
cross join lateral generate_series(1, pt.cards_per_pack) as gs(slot)
cross join lateral (
    select * from (values
        ('simple_125','common'::text,null::text,false,90),
        ('simple_125','rare',null,false,10),
        ('simple_rare_230','common',null,false,60),
        ('simple_rare_230','rare',null,false,35),
        ('simple_rare_230','epic',null,false,5),
        ('universal_500','common',null,false,50),
        ('universal_500','rare',null,false,30),
        ('universal_500','epic',null,false,15),
        ('universal_500','legendary',null,false,5),
        ('rare_epic_204','rare',null,false,70),
        ('rare_epic_204','epic',null,false,30),
        ('epic_legendary_154','epic',null,false,75),
        ('epic_legendary_154','legendary',null,false,25),
        ('collab_115',null,null,true,100),
        ('common_reward','common',null,false,100),
        ('leader_reward',null,'leader',false,100),
        ('daily_universal','common',null,false,50),
        ('daily_universal','rare',null,false,30),
        ('daily_universal','epic',null,false,15),
        ('daily_universal','legendary',null,false,5)
    ) as x(pack_code, rarity, card_type, collab_only, weight)
    where x.pack_code = pt.code
) r
where not exists (
    select 1 from public.pack_drop_rules old
    where old.pack_type_id = pt.id
      and old.slot_number = gs.slot
      and old.rarity is not distinct from r.rarity
      and old.card_type is not distinct from r.card_type
      and old.collab_only = r.collab_only
);

-- ============================================================================
-- 9. DECK BUILDER NORMALIZADO
-- ============================================================================

create table public.decks (
    id uuid primary key default gen_random_uuid(),
    user_id uuid not null references public.profiles(id) on delete cascade,
    name text not null,
    leader_card_id uuid references public.cards(id) on delete restrict,
    is_favorite boolean not null default false,
    is_valid boolean not null default false,
    total_cards integer not null default 0,
    golden_cards_count integer not null default 0,
    validation_errors jsonb not null default '[]'::jsonb,
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now(),
    constraint decks_name_length check (char_length(name) between 1 and 40),
    constraint decks_totals_nonnegative check (
        total_cards >= 0 and golden_cards_count >= 0
    )
);

create index decks_user_idx on public.decks(user_id);
create unique index decks_user_name_ci_uidx
    on public.decks(user_id, lower(name));

create table public.deck_cards (
    deck_id uuid not null references public.decks(id) on delete cascade,
    card_id uuid not null references public.cards(id) on delete restrict,
    quantity integer not null,
    added_at timestamptz not null default now(),
    primary key(deck_id, card_id),
    constraint deck_cards_quantity_check check (quantity > 0)
);

create index deck_cards_card_idx on public.deck_cards(card_id);


create table public.starter_grants (
    user_id uuid primary key references public.profiles(id) on delete cascade,
    deck_id uuid references public.decks(id) on delete set null,
    card_count integer not null default 0,
    granted_at timestamptz not null default now(),
    constraint starter_grants_card_count_check check (card_count >= 0)
);

-- ============================================================================
-- 10. MATCHMAKING E PARTIDAS
-- ============================================================================

create table public.matchmaking_queue (
    id uuid primary key default gen_random_uuid(),
    user_id uuid not null references public.profiles(id) on delete cascade,
    deck_id uuid not null references public.decks(id) on delete cascade,
    match_type text not null,
    rating integer not null default 1000,
    status text not null default 'searching',
    joined_at timestamptz not null default now(),
    expires_at timestamptz not null default (now() + interval '15 minutes'),
    constraint matchmaking_queue_type_check check (
        match_type in ('friendly','ranked')
    ),
    constraint matchmaking_queue_status_check check (
        status in ('searching','matched','cancelled','expired')
    )
);

create unique index matchmaking_one_active_user_uidx
    on public.matchmaking_queue(user_id)
    where status = 'searching';

create index matchmaking_search_idx
    on public.matchmaking_queue(match_type, status, rating, joined_at);

create table public.matches (
    id uuid primary key default gen_random_uuid(),
    rule_version_id uuid not null references public.game_rule_versions(id) on delete restrict,
    match_type text not null,
    status text not null default 'waiting',
    created_by uuid not null references public.profiles(id) on delete restrict,
    active_player_id uuid references public.profiles(id) on delete restrict,
    winner_id uuid references public.profiles(id) on delete restrict,
    current_turn integer not null default 0,
    state_version bigint not null default 0,
    requires_bans boolean not null default false,
    initiative_result jsonb,
    finish_reason text,
    is_private boolean not null default false,
    invite_code text,
    started_at timestamptz,
    finished_at timestamptz,
    last_action_at timestamptz not null default now(),
    expires_at timestamptz not null default (now() + interval '24 hours'),
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now(),
    constraint matches_type_check check (
        match_type in ('friendly','ranked','campaign')
    ),
    constraint matches_status_check check (
        status in (
            'waiting','ban_phase','setup','initiative',
            'in_progress','finished','cancelled','expired'
        )
    ),
    constraint matches_turn_check check (current_turn >= 0),
    constraint matches_version_check check (state_version >= 0)
);

create unique index matches_invite_code_uidx
    on public.matches(invite_code)
    where invite_code is not null;

create index matches_status_created_idx
    on public.matches(status, created_at);
create index matches_active_player_idx
    on public.matches(active_player_id);
create index matches_expiry_idx
    on public.matches(expires_at)
    where status not in ('finished','cancelled','expired');

create table public.match_public_states (
    match_id uuid primary key references public.matches(id) on delete cascade,
    player1_user_id uuid references public.profiles(id) on delete restrict,
    player2_user_id uuid references public.profiles(id) on delete restrict,
    player1_username text,
    player2_username text,
    player1_avatar_url text,
    player2_avatar_url text,
    player1_hand_count integer not null default 0,
    player2_hand_count integer not null default 0,
    player1_deck_count integer not null default 0,
    player2_deck_count integer not null default 0,
    player1_graveyard_count integer not null default 0,
    player2_graveyard_count integer not null default 0,
    player1_life_remaining integer not null default 0,
    player2_life_remaining integer not null default 0,
    player1_mana_available integer not null default 0,
    player2_mana_available integer not null default 0,
    public_board jsonb not null default '{}'::jsonb,
    updated_at timestamptz not null default now(),
    constraint match_public_states_counts_check check (
        player1_hand_count >= 0 and player2_hand_count >= 0
        and player1_deck_count >= 0 and player2_deck_count >= 0
        and player1_graveyard_count >= 0 and player2_graveyard_count >= 0
        and player1_life_remaining >= 0 and player2_life_remaining >= 0
        and player1_mana_available >= 0 and player2_mana_available >= 0
    )
);

create table public.match_players (
    match_id uuid not null references public.matches(id) on delete cascade,
    user_id uuid not null references public.profiles(id) on delete restrict,
    player_number smallint not null,
    original_deck_id uuid references public.decks(id) on delete set null,
    setup_finished boolean not null default false,
    passed_turn boolean not null default false,
    reaction_used_this_opponent_turn boolean not null default false,
    defense_replacement_used boolean not null default false,
    destroyed_life_count integer not null default 0,
    mana_available integer not null default 0,
    mana_snapshot integer not null default 0,
    mana_spent_this_turn integer not null default 0,
    actions_this_turn integer not null default 0,
    life_destroyed_this_turn boolean not null default false,
    leader_last_activated_turn integer,
    leader_last_swapped_turn integer,
    connection_status text not null default 'online',
    disconnected_at timestamptz,
    joined_at timestamptz not null default now(),
    primary key(match_id, user_id),
    unique(match_id, player_number),
    constraint match_players_number_check check (player_number in (1,2)),
    constraint match_players_nonnegative_check check (
        destroyed_life_count >= 0
        and mana_available >= 0
        and mana_snapshot >= 0
        and mana_spent_this_turn >= 0
        and actions_this_turn >= 0
    ),
    constraint match_players_connection_check check (
        connection_status in ('online','offline','left')
    )
);

create index match_players_user_idx on public.match_players(user_id);

-- Snapshot imutável do deck usado.
create table public.match_decks (
    id uuid primary key default gen_random_uuid(),
    match_id uuid not null references public.matches(id) on delete cascade,
    user_id uuid not null references public.profiles(id) on delete restrict,
    source_deck_id uuid references public.decks(id) on delete set null,
    leader_card_id uuid references public.cards(id) on delete restrict,
    total_cards integer not null,
    golden_cards_count integer not null,
    created_at timestamptz not null default now(),
    unique(match_id, user_id),
    constraint match_decks_counts_check check (
        total_cards >= 0 and golden_cards_count >= 0
    )
);

create table public.match_deck_cards (
    id uuid primary key default gen_random_uuid(),
    match_deck_id uuid not null references public.match_decks(id) on delete cascade,
    source_card_id uuid not null references public.cards(id) on delete restrict,
    card_version integer not null,
    card_name text not null,
    image_url text not null,
    element text not null,
    rarity text not null,
    card_type text not null,
    is_golden boolean not null,
    base_power integer not null,
    base_max_life integer not null,
    effect_mana_cost integer not null,
    tier integer not null,
    leader_cooldown integer not null,
    effect_definition jsonb not null default '[]'::jsonb,
    copy_number integer not null,
    initial_deck_position integer not null,
    created_at timestamptz not null default now(),
    unique(match_deck_id, initial_deck_position),
    constraint match_deck_cards_stats_check check (
        base_power between 0 and 20000
        and base_max_life between 0 and 20000
        and effect_mana_cost >= 0
        and tier >= 1
        and leader_cooldown >= 0
        and copy_number >= 1
        and initial_deck_position >= 1
    )
);

create index match_deck_cards_deck_idx
    on public.match_deck_cards(match_deck_id);

-- Cada cópia real de carta durante a partida.
create table public.match_cards (
    id uuid primary key default gen_random_uuid(),
    match_id uuid not null references public.matches(id) on delete cascade,
    owner_user_id uuid not null references public.profiles(id) on delete restrict,
    controller_user_id uuid not null references public.profiles(id) on delete restrict,
    match_deck_card_id uuid not null references public.match_deck_cards(id) on delete restrict,
    source_card_id uuid not null references public.cards(id) on delete restrict,

    zone text not null default 'deck',
    zone_position integer,
    is_face_up boolean not null default false,
    is_revealed_to_owner boolean not null default true,

    -- Atributos-base congelados para a partida.
    base_power integer not null,
    base_max_life integer not null,

    -- Atributos máximos e atuais. Estes são os campos que controlam dano/cura.
    current_power integer not null,
    maximum_power integer not null,
    current_life integer not null,
    maximum_life integer not null,

    damage_taken_total integer not null default 0,
    healing_received_total integer not null default 0,

    can_attack boolean not null default true,
    has_attacked_this_turn boolean not null default false,
    is_destroyed boolean not null default false,
    is_summoned boolean not null default false,
    is_token boolean not null default false,
    entered_zone_turn integer not null default 0,
    destroyed_at_turn integer,
    metadata jsonb not null default '{}'::jsonb,
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now(),

    constraint match_cards_zone_check check (
        zone in (
            'deck','hand','life','reinforcement','attacker',
            'leader','graveyard','banished','temporary'
        )
    ),
    constraint match_cards_zone_position_check check (
        zone_position is null or zone_position >= 1
    ),
    constraint match_cards_stats_check check (
        base_power between 0 and 20000
        and base_max_life between 0 and 20000
        and current_power between 0 and 20000
        and maximum_power between 0 and 20000
        and current_life between 0 and 20000
        and maximum_life between 0 and 20000
        and current_power <= maximum_power
        and current_life <= maximum_life
        and damage_taken_total >= 0
        and healing_received_total >= 0
    ),
    constraint match_cards_destroyed_consistency check (
        (is_destroyed = false)
        or (current_life = 0)
        or (zone in ('graveyard','banished'))
    )
);

create index match_cards_match_owner_zone_idx
    on public.match_cards(match_id, owner_user_id, zone);
create index match_cards_match_zone_position_idx
    on public.match_cards(match_id, zone, zone_position);
create index match_cards_source_idx on public.match_cards(source_card_id);

-- Garante slots únicos por jogador nas zonas que usam posição.
create unique index match_cards_unique_slot_uidx
    on public.match_cards(match_id, controller_user_id, zone, zone_position)
    where zone in ('life','reinforcement','attacker','leader')
      and zone_position is not null;

create table public.match_card_modifiers (
    id uuid primary key default gen_random_uuid(),
    match_card_id uuid not null references public.match_cards(id) on delete cascade,
    source_match_card_id uuid references public.match_cards(id) on delete set null,
    source_effect_id uuid references public.card_effects(id) on delete set null,
    modifier_type text not null,
    power_delta integer not null default 0,
    max_life_delta integer not null default 0,
    current_life_delta integer not null default 0,
    multiplier numeric(10,4),
    starts_on_turn integer not null,
    expires_on_turn integer,
    is_permanent boolean not null default false,
    metadata jsonb not null default '{}'::jsonb,
    created_at timestamptz not null default now(),
    constraint match_card_modifiers_type_check check (
        modifier_type in (
            'buff','debuff','damage','heal','deterioration',
            'set_power','set_max_life','immunity','status'
        )
    ),
    constraint match_card_modifiers_turn_check check (
        starts_on_turn >= 0
        and (expires_on_turn is null or expires_on_turn >= starts_on_turn)
    )
);

create index match_card_modifiers_card_idx
    on public.match_card_modifiers(match_card_id);

create table public.match_actions (
    id bigint generated always as identity primary key,
    match_id uuid not null references public.matches(id) on delete cascade,
    sequence_number bigint not null,
    actor_user_id uuid references public.profiles(id) on delete set null,
    action_type text not null,
    payload_public jsonb not null default '{}'::jsonb,
    payload_private jsonb not null default '{}'::jsonb,
    state_version_before bigint not null,
    state_version_after bigint not null,
    created_at timestamptz not null default now(),
    unique(match_id, sequence_number),
    constraint match_actions_versions_check check (
        state_version_before >= 0
        and state_version_after = state_version_before + 1
    )
);

create index match_actions_match_sequence_idx
    on public.match_actions(match_id, sequence_number);

create table public.match_bans (
    id uuid primary key default gen_random_uuid(),
    match_id uuid not null references public.matches(id) on delete cascade,
    banned_by_user_id uuid not null references public.profiles(id) on delete restrict,
    target_user_id uuid not null references public.profiles(id) on delete restrict,
    source_card_id uuid references public.cards(id) on delete restrict,
    ban_category text not null,
    is_skipped boolean not null default false,
    created_at timestamptz not null default now(),
    unique(match_id, banned_by_user_id, ban_category),
    constraint match_bans_category_check check (
        ban_category in ('rare','epic','legendary','collab','leader')
    ),
    constraint match_bans_players_check check (
        banned_by_user_id <> target_user_id
    ),
    constraint match_bans_source_or_skip_check check (
        (is_skipped = true and source_card_id is null)
        or (is_skipped = false and source_card_id is not null)
    )
);

create index match_bans_match_idx on public.match_bans(match_id);
create unique index match_bans_distinct_card_uidx
    on public.match_bans(match_id,banned_by_user_id,source_card_id)
    where source_card_id is not null;

create table public.match_reactions (
    id uuid primary key default gen_random_uuid(),
    match_id uuid not null references public.matches(id) on delete cascade,
    reacting_user_id uuid not null references public.profiles(id) on delete restrict,
    source_action_id bigint references public.match_actions(id) on delete cascade,
    match_card_id uuid references public.match_cards(id) on delete set null,
    status text not null default 'pending',
    response_payload jsonb not null default '{}'::jsonb,
    created_at timestamptz not null default now(),
    resolved_at timestamptz,
    constraint match_reactions_status_check check (
        status in ('pending','resolved','cancelled','expired')
    )
);

create table public.match_effect_uses (
    id uuid primary key default gen_random_uuid(),
    match_id uuid not null references public.matches(id) on delete cascade,
    match_card_id uuid not null references public.match_cards(id) on delete cascade,
    actor_user_id uuid not null references public.profiles(id) on delete restrict,
    effect_order smallint not null,
    turn_number integer not null,
    is_reaction boolean not null default false,
    mana_spent integer not null default 0,
    created_at timestamptz not null default now(),
    constraint match_effect_uses_values_check check (
        effect_order >= 1 and turn_number >= 0 and mana_spent >= 0
    )
);

create unique index match_effect_uses_once_turn_uidx
    on public.match_effect_uses(match_id, match_card_id, effect_order, turn_number);

create table public.match_rewards (
    id uuid primary key default gen_random_uuid(),
    match_id uuid not null references public.matches(id) on delete cascade,
    user_id uuid not null references public.profiles(id) on delete cascade,
    coins_awarded integer not null default 0,
    pack_type_id uuid references public.pack_types(id) on delete restrict,
    card_id uuid references public.cards(id) on delete restrict,
    granted_at timestamptz,
    idempotency_key uuid not null default gen_random_uuid(),
    unique(match_id, user_id),
    unique(user_id, idempotency_key),
    constraint match_rewards_coins_check check (coins_awarded >= 0)
);

-- ============================================================================
-- 11. CAMPANHA E MODO HISTÓRIA
-- ============================================================================

create table public.campaign_bosses (
    id uuid primary key default gen_random_uuid(),
    tier integer not null unique,
    name text not null,
    description text,
    image_url text,
    reward_card_id uuid references public.cards(id) on delete restrict,
    golden_completion_reward_card_id uuid references public.cards(id) on delete restrict,
    ai_profile jsonb not null default '{}'::jsonb,
    is_active boolean not null default true,
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now(),
    constraint campaign_bosses_tier_check check (tier between 1 and 20)
);

create table public.campaign_boss_deck_cards (
    boss_id uuid not null references public.campaign_bosses(id) on delete cascade,
    card_id uuid not null references public.cards(id) on delete restrict,
    quantity integer not null,
    primary key(boss_id, card_id),
    constraint campaign_boss_deck_quantity_check check (quantity > 0)
);

create table public.campaign_progress (
    user_id uuid not null references public.profiles(id) on delete cascade,
    boss_id uuid not null references public.campaign_bosses(id) on delete cascade,
    attempts integer not null default 0,
    victories integer not null default 0,
    is_defeated boolean not null default false,
    reward_granted boolean not null default false,
    first_defeated_at timestamptz,
    last_attempt_at timestamptz,
    primary key(user_id, boss_id),
    constraint campaign_progress_counts_check check (
        attempts >= 0 and victories >= 0 and victories <= attempts
    )
);

create index campaign_progress_user_idx
    on public.campaign_progress(user_id);

create table public.campaign_attempts (
    id uuid primary key default gen_random_uuid(),
    user_id uuid not null references public.profiles(id) on delete cascade,
    boss_id uuid not null references public.campaign_bosses(id) on delete cascade,
    match_id uuid references public.matches(id) on delete set null,
    result text,
    started_at timestamptz not null default now(),
    finished_at timestamptz,
    constraint campaign_attempts_result_check check (
        result is null or result in ('win','loss','draw','cancelled')
    )
);

create table public.story_chapters (
    id uuid primary key default gen_random_uuid(),
    unlock_card_id uuid not null references public.cards(id) on delete restrict,
    chapter_number integer not null,
    title text not null,
    body_markdown text not null,
    image_url text,
    is_active boolean not null default true,
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now(),
    unique(unlock_card_id, chapter_number),
    constraint story_chapters_number_check check (chapter_number >= 1)
);

create table public.story_unlocks (
    user_id uuid not null references public.profiles(id) on delete cascade,
    chapter_id uuid not null references public.story_chapters(id) on delete cascade,
    unlocked_at timestamptz not null default now(),
    read_at timestamptz,
    primary key(user_id, chapter_id)
);

-- ============================================================================
-- 12. NOTIFICAÇÕES E AUDITORIA ADMINISTRATIVA
-- ============================================================================

create table public.notifications (
    id uuid primary key default gen_random_uuid(),
    user_id uuid not null references public.profiles(id) on delete cascade,
    notification_type text not null,
    title text not null,
    body text not null,
    payload jsonb not null default '{}'::jsonb,
    read_at timestamptz,
    created_at timestamptz not null default now()
);

create index notifications_user_unread_idx
    on public.notifications(user_id, created_at desc)
    where read_at is null;

create table public.admin_audit_log (
    id uuid primary key default gen_random_uuid(),
    admin_user_id uuid references public.profiles(id) on delete set null,
    action_type text not null,
    target_user_id uuid references public.profiles(id) on delete set null,
    target_table text,
    target_id text,
    details jsonb not null default '{}'::jsonb,
    created_at timestamptz not null default now()
);

-- ============================================================================
-- 13. TRIGGERS DE updated_at
-- ============================================================================

do $$
declare
    v_table text;
begin
    foreach v_table in array array[
        'profiles','player_wallets','player_stats','app_settings',
        'card_sets','cards','card_effects','pack_types','decks',
        'matches','match_public_states','match_cards',
        'campaign_bosses','story_chapters'
    ]
    loop
        execute format(
            'create trigger %I before update on public.%I
             for each row execute function public.set_updated_at()',
            'set_' || v_table || '_updated_at',
            v_table
        );
    end loop;
end
$$;

-- ============================================================================
-- 14. CRIAÇÃO AUTOMÁTICA DE PERFIL
-- ============================================================================

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
    v_base_username text;
    v_username text;
    v_attempt integer := 0;
begin
    v_base_username := coalesce(
        nullif(trim(new.raw_user_meta_data ->> 'username'), ''),
        'Bruxo_' || substr(new.id::text, 1, 8)
    );

    v_base_username := left(regexp_replace(v_base_username, '[^A-Za-zÀ-ÿ0-9_ -]', '', 'g'), 20);
    if char_length(v_base_username) < 3 then
        v_base_username := 'Bruxo_' || substr(new.id::text, 1, 8);
    end if;

    v_username := v_base_username;

    while exists (
        select 1 from public.profiles p where lower(p.username) = lower(v_username)
    ) loop
        v_attempt := v_attempt + 1;
        v_username := left(v_base_username, 18) || '_' || v_attempt::text;
    end loop;

    insert into public.profiles(id, username, avatar_url)
    values (
        new.id,
        v_username,
        coalesce(
            nullif(trim(new.raw_user_meta_data ->> 'avatar_url'), ''),
            'https://api.dicebear.com/7.x/bottts/svg?seed=' || new.id::text
        )
    );

    insert into public.user_roles(user_id, role)
    values (new.id, 'player');

    insert into public.player_wallets(user_id, coins)
    values (new.id, 150);

    insert into public.player_stats(user_id)
    values (new.id);

    insert into public.wallet_transactions(
        user_id, amount, balance_before, balance_after,
        transaction_type, description
    )
    values (
        new.id, 150, 0, 150,
        'initial_balance', 'Saldo inicial da conta'
    );

    return new;
end;
$$;

create trigger on_auth_user_created
after insert on auth.users
for each row execute function public.handle_new_user();

-- Cria os registros para usuários que já existiam antes desta migração.
insert into public.profiles(id, username, avatar_url)
select
    u.id,
    'Bruxo_' || substr(u.id::text, 1, 8),
    'https://api.dicebear.com/7.x/bottts/svg?seed=' || u.id::text
from auth.users u
where not exists (
    select 1 from public.profiles p where p.id = u.id
)
on conflict do nothing;

insert into public.user_roles(user_id, role)
select p.id, 'player'
from public.profiles p
on conflict do nothing;

insert into public.player_wallets(user_id, coins)
select p.id, 150
from public.profiles p
on conflict do nothing;

insert into public.player_stats(user_id)
select p.id
from public.profiles p
on conflict do nothing;

insert into public.wallet_transactions(
    user_id,amount,balance_before,balance_after,
    transaction_type,description
)
select pw.user_id,pw.coins,0,pw.coins,
       'initial_balance','Saldo inicial reconstruído pela migração'
from public.player_wallets pw
where not exists(
    select 1 from public.wallet_transactions wt
    where wt.user_id=pw.user_id
);

-- ============================================================================
-- 15. FUNÇÕES INTERNAS DE ECONOMIA E INVENTÁRIO
-- ============================================================================

create or replace function game_private.adjust_wallet(
    p_user_id uuid,
    p_amount bigint,
    p_transaction_type text,
    p_reference_type text default null,
    p_reference_id uuid default null,
    p_idempotency_key uuid default null,
    p_description text default null
)
returns bigint
language plpgsql
security definer
set search_path = ''
as $$
declare
    v_before bigint;
    v_after bigint;
begin
    if p_idempotency_key is not null then
        select wt.balance_after
        into v_after
        from public.wallet_transactions wt
        where wt.user_id = p_user_id
          and wt.idempotency_key = p_idempotency_key;

        if found then
            return v_after;
        end if;
    end if;

    select coins
    into v_before
    from public.player_wallets
    where user_id = p_user_id
    for update;

    if not found then
        raise exception 'WALLET_NOT_FOUND';
    end if;

    v_after := v_before + p_amount;

    if v_after < 0 then
        raise exception 'INSUFFICIENT_COINS';
    end if;

    update public.player_wallets
    set coins = v_after
    where user_id = p_user_id;

    insert into public.wallet_transactions(
        user_id, amount, balance_before, balance_after,
        transaction_type, reference_type, reference_id,
        idempotency_key, description
    )
    values (
        p_user_id, p_amount, v_before, v_after,
        p_transaction_type, p_reference_type, p_reference_id,
        p_idempotency_key, p_description
    );

    return v_after;
end;
$$;

create or replace function game_private.adjust_inventory(
    p_user_id uuid,
    p_card_id uuid,
    p_quantity_delta integer,
    p_source_type text,
    p_source_id uuid default null,
    p_idempotency_key uuid default null,
    p_description text default null
)
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
    v_before integer;
    v_after integer;
begin
    if p_quantity_delta = 0 then
        raise exception 'QUANTITY_DELTA_CANNOT_BE_ZERO';
    end if;

    if p_idempotency_key is not null then
        select it.quantity_after
        into v_after
        from public.inventory_transactions it
        where it.user_id = p_user_id
          and it.card_id = p_card_id
          and it.idempotency_key = p_idempotency_key;

        if found then
            return v_after;
        end if;
    end if;

    insert into public.user_cards(user_id, card_id, quantity)
    values (p_user_id, p_card_id, 0)
    on conflict (user_id, card_id) do nothing;

    select quantity
    into v_before
    from public.user_cards
    where user_id = p_user_id
      and card_id = p_card_id
    for update;

    v_after := v_before + p_quantity_delta;

    if v_after < 0 then
        raise exception 'INSUFFICIENT_CARD_QUANTITY';
    end if;

    update public.user_cards
    set quantity = v_after,
        last_obtained_at = case when p_quantity_delta > 0 then now() else last_obtained_at end,
        is_new = case when p_quantity_delta > 0 then true else is_new end
    where user_id = p_user_id
      and card_id = p_card_id;

    insert into public.inventory_transactions(
        user_id, card_id, quantity_delta,
        quantity_before, quantity_after,
        source_type, source_id, idempotency_key, description
    )
    values (
        p_user_id, p_card_id, p_quantity_delta,
        v_before, v_after,
        p_source_type, p_source_id, p_idempotency_key, p_description
    );

    -- Uma carta original de RPG libera automaticamente seus capítulos de história.
    if p_quantity_delta > 0 then
        insert into public.story_unlocks(user_id, chapter_id)
        select p_user_id, sc.id
        from public.story_chapters sc
        join public.cards c on c.id = sc.unlock_card_id
        where sc.unlock_card_id = p_card_id
          and sc.is_active = true
          and c.is_original_rpg = true
        on conflict do nothing;
    end if;

    return v_after;
end;
$$;

create or replace function game_private.adjust_pack_balance(
    p_user_id uuid,
    p_pack_type_id uuid,
    p_quantity_delta integer,
    p_source_type text,
    p_source_id uuid default null,
    p_idempotency_key uuid default null,
    p_description text default null
)
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
    v_before integer;
    v_after integer;
begin
    if p_quantity_delta = 0 then
        raise exception 'PACK_QUANTITY_DELTA_CANNOT_BE_ZERO';
    end if;

    if p_idempotency_key is not null then
        select pbt.quantity_after
        into v_after
        from public.pack_balance_transactions pbt
        where pbt.user_id = p_user_id
          and pbt.pack_type_id = p_pack_type_id
          and pbt.idempotency_key = p_idempotency_key;
        if found then
            return v_after;
        end if;
    end if;

    insert into public.user_pack_balances(user_id, pack_type_id, quantity)
    values (p_user_id, p_pack_type_id, 0)
    on conflict (user_id, pack_type_id) do nothing;

    select quantity into v_before
    from public.user_pack_balances
    where user_id = p_user_id and pack_type_id = p_pack_type_id
    for update;

    v_after := v_before + p_quantity_delta;
    if v_after < 0 then
        raise exception 'INSUFFICIENT_PACK_BALANCE';
    end if;

    update public.user_pack_balances
    set quantity = v_after
    where user_id = p_user_id and pack_type_id = p_pack_type_id;

    insert into public.pack_balance_transactions(
        user_id, pack_type_id, quantity_delta, quantity_before, quantity_after,
        source_type, source_id, idempotency_key, description
    ) values (
        p_user_id, p_pack_type_id, p_quantity_delta, v_before, v_after,
        p_source_type, p_source_id, p_idempotency_key, p_description
    );

    return v_after;
end;
$$;

revoke all on function game_private.adjust_wallet(uuid,bigint,text,text,uuid,uuid,text)
    from public, anon, authenticated;
revoke all on function game_private.adjust_inventory(uuid,uuid,integer,text,uuid,uuid,text)
    from public, anon, authenticated;
revoke all on function game_private.adjust_pack_balance(uuid,uuid,integer,text,uuid,uuid,text)
    from public, anon, authenticated;

-- ============================================================================
-- 16. RPC DE PERFIL
-- ============================================================================

create or replace function public.update_my_profile(
    p_username text,
    p_avatar_url text default null
)
returns public.profiles
language plpgsql
security definer
set search_path = ''
as $$
declare
    v_user_id uuid := game_private.require_authenticated();
    v_profile public.profiles;
begin
    p_username := trim(p_username);

    if char_length(p_username) not between 3 and 24 then
        raise exception 'USERNAME_LENGTH_INVALID';
    end if;

    if p_username !~ '^[A-Za-zÀ-ÿ0-9_ -]+$' then
        raise exception 'USERNAME_FORMAT_INVALID';
    end if;

    update public.profiles
    set username = p_username,
        avatar_url = case
            when p_avatar_url is null then avatar_url
            else nullif(trim(p_avatar_url), '')
        end
    where id = v_user_id
    returning * into v_profile;

    return v_profile;
exception
    when unique_violation then
        raise exception 'USERNAME_ALREADY_IN_USE';
end;
$$;

revoke all on function public.update_my_profile(text,text) from public;
grant execute on function public.update_my_profile(text,text) to authenticated;

-- ============================================================================
-- 17. VALIDAÇÃO E MANUTENÇÃO DE DECKS
-- ============================================================================

create or replace function public.validate_deck(p_deck_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
    v_owner uuid;
    v_total integer;
    v_golden integer;
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
        coalesce(sum(case when c.is_golden then dc.quantity else 0 end), 0)::integer
    into v_total, v_golden
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
$$;

create or replace function public.create_deck(
    p_name text,
    p_leader_card_id uuid default null
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
    v_user_id uuid := game_private.require_authenticated();
    v_deck_id uuid;
begin
    insert into public.decks(user_id, name, leader_card_id)
    values (v_user_id, trim(p_name), p_leader_card_id)
    returning id into v_deck_id;

    perform public.validate_deck(v_deck_id);
    return v_deck_id;
end;
$$;

-- p_cards deve ser: [{"card_id":"uuid","quantity":2}, ...]
create or replace function public.replace_deck_cards(
    p_deck_id uuid,
    p_cards jsonb
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
    v_user_id uuid := game_private.require_authenticated();
begin
    if not exists (
        select 1 from public.decks
        where id = p_deck_id and user_id = v_user_id
    ) then
        raise exception 'DECK_NOT_FOUND_OR_NOT_OWNED';
    end if;

    if jsonb_typeof(p_cards) <> 'array' then
        raise exception 'CARDS_MUST_BE_JSON_ARRAY';
    end if;

    if exists (
        select 1
        from jsonb_to_recordset(p_cards) as x(card_id uuid, quantity integer)
        where x.card_id is null or x.quantity is null or x.quantity <= 0
    ) then
        raise exception 'INVALID_DECK_CARD_ENTRY';
    end if;

    delete from public.deck_cards where deck_id = p_deck_id;

    insert into public.deck_cards(deck_id, card_id, quantity)
    select p_deck_id, x.card_id, sum(x.quantity)::integer
    from jsonb_to_recordset(p_cards) as x(card_id uuid, quantity integer)
    group by x.card_id;

    return public.validate_deck(p_deck_id);
end;
$$;

create or replace function public.update_deck_metadata(
    p_deck_id uuid,
    p_name text default null,
    p_leader_card_id uuid default null,
    p_is_favorite boolean default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
    v_user_id uuid:=game_private.require_authenticated();
    v_name text;
begin
    if not exists(
        select 1 from public.decks
        where id=p_deck_id and user_id=v_user_id
    ) then
        raise exception 'DECK_NOT_FOUND_OR_NOT_OWNED';
    end if;

    v_name:=case when p_name is null then null else trim(p_name) end;
    if v_name is not null and char_length(v_name) not between 1 and 40 then
        raise exception 'DECK_NAME_LENGTH_INVALID';
    end if;

    update public.decks
    set name=coalesce(v_name,name),
        leader_card_id=p_leader_card_id,
        is_favorite=coalesce(p_is_favorite,is_favorite)
    where id=p_deck_id and user_id=v_user_id;

    return public.validate_deck(p_deck_id);
exception
    when unique_violation then
        raise exception 'DECK_NAME_ALREADY_IN_USE';
end;
$$;

create or replace function public.delete_my_deck(p_deck_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
    v_user_id uuid := game_private.require_authenticated();
begin
    delete from public.decks
    where id = p_deck_id
      and user_id = v_user_id;

    if not found then
        raise exception 'DECK_NOT_FOUND_OR_NOT_OWNED';
    end if;
end;
$$;

revoke all on function public.validate_deck(uuid) from public;
revoke all on function public.create_deck(text,uuid) from public;
revoke all on function public.replace_deck_cards(uuid,jsonb) from public;
revoke all on function public.update_deck_metadata(uuid,text,uuid,boolean) from public;
revoke all on function public.delete_my_deck(uuid) from public;

grant execute on function public.validate_deck(uuid) to authenticated, service_role;
grant execute on function public.create_deck(text,uuid) to authenticated;
grant execute on function public.replace_deck_cards(uuid,jsonb) to authenticated;
grant execute on function public.update_deck_metadata(uuid,text,uuid,boolean) to authenticated;
grant execute on function public.delete_my_deck(uuid) to authenticated;

create or replace function public.claim_starter_deck(p_deck_name text default 'Deck Inicial')
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
    v_user_id uuid := game_private.require_authenticated();
    v_deck_id uuid;
    v_leader_id uuid;
    v_card_id uuid;
    v_i integer;
    v_min_cards integer;
    v_result jsonb;
begin
    if exists (select 1 from public.starter_grants where user_id=v_user_id) then
        select jsonb_build_object(
            'already_claimed',true,'deck_id',sg.deck_id,'card_count',sg.card_count
        ) into v_result
        from public.starter_grants sg where sg.user_id=v_user_id;
        return v_result;
    end if;

    select minimum_deck_cards into v_min_cards
    from public.game_rule_versions where is_active=true;

    if not exists (select 1 from public.cards where is_active=true and card_type='normal') then
        raise exception 'CARD_CATALOG_EMPTY';
    end if;

    -- A linha de concessão é inserida primeiro e bloqueia cliques/requisições duplicadas.
    insert into public.starter_grants(user_id,card_count)
    values(v_user_id,v_min_cards);

    create temporary table tmp_starter_cards(
        card_id uuid primary key,
        quantity integer not null
    ) on commit drop;

    for v_i in 1..v_min_cards loop
        select c.id into v_card_id
        from public.cards c
        where c.is_active=true and c.card_type='normal'
        order by (
            -ln(greatest(random(),0.000000000001)) /
            case c.rarity
                when 'common' then 60
                when 'rare' then 25
                when 'epic' then 12
                when 'legendary' then 3
                else 1
            end::numeric
        ) asc
        limit 1;

        insert into tmp_starter_cards(card_id,quantity)
        values(v_card_id,1)
        on conflict(card_id) do update
        set quantity=tmp_starter_cards.quantity+1;
    end loop;

    select c.id into v_leader_id
    from public.cards c
    where c.is_active=true and c.card_type='leader'
    order by random() limit 1;

    insert into public.decks(user_id,name,leader_card_id)
    values(v_user_id,coalesce(nullif(trim(p_deck_name),''),'Deck Inicial'),v_leader_id)
    returning id into v_deck_id;

    for v_card_id, v_i in select card_id,quantity from tmp_starter_cards loop
        perform game_private.adjust_inventory(
            v_user_id,v_card_id,v_i,'starter_deck',v_deck_id,null,'Deck inicial'
        );
        insert into public.deck_cards(deck_id,card_id,quantity)
        values(v_deck_id,v_card_id,v_i);
    end loop;

    if v_leader_id is not null then
        perform game_private.adjust_inventory(
            v_user_id,v_leader_id,1,'starter_deck',v_deck_id,null,'Líder inicial'
        );
    end if;

    perform public.validate_deck(v_deck_id);
    update public.starter_grants set deck_id=v_deck_id where user_id=v_user_id;

    return jsonb_build_object(
        'already_claimed',false,'deck_id',v_deck_id,'card_count',v_min_cards,
        'leader_card_id',v_leader_id
    );
end;
$$;

revoke all on function public.claim_starter_deck(text) from public;
grant execute on function public.claim_starter_deck(text) to authenticated;

-- ============================================================================
-- 18. ABERTURA SEGURA DE PACOTES
-- ============================================================================

create or replace function game_private.pick_card_for_rule(p_rule_id uuid)
returns uuid
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
    v_card_id uuid;
begin
    select c.id
    into v_card_id
    from public.pack_drop_rules r
    join public.cards c
      on c.is_active = true
     and (r.rarity is null or c.rarity = r.rarity)
     and (r.set_id is null or c.set_id = r.set_id)
     and (r.card_type is null or c.card_type = r.card_type)
     and (r.golden_only = false or c.is_golden = true)
    left join public.card_sets cs on cs.id = c.set_id
    where r.id = p_rule_id
      and (r.collab_only = false or coalesce(cs.is_collab,false) = true)
    order by random()
    limit 1;

    if v_card_id is null then
        raise exception 'NO_ELIGIBLE_CARD_FOR_DROP_RULE';
    end if;

    return v_card_id;
end;
$$;

create or replace function public.mark_cards_seen(
    p_card_ids uuid[] default null
)
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
    v_user_id uuid:=game_private.require_authenticated();
    v_count integer;
begin
    update public.user_cards
    set is_new=false
    where user_id=v_user_id
      and is_new=true
      and (p_card_ids is null or card_id=any(p_card_ids));
    get diagnostics v_count=row_count;
    return v_count;
end;
$$;

revoke all on function public.mark_cards_seen(uuid[]) from public;
grant execute on function public.mark_cards_seen(uuid[]) to authenticated;

create or replace function public.purchase_and_open_pack(
    p_pack_type_id uuid,
    p_idempotency_key uuid
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
    v_user_id uuid := game_private.require_authenticated();
    v_pack public.pack_types;
    v_opening_id uuid;
    v_existing jsonb;
    v_slot integer;
    v_rule_id uuid;
    v_card_id uuid;
    v_results jsonb := '[]'::jsonb;
begin
    select jsonb_agg(
        jsonb_build_object(
            'order', por.result_order,
            'card_id', por.card_id,
            'name', c.name,
            'image_url', c.image_url,
            'rarity', c.rarity,
            'is_golden', c.is_golden
        ) order by por.result_order
    )
    into v_existing
    from public.pack_openings po
    join public.pack_opening_results por on por.opening_id = po.id
    join public.cards c on c.id = por.card_id
    where po.user_id = v_user_id
      and po.idempotency_key = p_idempotency_key;

    if v_existing is not null then
        return jsonb_build_object('already_processed', true, 'cards', v_existing);
    end if;

    select *
    into v_pack
    from public.pack_types
    where id = p_pack_type_id
      and is_active = true
      and is_daily = false
    for share;

    if not found then
        raise exception 'PACK_NOT_FOUND_OR_NOT_PURCHASABLE';
    end if;

    insert into public.pack_openings(
        user_id, pack_type_id, idempotency_key,
        coins_spent, source_type
    )
    values (
        v_user_id, v_pack.id, p_idempotency_key,
        v_pack.price_coins, 'purchase'
    )
    returning id into v_opening_id;

    perform game_private.adjust_wallet(
        v_user_id,
        -v_pack.price_coins,
        'pack_purchase',
        'pack_opening',
        v_opening_id,
        p_idempotency_key,
        'Compra do pacote ' || v_pack.name
    );

    for v_slot in 1..v_pack.cards_per_pack loop
        select r.id
        into v_rule_id
        from public.pack_drop_rules r
        where r.pack_type_id = v_pack.id
          and r.slot_number = v_slot
        order by (-ln(greatest(random(), 0.000000000001)) / r.weight::numeric) asc
        limit 1;

        if v_rule_id is null then
            raise exception 'PACK_SLOT_WITHOUT_DROP_RULE: %', v_slot;
        end if;

        v_card_id := game_private.pick_card_for_rule(v_rule_id);

        insert into public.pack_opening_results(
            opening_id, result_order, card_id, drop_rule_id
        )
        values (v_opening_id, v_slot, v_card_id, v_rule_id);

        perform game_private.adjust_inventory(
            v_user_id,
            v_card_id,
            1,
            'pack_opening',
            v_opening_id,
            null,
            'Carta obtida no pacote ' || v_pack.name
        );

        v_results := v_results || jsonb_build_array(
            (
                select jsonb_build_object(
                    'order', v_slot,
                    'card_id', c.id,
                    'name', c.name,
                    'image_url', c.image_url,
                    'rarity', c.rarity,
                    'is_golden', c.is_golden
                )
                from public.cards c
                where c.id = v_card_id
            )
        );
    end loop;

    return jsonb_build_object(
        'already_processed', false,
        'opening_id', v_opening_id,
        'coins_spent', v_pack.price_coins,
        'cards', v_results
    );
end;
$$;

revoke all on function public.purchase_and_open_pack(uuid,uuid) from public;
grant execute on function public.purchase_and_open_pack(uuid,uuid) to authenticated;

create or replace function public.open_owned_pack(
    p_pack_type_id uuid,
    p_idempotency_key uuid
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
    v_user_id uuid := game_private.require_authenticated();
    v_pack public.pack_types;
    v_opening_id uuid;
    v_existing jsonb;
    v_slot integer;
    v_rule_id uuid;
    v_card_id uuid;
    v_results jsonb := '[]'::jsonb;
begin
    select jsonb_agg(jsonb_build_object(
        'order', por.result_order, 'card_id', por.card_id, 'name', c.name,
        'image_url', c.image_url, 'rarity', c.rarity, 'is_golden', c.is_golden
    ) order by por.result_order)
    into v_existing
    from public.pack_openings po
    join public.pack_opening_results por on por.opening_id = po.id
    join public.cards c on c.id = por.card_id
    where po.user_id = v_user_id and po.idempotency_key = p_idempotency_key;

    if v_existing is not null then
        return jsonb_build_object('already_processed',true,'cards',v_existing);
    end if;

    select * into v_pack
    from public.pack_types
    where id = p_pack_type_id and is_active = true
    for share;
    if not found then raise exception 'PACK_NOT_FOUND'; end if;

    insert into public.pack_openings(
        user_id, pack_type_id, idempotency_key, coins_spent, source_type
    ) values (v_user_id, v_pack.id, p_idempotency_key, 0, 'owned_balance')
    returning id into v_opening_id;

    perform game_private.adjust_pack_balance(
        v_user_id, v_pack.id, -1, 'pack_opening', v_opening_id,
        p_idempotency_key, 'Abertura de pacote possuído'
    );

    for v_slot in 1..v_pack.cards_per_pack loop
        select r.id into v_rule_id
        from public.pack_drop_rules r
        where r.pack_type_id = v_pack.id and r.slot_number = v_slot
        order by (-ln(greatest(random(),0.000000000001)) / r.weight::numeric) asc
        limit 1;
        if v_rule_id is null then
            raise exception 'PACK_SLOT_WITHOUT_DROP_RULE: %', v_slot;
        end if;

        v_card_id := game_private.pick_card_for_rule(v_rule_id);
        insert into public.pack_opening_results(opening_id,result_order,card_id,drop_rule_id)
        values (v_opening_id,v_slot,v_card_id,v_rule_id);
        perform game_private.adjust_inventory(
            v_user_id,v_card_id,1,'pack_opening',v_opening_id,null,
            'Carta obtida em pacote possuído'
        );
        v_results := v_results || jsonb_build_array((
            select jsonb_build_object(
                'order',v_slot,'card_id',c.id,'name',c.name,'image_url',c.image_url,
                'rarity',c.rarity,'is_golden',c.is_golden
            ) from public.cards c where c.id = v_card_id
        ));
    end loop;

    return jsonb_build_object(
        'already_processed',false,'opening_id',v_opening_id,'cards',v_results
    );
end;
$$;

create or replace function public.claim_daily_reward(p_idempotency_key uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
    v_user_id uuid := game_private.require_authenticated();
    v_date date := game_private.current_game_date();
    v_pack public.pack_types;
    v_opening_id uuid;
    v_last_date date;
    v_missed integer := 0;
    v_max_missed integer := 30;
    v_had_duel boolean;
    v_base_cards integer;
    v_total_cards integer;
    v_i integer;
    v_slot integer;
    v_rule_id uuid;
    v_card_id uuid;
    v_results jsonb := '[]'::jsonb;
begin
    if exists (
        select 1 from public.daily_claims
        where user_id = v_user_id and game_date = v_date
    ) then
        select jsonb_agg(jsonb_build_object(
            'order',por.result_order,'card_id',por.card_id,'name',c.name,
            'image_url',c.image_url,'rarity',c.rarity,'is_golden',c.is_golden
        ) order by por.result_order)
        into v_results
        from public.daily_claims dc
        join public.pack_opening_results por on por.opening_id = dc.opening_id
        join public.cards c on c.id = por.card_id
        where dc.user_id = v_user_id and dc.game_date = v_date;
        return jsonb_build_object('already_claimed',true,'game_date',v_date,'cards',coalesce(v_results,'[]'::jsonb));
    end if;

    select max(game_date) into v_last_date
    from public.daily_claims where user_id = v_user_id;
    if v_last_date is not null then
        v_missed := greatest(0, v_date - v_last_date - 1);
    end if;
    select coalesce((value #>> '{}')::integer,30) into v_max_missed
    from public.app_settings where key='daily_makeup_max_days';
    v_missed := least(v_missed,coalesce(v_max_missed,30));

    select exists (
        select 1
        from public.matches m
        join public.match_players mp on mp.match_id=m.id
        where mp.user_id=v_user_id
          and m.status='finished'
          and (m.finished_at at time zone 'America/Sao_Paulo')::date=v_date
    ) into v_had_duel;

    select case when v_had_duel
        then coalesce((select (value #>> '{}')::integer from public.app_settings where key='daily_pack_duel_cards'),8)
        else coalesce((select (value #>> '{}')::integer from public.app_settings where key='daily_pack_no_duel_cards'),4)
    end into v_base_cards;
    v_total_cards := v_base_cards + (v_missed * 2);

    select * into v_pack from public.pack_types
    where code='daily_universal' and is_active=true for share;
    if not found then raise exception 'DAILY_PACK_NOT_CONFIGURED'; end if;

    insert into public.pack_openings(user_id,pack_type_id,idempotency_key,coins_spent,source_type)
    values(v_user_id,v_pack.id,p_idempotency_key,0,'daily_reward')
    returning id into v_opening_id;

    for v_i in 1..v_total_cards loop
        v_slot := ((v_i - 1) % v_pack.cards_per_pack) + 1;
        select r.id into v_rule_id
        from public.pack_drop_rules r
        where r.pack_type_id=v_pack.id and r.slot_number=v_slot
        order by (-ln(greatest(random(),0.000000000001)) / r.weight::numeric) asc
        limit 1;
        if v_rule_id is null then raise exception 'DAILY_PACK_SLOT_WITHOUT_RULE: %',v_slot; end if;
        v_card_id := game_private.pick_card_for_rule(v_rule_id);
        insert into public.pack_opening_results(opening_id,result_order,card_id,drop_rule_id)
        values(v_opening_id,v_i,v_card_id,v_rule_id);
        perform game_private.adjust_inventory(
            v_user_id,v_card_id,1,'pack_opening',v_opening_id,null,'Recompensa diária'
        );
        v_results := v_results || jsonb_build_array((
            select jsonb_build_object(
                'order',v_i,'card_id',c.id,'name',c.name,'image_url',c.image_url,
                'rarity',c.rarity,'is_golden',c.is_golden
            ) from public.cards c where c.id=v_card_id
        ));
    end loop;

    insert into public.daily_claims(
        user_id,game_date,pack_type_id,opening_id,cards_awarded,missed_days_before
    ) values(v_user_id,v_date,v_pack.id,v_opening_id,v_total_cards,v_missed);

    return jsonb_build_object(
        'already_claimed',false,'game_date',v_date,'duel_day',v_had_duel,
        'base_cards',v_base_cards,'missed_days',v_missed,'makeup_cards',v_missed*2,
        'cards',v_results
    );
end;
$$;

revoke all on function public.open_owned_pack(uuid,uuid) from public;
revoke all on function public.claim_daily_reward(uuid) from public;
grant execute on function public.open_owned_pack(uuid,uuid) to authenticated;
grant execute on function public.claim_daily_reward(uuid) to authenticated;

-- ============================================================================
-- 19. CRIAÇÃO E SNAPSHOT DE PARTIDAS
-- ============================================================================

create or replace function game_private.snapshot_deck(
    p_match_id uuid,
    p_user_id uuid,
    p_deck_id uuid
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
    v_match_deck_id uuid;
    v_deck public.decks;
    v_position integer := 0;
    v_copy integer;
    v_row record;
begin
    select *
    into v_deck
    from public.decks
    where id = p_deck_id
      and user_id = p_user_id
      and is_valid = true
    for share;

    if not found then
        raise exception 'VALID_DECK_REQUIRED';
    end if;

    insert into public.match_decks(
        match_id, user_id, source_deck_id,
        leader_card_id, total_cards, golden_cards_count
    )
    values (
        p_match_id, p_user_id, p_deck_id,
        v_deck.leader_card_id, v_deck.total_cards, v_deck.golden_cards_count
    )
    returning id into v_match_deck_id;

    for v_row in
        select dc.card_id, dc.quantity, c.*,
               coalesce(
                   (
                       select jsonb_agg(
                           jsonb_build_object(
                               'effect_order', ce.effect_order,
                               'trigger_type', ce.trigger_type,
                               'effect_code', ce.effect_code,
                               'target_mode', ce.target_mode,
                               'parameters', ce.parameters,
                               'priority', ce.priority,
                               'is_reaction', ce.is_reaction,
                               'once_per_turn', ce.once_per_turn
                           ) order by ce.effect_order
                       )
                       from public.card_effects ce
                       where ce.card_id = c.id
                         and ce.is_active = true
                   ),
                   '[]'::jsonb
               ) as effect_definition
        from public.deck_cards dc
        join public.cards c on c.id = dc.card_id
        where dc.deck_id = p_deck_id
        order by c.id
    loop
        for v_copy in 1..v_row.quantity loop
            v_position := v_position + 1;

            insert into public.match_deck_cards(
                match_deck_id, source_card_id, card_version,
                card_name, image_url, element, rarity, card_type,
                is_golden, base_power, base_max_life,
                effect_mana_cost, tier, leader_cooldown,
                effect_definition, copy_number, initial_deck_position
            )
            values (
                v_match_deck_id, v_row.card_id, v_row.version,
                v_row.name, v_row.image_url, v_row.element, v_row.rarity,
                v_row.card_type, v_row.is_golden, v_row.base_power,
                v_row.base_max_life, v_row.effect_mana_cost,
                v_row.tier, v_row.leader_cooldown,
                v_row.effect_definition, v_copy, v_position
            );
        end loop;
    end loop;

    -- Embaralhamento criptograficamente imprevisível não é garantido por random().
    -- Para jogo competitivo de alto valor, substitua por Edge Function/servidor.
    -- Para este projeto, random() dentro do servidor evita manipulação pelo cliente.
    -- Move temporariamente para uma faixa positiva distante; assim o índice
    -- UNIQUE não colide durante a redistribuição e o CHECK >= 1 é preservado.
    update public.match_deck_cards
    set initial_deck_position = initial_deck_position + 1000000
    where match_deck_id = v_match_deck_id;

    with shuffled as (
        select id, row_number() over (order by random()) as new_position
        from public.match_deck_cards
        where match_deck_id = v_match_deck_id
    )
    update public.match_deck_cards mdc
    set initial_deck_position = s.new_position
    from shuffled s
    where mdc.id = s.id;

    insert into public.match_cards(
        match_id, owner_user_id, controller_user_id,
        match_deck_card_id, source_card_id,
        zone, zone_position, is_face_up,
        base_power, base_max_life,
        current_power, maximum_power,
        current_life, maximum_life
    )
    select
        p_match_id, p_user_id, p_user_id,
        mdc.id, mdc.source_card_id,
        'deck', mdc.initial_deck_position, false,
        mdc.base_power, mdc.base_max_life,
        mdc.base_power, mdc.base_power,
        mdc.base_max_life, mdc.base_max_life
    from public.match_deck_cards mdc
    where mdc.match_deck_id = v_match_deck_id;

    return v_match_deck_id;
end;
$$;

create or replace function game_private.snapshot_boss_deck(
    p_match_id uuid,
    p_controller_user_id uuid,
    p_boss_id uuid
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
    v_match_deck_id uuid;
    v_total integer;
    v_position integer:=0;
    v_copy integer;
    v_row record;
begin
    select coalesce(sum(quantity),0)::integer into v_total
    from public.campaign_boss_deck_cards where boss_id=p_boss_id;
    if v_total=0 then raise exception 'BOSS_DECK_EMPTY'; end if;

    insert into public.match_decks(match_id,user_id,source_deck_id,leader_card_id,total_cards,golden_cards_count)
    select p_match_id,p_controller_user_id,null,
           (select cbd.card_id from public.campaign_boss_deck_cards cbd
            join public.cards lc on lc.id=cbd.card_id
            where cbd.boss_id=p_boss_id and lc.card_type='leader' limit 1),
           v_total,
           coalesce(sum(case when c.is_golden then cbd.quantity else 0 end),0)::integer
    from public.campaign_boss_deck_cards cbd
    join public.cards c on c.id=cbd.card_id
    where cbd.boss_id=p_boss_id
    returning id into v_match_deck_id;

    for v_row in
        select cbd.card_id,cbd.quantity,c.*,
            coalesce((select jsonb_agg(jsonb_build_object(
                'effect_order',ce.effect_order,'trigger_type',ce.trigger_type,
                'effect_code',ce.effect_code,'target_mode',ce.target_mode,
                'parameters',ce.parameters,'priority',ce.priority,
                'is_reaction',ce.is_reaction,'once_per_turn',ce.once_per_turn
            ) order by ce.effect_order)
            from public.card_effects ce where ce.card_id=c.id and ce.is_active=true),'[]'::jsonb) effect_definition
        from public.campaign_boss_deck_cards cbd
        join public.cards c on c.id=cbd.card_id
        where cbd.boss_id=p_boss_id and c.is_active=true
    loop
        for v_copy in 1..v_row.quantity loop
            v_position:=v_position+1;
            insert into public.match_deck_cards(
                match_deck_id,source_card_id,card_version,card_name,image_url,element,rarity,card_type,
                is_golden,base_power,base_max_life,effect_mana_cost,tier,leader_cooldown,
                effect_definition,copy_number,initial_deck_position
            ) values(
                v_match_deck_id,v_row.card_id,v_row.version,v_row.name,v_row.image_url,v_row.element,
                v_row.rarity,v_row.card_type,v_row.is_golden,v_row.base_power,v_row.base_max_life,
                v_row.effect_mana_cost,v_row.tier,v_row.leader_cooldown,v_row.effect_definition,
                v_copy,v_position
            );
        end loop;
    end loop;

    update public.match_deck_cards
    set initial_deck_position=initial_deck_position+1000000
    where match_deck_id=v_match_deck_id;
    with shuffled as(
        select id,row_number() over(order by random()) pos
        from public.match_deck_cards where match_deck_id=v_match_deck_id
    )
    update public.match_deck_cards mdc set initial_deck_position=s.pos
    from shuffled s where mdc.id=s.id;

    insert into public.match_cards(
        match_id,owner_user_id,controller_user_id,match_deck_card_id,source_card_id,
        zone,zone_position,is_face_up,base_power,base_max_life,
        current_power,maximum_power,current_life,maximum_life
    )
    select p_match_id,p_controller_user_id,p_controller_user_id,mdc.id,mdc.source_card_id,
           'deck',mdc.initial_deck_position,false,mdc.base_power,mdc.base_max_life,
           mdc.base_power,mdc.base_power,mdc.base_max_life,mdc.base_max_life
    from public.match_deck_cards mdc where mdc.match_deck_id=v_match_deck_id;

    return v_match_deck_id;
end;
$$;

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

    if p_is_private then
        -- gen_random_bytes pertence ao pgcrypto e pode não estar visível quando
        -- a função usa search_path vazio. UUID é nativo, seguro e suficiente.
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

create or replace function public.join_match(
    p_match_id uuid,
    p_deck_id uuid
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
    v_user_id uuid := game_private.require_authenticated();
    v_match public.matches;
    v_golden_count integer;
begin
    select *
    into v_match
    from public.matches
    where id = p_match_id
    for update;

    if not found or v_match.status <> 'waiting' then
        raise exception 'MATCH_NOT_AVAILABLE';
    end if;

    if v_match.created_by = v_user_id then
        raise exception 'CANNOT_JOIN_OWN_MATCH';
    end if;

    if exists (
        select 1 from public.match_players
        where match_id = p_match_id and player_number = 2
    ) then
        raise exception 'MATCH_ALREADY_FULL';
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

    insert into public.match_players(
        match_id, user_id, player_number, original_deck_id
    )
    values (p_match_id, v_user_id, 2, p_deck_id);

    perform game_private.snapshot_deck(p_match_id, v_user_id, p_deck_id);

    update public.matches
    set requires_bans = requires_bans or v_golden_count >= 10,
        status = case
            when requires_bans or v_golden_count >= 10 then 'ban_phase'
            else 'setup'
        end,
        started_at = now(),
        last_action_at = now(),
        expires_at = now() + interval '4 hours'
    where id = p_match_id;

    update public.match_public_states mps
    set player2_user_id = p.id,
        player2_username = p.username,
        player2_avatar_url = p.avatar_url
    from public.profiles p
    where mps.match_id = p_match_id
      and p.id = v_user_id;

    if not (v_match.requires_bans or v_golden_count >= 10) then
        perform game_private.deal_initial_hands(p_match_id);
    else
        perform game_private.recalculate_match_public_state(p_match_id);
    end if;
end;
$$;

revoke all on function public.create_match(uuid,text,boolean) from public;
revoke all on function public.join_match(uuid,uuid) from public;
grant execute on function public.create_match(uuid,text,boolean) to authenticated;
grant execute on function public.join_match(uuid,uuid) to authenticated;

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
    if not exists(select 1 from public.match_players where match_id=p_match_id and user_id=v_user_id) then
        raise exception 'NOT_A_MATCH_PLAYER';
    end if;
    select user_id into v_target_id from public.match_players
    where match_id=p_match_id and user_id<>v_user_id;
    if v_target_id is null then raise exception 'OPPONENT_NOT_FOUND'; end if;

    select coalesce(jsonb_agg(jsonb_build_object(
        'card_id',x.source_card_id,'name',x.card_name,'image_url',x.image_url,
        'rarity',x.rarity,'card_type',x.card_type,'is_golden',x.is_golden,
        'copy_count',x.copy_count,'categories',x.categories
    ) order by x.card_name),'[]'::jsonb)
    into v_result
    from (
        select mdc.source_card_id,max(mdc.card_name) card_name,max(mdc.image_url) image_url,
               max(mdc.rarity) rarity,max(mdc.card_type) card_type,
               bool_or(mdc.is_golden) is_golden,count(*) copy_count,
               array_remove(array[
                    case when max(mdc.rarity)='rare' then 'rare' end,
                    case when max(mdc.rarity)='epic' then 'epic' end,
                    case when max(mdc.rarity)='legendary' then 'legendary' end,
                    case when bool_or(coalesce(cs.is_collab,false)) then 'collab' end,
                    case when max(mdc.card_type)='leader' then 'leader' end
               ],null) categories
        from public.match_decks md
        join public.match_deck_cards mdc on mdc.match_deck_id=md.id
        join public.cards c on c.id=mdc.source_card_id
        left join public.card_sets cs on cs.id=c.set_id
        where md.match_id=p_match_id and md.user_id=v_target_id
          and not exists(
              select 1 from public.match_bans mb
              where mb.match_id=p_match_id and mb.banned_by_user_id=v_user_id
                and mb.source_card_id=mdc.source_card_id
          )
        group by mdc.source_card_id
    ) x
    where cardinality(x.categories)>0;
    return v_result;
end;
$$;

create or replace function public.submit_match_ban(
    p_match_id uuid,
    p_source_card_id uuid,
    p_ban_category text,
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
    v_target_id uuid;
    v_valid boolean;
    v_complete boolean;
    v_new_version bigint;
begin
    v_match:=game_private.lock_match_for_action(p_match_id,p_expected_version,array['ban_phase']);
    if p_ban_category not in ('rare','epic','legendary','collab','leader') then
        raise exception 'INVALID_BAN_CATEGORY';
    end if;
    select user_id into v_target_id from public.match_players
    where match_id=p_match_id and user_id<>v_user_id;
    if v_target_id is null then raise exception 'OPPONENT_NOT_FOUND'; end if;
    if exists(select 1 from public.match_bans where match_id=p_match_id and banned_by_user_id=v_user_id and ban_category=p_ban_category) then
        raise exception 'BAN_CATEGORY_ALREADY_SUBMITTED';
    end if;

    select exists(
        select 1
        from public.match_decks md
        join public.match_deck_cards mdc on mdc.match_deck_id=md.id
        join public.cards c on c.id=mdc.source_card_id
        left join public.card_sets cs on cs.id=c.set_id
        where md.match_id=p_match_id and md.user_id=v_target_id
          and not exists(
              select 1 from public.match_bans mb
              where mb.match_id=p_match_id and mb.banned_by_user_id=v_user_id
                and mb.source_card_id=mdc.source_card_id
          )
          and (p_source_card_id is null or mdc.source_card_id=p_source_card_id)
          and case p_ban_category
                when 'rare' then mdc.rarity='rare'
                when 'epic' then mdc.rarity='epic'
                when 'legendary' then mdc.rarity='legendary'
                when 'leader' then mdc.card_type='leader'
                when 'collab' then coalesce(cs.is_collab,false)
              end
    ) into v_valid;

    if p_source_card_id is null then
        if v_valid then raise exception 'BAN_CANNOT_BE_SKIPPED_WHEN_CANDIDATE_EXISTS'; end if;
        insert into public.match_bans(
            match_id,banned_by_user_id,target_user_id,source_card_id,ban_category,is_skipped
        ) values(p_match_id,v_user_id,v_target_id,null,p_ban_category,true);
    else
        if not v_valid then raise exception 'CARD_NOT_VALID_FOR_BAN_CATEGORY'; end if;
        insert into public.match_bans(
            match_id,banned_by_user_id,target_user_id,source_card_id,ban_category,is_skipped
        ) values(p_match_id,v_user_id,v_target_id,p_source_card_id,p_ban_category,false);

        update public.match_cards
        set zone='banished',zone_position=null,is_face_up=true
        where match_id=p_match_id and owner_user_id=v_target_id
          and source_card_id=p_source_card_id and zone='deck';
    end if;

    select count(*)=10 into v_complete
    from public.match_bans where match_id=p_match_id;
    if v_complete then
        perform game_private.deal_initial_hands(p_match_id);
    end if;

    v_new_version:=game_private.record_match_action(
        p_match_id,v_user_id,'card_banned',
        jsonb_build_object('target_user_id',v_target_id,'category',p_ban_category,
            'source_card_id',p_source_card_id,'skipped',p_source_card_id is null,
            'ban_phase_complete',v_complete),
        '{}'::jsonb,p_expected_version
    );
    return jsonb_build_object('ban_phase_complete',v_complete,'state_version',v_new_version);
end;
$$;

create or replace function public.submit_match_setup(
    p_match_id uuid,
    p_life_card_ids uuid[],
    p_reinforcement_card_ids uuid[] default array[]::uuid[],
    p_leader_card_id uuid default null,
    p_expected_version bigint default 0
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
    v_user_id uuid:=game_private.require_authenticated();
    v_match public.matches;
    v_life_slots integer;
    v_reinforcement_slots integer;
    v_ready boolean;
    v_active uuid;
    v_roll1 integer;
    v_roll2 integer;
    v_mode text;
    v_new_version bigint;
    v_hand_count integer;
    v_all_ids uuid[];
    v_distinct_count integer;
    v_total_selected integer;
begin
    v_match:=game_private.lock_match_for_action(p_match_id,p_expected_version,array['setup']);
    if exists(select 1 from public.match_players where match_id=p_match_id and user_id=v_user_id and setup_finished=true) then
        raise exception 'SETUP_ALREADY_SUBMITTED';
    end if;
    select life_slots,reinforcement_slots,initiative_mode
    into v_life_slots,v_reinforcement_slots,v_mode
    from public.game_rule_versions where id=v_match.rule_version_id;

    if coalesce(cardinality(p_life_card_ids),0)<>v_life_slots then raise exception 'EXACT_LIFE_CARDS_REQUIRED'; end if;
    if coalesce(cardinality(p_reinforcement_card_ids),0)>v_reinforcement_slots then raise exception 'TOO_MANY_REINFORCEMENTS'; end if;

    v_all_ids := p_life_card_ids
        || coalesce(p_reinforcement_card_ids,array[]::uuid[])
        || case when p_leader_card_id is null then array[]::uuid[] else array[p_leader_card_id] end;
    v_total_selected := cardinality(v_all_ids);
    select count(distinct u.id)::integer into v_distinct_count
    from unnest(v_all_ids) as u(id);
    if v_distinct_count <> v_total_selected then
        raise exception 'DUPLICATED_SETUP_CARD';
    end if;

    if exists(
        select 1 from unnest(v_all_ids) as selected(id)
        where not exists(select 1 from public.match_cards mc
            where mc.id=selected.id and mc.match_id=p_match_id and mc.owner_user_id=v_user_id and mc.zone='hand')
    ) then raise exception 'SETUP_CARD_NOT_IN_HAND'; end if;

    if exists(
        select 1
        from public.match_cards mc
        join public.cards c on c.id=mc.source_card_id
        where mc.id=any(p_life_card_ids||coalesce(p_reinforcement_card_ids,array[]::uuid[]))
          and c.card_type='leader'
    ) then
        raise exception 'LEADER_CANNOT_BE_LIFE_OR_REINFORCEMENT';
    end if;

    if (select count(*) from public.match_cards mc join public.cards c on c.id=mc.source_card_id
        where mc.id=any(p_life_card_ids||coalesce(p_reinforcement_card_ids,array[]::uuid[])) and c.rarity='legendary')>1 then
        raise exception 'LEGENDARY_FIELD_LIMIT_REACHED';
    end if;
    if p_leader_card_id is not null and not exists(
        select 1 from public.match_cards mc join public.cards c on c.id=mc.source_card_id
        where mc.id=p_leader_card_id and c.card_type='leader'
    ) then raise exception 'LEADER_CARD_REQUIRED'; end if;

    update public.match_cards mc set zone='life',zone_position=x.ord,is_face_up=true,entered_zone_turn=0
    from unnest(p_life_card_ids) with ordinality x(id,ord)
    where mc.id=x.id;
    update public.match_cards mc set zone='reinforcement',zone_position=x.ord,is_face_up=false,entered_zone_turn=0
    from unnest(coalesce(p_reinforcement_card_ids,array[]::uuid[])) with ordinality x(id,ord)
    where mc.id=x.id;
    if p_leader_card_id is not null then
        update public.match_cards set zone='leader',zone_position=1,is_face_up=true,entered_zone_turn=0
        where id=p_leader_card_id;
    end if;

    select count(*)::integer into v_hand_count from public.match_cards
    where match_id=p_match_id and owner_user_id=v_user_id and zone='hand';
    update public.match_players set setup_finished=true,mana_snapshot=v_hand_count,mana_available=v_hand_count
    where match_id=p_match_id and user_id=v_user_id;

    select count(*)=2 into v_ready from public.match_players where match_id=p_match_id and setup_finished=true;
    if v_ready then
        if v_mode='d20' then
            loop
                v_roll1:=floor(random()*20+1)::integer;
                v_roll2:=floor(random()*20+1)::integer;
                exit when v_roll1<>v_roll2;
            end loop;
            select user_id into v_active from public.match_players
            where match_id=p_match_id and player_number=case when v_roll1>v_roll2 then 1 else 2 end;
            update public.matches set initiative_result=jsonb_build_object('mode','d20','player1',v_roll1,'player2',v_roll2) where id=p_match_id;
        else
            select user_id into v_active from public.match_players
            where match_id=p_match_id and player_number=case when random()<0.5 then 1 else 2 end;
            update public.matches set initiative_result=jsonb_build_object('mode','coin_flip','winner_user_id',v_active) where id=p_match_id;
        end if;
        update public.matches set status='in_progress',current_turn=1,active_player_id=v_active where id=p_match_id;
        update public.match_players set actions_this_turn=0,life_destroyed_this_turn=false where match_id=p_match_id;
    end if;

    v_new_version:=game_private.record_match_action(
        p_match_id,v_user_id,'setup_submitted',
        jsonb_build_object('player_user_id',v_user_id,'setup_complete',v_ready,
            'active_player_id',case when v_ready then v_active else null end),
        jsonb_build_object('life_card_ids',p_life_card_ids,'reinforcement_card_ids',p_reinforcement_card_ids,'leader_card_id',p_leader_card_id),
        p_expected_version
    );
    return jsonb_build_object('match_started',v_ready,'active_player_id',v_active,'state_version',v_new_version);
end;
$$;

revoke all on function public.get_match_ban_candidates(uuid) from public;
revoke all on function public.submit_match_ban(uuid,uuid,text,bigint) from public;
revoke all on function public.submit_match_setup(uuid,uuid[],uuid[],uuid,bigint) from public;
grant execute on function public.get_match_ban_candidates(uuid) to authenticated;
grant execute on function public.submit_match_ban(uuid,uuid,text,bigint) to authenticated;
grant execute on function public.submit_match_setup(uuid,uuid[],uuid[],uuid,bigint) to authenticated;

create or replace function public.enqueue_matchmaking(
    p_deck_id uuid,
    p_match_type text default 'friendly'
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
    v_user_id uuid:=game_private.require_authenticated();
    v_queue_id uuid;
    v_rating integer;
begin
    if p_match_type not in ('friendly','ranked') then raise exception 'INVALID_MATCHMAKING_TYPE'; end if;
    perform public.validate_deck(p_deck_id);
    if not exists(select 1 from public.decks where id=p_deck_id and user_id=v_user_id and is_valid=true) then
        raise exception 'VALID_OWNED_DECK_REQUIRED';
    end if;
    if exists(select 1 from public.matches m join public.match_players mp on mp.match_id=m.id
        where mp.user_id=v_user_id and m.status in ('ban_phase','setup','initiative','in_progress')) then
        raise exception 'PLAYER_ALREADY_IN_ACTIVE_MATCH';
    end if;
    update public.matchmaking_queue set status='cancelled'
    where user_id=v_user_id and status='searching';
    select ranked_rating into v_rating from public.player_stats where user_id=v_user_id;
    insert into public.matchmaking_queue(user_id,deck_id,match_type,rating,status)
    values(v_user_id,p_deck_id,p_match_type,coalesce(v_rating,1000),'searching')
    returning id into v_queue_id;
    return v_queue_id;
end;
$$;

create or replace function public.leave_matchmaking()
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
    v_user_id uuid:=game_private.require_authenticated();
    v_count integer;
begin
    update public.matchmaking_queue set status='cancelled'
    where user_id=v_user_id and status='searching';
    get diagnostics v_count=row_count;
    return v_count;
end;
$$;

create or replace function public.matchmake_now()
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
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
    if not exists(select 1 from public.decks where id=v_other.deck_id and user_id=v_other.user_id and is_valid=true) then
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
$$;

create or replace function public.start_campaign_attempt(
    p_boss_id uuid,
    p_deck_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
    v_user_id uuid:=game_private.require_authenticated();
    v_rule_id uuid;
    v_match_id uuid;
    v_attempt_id uuid;
begin
    if not exists(select 1 from public.campaign_bosses where id=p_boss_id and is_active=true) then
        raise exception 'CAMPAIGN_BOSS_NOT_FOUND';
    end if;
    perform public.validate_deck(p_deck_id);
    if not exists(select 1 from public.decks where id=p_deck_id and user_id=v_user_id and is_valid=true) then
        raise exception 'VALID_OWNED_DECK_REQUIRED';
    end if;
    select id into v_rule_id from public.game_rule_versions where is_active=true;
    insert into public.matches(rule_version_id,match_type,status,created_by,is_private,expires_at)
    values(v_rule_id,'campaign','waiting',v_user_id,true,now()+interval '24 hours')
    returning id into v_match_id;
    insert into public.match_players(match_id,user_id,player_number,original_deck_id)
    values(v_match_id,v_user_id,1,p_deck_id);
    perform game_private.snapshot_deck(v_match_id,v_user_id,p_deck_id);
    insert into public.match_public_states(match_id,player1_user_id,player1_username,player1_avatar_url)
    select v_match_id,id,username,avatar_url from public.profiles where id=v_user_id;
    insert into public.campaign_attempts(user_id,boss_id,match_id)
    values(v_user_id,p_boss_id,v_match_id) returning id into v_attempt_id;
    return jsonb_build_object('attempt_id',v_attempt_id,'match_id',v_match_id,'status','waiting_for_controller');
end;
$$;

create or replace function public.join_campaign_as_controller(p_attempt_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
    v_user_id uuid:=game_private.require_authenticated();
    v_attempt public.campaign_attempts;
    v_match public.matches;
begin
    if not exists(select 1 from public.user_roles where user_id=v_user_id and role in('game_master','admin')) then
        raise exception 'GAME_MASTER_ROLE_REQUIRED';
    end if;
    select * into v_attempt from public.campaign_attempts where id=p_attempt_id for update;
    if not found or v_attempt.finished_at is not null then raise exception 'CAMPAIGN_ATTEMPT_NOT_AVAILABLE'; end if;
    if v_attempt.user_id=v_user_id then raise exception 'CANNOT_CONTROL_OWN_BOSS'; end if;
    select * into v_match from public.matches where id=v_attempt.match_id for update;
    if not found or v_match.status<>'waiting' then raise exception 'CAMPAIGN_MATCH_NOT_WAITING'; end if;

    insert into public.match_players(match_id,user_id,player_number,original_deck_id)
    values(v_match.id,v_user_id,2,null);
    perform game_private.snapshot_boss_deck(v_match.id,v_user_id,v_attempt.boss_id);
    update public.matches set status='setup',started_at=now(),expires_at=now()+interval '4 hours' where id=v_match.id;
    update public.match_public_states mps set
        player2_user_id=p.id,player2_username=p.username,player2_avatar_url=p.avatar_url
    from public.profiles p where mps.match_id=v_match.id and p.id=v_user_id;
    perform game_private.deal_initial_hands(v_match.id);
    return jsonb_build_object('match_id',v_match.id,'status','setup');
end;
$$;

revoke all on function public.enqueue_matchmaking(uuid,text) from public;
revoke all on function public.leave_matchmaking() from public;
revoke all on function public.matchmake_now() from public;
revoke all on function public.start_campaign_attempt(uuid,uuid) from public;
revoke all on function public.join_campaign_as_controller(uuid) from public;
grant execute on function public.enqueue_matchmaking(uuid,text) to authenticated;
grant execute on function public.leave_matchmaking() to authenticated;
grant execute on function public.matchmake_now() to authenticated;
grant execute on function public.start_campaign_attempt(uuid,uuid) to authenticated;
grant execute on function public.join_campaign_as_controller(uuid) to authenticated;

-- ============================================================================
-- 20. FUNÇÕES CENTRAIS DA PARTIDA
-- ============================================================================

create or replace function game_private.recalculate_match_public_state(p_match_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
    update public.match_public_states mps
    set player1_hand_count = coalesce((
            select count(*) from public.match_cards mc
            join public.match_players mp on mp.match_id=mc.match_id and mp.user_id=mc.owner_user_id
            where mc.match_id=p_match_id and mp.player_number=1 and mc.zone='hand'
        ),0),
        player2_hand_count = coalesce((
            select count(*) from public.match_cards mc
            join public.match_players mp on mp.match_id=mc.match_id and mp.user_id=mc.owner_user_id
            where mc.match_id=p_match_id and mp.player_number=2 and mc.zone='hand'
        ),0),
        player1_deck_count = coalesce((
            select count(*) from public.match_cards mc
            join public.match_players mp on mp.match_id=mc.match_id and mp.user_id=mc.owner_user_id
            where mc.match_id=p_match_id and mp.player_number=1 and mc.zone='deck'
        ),0),
        player2_deck_count = coalesce((
            select count(*) from public.match_cards mc
            join public.match_players mp on mp.match_id=mc.match_id and mp.user_id=mc.owner_user_id
            where mc.match_id=p_match_id and mp.player_number=2 and mc.zone='deck'
        ),0),
        player1_graveyard_count = coalesce((
            select count(*) from public.match_cards mc
            join public.match_players mp on mp.match_id=mc.match_id and mp.user_id=mc.owner_user_id
            where mc.match_id=p_match_id and mp.player_number=1 and mc.zone='graveyard'
        ),0),
        player2_graveyard_count = coalesce((
            select count(*) from public.match_cards mc
            join public.match_players mp on mp.match_id=mc.match_id and mp.user_id=mc.owner_user_id
            where mc.match_id=p_match_id and mp.player_number=2 and mc.zone='graveyard'
        ),0),
        player1_life_remaining = coalesce((
            select count(*) from public.match_cards mc
            join public.match_players mp on mp.match_id=mc.match_id and mp.user_id=mc.controller_user_id
            where mc.match_id=p_match_id and mp.player_number=1 and mc.zone='life' and mc.current_life>0
        ),0),
        player2_life_remaining = coalesce((
            select count(*) from public.match_cards mc
            join public.match_players mp on mp.match_id=mc.match_id and mp.user_id=mc.controller_user_id
            where mc.match_id=p_match_id and mp.player_number=2 and mc.zone='life' and mc.current_life>0
        ),0),
        player1_mana_available = coalesce((
            select mana_available from public.match_players
            where match_id=p_match_id and player_number=1
        ),0),
        player2_mana_available = coalesce((
            select mana_available from public.match_players
            where match_id=p_match_id and player_number=2
        ),0),
        public_board = coalesce((
            select jsonb_build_object(
                'cards',coalesce(jsonb_agg(
                    jsonb_build_object(
                        'instance_id',case when mc.zone='reinforcement' and not mc.is_face_up then null else mc.id end,
                        'owner_user_id',mc.owner_user_id,
                        'controller_user_id',mc.controller_user_id,
                        'zone',mc.zone,
                        'position',mc.zone_position,
                        'is_face_up',mc.is_face_up,
                        'source_card_id',case when mc.zone='reinforcement' and not mc.is_face_up then null else mc.source_card_id end,
                        'name',case when mc.zone='reinforcement' and not mc.is_face_up then null else mdc.card_name end,
                        'image_url',case when mc.zone='reinforcement' and not mc.is_face_up then null else mdc.image_url end,
                        'rarity',case when mc.zone='reinforcement' and not mc.is_face_up then null else mdc.rarity end,
                        'current_power',case when mc.zone='reinforcement' and not mc.is_face_up then null else mc.current_power end,
                        'maximum_power',case when mc.zone='reinforcement' and not mc.is_face_up then null else mc.maximum_power end,
                        'current_life',case when mc.zone='reinforcement' and not mc.is_face_up then null else mc.current_life end,
                        'maximum_life',case when mc.zone='reinforcement' and not mc.is_face_up then null else mc.maximum_life end,
                        'destroyed',mc.is_destroyed
                    ) order by mc.controller_user_id,mc.zone,mc.zone_position nulls last,mc.created_at
                ),'[]'::jsonb)
            )
            from public.match_cards mc
            join public.match_deck_cards mdc on mdc.id=mc.match_deck_card_id
            where mc.match_id=p_match_id
              and mc.zone in ('life','reinforcement','attacker','leader','graveyard','banished')
        ),jsonb_build_object('cards','[]'::jsonb)),
        updated_at=now()
    where mps.match_id=p_match_id;
end;
$$;

create or replace function game_private.draw_internal(
    p_match_id uuid,
    p_user_id uuid,
    p_amount integer
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
    v_max_hand integer;
    v_hand integer;
    v_take integer;
    v_ids jsonb;
begin
    select grv.maximum_hand_size into v_max_hand
    from public.matches m
    join public.game_rule_versions grv on grv.id=m.rule_version_id
    where m.id=p_match_id;

    select count(*)::integer into v_hand
    from public.match_cards
    where match_id=p_match_id and owner_user_id=p_user_id and zone='hand';

    v_take := least(greatest(coalesce(p_amount,0),0),greatest(v_max_hand-v_hand,0));

    with chosen as (
        select id,row_number() over(order by zone_position,id) rn
        from public.match_cards
        where match_id=p_match_id and owner_user_id=p_user_id and zone='deck'
        order by zone_position,id
        limit v_take
    ), moved as (
        update public.match_cards mc
        set zone='hand',zone_position=v_hand+c.rn,is_face_up=false
        from chosen c where mc.id=c.id
        returning mc.id
    )
    select coalesce(jsonb_agg(id),'[]'::jsonb) into v_ids from moved;

    select count(*)::integer into v_hand
    from public.match_cards
    where match_id=p_match_id and owner_user_id=p_user_id and zone='hand';

    update public.match_players
    set mana_snapshot=v_hand,
        mana_available=greatest(v_hand-mana_spent_this_turn,0)
    where match_id=p_match_id and user_id=p_user_id;

    return v_ids;
end;
$$;

create or replace function game_private.deal_initial_hands(p_match_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
    v_size integer;
    v_player record;
begin
    select grv.initial_hand_size into v_size
    from public.matches m
    join public.game_rule_versions grv on grv.id=m.rule_version_id
    where m.id=p_match_id;

    for v_player in
        select user_id from public.match_players where match_id=p_match_id order by player_number
    loop
        if not exists (
            select 1 from public.match_cards
            where match_id=p_match_id and owner_user_id=v_player.user_id and zone='hand'
        ) then
            perform game_private.draw_internal(p_match_id,v_player.user_id,v_size);
        end if;
    end loop;

    update public.matches set status='setup' where id=p_match_id;
    perform game_private.recalculate_match_public_state(p_match_id);
end;
$$;

create or replace function game_private.apply_damage_internal(
    p_match_id uuid,
    p_target_card_id uuid,
    p_damage integer,
    p_turn integer
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
    v_card public.match_cards;
    v_old_zone text;
    v_new_life integer;
    v_destroyed boolean;
begin
    if p_damage < 0 then raise exception 'INVALID_DAMAGE'; end if;
    select * into v_card from public.match_cards
    where id=p_target_card_id and match_id=p_match_id for update;
    if not found then raise exception 'TARGET_CARD_NOT_FOUND'; end if;

    v_old_zone:=v_card.zone;
    v_new_life:=greatest(0,v_card.current_life-p_damage);
    v_destroyed:=(v_new_life=0 and v_card.current_life>0);

    update public.match_cards
    set current_life=v_new_life,
        damage_taken_total=damage_taken_total+least(p_damage,v_card.current_life),
        is_destroyed=case when v_destroyed then true else is_destroyed end,
        destroyed_at_turn=case when v_destroyed then p_turn else destroyed_at_turn end,
        zone=case when v_destroyed then 'graveyard' else zone end,
        zone_position=case when v_destroyed then null else zone_position end,
        is_face_up=case when v_destroyed then true else is_face_up end
    where id=p_target_card_id;

    return jsonb_build_object(
        'card_id',p_target_card_id,'old_zone',v_old_zone,'current_life',v_new_life,
        'maximum_life',v_card.maximum_life,'destroyed',v_destroyed
    );
end;
$$;

create or replace function game_private.finish_match(
    p_match_id uuid,
    p_winner_id uuid,
    p_reason text
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
    v_match public.matches;
    v_player record;
    v_common_pack uuid;
    v_leader_pack uuid;
    v_universal_pack uuid;
    v_attempt public.campaign_attempts;
    v_boss public.campaign_bosses;
    v_completion_card uuid;
begin
    select * into v_match from public.matches where id=p_match_id for update;
    if not found or v_match.status='finished' then return; end if;

    update public.matches
    set status='finished',winner_id=p_winner_id,finish_reason=p_reason,
        finished_at=now(),active_player_id=null
    where id=p_match_id;

    for v_player in select user_id from public.match_players where match_id=p_match_id loop
        update public.player_stats
        set wins=wins+case when v_player.user_id=p_winner_id then 1 else 0 end,
            losses=losses+case when p_winner_id is not null and v_player.user_id<>p_winner_id then 1 else 0 end,
            draws=draws+case when p_winner_id is null then 1 else 0 end,
            current_win_streak=case when v_player.user_id=p_winner_id then current_win_streak+1 else 0 end,
            best_win_streak=case when v_player.user_id=p_winner_id then greatest(best_win_streak,current_win_streak+1) else best_win_streak end,
            last_match_at=now()
        where user_id=v_player.user_id;
    end loop;

    if v_match.match_type='friendly' then
        select id into v_common_pack from public.pack_types where code='common_reward';
        select id into v_leader_pack from public.pack_types where code='leader_reward';
        select id into v_universal_pack from public.pack_types where code='universal_500';

        for v_player in select user_id from public.match_players where match_id=p_match_id loop
            perform game_private.adjust_wallet(
                v_player.user_id,50,'match_reward','match',p_match_id,p_match_id,
                'Participação em duelo amistoso'
            );
            if v_common_pack is not null then
                perform game_private.adjust_pack_balance(v_player.user_id,v_common_pack,1,'match_reward',p_match_id,p_match_id,'Pacote comum do duelo');
            end if;
            if v_leader_pack is not null then
                perform game_private.adjust_pack_balance(v_player.user_id,v_leader_pack,1,'match_reward',p_match_id,p_match_id,'Pacote de líder do duelo');
            end if;
            insert into public.match_rewards(match_id,user_id,coins_awarded,granted_at,idempotency_key)
            values(p_match_id,v_player.user_id,50,now(),p_match_id)
            on conflict(match_id,user_id) do nothing;
        end loop;
        if p_winner_id is not null and v_universal_pack is not null then
            perform game_private.adjust_pack_balance(p_winner_id,v_universal_pack,1,'match_reward',p_match_id,p_match_id,'Pacote universal da vitória');
        end if;
    end if;

    if v_match.match_type='campaign' then
        select * into v_attempt from public.campaign_attempts where match_id=p_match_id for update;
        if found then
            select * into v_boss from public.campaign_bosses where id=v_attempt.boss_id;
            update public.campaign_attempts
            set result=case when p_winner_id=v_attempt.user_id then 'win' else 'loss' end,
                finished_at=now()
            where id=v_attempt.id;

            insert into public.campaign_progress(user_id,boss_id,attempts,victories,is_defeated,last_attempt_at)
            values(v_attempt.user_id,v_attempt.boss_id,1,
                case when p_winner_id=v_attempt.user_id then 1 else 0 end,
                p_winner_id=v_attempt.user_id,now())
            on conflict(user_id,boss_id) do update set
                attempts=public.campaign_progress.attempts+1,
                victories=public.campaign_progress.victories+case when p_winner_id=v_attempt.user_id then 1 else 0 end,
                is_defeated=public.campaign_progress.is_defeated or p_winner_id=v_attempt.user_id,
                first_defeated_at=case
                    when p_winner_id=v_attempt.user_id then coalesce(public.campaign_progress.first_defeated_at,now())
                    else public.campaign_progress.first_defeated_at end,
                last_attempt_at=now();

            if p_winner_id=v_attempt.user_id and v_boss.reward_card_id is not null and not exists(
                select 1 from public.campaign_progress
                where user_id=v_attempt.user_id and boss_id=v_attempt.boss_id and reward_granted=true
            ) then
                perform game_private.adjust_inventory(v_attempt.user_id,v_boss.reward_card_id,1,'campaign_reward',v_attempt.id,v_attempt.id,'Recompensa do chefe');
                update public.campaign_progress set reward_granted=true
                where user_id=v_attempt.user_id and boss_id=v_attempt.boss_id;
                update public.player_stats set campaign_wins=campaign_wins+1 where user_id=v_attempt.user_id;
            end if;

            if p_winner_id=v_attempt.user_id and (
                select count(*) from public.campaign_progress cp
                join public.campaign_bosses cb on cb.id=cp.boss_id and cb.is_active=true
                where cp.user_id=v_attempt.user_id and cp.is_defeated=true
            ) >= 20 then
                select golden_completion_reward_card_id into v_completion_card
                from public.campaign_bosses
                where golden_completion_reward_card_id is not null
                order by tier desc limit 1;
                if v_completion_card is not null and not exists(
                    select 1 from public.inventory_transactions
                    where user_id=v_attempt.user_id and card_id=v_completion_card
                      and source_type='campaign_reward' and description='Conclusão dos 20 chefes'
                ) then
                    perform game_private.adjust_inventory(v_attempt.user_id,v_completion_card,1,'campaign_reward',v_attempt.id,null,'Conclusão dos 20 chefes');
                end if;
            end if;
        end if;
    end if;

    perform game_private.recalculate_match_public_state(p_match_id);
end;
$$;

create or replace function game_private.lock_match_for_action(
    p_match_id uuid,
    p_expected_version bigint,
    p_allowed_statuses text[]
)
returns public.matches
language plpgsql
security definer
set search_path = ''
as $$
declare
    v_match public.matches;
    v_user_id uuid := game_private.require_authenticated();
begin
    select *
    into v_match
    from public.matches
    where id = p_match_id
    for update;

    if not found then
        raise exception 'MATCH_NOT_FOUND';
    end if;

    if not exists (
        select 1 from public.match_players mp
        where mp.match_id = p_match_id
          and mp.user_id = v_user_id
    ) then
        raise exception 'NOT_A_MATCH_PLAYER';
    end if;

    if v_match.state_version <> p_expected_version then
        raise exception 'STALE_MATCH_VERSION';
    end if;

    if not (v_match.status = any(p_allowed_statuses)) then
        raise exception 'INVALID_MATCH_STATUS';
    end if;

    return v_match;
end;
$$;

create or replace function game_private.record_match_action(
    p_match_id uuid,
    p_actor_user_id uuid,
    p_action_type text,
    p_payload_public jsonb,
    p_payload_private jsonb,
    p_version_before bigint
)
returns bigint
language plpgsql
security definer
set search_path = ''
as $$
declare
    v_sequence bigint;
    v_new_version bigint := p_version_before + 1;
begin
    select coalesce(max(sequence_number), 0) + 1
    into v_sequence
    from public.match_actions
    where match_id = p_match_id;

    insert into public.match_actions(
        match_id, sequence_number, actor_user_id,
        action_type, payload_public, payload_private,
        state_version_before, state_version_after
    )
    values (
        p_match_id, v_sequence, p_actor_user_id,
        p_action_type, coalesce(p_payload_public,'{}'::jsonb),
        coalesce(p_payload_private,'{}'::jsonb),
        p_version_before, v_new_version
    );

    update public.matches
    set state_version = v_new_version,
        last_action_at = now()
    where id = p_match_id;

    perform game_private.recalculate_match_public_state(p_match_id);
    return v_new_version;
end;
$$;

create or replace function public.draw_match_cards(
    p_match_id uuid,
    p_player_number smallint,
    p_amount integer,
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
    v_target_user_id uuid;
    v_max_hand integer;
    v_current_hand integer;
    v_draw_count integer;
    v_new_version bigint;
    v_drawn_ids jsonb;
begin
    v_match := game_private.lock_match_for_action(
        p_match_id, p_expected_version,
        array['setup','initiative','in_progress']
    );

    select mp.user_id
    into v_target_user_id
    from public.match_players mp
    where mp.match_id = p_match_id
      and mp.player_number = p_player_number;

    if v_target_user_id is null then
        raise exception 'PLAYER_NOT_FOUND';
    end if;

    -- Jogador só pode comprar para si, salvo chamadas service_role.
    if auth.role() <> 'service_role' and v_target_user_id <> v_user_id then
        raise exception 'CANNOT_DRAW_FOR_OTHER_PLAYER';
    end if;

    select grv.maximum_hand_size
    into v_max_hand
    from public.game_rule_versions grv
    where grv.id = v_match.rule_version_id;

    select count(*)::integer
    into v_current_hand
    from public.match_cards mc
    where mc.match_id = p_match_id
      and mc.owner_user_id = v_target_user_id
      and mc.zone = 'hand';

    v_draw_count := least(greatest(p_amount, 0), v_max_hand - v_current_hand);

    with cards_to_draw as (
        select mc.id,
               row_number() over (order by mc.zone_position) as rn
        from public.match_cards mc
        where mc.match_id = p_match_id
          and mc.owner_user_id = v_target_user_id
          and mc.zone = 'deck'
        order by mc.zone_position
        limit v_draw_count
    ),
    moved as (
        update public.match_cards mc
        set zone = 'hand',
            zone_position = v_current_hand + ctd.rn,
            is_face_up = false
        from cards_to_draw ctd
        where mc.id = ctd.id
        returning mc.id
    )
    select coalesce(jsonb_agg(id), '[]'::jsonb)
    into v_drawn_ids
    from moved;

    select count(*)::integer
    into v_current_hand
    from public.match_cards mc
    where mc.match_id = p_match_id
      and mc.owner_user_id = v_target_user_id
      and mc.zone = 'hand';

    update public.match_players
    set mana_snapshot = v_current_hand,
        mana_available = v_current_hand,
        mana_spent_this_turn = 0
    where match_id = p_match_id
      and user_id = v_target_user_id;

    v_new_version := game_private.record_match_action(
        p_match_id,
        v_user_id,
        'cards_drawn',
        jsonb_build_object(
            'player_number', p_player_number,
            'amount', jsonb_array_length(v_drawn_ids)
        ),
        jsonb_build_object('card_instance_ids', v_drawn_ids),
        p_expected_version
    );

    return jsonb_build_object(
        'drawn_card_ids', v_drawn_ids,
        'state_version', v_new_version
    );
end;
$$;

create or replace function public.apply_card_damage(
    p_match_id uuid,
    p_target_match_card_id uuid,
    p_damage integer,
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
    v_new_life integer;
    v_new_version bigint;
begin
    if p_damage <= 0 then
        raise exception 'DAMAGE_MUST_BE_POSITIVE';
    end if;

    v_match := game_private.lock_match_for_action(
        p_match_id, p_expected_version,
        array['in_progress']
    );

    if v_match.active_player_id <> v_user_id then
        raise exception 'NOT_YOUR_TURN';
    end if;

    select *
    into v_card
    from public.match_cards
    where id = p_target_match_card_id
      and match_id = p_match_id
    for update;

    if not found then
        raise exception 'TARGET_CARD_NOT_FOUND';
    end if;

    v_new_life := greatest(0, v_card.current_life - p_damage);

    update public.match_cards
    set current_life = v_new_life,
        damage_taken_total = damage_taken_total + least(p_damage, v_card.current_life),
        is_destroyed = (v_new_life = 0),
        destroyed_at_turn = case when v_new_life = 0 then v_match.current_turn else destroyed_at_turn end,
        zone = case when v_new_life = 0 then 'graveyard' else zone end,
        zone_position = case when v_new_life = 0 then null else zone_position end,
        is_face_up = case when v_new_life = 0 then true else is_face_up end
    where id = p_target_match_card_id;

    insert into public.match_card_modifiers(
        match_card_id, modifier_type, current_life_delta,
        starts_on_turn, is_permanent,
        metadata
    )
    values (
        p_target_match_card_id, 'damage', -least(p_damage, v_card.current_life),
        v_match.current_turn, true,
        jsonb_build_object('actor_user_id', v_user_id)
    );

    v_new_version := game_private.record_match_action(
        p_match_id,
        v_user_id,
        'damage_applied',
        jsonb_build_object(
            'target_card_id', p_target_match_card_id,
            'damage', p_damage,
            'remaining_life', v_new_life,
            'destroyed', v_new_life = 0
        ),
        '{}'::jsonb,
        p_expected_version
    );

    return jsonb_build_object(
        'target_card_id', p_target_match_card_id,
        'current_life', v_new_life,
        'maximum_life', v_card.maximum_life,
        'destroyed', v_new_life = 0,
        'state_version', v_new_version
    );
end;
$$;

create or replace function public.heal_match_card(
    p_match_id uuid,
    p_target_match_card_id uuid,
    p_healing integer,
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
    v_new_life integer;
    v_actual_heal integer;
    v_new_version bigint;
begin
    if p_healing <= 0 then
        raise exception 'HEALING_MUST_BE_POSITIVE';
    end if;

    v_match := game_private.lock_match_for_action(
        p_match_id, p_expected_version,
        array['in_progress']
    );

    if v_match.active_player_id <> v_user_id then
        raise exception 'NOT_YOUR_TURN';
    end if;

    select *
    into v_card
    from public.match_cards
    where id = p_target_match_card_id
      and match_id = p_match_id
      and is_destroyed = false
    for update;

    if not found then
        raise exception 'HEALABLE_CARD_NOT_FOUND';
    end if;

    v_new_life := least(v_card.maximum_life, v_card.current_life + p_healing);
    v_actual_heal := v_new_life - v_card.current_life;

    update public.match_cards
    set current_life = v_new_life,
        healing_received_total = healing_received_total + v_actual_heal
    where id = p_target_match_card_id;

    insert into public.match_card_modifiers(
        match_card_id, modifier_type, current_life_delta,
        starts_on_turn, is_permanent,
        metadata
    )
    values (
        p_target_match_card_id, 'heal', v_actual_heal,
        v_match.current_turn, true,
        jsonb_build_object('actor_user_id', v_user_id)
    );

    v_new_version := game_private.record_match_action(
        p_match_id,
        v_user_id,
        'card_healed',
        jsonb_build_object(
            'target_card_id', p_target_match_card_id,
            'healing', v_actual_heal,
            'current_life', v_new_life,
            'maximum_life', v_card.maximum_life
        ),
        '{}'::jsonb,
        p_expected_version
    );

    return jsonb_build_object(
        'target_card_id', p_target_match_card_id,
        'current_life', v_new_life,
        'maximum_life', v_card.maximum_life,
        'state_version', v_new_version
    );
end;
$$;

create or replace function public.move_match_card(
    p_match_id uuid,
    p_match_card_id uuid,
    p_destination_zone text,
    p_destination_position smallint,
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
    v_slot_limit integer;
    v_new_version bigint;
begin
    v_match := game_private.lock_match_for_action(
        p_match_id, p_expected_version,
        array['setup','in_progress']
    );

    select *
    into v_card
    from public.match_cards
    where id = p_match_card_id
      and match_id = p_match_id
      and controller_user_id = v_user_id
    for update;

    if not found then
        raise exception 'CARD_NOT_CONTROLLED_BY_USER';
    end if;

    if p_destination_zone not in (
        'hand','life','reinforcement','attacker','leader','graveyard','banished'
    ) then
        raise exception 'INVALID_DESTINATION_ZONE';
    end if;

    select case p_destination_zone
        when 'life' then life_slots
        when 'reinforcement' then reinforcement_slots
        when 'attacker' then attacker_slots
        when 'leader' then 1
        else null
    end
    into v_slot_limit
    from public.game_rule_versions
    where id = v_match.rule_version_id;

    if v_slot_limit is not null then
        if p_destination_position is null
           or p_destination_position < 1
           or p_destination_position > v_slot_limit then
            raise exception 'INVALID_SLOT_POSITION';
        end if;

        if exists (
            select 1
            from public.match_cards
            where match_id = p_match_id
              and controller_user_id = v_user_id
              and zone = p_destination_zone
              and zone_position = p_destination_position
              and id <> p_match_card_id
        ) then
            raise exception 'SLOT_ALREADY_OCCUPIED';
        end if;
    end if;

    if p_destination_zone in ('life','reinforcement','attacker','leader')
       and v_card.zone <> 'hand' then
        raise exception 'CARD_MUST_BE_IN_HAND';
    end if;

    if p_destination_zone in ('life','reinforcement','attacker')
       and exists (
           select 1
           from public.cards c
           where c.id = v_card.source_card_id
             and c.rarity = 'legendary'
       )
       and exists (
           select 1
           from public.match_cards mc
           join public.cards c on c.id = mc.source_card_id
           where mc.match_id = p_match_id
             and mc.controller_user_id = v_user_id
             and mc.zone in ('life','reinforcement','attacker')
             and mc.is_destroyed = false
             and c.rarity = 'legendary'
             and mc.id <> p_match_card_id
       ) then
        raise exception 'LEGENDARY_FIELD_LIMIT_REACHED';
    end if;

    update public.match_cards
    set zone = p_destination_zone,
        zone_position = case
            when p_destination_zone in ('life','reinforcement','attacker','leader')
                then p_destination_position
            else null
        end,
        is_face_up = case
            when p_destination_zone in ('life','attacker','leader','graveyard','banished')
                then true
            when p_destination_zone = 'reinforcement'
                then false
            else is_face_up
        end,
        entered_zone_turn = v_match.current_turn
    where id = p_match_card_id;

    v_new_version := game_private.record_match_action(
        p_match_id,
        v_user_id,
        'card_moved',
        jsonb_build_object(
            'card_id', case
                when p_destination_zone in ('reinforcement','hand') then null
                else p_match_card_id
            end,
            'destination_zone', p_destination_zone,
            'destination_position', p_destination_position
        ),
        jsonb_build_object('card_id', p_match_card_id),
        p_expected_version
    );

    return jsonb_build_object(
        'card_id', p_match_card_id,
        'zone', p_destination_zone,
        'position', p_destination_position,
        'state_version', v_new_version
    );
end;
$$;

create or replace function public.play_match_card(
    p_match_id uuid,
    p_match_card_id uuid,
    p_destination_zone text,
    p_destination_position integer,
    p_expected_version bigint
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
    v_user_id uuid:=game_private.require_authenticated();
    v_match public.matches;
    v_card public.match_cards;
    v_card_data public.match_deck_cards;
    v_limit integer;
    v_cost integer:=0;
    v_last_swap integer;
    v_new_version bigint;
begin
    v_match:=game_private.lock_match_for_action(p_match_id,p_expected_version,array['in_progress']);
    if v_match.active_player_id<>v_user_id then raise exception 'NOT_YOUR_TURN'; end if;
    if p_destination_zone not in ('reinforcement','attacker','leader') then raise exception 'INVALID_PLAY_ZONE'; end if;

    select * into v_card from public.match_cards
    where id=p_match_card_id and match_id=p_match_id and controller_user_id=v_user_id and zone='hand'
    for update;
    if not found then raise exception 'CARD_NOT_IN_YOUR_HAND'; end if;
    select * into v_card_data from public.match_deck_cards where id=v_card.match_deck_card_id;

    if v_card_data.card_type='leader' and p_destination_zone<>'leader' then
        raise exception 'LEADER_MUST_USE_LEADER_SLOT';
    end if;
    if v_card_data.card_type<>'leader' and p_destination_zone='leader' then
        raise exception 'CARD_IS_NOT_A_LEADER';
    end if;

    select case p_destination_zone when 'reinforcement' then reinforcement_slots when 'attacker' then attacker_slots else 1 end
    into v_limit from public.game_rule_versions where id=v_match.rule_version_id;
    if p_destination_position is null or p_destination_position<1 or p_destination_position>v_limit then
        raise exception 'INVALID_SLOT_POSITION';
    end if;
    if exists(select 1 from public.match_cards where match_id=p_match_id and controller_user_id=v_user_id
        and zone=p_destination_zone and zone_position=p_destination_position) then raise exception 'SLOT_ALREADY_OCCUPIED'; end if;

    if v_card_data.rarity='legendary' and p_destination_zone in ('reinforcement','attacker') and exists(
        select 1 from public.match_cards mc join public.match_deck_cards d on d.id=mc.match_deck_card_id
        where mc.match_id=p_match_id and mc.controller_user_id=v_user_id
          and mc.zone in ('life','reinforcement','attacker') and mc.current_life>0 and d.rarity='legendary'
    ) then raise exception 'LEGENDARY_FIELD_LIMIT_REACHED'; end if;

    if p_destination_zone='leader' then
        if v_card_data.card_type<>'leader' then raise exception 'CARD_IS_NOT_A_LEADER'; end if;
        select leader_last_swapped_turn into v_last_swap from public.match_players
        where match_id=p_match_id and user_id=v_user_id for update;
        if exists(select 1 from public.match_cards where match_id=p_match_id and controller_user_id=v_user_id and zone='leader') then
            if v_last_swap is not null and v_match.current_turn-v_last_swap<2 then raise exception 'LEADER_SWAP_COOLDOWN'; end if;
            update public.match_cards set zone='graveyard',zone_position=null,is_face_up=true
            where match_id=p_match_id and controller_user_id=v_user_id and zone='leader';
        end if;
        v_cost:=v_card_data.leader_cooldown;
        if (select mana_available from public.match_players where match_id=p_match_id and user_id=v_user_id)<v_cost then
            raise exception 'INSUFFICIENT_MANA_FOR_LEADER';
        end if;
        update public.match_players
        set mana_available=mana_available-v_cost,mana_spent_this_turn=mana_spent_this_turn+v_cost,
            leader_last_swapped_turn=v_match.current_turn
        where match_id=p_match_id and user_id=v_user_id;
    end if;

    update public.match_cards
    set zone=p_destination_zone,zone_position=p_destination_position,
        is_face_up=(p_destination_zone<>'reinforcement'),entered_zone_turn=v_match.current_turn
    where id=p_match_card_id;
    update public.match_players set actions_this_turn=actions_this_turn+1
    where match_id=p_match_id and user_id=v_user_id;

    v_new_version:=game_private.record_match_action(
        p_match_id,v_user_id,'card_played',
        jsonb_build_object('card_id',case when p_destination_zone='reinforcement' then null else p_match_card_id end,
            'zone',p_destination_zone,'position',p_destination_position,'mana_spent',v_cost),
        jsonb_build_object('card_id',p_match_card_id),p_expected_version
    );
    return jsonb_build_object('card_id',p_match_card_id,'zone',p_destination_zone,
        'position',p_destination_position,'mana_spent',v_cost,'state_version',v_new_version);
end;
$$;

create or replace function public.replace_early_life_card(
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
    v_user_id uuid:=game_private.require_authenticated();
    v_match public.matches;
    v_card public.match_cards;
    v_card_data public.match_deck_cards;
    v_life_slots integer;
    v_before_turn integer;
    v_losses_required integer;
    v_player public.match_players;
    v_new_version bigint;
begin
    v_match:=game_private.lock_match_for_action(
        p_match_id,p_expected_version,array['in_progress']
    );

    select * into v_player
    from public.match_players
    where match_id=p_match_id and user_id=v_user_id
    for update;

    select life_slots,replacement_defense_before_turn,
           replacement_defense_losses_required
    into v_life_slots,v_before_turn,v_losses_required
    from public.game_rule_versions
    where id=v_match.rule_version_id;

    if v_match.current_turn>=v_before_turn then
        raise exception 'DEFENSE_REPLACEMENT_WINDOW_CLOSED';
    end if;
    if v_player.defense_replacement_used then
        raise exception 'DEFENSE_REPLACEMENT_ALREADY_USED';
    end if;
    if v_player.destroyed_life_count<v_losses_required then
        raise exception 'NOT_ENOUGH_DESTROYED_LIFE_CARDS';
    end if;
    if p_life_position is null or p_life_position<1 or p_life_position>v_life_slots then
        raise exception 'INVALID_LIFE_POSITION';
    end if;
    if exists(
        select 1 from public.match_cards
        where match_id=p_match_id
          and controller_user_id=v_user_id
          and zone='life'
          and zone_position=p_life_position
          and current_life>0
    ) then
        raise exception 'LIFE_SLOT_ALREADY_OCCUPIED';
    end if;

    select * into v_card
    from public.match_cards
    where id=p_match_card_id
      and match_id=p_match_id
      and owner_user_id=v_user_id
      and controller_user_id=v_user_id
      and zone='hand'
    for update;
    if not found then
        raise exception 'CARD_NOT_IN_YOUR_HAND';
    end if;

    select * into v_card_data
    from public.match_deck_cards
    where id=v_card.match_deck_card_id;

    if v_card_data.card_type='leader' then
        raise exception 'LEADER_CANNOT_BE_LIFE_CARD';
    end if;

    if v_card_data.rarity='legendary' and exists(
        select 1
        from public.match_cards mc
        join public.match_deck_cards d on d.id=mc.match_deck_card_id
        where mc.match_id=p_match_id
          and mc.controller_user_id=v_user_id
          and mc.zone in ('life','reinforcement','attacker')
          and mc.current_life>0
          and d.rarity='legendary'
    ) then
        raise exception 'LEGENDARY_FIELD_LIMIT_REACHED';
    end if;

    update public.match_cards
    set zone='life',zone_position=p_life_position,is_face_up=true,
        entered_zone_turn=v_match.current_turn,is_destroyed=false,
        destroyed_at_turn=null,current_life=greatest(1,current_life)
    where id=p_match_card_id;

    update public.match_players
    set defense_replacement_used=true,
        actions_this_turn=actions_this_turn+
            case when v_match.active_player_id=v_user_id then 1 else 0 end
    where match_id=p_match_id and user_id=v_user_id;

    v_new_version:=game_private.record_match_action(
        p_match_id,v_user_id,'early_life_card_replaced',
        jsonb_build_object(
            'player_user_id',v_user_id,
            'card_id',p_match_card_id,
            'life_position',p_life_position
        ),
        '{}'::jsonb,p_expected_version
    );

    return jsonb_build_object(
        'card_id',p_match_card_id,
        'life_position',p_life_position,
        'state_version',v_new_version
    );
end;
$$;

create or replace function public.declare_attack(
    p_match_id uuid,
    p_attacker_card_id uuid,
    p_target_card_id uuid,
    p_is_direct boolean default false,
    p_expected_version bigint default 0
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
    v_user_id uuid:=game_private.require_authenticated();
    v_match public.matches;
    v_attacker public.match_cards;
    v_target public.match_cards;
    v_target_old_zone text;
    v_result jsonb;
    v_new_version bigint;
    v_remaining integer;
    v_target_player uuid;
    v_winner boolean:=false;
    v_has_direct_attack boolean:=false;
begin
    v_match:=game_private.lock_match_for_action(p_match_id,p_expected_version,array['in_progress']);
    if v_match.active_player_id<>v_user_id then raise exception 'NOT_YOUR_TURN'; end if;

    select * into v_attacker from public.match_cards
    where id=p_attacker_card_id and match_id=p_match_id and controller_user_id=v_user_id
      and zone='attacker' and current_life>0 and has_attacked_this_turn=false for update;
    if not found then raise exception 'INVALID_ATTACKER'; end if;
    select * into v_target from public.match_cards
    where id=p_target_card_id and match_id=p_match_id and controller_user_id<>v_user_id
      and zone in ('reinforcement','life') and current_life>0 for update;
    if not found then raise exception 'INVALID_ATTACK_TARGET'; end if;
    v_target_player:=v_target.controller_user_id;
    v_target_old_zone:=v_target.zone;

    -- O cliente não pode simplesmente declarar que qualquer ataque é direto.
    -- A permissão precisa existir no snapshot imutável da carta atacante.
    select exists (
        select 1
        from jsonb_array_elements(
            coalesce(
                (select effect_definition
                 from public.match_deck_cards
                 where id=v_attacker.match_deck_card_id),
                '[]'::jsonb
            )
        ) as e(value)
        where e.value->>'effect_code' in ('direct_attack','attack_direct')
           or coalesce((e.value->'parameters'->>'ignore_reinforcement')::boolean,false)
    ) into v_has_direct_attack;

    if p_is_direct and not v_has_direct_attack then
        raise exception 'ATTACKER_HAS_NO_DIRECT_ATTACK_EFFECT';
    end if;

    if p_is_direct and v_target.zone <> 'life' then
        raise exception 'DIRECT_ATTACK_REQUIRES_LIFE_TARGET';
    end if;

    if v_target.zone='life' then
        if not p_is_direct and exists(select 1 from public.match_cards
            where match_id=p_match_id and controller_user_id=v_target_player and zone='reinforcement' and current_life>0) then
            raise exception 'REINFORCEMENT_MUST_BE_ATTACKED_FIRST';
        end if;
        if v_target.zone_position<>(select min(zone_position) from public.match_cards
            where match_id=p_match_id and controller_user_id=v_target_player and zone='life' and current_life>0) then
            raise exception 'ONLY_NEAREST_LIFE_CARD_CAN_BE_ATTACKED';
        end if;
        if (select life_destroyed_this_turn from public.match_players where match_id=p_match_id and user_id=v_user_id) then
            raise exception 'ONLY_ONE_LIFE_CARD_MAY_BE_DESTROYED_PER_TURN';
        end if;
    end if;

    -- Reforço é revelado no momento da declaração do ataque.
    if v_target.zone='reinforcement' then
        update public.match_cards set is_face_up=true where id=v_target.id;
    end if;

    v_result:=game_private.apply_damage_internal(p_match_id,v_target.id,v_attacker.current_power,v_match.current_turn);
    update public.match_cards set zone='graveyard',zone_position=null,is_face_up=true,
        has_attacked_this_turn=true where id=v_attacker.id;
    update public.match_players set actions_this_turn=actions_this_turn+1
    where match_id=p_match_id and user_id=v_user_id;

    if v_target_old_zone='life' and coalesce((v_result->>'destroyed')::boolean,false) then
        update public.match_players set destroyed_life_count=destroyed_life_count+1
        where match_id=p_match_id and user_id=v_target_player;
        update public.match_players set life_destroyed_this_turn=true
        where match_id=p_match_id and user_id=v_user_id;
    end if;

    select count(*)::integer into v_remaining from public.match_cards
    where match_id=p_match_id and controller_user_id=v_target_player and zone='life' and current_life>0;
    v_winner:=(v_remaining=0);

    v_new_version:=game_private.record_match_action(
        p_match_id,v_user_id,'attack_resolved',
        jsonb_build_object('attacker_card_id',p_attacker_card_id,'target_card_id',p_target_card_id,
            'direct',p_is_direct,'damage',v_attacker.current_power,'target_result',v_result,
            'life_remaining',v_remaining,'match_finished',v_winner),
        '{}'::jsonb,p_expected_version
    );
    if v_winner then perform game_private.finish_match(p_match_id,v_user_id,'all_life_cards_destroyed'); end if;
    return jsonb_build_object('target',v_result,'life_remaining',v_remaining,
        'match_finished',v_winner,'winner_id',case when v_winner then v_user_id else null end,
        'state_version',v_new_version);
end;
$$;

create or replace function public.activate_match_effect(
    p_match_id uuid,
    p_source_card_id uuid,
    p_effect_order integer,
    p_target_card_id uuid default null,
    p_expected_version bigint default 0
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
    v_user_id uuid:=game_private.require_authenticated();
    v_match public.matches;
    v_source public.match_cards;
    v_data public.match_deck_cards;
    v_effect jsonb;
    v_code text;
    v_target_mode text;
    v_params jsonb;
    v_is_reaction boolean;
    v_once boolean;
    v_cost integer;
    v_amount integer;
    v_target public.match_cards;
    v_result jsonb:='{}'::jsonb;
    v_new_version bigint;
    v_cap integer;
    v_random_id uuid;
    v_target_old_zone text;
    v_target_player uuid;
    v_remaining integer;
    v_match_finished boolean:=false;
    v_winner_id uuid;
begin
    v_match:=game_private.lock_match_for_action(p_match_id,p_expected_version,array['in_progress']);
    select * into v_source from public.match_cards
    where id=p_source_card_id and match_id=p_match_id and controller_user_id=v_user_id
      and zone in ('life','reinforcement','attacker','leader') and current_life>0 for update;
    if not found then raise exception 'EFFECT_SOURCE_NOT_ACTIVE'; end if;
    select * into v_data from public.match_deck_cards where id=v_source.match_deck_card_id;
    select e.value into v_effect from jsonb_array_elements(v_data.effect_definition) e(value)
    where (e.value->>'effect_order')::integer=p_effect_order limit 1;
    if v_effect is null then raise exception 'EFFECT_NOT_FOUND'; end if;

    v_code:=v_effect->>'effect_code';
    v_target_mode:=coalesce(v_effect->>'target_mode','none');
    v_params:=coalesce(v_effect->'parameters','{}'::jsonb);
    v_is_reaction:=coalesce((v_effect->>'is_reaction')::boolean,false);
    v_once:=coalesce((v_effect->>'once_per_turn')::boolean,false);
    v_cost:=coalesce((v_params->>'mana_cost')::integer,v_data.effect_mana_cost,0);
    v_amount:=coalesce((v_params->>'amount')::integer,0);
    select stat_cap into v_cap from public.game_rule_versions where id=v_match.rule_version_id;

    if v_is_reaction then
        if v_match.active_player_id=v_user_id then raise exception 'REACTION_ONLY_ON_OPPONENT_TURN'; end if;
        if (select reaction_used_this_opponent_turn from public.match_players where match_id=p_match_id and user_id=v_user_id) then
            raise exception 'REACTION_ALREADY_USED';
        end if;
    elsif v_match.active_player_id<>v_user_id then
        raise exception 'NOT_YOUR_TURN';
    end if;

    if v_source.zone='reinforcement' and not v_source.is_face_up and not v_is_reaction then
        raise exception 'HIDDEN_REINFORCEMENT_EFFECT_REQUIRES_REACTION';
    end if;

    if v_once and exists(select 1 from public.match_effect_uses where match_id=p_match_id
        and match_card_id=p_source_card_id and effect_order=p_effect_order and turn_number=v_match.current_turn) then
        raise exception 'EFFECT_ALREADY_USED_THIS_TURN';
    end if;
    if (select mana_available from public.match_players where match_id=p_match_id and user_id=v_user_id)<v_cost then
        raise exception 'INSUFFICIENT_MANA';
    end if;

    -- Resolve alvos que não dependem de escolha do cliente.
    if v_target_mode='self' then
        if p_target_card_id is not null and p_target_card_id<>v_source.id then
            raise exception 'SELF_TARGET_REQUIRED';
        end if;
        p_target_card_id:=v_source.id;
    elsif v_target_mode='nearest_life' and p_target_card_id is null then
        select id into p_target_card_id
        from public.match_cards
        where match_id=p_match_id
          and controller_user_id<>v_user_id
          and zone='life'
          and current_life>0
        order by zone_position
        limit 1;
    elsif v_target_mode in ('ally_random','enemy_random') then
        select id into p_target_card_id
        from public.match_cards
        where match_id=p_match_id
          and current_life>0
          and zone in ('life','reinforcement','attacker','leader')
          and case when v_target_mode='ally_random'
                   then controller_user_id=v_user_id
                   else controller_user_id<>v_user_id end
        order by random()
        limit 1;
    elsif v_target_mode in ('all_allies','all_enemies') then
        raise exception 'MULTI_TARGET_EFFECT_REQUIRES_DEDICATED_HANDLER';
    end if;

    if p_target_card_id is not null then
        select * into v_target from public.match_cards
        where id=p_target_card_id and match_id=p_match_id
        for update;
        if not found then raise exception 'EFFECT_TARGET_NOT_FOUND'; end if;

        v_target_old_zone:=v_target.zone;
        v_target_player:=v_target.controller_user_id;

        if v_target_mode in ('ally','self','ally_random')
           and v_target.controller_user_id<>v_user_id then
            raise exception 'ALLY_TARGET_REQUIRED';
        end if;
        if v_target_mode in ('enemy','nearest_life','enemy_random')
           and v_target.controller_user_id=v_user_id then
            raise exception 'ENEMY_TARGET_REQUIRED';
        end if;
        if v_target_mode='self' and v_target.id<>v_source.id then
            raise exception 'SELF_TARGET_REQUIRED';
        end if;
        if v_target_mode='nearest_life' and (
            v_target.zone<>'life'
            or v_target.zone_position<>(
                select min(zone_position)
                from public.match_cards
                where match_id=p_match_id
                  and controller_user_id=v_target.controller_user_id
                  and zone='life'
                  and current_life>0
            )
        ) then
            raise exception 'NEAREST_LIFE_TARGET_REQUIRED';
        end if;
        if v_target_mode in ('graveyard','deck','hand')
           and v_target.zone<>v_target_mode then
            raise exception 'TARGET_MUST_BE_IN_REQUIRED_ZONE';
        end if;
    elsif v_target_mode not in ('none','all_allies','all_enemies')
          and v_code not in ('draw','mana_gain','discard_random') then
        raise exception 'TARGET_REQUIRED';
    end if;

    update public.match_players
    set mana_available=mana_available-v_cost,mana_spent_this_turn=mana_spent_this_turn+v_cost,
        actions_this_turn=actions_this_turn+case when v_is_reaction then 0 else 1 end,
        reaction_used_this_opponent_turn=case when v_is_reaction then true else reaction_used_this_opponent_turn end
    where match_id=p_match_id and user_id=v_user_id;

    case v_code
        when 'damage' then
            if p_target_card_id is null then raise exception 'TARGET_REQUIRED'; end if;
            v_result:=game_private.apply_damage_internal(p_match_id,p_target_card_id,v_amount,v_match.current_turn);
        when 'heal' then
            if p_target_card_id is null then raise exception 'TARGET_REQUIRED'; end if;
            update public.match_cards set current_life=least(maximum_life,current_life+v_amount),
                healing_received_total=healing_received_total+least(v_amount,maximum_life-current_life)
            where id=p_target_card_id and is_destroyed=false;
            select jsonb_build_object('card_id',id,'current_life',current_life,'maximum_life',maximum_life)
            into v_result from public.match_cards where id=p_target_card_id;
        when 'power_delta' then
            if p_target_card_id is null then raise exception 'TARGET_REQUIRED'; end if;
            update public.match_cards set maximum_power=least(v_cap,greatest(0,maximum_power+v_amount)),
                current_power=least(least(v_cap,greatest(0,maximum_power+v_amount)),greatest(0,current_power+v_amount))
            where id=p_target_card_id;
            select jsonb_build_object('card_id',id,'current_power',current_power,'maximum_power',maximum_power)
            into v_result from public.match_cards where id=p_target_card_id;
        when 'max_life_delta' then
            if p_target_card_id is null then raise exception 'TARGET_REQUIRED'; end if;
            update public.match_cards set maximum_life=least(v_cap,greatest(0,maximum_life+v_amount)),
                current_life=least(least(v_cap,greatest(0,maximum_life+v_amount)),greatest(0,current_life+v_amount))
            where id=p_target_card_id;
            select jsonb_build_object('card_id',id,'current_life',current_life,'maximum_life',maximum_life)
            into v_result from public.match_cards where id=p_target_card_id;
        when 'destroy' then
            if p_target_card_id is null then raise exception 'TARGET_REQUIRED'; end if;
            v_result:=game_private.apply_damage_internal(p_match_id,p_target_card_id,v_target.current_life,v_match.current_turn);
        when 'draw' then
            v_result:=jsonb_build_object('drawn_card_ids',game_private.draw_internal(p_match_id,v_user_id,greatest(v_amount,1)));
        when 'mana_gain' then
            update public.match_players set mana_available=mana_available+greatest(v_amount,0)
            where match_id=p_match_id and user_id=v_user_id;
            v_result:=jsonb_build_object('mana_gained',greatest(v_amount,0));
        when 'return_to_hand' then
            if p_target_card_id is null then raise exception 'TARGET_REQUIRED'; end if;
            if (select count(*) from public.match_cards where match_id=p_match_id and owner_user_id=v_target.owner_user_id and zone='hand')>=10 then
                raise exception 'TARGET_HAND_FULL';
            end if;
            update public.match_cards set zone='hand',zone_position=null,is_face_up=false,is_destroyed=false where id=p_target_card_id;
            v_result:=jsonb_build_object('returned_card_id',p_target_card_id);
        when 'revive' then
            if p_target_card_id is null or v_target.owner_user_id<>v_user_id or v_target.zone<>'graveyard' then raise exception 'OWN_GRAVEYARD_TARGET_REQUIRED'; end if;
            if (select count(*) from public.match_cards where match_id=p_match_id and owner_user_id=v_user_id and zone='hand')>=10 then raise exception 'HAND_FULL'; end if;
            update public.match_cards set zone='hand',zone_position=null,is_face_up=false,is_destroyed=false,
                current_life=maximum_life where id=p_target_card_id;
            v_result:=jsonb_build_object('revived_card_id',p_target_card_id);
        when 'discard_random' then
            select mc.id into v_random_id from public.match_cards mc
            where mc.match_id=p_match_id and mc.owner_user_id<>v_user_id and mc.zone='hand'
            order by random() limit 1;
            if v_random_id is not null then
                update public.match_cards set zone='graveyard',zone_position=null,is_face_up=true where id=v_random_id;
            end if;
            v_result:=jsonb_build_object('discarded',v_random_id is not null);
        when 'reveal_reinforcement' then
            if p_target_card_id is null or v_target.zone<>'reinforcement' then raise exception 'REINFORCEMENT_TARGET_REQUIRED'; end if;
            update public.match_cards set is_face_up=true where id=p_target_card_id;
            v_result:=jsonb_build_object('revealed_card_id',p_target_card_id);
        else
            raise exception 'UNSUPPORTED_EFFECT_CODE: %',v_code;
    end case;

    -- Alterações de vida máxima também podem zerar uma carta sem passar pela
    -- rotina de dano. Normaliza imediatamente a zona e o estado destruído.
    if p_target_card_id is not null then
        update public.match_cards
        set is_destroyed=true,
            destroyed_at_turn=coalesce(destroyed_at_turn,v_match.current_turn),
            zone='graveyard',zone_position=null,is_face_up=true
        where id=p_target_card_id
          and current_life<=0
          and zone in ('life','reinforcement','attacker','leader');
    end if;

    if v_target_old_zone='life' and p_target_card_id is not null
       and exists(
           select 1 from public.match_cards
           where id=p_target_card_id
             and (is_destroyed=true or zone='graveyard' or current_life<=0)
       ) then
        update public.match_players
        set destroyed_life_count=destroyed_life_count+1
        where match_id=p_match_id and user_id=v_target_player;

        select count(*)::integer into v_remaining
        from public.match_cards
        where match_id=p_match_id
          and controller_user_id=v_target_player
          and zone='life'
          and current_life>0;

        if v_remaining=0 then
            v_match_finished:=true;
            select user_id into v_winner_id
            from public.match_players
            where match_id=p_match_id
              and user_id<>v_target_player
            order by player_number
            limit 1;
        end if;
    end if;

    insert into public.match_effect_uses(match_id,match_card_id,actor_user_id,effect_order,turn_number,is_reaction,mana_spent)
    values(p_match_id,p_source_card_id,v_user_id,p_effect_order,v_match.current_turn,v_is_reaction,v_cost);

    v_new_version:=game_private.record_match_action(
        p_match_id,v_user_id,'effect_activated',
        jsonb_build_object('source_card_id',p_source_card_id,'effect_order',p_effect_order,
            'effect_code',v_code,'target_card_id',p_target_card_id,'mana_spent',v_cost,'result',v_result),
        '{}'::jsonb,p_expected_version
    );
    if v_match_finished then
        perform game_private.finish_match(
            p_match_id,v_winner_id,'all_life_cards_destroyed_by_effect'
        );
    end if;

    return jsonb_build_object(
        'effect_code',v_code,
        'result',v_result,
        'mana_spent',v_cost,
        'match_finished',v_match_finished,
        'winner_id',case when v_match_finished then v_winner_id else null end,
        'state_version',v_new_version
    );
end;
$$;

create or replace function public.pass_turn(
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
    v_match public.matches;
    v_next_user_id uuid;
    v_new_turn integer;
    v_new_version bigint;
    v_deterioration_start integer;
    v_deterioration_mode text;
    v_percent numeric;
    v_actions integer;
    v_player1_id uuid;
    v_player2_id uuid;
    v_player1_life integer;
    v_player2_life integer;
    v_winner_id uuid;
    v_match_finished boolean:=false;
begin
    v_match := game_private.lock_match_for_action(
        p_match_id, p_expected_version,
        array['in_progress']
    );

    if v_match.active_player_id <> v_user_id then
        raise exception 'NOT_YOUR_TURN';
    end if;

    select mp.user_id
    into v_next_user_id
    from public.match_players mp
    where mp.match_id = p_match_id
      and mp.user_id <> v_user_id;

    if v_next_user_id is null then
        raise exception 'OPPONENT_NOT_FOUND';
    end if;

    select actions_this_turn into v_actions
    from public.match_players
    where match_id=p_match_id and user_id=v_user_id for update;

    -- Regra do Discord: somente quando o jogador realmente passa sem jogar,
    -- atacar ou ativar efeito, ele compra uma carta antes de entregar o turno.
    if coalesce(v_actions,0)=0 then
        perform game_private.draw_internal(p_match_id,v_user_id,1);
    end if;

    v_new_turn := v_match.current_turn + 1;

    select deterioration_start_turn, deterioration_mode, deterioration_percent
    into v_deterioration_start, v_deterioration_mode, v_percent
    from public.game_rule_versions
    where id = v_match.rule_version_id;

    -- Regra oficial configurada inicialmente: no turno 8, reduz vida máxima
    -- e vida atual pela metade uma única vez.
    if v_new_turn = v_deterioration_start
       and v_deterioration_mode = 'halve_life_once' then

        update public.match_cards
        set maximum_life = greatest(0, floor(maximum_life * 0.5)::integer),
            current_life = least(
                current_life,
                greatest(0, floor(maximum_life * 0.5)::integer)
            )
        where match_id = p_match_id
          and zone in ('deck','hand','life','reinforcement','attacker','leader','graveyard');

        insert into public.match_card_modifiers(
            match_card_id, modifier_type, max_life_delta,
            starts_on_turn, is_permanent, metadata
        )
        select
            mc.id,
            'deterioration',
            greatest(0, floor(mc.maximum_life * 0.5)::integer) - mc.maximum_life,
            v_new_turn,
            true,
            jsonb_build_object('mode','halve_life_once')
        from public.match_cards mc
        where mc.match_id = p_match_id;
    elsif v_new_turn >= v_deterioration_start
       and v_deterioration_mode in (
           'percent_life_each_turn','percent_power_and_life_each_turn'
       ) then

        update public.match_cards
        set maximum_life = greatest(
                0,
                floor(maximum_life * (1 - coalesce(v_percent,20) / 100.0))::integer
            ),
            current_life = least(
                current_life,
                greatest(
                    0,
                    floor(maximum_life * (1 - coalesce(v_percent,20) / 100.0))::integer
                )
            ),
            maximum_power = case
                when v_deterioration_mode = 'percent_power_and_life_each_turn'
                then greatest(
                    0,
                    floor(maximum_power * (1 - coalesce(v_percent,20) / 100.0))::integer
                )
                else maximum_power
            end,
            current_power = case
                when v_deterioration_mode = 'percent_power_and_life_each_turn'
                then least(
                    current_power,
                    greatest(
                        0,
                        floor(maximum_power * (1 - coalesce(v_percent,20) / 100.0))::integer
                    )
                )
                else current_power
            end
        where match_id = p_match_id;
    end if;

    -- Conta cartas de vida que acabaram de ser destruídas pela deterioração
    -- antes de movê-las ao cemitério.
    update public.match_players mp
    set destroyed_life_count=mp.destroyed_life_count+x.destroyed_count
    from (
        select controller_user_id,count(*)::integer as destroyed_count
        from public.match_cards
        where match_id=p_match_id
          and current_life<=0
          and zone='life'
        group by controller_user_id
    ) x
    where mp.match_id=p_match_id
      and mp.user_id=x.controller_user_id;

    update public.match_cards
    set is_destroyed=true,destroyed_at_turn=coalesce(destroyed_at_turn,v_new_turn),
        zone='graveyard',zone_position=null,is_face_up=true
    where match_id=p_match_id and current_life<=0
      and zone in ('life','reinforcement','attacker','leader');

    -- Limpa atacantes do jogador que terminou o turno.
    update public.match_cards
    set zone = 'graveyard',
        zone_position = null,
        is_face_up = true
    where match_id = p_match_id
      and controller_user_id = v_user_id
      and zone = 'attacker';

    update public.match_cards
    set has_attacked_this_turn = false
    where match_id = p_match_id;

    update public.match_players mp
    set reaction_used_this_opponent_turn = false,
        passed_turn = (mp.user_id = v_user_id),
        mana_spent_this_turn = case when mp.user_id = v_next_user_id then 0 else mp.mana_spent_this_turn end,
        actions_this_turn = case when mp.user_id = v_next_user_id then 0 else mp.actions_this_turn end,
        life_destroyed_this_turn = case when mp.user_id = v_next_user_id then false else mp.life_destroyed_this_turn end,
        mana_snapshot = case when mp.user_id = v_next_user_id then (
            select count(*)::integer from public.match_cards mc
            where mc.match_id=p_match_id and mc.owner_user_id=v_next_user_id and mc.zone='hand'
        ) else mp.mana_snapshot end,
        mana_available = case when mp.user_id = v_next_user_id then (
            select count(*)::integer from public.match_cards mc
            where mc.match_id=p_match_id and mc.owner_user_id=v_next_user_id and mc.zone='hand'
        ) else mp.mana_available end
    where mp.match_id = p_match_id;

    update public.matches
    set current_turn = v_new_turn,
        active_player_id = v_next_user_id
    where id = p_match_id;

    v_new_version := game_private.record_match_action(
        p_match_id,
        v_user_id,
        'turn_passed',
        jsonb_build_object(
            'new_turn', v_new_turn,
            'active_player_id', v_next_user_id
        ),
        '{}'::jsonb,
        p_expected_version
    );

    select user_id into v_player1_id
    from public.match_players
    where match_id=p_match_id and player_number=1;

    select user_id into v_player2_id
    from public.match_players
    where match_id=p_match_id and player_number=2;

    select count(*)::integer into v_player1_life
    from public.match_cards
    where match_id=p_match_id and controller_user_id=v_player1_id
      and zone='life' and current_life>0;

    select count(*)::integer into v_player2_life
    from public.match_cards
    where match_id=p_match_id and controller_user_id=v_player2_id
      and zone='life' and current_life>0;

    if v_player1_life=0 or v_player2_life=0 then
        v_match_finished:=true;
        v_winner_id:=case
            when v_player1_life=0 and v_player2_life=0 then null
            when v_player1_life=0 then v_player2_id
            else v_player1_id
        end;
        perform game_private.finish_match(
            p_match_id,v_winner_id,'deterioration_destroyed_all_life'
        );
    end if;

    return jsonb_build_object(
        'current_turn', v_new_turn,
        'active_player_id', case when v_match_finished then null else v_next_user_id end,
        'match_finished',v_match_finished,
        'winner_id',v_winner_id,
        'state_version', v_new_version
    );
end;
$$;

create or replace function public.surrender_match(
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
    v_match public.matches;
    v_winner_id uuid;
    v_new_version bigint;
begin
    v_match := game_private.lock_match_for_action(
        p_match_id, p_expected_version,
        array['ban_phase','setup','initiative','in_progress']
    );

    select user_id
    into v_winner_id
    from public.match_players
    where match_id = p_match_id
      and user_id <> v_user_id;

    v_new_version := game_private.record_match_action(
        p_match_id,
        v_user_id,
        'player_surrendered',
        jsonb_build_object(
            'surrendered_user_id', v_user_id,
            'winner_id', v_winner_id
        ),
        '{}'::jsonb,
        p_expected_version
    );

    perform game_private.finish_match(p_match_id,v_winner_id,'surrender');

    return jsonb_build_object(
        'winner_id', v_winner_id,
        'state_version', v_new_version
    );
end;
$$;

create or replace function public.cancel_waiting_match(
    p_match_id uuid,
    p_expected_version bigint
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
    v_user_id uuid:=game_private.require_authenticated();
    v_match public.matches;
    v_new_version bigint;
begin
    v_match:=game_private.lock_match_for_action(
        p_match_id,p_expected_version,array['waiting']
    );
    if v_match.created_by<>v_user_id then
        raise exception 'ONLY_CREATOR_CAN_CANCEL_WAITING_MATCH';
    end if;

    v_new_version:=game_private.record_match_action(
        p_match_id,v_user_id,'match_cancelled',
        jsonb_build_object('cancelled_by',v_user_id),
        '{}'::jsonb,p_expected_version
    );

    update public.matches
    set status='cancelled',finish_reason='cancelled_by_creator',
        finished_at=now(),active_player_id=null
    where id=p_match_id;
    perform game_private.recalculate_match_public_state(p_match_id);

    return jsonb_build_object(
        'match_id',p_match_id,'status','cancelled','state_version',v_new_version
    );
end;
$$;

create or replace function public.mark_notifications_read(
    p_notification_id uuid default null
)
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
    v_user_id uuid:=game_private.require_authenticated();
    v_count integer;
begin
    update public.notifications
    set read_at=coalesce(read_at,now())
    where user_id=v_user_id
      and read_at is null
      and (p_notification_id is null or id=p_notification_id);
    get diagnostics v_count=row_count;
    return v_count;
end;
$$;

revoke all on function public.draw_match_cards(uuid,smallint,integer,bigint) from public;
revoke all on function public.apply_card_damage(uuid,uuid,integer,bigint) from public;
revoke all on function public.heal_match_card(uuid,uuid,integer,bigint) from public;
revoke all on function public.move_match_card(uuid,uuid,text,smallint,bigint) from public;
revoke all on function public.pass_turn(uuid,bigint) from public;
revoke all on function public.surrender_match(uuid,bigint) from public;
revoke all on function public.play_match_card(uuid,uuid,text,integer,bigint) from public;
revoke all on function public.declare_attack(uuid,uuid,uuid,boolean,bigint) from public;
revoke all on function public.replace_early_life_card(uuid,uuid,integer,bigint) from public;
revoke all on function public.activate_match_effect(uuid,uuid,integer,uuid,bigint) from public;
revoke all on function public.cancel_waiting_match(uuid,bigint) from public;
revoke all on function public.mark_notifications_read(uuid) from public;

-- Operações brutas não ficam disponíveis ao navegador.
grant execute on function public.draw_match_cards(uuid,smallint,integer,bigint) to service_role;
grant execute on function public.apply_card_damage(uuid,uuid,integer,bigint) to service_role;
grant execute on function public.heal_match_card(uuid,uuid,integer,bigint) to service_role;
grant execute on function public.move_match_card(uuid,uuid,text,smallint,bigint) to service_role;

grant execute on function public.play_match_card(uuid,uuid,text,integer,bigint) to authenticated;
grant execute on function public.declare_attack(uuid,uuid,uuid,boolean,bigint) to authenticated;
grant execute on function public.replace_early_life_card(uuid,uuid,integer,bigint) to authenticated;
grant execute on function public.activate_match_effect(uuid,uuid,integer,uuid,bigint) to authenticated;
grant execute on function public.pass_turn(uuid,bigint) to authenticated;
grant execute on function public.surrender_match(uuid,bigint) to authenticated;
grant execute on function public.cancel_waiting_match(uuid,bigint) to authenticated;
grant execute on function public.mark_notifications_read(uuid) to authenticated;

-- ============================================================================
-- 21. FUNÇÕES ADMINISTRATIVAS
-- ============================================================================

create or replace function public.admin_adjust_coins(
    p_target_user_id uuid,
    p_amount bigint,
    p_reason text,
    p_idempotency_text text
)
returns bigint
language plpgsql
security definer
set search_path = ''
as $$
declare
    v_admin_id uuid := game_private.require_authenticated();
    v_key uuid;
    v_balance bigint;
begin
    if not public.is_admin() then
        raise exception 'ADMIN_REQUIRED';
    end if;

    v_key := md5(p_idempotency_text)::uuid;

    v_balance := game_private.adjust_wallet(
        p_target_user_id,
        p_amount,
        'admin_adjustment',
        'admin',
        v_admin_id,
        v_key,
        p_reason
    );

    insert into public.admin_audit_log(
        admin_user_id, action_type, target_user_id,
        target_table, target_id, details
    )
    values (
        v_admin_id, 'adjust_coins', p_target_user_id,
        'player_wallets', p_target_user_id::text,
        jsonb_build_object('amount',p_amount,'reason',p_reason,'balance',v_balance)
    );

    return v_balance;
end;
$$;

create or replace function public.admin_grant_cards(
    p_target_user_id uuid,
    p_card_id uuid,
    p_quantity integer,
    p_reason text,
    p_idempotency_text text
)
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
    v_admin_id uuid := game_private.require_authenticated();
    v_key uuid;
    v_quantity integer;
begin
    if not public.is_admin() then
        raise exception 'ADMIN_REQUIRED';
    end if;

    if p_quantity = 0 then
        raise exception 'QUANTITY_CANNOT_BE_ZERO';
    end if;

    v_key := md5(p_idempotency_text)::uuid;

    v_quantity := game_private.adjust_inventory(
        p_target_user_id,
        p_card_id,
        p_quantity,
        'admin_grant',
        v_admin_id,
        v_key,
        p_reason
    );

    insert into public.admin_audit_log(
        admin_user_id, action_type, target_user_id,
        target_table, target_id, details
    )
    values (
        v_admin_id, 'grant_cards', p_target_user_id,
        'user_cards', p_card_id::text,
        jsonb_build_object('quantity_delta',p_quantity,'reason',p_reason,'new_quantity',v_quantity)
    );

    return v_quantity;
end;
$$;

revoke all on function public.admin_adjust_coins(uuid,bigint,text,text) from public;
revoke all on function public.admin_grant_cards(uuid,uuid,integer,text,text) from public;
grant execute on function public.admin_adjust_coins(uuid,bigint,text,text) to authenticated;
grant execute on function public.admin_grant_cards(uuid,uuid,integer,text,text) to authenticated;

-- ============================================================================
-- 22. VIEWS SEGURAS
-- ============================================================================

create view public.my_wallet
with (security_invoker = true)
as
select user_id, coins, updated_at
from public.player_wallets
where user_id = auth.uid();

create view public.my_stats
with (security_invoker = true)
as
select *
from public.player_stats
where user_id = auth.uid();

-- Exibe:
-- 1) todas as cartas próprias;
-- 2) cartas do oponente somente quando públicas/reveladas;
-- 3) nunca expõe ordem de deck/mão/reforço oculto do oponente.
create view public.visible_match_cards
with (security_barrier = true)
as
select
    mc.id,
    mc.match_id,
    mc.owner_user_id,
    mc.controller_user_id,
    mc.source_card_id,
    case
        when mc.owner_user_id = auth.uid()
          or mc.is_face_up = true
          or mc.zone in ('life','attacker','leader','graveyard','banished')
        then mdc.card_name
        else null
    end as card_name,
    case
        when mc.owner_user_id = auth.uid()
          or mc.is_face_up = true
          or mc.zone in ('life','attacker','leader','graveyard','banished')
        then mdc.image_url
        else null
    end as image_url,
    case
        when mc.owner_user_id = auth.uid()
          or mc.is_face_up = true
          or mc.zone in ('life','attacker','leader','graveyard','banished')
        then mdc.rarity
        else null
    end as rarity,
    case
        when mc.owner_user_id = auth.uid()
          or mc.is_face_up = true
          or mc.zone in ('life','attacker','leader','graveyard','banished')
        then mc.current_power
        else null
    end as current_power,
    case
        when mc.owner_user_id = auth.uid()
          or mc.is_face_up = true
          or mc.zone in ('life','attacker','leader','graveyard','banished')
        then mc.maximum_power
        else null
    end as maximum_power,
    case
        when mc.owner_user_id = auth.uid()
          or mc.is_face_up = true
          or mc.zone in ('life','attacker','leader','graveyard','banished')
        then mc.current_life
        else null
    end as current_life,
    case
        when mc.owner_user_id = auth.uid()
          or mc.is_face_up = true
          or mc.zone in ('life','attacker','leader','graveyard','banished')
        then mc.maximum_life
        else null
    end as maximum_life,
    mc.zone,
    case
        when mc.owner_user_id = auth.uid()
          or mc.is_face_up = true
          or mc.zone in ('life','attacker','leader','graveyard','banished')
        then mc.zone_position
        else null
    end as zone_position,
    mc.is_face_up,
    mc.is_destroyed,
    mc.has_attacked_this_turn
from public.match_cards mc
join public.match_deck_cards mdc on mdc.id = mc.match_deck_card_id
where exists (
    select 1
    from public.match_players mp
    where mp.match_id = mc.match_id
      and mp.user_id = auth.uid()
);

create view public.visible_match_actions
with (security_barrier = true)
as
select ma.id,ma.match_id,ma.sequence_number,ma.actor_user_id,ma.action_type,
       ma.payload_public,ma.state_version_before,ma.state_version_after,ma.created_at
from public.match_actions ma
where exists(
    select 1 from public.match_players mp
    where mp.match_id=ma.match_id and mp.user_id=auth.uid()
);

grant select on public.my_wallet to authenticated;
grant select on public.my_stats to authenticated;
grant select on public.visible_match_cards to authenticated;
grant select on public.visible_match_actions to authenticated;

-- ============================================================================
-- 23. ROW LEVEL SECURITY
-- ============================================================================

alter table public.profiles enable row level security;
alter table public.user_roles enable row level security;
alter table public.player_wallets enable row level security;
alter table public.player_stats enable row level security;
alter table public.wallet_transactions enable row level security;
alter table public.app_settings enable row level security;
alter table public.game_rule_versions enable row level security;
alter table public.card_sets enable row level security;
alter table public.cards enable row level security;
alter table public.card_effects enable row level security;
alter table public.user_cards enable row level security;
alter table public.inventory_transactions enable row level security;
alter table public.pack_types enable row level security;
alter table public.pack_drop_rules enable row level security;
alter table public.pack_openings enable row level security;
alter table public.pack_opening_results enable row level security;
alter table public.daily_claims enable row level security;
alter table public.user_pack_balances enable row level security;
alter table public.pack_balance_transactions enable row level security;
alter table public.starter_grants enable row level security;
alter table public.decks enable row level security;
alter table public.deck_cards enable row level security;
alter table public.matchmaking_queue enable row level security;
alter table public.matches enable row level security;
alter table public.match_public_states enable row level security;
alter table public.match_players enable row level security;
alter table public.match_decks enable row level security;
alter table public.match_deck_cards enable row level security;
alter table public.match_cards enable row level security;
alter table public.match_card_modifiers enable row level security;
alter table public.match_actions enable row level security;
alter table public.match_bans enable row level security;
alter table public.match_reactions enable row level security;
alter table public.match_effect_uses enable row level security;
alter table public.match_rewards enable row level security;
alter table public.campaign_bosses enable row level security;
alter table public.campaign_boss_deck_cards enable row level security;
alter table public.campaign_progress enable row level security;
alter table public.campaign_attempts enable row level security;
alter table public.story_chapters enable row level security;
alter table public.story_unlocks enable row level security;
alter table public.notifications enable row level security;
alter table public.admin_audit_log enable row level security;

-- Leitura pública limitada.
create policy profiles_public_read
on public.profiles for select
to anon, authenticated
using (true);

create policy card_sets_public_read
on public.card_sets for select
to anon, authenticated
using (is_active = true or public.is_admin());

create policy cards_public_read
on public.cards for select
to anon, authenticated
using (is_active = true or public.is_admin());

create policy card_effects_public_read
on public.card_effects for select
to anon, authenticated
using (is_active = true or public.is_admin());

create policy game_rules_public_read
on public.game_rule_versions for select
to anon, authenticated
using (is_active = true or public.is_admin());

create policy app_settings_public_read
on public.app_settings for select
to anon, authenticated
using (key in (
    'game_timezone','maintenance_mode',
    'daily_pack_no_duel_cards','daily_pack_duel_cards','daily_makeup_max_days'
) or public.is_admin());

create policy pack_types_public_read
on public.pack_types for select
to anon, authenticated
using (is_active = true or public.is_admin());

create policy pack_drop_rules_admin_read
on public.pack_drop_rules for select
to authenticated
using (public.is_admin());

create policy campaign_bosses_public_read
on public.campaign_bosses for select
to anon, authenticated
using (is_active = true or public.is_admin());

create policy campaign_boss_decks_public_read
on public.campaign_boss_deck_cards for select
to authenticated
using (true);

create policy story_chapters_owned_read
on public.story_chapters for select
to authenticated
using (
    public.is_admin()
    or exists (
        select 1
        from public.story_unlocks su
        where su.chapter_id = story_chapters.id
          and su.user_id = auth.uid()
    )
);

-- Dados próprios.
create policy user_roles_own_read
on public.user_roles for select
to authenticated
using (user_id = auth.uid() or public.is_admin());

create policy wallets_own_read
on public.player_wallets for select
to authenticated
using (user_id = auth.uid() or public.is_admin());

create policy stats_read
on public.player_stats for select
to authenticated
using (true);

create policy wallet_transactions_own_read
on public.wallet_transactions for select
to authenticated
using (user_id = auth.uid() or public.is_admin());

create policy user_cards_own_read
on public.user_cards for select
to authenticated
using (user_id = auth.uid() or public.is_admin());

create policy inventory_transactions_own_read
on public.inventory_transactions for select
to authenticated
using (user_id = auth.uid() or public.is_admin());

create policy pack_openings_own_read
on public.pack_openings for select
to authenticated
using (user_id = auth.uid() or public.is_admin());

create policy pack_opening_results_own_read
on public.pack_opening_results for select
to authenticated
using (
    public.is_admin()
    or exists (
        select 1 from public.pack_openings po
        where po.id = pack_opening_results.opening_id
          and po.user_id = auth.uid()
    )
);

create policy daily_claims_own_read
on public.daily_claims for select
to authenticated
using (user_id = auth.uid() or public.is_admin());


create policy user_pack_balances_own_read
on public.user_pack_balances for select
to authenticated
using (user_id=auth.uid() or public.is_admin());

create policy pack_balance_transactions_own_read
on public.pack_balance_transactions for select
to authenticated
using (user_id=auth.uid() or public.is_admin());

create policy starter_grants_own_read
on public.starter_grants for select
to authenticated
using (user_id=auth.uid() or public.is_admin());

create policy decks_own_read
on public.decks for select
to authenticated
using (user_id = auth.uid() or public.is_admin());

create policy deck_cards_own_read
on public.deck_cards for select
to authenticated
using (
    public.is_admin()
    or exists (
        select 1 from public.decks d
        where d.id = deck_cards.deck_id
          and d.user_id = auth.uid()
    )
);

create policy queue_own_read
on public.matchmaking_queue for select
to authenticated
using (user_id = auth.uid() or public.is_admin());

create policy matches_participant_or_waiting_read
on public.matches for select
to authenticated
using (
    public.is_admin()
    or (
        status = 'waiting'
        and is_private = false
    )
    or exists (
        select 1 from public.match_players mp
        where mp.match_id = matches.id
          and mp.user_id = auth.uid()
    )
);

create policy match_public_states_participant_read
on public.match_public_states for select
to authenticated
using (
    public.is_admin()
    or exists (
        select 1 from public.match_players mp
        where mp.match_id = match_public_states.match_id
          and mp.user_id = auth.uid()
    )
);

create policy match_players_participant_read
on public.match_players for select
to authenticated
using (
    public.is_admin()
    or exists (
        select 1 from public.match_players me
        where me.match_id = match_players.match_id
          and me.user_id = auth.uid()
    )
);

create policy match_decks_own_only_read
on public.match_decks for select
to authenticated
using (user_id = auth.uid() or public.is_admin());

create policy match_deck_cards_own_only_read
on public.match_deck_cards for select
to authenticated
using (
    public.is_admin()
    or exists (
        select 1
        from public.match_decks md
        where md.id = match_deck_cards.match_deck_id
          and md.user_id = auth.uid()
    )
);

-- Tabela bruta de match_cards: apenas cartas próprias.
-- Cartas públicas do oponente são lidas pela view visible_match_cards.
create policy match_cards_own_raw_read
on public.match_cards for select
to authenticated
using (owner_user_id = auth.uid() or public.is_admin());

create policy match_modifiers_visible_read
on public.match_card_modifiers for select
to authenticated
using (
    public.is_admin()
    or exists (
        select 1
        from public.match_cards mc
        join public.match_players mp on mp.match_id = mc.match_id
        where mc.id = match_card_modifiers.match_card_id
          and mp.user_id = auth.uid()
          and (
              mc.owner_user_id = auth.uid()
              or mc.is_face_up = true
              or mc.zone in ('life','attacker','leader','graveyard','banished')
          )
    )
);

-- A tabela bruta contém payload_private. Jogadores usam visible_match_actions.
create policy match_actions_admin_raw_read
on public.match_actions for select
to authenticated
using (public.is_admin());

create policy match_bans_participant_read
on public.match_bans for select
to authenticated
using (
    public.is_admin()
    or exists (
        select 1 from public.match_players mp
        where mp.match_id = match_bans.match_id
          and mp.user_id = auth.uid()
    )
);

create policy match_reactions_own_read
on public.match_reactions for select
to authenticated
using (
    reacting_user_id = auth.uid()
    or public.is_admin()
);

create policy match_effect_uses_participant_read
on public.match_effect_uses for select
to authenticated
using (
    public.is_admin() or exists(
        select 1 from public.match_players mp
        where mp.match_id=match_effect_uses.match_id and mp.user_id=auth.uid()
    )
);

create policy match_rewards_own_read
on public.match_rewards for select
to authenticated
using (user_id = auth.uid() or public.is_admin());

create policy campaign_progress_own_read
on public.campaign_progress for select
to authenticated
using (user_id = auth.uid() or public.is_admin());

create policy campaign_attempts_own_read
on public.campaign_attempts for select
to authenticated
using (user_id = auth.uid() or public.is_admin());

create policy story_unlocks_own_read
on public.story_unlocks for select
to authenticated
using (user_id = auth.uid() or public.is_admin());

create policy notifications_own_read
on public.notifications for select
to authenticated
using (user_id = auth.uid() or public.is_admin());

create policy admin_audit_admin_read
on public.admin_audit_log for select
to authenticated
using (public.is_admin());

-- Nenhuma policy de INSERT/UPDATE/DELETE é criada nas tabelas econômicas,
-- inventário, partidas ou campanha. Escrita ocorre exclusivamente pelas RPCs
-- SECURITY DEFINER controladas acima.

-- ============================================================================
-- 24. PRIVILÉGIOS DA DATA API
-- ============================================================================

-- Revoga escrita direta de clientes em todas as tabelas sensíveis.
revoke insert, update, delete, truncate, references, trigger
on all tables in schema public
from anon, authenticated;

-- Permite SELECT; a RLS decide quais linhas cada usuário enxerga.
grant select on all tables in schema public to anon, authenticated;

-- Sequence de match_actions para funções e service role.
grant usage, select on all sequences in schema public to service_role;

-- service_role mantém acesso operacional.
grant all on all tables in schema public to service_role;
grant all on all sequences in schema public to service_role;
grant all on all functions in schema public to service_role;

-- Protege execução automática de funções novas.
alter default privileges in schema public
revoke execute on functions from public, anon;

-- ============================================================================
-- 25. REALTIME SEM APAGAR A PUBLICAÇÃO DO SUPABASE
-- ============================================================================

do $$
declare
    v_table text;
begin
    if not exists (
        select 1 from pg_publication where pubname = 'supabase_realtime'
    ) then
        execute 'create publication supabase_realtime';
    end if;

    foreach v_table in array array[
        'matches',
        'match_public_states',
        'notifications'
    ]
    loop
        if not exists (
            select 1
            from pg_publication_tables
            where pubname = 'supabase_realtime'
              and schemaname = 'public'
              and tablename = v_table
        ) then
            execute format(
                'alter publication supabase_realtime add table public.%I',
                v_table
            );
        end if;
    end loop;
end
$$;

-- Replica identidade completa apenas onde UPDATE/DELETE precisam de payload amplo.
alter table public.matches replica identity full;
alter table public.match_public_states replica identity full;
alter table public.notifications replica identity full;

-- ============================================================================
-- 26. AUTOLIMPEZA E CRON
-- ============================================================================

create or replace function public.cleanup_expired_game_data()
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
    v_expired_queue integer;
    v_expired_matches integer;
    v_deleted_actions integer;
    v_deleted_notifications integer;
begin
    update public.matchmaking_queue
    set status = 'expired'
    where status = 'searching'
      and expires_at < now();
    get diagnostics v_expired_queue = row_count;

    update public.matches
    set status = 'expired',
        finish_reason = 'timeout',
        finished_at = coalesce(finished_at, now()),
        active_player_id = null
    where status in ('waiting','ban_phase','setup','initiative','in_progress')
      and expires_at < now();
    get diagnostics v_expired_matches = row_count;

    -- Mantém ações de partidas por 180 dias.
    delete from public.match_actions ma
    using public.matches m
    where ma.match_id = m.id
      and m.status in ('finished','cancelled','expired')
      and m.finished_at < now() - interval '180 days';
    get diagnostics v_deleted_actions = row_count;

    -- Remove notificações lidas antigas.
    delete from public.notifications
    where read_at is not null
      and read_at < now() - interval '90 days';
    get diagnostics v_deleted_notifications = row_count;

    return jsonb_build_object(
        'expired_queue_entries', v_expired_queue,
        'expired_matches', v_expired_matches,
        'deleted_old_actions', v_deleted_actions,
        'deleted_old_notifications', v_deleted_notifications,
        'ran_at', now()
    );
end;
$$;

revoke all on function public.cleanup_expired_game_data() from public, anon, authenticated;
grant execute on function public.cleanup_expired_game_data() to service_role;

-- Remove o job anterior e agenda a autolimpeza. Tudo é executado
-- dinamicamente para que a migração continue funcionando mesmo quando
-- pg_cron não estiver habilitado. Nesse caso, a função permanece disponível
-- para ser chamada por uma Edge Function ou habilitada depois.
do $cron_setup$
declare
    v_job_id bigint;
    v_new_job_id bigint;
begin
    if to_regnamespace('cron') is null
       or to_regclass('cron.job') is null then
        raise notice 'Schema cron indisponível; job automático não foi criado.';
        return;
    end if;

    execute 'select jobid from cron.job where jobname = $1 limit 1'
       into v_job_id
       using 'gwent-ofieri-cleanup';

    if v_job_id is not null then
        execute 'select cron.unschedule($1)' using v_job_id;
    end if;

    execute 'select cron.schedule($1,$2,$3)'
       into v_new_job_id
       using
           'gwent-ofieri-cleanup',
           '*/15 * * * *',
           'select public.cleanup_expired_game_data();';

    raise notice 'Job gwent-ofieri-cleanup criado com id %.', v_new_job_id;
exception
    when others then
        raise notice 'Não foi possível agendar o cron de autolimpeza: %', sqlerrm;
end
$cron_setup$;

-- ============================================================================
-- 27. ÍNDICES COMPLEMENTARES PARA RLS E CONSULTAS
-- ============================================================================

create index profiles_created_idx on public.profiles(created_at);
create index user_roles_user_idx on public.user_roles(user_id);
create index player_wallets_user_idx on public.player_wallets(user_id);
create index player_stats_rating_idx on public.player_stats(ranked_rating desc);
create index pack_openings_user_date_idx on public.pack_openings(user_id, opened_at desc);
create index daily_claims_user_date_idx on public.daily_claims(user_id, game_date desc);
create index user_pack_balances_user_idx on public.user_pack_balances(user_id);
create index pack_balance_transactions_user_idx on public.pack_balance_transactions(user_id,created_at desc);
create index match_players_match_user_idx on public.match_players(match_id, user_id);
create index match_decks_match_user_idx on public.match_decks(match_id, user_id);
create index match_actions_actor_idx on public.match_actions(actor_user_id);
create index story_unlocks_user_idx on public.story_unlocks(user_id);
create index notifications_user_idx on public.notifications(user_id, created_at desc);

-- ============================================================================
-- 28. VERIFICAÇÕES FINAIS
-- ============================================================================

do $$
begin
    if not exists (
        select 1 from public.game_rule_versions where is_active = true
    ) then
        raise exception 'NO_ACTIVE_GAME_RULE_VERSION';
    end if;

    if exists (
        select 1
        from pg_class c
        join pg_namespace n on n.oid = c.relnamespace
        where n.nspname = 'public'
          and c.relname in ('profiles','cards','user_cards','decks','matches')
          and c.relrowsecurity = false
    ) then
        raise exception 'RLS_NOT_ENABLED_ON_CORE_TABLE';
    end if;
end
$$;

commit;

-- ============================================================================
-- PÓS-EXECUÇÃO
-- ============================================================================
-- 1) Cadastre card_sets, cards e card_effects.
-- 2) Cadastre pack_types e pack_drop_rules.
-- 3) Cadastre campaign_bosses e seus decks.
-- 4) Crie o primeiro administrador manualmente, no SQL Editor:
--
--    insert into public.user_roles(user_id, role)
--    values ('UUID_DO_SEU_USUARIO', 'admin')
--    on conflict do nothing;
--
-- 5) Teste RLS com usuário autenticado e anon.
-- 6) Use visible_match_cards no frontend; NÃO leia match_cards do oponente.
-- 7) Todas as alterações econômicas e de partida devem passar pelas RPCs.
-- 8) Os efeitos comuns já usam card_effects; efeitos totalmente inéditos devem receber um novo effect_code e handler versionado.
-- ============================================================================
