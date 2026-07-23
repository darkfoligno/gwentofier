-- Migration 202607240051_insert_and_implement_rare_batch_2.sql
-- Inserção das cartas RARE_021 a RARE_040 com target_mode = 'none' obrigatório.

BEGIN;

DO $$
DECLARE
    v_set_id uuid;
BEGIN
    SELECT id INTO v_set_id FROM public.card_sets ORDER BY created_at ASC LIMIT 1;
    IF v_set_id IS NULL THEN
        INSERT INTO public.card_sets (name, code, description) VALUES ('Expansão Rara 2', 'RARE2', 'Segundo lote de raras') RETURNING id INTO v_set_id;
    END IF;

    -- 1. Inserir as cartas do lote 2 com ON CONFLICT UPDATE
    INSERT INTO public.cards (set_id, code, name, image_url, element, rarity, card_type, is_golden, is_original_rpg, base_power, base_max_life, effect_mana_cost, tier, effect_text)
    VALUES
    (v_set_id, 'RARE_021', 'Feitiçeira Jhenny', 'https://via.placeholder.com/300x450.png?text=Gwent+Rare', 'M&F', 'rare', 'normal', false, false, 2800, 2600, 0, 1, 'Ative esse efeito e impeça que o oponente consiga reagir ao efeito de custo de mana que você ativar de uma carta do tipo M&F.'),
    (v_set_id, 'RARE_022', 'Kraken', 'https://via.placeholder.com/300x450.png?text=Gwent+Rare', 'Bestiário', 'rare', 'normal', false, false, 2400, 3000, 0, 1, 'Passivo. Esta carta só perderá no máximo 1000 de Vida por turno. O dano excedente ultrapassará para a próxima carta de reforço, mas o Kraken permanece intocável no campo após sofrer esses 1000 de dano.'),
    (v_set_id, 'RARE_023', 'Demônio', 'https://via.placeholder.com/300x450.png?text=Gwent+Rare', 'Bestiário', 'rare', 'normal', false, false, 2000, 2700, 2, 1, 'Veja todas as cartas da mão do seu oponente.'),
    (v_set_id, 'RARE_024', 'Fleder', 'https://via.placeholder.com/300x450.png?text=Gwent+Rare', 'Bestiário', 'rare', 'normal', false, false, 2100, 2600, 3, 1, 'Só pode ser ativado no Turno 1 (primeiro turno do jogo). Esta carta ataca simultaneamente as 3 Cartas de Vida do oponente.'),
    (v_set_id, 'RARE_025', 'Yrsa de Hindar', 'https://via.placeholder.com/300x450.png?text=Gwent+Rare', 'Bestiário', 'rare', 'normal', false, false, 2500, 1600, 3, 1, 'Ao ativar durante um turno de ataque, o oponente perderá (descarte para o cemitério) a carta de menor custo de mana da mão dele aleatoriamente.'),
    (v_set_id, 'RARE_026', 'Elemental', 'https://via.placeholder.com/300x450.png?text=Gwent+Rare', 'Bestiário', 'rare', 'normal', false, false, 1700, 2900, 2, 1, 'Só pode ser ativado se esta carta estiver no campo como Carta de Vida. Ao ativar, nenhuma carta com Poder superior a 4000 poderá ser colocada em campo por nenhum jogador.'),
    (v_set_id, 'RARE_027', 'Diana de Tauren', 'https://via.placeholder.com/300x450.png?text=Gwent+Rare', 'Bestiário', 'rare', 'normal', false, false, 2750, 2250, 2, 1, 'Ao ativar, uma Carta de Vida aleatória do oponente será destruída. Em contrapartida, todas as cartas de raridade lendária e épica do seu próprio deck serão destruídas e enviadas ao seu cemitério.'),
    (v_set_id, 'RARE_028', 'Feiticeira Scalet', 'https://via.placeholder.com/300x450.png?text=Gwent+Rare', 'M&F', 'rare', 'normal', false, false, 2000, 2000, 0, 1, 'Puxe uma carta do tipo Bestiário aleatória do seu deck para o campo para atacar junto desta carta.'),
    (v_set_id, 'RARE_029', 'Morvim da Escola da Coruja', 'https://via.placeholder.com/300x450.png?text=Gwent+Rare', 'Witcher', 'rare', 'normal', false, false, 1300, 600, 0, 1, 'Ao ativar, ataque uma Carta de Vida diretamente aleatória do oponente para cada carta com o nome "Ursulla" presente no deck do oponente.'),
    (v_set_id, 'RARE_030', 'Casa das Lágrimas', 'https://via.placeholder.com/300x450.png?text=Gwent+Rare', 'Bestiário', 'rare', 'normal', false, false, 2800, 3000, 4, 1, 'Só pode ser ativada quando estiver no campo como Carta de Vida. Ao ativar, esta carta só poderá ser destruída por dano de ataque normal convencional após o Turno 7 (imune a destruição por efeitos ou magias).'),
    (v_set_id, 'RARE_031', 'Kikimora', 'https://via.placeholder.com/300x450.png?text=Gwent+Rare', 'Bestiário', 'rare', 'normal', false, false, 2700, 3000, 3, 1, 'Se esta carta for destruída por uma carta do tipo Witcher do oponente, mude o custo de mana de uma carta da sua mão à sua escolha para 0.'),
    (v_set_id, 'RARE_032', 'Tordo', 'https://via.placeholder.com/300x450.png?text=Gwent+Rare', 'Bestiário', 'rare', 'normal', false, false, 2000, 2000, 0, 1, 'Devolva uma Carta de Vida do campo do oponente para a mão dele e force-o imediatamente a colocar outra carta da mão dele no lugar.'),
    (v_set_id, 'RARE_033', 'Troll de Gelo', 'https://via.placeholder.com/300x450.png?text=Gwent+Rare', 'Bestiário', 'rare', 'normal', false, false, 2100, 2700, 3, 1, 'Abra outra tela de banimento neste momento para cada jogador banir outra carta que estiver nos decks de cada um.'),
    (v_set_id, 'RARE_034', 'Feitiçeira Morgana', 'https://via.placeholder.com/300x450.png?text=Gwent+Rare', 'M&F', 'rare', 'normal', false, false, 2250, 2500, 6, 1, 'Ative na sua rodada e faça o seu oponente perder a próxima rodada dele inteira.'),
    (v_set_id, 'RARE_035', 'Etéreo', 'https://via.placeholder.com/300x450.png?text=Gwent+Rare', 'Bestiário', 'rare', 'normal', false, false, 2000, 2500, 4, 1, 'Saque para sua mão duas cartas idênticas (que tenham mais de 2 cópias) que ainda estiverem no seu deck.'),
    (v_set_id, 'RARE_036', 'Canoleta', 'https://via.placeholder.com/300x450.png?text=Gwent+Rare', 'Bestiário', 'rare', 'normal', false, false, 1000, 2700, 2, 1, 'Compre uma carta do seu deck à sua escolha (abrindo tela de seleção) que seja de raridade rara (rarity = "rare").'),
    (v_set_id, 'RARE_037', 'Zoltan', 'https://via.placeholder.com/300x450.png?text=Gwent+Rare', 'Anão', 'rare', 'normal', false, false, 2800, 1000, 3, 1, 'Ao ativar durante um turno de ataque, se esta carta conseguir destruir sozinha o primeiro reforço do oponente, destrua o segundo reforço sem sequer revelá-lo ou dar a chance do oponente ativar um efeito de reação.'),
    (v_set_id, 'RARE_038', 'Danvis Vampiro Coveiro', 'https://via.placeholder.com/300x450.png?text=Gwent+Rare', 'Bestiário', 'rare', 'normal', false, false, 2500, 1400, 3, 1, 'Aumente o custo de mana de toda a mão atual do oponente em +1.'),
    (v_set_id, 'RARE_039', 'Lagaz', 'https://via.placeholder.com/300x450.png?text=Gwent+Rare', 'Bestiário', 'rare', 'normal', false, false, 2200, 2300, 3, 1, 'Ao ativar, todos os campos vagos de reforço do oponente são preenchidos compulsoriamente por cartas aleatórias da mão dele viradas para baixo.'),
    (v_set_id, 'RARE_040', 'Súcubo', 'https://via.placeholder.com/300x450.png?text=Gwent+Rare', 'Bestiário', 'rare', 'normal', false, false, 2500, 2500, 6, 1, 'Ao ativar, uma carta aleatória do cemitério do oponente é reanimada como espectro atacante e desgere um ataque contra todas as Cartas de Vida do próprio oponente.')
    ON CONFLICT (code) DO UPDATE SET
        name = EXCLUDED.name,
        base_power = EXCLUDED.base_power,
        base_max_life = EXCLUDED.base_max_life,
        effect_mana_cost = EXCLUDED.effect_mana_cost,
        effect_text = EXCLUDED.effect_text;

    -- 2. Inserir os Efeitos blindados com target_mode = 'none' e parâmetros JSONB

    INSERT INTO public.card_effects (card_id, trigger_type, effect_code, target_mode, parameters)
    SELECT id, 'manual', 'rare_jhenny_uninterruptible_mf', 'none', '{"mana_cost": 0}' FROM public.cards WHERE code = 'RARE_021' ON CONFLICT DO NOTHING;

    INSERT INTO public.card_effects (card_id, trigger_type, effect_code, target_mode, parameters)
    SELECT id, 'passive', 'rare_kraken_damage_cap_spill', 'none', '{"mana_cost": 0}' FROM public.cards WHERE code = 'RARE_022' ON CONFLICT DO NOTHING;

    INSERT INTO public.card_effects (card_id, trigger_type, effect_code, target_mode, parameters)
    SELECT id, 'manual', 'rare_fiend_peek_hand', 'none', '{"mana_cost": 2, "target_scope": "opponent_hand"}' FROM public.cards WHERE code = 'RARE_023' ON CONFLICT DO NOTHING;

    INSERT INTO public.card_effects (card_id, trigger_type, effect_code, target_mode, parameters)
    SELECT id, 'manual', 'rare_fleder_turn1_triple_strike', 'none', '{"mana_cost": 3, "required_turn": 1}' FROM public.cards WHERE code = 'RARE_024' ON CONFLICT DO NOTHING;

    INSERT INTO public.card_effects (card_id, trigger_type, effect_code, target_mode, parameters)
    SELECT id, 'manual', 'rare_yrsa_discard_lowest_mana', 'none', '{"mana_cost": 3}' FROM public.cards WHERE code = 'RARE_025' ON CONFLICT DO NOTHING;

    INSERT INTO public.card_effects (card_id, trigger_type, effect_code, target_mode, parameters)
    SELECT id, 'manual', 'rare_elemental_lock_high_power', 'none', '{"mana_cost": 2, "required_zone": "life"}' FROM public.cards WHERE code = 'RARE_026' ON CONFLICT DO NOTHING;

    INSERT INTO public.card_effects (card_id, trigger_type, effect_code, target_mode, parameters)
    SELECT id, 'manual', 'rare_diana_trade_life_for_elites', 'none', '{"mana_cost": 2}' FROM public.cards WHERE code = 'RARE_027' ON CONFLICT DO NOTHING;

    INSERT INTO public.card_effects (card_id, trigger_type, effect_code, target_mode, parameters)
    SELECT id, 'manual', 'rare_scalet_summon_beast_attacker', 'none', '{"mana_cost": 0}' FROM public.cards WHERE code = 'RARE_028' ON CONFLICT DO NOTHING;

    INSERT INTO public.card_effects (card_id, trigger_type, effect_code, target_mode, parameters)
    SELECT id, 'manual', 'rare_morvran_ursulla_direct_snipes', 'none', '{"mana_cost": 0}' FROM public.cards WHERE code = 'RARE_029' ON CONFLICT DO NOTHING;

    INSERT INTO public.card_effects (card_id, trigger_type, effect_code, target_mode, parameters)
    SELECT id, 'manual', 'rare_house_of_tears_effect_immunity', 'none', '{"mana_cost": 4, "required_zone": "life"}' FROM public.cards WHERE code = 'RARE_030' ON CONFLICT DO NOTHING;

    INSERT INTO public.card_effects (card_id, trigger_type, effect_code, target_mode, parameters)
    SELECT id, 'on_destroyed', 'rare_kikimore_witcher_death_discount', 'none', '{"mana_cost": 3}' FROM public.cards WHERE code = 'RARE_031' ON CONFLICT DO NOTHING;

    INSERT INTO public.card_effects (card_id, trigger_type, effect_code, target_mode, parameters)
    SELECT id, 'manual', 'rare_thrush_bounce_life_swap', 'none', '{"mana_cost": 0, "target_scope": "enemy_life"}' FROM public.cards WHERE code = 'RARE_032' ON CONFLICT DO NOTHING;

    INSERT INTO public.card_effects (card_id, trigger_type, effect_code, target_mode, parameters)
    SELECT id, 'manual', 'rare_ice_troll_midgame_banish', 'none', '{"mana_cost": 3}' FROM public.cards WHERE code = 'RARE_033' ON CONFLICT DO NOTHING;

    INSERT INTO public.card_effects (card_id, trigger_type, effect_code, target_mode, parameters)
    SELECT id, 'manual', 'rare_morgana_skip_entire_round', 'none', '{"mana_cost": 6}' FROM public.cards WHERE code = 'RARE_034' ON CONFLICT DO NOTHING;

    INSERT INTO public.card_effects (card_id, trigger_type, effect_code, target_mode, parameters)
    SELECT id, 'manual', 'rare_ethereal_tutor_pairs', 'none', '{"mana_cost": 4}' FROM public.cards WHERE code = 'RARE_035' ON CONFLICT DO NOTHING;

    INSERT INTO public.card_effects (card_id, trigger_type, effect_code, target_mode, parameters)
    SELECT id, 'manual', 'rare_reed_select_rare_tutor', 'none', '{"mana_cost": 2}' FROM public.cards WHERE code = 'RARE_036' ON CONFLICT DO NOTHING;

    INSERT INTO public.card_effects (card_id, trigger_type, effect_code, target_mode, parameters)
    SELECT id, 'on_attack_resolved', 'rare_zoltan_trample_blind_destroy', 'none', '{"mana_cost": 3}' FROM public.cards WHERE code = 'RARE_037' ON CONFLICT DO NOTHING;

    INSERT INTO public.card_effects (card_id, trigger_type, effect_code, target_mode, parameters)
    SELECT id, 'manual', 'rare_danvis_tax_hand', 'none', '{"mana_cost": 3}' FROM public.cards WHERE code = 'RARE_038' ON CONFLICT DO NOTHING;

    INSERT INTO public.card_effects (card_id, trigger_type, effect_code, target_mode, parameters)
    SELECT id, 'manual', 'rare_lagaz_force_reinforcement_fill', 'none', '{"mana_cost": 3}' FROM public.cards WHERE code = 'RARE_039' ON CONFLICT DO NOTHING;

    INSERT INTO public.card_effects (card_id, trigger_type, effect_code, target_mode, parameters)
    SELECT id, 'manual', 'rare_succubus_graveyard_treason_strike', 'none', '{"mana_cost": 6}' FROM public.cards WHERE code = 'RARE_040' ON CONFLICT DO NOTHING;

END $$;

COMMIT;
