-- Execute depois da migração 015. Não altera dados.
select * from public.audit_common_effect_engine();

select c.code as card_code, c.name, e.trigger_type, e.effect_code
from public.cards c
join public.card_effects e on e.card_id=c.id and e.is_active
where c.code like 'COMMON_%'
order by c.code,e.effect_order;

select status, count(*)
from public.match_effect_events
group by status
order by status;

select created_at, effect_code, result
from public.match_effect_execution_log
order by created_at desc
limit 50;
