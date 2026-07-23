-- Migration 202607250052_insert_and_implement_rare_batch_3.sql
-- Inserção das cartas RARE_041 a RARE_060 com target_mode seguro e parâmetros JSONB.

BEGIN;

DO $$
DECLARE
    v_set_id uuid;
BEGIN
    SELECT id INTO v_set_id FROM public.card_sets ORDER BY created_at ASC LIMIT 1;
    IF v_set_id IS NULL THEN
        INSERT INTO public.card_sets (name, code, description) VALUES ('Expansão Rara 3', 'RARE3', 'Terceiro lote de raras') RETURNING id INTO v_set_id;
    END IF;

    -- 1. Inserir as cartas do lote 3 com ON CONFLICT UPDATE
    INSERT INTO public.cards (set_id, code, name, image_url, element, rarity, card_type, is_golden, is_original_rpg, base_power, base_max_life, effect_mana_cost, tier, effect_text)
    VALUES
    (v_set_id, 'RARE_041', 'Morvudd', 'https://via.placeholder.com/300x450.png?text=Gwent+Rare', 'Bestiário', 'rare', 'normal', false, false, 2300, 2600, 4, 1, 'Ative este efeito e inverta a Vida atual e o Poder atual de uma carta de defesa do oponente à sua escolha (seleção interativa).'),
    (v_set_id, 'RARE_042', 'Amduat o Elfo', 'https://via.placeholder.com/300x450.png?text=Gwent+Rare', 'M&F', 'rare', 'normal', false, false, 2200, 3000, 5, 1, 'Ative este efeito e destrua todas as cartas repetidas/iguais presentes na mão do seu oponente.'),
    (v_set_id, 'RARE_043', 'Dama de Ferro', 'https://via.placeholder.com/300x450.png?text=Gwent+Rare', 'Bestiário', 'rare', 'normal', false, false, 2500, 2400, 0, 1, 'Efeito passivo que ativa direto do deck: esta carta sempre estará garantida na sua mão inicial no Turno 1.'),
    (v_set_id, 'RARE_044', 'Sylvano', 'https://via.placeholder.com/300x450.png?text=Gwent+Rare', 'Bestiário', 'rare', 'normal', false, false, 2800, 1700, 2, 1, 'Ative este efeito e compre do seu cemitério uma carta à sua escolha (seleção) do tipo Bestiário que tenha o Poder maior que o desta carta (2800).'),
    (v_set_id, 'RARE_045', 'ArqueGriffo', 'https://via.placeholder.com/300x450.png?text=Gwent+Rare', 'Bestiário', 'rare', 'normal', false, false, 4000, 1700, 4, 1, 'Ataque diretamente uma Carta de Vida do seu campo e uma Carta de Vida do campo do seu oponente à sua escolha (seleção dupla).'),
    (v_set_id, 'RARE_046', 'Orianna', 'https://via.placeholder.com/300x450.png?text=Gwent+Rare', 'Bestiário', 'rare', 'normal', false, false, 2400, 2000, 4, 1, 'Só pode ser ativada como Carta de Vida no campo. O oponente só poderá posicionar no máximo 1 carta de reforço no campo dele por rodada até Orianna ser destruída.'),
    (v_set_id, 'RARE_047', 'Qebehsenuef o elfo', 'https://via.placeholder.com/300x450.png?text=Gwent+Rare', 'M&F', 'rare', 'normal', false, false, 1300, 1, 0, 1, 'Passivo automático. Esta carta ganha +250 de Vida para cada carta de raridade comum presente no deck do oponente.'),
    (v_set_id, 'RARE_048', 'Thalorien o Elfo', 'https://via.placeholder.com/300x450.png?text=Gwent+Rare', 'M&F', 'rare', 'normal', false, false, 1800, 3000, 2, 1, 'Ao ativar durante um ataque do oponente, se esta carta sobreviver ao golpe estando no campo de reforço, a Vida dela dobra imediatamente.'),
    (v_set_id, 'RARE_049', 'Veneno a Mercenária', 'https://via.placeholder.com/300x450.png?text=Gwent+Rare', 'Civil', 'rare', 'normal', false, false, 1200, 1000, 0, 1, 'Aumente em +1 o custo de mana de uma carta aleatória da mão do oponente.'),
    (v_set_id, 'RARE_050', 'Cerlinna a Alpor', 'https://via.placeholder.com/300x450.png?text=Gwent+Rare', 'Bestiário', 'rare', 'normal', false, false, 1800, 2800, 4, 1, 'Só pode ser ativado se estiver no campo como Carta de Vida. Altere o custo de mana da carta "Varuss o Meio Elfo" dentro do seu deck para =0.'),
    (v_set_id, 'RARE_051', 'Varuss o Meio Elfo', 'https://via.placeholder.com/300x450.png?text=Gwent+Rare', 'M&F', 'rare', 'normal', false, false, 1800, 2000, 7, 1, 'Só pode ser ativado se houver uma carta "Cerlinna a Alpor" no seu cemitério. Destrua uma Carta de Vida do oponente à sua escolha (seleção interativa).'),
    (v_set_id, 'RARE_052', 'Thanatos da Escola da Víbora', 'https://via.placeholder.com/300x450.png?text=Gwent+Rare', 'Witcher', 'rare', 'normal', false, false, 1700, 1550, 4, 1, 'Ao ativar, a carta do tipo Witcher com o maior Poder dentro do deck de cada jogador será destruída e enviada ao cemitério.'),
    (v_set_id, 'RARE_053', 'Jansen da Escola da Coruja', 'https://via.placeholder.com/300x450.png?text=Gwent+Rare', 'Witcher', 'rare', 'normal', false, false, 1350, 1900, 3, 1, 'Só pode ser ativado se houver uma carta "Morvim da Escola da Coruja" na sua mão. Compre (saque para a mão) uma carta do tipo Witcher à sua escolha do seu deck.'),
    (v_set_id, 'RARE_054', 'General Franz de Teméria', 'https://via.placeholder.com/300x450.png?text=Gwent+Rare', 'Civil', 'rare', 'normal', false, false, 2000, 2000, 0, 1, 'Após realizar um ataque com esta carta, escolha se quer exilar/limpar uma carta do seu cemitério para que Franz retorne imediatamente para a sua mão.'),
    (v_set_id, 'RARE_055', 'Enel Ducat - Agente de Inteligencia', 'https://via.placeholder.com/300x450.png?text=Gwent+Rare', 'Civil', 'rare', 'normal', false, false, 700, 2000, 0, 1, 'Só pode ser ativado se o oponente passou a rodada/turno anterior dele sem agir. Compre uma carta de raridade lendária do seu deck à sua escolha (seleção).'),
    (v_set_id, 'RARE_056', 'Sigrith Gowdie - A Bruxa', 'https://via.placeholder.com/300x450.png?text=Gwent+Rare', 'M&F', 'rare', 'normal', false, false, 2500, 2500, 5, 1, 'Só pode ser ativada como Carta de Vida no campo. A cada início de rodada do jogador, ele comprará compulsoriamente uma carta do seu próprio cemitério para a mão até Sigrith ser destruída.'),
    (v_set_id, 'RARE_057', 'Venger o Mercenário', 'https://via.placeholder.com/300x450.png?text=Gwent+Rare', 'Civil', 'rare', 'normal', false, false, 2400, 1500, 3, 1, 'Ao ativar, os dois jogadores trocam uma Carta de Vida de seus campos pela do campo do oponente (seleção interativa para ambos ou troca direta por escolha do conjurador).'),
    (v_set_id, 'RARE_058', 'Trevor da Escola da Manticora', 'https://via.placeholder.com/300x450.png?text=Gwent+Rare', 'Witcher', 'rare', 'normal', false, false, 1000, 2400, 2, 1, 'Ative e restaure exatamente 50% da Vida máxima de uma Carta de Vida do seu campo que já esteja danificada (current_life < base_max_life).'),
    (v_set_id, 'RARE_059', 'Dama da Peste', 'https://via.placeholder.com/300x450.png?text=Gwent+Rare', 'Bestiário', 'rare', 'normal', false, false, 2500, 2000, 4, 1, 'Ative este efeito e limpe (purga total) todo o cemitério do oponente.'),
    (v_set_id, 'RARE_060', 'Heythan da Escola do Lobo', 'https://via.placeholder.com/300x450.png?text=Gwent+Rare', 'Witcher', 'rare', 'normal', false, false, 1800, 1100, 2, 1, 'Ative este efeito e force o oponente a descartar para o cemitério uma carta aleatória da mão dele que seja especificamente de raridade comum (rarity = "common").')
    ON CONFLICT (code) DO UPDATE SET
        name = EXCLUDED.name,
        base_power = EXCLUDED.base_power,
        base_max_life = EXCLUDED.base_max_life,
        effect_mana_cost = EXCLUDED.effect_mana_cost,
        effect_text = EXCLUDED.effect_text;

    -- 2. Inserir os Efeitos blindados com target_mode padronizado e parâmetros JSONB

    INSERT INTO public.card_effects (card_id, trigger_type, effect_code, target_mode, parameters)
    SELECT id, 'manual', 'rare_morvudd_stat_invert', 'target_card', '{"mana_cost": 4, "target_scope": "enemy_reinforcement"}' FROM public.cards WHERE code = 'RARE_041' ON CONFLICT DO NOTHING;

    INSERT INTO public.card_effects (card_id, trigger_type, effect_code, target_mode, parameters)
    SELECT id, 'manual', 'rare_amduat_purge_hand_duplicates', 'none', '{"mana_cost": 5}' FROM public.cards WHERE code = 'RARE_042' ON CONFLICT DO NOTHING;

    INSERT INTO public.card_effects (card_id, trigger_type, effect_code, target_mode, parameters)
    SELECT id, 'passive', 'rare_iron_maiden_guaranteed_opener', 'none', '{"mana_cost": 0}' FROM public.cards WHERE code = 'RARE_043' ON CONFLICT DO NOTHING;

    INSERT INTO public.card_effects (card_id, trigger_type, effect_code, target_mode, parameters)
    SELECT id, 'manual', 'rare_sylvano_beast_revive_tutor', 'none', '{"mana_cost": 2}' FROM public.cards WHERE code = 'RARE_044' ON CONFLICT DO NOTHING;

    INSERT INTO public.card_effects (card_id, trigger_type, effect_code, target_mode, parameters)
    SELECT id, 'manual', 'rare_archgriffin_double_edge_snipe', 'none', '{"mana_cost": 4, "target_scope": "double_life_selection"}' FROM public.cards WHERE code = 'RARE_045' ON CONFLICT DO NOTHING;

    INSERT INTO public.card_effects (card_id, trigger_type, effect_code, target_mode, parameters)
    SELECT id, 'manual', 'rare_orianna_reinforcement_throttle', 'none', '{"mana_cost": 4, "required_zone": "life"}' FROM public.cards WHERE code = 'RARE_046' ON CONFLICT DO NOTHING;

    INSERT INTO public.card_effects (card_id, trigger_type, effect_code, target_mode, parameters)
    SELECT id, 'passive', 'rare_qebehsenuef_scale_by_enemy_commons', 'none', '{"mana_cost": 0}' FROM public.cards WHERE code = 'RARE_047' ON CONFLICT DO NOTHING;

    INSERT INTO public.card_effects (card_id, trigger_type, effect_code, target_mode, parameters)
    SELECT id, 'reaction', 'rare_thalorien_survive_double_hp', 'none', '{"mana_cost": 2}' FROM public.cards WHERE code = 'RARE_048' ON CONFLICT DO NOTHING;

    INSERT INTO public.card_effects (card_id, trigger_type, effect_code, target_mode, parameters)
    SELECT id, 'manual', 'rare_venom_tax_random_card', 'none', '{"mana_cost": 0}' FROM public.cards WHERE code = 'RARE_049' ON CONFLICT DO NOTHING;

    INSERT INTO public.card_effects (card_id, trigger_type, effect_code, target_mode, parameters)
    SELECT id, 'manual', 'rare_cerlinna_discount_varuss', 'none', '{"mana_cost": 4, "required_zone": "life"}' FROM public.cards WHERE code = 'RARE_050' ON CONFLICT DO NOTHING;

    INSERT INTO public.card_effects (card_id, trigger_type, effect_code, target_mode, parameters)
    SELECT id, 'manual', 'rare_varuss_execute_life', 'target_card', '{"mana_cost": 7, "target_scope": "enemy_life"}' FROM public.cards WHERE code = 'RARE_051' ON CONFLICT DO NOTHING;

    INSERT INTO public.card_effects (card_id, trigger_type, effect_code, target_mode, parameters)
    SELECT id, 'manual', 'rare_thanatos_purge_highest_witchers', 'none', '{"mana_cost": 4}' FROM public.cards WHERE code = 'RARE_052' ON CONFLICT DO NOTHING;

    INSERT INTO public.card_effects (card_id, trigger_type, effect_code, target_mode, parameters)
    SELECT id, 'manual', 'rare_jansen_tutor_witcher', 'none', '{"mana_cost": 3}' FROM public.cards WHERE code = 'RARE_053' ON CONFLICT DO NOTHING;

    INSERT INTO public.card_effects (card_id, trigger_type, effect_code, target_mode, parameters)
    SELECT id, 'on_attack_resolved', 'rare_franz_graveyard_bounce', 'none', '{"mana_cost": 0}' FROM public.cards WHERE code = 'RARE_054' ON CONFLICT DO NOTHING;

    INSERT INTO public.card_effects (card_id, trigger_type, effect_code, target_mode, parameters)
    SELECT id, 'manual', 'rare_enel_legendary_tutor', 'none', '{"mana_cost": 0}' FROM public.cards WHERE code = 'RARE_055' ON CONFLICT DO NOTHING;

    INSERT INTO public.card_effects (card_id, trigger_type, effect_code, target_mode, parameters)
    SELECT id, 'on_turn_start', 'rare_sigrith_graveyard_engine', 'none', '{"mana_cost": 5, "required_zone": "life"}' FROM public.cards WHERE code = 'RARE_056' ON CONFLICT DO NOTHING;

    INSERT INTO public.card_effects (card_id, trigger_type, effect_code, target_mode, parameters)
    SELECT id, 'manual', 'rare_venger_life_swap', 'none', '{"mana_cost": 3, "target_scope": "double_life_selection"}' FROM public.cards WHERE code = 'RARE_057' ON CONFLICT DO NOTHING;

    INSERT INTO public.card_effects (card_id, trigger_type, effect_code, target_mode, parameters)
    SELECT id, 'manual', 'rare_trevor_heal_half', 'target_card', '{"mana_cost": 2, "target_scope": "my_life"}' FROM public.cards WHERE code = 'RARE_058' ON CONFLICT DO NOTHING;

    INSERT INTO public.card_effects (card_id, trigger_type, effect_code, target_mode, parameters)
    SELECT id, 'manual', 'rare_plague_maiden_purge_enemy_graveyard', 'none', '{"mana_cost": 4}' FROM public.cards WHERE code = 'RARE_059' ON CONFLICT DO NOTHING;

    INSERT INTO public.card_effects (card_id, trigger_type, effect_code, target_mode, parameters)
    SELECT id, 'manual', 'rare_heythan_discard_common', 'none', '{"mana_cost": 2}' FROM public.cards WHERE code = 'RARE_060' ON CONFLICT DO NOTHING;

END $$;

COMMIT;
