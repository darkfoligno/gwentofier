-- Pode ser executado imediatamente depois da inserção do catálogo (migração 005).
select count(*) as common_catalog_count,
       min(code) as first_code,
       max(code) as last_code,
       count(*) filter(where is_active) as active_count
from public.cards where code like 'COMMON_%';

select code,name,base_power,base_max_life,effect_mana_cost,element,rarity,card_type
from public.cards where code like 'COMMON_%' order by code;
