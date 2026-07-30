-- Refactor legendary cards: Arma X and Rainha Pavetta
-- ID 682b43ff-9816-4a87-9329-3274927e2503 (Arma X)
-- ID f34cb481-7c12-441d-b6f2-deec722d3279 (Rainha Pavetta)

UPDATE public.cards
SET card_type = 'normal',
    rarity = 'legendary',
    code = 'leg_arma_x',
    effect_text = 'Ataque todos os reforços, a primeira carta de defesa do inimigo e todas as cartas na mão dele. Pague +1 de mana para pular para outra defesa.'
WHERE id = '682b43ff-9816-4a87-9329-3274927e2503';

UPDATE public.cards
SET card_type = 'leader',
    rarity = 'legendary',
    code = 'leg_pavetta',
    effect_text = 'Ative uma única vez de qualquer local do campo, aumente em 2000 o poder de todas as cartas no seu deck. Se a carta Ciri (ID: 9088670c-9eb9-4bb7-96fc-9edfdb01fae6) estiver no seu deck, zere o custo de mana dela (mana_cost = 0).'
WHERE id = 'f34cb481-7c12-441d-b6f2-deec722d3279';

-- Setup card_effects entries
DELETE FROM public.card_effects WHERE card_id IN ('682b43ff-9816-4a87-9329-3274927e2503', 'f34cb481-7c12-441d-b6f2-deec722d3279');

INSERT INTO public.card_effects (card_id, effect_order, trigger_type, effect_code, target_mode, parameters, is_active)
VALUES 
('682b43ff-9816-4a87-9329-3274927e2503', 1, 'on_play', 'leg_arma_x_mass_attack', 'none', '{}'::jsonb, true),
('f34cb481-7c12-441d-b6f2-deec722d3279', 1, 'on_play', 'leg_pavetta_deck_buff', 'none', '{}'::jsonb, true);
