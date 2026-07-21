-- Auditoria instalável: a migração falha se qualquer uma das 72 cartas,
-- definições ou ramos individuais do laboratório estiver ausente.
begin;

do $$
declare v_index integer;v_code text;v_missing text[]:='{}';v_report text;
begin
  select pg_get_functiondef('public.get_sandbox_test_report(uuid)'::regprocedure) into v_report;
  for v_index in 0..71 loop
    v_code:='COMMON_'||lpad(v_index::text,3,'0');
    if not exists(select 1 from public.cards c where c.code=v_code and c.is_active) then v_missing:=array_append(v_missing,v_code||':card');end if;
    if not exists(select 1 from public.card_effects e join public.cards c on c.id=e.card_id where c.code=v_code and e.is_active) then v_missing:=array_append(v_missing,v_code||':effect');end if;
    if position(v_code in v_report)=0 then v_missing:=array_append(v_missing,v_code||':assertion');end if;
  end loop;
  if cardinality(v_missing)>0 then raise exception 'LAB_72_INSTALLATION_INCOMPLETE: %',array_to_string(v_missing,', ');end if;
end $$;

create or replace function public.audit_authoritative_lab()
returns jsonb language plpgsql stable security definer set search_path='' as $$
declare v_actor uuid:=game_private.require_authenticated();v_missing_cards text[];v_missing_effects text[];v_report text;v_missing_contracts text[]:='{}';v_index integer;v_code text;
begin
  select coalesce(array_agg(expected.code order by expected.code),'{}') into v_missing_cards
  from (select 'COMMON_'||lpad(gs::text,3,'0') code from generate_series(0,71) gs) expected
  where not exists(select 1 from public.cards c where c.code=expected.code and c.is_active);
  select coalesce(array_agg(expected.code order by expected.code),'{}') into v_missing_effects
  from (select 'COMMON_'||lpad(gs::text,3,'0') code from generate_series(0,71) gs) expected
  where not exists(select 1 from public.card_effects e join public.cards c on c.id=e.card_id where c.code=expected.code and e.is_active);
  select pg_get_functiondef('public.get_sandbox_test_report(uuid)'::regprocedure) into v_report;
  for v_index in 0..71 loop v_code:='COMMON_'||lpad(v_index::text,3,'0');if position(v_code in v_report)=0 then v_missing_contracts:=array_append(v_missing_contracts,v_code);end if;end loop;
  return jsonb_build_object('success',cardinality(v_missing_cards)=0 and cardinality(v_missing_effects)=0 and cardinality(v_missing_contracts)=0,
    'audited_by',v_actor,'expected_cards',72,'active_cards',(select count(*) from public.cards where code~'^COMMON_[0-9]{3}$' and is_active),
    'active_effect_definitions',(select count(distinct c.code) from public.card_effects e join public.cards c on c.id=e.card_id where c.code~'^COMMON_[0-9]{3}$' and e.is_active),
    'individual_report_branches',72-cardinality(v_missing_contracts),'missing_cards',to_jsonb(v_missing_cards),'missing_effects',to_jsonb(v_missing_effects),'missing_contracts',to_jsonb(v_missing_contracts));
end $$;

revoke all on function public.audit_authoritative_lab() from public,anon;
grant execute on function public.audit_authoritative_lab() to authenticated;
notify pgrst,'reload schema';
commit;
