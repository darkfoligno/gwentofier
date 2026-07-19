-- V7.0: snapshots imutáveis de colisão e atualização direta do tabuleiro.
begin;

create or replace function game_private.enrich_combat_payload_v7(
  p_match_id uuid,
  p_payload jsonb
)
returns jsonb
language plpgsql
security definer
stable
set search_path = ''
as $$
declare
  v_item jsonb;
  v_result jsonb;
  v_enriched jsonb := '[]'::jsonb;
  v_life jsonb;
  v_card record;
  v_initial integer;
  v_final integer;
  v_damage integer;
begin
  for v_item in
    select value from jsonb_array_elements(coalesce(p_payload->'reinforcements','[]'::jsonb))
  loop
    select mc.current_power, mdc.card_name, mdc.element
    into v_card
    from public.match_cards mc
    join public.match_deck_cards mdc on mdc.id = mc.match_deck_card_id
    where mc.id = (v_item->>'card_id')::uuid and mc.match_id = p_match_id;

    v_result := coalesce(v_item->'result','{}'::jsonb);
    v_initial := greatest(0, coalesce((v_item->>'initial_hp')::integer, (v_item->>'life_before')::integer, 0));
    v_final := greatest(0, coalesce((v_item->>'final_hp')::integer, (v_result->>'current_life')::integer, 0));
    v_damage := greatest(0, coalesce((v_item->>'damage_dealt')::integer, v_initial - v_final));

    v_enriched := v_enriched || jsonb_build_array(v_item || jsonb_build_object(
      'card_name', v_card.card_name,
      'attack_power', v_card.current_power,
      'element', v_card.element,
      'initial_hp', v_initial,
      'damage_dealt', v_damage,
      'final_hp', v_final,
      'overflow_damage', greatest(0, coalesce((v_item->>'remaining_damage')::integer, 0)),
      'revealed', v_final > 0
    ));
  end loop;

  v_life := p_payload->'life';
  if v_life is not null and jsonb_typeof(v_life) = 'object' then
    select mc.current_power, mdc.card_name, mdc.element
    into v_card
    from public.match_cards mc
    join public.match_deck_cards mdc on mdc.id = mc.match_deck_card_id
    where mc.id = (v_life->>'card_id')::uuid and mc.match_id = p_match_id;

    v_result := coalesce(v_life->'result','{}'::jsonb);
    v_initial := greatest(0, coalesce((v_life->>'initial_hp')::integer, (v_life->>'life_before')::integer, 0));
    v_final := greatest(0, coalesce((v_life->>'final_hp')::integer, (v_result->>'current_life')::integer, 0));
    v_damage := greatest(0, coalesce((v_life->>'damage_dealt')::integer, (v_life->>'damage_received')::integer, v_initial - v_final));
    v_life := v_life || jsonb_build_object(
      'card_name', v_card.card_name,
      'attack_power', v_card.current_power,
      'element', v_card.element,
      'initial_hp', v_initial,
      'damage_dealt', v_damage,
      'final_hp', v_final,
      'overflow_damage', greatest(0, coalesce((v_life->>'discarded_overflow')::integer, 0)),
      'revealed', true
    );
  end if;

  return p_payload || jsonb_build_object('reinforcements', v_enriched, 'life', v_life);
end;
$$;

create or replace function game_private.freeze_combat_action_v7()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.action_type = 'attack_resolved' then
    new.payload_public := game_private.enrich_combat_payload_v7(new.match_id, new.payload_public);
  end if;
  return new;
end;
$$;

drop trigger if exists match_actions_freeze_combat_v7 on public.match_actions;
create trigger match_actions_freeze_combat_v7
before insert or update of payload_public on public.match_actions
for each row execute function game_private.freeze_combat_action_v7();

create or replace function game_private.freeze_pending_combat_v7()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.status = 'resolved' and old.status is distinct from 'resolved' then
    new.result := game_private.enrich_combat_payload_v7(new.match_id, new.result);
  end if;
  return new;
end;
$$;

drop trigger if exists pending_attacks_freeze_combat_v7 on public.pending_attacks;
create trigger pending_attacks_freeze_combat_v7
before update of status on public.pending_attacks
for each row execute function game_private.freeze_pending_combat_v7();

-- O evento da tabela funciona somente como invalidador; o cliente continua
-- lendo a view sanitizada, portanto nenhuma carta oculta é exposta.
do $$
begin
  if exists(select 1 from pg_publication where pubname='supabase_realtime')
     and not exists(
       select 1 from pg_publication_tables
       where pubname='supabase_realtime' and schemaname='public' and tablename='match_cards'
     ) then
    alter publication supabase_realtime add table public.match_cards;
  end if;
end;
$$;
alter table public.match_cards replica identity full;

notify pgrst, 'reload schema';
commit;
