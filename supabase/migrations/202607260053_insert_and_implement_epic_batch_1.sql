-- Migration 202607260053_insert_and_implement_epic_batch_1.sql
-- Inserção das cartas EPIC_001 a EPIC_019 com target_mode seguro e parâmetros JSONB.

BEGIN;

DO $$
DECLARE
    v_set_id uuid;
BEGIN
    SELECT id INTO v_set_id FROM public.card_sets ORDER BY created_at ASC LIMIT 1;
    IF v_set_id IS NULL THEN
        INSERT INTO public.card_sets (name, code, description) VALUES ('Expansão Épica 1', 'EPIC1', 'Primeiro lote de épicas') RETURNING id INTO v_set_id;
    END IF;

    -- 1. Inserir as cartas do lote épico com ON CONFLICT UPDATE
    INSERT INTO public.cards (set_id, code, name, image_url, element, rarity, card_type, is_golden, is_original_rpg, base_power, base_max_life, effect_mana_cost, tier, effect_text)
    VALUES
    (v_set_id, 'EPIC_001', 'Djinn', 'https://via.placeholder.com/300x450.png?text=Gwent+Epic', 'Bestiário', 'epic', 'normal', false, false, 5000, 2000, 1, 2, 'Ao ativar no Campo de Vida, o oponente fica impedido de usar qualquer carta do tipo M&F na linha de ataque até o Djinn ser destruído. Efeito passivo: se o Djinn for usado para atacar, o jogador perde permanentemente 1 de Mana Máxima até o fim do jogo.'),
    (v_set_id, 'EPIC_002', 'Ursulla Demetria Crest', 'https://via.placeholder.com/300x450.png?text=Gwent+Epic', 'Civil', 'epic', 'normal', false, false, 100, 100, 0, 2, 'Passivo automático. Logo ao ser comprada/sacada, a Vida desta carta se torna = 100 * [número de cartas M&F no deck do jogador], e seu Poder se torna = 250 * [número de cartas Bestiário no deck do jogador].'),
    (v_set_id, 'EPIC_003', 'Ekimmu', 'https://via.placeholder.com/300x450.png?text=Gwent+Epic', 'Bestiário', 'epic', 'normal', false, false, 3000, 4000, 3, 2, 'Ao ativar, esta carta "rouba" 1000 de Vida e 1000 de Poder de TODAS as cartas presentes na mão do jogador oponente.'),
    (v_set_id, 'EPIC_004', 'Liche Ancião', 'https://via.placeholder.com/300x450.png?text=Gwent+Epic', 'Bestiário', 'epic', 'normal', false, false, 4000, 3500, 0, 2, 'Só pode ser ativada no Campo de Vida. Após ativar, em todo início de rodada do oponente, ele será forçado a descartar uma carta à escolha dele da mão até o Liche ser destruído.'),
    (v_set_id, 'EPIC_005', 'Feiticeira Eliah', 'https://via.placeholder.com/300x450.png?text=Gwent+Epic', 'M&F', 'epic', 'normal', false, false, 500, 4000, 4, 2, 'Ative de qualquer local do campo ou da sua mão: esta carta torna-se imune a destruição por efeitos ou feitiços ativados pelo oponente até o fim da partida.'),
    (v_set_id, 'EPIC_006', 'Feiticeira Annie', 'https://via.placeholder.com/300x450.png?text=Gwent+Epic', 'M&F', 'epic', 'normal', false, false, 2600, 2300, 4, 2, 'Ao ativar, seleciona e ativa aleatoriamente o efeito de uma carta que o seu oponente já tenha ativado durante a partida atual.'),
    (v_set_id, 'EPIC_007', 'Saskia', 'https://via.placeholder.com/300x450.png?text=Gwent+Epic', 'Bestiário', 'epic', 'normal', false, false, 2000, 2000, 5, 2, 'Ative direto da sua mão apenas. Saskia retorna para dentro do seu deck e ativa o feitiço: reduz em -2 o custo de mana de TODAS as cartas do seu deck até ela retornar para sua mão novamente.'),
    (v_set_id, 'EPIC_008', 'Principe Alex', 'https://via.placeholder.com/300x450.png?text=Gwent+Epic', 'Civil', 'epic', 'normal', false, false, 2900, 2700, 5, 2, 'Só pode ser ativado como Carta de Vida. No início de cada rodada sua, o sistema verifica se há um espaço vago de reforço e adiciona automaticamente 1 carta aleatória revelada como reforço no seu campo.'),
    (v_set_id, 'EPIC_009', 'Nevuloso', 'https://via.placeholder.com/300x450.png?text=Gwent+Epic', 'Bestiário', 'epic', 'normal', false, false, 3000, 1000, 6, 2, 'Ao ativar, abra o modal de seleção para escolher e duplificar exata e integralmente uma carta da sua própria mão.'),
    (v_set_id, 'EPIC_010', 'Magnus de Kaedwen', 'https://via.placeholder.com/300x450.png?text=Gwent+Epic', 'Civil', 'epic', 'normal', false, false, 1500, 2000, 0, 2, 'Passivo. Esta carta ataca diretamente uma Carta de Vida aleatória do oponente e retorna intacta para a mão do jogador enquanto ele controlar a carta "Sigrith Gowdie - A Bruxa" em seu Campo de Vida.'),
    (v_set_id, 'EPIC_011', 'Letho', 'https://via.placeholder.com/300x450.png?text=Gwent+Epic', 'Witcher', 'epic', 'normal', false, false, 5000, 8000, 0, 2, 'Passivo automático. Esta carta não pode ser invocada para o campo enquanto houver qualquer carta do tipo Witcher revelada no campo de reforço ou no campo de vida de NENHUM dos jogadores.'),
    (v_set_id, 'EPIC_012', 'Katakan', 'https://via.placeholder.com/300x450.png?text=Gwent+Epic', 'Bestiário', 'epic', 'normal', false, false, 2800, 2100, 4, 2, 'Ao ativar, esta carta remove e anula o feitiço de todas as cartas de reforço viradas para baixo (ocultas) do oponente, impossibilitando-as de reagirem ou ativarem efeitos defensivos ao serem atacadas.'),
    (v_set_id, 'EPIC_013', 'Baldur de Lyria', 'https://via.placeholder.com/300x450.png?text=Gwent+Epic', 'Civil', 'epic', 'normal', false, false, 4000, 4000, 0, 2, 'Passivo automático. Enquanto houver uma carta do tipo M&F no seu Campo de Vida, Baldur sempre retorna da mesa para dentro do seu deck ao final de cada rodada.'),
    (v_set_id, 'EPIC_014', 'Lisandro Vanderbaster', 'https://via.placeholder.com/300x450.png?text=Gwent+Epic', 'Civil', 'epic', 'normal', false, false, 3000, 3000, 6, 2, 'Ative este efeito e ataque diretamente as 3 Cartas de Vida do oponente de uma só vez.'),
    (v_set_id, 'EPIC_015', 'Penitente', 'https://via.placeholder.com/300x450.png?text=Gwent+Epic', 'Bestiário', 'epic', 'normal', false, false, 2500, 2500, 0, 2, 'Passivo automático. Esta carta só pode ser destruída do campo como reforço ou vida se o oponente tiver pelo menos 6 cartas no próprio cemitério. Caso contrário, o dano letal é anulado, a carta permanece em campo e cura-se 100% ao fim da rodada.'),
    (v_set_id, 'EPIC_016', 'Lambert', 'https://via.placeholder.com/300x450.png?text=Gwent+Epic', 'Witcher', 'epic', 'normal', false, false, 3100, 2600, 2, 2, 'Ative este efeito e destrua uma carta aleatória diretamente do deck do oponente.'),
    (v_set_id, 'EPIC_017', 'Scyla da Escola da Coruja', 'https://via.placeholder.com/300x450.png?text=Gwent+Epic', 'Witcher', 'epic', 'normal', false, false, 2950, 3000, 4, 2, 'Ative este efeito e compre (saque para a mão) uma carta do tipo Witcher aleatória do seu deck, alterando o custo de mana dela para = 0.'),
    (v_set_id, 'EPIC_018', 'Gigante de Gelo', 'https://via.placeholder.com/300x450.png?text=Gwent+Epic', 'Bestiário', 'epic', 'normal', false, false, 2800, 4000, 0, 2, 'Passivo automático. Esta carta triplica sua própria Vida quando a partida ultrapassar o Turno 5.'),
    (v_set_id, 'EPIC_019', 'Darko o Elfo', 'https://via.placeholder.com/300x450.png?text=Gwent+Epic', 'M&F', 'epic', 'normal', false, false, 2900, 5000, 4, 2, 'Ao ativar, agenda um feitiço transacional: ao final da rodada atual, todas as cartas presentes na sua mão serão permutadas pelas cartas da mão do oponente.')
    ON CONFLICT (code) DO UPDATE SET
        name = EXCLUDED.name,
        base_power = EXCLUDED.base_power,
        base_max_life = EXCLUDED.base_max_life,
        effect_mana_cost = EXCLUDED.effect_mana_cost,
        effect_text = EXCLUDED.effect_text,
        tier = EXCLUDED.tier;

    -- 2. Inserir os Efeitos blindados com target_mode padronizado e parâmetros JSONB

    INSERT INTO public.card_effects (card_id, trigger_type, effect_code, target_mode, parameters)
    SELECT id, 'manual', 'epic_djinn_lock_mf_attack', 'none', '{"mana_cost": 1, "required_zone": "life"}' FROM public.cards WHERE code = 'EPIC_001' ON CONFLICT DO NOTHING;

    INSERT INTO public.card_effects (card_id, trigger_type, effect_code, target_mode, parameters)
    SELECT id, 'on_draw', 'epic_ursulla_dynamic_scaling', 'none', '{"mana_cost": 0}' FROM public.cards WHERE code = 'EPIC_002' ON CONFLICT DO NOTHING;

    INSERT INTO public.card_effects (card_id, trigger_type, effect_code, target_mode, parameters)
    SELECT id, 'manual', 'epic_ekimmu_siphon_hand', 'none', '{"mana_cost": 3}' FROM public.cards WHERE code = 'EPIC_003' ON CONFLICT DO NOTHING;

    INSERT INTO public.card_effects (card_id, trigger_type, effect_code, target_mode, parameters)
    SELECT id, 'manual', 'epic_ancient_lich_hand_bleed', 'none', '{"mana_cost": 0, "required_zone": "life"}' FROM public.cards WHERE code = 'EPIC_004' ON CONFLICT DO NOTHING;

    INSERT INTO public.card_effects (card_id, trigger_type, effect_code, target_mode, parameters)
    SELECT id, 'manual', 'epic_eliah_effect_immortality', 'none', '{"mana_cost": 4}' FROM public.cards WHERE code = 'EPIC_005' ON CONFLICT DO NOTHING;

    INSERT INTO public.card_effects (card_id, trigger_type, effect_code, target_mode, parameters)
    SELECT id, 'manual', 'epic_annie_mimic_past_effect', 'none', '{"mana_cost": 4}' FROM public.cards WHERE code = 'EPIC_006' ON CONFLICT DO NOTHING;

    INSERT INTO public.card_effects (card_id, trigger_type, effect_code, target_mode, parameters)
    SELECT id, 'manual', 'epic_saskia_deck_discount_loop', 'none', '{"mana_cost": 5, "required_zone": "hand"}' FROM public.cards WHERE code = 'EPIC_007' ON CONFLICT DO NOTHING;

    INSERT INTO public.card_effects (card_id, trigger_type, effect_code, target_mode, parameters)
    SELECT id, 'on_round_start', 'epic_alex_auto_reinforce', 'none', '{"mana_cost": 5, "required_zone": "life"}' FROM public.cards WHERE code = 'EPIC_008' ON CONFLICT DO NOTHING;

    INSERT INTO public.card_effects (card_id, trigger_type, effect_code, target_mode, parameters)
    SELECT id, 'manual', 'epic_foglet_duplicate_hand', 'target_card', '{"mana_cost": 6, "target_scope": "my_hand"}' FROM public.cards WHERE code = 'EPIC_009' ON CONFLICT DO NOTHING;

    INSERT INTO public.card_effects (card_id, trigger_type, effect_code, target_mode, parameters)
    SELECT id, 'on_attack_declared', 'epic_magnus_sigrith_bounce_snipe', 'none', '{"mana_cost": 0}' FROM public.cards WHERE code = 'EPIC_010' ON CONFLICT DO NOTHING;

    INSERT INTO public.card_effects (card_id, trigger_type, effect_code, target_mode, parameters)
    SELECT id, 'passive', 'epic_letho_summon_restriction', 'none', '{"mana_cost": 0}' FROM public.cards WHERE code = 'EPIC_011' ON CONFLICT DO NOTHING;

    INSERT INTO public.card_effects (card_id, trigger_type, effect_code, target_mode, parameters)
    SELECT id, 'manual', 'epic_katakan_suppress_blind_reinforcements', 'none', '{"mana_cost": 4}' FROM public.cards WHERE code = 'EPIC_012' ON CONFLICT DO NOTHING;

    INSERT INTO public.card_effects (card_id, trigger_type, effect_code, target_mode, parameters)
    SELECT id, 'on_round_end', 'epic_baldur_mf_deck_return', 'none', '{"mana_cost": 0}' FROM public.cards WHERE code = 'EPIC_013' ON CONFLICT DO NOTHING;

    INSERT INTO public.card_effects (card_id, trigger_type, effect_code, target_mode, parameters)
    SELECT id, 'manual', 'epic_lisandro_triple_direct_strike', 'none', '{"mana_cost": 6}' FROM public.cards WHERE code = 'EPIC_014' ON CONFLICT DO NOTHING;

    INSERT INTO public.card_effects (card_id, trigger_type, effect_code, target_mode, parameters)
    SELECT id, 'on_destroyed', 'epic_penitent_graveyard_immortality', 'none', '{"mana_cost": 0}' FROM public.cards WHERE code = 'EPIC_015' ON CONFLICT DO NOTHING;

    INSERT INTO public.card_effects (card_id, trigger_type, effect_code, target_mode, parameters)
    SELECT id, 'manual', 'epic_lambert_mill_random_deck', 'none', '{"mana_cost": 2}' FROM public.cards WHERE code = 'EPIC_016' ON CONFLICT DO NOTHING;

    INSERT INTO public.card_effects (card_id, trigger_type, effect_code, target_mode, parameters)
    SELECT id, 'manual', 'epic_scyla_free_witcher_tutor', 'none', '{"mana_cost": 4}' FROM public.cards WHERE code = 'EPIC_017' ON CONFLICT DO NOTHING;

    INSERT INTO public.card_effects (card_id, trigger_type, effect_code, target_mode, parameters)
    SELECT id, 'on_turn_start', 'epic_ice_giant_turn5_scaling', 'none', '{"mana_cost": 0}' FROM public.cards WHERE code = 'EPIC_018' ON CONFLICT DO NOTHING;

    INSERT INTO public.card_effects (card_id, trigger_type, effect_code, target_mode, parameters)
    SELECT id, 'manual', 'epic_darko_hand_swap_endround', 'none', '{"mana_cost": 4}' FROM public.cards WHERE code = 'EPIC_019' ON CONFLICT DO NOTHING;

END $$;

COMMIT;
