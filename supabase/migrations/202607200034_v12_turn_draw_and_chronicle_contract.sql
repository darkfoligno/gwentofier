-- V12.0: saque obrigatório a partir do Turno 2 e metadados narrativos.
begin;

-- A guarda V2 só suprime a compra quando esta flag está falsa. Marcá-la antes
-- da transição para o Turno 2 remove o antigo atalho sem descartar as demais
-- proteções de movimento de carta presentes em guard_common_card_movement().
create or replace function game_private.enable_draw_from_turn_two_v12()
returns trigger language plpgsql security definer set search_path='' as $$
begin
  if new.current_turn>=2 and old.current_turn<2 then
    new.second_player_opening_draw_skipped:=true;
  end if;
  return new;
end $$;
drop trigger if exists matches_enable_draw_from_turn_two_v12 on public.matches;
create trigger matches_enable_draw_from_turn_two_v12 before update of current_turn on public.matches for each row execute function game_private.enable_draw_from_turn_two_v12();

-- Remove a falsificação antiga do payload que declarava ausência de saque no
-- Turno 2 mesmo quando a regra geral de troca de turno registrava uma compra.
drop trigger if exists match_actions_correct_turn_draw_payload on public.match_actions;

create or replace function game_private.enrich_effect_source_zone_v12()
returns trigger language plpgsql security definer set search_path='' as $$
declare v_zone text;
begin
  if new.action_type='effect_activated' and new.payload_public->>'source_card_id' is not null then
    select mc.zone into v_zone from public.match_cards mc where mc.id=(new.payload_public->>'source_card_id')::uuid and mc.match_id=new.match_id;
    new.payload_public:=new.payload_public||jsonb_build_object('source_zone',coalesce(v_zone,'campo'));
  end if;
  return new;
end $$;
drop trigger if exists match_actions_enrich_effect_zone_v12 on public.match_actions;
create trigger match_actions_enrich_effect_zone_v12 before insert on public.match_actions for each row execute function game_private.enrich_effect_source_zone_v12();

notify pgrst,'reload schema';
commit;
