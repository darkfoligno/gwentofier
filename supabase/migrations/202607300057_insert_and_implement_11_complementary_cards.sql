-- Migration 202607300057_insert_and_implement_11_complementary_cards.sql
-- Saneamento de acentos e padronização Dourada/Lendária.
-- Inserção das 11 cartas complementares.

BEGIN;

-- =========================================================================
-- SEÇÃO 1: NORMALIZAÇÃO DE ELEMENTOS (SQL SANITIZATION)
-- =========================================================================

UPDATE public.cards SET element = 'Bestiario' WHERE element IN ('Bestiário', 'bestiario', 'bestiário');
UPDATE public.cards SET element = 'Elfica' WHERE element IN ('Élfica', 'élfica', 'elfica');
UPDATE public.cards SET element = 'Anao' WHERE element IN ('Anão', 'anão', 'anao');
UPDATE public.cards SET element = 'M&F' WHERE element IN ('m&f', 'M e F', 'Magia e Feitiaria', 'M&amp;F');
UPDATE public.cards SET element = 'Witcher' WHERE element IN ('witcher', 'Bruxo', 'bruxo');
UPDATE public.cards SET element = 'Civil' WHERE element IN ('civil', 'Humano');
UPDATE public.cards SET element = 'Vampiro' WHERE element IN ('vampiro', 'Vampiros');

-- =========================================================================
-- SEÇÃO 2: INSERÇÃO DAS 11 CARTAS COMPLEMENTARES
-- =========================================================================

DO $$
DECLARE
    v_set_id uuid;
BEGIN
    SELECT id INTO v_set_id FROM public.card_sets ORDER BY created_at ASC LIMIT 1;
    IF v_set_id IS NULL THEN
        INSERT INTO public.card_sets (name, code, description) VALUES ('Expansão Complementar', 'COMP', 'Lote de cartas complementares') RETURNING id INTO v_set_id;
    END IF;

    -- 1. Inserir as cartas
    INSERT INTO public.cards (set_id, code, name, image_url, element, rarity, card_type, is_golden, is_original_rpg, base_power, base_max_life, effect_mana_cost, tier, effect_text)
    VALUES
    (v_set_id, 'EXTRA_COM_01', 'Principe Adrian de Kaedwen', 'https://i.postimg.cc/bwCBxBzH/princpa.webp', 'Civil', 'common', 'normal', false, false, 1600, 1500, 2, 1, 'Ative este efeito e traga uma carta de raridade comum (rarity = ''common'') à sua escolha do seu cemitério de volta para a sua mão.'),
    (v_set_id, 'EXTRA_RARE_01', 'Altair da Escola do Lobo', 'https://i.postimg.cc/5XfdFH5d/content.webp', 'Witcher', 'rare', 'normal', false, false, 1800, 1500, 2, 1, 'Esta carta ataca diretamente uma Carta de Vida do oponente ignorando reforços, SE houver a carta "Feiticeira Selenne" (EXTRA_RARE_02) na sua mão.'),
    (v_set_id, 'EXTRA_RARE_02', 'Feiticeira Selenne', 'https://i.postimg.cc/VdqP69tf/content-(4).webp', 'M&F', 'rare', 'normal', false, false, 1000, 1000, 0, 1, 'Ative e descarte quantas cartas você quiser da sua mão para o cemitério. Cada carta descartada aumenta permanentemente em +2000 a Vida e +2000 o Poder de Selenne.'),
    (v_set_id, 'EXTRA_RARE_03', 'Arella da Escola do Grifo', 'https://i.postimg.cc/VdqP69t1/content-(2).webp', 'Witcher', 'rare', 'normal', false, false, 1200, 2600, 6, 1, 'Inverta permanentemente os valores de Poder e Vida de alguma carta aliada presente na sua mão ou no seu campo à sua escolha.'),
    (v_set_id, 'EXTRA_RARE_04', 'Alpor', 'https://encrypted-tbn0.gstatic.com/images?q=tbn:ANd9GcSFsM8JTCLnYFzFvaMbGBR1pwFyahCtvWadT99kOrOL3w&s=10', 'Vampiro', 'rare', 'normal', false, false, 2000, 2000, 3, 1, 'Ao ativar este feitiço, durante o ataque desta rodada, 10% de todo dano causado por Alpor cura (aumenta a Vida atual) de uma Carta de Vida aliada aleatória no seu campo.'),
    (v_set_id, 'EXTRA_RARE_05', 'Protofleders', 'https://encrypted-tbn0.gstatic.com/images?q=tbn:ANd9GcSOragcVQx0LfwTJ-ynkLNVsZf2Osg2yQ-PaTs2mNKxOQ&s', 'Vampiro', 'rare', 'normal', false, false, 2900, 2700, 5, 1, 'Ao ativar, 50% de chance de desferir um ataque direto com seu Poder (2900) contra uma Carta de Vida inimiga aleatória, e 50% de chance de falhar completamente.'),
    (v_set_id, 'EXTRA_RARE_06', 'Lamia', 'https://encrypted-tbn0.gstatic.com/images?q=tbn:ANd9GcQr8N2NPsiQMbEem6pTYTeEpjnYP_yK_CE7yz2Qei2zmw&s=10', 'Vampiro', 'rare', 'normal', false, false, 1800, 2500, 0, 1, 'Passivo no cemitério. No início de cada rodada, se o jogador tiver menos cartas na mão do que o limite máximo atual, Lamia ressuscita do cemitério para a mão.'),
    (v_set_id, 'EXTRA_RARE_07', 'Darion da Escola do Gato', 'https://i.postimg.cc/BnqrcF2Z/darion.jpg', 'Witcher', 'rare', 'normal', false, false, 2000, 1000, 3, 1, 'Ative este efeito e roube/sequestre compulsoriamente 1 carta aleatória da mão do oponente direto para a sua mão.'),
    (v_set_id, 'EXTRA_RARE_08', 'Dismas da Escola da Manticora', 'http://thewitcherrpg.ucoz.com.br/895362651.jpg', 'Witcher', 'rare', 'normal', false, false, 1500, 3000, 2, 1, 'Ao ser destruído no campo de reforço, cura (ou adiciona) +1000 de Vida diretamente à Carta de Vida aliada mais próxima de seu slot na mesa.'),
    (v_set_id, 'EXTRA_EPIC_01', 'Razen de Tauren', 'http://thewitcherrpg.ucoz.com.br/novapasta/novissima/razen.jpg', 'Witcher', 'epic', 'normal', false, false, 2800, 2700, 2, 2, 'Ative e destrua instantaneamente TODAS as cartas em campo cujos feitiços ou passivas impessam ou bloqueiem ataques diretos à Vida.'),
    (v_set_id, 'EXTRA_LEG_01', 'Princesa Lyra de Dol Blathanna', 'https://i.postimg.cc/vcrwB7n8/content-(1).webp', 'Elfica', 'legendary', 'normal', false, false, 2500, 2500, 0, 3, 'Passivo na mão. Enquanto Lyra estiver na sua mão, a carta com o custo de mana originalmente mais caro dentro do seu deck terá o seu custo fixado em = 5.')
    ON CONFLICT (code) DO UPDATE SET
        name = EXCLUDED.name,
        image_url = EXCLUDED.image_url,
        base_power = EXCLUDED.base_power,
        base_max_life = EXCLUDED.base_max_life,
        effect_mana_cost = EXCLUDED.effect_mana_cost,
        effect_text = EXCLUDED.effect_text,
        tier = EXCLUDED.tier;

    -- 2. Inserir os Efeitos blindados com target_mode padronizado e parâmetros JSONB

    INSERT INTO public.card_effects (card_id, trigger_type, effect_code, target_mode, parameters)
    SELECT id, 'manual', 'comp_adrian_common_revive_hand', 'none', '{"mana_cost": 2, "target_scope": "common_graveyard_tutor"}' FROM public.cards WHERE code = 'EXTRA_COM_01' ON CONFLICT DO NOTHING;

    INSERT INTO public.card_effects (card_id, trigger_type, effect_code, target_mode, parameters)
    SELECT id, 'manual', 'comp_altair_selenne_direct_snipe', 'none', '{"mana_cost": 2, "required_zone": "attacker"}' FROM public.cards WHERE code = 'EXTRA_RARE_01' ON CONFLICT DO NOTHING;

    INSERT INTO public.card_effects (card_id, trigger_type, effect_code, target_mode, parameters)
    SELECT id, 'manual', 'comp_selenne_discard_scaling_buff', 'none', '{"mana_cost": 0}' FROM public.cards WHERE code = 'EXTRA_RARE_02' ON CONFLICT DO NOTHING;

    INSERT INTO public.card_effects (card_id, trigger_type, effect_code, target_mode, parameters)
    SELECT id, 'manual', 'comp_arella_stat_inversion', 'target_card', '{"mana_cost": 6, "target_scope": "my_field_or_hand"}' FROM public.cards WHERE code = 'EXTRA_RARE_03' ON CONFLICT DO NOTHING;

    INSERT INTO public.card_effects (card_id, trigger_type, effect_code, target_mode, parameters)
    SELECT id, 'manual', 'comp_alpor_lifesteal_tenth', 'none', '{"mana_cost": 3, "required_zone": "attacker"}' FROM public.cards WHERE code = 'EXTRA_RARE_04' ON CONFLICT DO NOTHING;

    INSERT INTO public.card_effects (card_id, trigger_type, effect_code, target_mode, parameters)
    SELECT id, 'manual', 'comp_protofleders_coinflip_snipe', 'none', '{"mana_cost": 5}' FROM public.cards WHERE code = 'EXTRA_RARE_05' ON CONFLICT DO NOTHING;

    INSERT INTO public.card_effects (card_id, trigger_type, effect_code, target_mode, parameters)
    SELECT id, 'on_round_start', 'comp_lamia_graveyard_return_loop', 'none', '{"mana_cost": 0, "required_zone": "graveyard"}' FROM public.cards WHERE code = 'EXTRA_RARE_06' ON CONFLICT DO NOTHING;

    INSERT INTO public.card_effects (card_id, trigger_type, effect_code, target_mode, parameters)
    SELECT id, 'manual', 'comp_darion_hand_robbery', 'none', '{"mana_cost": 3}' FROM public.cards WHERE code = 'EXTRA_RARE_07' ON CONFLICT DO NOTHING;

    INSERT INTO public.card_effects (card_id, trigger_type, effect_code, target_mode, parameters)
    SELECT id, 'on_destroyed', 'comp_dismas_death_heal_adjacent_life', 'none', '{"mana_cost": 2, "required_zone": "reinforcement"}' FROM public.cards WHERE code = 'EXTRA_RARE_08' ON CONFLICT DO NOTHING;

    INSERT INTO public.card_effects (card_id, trigger_type, effect_code, target_mode, parameters)
    SELECT id, 'manual', 'comp_razen_destroy_anti_direct_attackers', 'none', '{"mana_cost": 2}' FROM public.cards WHERE code = 'EXTRA_EPIC_01' ON CONFLICT DO NOTHING;

    INSERT INTO public.card_effects (card_id, trigger_type, effect_code, target_mode, parameters)
    SELECT id, 'passive', 'comp_lyra_cap_highest_deck_mana', 'none', '{"mana_cost": 0, "required_zone": "hand"}' FROM public.cards WHERE code = 'EXTRA_LEG_01' ON CONFLICT DO NOTHING;

END $$;

COMMIT;
