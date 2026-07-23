-- Migration 202607270054_insert_and_implement_epic_batch_2.sql
-- Inserção das cartas EPIC_020 a EPIC_032 com sinergias retroativas e blindagem jsonb.

BEGIN;

DO $$
DECLARE
    v_set_id uuid;
BEGIN
    SELECT id INTO v_set_id FROM public.card_sets ORDER BY created_at ASC LIMIT 1;
    IF v_set_id IS NULL THEN
        INSERT INTO public.card_sets (name, code, description) VALUES ('Expansão Épica 2', 'EPIC2', 'Segundo lote de épicas') RETURNING id INTO v_set_id;
    END IF;

    -- 1. Inserir as cartas do lote épico com ON CONFLICT UPDATE
    INSERT INTO public.cards (set_id, code, name, image_url, element, rarity, card_type, is_golden, is_original_rpg, base_power, base_max_life, effect_mana_cost, tier, effect_text)
    VALUES
    (v_set_id, 'EPIC_020', 'Chorabash', 'https://via.placeholder.com/300x450.png?text=Gwent+Epic', 'Bestiário', 'epic', 'normal', false, false, 4000, 3500, 4, 2, 'Ao ativar em um turno de ataque, se a carta alvo inimiga for do elemento Bestiário, seu feitiço/passiva é suprimido imediatamente e sua Vida é reduzida à metade antes da colisão de combate. Sinergia: Se Vaca (COMMON_001) estiver no cemitério do conjurador, Chorabash ganha +1000 ATK/HP permanentes.'),
    (v_set_id, 'EPIC_021', 'Lobisomen', 'https://via.placeholder.com/300x450.png?text=Gwent+Epic', 'Bestiário', 'epic', 'normal', false, false, 3200, 5000, 4, 2, 'Só pode ser ativada na janela de reação defensiva, estando posicionada como carta de reforço. Se o oponente declarou ataque utilizando mais de 3 cartas, cancela e zera completamente o Poder de uma dessas atacantes aleatoriamente.'),
    (v_set_id, 'EPIC_022', 'Principe Helel', 'https://via.placeholder.com/300x450.png?text=Gwent+Epic', 'Civil', 'epic', 'normal', false, false, 2800, 2400, 3, 2, 'Ao ativar, abre o modal interativo para ver o deck do oponente. O jogador seleciona 1 carta; o servidor exila (bana) aquela carta E TODAS as cópias idênticas a ela presentes no baralho e no campo inimigo.'),
    (v_set_id, 'EPIC_023', 'Conjunção de Esferas', 'https://via.placeholder.com/300x450.png?text=Gwent+Epic', 'M&F', 'epic', 'normal', false, false, 1, 1, 6, 2, 'Só pode ser ativada direto da sua mão se você possuir exatamente 3 cópias idênticas desta carta na sua mão. Ao pagar 6 de Mana e ativar o feitiço, você vence a partida imediatamente.'),
    (v_set_id, 'EPIC_024', 'Hym', 'https://via.placeholder.com/300x450.png?text=Gwent+Epic', 'Bestiário', 'epic', 'normal', false, false, 3000, 4000, 4, 2, 'Ao ativar, rouba TODAS as cartas do cemitério do oponente, transferindo-as para o seu próprio cemitério.'),
    (v_set_id, 'EPIC_025', 'Liche', 'https://via.placeholder.com/300x450.png?text=Gwent+Epic', 'Bestiário', 'epic', 'normal', false, false, 2900, 4000, 2, 2, 'Só pode ser ativado se estiver no Campo de Vida. Ao ativar, o oponente fica totalmente impedido de invocar ou jogar qualquer carta de raridade Rara direto do deck para a mesa até o Liche ser destruído. Sinergia: Totem (COMMON_033).'),
    (v_set_id, 'EPIC_026', 'Nargor o Elfo', 'https://via.placeholder.com/300x450.png?text=Gwent+Epic', 'M&F', 'epic', 'normal', false, false, 2000, 3000, 4, 2, 'Efeito passivo operando do DECK. No início de cada rodada do oponente, 1 carta aleatória da mão inimiga é bloqueada de ser jogada. Apenas 1 carta é bloqueada por rodada, independentemente de cópias.'),
    (v_set_id, 'EPIC_027', 'Feiticeira Helena', 'https://via.placeholder.com/300x450.png?text=Gwent+Epic', 'M&F', 'epic', 'normal', false, false, 3000, 2700, 6, 2, 'Ao ativar, altera permanentemente a regra de limite da mão de ambos os jogadores: de 7 para 4 cartas até o fim do jogo.'),
    (v_set_id, 'EPIC_028', 'Kalemir da Escola do Lobo', 'https://via.placeholder.com/300x450.png?text=Gwent+Epic', 'Witcher', 'epic', 'normal', false, false, 2900, 1500, 3, 2, 'Ao ativar, embaralha sua mão no deck. Em seguida, busca no deck o mesmo número de cartas devolvidas, escolhendo apenas Witcher.'),
    (v_set_id, 'EPIC_029', 'Rosa de Myrkvid a Lâmia', 'https://via.placeholder.com/300x450.png?text=Gwent+Epic', 'Bestiário', 'epic', 'normal', false, false, 2500, 2500, 0, 2, 'Ao ativar durante um ataque, aborta o combate, retorna à mão e recebe +500 Vida/Poder permanente.'),
    (v_set_id, 'EPIC_030', 'Celenia Vorgues a Elfa', 'https://via.placeholder.com/300x450.png?text=Gwent+Epic', 'M&F', 'epic', 'normal', false, false, 1000, 5000, 3, 2, 'Ao ativar, seleciona uma Carta de Vida aliada esgotada e purga sua trava de ativação, permitindo novo uso no mesmo turno.'),
    (v_set_id, 'EPIC_031', 'Lirenne Vorgues a Barda Elfa', 'https://via.placeholder.com/300x450.png?text=Gwent+Epic', 'Civil', 'epic', 'normal', false, false, 1200, 3000, 2, 2, 'Ao ativar, seleciona uma carta da mão e permuta com uma Carta de Vida atualmente em campo.'),
    (v_set_id, 'EPIC_032', 'Fetulho', 'https://via.placeholder.com/300x450.png?text=Gwent+Epic', 'Bestiário', 'epic', 'normal', false, false, 0, 0, 4, 2, 'Compre cartas igual ao número usado no último ataque inimigo. Sinergia: Injeta 1 Filho da Puta Júnior (COMMON_013) na mão do oponente.')
    ON CONFLICT (code) DO UPDATE SET
        name = EXCLUDED.name,
        base_power = EXCLUDED.base_power,
        base_max_life = EXCLUDED.base_max_life,
        effect_mana_cost = EXCLUDED.effect_mana_cost,
        effect_text = EXCLUDED.effect_text,
        tier = EXCLUDED.tier;

    -- 2. Inserir os Efeitos blindados com target_mode padronizado e parâmetros JSONB

    INSERT INTO public.card_effects (card_id, trigger_type, effect_code, target_mode, parameters)
    SELECT id, 'manual', 'epic_chorabash_beast_suppress_halve', 'target_card', '{"mana_cost": 4, "target_scope": "enemy_beast_in_combat", "synergy_target": "COMMON_001"}' FROM public.cards WHERE code = 'EPIC_020' ON CONFLICT DO NOTHING;

    INSERT INTO public.card_effects (card_id, trigger_type, effect_code, target_mode, parameters)
    SELECT id, 'reaction', 'epic_werewolf_defensive_power_nullify', 'none', '{"mana_cost": 4, "required_zone": "reinforcement"}' FROM public.cards WHERE code = 'EPIC_021' ON CONFLICT DO NOTHING;

    INSERT INTO public.card_effects (card_id, trigger_type, effect_code, target_mode, parameters)
    SELECT id, 'manual', 'epic_helel_surgical_eradication', 'target_card', '{"mana_cost": 3, "target_scope": "enemy_deck"}' FROM public.cards WHERE code = 'EPIC_022' ON CONFLICT DO NOTHING;

    INSERT INTO public.card_effects (card_id, trigger_type, effect_code, target_mode, parameters)
    SELECT id, 'manual', 'epic_conjunction_instant_win', 'none', '{"mana_cost": 6, "required_zone": "hand"}' FROM public.cards WHERE code = 'EPIC_023' ON CONFLICT DO NOTHING;

    INSERT INTO public.card_effects (card_id, trigger_type, effect_code, target_mode, parameters)
    SELECT id, 'manual', 'epic_hym_graveyard_hijack', 'none', '{"mana_cost": 4}' FROM public.cards WHERE code = 'EPIC_024' ON CONFLICT DO NOTHING;

    INSERT INTO public.card_effects (card_id, trigger_type, effect_code, target_mode, parameters)
    SELECT id, 'manual', 'epic_lich_lock_rare_summons', 'none', '{"mana_cost": 2, "required_zone": "life", "synergy_target": "COMMON_033"}' FROM public.cards WHERE code = 'EPIC_025' ON CONFLICT DO NOTHING;

    INSERT INTO public.card_effects (card_id, trigger_type, effect_code, target_mode, parameters)
    SELECT id, 'on_round_start', 'epic_nargor_deck_hand_seal', 'none', '{"mana_cost": 0, "required_zone": "deck"}' FROM public.cards WHERE code = 'EPIC_026' ON CONFLICT DO NOTHING;

    INSERT INTO public.card_effects (card_id, trigger_type, effect_code, target_mode, parameters)
    SELECT id, 'manual', 'epic_helena_hand_size_squeeze', 'none', '{"mana_cost": 6}' FROM public.cards WHERE code = 'EPIC_027' ON CONFLICT DO NOTHING;

    INSERT INTO public.card_effects (card_id, trigger_type, effect_code, target_mode, parameters)
    SELECT id, 'manual', 'epic_kalemir_witcher_hand_reload', 'none', '{"mana_cost": 3, "target_scope": "witcher_deck_tutor"}' FROM public.cards WHERE code = 'EPIC_028' ON CONFLICT DO NOTHING;

    INSERT INTO public.card_effects (card_id, trigger_type, effect_code, target_mode, parameters)
    SELECT id, 'manual', 'epic_rosa_attack_bounce_buff', 'none', '{"mana_cost": 0, "required_zone": "attacker"}' FROM public.cards WHERE code = 'EPIC_029' ON CONFLICT DO NOTHING;

    INSERT INTO public.card_effects (card_id, trigger_type, effect_code, target_mode, parameters)
    SELECT id, 'manual', 'epic_celenia_reset_life_cooldown', 'target_card', '{"mana_cost": 3, "target_scope": "my_life_exhausted"}' FROM public.cards WHERE code = 'EPIC_030' ON CONFLICT DO NOTHING;

    INSERT INTO public.card_effects (card_id, trigger_type, effect_code, target_mode, parameters)
    SELECT id, 'manual', 'epic_lirenne_hand_life_swap', 'target_card', '{"mana_cost": 2, "target_scope": "double_hand_life_selection"}' FROM public.cards WHERE code = 'EPIC_031' ON CONFLICT DO NOTHING;

    INSERT INTO public.card_effects (card_id, trigger_type, effect_code, target_mode, parameters)
    SELECT id, 'manual', 'epic_botchling_retaliation_draw_curse', 'none', '{"mana_cost": 4, "synergy_target": "COMMON_013"}' FROM public.cards WHERE code = 'EPIC_032' ON CONFLICT DO NOTHING;

END $$;

COMMIT;
