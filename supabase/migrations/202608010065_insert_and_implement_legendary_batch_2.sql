-- Migration 202608010065_insert_and_implement_legendary_batch_2.sql

BEGIN;

DO $$
DECLARE
    v_set_id uuid;
BEGIN
    SELECT id INTO v_set_id FROM public.card_sets ORDER BY created_at ASC LIMIT 1;
    IF v_set_id IS NULL THEN
        INSERT INTO public.card_sets (name, code, description) VALUES ('Expansão Lendária 1', 'LEG1', 'Primeiro lote de lendárias') RETURNING id INTO v_set_id;
    END IF;

    -- Inserir as cartas
    INSERT INTO public.cards (set_id, code, name, image_url, element, rarity, card_type, is_golden, is_original_rpg, base_power, base_max_life, effect_mana_cost, tier, effect_text)
    VALUES
    (v_set_id, 'LEGENDARY_021', 'Vesemir', 'https://encrypted-tbn0.gstatic.com/images?q=tbn:ANd9GcRMvHSzor1oMJ16bHiU-mcqOc4R461OuioSLpK9ffakwQ&s=10', 'Witcher', 'legendary', 'normal', false, false, 2800, 4000, 0, 3, 'Efeito passivo automático operando da mão. Enquanto esta carta estiver na sua mão, no término de cada rodada, todas as outras cartas presentes na sua mão ganham permanentemente +1000 de Poder e +1000 de Vida.'),
    (v_set_id, 'LEGENDARY_022', 'Geralt de Rivia', 'https://encrypted-tbn0.gstatic.com/images?q=tbn:ANd9GcQQFULHLyNKXXeNzYQXR9jEbxy17G1iHFWD0yAK5If3Sw&s=10', 'Witcher', 'legendary', 'normal', false, false, 5000, 3000, 0, 3, 'Efeito passivo automático operando APENAS do deck. Sempre que você iniciar o turno, em vez da compra comum, o servidor abre um modal de seleção exibindo 2 cartas aleatórias do seu deck para você escolher qual deseja sacar para a mão.'),
    (v_set_id, 'LEGENDARY_023', 'Triss Merigold', 'https://encrypted-tbn0.gstatic.com/images?q=tbn:ANd9GcTw_i3txYlLlZSKndh38FZTmEs3K5hGNyup7_OJ1EiBMg&s=10', 'M&F', 'legendary', 'normal', false, false, 2300, 6000, 4, 3, 'Passivo na mesa. Enquanto Triss estiver viva no campo (vida ou reforço), todas as suas cartas na zona de Reforço têm sua Vida atual e Vida máxima dobradas.'),
    (v_set_id, 'LEGENDARY_024', 'Ciri', 'https://encrypted-tbn0.gstatic.com/images?q=tbn:ANd9GcRmjU1fyrJyuyxZrJMozaL74GYVlOdYX8sMo5TtziXjWQ&s=10', 'Elfica', 'legendary', 'normal', false, false, 5000, 1700, 5, 3, 'Ao ativar, desfere um ataque direto contra 1 Carta de Vida do oponente à sua escolha (ignorando reforços). Imediatamente após o dano, Ciri retorna ao seu deck, tendo 50% de chance de ser posicionada compulsoriamente no topo do baralho.'),
    (v_set_id, 'LEGENDARY_025', 'Borch Três Gralhas', 'https://encrypted-tbn0.gstatic.com/images?q=tbn:ANd9GcTsouQCZ3wkum6QAhbJPn0--XY6jHEx4l99eKWk57xRDQ&s=10', 'Bestiario', 'legendary', 'normal', false, false, 4000, 7000, 5, 3, 'Ao ativar, zera completamente a Vida e o Poder de TODAS as cartas atualmente presentes na mão do oponente.'),
    (v_set_id, 'LEGENDARY_026', 'Yennefer', 'https://encrypted-tbn0.gstatic.com/images?q=tbn:ANd9GcT1T3mbhtHdY51I3F0u0xSRlcRKez4RzU4bK1DV1ZtOlw&s=10', 'M&F', 'legendary', 'normal', false, false, 3300, 4000, 6, 3, 'Ative este efeito e destrua instantaneamente (execute direto para o cemitério) uma Carta de Vida do oponente à sua escolha na mesa.'),
    (v_set_id, 'LEGENDARY_027', 'Gaunter O''Dimm', 'https://encrypted-tbn0.gstatic.com/images?q=tbn:ANd9GcRVWs1KmUBCqeh_9IRnRST9YA49Bdmhn1XUKuXOvT6EAA&s=10', 'Bestiario', 'legendary', 'normal', false, false, 2600, 6000, 8, 3, 'Ao ativar, destrói e purga absolutamente TODO O CAMPO do inimigo (todos os Reforços e todas as Cartas de Vida), deixando compulsoriamente apenas a última (1) Carta de Vida dele viva na mesa.'),
    (v_set_id, 'LEGENDARY_028', 'Francesca Findabair', 'https://encrypted-tbn0.gstatic.com/images?q=tbn:ANd9GcRYhqqoLgoGFfxIESXWDsPldbCUeRd5VZvmST4zINfrhQ&s=10', 'M&F', 'legendary', 'normal', false, false, 5000, 5000, 6, 3, 'Ao ativar, protege permanentemente uma Carta de Vida aliada à sua escolha. Quando essa carta protegida for destruída, seu feitiço de vingança destrói TODA a mão do oponente e remove 50% da Vida atual de todas as Cartas de Vida inimigas restantes.'),
    (v_set_id, 'LEGENDARY_029', 'Kaen Glahel', 'https://i.postimg.cc/v4j2zprt/kaengla.webp', 'Elfica', 'legendary', 'normal', false, false, 2500, 6000, 0, 3, 'Efeito passivo automático operando APENAS do deck. Enquanto esta carta estiver dentro do seu baralho, você compra compulsoriamente uma carta a mais em todo início de rodada.'),
    (v_set_id, 'LEGENDARY_030', 'Sonegado Ancião', 'https://encrypted-tbn0.gstatic.com/images?q=tbn:ANd9GcT_WBTqXe-mg-c4d-lmjB8S0IAziCWR5iqAGZwTFs3Tiw&s=10', 'Vampiro', 'legendary', 'normal', false, false, 4000, 4000, 0, 3, 'Ao ativar, varre a mesa e destrói instantaneamente todas as cartas NÃO REVELADAS do oponente, sem abrir janela de reação ou permitir ativação de efeitos.'),
    (v_set_id, 'LEGENDARY_031', 'Deglan o Bruxo', 'https://encrypted-tbn0.gstatic.com/images?q=tbn:ANd9GcT_WBTqXe-mg-c4d-lmjB8S0IAziCWR5iqAGZwTFs3Tiw&s=10', 'Witcher', 'legendary', 'normal', false, false, 2800, 4000, 2, 3, 'Só pode ser ativada como Carta de Vida. Enquanto Deglan estiver vivo em seu campo de vida, o oponente fica totalmente bloqueado de ativar feitiços ou ataques diretos ignorando reforços.'),
    (v_set_id, 'LEGENDARY_032', 'Shaw Okami o Mago', 'http://thewitcherrpg.ucoz.com.br/novapasta/novadnv/okami.jpg', 'M&F', 'legendary', 'normal', false, false, 2900, 2900, 2, 3, 'Ao ativar, seleciona 1 carta do seu deck e gera compulsoriamente 5 cópias exatas e idênticas dessa carta, misturando-as dentro do seu baralho.'),
    (v_set_id, 'LEGENDARY_033', 'Vilgefortz', 'https://encrypted-tbn0.gstatic.com/images?q=tbn:ANd9GcSVSW29JiFjJzP5Hh460nj2LSoOi4-tcZThzIPiZhXdJQ&s=10', 'M&F', 'legendary', 'normal', false, false, 4000, 4000, 5, 3, 'Ao ativar, destrói instantaneamente TODAS as cartas presentes na mão, no cemitério e na linha de reforço do oponente cujo Poder original ou atual seja inferior a 4000.'),
    (v_set_id, 'LEGENDARY_034', 'Dagon', 'https://encrypted-tbn0.gstatic.com/images?q=tbn:ANd9GcRLCOei1fec_5zgFHyLbgjyI2RfKvkyIBI8vFCVsuMnHA&s=10', 'Bestiario', 'legendary', 'normal', false, false, 4000, 4000, 4, 3, 'Reação (Reforço). Se atacado e o oponente já tiver ativado efeito neste turno, Dagon aborta o ataque e retorna ao deck com atributos dobrados.'),
    (v_set_id, 'LEGENDARY_035', 'Madoc o Primeiro Bruxo', 'https://encrypted-tbn0.gstatic.com/images?q=tbn:ANd9GcQ9cRsiBYub0ifGRC2_UDUR-AH4JELtQ-250SA-9YSS_Q&s=10', 'Witcher', 'legendary', 'normal', false, false, 3000, 2000, 0, 3, 'Ao ativar, lista todos os efeitos Witcher já usados na partida e permite que você reexecute 1 deles gratuitamente.'),
    (v_set_id, 'LEGENDARY_036', 'Sheala de Tancarville', 'https://encrypted-tbn0.gstatic.com/images?q=tbn:ANd9GcTwYzCU6S4HzG4qUHRy-DlAUCBrC2AanTimaF9RZSc_ng&s=10', 'M&F', 'legendary', 'normal', false, false, 2500, 2900, 1, 3, 'Ao ativar, destrói instantaneamente todas as cartas da mão do oponente cujo Custo de Mana seja maior que o custo desta carta (mana > 1).'),
    (v_set_id, 'LEGENDARY_037', 'Lara Dorren', 'https://encrypted-tbn0.gstatic.com/images?q=tbn:ANd9GcSaTFT-Y-OLBuoL_eRMNNtDfHt7Ax37WT8ePN1Q-narsQ&s=10', 'Elfica', 'legendary', 'normal', false, false, 2000, 5000, 6, 3, 'Ao ativar, sorteia um número de 1 a 3. Desfere essa quantidade de ataques diretos sucessivos (2000 cada) contra Cartas de Vida inimigas aleatórias.'),
    (v_set_id, 'LEGENDARY_038', 'Dragão Myrgtabrakke', 'https://encrypted-tbn0.gstatic.com/images?q=tbn:ANd9GcTAZ_gZPSr6fxCUNiXgv6Y102uAQP9B-WA0IDHLB2xGQw&s=10', 'Bestiario', 'legendary', 'normal', false, false, 5000, 5500, 5, 3, 'Ao ativar, inspeciona seu deck, seleciona aleatoriamente 2 cartas que possuam ataques diretos à Vida e compra-as.'),
    (v_set_id, 'LEGENDARY_039', 'Falken', 'https://encrypted-tbn0.gstatic.com/images?q=tbn:ANd9GcRgnx7VFU5TFT40GI4QrmwvJKMAVoP1ZLKv9OTIdBVZ7A&s=10', 'Civil', 'legendary', 'normal', false, false, 4000, 2700, 2, 3, 'Destrói todas as cartas do elemento Civil da sua mão. Ganha permanentemente +1 de Mana Máxima e Mana Atual para cada uma.'),
    (v_set_id, 'LEGENDARY_040', 'Kagma o Herói de Mahakan', 'https://encrypted-tbn0.gstatic.com/images?q=tbn:ANd9GcTZ6QdtImYrtuHbfZdeYoDQDsWjXlS7mUFInASnGiobyQ&s=10', 'Anao', 'legendary', 'normal', false, false, 6000, 3000, 0, 3, 'Efeito passivo. Se esta carta for descartada da sua mão para o cemitério, destrói instantaneamente 1 Carta de Vida do oponente.')
    ON CONFLICT (code) DO UPDATE SET
        name = EXCLUDED.name,
        image_url = EXCLUDED.image_url,
        base_power = EXCLUDED.base_power,
        base_max_life = EXCLUDED.base_max_life,
        effect_mana_cost = EXCLUDED.effect_mana_cost,
        effect_text = EXCLUDED.effect_text,
        tier = EXCLUDED.tier;

    -- Inserir os Efeitos blindados com target_mode padronizado e parâmetros JSONB
    INSERT INTO public.card_effects (card_id, trigger_type, effect_code, target_mode, parameters)
    SELECT id, 'on_turn_end', 'leg_vesemir_hand_buff_loop', 'none', '{"mana_cost": 0, "required_zone": "hand", "tier": 3}' FROM public.cards WHERE code = 'LEGENDARY_021' ON CONFLICT DO NOTHING;

    INSERT INTO public.card_effects (card_id, trigger_type, effect_code, target_mode, parameters)
    SELECT id, 'on_draw', 'leg_geralt_double_scry_draw', 'none', '{"mana_cost": 0, "required_zone": "deck", "tier": 3}' FROM public.cards WHERE code = 'LEGENDARY_022' ON CONFLICT DO NOTHING;

    INSERT INTO public.card_effects (card_id, trigger_type, effect_code, target_mode, parameters)
    SELECT id, 'passive', 'leg_triss_double_reinforcement_hp', 'none', '{"mana_cost": 0, "tier": 3}' FROM public.cards WHERE code = 'LEGENDARY_023' ON CONFLICT DO NOTHING;

    INSERT INTO public.card_effects (card_id, trigger_type, effect_code, target_mode, parameters)
    SELECT id, 'manual', 'leg_ciri_direct_snipe_deck_bounce', 'target_card', '{"mana_cost": 5, "target_scope": "enemy_life", "tier": 3}' FROM public.cards WHERE code = 'LEGENDARY_024' ON CONFLICT DO NOTHING;

    INSERT INTO public.card_effects (card_id, trigger_type, effect_code, target_mode, parameters)
    SELECT id, 'manual', 'leg_borch_zero_enemy_hand_stats', 'none', '{"mana_cost": 5, "target_scope": "enemy_hand", "tier": 3}' FROM public.cards WHERE code = 'LEGENDARY_025' ON CONFLICT DO NOTHING;

    INSERT INTO public.card_effects (card_id, trigger_type, effect_code, target_mode, parameters)
    SELECT id, 'manual', 'leg_yennefer_execute_enemy_life', 'target_card', '{"mana_cost": 6, "target_scope": "enemy_life", "tier": 3}' FROM public.cards WHERE code = 'LEGENDARY_026' ON CONFLICT DO NOTHING;

    INSERT INTO public.card_effects (card_id, trigger_type, effect_code, target_mode, parameters)
    SELECT id, 'manual', 'leg_gaunter_apocalyptic_board_wipe', 'none', '{"mana_cost": 8, "target_scope": "all_enemy", "tier": 3}' FROM public.cards WHERE code = 'LEGENDARY_027' ON CONFLICT DO NOTHING;

    INSERT INTO public.card_effects (card_id, trigger_type, effect_code, target_mode, parameters)
    SELECT id, 'manual', 'leg_francesca_retaliation_ward', 'target_card', '{"mana_cost": 6, "target_scope": "ally_life", "tier": 3}' FROM public.cards WHERE code = 'LEGENDARY_028' ON CONFLICT DO NOTHING;

    INSERT INTO public.card_effects (card_id, trigger_type, effect_code, target_mode, parameters)
    SELECT id, 'on_turn_end', 'leg_kaen_glahel_extra_draw_from_deck', 'none', '{"mana_cost": 0, "required_zone": "deck", "tier": 3}' FROM public.cards WHERE code = 'LEGENDARY_029' ON CONFLICT DO NOTHING;

    INSERT INTO public.card_effects (card_id, trigger_type, effect_code, target_mode, parameters)
    SELECT id, 'manual', 'leg_unseen_elder_destroy_unrevealed', 'none', '{"mana_cost": 0, "target_scope": "enemy_unrevealed", "tier": 3}' FROM public.cards WHERE code = 'LEGENDARY_030' ON CONFLICT DO NOTHING;

    INSERT INTO public.card_effects (card_id, trigger_type, effect_code, target_mode, parameters)
    SELECT id, 'passive', 'leg_deglan_block_direct_attacks', 'none', '{"mana_cost": 0, "required_zone": "life", "tier": 3}' FROM public.cards WHERE code = 'LEGENDARY_031' ON CONFLICT DO NOTHING;

    INSERT INTO public.card_effects (card_id, trigger_type, effect_code, target_mode, parameters)
    SELECT id, 'manual', 'leg_shaw_okami_clone_five_to_deck', 'none', '{"mana_cost": 2, "target_scope": "deck", "tier": 3}' FROM public.cards WHERE code = 'LEGENDARY_032' ON CONFLICT DO NOTHING;

    INSERT INTO public.card_effects (card_id, trigger_type, effect_code, target_mode, parameters)
    SELECT id, 'manual', 'leg_vilgefortz_purge_weaker_cards', 'none', '{"mana_cost": 5, "target_scope": "enemy_hand_reinforcement", "tier": 3}' FROM public.cards WHERE code = 'LEGENDARY_033' ON CONFLICT DO NOTHING;

    INSERT INTO public.card_effects (card_id, trigger_type, effect_code, target_mode, parameters)
    SELECT id, 'reaction', 'leg_dagon_reactive_deck_bounce_double', 'none', '{"mana_cost": 4, "required_zone": "reinforcement", "tier": 3}' FROM public.cards WHERE code = 'LEGENDARY_034' ON CONFLICT DO NOTHING;

    INSERT INTO public.card_effects (card_id, trigger_type, effect_code, target_mode, parameters)
    SELECT id, 'manual', 'leg_madoc_mimic_past_witcher_effect', 'none', '{"mana_cost": 0, "tier": 3}' FROM public.cards WHERE code = 'LEGENDARY_035' ON CONFLICT DO NOTHING;

    INSERT INTO public.card_effects (card_id, trigger_type, effect_code, target_mode, parameters)
    SELECT id, 'manual', 'leg_sheala_discard_expensive_enemy_hand', 'none', '{"mana_cost": 1, "target_scope": "enemy_hand", "tier": 3}' FROM public.cards WHERE code = 'LEGENDARY_036' ON CONFLICT DO NOTHING;

    INSERT INTO public.card_effects (card_id, trigger_type, effect_code, target_mode, parameters)
    SELECT id, 'manual', 'leg_lara_dorren_rng_multi_strike', 'none', '{"mana_cost": 6, "target_scope": "enemy_life", "tier": 3}' FROM public.cards WHERE code = 'LEGENDARY_037' ON CONFLICT DO NOTHING;

    INSERT INTO public.card_effects (card_id, trigger_type, effect_code, target_mode, parameters)
    SELECT id, 'manual', 'leg_myrgtabrakke_tutor_snipers', 'none', '{"mana_cost": 5, "target_scope": "deck", "tier": 3}' FROM public.cards WHERE code = 'LEGENDARY_038' ON CONFLICT DO NOTHING;

    INSERT INTO public.card_effects (card_id, trigger_type, effect_code, target_mode, parameters)
    SELECT id, 'manual', 'leg_falken_sacrifice_civilians_for_mana', 'none', '{"mana_cost": 2, "target_scope": "ally_hand", "tier": 3}' FROM public.cards WHERE code = 'LEGENDARY_039' ON CONFLICT DO NOTHING;

    INSERT INTO public.card_effects (card_id, trigger_type, effect_code, target_mode, parameters)
    SELECT id, 'on_destroyed', 'leg_kagma_discard_retaliation_snipe', 'none', '{"mana_cost": 0, "required_zone": "hand", "tier": 3}' FROM public.cards WHERE code = 'LEGENDARY_040' ON CONFLICT DO NOTHING;

END $$;

COMMIT;
