-- Execute no SQL Editor depois das migrações 005 e 007.
-- Não modifica dados: retorna diagnóstico do catálogo e das ligações obrigatórias.
with expected as (select 'COMMON_'||lpad(n::text,3,'0') code from generate_series(0,71) n),
catalog as (select c.* from public.cards c where c.code like 'COMMON_%')
select
  (select count(*) from catalog) as catalog_cards,
  (select count(*) from expected e left join catalog c using(code) where c.id is null) as missing_cards,
  (select count(*) from catalog c left join public.card_effects ce on ce.card_id=c.id and ce.is_active where ce.id is null) as cards_without_effect,
  (select count(*) from catalog where not is_active) as inactive_cards,
  (select count(*) from catalog where image_url is null or image_url='') as missing_images,
  (select count(*) from catalog where element not in ('Bestiário','M&F','Witcher','Elfica','Cívil','Vampiro')) as invalid_elements;

select c.code,c.name,count(ce.id) active_effects,string_agg(ce.effect_code,', ' order by ce.effect_order) effect_codes
from public.cards c left join public.card_effects ce on ce.card_id=c.id and ce.is_active
where c.code like 'COMMON_%'
group by c.id,c.code,c.name
order by c.code;

-- Cobertura comercial: regras com set_id nulo aceitam qualquer coleção; regras
-- presas a outro set não incluem OFIERI_COMMON.
select pt.code pack_code,pt.name,pt.price_coins,pt.cards_per_pack,
 count(pdr.id) filter(where pdr.set_id is null or pdr.set_id=(select id from public.card_sets where code='OFIERI_COMMON')) compatible_rules,
 count(distinct pdr.slot_number) filter(where pdr.set_id is null or pdr.set_id=(select id from public.card_sets where code='OFIERI_COMMON')) covered_slots
from public.pack_types pt left join public.pack_drop_rules pdr on pdr.pack_type_id=pt.id
where pt.is_active
group by pt.id order by pt.price_coins,pt.code;

-- Confirma a regra ativa que controla starter deck, mão e campos.
select version_name,is_active,minimum_deck_cards,maximum_deck_cards,initial_hand_size,maximum_hand_size,life_slots,reinforcement_slots,attacker_slots
from public.game_rule_versions where is_active;
