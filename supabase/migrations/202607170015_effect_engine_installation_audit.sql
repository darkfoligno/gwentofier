-- Auditoria final, somente leitura dos dados de jogo. A migração falha se o pacote
-- tiver sido aplicado fora de ordem ou estiver incompleto.
create or replace function public.audit_common_effect_engine()
returns table(check_name text, expected bigint, actual bigint, ok boolean)
language sql security definer set search_path='' stable as $$
  with checks(check_name, expected, actual) as (
    values
      ('cartas comuns ativas', 72::bigint,
        (select count(*) from public.cards where code like 'COMMON_%' and is_active)),
      ('cartas com efeito ativo', 72::bigint,
        (select count(distinct c.id) from public.cards c join public.card_effects e on e.card_id=c.id and e.is_active
          where c.code like 'COMMON_%')),
      ('codigos common unicos', 72::bigint,
        (select count(distinct e.effect_code) from public.cards c join public.card_effects e on e.card_id=c.id
          where c.code like 'COMMON_%' and e.effect_code like 'common_%')),
      ('definicoes card_effects ativas', 72::bigint,
        (select count(distinct effect_code) from public.card_effects
          where effect_code like 'common_%' and is_active)),
      ('gatilho de eventos de zona', 1::bigint,
        (select count(*) from pg_catalog.pg_trigger
          where tgname='match_cards_queue_effect_events' and not tgisinternal)),
      ('gatilho despachante de acoes', 1::bigint,
        (select count(*) from pg_catalog.pg_trigger
          where tgname='match_actions_bridge_effects' and not tgisinternal)),
      ('gatilho de regras de ataque', 1::bigint,
        (select count(*) from pg_catalog.pg_trigger
          where tgname='pending_attack_cards_common_rules' and not tgisinternal)),
      ('executor publico v2', 1::bigint,
        case when pg_catalog.to_regprocedure('public.activate_card_effect_v2(uuid,uuid,integer,uuid,bigint)') is null then 0 else 1 end),
      ('executor privado comum', 1::bigint,
        case when pg_catalog.to_regprocedure('game_private.execute_common_effect_internal(uuid,uuid,uuid,text,jsonb,uuid,jsonb)') is null then 0 else 1 end),
      ('processador da fila', 1::bigint,
        case when pg_catalog.to_regprocedure('game_private.process_match_effect_queue(uuid)') is null then 0 else 1 end),
      ('escolha pendente', 1::bigint,
        case when pg_catalog.to_regclass('public.pending_effect_choices') is null then 0 else 1 end),
      ('realtime seguro de efeitos', 1::bigint,
        case when pg_catalog.to_regclass('public.visible_match_card_effects') is null then 0 else 1 end)
  )
  select check_name, expected, actual, actual=expected from checks
  order by check_name
$$;

revoke all on function public.audit_common_effect_engine() from public,anon;
grant execute on function public.audit_common_effect_engine() to authenticated;

do $$
declare failed text;
begin
  select string_agg(format('%s (esperado %s, encontrado %s)',check_name,expected,actual),'; ')
    into failed from public.audit_common_effect_engine() where not ok;
  if failed is not null then
    raise exception 'COMMON_EFFECT_ENGINE_INCOMPLETE: %',failed;
  end if;
end $$;
