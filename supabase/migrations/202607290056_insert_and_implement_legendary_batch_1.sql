-- Migration 202607290056_insert_and_implement_legendary_batch_1.sql
-- Inserção das cartas LEGENDARY_001 a LEGENDARY_020 com target_mode seguro, parâmetros JSONB e sinergias retroativas de Tier 3.

BEGIN;

DO $$
DECLARE
    v_set_id uuid;
BEGIN
    SELECT id INTO v_set_id FROM public.card_sets ORDER BY created_at ASC LIMIT 1;
    IF v_set_id IS NULL THEN
        INSERT INTO public.card_sets (name, code, description) VALUES ('Expansão Lendária 1', 'LEG1', 'Primeiro lote de lendárias') RETURNING id INTO v_set_id;
    END IF;

    -- 1. Inserir as cartas do lote lendário com ON CONFLICT UPDATE
    INSERT INTO public.cards (set_id, code, name, image_url, element, rarity, card_type, is_golden, is_original_rpg, base_power, base_max_life, effect_mana_cost, tier, effect_text)
    VALUES
    (v_set_id, 'LEGENDARY_001', 'Deatlaff', 'https://encrypted-tbn0.gstatic.com/images?q=tbn:ANd9GcR5UfYqMmdKx0giAiNQmFR6-bw-EIPbtxpcebvw53YjoQ&s', 'Vampiro', 'legendary', 'normal', false, false, 3000, 2900, 5, 3, 'Ao ativar, realiza ataques diretos simultâneos contra Cartas de Vida do oponente (ignorando reforços) igual à quantidade de suas Cartas de Vida vivas em campo.'),
    (v_set_id, 'LEGENDARY_002', 'Ge''els', 'https://encrypted-tbn0.gstatic.com/images?q=tbn:ANd9GcRGaCUxr6MbuNXCmXqTar_gUnoEHaP2cm9wvwhhgfEVwg&s=10', 'Elfica', 'legendary', 'normal', false, false, 3000, 4000, 0, 3, 'Selecione 1 Carta de Vida aliada para trocar por qualquer carta do seu deck. Em transação simultânea, troque 1 carta da sua mão por outra do deck.'),
    (v_set_id, 'LEGENDARY_003', 'Filavandrel', 'https://encrypted-tbn0.gstatic.com/images?q=tbn:ANd9GcRDPNF-C_Y1SDM3J1x2VJjgdRsWS7xD2SpxH0iT86QDtg&s=10', 'Elfica', 'legendary', 'normal', false, false, 2000, 5000, 3, 3, 'Ativável no Campo de Vida. TODAS as cartas do elemento Elfica do oponente destruídas em combate vão compulsoriamente para o seu deck em vez do cemitério dele.'),
    (v_set_id, 'LEGENDARY_004', 'Auberon Muircetach', 'https://encrypted-tbn0.gstatic.com/images?q=tbn:ANd9GcQDaA5cUkF2kbad5t6Z41tz6GU9hAaecQFCjZfwSMu9YA&s=10', 'Elfica', 'legendary', 'normal', false, false, 4000, 4000, 4, 3, 'Dobra permanentemente o custo de mana de TODAS as cartas do elemento Elfica dentro do deck do oponente.'),
    (v_set_id, 'LEGENDARY_005', 'Eredin', 'https://encrypted-tbn0.gstatic.com/images?q=tbn:ANd9GcSwYkxWVfXzMkuqhXfVG-tcTv8KbNZ0_Ccd45s7jv4uJQ&s=10', 'Elfica', 'legendary', 'normal', false, false, 6000, 4500, 4, 3, 'Sempre que atacar SOZINHO, reduz -1000 de Vida de TODAS as Cartas de Vida vivas do oponente e aumenta em +1 o custo de mana delas.'),
    (v_set_id, 'LEGENDARY_006', 'Verdum o Primeiro Monstro', 'https://i.postimg.cc/sftq87zh/2Q.webp', 'Bestiario', 'legendary', 'normal', false, false, 1, 1, 2, 3, 'Ative uma única vez. A partir de então, no início de TODA rodada, o sistema gera e adiciona compulsoriamente uma carta Lendária aleatória ao seu deck.'),
    (v_set_id, 'LEGENDARY_007', 'Erland de Larvik', 'https://encrypted-tbn0.gstatic.com/images?q=tbn:ANd9GcSCYLL68EppVUlDuFPp1TYqNT6MMAAXP5CmotQT1FYXIA&s=10', 'Witcher', 'legendary', 'normal', false, false, 3000, 3000, 0, 3, 'Ao ativar durante um ataque liderado por Erland, ganha para o início do próximo turno +1 de Mana Máxima para cada carta inimiga destruída no ataque.'),
    (v_set_id, 'LEGENDARY_008', 'Arnaghad', 'https://encrypted-tbn0.gstatic.com/images?q=tbn:ANd9GcSaW1MHcZezqJ2ttZ3awsaQkD5R9N9e3zY1zerFORhxNQ&s=10', 'Witcher', 'legendary', 'normal', false, false, 4000, 4000, 4, 3, 'Ativável no campo de reforço. Transmuta todas as outras cartas de reforço aliadas na sua linha defensiva em cópias exatas e idênticas de Arnaghad.'),
    (v_set_id, 'LEGENDARY_009', 'Gezras de Leyda', 'https://encrypted-tbn0.gstatic.com/images?q=tbn:ANd9GcQCVZEw4perAOh0yv__qGVc6bqHLGqLEdDAxnN7hm-e0w&s=10', 'Witcher', 'legendary', 'normal', false, false, 2500, 2500, 0, 3, 'Abre modal interativo para inspecionar o deck inimigo. Selecione 1 carta à sua escolha e ela é sequestrada diretamente para a sua mão.'),
    (v_set_id, 'LEGENDARY_010', 'Cosimo Malaspina o Mago', 'https://encrypted-tbn0.gstatic.com/images?q=tbn:ANd9GcR_nMKVrpNcV4r9IBipNu5v7BXVSk5G-RrIhOvP2QI82Q&s=10', 'Civil', 'legendary', 'normal', false, false, 1000, 4000, 4, 3, 'Reduz e fixa compulsoriamente a Vida de TODAS as cartas do elemento Witcher presentes no campo do oponente em exatamente = 1.'),
    (v_set_id, 'LEGENDARY_011', 'Alzur de Maribor', 'https://encrypted-tbn0.gstatic.com/images?q=tbn:ANd9GcTsOEggeCMsWKnR-QDFvF3VCOD8qPYHI76ZkKl-NzVJTg&s=10', 'M&F', 'legendary', 'normal', false, false, 4000, 4000, 2, 3, 'Devolve TODOS os reforços e Cartas de Vida de ambos os jogadores às mãos. Abre tela de alocação obrigatória para recolocarem as Cartas de Vida.'),
    (v_set_id, 'LEGENDARY_012', 'Tissaia', 'https://encrypted-tbn0.gstatic.com/images?q=tbn:ANd9GcTbGXaeyCdHPGeVZyVA7cA6QVHMLUbP5yX-yUBaXDfj6A&s=10', 'M&F', 'legendary', 'normal', false, false, 5000, 3000, 6, 3, 'Busca em seu deck todas as cópias da carta Yennefer (LEGENDARY_025), compra-as compulsoriamente e reduz pela metade o custo de mana de cada uma delas.'),
    (v_set_id, 'LEGENDARY_013', 'Carla Demetia Crest', 'https://encrypted-tbn0.gstatic.com/images?q=tbn:ANd9GcTzo8YzoVt5IKJY9bnFPcfKAZEl1N2pI-4XZNFKe4hHHg&s=10', 'M&F', 'legendary', 'normal', false, false, 3800, 2800, 2, 3, 'Seleciona e destrói exatamente 10 cartas do elemento Bestiario presentes no deck do seu oponente.'),
    (v_set_id, 'LEGENDARY_014', 'Tetra Gilcrest', 'https://encrypted-tbn0.gstatic.com/images?q=tbn:ANd9GcSg029rntSg5cI3K_kmIgWxF1i_43l35BqMhHgusKgs7w&s=10', 'M&F', 'legendary', 'normal', false, false, 5000, 3000, 6, 3, 'Destrói compulsoriamente todas as Cartas de Vida vivas na mesa (aliadas ou inimigas) cuja Vida Atual seja inferior à Vida Atual de Tetra no momento da ativação.'),
    (v_set_id, 'LEGENDARY_015', 'Kitsu', 'https://encrypted-tbn0.gstatic.com/images?q=tbn:ANd9GcTuD1Febf9gufEfsxr5nh0LDpODipagR8A_yJrUEoxGqA&s=10', 'Elfica', 'legendary', 'normal', false, false, 2900, 2500, 0, 3, 'Conta as cartas restantes no deck do oponente e transmuta exatamente a metade desse baralho em cartas aleatórias de raridade Rara.'),
    (v_set_id, 'LEGENDARY_016', 'Senhora do Lago', 'https://encrypted-tbn0.gstatic.com/images?q=tbn:ANd9GcSay1VW6_IJfrodMkbVOTldSitFao_5oQafF3IvacyMow&s=10', 'Civil', 'legendary', 'normal', false, false, 2200, 7000, 0, 3, 'Todas as cartas no seu deck tornam-se imunes a serem afetadas, transmutadas, destruídas ou alteradas em custo por qualquer efeito inimigo até o fim da partida.'),
    (v_set_id, 'LEGENDARY_017', 'Dandelion', 'https://encrypted-tbn0.gstatic.com/images?q=tbn:ANd9GcSlPx0I_hxpa92ZyyYCFhs6aDG2aj3q7xpT7YSGZawvhQ&s', 'Civil', 'legendary', 'normal', false, false, 1500, 3000, 5, 3, 'Ganhe visão da mão inimiga. Selecione qualquer número de cartas da sua mão e a mesma quantidade na mão do inimigo para uma permuta forçada e imediata.'),
    (v_set_id, 'LEGENDARY_018', 'Caseiro', 'https://encrypted-tbn0.gstatic.com/images?q=tbn:ANd9GcQFio2p9p-tptZ56RemLQ26RuIIegRtNurmlO5HzUlaRA&s=10', 'Bestiario', 'legendary', 'normal', false, false, 1800, 7000, 5, 3, 'Ativável no Campo de Vida. Ao término de cada turno do jogo, esta carta ataca com o seu Poder atual diretamente uma Carta de Vida aleatória do oponente.'),
    (v_set_id, 'LEGENDARY_019', 'Von Everec', 'https://encrypted-tbn0.gstatic.com/images?q=tbn:ANd9GcTllTHTjb3KC4e2ELbTH503Q1sWDCh0DtJCuq2eYGXaKA&s=10', 'Bestiario', 'legendary', 'normal', false, false, 4000, 3000, 3, 3, 'Se atacar SOZINHO, após concluir o ataque retorna intacto para a sua mão e reduz em -1 o custo de mana de TODAS as outras cartas atualmente presentes na sua mão.'),
    (v_set_id, 'LEGENDARY_020', 'Régis', 'https://encrypted-tbn0.gstatic.com/images?q=tbn:ANd9GcROqTgnSfJjgSTlPniBOFcaTHWyLbPOoOBrv4pLaHwOOg&s=10', 'Vampiro', 'legendary', 'normal', false, false, 4300, 4000, 4, 3, 'Reação (Vida ou Reforço). Se sobreviver ao dano, resgata compulsoriamente TODAS as cartas do elemento Vampiro do seu deck e cemitério para a sua mão.')
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
    SELECT id, 'manual', 'leg_dettlaff_multi_direct_strike', 'none', '{"mana_cost": 5, "target_scope": "enemy_life", "tier": 3}' FROM public.cards WHERE code = 'LEGENDARY_001' ON CONFLICT DO NOTHING;

    INSERT INTO public.card_effects (card_id, trigger_type, effect_code, target_mode, parameters)
    SELECT id, 'manual', 'leg_geels_double_surgical_swap', 'none', '{"mana_cost": 0, "target_scope": "double_deck_swap", "tier": 3}' FROM public.cards WHERE code = 'LEGENDARY_002' ON CONFLICT DO NOTHING;

    INSERT INTO public.card_effects (card_id, trigger_type, effect_code, target_mode, parameters)
    SELECT id, 'passive', 'leg_filavandrel_elf_hijack_to_deck', 'none', '{"mana_cost": 3, "required_zone": "life", "tier": 3}' FROM public.cards WHERE code = 'LEGENDARY_003' ON CONFLICT DO NOTHING;

    INSERT INTO public.card_effects (card_id, trigger_type, effect_code, target_mode, parameters)
    SELECT id, 'manual', 'leg_auberon_double_enemy_elf_mana', 'none', '{"mana_cost": 4, "tier": 3}' FROM public.cards WHERE code = 'LEGENDARY_004' ON CONFLICT DO NOTHING;

    INSERT INTO public.card_effects (card_id, trigger_type, effect_code, target_mode, parameters)
    SELECT id, 'on_attack_resolved', 'leg_eredin_solo_attack_bleed_tax', 'none', '{"mana_cost": 4, "tier": 3}' FROM public.cards WHERE code = 'LEGENDARY_005' ON CONFLICT DO NOTHING;

    INSERT INTO public.card_effects (card_id, trigger_type, effect_code, target_mode, parameters)
    SELECT id, 'manual', 'leg_verdum_legendary_generator_loop', 'none', '{"mana_cost": 2, "max_triggers": 1, "tier": 3}' FROM public.cards WHERE code = 'LEGENDARY_006' ON CONFLICT DO NOTHING;

    INSERT INTO public.card_effects (card_id, trigger_type, effect_code, target_mode, parameters)
    SELECT id, 'on_attack_resolved', 'leg_erland_slay_mana_ramp', 'none', '{"mana_cost": 0, "tier": 3}' FROM public.cards WHERE code = 'LEGENDARY_007' ON CONFLICT DO NOTHING;

    INSERT INTO public.card_effects (card_id, trigger_type, effect_code, target_mode, parameters)
    SELECT id, 'manual', 'leg_arnaghad_clone_reinforcements', 'none', '{"mana_cost": 4, "required_zone": "reinforcement", "tier": 3}' FROM public.cards WHERE code = 'LEGENDARY_008' ON CONFLICT DO NOTHING;

    INSERT INTO public.card_effects (card_id, trigger_type, effect_code, target_mode, parameters)
    SELECT id, 'manual', 'leg_gezras_hijack_enemy_deck_card', 'none', '{"mana_cost": 0, "tier": 3}' FROM public.cards WHERE code = 'LEGENDARY_009' ON CONFLICT DO NOTHING;

    INSERT INTO public.card_effects (card_id, trigger_type, effect_code, target_mode, parameters)
    SELECT id, 'manual', 'leg_cosimo_reduce_enemy_witchers_to_one', 'none', '{"mana_cost": 4, "tier": 3}' FROM public.cards WHERE code = 'LEGENDARY_010' ON CONFLICT DO NOTHING;

    INSERT INTO public.card_effects (card_id, trigger_type, effect_code, target_mode, parameters)
    SELECT id, 'manual', 'leg_alzur_global_field_bounce_reset', 'none', '{"mana_cost": 2, "tier": 3}' FROM public.cards WHERE code = 'LEGENDARY_011' ON CONFLICT DO NOTHING;

    INSERT INTO public.card_effects (card_id, trigger_type, effect_code, target_mode, parameters)
    SELECT id, 'manual', 'leg_tissaia_tutor_discount_yennefers', 'none', '{"mana_cost": 6, "synergy_target": "LEGENDARY_025", "tier": 3}' FROM public.cards WHERE code = 'LEGENDARY_012' ON CONFLICT DO NOTHING;

    INSERT INTO public.card_effects (card_id, trigger_type, effect_code, target_mode, parameters)
    SELECT id, 'manual', 'leg_carla_mill_ten_enemy_beasts', 'none', '{"mana_cost": 2, "tier": 3}' FROM public.cards WHERE code = 'LEGENDARY_013' ON CONFLICT DO NOTHING;

    INSERT INTO public.card_effects (card_id, trigger_type, effect_code, target_mode, parameters)
    SELECT id, 'manual', 'leg_tetra_execute_weaker_lives', 'none', '{"mana_cost": 6, "tier": 3}' FROM public.cards WHERE code = 'LEGENDARY_014' ON CONFLICT DO NOTHING;

    INSERT INTO public.card_effects (card_id, trigger_type, effect_code, target_mode, parameters)
    SELECT id, 'manual', 'leg_kitsu_transmute_half_enemy_deck', 'none', '{"mana_cost": 0, "tier": 3}' FROM public.cards WHERE code = 'LEGENDARY_015' ON CONFLICT DO NOTHING;

    INSERT INTO public.card_effects (card_id, trigger_type, effect_code, target_mode, parameters)
    SELECT id, 'manual', 'leg_lady_of_lake_deck_protection', 'none', '{"mana_cost": 0, "tier": 3}' FROM public.cards WHERE code = 'LEGENDARY_016' ON CONFLICT DO NOTHING;

    INSERT INTO public.card_effects (card_id, trigger_type, effect_code, target_mode, parameters)
    SELECT id, 'manual', 'leg_dandelion_forced_hand_trade', 'none', '{"mana_cost": 5, "tier": 3}' FROM public.cards WHERE code = 'LEGENDARY_017' ON CONFLICT DO NOTHING;

    INSERT INTO public.card_effects (card_id, trigger_type, effect_code, target_mode, parameters)
    SELECT id, 'on_turn_end', 'leg_caretaker_endturn_direct_snipe', 'none', '{"mana_cost": 5, "required_zone": "life", "tier": 3}' FROM public.cards WHERE code = 'LEGENDARY_018' ON CONFLICT DO NOTHING;

    INSERT INTO public.card_effects (card_id, trigger_type, effect_code, target_mode, parameters)
    SELECT id, 'on_attack_resolved', 'leg_von_everec_solo_bounce_discount', 'none', '{"mana_cost": 3, "tier": 3}' FROM public.cards WHERE code = 'LEGENDARY_019' ON CONFLICT DO NOTHING;

    INSERT INTO public.card_effects (card_id, trigger_type, effect_code, target_mode, parameters)
    SELECT id, 'reaction', 'leg_regis_vampire_mass_tutor_revive', 'none', '{"mana_cost": 4, "tier": 3}' FROM public.cards WHERE code = 'LEGENDARY_020' ON CONFLICT DO NOTHING;

END $$;

COMMIT;
