-- Migration 202608030240_fix_ghost_effects_and_mapping.sql
-- Alinhamento de chaves de efeitos (Mapping Mismatch) e atualização de target_mode/effect_definition

BEGIN;

-- 1. Atualizar a tabela card_effects com os códigos e modos de alvo corretos
-- target_mode: enemy
UPDATE public.card_effects ce
SET target_mode = 'enemy', trigger_type = 'manual'
FROM public.cards c
WHERE ce.card_id = c.id
  AND c.name IN ('Endriuga', 'Pantera', 'Cão Selvagem', 'Shaelmar', 'Alquimista a Moira', 'Ciri', 'Yennefer', 'Varuss o Meio Elfo', 'ArqueGriffo', 'Morvudd', 'Garklain', 'Salusia');

-- target_mode: ally
UPDATE public.card_effects ce
SET target_mode = 'ally', trigger_type = 'manual'
FROM public.cards c
WHERE ce.card_id = c.id
  AND c.name IN ('Tomira', 'Celenia Vorgues a Elfa', 'Lirenne Vorgues a Barda Elfa', 'Ge''els', 'Francesca Findabair', 'Trevor da Escola da Manticora', 'Arella da Escola do Grifo', 'Venger o Mercenário', 'Arnaghad');

-- target_mode: hand
UPDATE public.card_effects ce
SET target_mode = 'hand', trigger_type = 'manual'
FROM public.cards c
WHERE ce.card_id = c.id
  AND c.name IN ('Erinia', 'Aparição Noturna', 'Necroso', 'Barroso', 'Dudu Biberveld', 'Eveline Gallo', 'Udalryk o Atormentado', 'Bruxa Áquatica', 'Yrsa de Hindar', 'Darion da Escola do Gato', 'Troll', 'Cutelo', 'Baltazar', 'Hattori o Elfo Ferreiro', 'Ciclope', 'Dandelion', 'Liche Ancião', 'Feiticeira Selenne', 'Falken', 'Érebo Luch Grännic');

-- target_mode: deck
UPDATE public.card_effects ce
SET target_mode = 'deck', trigger_type = 'manual'
FROM public.cards c
WHERE ce.card_id = c.id
  AND c.name IN ('Dilion Vorgues', 'Reynold Longmes', 'Tamara Stranger', 'Vimme Vivaldi', 'Síle de Tansarville', 'Kiyan', 'Vaca', 'Arquespora', 'Feiticeira Scalet', 'Canoleta', 'AVALACH', 'Noldorath o Elfo Navegador', 'Tissaia', 'Shaw Okami o Mago', 'Jansen da Escola da Coruja', 'Enel Ducat', 'Scyla da Escola da Coruja', 'Kalemir da Escola do Lobo', 'Dragão Myrgtabrakke', 'Thaler', 'Ida Emean', 'Gezras de Leyda', 'Principe Helel', 'Stregobor o Mago', 'Iris de Cintra');

-- target_mode: graveyard
UPDATE public.card_effects ce
SET target_mode = 'graveyard', trigger_type = 'manual'
FROM public.cards c
WHERE ce.card_id = c.id
  AND c.name IN ('Carniçal', 'Feitiçeira Sylvanna', 'Beann''shie', 'Régis', 'Sylvano', 'General Franz de Teméria', 'Sigrith Gowdie', 'Principe Adrian de Kaedwen', 'Berseker', 'Marlene de Trastamara', 'Súcubo', 'Hym');

-- 2. Corrigir códigos de efeito genéricos que possam estar na tabela card_effects
UPDATE public.card_effects ce
SET effect_code = 'common_drowner_mill', trigger_type = 'on_destroyed', target_mode = 'hand'
FROM public.cards c
WHERE ce.card_id = c.id AND c.code = 'COMMON_027';

UPDATE public.card_effects ce
SET effect_code = 'common_anna_increase_hand_costs', trigger_type = 'manual', target_mode = 'none'
FROM public.cards c
WHERE ce.card_id = c.id AND c.code = 'COMMON_065';

-- Padrão de segurança para quaisquer nulos ou vazios
UPDATE public.card_effects 
SET target_mode = 'none' 
WHERE target_mode IS NULL OR target_mode = '';

-- 3. Bloco dinâmico de segurança caso colunas effect_code ou effect_definition existam diretamente na tabela cards
DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'cards' AND table_schema = 'public' AND column_name = 'effect_code'
    ) THEN
        UPDATE public.cards SET effect_code = 'common_drowner_mill' WHERE code = 'COMMON_027';
        UPDATE public.cards SET effect_code = 'common_anna_increase_hand_costs' WHERE code = 'COMMON_065';
    END IF;

    IF EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'cards' AND table_schema = 'public' AND column_name = 'effect_definition'
    ) THEN
        UPDATE public.cards SET effect_definition = '[{"trigger_type": "on_destroyed", "target_mode": "hand"}]'::jsonb WHERE code = 'COMMON_027';
        UPDATE public.cards SET effect_definition = '[{"trigger_type": "manual", "target_mode": "none"}]'::jsonb WHERE code = 'COMMON_065';
    END IF;
END $$;

-- 4. Sincronizar deck snapshots de partidas ativas
UPDATE public.match_deck_cards mdc 
SET effect_definition = COALESCE((
    SELECT jsonb_agg(jsonb_build_object(
        'effect_order', ce.effect_order,
        'trigger_type', ce.trigger_type,
        'effect_code', ce.effect_code,
        'target_mode', ce.target_mode,
        'parameters', ce.parameters,
        'priority', ce.priority,
        'is_reaction', ce.is_reaction,
        'once_per_turn', ce.once_per_turn,
        'is_active', ce.is_active
    ) ORDER BY ce.effect_order)
    FROM public.card_effects ce 
    WHERE ce.card_id = mdc.source_card_id AND ce.is_active = true
), '[]'::jsonb);

COMMIT;
