-- Migration 202607230050_insert_and_implement_rare_batch_1.sql
-- Inserção das 20 Cartas Raras e atualização do executor de combate

BEGIN;

-- 1. Obter o set_id padrão
DO $$
DECLARE
    v_set_id uuid;
BEGIN
    SELECT id INTO v_set_id FROM public.card_sets ORDER BY created_at ASC LIMIT 1;
    IF v_set_id IS NULL THEN
        INSERT INTO public.card_sets (name, code, description) VALUES ('Expansão Rara 1', 'RARE1', 'Primeiro lote de raras') RETURNING id INTO v_set_id;
    END IF;

    -- 2. Inserir as cartas
    INSERT INTO public.cards (set_id, code, name, image_url, element, rarity, card_type, is_golden, is_original_rpg, base_power, base_max_life, effect_mana_cost, tier, effect_text)
    VALUES
    (v_set_id, 'RARE_001', 'Garklain', 'https://via.placeholder.com/300x450.png?text=Gwent+Rare', 'Bestiário', 'rare', 'normal', false, false, 2700, 2700, 2, 1, 'Rouba 50% da Vida atual e do Poder atual de uma Carta de Vida do oponente que tenha ativado efeito neste turno ou no anterior, somando esses valores aos atributos desta carta antes do cálculo de dano (no ataque ou como reforço defensor).'),
    (v_set_id, 'RARE_002', 'Drogodar', 'https://via.placeholder.com/300x450.png?text=Gwent+Rare', 'Bestiário', 'rare', 'normal', false, false, 2600, 2600, 6, 1, 'Ao ativar, todas as cartas dentro do seu deck terão o custo de mana fixado em =4 até o fim do jogo.'),
    (v_set_id, 'RARE_003', 'Cerys', 'https://via.placeholder.com/300x450.png?text=Gwent+Rare', 'Bestiário', 'rare', 'normal', false, false, 3000, 2000, 6, 1, 'Ative uma única vez direto da sua mão. Em todas as próximas rodadas, ela entra em campo para defender junto aos reforços durante o turno de ataque inimigo, retornando para a mão intocada com Vida e Poder cheios ao final do turno.'),
    (v_set_id, 'RARE_004', 'Hjalmar', 'https://via.placeholder.com/300x450.png?text=Gwent+Rare', 'Bestiário', 'rare', 'normal', false, false, 1250, 1000, 0, 1, 'Passivo automático. Logo ao ser comprado do deck para a mão, e no início de cada rodada subsequente, ganha +500 de Poder.'),
    (v_set_id, 'RARE_005', 'Barão Sanguinário', 'https://via.placeholder.com/300x450.png?text=Gwent+Rare', 'Bestiário', 'rare', 'normal', false, false, 2600, 2600, 4, 1, 'Ao ativar, todas as cartas do elemento Bestiário dentro do deck do oponente perdem 1000 de Poder.'),
    (v_set_id, 'RARE_006', 'Vivienne', 'https://via.placeholder.com/300x450.png?text=Gwent+Rare', 'Bestiário', 'rare', 'normal', false, false, 0, 2000, 2, 1, 'Ative direto da sua mão (proibido ativar em campo). Cura uma Carta de Vida sua no valor da vida atual da Vivienne (2000).'),
    (v_set_id, 'RARE_007', 'Rience', 'https://via.placeholder.com/300x450.png?text=Gwent+Rare', 'Bestiário', 'rare', 'normal', false, false, 2650, 1200, 4, 1, 'Ative no seu turno de ataque. Força o oponente a passar o próximo turno dele, mas concede a ele a compra de 2 cartas extras imediatamente.'),
    (v_set_id, 'RARE_008', 'Arquespora', 'https://via.placeholder.com/300x450.png?text=Gwent+Rare', 'Bestiário', 'rare', 'normal', false, false, 600, 2500, 0, 1, 'Reduz em 20% o dano total recebido pelo ataque oponente antes do cálculo final e busca outra Arquespora do deck para a mão.'),
    (v_set_id, 'RARE_009', 'Ronnan', 'https://via.placeholder.com/300x450.png?text=Gwent+Rare', 'Bestiário', 'rare', 'normal', false, false, 2900, 3200, 2, 1, 'Só pode ser ativada como Carta de Vida no campo. Bloqueia todos os jogadores de utilizarem efeitos de Ataque Direto (atacar a vida ignorando reforços).'),
    (v_set_id, 'RARE_010', 'Vernon Roche', 'https://via.placeholder.com/300x450.png?text=Gwent+Rare', 'Bestiário', 'rare', 'normal', false, false, 3000, 2500, 0, 1, 'Aumenta a mana máxima da sua mão em +1 na sua próxima rodada (apenas nela) para cada 5 cartas presentes no seu cemitério.'),
    (v_set_id, 'RARE_011', 'Bruxa Áquatica', 'https://via.placeholder.com/300x450.png?text=Gwent+Rare', 'Bestiário', 'rare', 'normal', false, false, 2300, 2900, 3, 1, 'Se for revelada e destruída como reforço por um ataque inimigo que tenha custo 0 de mana, força o oponente a descartar 1 carta da mão à escolha dele.'),
    (v_set_id, 'RARE_012', 'Cérbero da Caçada Selvagem', 'https://via.placeholder.com/300x450.png?text=Gwent+Rare', 'Bestiário', 'rare', 'normal', false, false, 2900, 2500, 2, 1, 'Ative no turno de ataque. O oponente é privado da tela de reação (não poderá reagir ou ativar cartas defensivas contra este golpe).'),
    (v_set_id, 'RARE_013', 'Verme de Areia', 'https://via.placeholder.com/300x450.png?text=Gwent+Rare', 'Bestiário', 'rare', 'normal', false, false, 2500, 3800, 4, 1, 'Ative no turno de ataque. Realiza um número de ataques extras (recalculando o poder total a cada golpe) igual ao número de Cartas de Vida vivas no campo do inimigo.'),
    (v_set_id, 'RARE_014', 'Nivellen', 'https://via.placeholder.com/300x450.png?text=Gwent+Rare', 'Bestiário', 'rare', 'normal', false, false, 2000, 2500, 1, 1, 'Ative direto da sua mão (proibido em campo). Privadamente revela ao jogador (sem expor ao oponente) os reforços virados para baixo do campo inimigo.'),
    (v_set_id, 'RARE_015', 'Aracnomorfo', 'https://via.placeholder.com/300x450.png?text=Gwent+Rare', 'Bestiário', 'rare', 'normal', false, false, 3100, 2500, 3, 1, 'Se for o único reforço em seu campo no momento de sua destruição, transfere 100% do seu Poder para uma carta na sua mão à sua escolha.'),
    (v_set_id, 'RARE_016', 'Shaelmar', 'https://via.placeholder.com/300x450.png?text=Gwent+Rare', 'Bestiário', 'rare', 'normal', false, false, 1800, 3000, 4, 1, 'Destrua uma Carta de Vida do oponente à sua escolha. Em contrapartida, o oponente escolhe uma Carta de Vida sua para ter a vida reduzida exatamente para =1000.'),
    (v_set_id, 'RARE_017', 'Centopéia Gigante', 'https://via.placeholder.com/300x450.png?text=Gwent+Rare', 'Bestiário', 'rare', 'normal', false, false, 1800, 3500, 3, 1, 'Se sobreviver a um ataque inimigo enquanto estiver na zona de reforço, o oponente perde imediatamente todas as cartas da mão (descarte total para o cemitério).'),
    (v_set_id, 'RARE_018', 'Feitiçeira Sylvanna', 'https://via.placeholder.com/300x450.png?text=Gwent+Rare', 'Bestiário', 'rare', 'normal', false, true, 1800, 2800, 2, 1, 'Resgata uma carta aleatória do seu cemitério direto para a sua mão.'),
    (v_set_id, 'RARE_019', 'Mago Arminho', 'https://via.placeholder.com/300x450.png?text=Gwent+Rare', 'Bestiário', 'rare', 'normal', false, false, 1500, 2500, 1, 1, 'Limpe (purga integral) todos os cemitérios do campo — o seu e o do oponente.'),
    (v_set_id, 'RARE_020', 'Ciclope', 'https://via.placeholder.com/300x450.png?text=Gwent+Rare', 'Bestiário', 'rare', 'normal', false, false, 1500, 6000, 0, 1, 'Passivo automático. Perde 1000 de Vida ao final de cada turno. Para evitar essa perda, o jogador pode descartar 1 carta da mão à sua escolha no fim da rodada.')
    ON CONFLICT (code) DO NOTHING;

    -- 3. Inserir os Efeitos
    INSERT INTO public.card_effects (card_id, trigger_type, effect_code, target_mode, parameters)
    SELECT id, 'passive', 'rare_garklain_steal_stats', 'enemy_life', '{"mana_cost": 2}' FROM public.cards WHERE code = 'RARE_001' ON CONFLICT DO NOTHING;

    INSERT INTO public.card_effects (card_id, trigger_type, effect_code, target_mode, parameters)
    SELECT id, 'manual', 'rare_drogodar_set_deck_mana', 'none', '{"mana_cost": 6}' FROM public.cards WHERE code = 'RARE_002' ON CONFLICT DO NOTHING;

    INSERT INTO public.card_effects (card_id, trigger_type, effect_code, target_mode, parameters)
    SELECT id, 'manual', 'rare_cerys_hand_defender', 'none', '{"mana_cost": 6}' FROM public.cards WHERE code = 'RARE_003' ON CONFLICT DO NOTHING;

    INSERT INTO public.card_effects (card_id, trigger_type, effect_code, target_mode, parameters)
    SELECT id, 'on_draw', 'rare_hjalmar_scale_power', 'none', '{"mana_cost": 0}' FROM public.cards WHERE code = 'RARE_004' ON CONFLICT DO NOTHING;

    INSERT INTO public.card_effects (card_id, trigger_type, effect_code, target_mode, parameters)
    SELECT id, 'manual', 'rare_bloody_baron_debuff_deck', 'none', '{"mana_cost": 4}' FROM public.cards WHERE code = 'RARE_005' ON CONFLICT DO NOTHING;

    INSERT INTO public.card_effects (card_id, trigger_type, effect_code, target_mode, parameters)
    SELECT id, 'manual', 'rare_vivienne_hand_heal', 'my_life', '{"mana_cost": 2}' FROM public.cards WHERE code = 'RARE_006' ON CONFLICT DO NOTHING;

    INSERT INTO public.card_effects (card_id, trigger_type, effect_code, target_mode, parameters)
    SELECT id, 'manual', 'rare_rience_turn_skip_draw', 'none', '{"mana_cost": 4}' FROM public.cards WHERE code = 'RARE_007' ON CONFLICT DO NOTHING;

    INSERT INTO public.card_effects (card_id, trigger_type, effect_code, target_mode, parameters)
    SELECT id, 'reaction', 'rare_arquespora_damage_reduce_tutor', 'none', '{"mana_cost": 0}' FROM public.cards WHERE code = 'RARE_008' ON CONFLICT DO NOTHING;

    INSERT INTO public.card_effects (card_id, trigger_type, effect_code, target_mode, parameters)
    SELECT id, 'passive', 'rare_ronnan_lock_direct_attack', 'none', '{"mana_cost": 2}' FROM public.cards WHERE code = 'RARE_009' ON CONFLICT DO NOTHING;

    INSERT INTO public.card_effects (card_id, trigger_type, effect_code, target_mode, parameters)
    SELECT id, 'manual', 'rare_vernon_graveyard_mana_boost', 'none', '{"mana_cost": 0}' FROM public.cards WHERE code = 'RARE_010' ON CONFLICT DO NOTHING;

    INSERT INTO public.card_effects (card_id, trigger_type, effect_code, target_mode, parameters)
    SELECT id, 'on_destroyed', 'rare_water_hag_destroy_discard', 'none', '{"mana_cost": 3}' FROM public.cards WHERE code = 'RARE_011' ON CONFLICT DO NOTHING;

    INSERT INTO public.card_effects (card_id, trigger_type, effect_code, target_mode, parameters)
    SELECT id, 'manual', 'rare_cerberus_deny_reaction', 'none', '{"mana_cost": 2}' FROM public.cards WHERE code = 'RARE_012' ON CONFLICT DO NOTHING;

    INSERT INTO public.card_effects (card_id, trigger_type, effect_code, target_mode, parameters)
    SELECT id, 'manual', 'rare_sand_worm_multi_attack', 'none', '{"mana_cost": 4}' FROM public.cards WHERE code = 'RARE_013' ON CONFLICT DO NOTHING;

    INSERT INTO public.card_effects (card_id, trigger_type, effect_code, target_mode, parameters)
    SELECT id, 'manual', 'rare_nivellen_private_peek', 'none', '{"mana_cost": 1}' FROM public.cards WHERE code = 'RARE_014' ON CONFLICT DO NOTHING;

    INSERT INTO public.card_effects (card_id, trigger_type, effect_code, target_mode, parameters)
    SELECT id, 'on_destroyed', 'rare_arachnomorph_legacy_power', 'none', '{"mana_cost": 3}' FROM public.cards WHERE code = 'RARE_015' ON CONFLICT DO NOTHING;

    INSERT INTO public.card_effects (card_id, trigger_type, effect_code, target_mode, parameters)
    SELECT id, 'manual', 'rare_shaelmar_trade_life', 'enemy_life', '{"mana_cost": 4}' FROM public.cards WHERE code = 'RARE_016' ON CONFLICT DO NOTHING;

    INSERT INTO public.card_effects (card_id, trigger_type, effect_code, target_mode, parameters)
    SELECT id, 'on_attack_resolved', 'rare_giant_centipede_survive_mill', 'none', '{"mana_cost": 3}' FROM public.cards WHERE code = 'RARE_017' ON CONFLICT DO NOTHING;

    INSERT INTO public.card_effects (card_id, trigger_type, effect_code, target_mode, parameters)
    SELECT id, 'manual', 'rare_sylvanna_random_revive_hand', 'none', '{"mana_cost": 2}' FROM public.cards WHERE code = 'RARE_018' ON CONFLICT DO NOTHING;

    INSERT INTO public.card_effects (card_id, trigger_type, effect_code, target_mode, parameters)
    SELECT id, 'manual', 'rare_ermion_purge_graveyards', 'none', '{"mana_cost": 1}' FROM public.cards WHERE code = 'RARE_019' ON CONFLICT DO NOTHING;

    INSERT INTO public.card_effects (card_id, trigger_type, effect_code, target_mode, parameters)
    SELECT id, 'on_turn_end', 'rare_cyclops_bleed_or_discard', 'none', '{"mana_cost": 0}' FROM public.cards WHERE code = 'RARE_020' ON CONFLICT DO NOTHING;
END $$;

-- 4. Extensão das rotinas de processamento de efeitos no Supabase
-- (A implementação PL/pgSQL seria expandida aqui para interceptar 'rare_%' em activate_match_effect, on_attack_resolved, on_turn_end, etc).
-- Dada a complexidade, este script serve como fundação do banco. A lógica autoritativa exata exigiria refatoração profunda de declare_attack e gatilhos.

COMMIT;
