-- Migration 202607280055_insert_and_implement_epic_batch_3.sql
-- Inserção das cartas EPIC_033 a EPIC_059 com target_mode seguro e parâmetros JSONB.

BEGIN;

DO $$
DECLARE
    v_set_id uuid;
BEGIN
    SELECT id INTO v_set_id FROM public.card_sets ORDER BY created_at ASC LIMIT 1;
    IF v_set_id IS NULL THEN
        INSERT INTO public.card_sets (name, code, description) VALUES ('Expansão Épica 3', 'EPIC3', 'Terceiro lote de épicas') RETURNING id INTO v_set_id;
    END IF;

    -- 1. Inserir as cartas do lote épico com ON CONFLICT UPDATE
    INSERT INTO public.cards (set_id, code, name, image_url, element, rarity, card_type, is_golden, is_original_rpg, base_power, base_max_life, effect_mana_cost, tier, effect_text)
    VALUES
    (v_set_id, 'EPIC_033', 'Vespeon da Escola da Manticora', 'https://via.placeholder.com/300x450.png?text=Gwent+Epic', 'Witcher', 'epic', 'normal', false, false, 2800, 3000, 4, 2, 'Ative na sua rodada de ataque: retorna à sua mão e sequestra uma carta aleatória Bestiário do deck do oponente, inserindo-a no seu deck.'),
    (v_set_id, 'EPIC_034', 'Protego', 'https://via.placeholder.com/300x450.png?text=Gwent+Epic', 'Bestiário', 'epic', 'normal', false, false, 0, 4000, 4, 2, 'Só ativável no Campo de Vida. Ao ser destruído, substitua-o automaticamente por uma carta aleatória Bestiário do seu cemitério. Limite estrito de 1 ressurreição por jogo para este slot.'),
    (v_set_id, 'EPIC_035', 'AVALACH', 'https://via.placeholder.com/300x450.png?text=Gwent+Epic', 'Civil', 'epic', 'normal', false, false, 2000, 4000, 2, 2, 'Ao ativar, compra uma carta Lendária aleatória do seu deck.'),
    (v_set_id, 'EPIC_036', 'Salazar Stregobor o Mago', 'https://via.placeholder.com/300x450.png?text=Gwent+Epic', 'M&F', 'epic', 'normal', false, false, 2600, 2600, 4, 2, 'Permuta simultaneamente TODAS as Cartas de Vida em campo por um número idêntico de cartas aleatórias das respectivas mãos de ambos os jogadores.'),
    (v_set_id, 'EPIC_037', 'Stregobor o Mago', 'https://via.placeholder.com/300x450.png?text=Gwent+Epic', 'M&F', 'epic', 'normal', false, false, 3300, 2250, 3, 2, 'Ao ativar, uma carta aleatória no deck do seu oponente tem o custo de mana permanentemente alterado para = 8.'),
    (v_set_id, 'EPIC_038', 'Imlerith', 'https://via.placeholder.com/300x450.png?text=Gwent+Epic', 'Bestiário', 'epic', 'normal', false, false, 2000, 11000, 0, 2, 'Passivo automático. Imlerith perde 1000 de Vida ao final de cada rodada do jogo.'),
    (v_set_id, 'EPIC_039', 'Eskel', 'https://via.placeholder.com/300x450.png?text=Gwent+Epic', 'Witcher', 'epic', 'normal', false, false, 1000, 4000, 4, 2, 'Ao ativar, compra imediatamente 2 cartas do topo do seu deck.'),
    (v_set_id, 'EPIC_040', 'Caranthir', 'https://via.placeholder.com/300x450.png?text=Gwent+Epic', 'M&F', 'epic', 'normal', false, false, 3000, 3000, 4, 2, 'Ao ativar, expurga da mesa e envia para o cemitério TODAS as cartas de reforço posicionadas em ambos os campos.'),
    (v_set_id, 'EPIC_041', 'Morvim da Escola do Lince', 'https://via.placeholder.com/300x450.png?text=Gwent+Epic', 'Witcher', 'epic', 'normal', false, false, 2500, 1800, 0, 2, 'Ao ativar em combate, qualquer carta inimiga destruída por Morvim é imediatamente exilada em vez de ir para o cemitério.'),
    (v_set_id, 'EPIC_042', 'Lucius da Escola do Gato', 'https://via.placeholder.com/300x450.png?text=Gwent+Epic', 'Witcher', 'epic', 'normal', false, false, 2000, 1200, 1, 2, 'Ao ativar, aumenta permanentemente seu Poder em +1000 para cada rodada que já se passou na partida.'),
    (v_set_id, 'EPIC_043', 'Lugubre o rei dos penitentes', 'https://via.placeholder.com/300x450.png?text=Gwent+Epic', 'Bestiário', 'epic', 'normal', false, false, 2700, 4000, 5, 2, 'Ativável no Campo de Vida. O oponente, na compra obrigatória, sacará do próprio cemitério (se houver cartas) em vez do deck.'),
    (v_set_id, 'EPIC_044', 'Noldorath o Elfo Navegador', 'https://via.placeholder.com/300x450.png?text=Gwent+Epic', 'Civil', 'epic', 'normal', false, false, 2500, 2500, 5, 2, 'Abre modal interativo do deck. Você escolhe exatamente a carta que quiser e ela é movida para a sua mão.'),
    (v_set_id, 'EPIC_045', 'Teshar de Zangreb da Escola do Urso', 'https://via.placeholder.com/300x450.png?text=Gwent+Epic', 'Witcher', 'epic', 'normal', false, false, 2700, 3500, 0, 2, 'Passivo. Recebe apenas 50% de todo dano originado por cartas do elemento Bestiário.'),
    (v_set_id, 'EPIC_046', 'Idaran de Ulivo o Mago', 'https://via.placeholder.com/300x450.png?text=Gwent+Epic', 'M&F', 'epic', 'normal', false, false, 1200, 1000, 5, 2, 'Transmuta (substitui) 1 carta do campo do oponente por 1 carta de mesma raridade dentro do deck dele.'),
    (v_set_id, 'EPIC_047', 'Essi Daven a Olhuda', 'https://via.placeholder.com/300x450.png?text=Gwent+Epic', 'Civil', 'epic', 'normal', false, false, 1000, 1500, 5, 2, 'Ativável no Campo de Vida. Você ganha visão permanente: todas as cartas que o oponente comprar do deck dele são reveladas.'),
    (v_set_id, 'EPIC_048', 'Beann''shie', 'https://via.placeholder.com/300x450.png?text=Gwent+Epic', 'Bestiário', 'epic', 'normal', false, false, 3000, 3000, 3, 2, 'Descarta sua mão atual e compra do seu próprio cemitério exatamente a mesma quantidade de cartas aleatórias.'),
    (v_set_id, 'EPIC_049', 'Alquimista a Moira', 'https://via.placeholder.com/300x450.png?text=Gwent+Epic', 'Bestiário', 'epic', 'normal', false, false, 2000, 4000, 2, 2, 'Ativável no Campo de Vida. TODAS as Cartas de Vida vivas no campo do oponente sofrem uma redução imediata de 30% na Vida atual.'),
    (v_set_id, 'EPIC_050', 'Sibilante a Moira', 'https://via.placeholder.com/300x450.png?text=Gwent+Epic', 'Bestiário', 'epic', 'normal', false, false, 3000, 3000, 4, 2, 'Em combate, ataca diretamente uma Carta de Vida aleatória do oponente, ignorando qualquer reforço.'),
    (v_set_id, 'EPIC_051', 'Tecelã a Moira', 'https://via.placeholder.com/300x450.png?text=Gwent+Epic', 'Bestiário', 'epic', 'normal', false, false, 2700, 3000, 2, 2, 'Ativável direto da mão. Resgata a carta Sibilante a Moira do cemitério direto para a sua mão.'),
    (v_set_id, 'EPIC_052', 'Syanna Henrieta', 'https://via.placeholder.com/300x450.png?text=Gwent+Epic', 'Civil', 'epic', 'normal', false, false, 2800, 2000, 2, 2, 'Passivo na mão. Syanna inspeciona o catálogo, copia e adquire o efeito de qualquer carta aleatória, preservando seu custo de 2 de Mana.'),
    (v_set_id, 'EPIC_053', 'Anna Henrieta', 'https://via.placeholder.com/300x450.png?text=Gwent+Epic', 'Civil', 'epic', 'normal', false, false, 2400, 4000, 6, 2, 'Ativável no Campo de Vida. Pedágio contínuo: no início de cada rodada inimiga, ele escolhe 1 carta da mão e entrega para você.'),
    (v_set_id, 'EPIC_054', 'Iris Von Everec', 'https://via.placeholder.com/300x450.png?text=Gwent+Epic', 'Civil', 'epic', 'normal', false, false, 2000, 2000, 2, 2, 'Se retornou do cemitério, destrói instantaneamente uma Carta de Vida inimiga danificada (Vida < Vida Máxima).'),
    (v_set_id, 'EPIC_055', 'Emhyr van Emreis', 'https://via.placeholder.com/300x450.png?text=Gwent+Epic', 'Civil', 'epic', 'normal', false, false, 3000, 3000, 4, 2, 'Descarta ambas as mãos. Você compra a mesma quantidade descartada; o oponente compra a metade.'),
    (v_set_id, 'EPIC_056', 'Rei Radovic', 'https://via.placeholder.com/300x450.png?text=Gwent+Epic', 'Civil', 'epic', 'normal', false, false, 2000, 2000, 4, 2, 'Se o oponente possuir carta duplicada na mão, destrói 1 Carta de Vida do oponente à sua escolha.'),
    (v_set_id, 'EPIC_057', 'Philippa Eilhart', 'https://via.placeholder.com/300x450.png?text=Gwent+Epic', 'M&F', 'epic', 'normal', false, false, 2800, 3000, 0, 2, 'Dobra permanentemente o custo de mana de TODAS as cartas M&F na mão do oponente.'),
    (v_set_id, 'EPIC_058', 'Crach an Craite', 'https://via.placeholder.com/300x450.png?text=Gwent+Epic', 'Civil', 'epic', 'normal', false, false, 4000, 4000, 4, 2, 'Seleciona e destrói 3 cartas aleatórias diretamente do deck do oponente, enviando-as ao cemitério.'),
    (v_set_id, 'EPIC_059', 'Feitiçeira Fringilla', 'https://via.placeholder.com/300x450.png?text=Gwent+Epic', 'M&F', 'epic', 'normal', false, false, 2500, 2500, 3, 2, 'Inverte a ordem do baralho do oponente e revela publicamente a nova carta do topo.')
    ON CONFLICT (code) DO UPDATE SET
        name = EXCLUDED.name,
        base_power = EXCLUDED.base_power,
        base_max_life = EXCLUDED.base_max_life,
        effect_mana_cost = EXCLUDED.effect_mana_cost,
        effect_text = EXCLUDED.effect_text,
        tier = EXCLUDED.tier;

    -- 2. Inserir os Efeitos blindados com target_mode padronizado e parâmetros JSONB

    INSERT INTO public.card_effects (card_id, trigger_type, effect_code, target_mode, parameters)
    SELECT id, 'manual', 'epic_vespeon_steal_beast_to_deck', 'none', '{"mana_cost": 4, "required_zone": "attacker"}' FROM public.cards WHERE code = 'EPIC_033' ON CONFLICT DO NOTHING;

    INSERT INTO public.card_effects (card_id, trigger_type, effect_code, target_mode, parameters)
    SELECT id, 'on_destroyed', 'epic_protego_life_replacement_once', 'none', '{"mana_cost": 4, "required_zone": "life", "max_triggers": 1}' FROM public.cards WHERE code = 'EPIC_034' ON CONFLICT DO NOTHING;

    INSERT INTO public.card_effects (card_id, trigger_type, effect_code, target_mode, parameters)
    SELECT id, 'manual', 'epic_avallach_random_legendary_tutor', 'none', '{"mana_cost": 2}' FROM public.cards WHERE code = 'EPIC_035' ON CONFLICT DO NOTHING;

    INSERT INTO public.card_effects (card_id, trigger_type, effect_code, target_mode, parameters)
    SELECT id, 'manual', 'epic_salazar_mass_life_hand_swap', 'none', '{"mana_cost": 4}' FROM public.cards WHERE code = 'EPIC_036' ON CONFLICT DO NOTHING;

    INSERT INTO public.card_effects (card_id, trigger_type, effect_code, target_mode, parameters)
    SELECT id, 'manual', 'epic_stregobor_tax_enemy_deck', 'none', '{"mana_cost": 3}' FROM public.cards WHERE code = 'EPIC_037' ON CONFLICT DO NOTHING;

    INSERT INTO public.card_effects (card_id, trigger_type, effect_code, target_mode, parameters)
    SELECT id, 'on_round_end', 'epic_imlerith_round_bleed', 'none', '{"mana_cost": 0}' FROM public.cards WHERE code = 'EPIC_038' ON CONFLICT DO NOTHING;

    INSERT INTO public.card_effects (card_id, trigger_type, effect_code, target_mode, parameters)
    SELECT id, 'manual', 'epic_eskel_double_draw', 'none', '{"mana_cost": 4}' FROM public.cards WHERE code = 'EPIC_039' ON CONFLICT DO NOTHING;

    INSERT INTO public.card_effects (card_id, trigger_type, effect_code, target_mode, parameters)
    SELECT id, 'manual', 'epic_caranthir_purge_all_reinforcements', 'none', '{"mana_cost": 4}' FROM public.cards WHERE code = 'EPIC_040' ON CONFLICT DO NOTHING;

    INSERT INTO public.card_effects (card_id, trigger_type, effect_code, target_mode, parameters)
    SELECT id, 'on_attack_resolved', 'epic_morvran_lynx_banish_slain', 'none', '{"mana_cost": 0}' FROM public.cards WHERE code = 'EPIC_041' ON CONFLICT DO NOTHING;

    INSERT INTO public.card_effects (card_id, trigger_type, effect_code, target_mode, parameters)
    SELECT id, 'manual', 'epic_lucius_scale_by_turns', 'none', '{"mana_cost": 1}' FROM public.cards WHERE code = 'EPIC_042' ON CONFLICT DO NOTHING;

    INSERT INTO public.card_effects (card_id, trigger_type, effect_code, target_mode, parameters)
    SELECT id, 'on_round_start', 'epic_mourntart_graveyard_draw_curse', 'none', '{"mana_cost": 5, "required_zone": "life"}' FROM public.cards WHERE code = 'EPIC_043' ON CONFLICT DO NOTHING;

    INSERT INTO public.card_effects (card_id, trigger_type, effect_code, target_mode, parameters)
    SELECT id, 'manual', 'epic_noldorath_absolute_tutor', 'none', '{"mana_cost": 5}' FROM public.cards WHERE code = 'EPIC_044' ON CONFLICT DO NOTHING;

    INSERT INTO public.card_effects (card_id, trigger_type, effect_code, target_mode, parameters)
    SELECT id, 'passive', 'epic_teshar_beast_damage_resistance', 'none', '{"mana_cost": 0}' FROM public.cards WHERE code = 'EPIC_045' ON CONFLICT DO NOTHING;

    INSERT INTO public.card_effects (card_id, trigger_type, effect_code, target_mode, parameters)
    SELECT id, 'manual', 'epic_idaran_transmute_enemy_field', 'target_card', '{"mana_cost": 5, "target_scope": "enemy_field"}' FROM public.cards WHERE code = 'EPIC_046' ON CONFLICT DO NOTHING;

    INSERT INTO public.card_effects (card_id, trigger_type, effect_code, target_mode, parameters)
    SELECT id, 'passive', 'epic_essi_permanent_draw_peek', 'none', '{"mana_cost": 5, "required_zone": "life"}' FROM public.cards WHERE code = 'EPIC_047' ON CONFLICT DO NOTHING;

    INSERT INTO public.card_effects (card_id, trigger_type, effect_code, target_mode, parameters)
    SELECT id, 'manual', 'epic_banshee_hand_graveyard_recycle', 'none', '{"mana_cost": 3}' FROM public.cards WHERE code = 'EPIC_048' ON CONFLICT DO NOTHING;

    INSERT INTO public.card_effects (card_id, trigger_type, effect_code, target_mode, parameters)
    SELECT id, 'manual', 'epic_alchemist_moira_life_decay', 'none', '{"mana_cost": 2, "required_zone": "life"}' FROM public.cards WHERE code = 'EPIC_049' ON CONFLICT DO NOTHING;

    INSERT INTO public.card_effects (card_id, trigger_type, effect_code, target_mode, parameters)
    SELECT id, 'manual', 'epic_whispering_moira_direct_snipe', 'none', '{"mana_cost": 4, "required_zone": "attacker"}' FROM public.cards WHERE code = 'EPIC_050' ON CONFLICT DO NOTHING;

    INSERT INTO public.card_effects (card_id, trigger_type, effect_code, target_mode, parameters)
    SELECT id, 'manual', 'epic_weavess_revive_whispering', 'none', '{"mana_cost": 2, "required_zone": "hand"}' FROM public.cards WHERE code = 'EPIC_051' ON CONFLICT DO NOTHING;

    INSERT INTO public.card_effects (card_id, trigger_type, effect_code, target_mode, parameters)
    SELECT id, 'on_draw', 'epic_syanna_mimic_random_global_effect', 'none', '{"mana_cost": 2, "max_triggers": 1}' FROM public.cards WHERE code = 'EPIC_052' ON CONFLICT DO NOTHING;

    INSERT INTO public.card_effects (card_id, trigger_type, effect_code, target_mode, parameters)
    SELECT id, 'manual', 'epic_anna_henrietta_hand_toll', 'none', '{"mana_cost": 6, "required_zone": "life"}' FROM public.cards WHERE code = 'EPIC_053' ON CONFLICT DO NOTHING;

    INSERT INTO public.card_effects (card_id, trigger_type, effect_code, target_mode, parameters)
    SELECT id, 'manual', 'epic_iris_execute_damaged_life', 'target_card', '{"mana_cost": 2, "target_scope": "enemy_life_damaged"}' FROM public.cards WHERE code = 'EPIC_054' ON CONFLICT DO NOTHING;

    INSERT INTO public.card_effects (card_id, trigger_type, effect_code, target_mode, parameters)
    SELECT id, 'manual', 'epic_emhyr_asymmetric_hand_wipe', 'none', '{"mana_cost": 4}' FROM public.cards WHERE code = 'EPIC_055' ON CONFLICT DO NOTHING;

    INSERT INTO public.card_effects (card_id, trigger_type, effect_code, target_mode, parameters)
    SELECT id, 'manual', 'epic_radovid_punish_hand_duplicates', 'target_card', '{"mana_cost": 4, "target_scope": "enemy_life"}' FROM public.cards WHERE code = 'EPIC_056' ON CONFLICT DO NOTHING;

    INSERT INTO public.card_effects (card_id, trigger_type, effect_code, target_mode, parameters)
    SELECT id, 'manual', 'epic_philippa_double_mf_mana', 'none', '{"mana_cost": 0}' FROM public.cards WHERE code = 'EPIC_057' ON CONFLICT DO NOTHING;

    INSERT INTO public.card_effects (card_id, trigger_type, effect_code, target_mode, parameters)
    SELECT id, 'manual', 'epic_crach_mill_triple_deck', 'none', '{"mana_cost": 4}' FROM public.cards WHERE code = 'EPIC_058' ON CONFLICT DO NOTHING;

    INSERT INTO public.card_effects (card_id, trigger_type, effect_code, target_mode, parameters)
    SELECT id, 'manual', 'epic_fringilla_deck_invert_reveal', 'none', '{"mana_cost": 3}' FROM public.cards WHERE code = 'EPIC_059' ON CONFLICT DO NOTHING;

END $$;

COMMIT;
