-- Área editorial para cartas ainda incompletas. Não participa do gacha nem de partidas.
create table if not exists public.card_design_staging (
  source_number integer not null,
  proposed_code text,
  name text not null,
  rarity text not null default 'common' check (rarity in ('common','rare','epic','legendary')),
  element text,
  image_url text,
  base_power integer,
  base_max_life integer,
  effect_mana_cost integer,
  effect_text text not null,
  proposed_trigger_type text,
  proposed_effect_code text,
  proposed_target_mode text,
  proposed_parameters jsonb not null default '{}'::jsonb,
  implementation_status text not null default 'audited' check (implementation_status in ('audited','needs_decision','handler_required','tested','ready_to_publish')),
  editorial_notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  primary key(source_number),
  unique(proposed_code)
);

alter table public.card_design_staging enable row level security;
drop policy if exists card_design_staging_editor_read on public.card_design_staging;
create policy card_design_staging_editor_read on public.card_design_staging for select to authenticated using (exists(select 1 from public.user_roles where user_id=auth.uid() and role in ('content_editor','game_master','admin')));

-- Publicação deliberadamente não é automática: somente cartas completas, com handler
-- testado, devem ser promovidas para cards/card_effects. Isso evita CARD_CATALOG_EMPTY,
-- efeitos declarados sem executor e valores inventados para campos obrigatórios.
