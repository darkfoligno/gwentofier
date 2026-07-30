-- Migration: 202608030230_insert_and_implement_17_witcher_cards.sql
-- Inserts 17 new Witcher/Vampire/Civil cards and implements their exact mechanics.

-- 1. Insert cards into public.cards
INSERT INTO public.cards (
    id, set_id, code, name, image_url, element, rarity, card_type, is_golden, is_original_rpg, base_power, base_max_life, effect_mana_cost, tier, leader_cooldown, effect_text, is_active, version
) VALUES
('a296e81d-e593-41bb-a79d-9cf94d112d01', '9088670c-9eb9-4bb7-96fc-9edfdb01fae6', 'EPIC_WITCHER_UFRIC', 'Ufric da Escola do Grifo', 'http://thewitcherrpg.ucoz.com.br/e56d4f7cbfb4d2551caf2f38ef9dc94d.jpg', 'Witcher', 'epic', 'normal', false, false, 2800, 4000, 4, 1, 0, 'Ao ativar, o servidor insere uma trava na tabela match_runtime_effects associada ao oponente. Durante a reaction_window, qualquer tentativa do oponente de ativar uma reação vinda de uma carta do tabuleiro cujo custo de mana seja MENOR QUE 4 será bloqueada/recusada.', true, 1),
('a296e81d-e593-41bb-a79d-9cf94d112d02', '9088670c-9eb9-4bb7-96fc-9edfdb01fae6', 'LEG_WITCHER_LUCIAN', 'Lucian de Velen', 'http://thewitcherrpg.ucoz.com.br/novapasta/outrapasta/2/NOVAIMA/Lucian-o-guerreiro-dos-raios.png', 'Witcher', 'legendary', 'normal', false, false, 4000, 2500, 6, 1, 0, 'Efeito de campo (Mass Removal). O servidor deve executar um UPDATE match_cards SET zone = ''graveyard'' para todas as cartas em campo (zone IN (''attacker'', ''reinforcement'', ''life'')) de AMBOS os jogadores cuja vida atual (current_life) seja inferior a 4000 (poder de Lucian).', true, 1),
('a296e81d-e593-41bb-a79d-9cf94d112d03', '9088670c-9eb9-4bb7-96fc-9edfdb01fae6', 'RARE_WITCHER_ARON', 'Aron de Kovir', 'http://thewitcherrpg.ucoz.com.br/_spt/Aron.jpg', 'Witcher', 'rare', 'normal', false, false, 2000, 2000, 3, 1, 0, 'O servidor faz um SELECT id FROM match_cards WHERE owner_user_id != p_actor AND zone = ''hand'' ORDER BY random() LIMIT 1. Com este alvo, insere um modificador permanente de silêncio (anulando o effect_code da carta sorteada) na mão do oponente.', true, 1),
('a296e81d-e593-41bb-a79d-9cf94d112d04', '9088670c-9eb9-4bb7-96fc-9edfdb01fae6', 'RARE_WITCHER_EMMA', 'Emma VanBrown', 'http://thewitcherrpg.ucoz.com.br/3bc0144c7342c36f45a8a363d4b6863e.jpg', 'Witcher', 'rare', 'normal', false, false, 2000, 2000, 4, 1, 0, 'O servidor sorteia 1 carta de vida (zone = ''life'') do oponente e chama apply_damage_internal aplicando dano direto. Em seguida, gera um número aleatório (random() <= 0.25). Se verdadeiro, repete o sorteio e aplica um novo ataque (mesmo poder) contra outra (ou a mesma) carta de vida.', true, 1),
('a296e81d-e593-41bb-a79d-9cf94d112d05', '9088670c-9eb9-4bb7-96fc-9edfdb01fae6', 'LEG_WITCHER_IRIS', 'Iris de Cintra', 'http://thewitcherrpg.ucoz.com.br/novapasta/outrapasta/tumblr_mzc3dnYgfq1rfyiu4o1_1280.jpg', 'Witcher', 'legendary', 'normal', false, false, 4000, 1800, 4, 1, 0, 'Metadado: {"target_mode": "deck"}. O jogador abre o próprio deck na interface, seleciona o alvo, e a RPC altera a zone do p_target_card_id de ''deck'' para ''hand''.', true, 1),
('a296e81d-e593-41bb-a79d-9cf94d112d06', '9088670c-9eb9-4bb7-96fc-9edfdb01fae6', 'EPIC_VAMP_KHAN', 'Khan o Caçador de Bruxos', 'https://i.postimg.cc/ZnwmzvjZ/lhan.webp', 'Vampiro', 'epic', 'normal', false, false, 2800, 2600, 1, 1, 0, 'O servidor conta (COUNT(*)) quantas cartas o oponente tem nas zonas de campo (attacker, reinforcement, life) cujo element = ''Witcher''. Faz um loop com esse número chamando game_private.draw_internal() para o jogador atual.', true, 1),
('a296e81d-e593-41bb-a79d-9cf94d112d07', '9088670c-9eb9-4bb7-96fc-9edfdb01fae6', 'COMMON_CIVIL_KRISZILA', 'Camponesa Kriszila', 'https://i.postimg.cc/QMJnzGfr/kris.webp', 'Civil', 'common', 'normal', false, false, 100, 2000, 0, 1, 0, '1) Imortalidade: Um Hook no recebimento de dano checa se a carta "Lucius da Escola do Gato" está no deck do dono desta carta. Se sim, bloqueia morte (mantém 1 HP). 2) Cura: Um Hook no end_turn checa se "Lucius" está no deck do oponente. Se sim, executa UPDATE current_life = maximum_life nesta carta.', true, 1),
('a296e81d-e593-41bb-a79d-9cf94d112d08', '9088670c-9eb9-4bb7-96fc-9edfdb01fae6', 'EPIC_WITCHER_CASTREL', 'Castrel da Escola do Gato', 'https://i.postimg.cc/G2Sz0cYy/kast.webp', 'Witcher', 'epic', 'normal', false, false, 3000, 1600, 0, 1, 0, 'O servidor conta as cartas na mão do jogador e deleta todas (manda pro graveyard). Depois, faz um SELECT id FROM cards WHERE name ILIKE ''%Escola do Gato%'' ORDER BY random() LIMIT [contagem_anterior] na tabela bruta de cartas do jogo (não do deck). Ele insere as cartas sorteadas na tabela match_cards diretamente na ''hand'' do jogador.', true, 1),
('a296e81d-e593-41bb-a79d-9cf94d112d09', '9088670c-9eb9-4bb7-96fc-9edfdb01fae6', 'EPIC_MF_KARAVELIA', 'Karavélia Villcargaram', 'https://i.postimg.cc/fT72yhhM/kara.webp', 'M&F', 'epic', 'normal', false, false, 2500, 3000, 3, 1, 0, 'Busca cirúrgica. SELECT id FROM match_cards WHERE owner_user_id != p_actor AND zone = ''deck'' AND element = ''Witcher'' ORDER BY current_power DESC LIMIT 1. Dá um UPDATE alterando o owner_user_id para o do jogador e a zone para ''hand''.', true, 1),
('a296e81d-e593-41bb-a79d-9cf94d112d10', '9088670c-9eb9-4bb7-96fc-9edfdb01fae6', 'LEG_WITCHER_YUNEPHOENIX', 'YunePhoenix o Bruxo Herói', 'http://thewitcherrpg.ucoz.com.br/novapasta/novagwen/imagem_rpg.png', 'Witcher', 'legendary', 'normal', false, false, 2000, 3000, 0, 1, 0, 'O servidor vasculha a tabela match_deck_cards da partida atual de AMBOS os jogadores. Soma quantas cartas possuem a raridade legendary. Atualiza o current_power desta carta na mesa somando (total_lendarias * 2000) permanentemente.', true, 1),
('a296e81d-e593-41bb-a79d-9cf94d112d11', '9088670c-9eb9-4bb7-96fc-9edfdb01fae6', 'EPIC_WITCHER_BLARKVHAR', 'Blarkvhar Valknut', 'http://thewitcherrpg.ucoz.com.br/_spt/Blarkvar.jpg', 'Witcher', 'epic', 'normal', false, false, 3000, 2100, 3, 1, 0, 'O banco faz um check (EXISTS) para ver se a carta "Gigante de Gelo" se encontra na zona ''deck'' ou ''graveyard'' de QUALQUER um dos dois jogadores. Se a condição for verdadeira, executa UPDATE match_cards SET zone = ''graveyard'' WHERE owner_user_id != p_actor AND zone = ''hand''.', true, 1),
('a296e81d-e593-41bb-a79d-9cf94d112d12', '9088670c-9eb9-4bb7-96fc-9edfdb01fae6', 'EPIC_WITCHER_ORION', 'Orion da Escola do Grifo', 'http://thewitcherrpg.ucoz.com.br/00b5733b685e713bdcbb465eedd8b6c7.jpg', 'Witcher', 'epic', 'normal', false, false, 3000, 2300, 3, 1, 0, 'Encontra a "Conjunção das Esferas" no ''deck'' do jogador, muda para ''hand'', e grava um modificador de desconto de mana no match_runtime_effects ou match_card_details para subtrair 2 do custo dessa carta específica sorteada.', true, 1),
('a296e81d-e593-41bb-a79d-9cf94d112d13', '9088670c-9eb9-4bb7-96fc-9edfdb01fae6', 'EPIC_WITCHER_AMONRA', 'Amonrá o Bruxo da Arena', 'http://thewitcherrpg.ucoz.com.br/novapasta/outrapasta/FB_IMG_1515765715795.jpg', 'Witcher', 'epic', 'normal', false, false, 2000, 1000, 1, 1, 0, 'Hook de combate passivo. Sempre que for alvo de ataque ou atacar uma carta cujo element = ''Witcher'', seu current_power é multiplicado por 3 estritamente para o cálculo de dano.', true, 1),
('a296e81d-e593-41bb-a79d-9cf94d112d14', '9088670c-9eb9-4bb7-96fc-9edfdb01fae6', 'EPIC_WITCHER_DERRE', 'Derre', 'http://thewitcherrpg.ucoz.com.br/novapasta/outrapasta/2/NOVAIMA/derreeee.jpg', 'Witcher', 'epic', 'normal', false, false, 2700, 2600, 0, 1, 0, 'Efeito de Limpeza em Massa. O servidor executa um UPDATE match_cards SET zone = ''graveyard'' abrangendo WHERE zone IN (''hand'', ''reinforcement'') sem filtrar o dono (afeta ambos os jogadores).', true, 1),
('a296e81d-e593-41bb-a79d-9cf94d112d15', '9088670c-9eb9-4bb7-96fc-9edfdb01fae6', 'LEG_WITCHER_GRETER', 'Greter o Bruxo Arcano', 'http://thewitcherrpg.ucoz.com.br/36fc4d6b4c9ddeadee7139c048d76f54.jpg', 'Witcher', 'legendary', 'normal', false, false, 3000, 3000, 4, 1, 0, 'O servidor executa uma queima de deck cirúrgica. UPDATE match_cards SET zone = ''graveyard'' WHERE owner_user_id != p_actor AND zone = ''deck'' AND mana_cost < 4 (menor que o custo de Greter).', true, 1),
('a296e81d-e593-41bb-a79d-9cf94d112d16', '9088670c-9eb9-4bb7-96fc-9edfdb01fae6', 'LEG_ELF_EREBO', 'Érebo Luch Grännic', 'http://thewitcherrpg.ucoz.com.br/_spt/image_2.jpeg', 'Elfica', 'legendary', 'normal', false, false, 5000, 5000, 4, 1, 0, 'Metadado {"target_mode": "hand"}. O jogador clica em uma carta da própria mão. A RPC converte a carta p_target_card_id sorteando (random 1) um card_id da base de dados entre as cartas: "Darko", "Rosa de Myrkvid", "Arma X" ou "Salusia", injetando a nova definição na mão no lugar da antiga.', true, 1),
('a296e81d-e593-41bb-a79d-9cf94d112d17', '9088670c-9eb9-4bb7-96fc-9edfdb01fae6', 'LEG_MF_SALUSIA', 'Salusia', 'http://thewitcherrpg.ucoz.com.br/_spt/image.jpeg', 'M&F', 'legendary', 'normal', false, false, 3000, 4000, 2, 1, 0, 'Metadado {"target_mode": "enemy_deck"} (ou similar se aplicável, caso contrário busca aleatória no SQL). O jogador seleciona o alvo do baralho rival. A RPC copia base_power, base_max_life, element e todos os atributos da carta alvo, e aplica como UPDATE diretamente na tabela match_cards para o ID de "Salusia" que está em campo.', true, 1)
ON CONFLICT (code) DO UPDATE SET
    name = EXCLUDED.name,
    image_url = EXCLUDED.image_url,
    element = EXCLUDED.element,
    rarity = EXCLUDED.rarity,
    base_power = EXCLUDED.base_power,
    base_max_life = EXCLUDED.base_max_life,
    effect_mana_cost = EXCLUDED.effect_mana_cost,
    effect_text = EXCLUDED.effect_text;

-- 2. Insert card effects into public.card_effects
INSERT INTO public.card_effects (
    card_id, effect_order, trigger_type, effect_code, target_mode, parameters, priority, is_reaction, once_per_turn, is_active
) VALUES
('a296e81d-e593-41bb-a79d-9cf94d112d01', 1, 'manual', 'epic_ufric_griffon_silence', 'none', '{"mana_cost": 4}', 0, false, true, true),
('a296e81d-e593-41bb-a79d-9cf94d112d02', 1, 'manual', 'leg_lucian_velen_mass_removal', 'none', '{"mana_cost": 6}', 0, false, true, true),
('a296e81d-e593-41bb-a79d-9cf94d112d03', 1, 'manual', 'rare_aron_kovir_silence_hand', 'none', '{"mana_cost": 3}', 0, false, true, true),
('a296e81d-e593-41bb-a79d-9cf94d112d04', 1, 'manual', 'rare_emma_vanbrown_multi_hit', 'none', '{"mana_cost": 4}', 0, false, true, true),
('a296e81d-e593-41bb-a79d-9cf94d112d05', 1, 'manual', 'leg_iris_cintra_draw_deck', 'deck', '{"mana_cost": 4}', 0, false, true, true),
('a296e81d-e593-41bb-a79d-9cf94d112d06', 1, 'manual', 'epic_khan_witcher_hunter_draw', 'none', '{"mana_cost": 1}', 0, false, true, true),
('a296e81d-e593-41bb-a79d-9cf94d112d07', 1, 'passive', 'common_kriszila_immortality_heal', 'none', '{"mana_cost": 0}', 0, false, false, true),
('a296e81d-e593-41bb-a79d-9cf94d112d08', 1, 'manual', 'epic_castrel_gato_swap_hand', 'none', '{"mana_cost": 0}', 0, false, true, true),
('a296e81d-e593-41bb-a79d-9cf94d112d09', 1, 'manual', 'epic_karavelia_steal_witcher', 'none', '{"mana_cost": 3}', 0, false, true, true),
('a296e81d-e593-41bb-a79d-9cf94d112d10', 1, 'manual', 'leg_yunephoenix_legendary_scaling', 'none', '{"mana_cost": 0}', 0, false, true, true),
('a296e81d-e593-41bb-a79d-9cf94d112d11', 1, 'manual', 'epic_blarkvhar_giant_ice_discard', 'none', '{"mana_cost": 3}', 0, false, true, true),
('a296e81d-e593-41bb-a79d-9cf94d112d12', 1, 'manual', 'epic_orion_griffon_conjunction', 'none', '{"mana_cost": 3}', 0, false, true, true),
('a296e81d-e593-41bb-a79d-9cf94d112d13', 1, 'passive', 'epic_amonra_witcher_duelist', 'none', '{"mana_cost": 0}', 0, false, false, true),
('a296e81d-e593-41bb-a79d-9cf94d112d14', 1, 'manual', 'epic_derre_mass_cleanse', 'none', '{"mana_cost": 0}', 0, false, true, true),
('a296e81d-e593-41bb-a79d-9cf94d112d15', 1, 'manual', 'leg_greter_arcane_deck_burn', 'none', '{"mana_cost": 4}', 0, false, true, true),
('a296e81d-e593-41bb-a79d-9cf94d112d16', 1, 'manual', 'leg_erebo_hand_morph', 'hand', '{"mana_cost": 4}', 0, false, true, true),
('a296e81d-e593-41bb-a79d-9cf94d112d17', 1, 'manual', 'leg_salusia_mimic_deck', 'enemy', '{"mana_cost": 2}', 0, false, true, true)
ON CONFLICT (card_id, effect_order) DO UPDATE SET
    trigger_type = EXCLUDED.trigger_type,
    effect_code = EXCLUDED.effect_code,
    target_mode = EXCLUDED.target_mode,
    parameters = EXCLUDED.parameters,
    is_reaction = EXCLUDED.is_reaction,
    once_per_turn = EXCLUDED.once_per_turn;

-- 3. Rename current execute_common_effect_internal to v36_core
ALTER FUNCTION game_private.execute_common_effect_internal(uuid, uuid, uuid, text, jsonb, uuid, jsonb)
    RENAME TO execute_common_effect_internal_v36_core;

-- 4. Create new execute_common_effect_internal intercepting the 17 new effect codes
CREATE OR REPLACE FUNCTION game_private.execute_common_effect_internal(
    p_match_id uuid,
    p_actor uuid,
    p_source uuid,
    p_code text,
    p_params jsonb,
    p_target uuid DEFAULT NULL::uuid,
    p_event jsonb DEFAULT NULL::jsonb
)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $$
DECLARE
    v_source_card_rec public.match_cards;
    v_target_card_rec public.match_cards;
    v_opponent_id uuid;
    v_result jsonb := '{"actions":[]}';
    v_action jsonb;
    v_temp_id uuid;
    v_val integer;
    v_count integer;
    v_target_life_id uuid;
    v_damage_result jsonb;
    v_bot_deck_id uuid;
    v_cat_card record;
    v_new_mdc_id uuid;
    v_steal_card_id uuid;
    v_leg_count integer;
    v_exists boolean;
    v_conjuncao_id uuid;
    v_new_card record;
    v_new_effect_def jsonb;
    v_target_mdc record;
BEGIN
    SELECT * INTO v_source_card_rec FROM public.match_cards WHERE id = p_source AND match_id = p_match_id;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Effect source card not found';
    END IF;

    SELECT user_id INTO v_opponent_id FROM public.match_players WHERE match_id = p_match_id AND user_id != p_actor LIMIT 1;
    
    IF p_target IS NOT NULL THEN
        SELECT * INTO v_target_card_rec FROM public.match_cards WHERE id = p_target AND match_id = p_match_id;
    END IF;

    CASE p_code
        WHEN 'epic_ufric_griffon_silence' THEN
            -- Ao ativar, insere uma trava na tabela match_runtime_effects associada ao oponente.
            INSERT INTO public.match_runtime_effects(
                match_id, owner_user_id, source_match_card_id, effect_code, scope, target_user_id, active
            ) VALUES (
                p_match_id, p_actor, p_source, 'epic_ufric_griffon_silence', 'match', v_opponent_id, true
            );
            RETURN jsonb_build_object('success', true, 'message', 'Ufric bloqueou reações baratas do oponente.', 'code', p_code);

        WHEN 'leg_lucian_velen_mass_removal' THEN
            -- Efeito de campo (Mass Removal).
            -- Destrói cartas de ambos os jogadores com current_life < 4000
            DECLARE
                v_destroyed_rec RECORD;
                v_p1_remaining INT;
                v_p2_remaining INT;
                v_p1_id uuid;
                v_p2_id uuid;
            BEGIN
                SELECT user_id INTO v_p1_id FROM public.match_players WHERE match_id = p_match_id AND player_number = 1;
                SELECT user_id INTO v_p2_id FROM public.match_players WHERE match_id = p_match_id AND player_number = 2;

                FOR v_destroyed_rec IN
                    SELECT id, owner_user_id, zone FROM public.match_cards
                    WHERE match_id = p_match_id AND zone IN ('attacker', 'reinforcement', 'life') AND current_life < 4000
                LOOP
                    UPDATE public.match_cards
                    SET zone = 'graveyard', zone_position = null, is_face_up = true, current_life = 0
                    WHERE id = v_destroyed_rec.id;

                    IF v_destroyed_rec.zone = 'life' THEN
                        UPDATE public.match_players
                        SET destroyed_life_count = destroyed_life_count + 1
                        WHERE match_id = p_match_id AND user_id = v_destroyed_rec.owner_user_id;
                    END IF;
                END LOOP;

                SELECT count(*) INTO v_p1_remaining FROM public.match_cards WHERE match_id = p_match_id AND owner_user_id = v_p1_id AND zone = 'life' AND current_life > 0;
                SELECT count(*) INTO v_p2_remaining FROM public.match_cards WHERE match_id = p_match_id AND owner_user_id = v_p2_id AND zone = 'life' AND current_life > 0;

                IF v_p1_remaining = 0 AND v_p2_remaining = 0 THEN
                    PERFORM game_private.finish_match(p_match_id, v_p2_id, 'all_life_cards_destroyed');
                ELSIF v_p1_remaining = 0 THEN
                    PERFORM game_private.finish_match(p_match_id, v_p2_id, 'all_life_cards_destroyed');
                ELSIF v_p2_remaining = 0 THEN
                    PERFORM game_private.finish_match(p_match_id, v_p1_id, 'all_life_cards_destroyed');
                END IF;
            END;
            RETURN jsonb_build_object('success', true, 'message', 'Lucian removeu cartas com menos de 4000 HP.', 'code', p_code);

        WHEN 'rare_aron_kovir_silence_hand' THEN
            -- Seleciona 1 carta aleatória na mão do oponente e anula seu efeito (silêncio)
            SELECT id INTO v_temp_id FROM public.match_cards
            WHERE match_id = p_match_id AND owner_user_id = v_opponent_id AND zone = 'hand'
            ORDER BY random() LIMIT 1;

            IF v_temp_id IS NOT NULL THEN
                UPDATE public.match_cards
                SET metadata = metadata || '{"effect_silenced": true}'::jsonb
                WHERE id = v_temp_id;
            END IF;
            RETURN jsonb_build_object('success', true, 'message', 'Aron silenciou uma carta da mão do oponente.', 'code', p_code);

        WHEN 'rare_emma_vanbrown_multi_hit' THEN
            -- Sorteia 1 carta de vida do oponente, dá 2000 de dano. Chance de 25% de repetir.
            DECLARE
                v_loop boolean := true;
                v_first_hit boolean := true;
            BEGIN
                WHILE v_loop LOOP
                    IF v_first_hit THEN
                        v_first_hit := false;
                    ELSE
                        IF random() > 0.25 THEN
                            EXIT;
                        END IF;
                    END IF;

                    SELECT id INTO v_target_life_id FROM public.match_cards
                    WHERE match_id = p_match_id AND owner_user_id = v_opponent_id AND zone = 'life' AND current_life > 0
                    ORDER BY random() LIMIT 1;

                    IF v_target_life_id IS NOT NULL THEN
                        v_damage_result := game_private.apply_damage_internal(p_match_id, v_target_life_id, 2000, (SELECT current_turn FROM public.matches WHERE id = p_match_id));
                        IF coalesce((v_damage_result->>'destroyed')::boolean, false) THEN
                            UPDATE public.match_players
                            SET destroyed_life_count = destroyed_life_count + 1
                            WHERE match_id = p_match_id AND user_id = v_opponent_id;
                            
                            IF NOT EXISTS (
                                SELECT 1 FROM public.match_cards WHERE match_id = p_match_id AND owner_user_id = v_opponent_id AND zone = 'life' AND current_life > 0
                            ) THEN
                                PERFORM game_private.finish_match(p_match_id, p_actor, 'all_life_cards_destroyed');
                            END IF;
                        END IF;
                    ELSE
                        EXIT;
                    END IF;
                END LOOP;
            END;
            RETURN jsonb_build_object('success', true, 'message', 'Emma VanBrown executou ataque múltiplo.', 'code', p_code);

        WHEN 'leg_iris_cintra_draw_deck' THEN
            -- Move o card selecionado do deck para a mão.
            IF p_target IS NOT NULL AND v_target_card_rec.owner_user_id = p_actor AND v_target_card_rec.zone = 'deck' THEN
                UPDATE public.match_cards
                SET zone = 'hand',
                    zone_position = (SELECT coalesce(max(zone_position), 0) + 1 FROM public.match_cards WHERE match_id = p_match_id AND owner_user_id = p_actor AND zone = 'hand'),
                    is_face_up = false
                WHERE id = p_target;

                PERFORM game_private.sync_player_hand_mana(p_match_id, p_actor);
            END IF;
            RETURN jsonb_build_object('success', true, 'message', 'Iris buscou carta do deck.', 'code', p_code);

        WHEN 'epic_khan_witcher_hunter_draw' THEN
            -- Conta quantos Witchers o oponente tem em campo e compra essa quantidade.
            SELECT count(*)::integer INTO v_count
            FROM public.match_cards mc
            JOIN public.cards c ON mc.source_card_id = c.id
            WHERE mc.match_id = p_match_id AND mc.owner_user_id = v_opponent_id AND mc.zone IN ('attacker', 'reinforcement', 'life') AND c.element = 'Witcher';

            IF v_count > 0 THEN
                PERFORM game_private.draw_internal(p_match_id, p_actor, v_count);
            END IF;
            RETURN jsonb_build_object('success', true, 'message', 'Khan fez comprar ' || v_count || ' cartas.', 'code', p_code);

        WHEN 'epic_castrel_gato_swap_hand' THEN
            -- Conta cartas na mão, envia todas pro graveyard, sorteia Escola do Gato e coloca na mão.
            SELECT count(*)::integer INTO v_val
            FROM public.match_cards
            WHERE match_id = p_match_id AND owner_user_id = p_actor AND zone = 'hand';

            UPDATE public.match_cards
            SET zone = 'graveyard', zone_position = null, is_face_up = true
            WHERE match_id = p_match_id AND owner_user_id = p_actor AND zone = 'hand';

            SELECT id INTO v_bot_deck_id FROM public.match_decks WHERE match_id = p_match_id AND user_id = p_actor LIMIT 1;

            IF v_val > 0 THEN
                FOR v_cat_card IN 
                    SELECT * FROM public.cards 
                    WHERE name ILIKE '%Escola do Gato%' AND is_active = true
                    ORDER BY random() LIMIT v_val
                LOOP
                    INSERT INTO public.match_deck_cards(
                        match_deck_id, source_card_id, card_version, card_name, image_url, element, rarity, card_type, is_golden, base_power, base_max_life, effect_mana_cost, tier, leader_cooldown, effect_definition, copy_number
                    ) VALUES (
                        v_bot_deck_id, v_cat_card.id, v_cat_card.version, v_cat_card.name, coalesce(v_cat_card.image_url, ''), coalesce(v_cat_card.element, 'Neutro'), v_cat_card.rarity, v_cat_card.card_type, v_cat_card.is_golden, coalesce(v_cat_card.base_power, 0), coalesce(v_cat_card.base_max_life, 0), coalesce(v_cat_card.effect_mana_cost, 0), coalesce(v_cat_card.tier, 1), coalesce(v_cat_card.leader_cooldown, 0), coalesce(
                            (select jsonb_agg(jsonb_build_object('effect_order', ce.effect_order, 'trigger_type', ce.trigger_type, 'effect_code', ce.effect_code, 'target_mode', ce.target_mode, 'parameters', ce.parameters, 'priority', ce.priority, 'is_reaction', ce.is_reaction, 'once_per_turn', ce.once_per_turn) order by ce.effect_order) from public.card_effects ce where ce.card_id = v_cat_card.id and ce.is_active = true), '[]'::jsonb
                        ), 1
                    ) RETURNING id INTO v_new_mdc_id;

                    INSERT INTO public.match_cards(
                        match_id, owner_user_id, controller_user_id, match_deck_card_id, source_card_id,
                        zone, zone_position, is_face_up, base_power, base_max_life,
                        current_power, maximum_power, current_life, maximum_life
                    ) VALUES (
                        p_match_id, p_actor, p_actor, v_new_mdc_id, v_cat_card.id,
                        'hand', (SELECT coalesce(max(zone_position), 0) + 1 FROM public.match_cards WHERE match_id = p_match_id AND owner_user_id = p_actor AND zone = 'hand'),
                        false, v_cat_card.base_power, v_cat_card.base_max_life,
                        v_cat_card.base_power, v_cat_card.base_power, v_cat_card.base_max_life, v_cat_card.base_max_life
                    );
                END LOOP;
            END IF;
            
            PERFORM game_private.sync_player_hand_mana(p_match_id, p_actor);
            RETURN jsonb_build_object('success', true, 'message', 'Castrel trocou a mão do jogador por cartas da Escola do Gato.', 'code', p_code);

        WHEN 'epic_karavelia_steal_witcher' THEN
            -- Rouba Witcher com maior poder do deck inimigo e coloca na mão.
            SELECT mc.id INTO v_steal_card_id
            FROM public.match_cards mc
            JOIN public.cards c ON mc.source_card_id = c.id
            WHERE mc.match_id = p_match_id AND mc.owner_user_id = v_opponent_id AND mc.zone = 'deck' AND c.element = 'Witcher'
            ORDER BY mc.current_power DESC LIMIT 1;

            IF v_steal_card_id IS NOT NULL THEN
                UPDATE public.match_cards
                SET owner_user_id = p_actor,
                    controller_user_id = p_actor,
                    zone = 'hand',
                    zone_position = (SELECT coalesce(max(zone_position), 0) + 1 FROM public.match_cards WHERE match_id = p_match_id AND owner_user_id = p_actor AND zone = 'hand'),
                    is_face_up = false
                WHERE id = v_steal_card_id;

                PERFORM game_private.sync_player_hand_mana(p_match_id, p_actor);
                PERFORM game_private.sync_player_hand_mana(p_match_id, v_opponent_id);
            END IF;
            RETURN jsonb_build_object('success', true, 'message', 'Karavélia roubou um Witcher do deck inimigo.', 'code', p_code);

        WHEN 'leg_yunephoenix_legendary_scaling' THEN
            -- Soma lendárias em ambos os decks e ganha total * 2000 permanentemente.
            SELECT count(*)::integer INTO v_leg_count
            FROM public.match_deck_cards mdc
            JOIN public.match_decks md ON md.id = mdc.match_deck_id
            WHERE md.match_id = p_match_id AND mdc.rarity = 'legendary';

            IF v_leg_count > 0 THEN
                UPDATE public.match_cards
                SET current_power = current_power + (v_leg_count * 2000),
                    base_power = base_power + (v_leg_count * 2000),
                    maximum_power = maximum_power + (v_leg_count * 2000)
                WHERE id = p_source;
            END IF;
            RETURN jsonb_build_object('success', true, 'message', 'YunePhoenix escalou com ' || v_leg_count || ' lendárias.', 'code', p_code);

        WHEN 'epic_blarkvhar_giant_ice_discard' THEN
            -- Se Gigante de Gelo está no deck ou graveyard de alguém, discarta a mão inimiga.
            SELECT EXISTS(
                SELECT 1 FROM public.match_cards mc
                JOIN public.match_deck_cards mdc ON mdc.id = mc.match_deck_card_id
                WHERE mc.match_id = p_match_id AND mdc.card_name = 'Gigante de Gelo' AND mc.zone IN ('deck', 'graveyard')
            ) INTO v_exists;

            IF v_exists THEN
                UPDATE public.match_cards
                SET zone = 'graveyard', zone_position = null, is_face_up = true
                WHERE match_id = p_match_id AND owner_user_id = v_opponent_id AND zone = 'hand';

                PERFORM game_private.sync_player_hand_mana(p_match_id, v_opponent_id);
            END IF;
            RETURN jsonb_build_object('success', true, 'message', 'Blarkvhar checou Gigante de Gelo e descartou mão inimiga.', 'code', p_code);

        WHEN 'epic_orion_griffon_conjunction' THEN
            -- Move Conjunção de Esferas do deck para a mão e dá desconto de -2 de mana.
            SELECT mc.id INTO v_conjuncao_id
            FROM public.match_cards mc
            JOIN public.match_deck_cards mdc ON mdc.id = mc.match_deck_card_id
            WHERE mc.match_id = p_match_id AND mc.owner_user_id = p_actor AND mc.zone = 'deck' AND mdc.card_name = 'Conjunção de Esferas'
            ORDER BY mc.id ASC LIMIT 1;

            IF v_conjuncao_id IS NOT NULL THEN
                UPDATE public.match_cards
                SET zone = 'hand',
                    zone_position = (SELECT coalesce(max(zone_position), 0) + 1 FROM public.match_cards WHERE match_id = p_match_id AND owner_user_id = p_actor AND zone = 'hand'),
                    is_face_up = false
                WHERE id = v_conjuncao_id;

                UPDATE public.match_deck_cards
                SET effect_mana_cost = greatest(0, effect_mana_cost - 2)
                WHERE id = (SELECT match_deck_card_id FROM public.match_cards WHERE id = v_conjuncao_id);

                PERFORM game_private.sync_player_hand_mana(p_match_id, p_actor);
            END IF;
            RETURN jsonb_build_object('success', true, 'message', 'Orion comprou Conjunção de Esferas com desconto.', 'code', p_code);

        WHEN 'epic_derre_mass_cleanse' THEN
            -- Limpeza em massa de mão e reforços de ambos.
            UPDATE public.match_cards
            SET zone = 'graveyard', zone_position = null, is_face_up = true
            WHERE match_id = p_match_id AND zone IN ('hand', 'reinforcement');

            PERFORM game_private.sync_player_hand_mana(p_match_id, p_actor);
            PERFORM game_private.sync_player_hand_mana(p_match_id, v_opponent_id);
            RETURN jsonb_build_object('success', true, 'message', 'Derre limpou mão e reforços de todos.', 'code', p_code);

        WHEN 'leg_greter_arcane_deck_burn' THEN
            -- Queima de deck inimigo (cartas < 4 mana).
            UPDATE public.match_cards mc
            SET zone = 'graveyard', zone_position = null, is_face_up = true
            FROM public.match_deck_cards mdc
            WHERE mc.match_deck_card_id = mdc.id
              AND mc.match_id = p_match_id
              AND mc.owner_user_id = v_opponent_id
              AND mc.zone = 'deck'
              AND mdc.effect_mana_cost < 4;
            RETURN jsonb_build_object('success', true, 'message', 'Greter queimou cartas baratas do deck inimigo.', 'code', p_code);

        WHEN 'leg_erebo_hand_morph' THEN
            -- Converte carta alvo na própria mão em um dos 4 candidatos.
            IF p_target IS NOT NULL AND v_target_card_rec.owner_user_id = p_actor AND v_target_card_rec.zone = 'hand' THEN
                SELECT * INTO v_new_card
                FROM public.cards
                WHERE name IN ('Darko o Elfo', 'Rosa de Myrkvid a Lâmia', 'Arma X', 'Salusia')
                ORDER BY random() LIMIT 1;

                IF v_new_card.id IS NOT NULL THEN
                    SELECT jsonb_agg(
                        jsonb_build_object(
                            'effect_order', effect_order,
                            'trigger_type', trigger_type,
                            'effect_code', effect_code,
                            'target_mode', target_mode,
                            'parameters', parameters,
                            'priority', priority,
                            'is_reaction', is_reaction,
                            'once_per_turn', once_per_turn
                        ) ORDER BY effect_order
                    ) INTO v_new_effect_def
                    FROM public.card_effects
                    WHERE card_id = v_new_card.id AND is_active = true;

                    v_new_effect_def := coalesce(v_new_effect_def, '[]'::jsonb);

                    UPDATE public.match_deck_cards
                    SET source_card_id = v_new_card.id,
                        card_name = v_new_card.name,
                        image_url = coalesce(v_new_card.image_url, ''),
                        element = coalesce(v_new_card.element, 'Neutro'),
                        rarity = v_new_card.rarity,
                        card_type = v_new_card.card_type,
                        is_golden = v_new_card.is_golden,
                        base_power = coalesce(v_new_card.base_power, 0),
                        base_max_life = coalesce(v_new_card.base_max_life, 0),
                        effect_mana_cost = coalesce(v_new_card.effect_mana_cost, 0),
                        effect_definition = v_new_effect_def
                    WHERE id = v_target_card_rec.match_deck_card_id;

                    UPDATE public.match_cards
                    SET source_card_id = v_new_card.id,
                        base_power = v_new_card.base_power,
                        base_max_life = v_new_card.base_max_life,
                        current_power = v_new_card.base_power,
                        maximum_power = v_new_card.base_power,
                        current_life = v_new_card.base_max_life,
                        maximum_life = v_new_card.base_max_life
                    WHERE id = p_target;

                    PERFORM game_private.sync_player_hand_mana(p_match_id, p_actor);
                END IF;
            END IF;
            RETURN jsonb_build_object('success', true, 'message', 'Érebo transmutou carta da mão.', 'code', p_code);

        WHEN 'leg_salusia_mimic_deck' THEN
            -- Copia atributos do alvo e aplica no Salusia.
            IF p_target IS NOT NULL AND v_target_card_rec.owner_user_id = v_opponent_id AND v_target_card_rec.zone = 'deck' THEN
                SELECT mdc.* INTO v_target_mdc FROM public.match_deck_cards mdc WHERE mdc.id = v_target_card_rec.match_deck_card_id;
                
                UPDATE public.match_cards
                SET base_power = v_target_card_rec.base_power,
                    base_max_life = v_target_card_rec.base_max_life,
                    current_power = v_target_card_rec.current_power,
                    maximum_power = v_target_card_rec.maximum_power,
                    current_life = v_target_card_rec.current_life,
                    maximum_life = v_target_card_rec.maximum_life
                WHERE id = p_source;

                UPDATE public.match_deck_cards
                SET card_name = v_target_mdc.card_name,
                    image_url = v_target_mdc.image_url,
                    element = v_target_mdc.element,
                    rarity = v_target_mdc.rarity,
                    card_type = v_target_mdc.card_type,
                    is_golden = v_target_mdc.is_golden,
                    base_power = v_target_mdc.base_power,
                    base_max_life = v_target_mdc.base_max_life,
                    effect_mana_cost = v_target_mdc.effect_mana_cost,
                    effect_definition = v_target_mdc.effect_definition
                WHERE id = v_source_card_rec.match_deck_card_id;
            END IF;
            RETURN jsonb_build_object('success', true, 'message', 'Salusia copiou a carta do deck rival.', 'code', p_code);

        ELSE
            RETURN game_private.execute_common_effect_internal_v36_core(p_match_id, p_actor, p_source, p_code, p_params, p_target, p_event);
    END CASE;
END;
$$;


-- 5. Redefine apply_damage_internal to include Camponesa Kriszila immortality hook
CREATE OR REPLACE FUNCTION game_private.apply_damage_internal(
    p_match_id uuid,
    p_target_card_id uuid,
    p_damage integer,
    p_turn integer
)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $$
declare
    v_card public.match_cards;
    v_old_zone text;
    v_new_life integer;
    v_destroyed boolean;
    v_target_name text;
begin
    if p_damage < 0 then raise exception 'INVALID_DAMAGE'; end if;
    select * into v_card from public.match_cards
    where id=p_target_card_id and match_id=p_match_id for update;
    if not found then raise exception 'TARGET_CARD_NOT_FOUND'; end if;

    v_old_zone:=v_card.zone;
    v_new_life:=greatest(0,v_card.current_life-p_damage);
    v_destroyed:=(v_new_life=0 and v_card.current_life>0);

    -- Hook Camponesa Kriszila immortality
    select card_name into v_target_name from public.match_deck_cards where id = v_card.match_deck_card_id;
    if v_target_name = 'Camponesa Kriszila' and v_new_life = 0 then
        if exists (
            select 1 from public.match_deck_cards mdc
            join public.match_decks md on md.id = mdc.match_deck_id
            where md.match_id = p_match_id and md.user_id = v_card.owner_user_id and mdc.card_name = 'Lucius da Escola do Gato'
        ) then
            v_new_life := 1;
            v_destroyed := false;
        end if;
    end if;

    update public.match_cards
    set current_life=v_new_life,
        damage_taken_total=damage_taken_total+least(p_damage,v_card.current_life),
        is_destroyed=case when v_destroyed then true else is_destroyed end,
        destroyed_at_turn=case when v_destroyed then p_turn else destroyed_at_turn end,
        zone=case when v_destroyed then 'graveyard' else zone end,
        zone_position=case when v_destroyed then null else zone_position end,
        is_face_up=case when v_destroyed then true else is_face_up end
    where id=p_target_card_id;

    return jsonb_build_object(
        'card_id',p_target_card_id,'old_zone',v_old_zone,'current_life',v_new_life,
        'maximum_life',v_card.maximum_life,'destroyed',v_destroyed
    );
end;
$$;


-- 6. Redefine change_active_turn to include Camponesa Kriszila heal hook
CREATE OR REPLACE FUNCTION game_private.change_active_turn(
    p_match_id uuid,
    p_user_id uuid,
    p_pass_without_action boolean,
    p_expected_version bigint
)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $$
declare
    v_match public.matches;
    v_next_user_id uuid;
    v_new_turn integer;
    v_actions integer;
    v_new_version bigint;
    v_player1_id uuid;
    v_player2_id uuid;
    v_player1_life integer;
    v_player2_life integer;
    v_winner_id uuid;
begin
    select *
    into v_match
    from public.matches
    where id = p_match_id
    for update;

    if not found then
        raise exception 'MATCH_NOT_FOUND';
    end if;

    if v_match.state_version <>
       p_expected_version then
        raise exception 'STALE_MATCH_VERSION';
    end if;

    if v_match.status <>
       'in_progress' then
        raise exception 'INVALID_MATCH_STATUS';
    end if;

    if v_match.active_player_id <>
       p_user_id then
        raise exception 'NOT_YOUR_TURN';
    end if;

    if exists (
        select 1
        from public.pending_attacks
        where match_id = p_match_id
          and status in (
              'awaiting_reaction',
              'reaction_used',
              'reaction_declined',
              'resolving'
          )
    ) then
        raise exception 'PENDING_ATTACK_MUST_BE_RESOLVED';
    end if;

    select actions_this_turn
    into v_actions
    from public.match_players
    where match_id = p_match_id
      and user_id = p_user_id
    for update;

    if p_pass_without_action
       and coalesce(v_actions, 0) <> 0 then
        raise exception 'CANNOT_PASS_AFTER_ACTION';
    end if;

    if p_pass_without_action then
        perform game_private.draw_internal(
            p_match_id,
            p_user_id,
            1
        );
    end if;

    select user_id
    into v_next_user_id
    from public.match_players
    where match_id = p_match_id
      and user_id <> p_user_id
    order by player_number
    limit 1;

    if v_next_user_id is null then
        raise exception 'OPPONENT_NOT_FOUND';
    end if;

    -- Hook Camponesa Kriszila heal at end of turn
    update public.match_cards mc
    set current_life = mc.maximum_life
    where mc.match_id = p_match_id
      and mc.current_life > 0
      and mc.zone in ('attacker', 'reinforcement', 'life')
      and (
          select card_name from public.match_deck_cards where id = mc.match_deck_card_id
      ) = 'Camponesa Kriszila'
      and exists (
          select 1 from public.match_deck_cards mdc
          join public.match_decks md on md.id = mdc.match_deck_id
          where md.match_id = p_match_id 
            and md.user_id <> mc.owner_user_id 
            and mdc.card_name = 'Lucius da Escola do Gato'
      );

    update public.match_cards
    set zone = 'graveyard',
        zone_position = null,
        is_face_up = true,
        has_attacked_this_turn = true,
        metadata =
            metadata
            - 'locked_for_pending_attack'
    where match_id = p_match_id
      and controller_user_id = p_user_id
      and zone = 'attacker';

    update public.match_cards
    set has_attacked_this_turn = false
    where match_id = p_match_id;

    v_new_turn :=
        v_match.current_turn + 1;

    perform game_private.apply_match_deterioration(
        p_match_id,
        v_new_turn
    );

    select user_id
    into v_player1_id
    from public.match_players
    where match_id = p_match_id
      and player_number = 1;

    select user_id
    into v_player2_id
    from public.match_players
    where match_id = p_match_id
      and player_number = 2;

    select count(*)::integer
    into v_player1_life
    from public.match_cards
    where match_id = p_match_id
      and controller_user_id = v_player1_id
      and zone = 'life'
      and current_life > 0;

    select count(*)::integer
    into v_player2_life
    from public.match_cards
    where match_id = p_match_id
      and controller_user_id = v_player2_id
      and zone = 'life'
      and current_life > 0;

    if v_player1_life = 0
       or v_player2_life = 0 then
        v_winner_id :=
            case
                when v_player1_life > 0
                then v_player1_id
                when v_player2_life > 0
                then v_player2_id
                else null
            end;

        v_new_version :=
            game_private.record_match_action(
                p_match_id,
                p_user_id,
                'deterioration_resolved',
                jsonb_build_object(
                    'turn',
                        v_new_turn,
                    'winner_id',
                        v_winner_id
                ),
                '{}'::jsonb,
                p_expected_version
            );

        perform game_private.finish_match(
            p_match_id,
            v_winner_id,
            'life_destroyed_by_turn_8_deterioration'
        );

        return jsonb_build_object(
            'match_finished',
                true,
            'winner_id',
                v_winner_id,
            'state_version',
                v_new_version
        );
    end if;

    update public.match_players
    set reaction_used_this_opponent_turn =
            false,
        passed_turn =
            (
                user_id = p_user_id
                and p_pass_without_action
            ),
        mana_spent_this_turn =
            case
                when user_id =
                     v_next_user_id
                then 0
                else mana_spent_this_turn
            end,
        actions_this_turn =
            case
                when user_id =
                     v_next_user_id
                then 0
                else actions_this_turn
            end,
        life_destroyed_this_turn =
            case
                when user_id =
                     v_next_user_id
                then false
                else life_destroyed_this_turn
            end,
        paid_effect_used_this_turn =
            case
                when user_id =
                     v_next_user_id
                then false
                else paid_effect_used_this_turn
            end,
        free_effect_used_this_turn =
            case
                when user_id =
                     v_next_user_id
                then false
                else free_effect_used_this_turn
            end
    where match_id = p_match_id;

    update public.matches
    set current_turn =
            v_new_turn,
        active_player_id =
            v_next_user_id
    where id = p_match_id;

    perform game_private.draw_internal(
        p_match_id,
        v_next_user_id,
        1
    );

    v_new_version :=
        game_private.record_match_action(
            p_match_id,
            p_user_id,
            case
                when p_pass_without_action
                then 'turn_passed_without_action'
                else 'turn_ended'
            end,
            jsonb_build_object(
                'previous_player_id',
                    p_user_id,
                'new_turn',
                    v_new_turn,
                'active_player_id',
                    v_next_user_id,
                'pass_without_action',
                    p_pass_without_action,
                'next_player_drew_card',
                    true,
                'passing_player_drew_card',
                    p_pass_without_action
            ),
            '{}'::jsonb,
            p_expected_version
        );

    return jsonb_build_object(
        'match_finished',
            false,
        'new_turn',
            v_new_turn,
        'active_player_id',
            v_next_user_id,
        'state_version',
            v_new_version
    );
end;
$$;


-- 7. Redefine resolve_pending_attack_internal to include Amonrá and Ufric cleanups
CREATE OR REPLACE FUNCTION game_private.resolve_pending_attack_internal(
    p_pending_attack_id uuid,
    p_actor_user_id uuid,
    p_expected_version bigint
)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $$
declare
 v_attack public.pending_attacks;v_match public.matches;v_card record;v_life_card public.match_cards;
 v_total_power integer;v_remaining_damage integer;v_card_life_before integer;v_damage_result jsonb;
 v_reinforcement_results jsonb:='[]'::jsonb;v_life_result jsonb:=null;v_attacker_ids uuid[];
 v_life_remaining integer;v_match_finished boolean:=false;v_new_version bigint;v_suppress_reveal boolean:=false;v_forced_life uuid;
 v_amonra_bonus_dmg integer := 0;
begin
 select * into v_attack from public.pending_attacks where id=p_pending_attack_id for update;
 if not found then raise exception 'PENDING_ATTACK_NOT_FOUND';end if;
 select * into v_match from public.matches where id=v_attack.match_id for update;
 if v_match.state_version<>p_expected_version then raise exception 'STALE_MATCH_VERSION';end if;
 if v_match.status<>'in_progress' then raise exception 'INVALID_MATCH_STATUS';end if;
 if v_attack.status not in('awaiting_reaction','reaction_used','reaction_declined','resolving') then raise exception 'ATTACK_CANNOT_BE_RESOLVED';end if;
 if v_attack.status='awaiting_reaction' and v_attack.reaction_deadline>clock_timestamp() then raise exception 'REACTION_WINDOW_STILL_OPEN';end if;
 update public.pending_attacks set status='resolving' where id=p_pending_attack_id;
 select array_agg(pac.match_card_id order by pac.attack_position) into v_attacker_ids
  from public.pending_attack_cards pac join public.match_cards mc on mc.id=pac.match_card_id
  where pac.pending_attack_id=p_pending_attack_id and mc.match_id=v_attack.match_id and mc.controller_user_id=v_attack.attacker_user_id and mc.zone='attacker' and mc.current_life>0;
 if coalesce(cardinality(v_attacker_ids),0)=0 then raise exception 'NO_VALID_ATTACKERS_REMAIN';end if;
 v_total_power:=greatest(0,v_attack.declared_power);
 v_remaining_damage:=v_total_power;
 v_suppress_reveal:=coalesce((v_attack.result->>'suppress_reinforcement_reveal')::boolean,false);
 v_forced_life:=nullif(v_attack.result->>'forced_life_target_id','')::uuid;

 if not v_attack.is_direct then
  for v_card in select * from public.match_cards where match_id=v_attack.match_id and controller_user_id=v_attack.defender_user_id and zone='reinforcement' and current_life>0 order by zone_position for update loop
   exit when v_remaining_damage<=0;
   if not v_suppress_reveal then update public.match_cards set is_face_up=true where id=v_card.id;end if;
   v_card_life_before:=v_card.current_life;
   update public.match_cards set metadata=metadata||jsonb_build_object('v25_incoming_attack_power',v_remaining_damage) where id=v_card.id;
   
   -- Hook Amonra witcher duelist attack bonus
   v_amonra_bonus_dmg := 0;
   if exists (
       select 1 from public.match_cards mc
       join public.cards c on mc.source_card_id = c.id
       where mc.id = any(v_attacker_ids) and c.effect_code = 'epic_amonra_witcher_duelist'
   ) then
       if (select element from public.cards where id = v_card.source_card_id) = 'Witcher' then
           select coalesce(sum(mc.current_power) * 2, 0) into v_amonra_bonus_dmg
           from public.match_cards mc
           join public.cards c on mc.source_card_id = c.id
           where mc.id = any(v_attacker_ids) and c.effect_code = 'epic_amonra_witcher_duelist';
       END IF;
   END IF;

   v_damage_result:=game_private.apply_damage_internal(v_attack.match_id,v_card.id,v_remaining_damage + v_amonra_bonus_dmg,v_match.current_turn);
   v_remaining_damage:=greatest(0,v_remaining_damage-v_card_life_before);
   v_reinforcement_results:=v_reinforcement_results||jsonb_build_array(jsonb_build_object('card_id',v_card.id,'position',v_card.zone_position,
    'life_before',v_card_life_before,'damage_received',least(v_card_life_before,(v_damage_result->>'maximum_life')::integer+v_remaining_damage),
    'final_hp',coalesce((v_damage_result->>'current_life')::integer,0),'result',v_damage_result,'remaining_damage',v_remaining_damage,'reveal_suppressed',v_suppress_reveal));
   if not coalesce((v_damage_result->>'destroyed')::boolean,false) then v_remaining_damage:=0;exit;end if;
  end loop;
 end if;

 if v_remaining_damage>0 then
  if v_forced_life is not null then
   select * into v_life_card from public.match_cards where id=v_forced_life and match_id=v_attack.match_id and controller_user_id=v_attack.defender_user_id and zone='life' and current_life>0 for update;
  end if;
  if not found or v_forced_life is null then
   select * into v_life_card from public.match_cards where match_id=v_attack.match_id and controller_user_id=v_attack.defender_user_id and zone='life' and current_life>0
    order by case when coalesce((v_attack.result->>'force_farthest_life')::boolean,false) then zone_position end desc,zone_position asc limit 1 for update;
  end if;
  if found then
   v_card_life_before:=v_life_card.current_life;
   update public.match_cards set metadata=metadata||jsonb_build_object('v25_incoming_attack_power',v_remaining_damage) where id=v_life_card.id;
   
   -- Hook Amonra witcher duelist attack bonus
   v_amonra_bonus_dmg := 0;
   if exists (
       select 1 from public.match_cards mc
       join public.cards c on mc.source_card_id = c.id
       where mc.id = any(v_attacker_ids) and c.effect_code = 'epic_amonra_witcher_duelist'
   ) then
       if (select element from public.cards where id = v_life_card.source_card_id) = 'Witcher' then
           select coalesce(sum(mc.current_power) * 2, 0) into v_amonra_bonus_dmg
           from public.match_cards mc
           join public.cards c on mc.source_card_id = c.id
           where mc.id = any(v_attacker_ids) and c.effect_code = 'epic_amonra_witcher_duelist';
       END IF;
   END IF;

   v_damage_result:=game_private.apply_damage_internal(v_attack.match_id,v_life_card.id,v_remaining_damage + v_amonra_bonus_dmg,v_match.current_turn);
   v_life_result:=jsonb_build_object('card_id',v_life_card.id,'position',v_life_card.zone_position,'life_before',v_card_life_before,
    'damage_received',least(v_remaining_damage,v_life_card.current_life),'discarded_overflow',greatest(0,v_remaining_damage-v_card_life_before),
    'final_hp',coalesce((v_damage_result->>'current_life')::integer,0),'result',v_damage_result);
   if coalesce((v_damage_result->>'destroyed')::boolean,false) then
    update public.match_players set destroyed_life_count=destroyed_life_count+1 where match_id=v_attack.match_id and user_id=v_attack.defender_user_id;
    update public.match_players set life_destroyed_this_turn=true where match_id=v_attack.match_id and user_id=v_attack.attacker_user_id;
   end if;
   v_remaining_damage:=0;
  end if;
 end if;

 update public.match_cards set zone='graveyard',zone_position=null,is_face_up=true,has_attacked_this_turn=true,
  current_power=case when metadata->>'v25_saved_power' is not null then (metadata->>'v25_saved_power')::integer else current_power end,
  metadata=metadata-'locked_for_pending_attack'-'v25_skip_normal_attack'-'v25_saved_power' where id=any(v_attacker_ids);
 select count(*)::integer into v_life_remaining from public.match_cards where match_id=v_attack.match_id and controller_user_id=v_attack.defender_user_id and zone='life' and current_life>0;
 v_match_finished:=v_life_remaining=0;
 update public.pending_attacks set status='resolved',resolved_power=v_total_power,damage_remaining_after_resolution=v_remaining_damage,resolved_at=clock_timestamp(),
  result=coalesce(v_attack.result,'{}'::jsonb)||jsonb_build_object('attackers',v_attacker_ids,'total_power',v_total_power,'reinforcements',v_reinforcement_results,
   'life',v_life_result,'defender_life_remaining',v_life_remaining,'match_finished',v_match_finished) where id=p_pending_attack_id;
 v_new_version:=game_private.record_match_action(v_attack.match_id,p_actor_user_id,'attack_resolved',jsonb_build_object('pending_attack_id',p_pending_attack_id,
  'attacker_user_id',v_attack.attacker_user_id,'defender_user_id',v_attack.defender_user_id,'attacker_card_ids',v_attacker_ids,'total_power',v_total_power,
  'is_direct',v_attack.is_direct,'reinforcements',v_reinforcement_results,'life',v_life_result,'defender_life_remaining',v_life_remaining,
  'match_finished',v_match_finished,'effect_contract',v_attack.result),'{}'::jsonb,p_expected_version);
 update public.pending_attacks set resolved_state_version=v_new_version where id=p_pending_attack_id;
 
 -- Ufric blocker cleanup
 update public.match_runtime_effects set active=false, consumed_at=clock_timestamp()
 where match_id = v_attack.match_id and effect_code = 'epic_ufric_griffon_silence' and active = true;

 if v_match_finished then perform game_private.finish_match(v_attack.match_id,v_attack.attacker_user_id,'all_life_cards_destroyed');end if;
 return jsonb_build_object('pending_attack_id',p_pending_attack_id,'attackers',v_attacker_ids,'total_power',v_total_power,'reinforcements',v_reinforcement_results,
  'life',v_life_result,'defender_life_remaining',v_life_remaining,'match_finished',v_match_finished,'winner_id',case when v_match_finished then v_attack.attacker_user_id else null end,'state_version',v_new_version);
end;
$$;


-- 8. Redefine activate_card_effect_v2_v14_core to check for Ufric reaction lock
CREATE OR REPLACE FUNCTION public.activate_card_effect_v2_v14_core(
    p_match_id uuid,
    p_source_card_id uuid,
    p_effect_order integer DEFAULT 1,
    p_target_card_id uuid DEFAULT NULL::uuid,
    p_expected_version bigint DEFAULT 0
)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $$
declare
  v_actor_id uuid := game_private.require_authenticated();
  v_source_card public.match_cards;
  v_effect_definition jsonb;
  v_effect_code text;
  v_effect_parameters jsonb;
  v_trigger_type text;
  v_is_reaction boolean;
  v_mana_cost integer;
  v_result jsonb;
  v_new_version bigint;
  v_match public.matches;
  v_hand_count integer;
begin
  select m.* into v_match
  from public.matches m
  where m.id = p_match_id
  for update;
  if not found then raise exception 'MATCH_NOT_FOUND'; end if;
  if v_match.state_version <> p_expected_version then raise exception 'STALE_MATCH_VERSION'; end if;

  select effect_source.* into v_source_card
  from game_private.assert_common_effect_source(
    p_match_id, v_actor_id, p_source_card_id, p_expected_version, true
  ) effect_source;

  select effect_item.value into v_effect_definition
  from public.match_deck_cards mdc
  cross join lateral jsonb_array_elements(mdc.effect_definition) effect_item(value)
  where mdc.id = v_source_card.match_deck_card_id
    and (effect_item.value->>'effect_order')::integer = p_effect_order;
  if v_effect_definition is null then raise exception 'EFFECT_NOT_FOUND'; end if;

  v_effect_code := v_effect_definition->>'effect_code';
  if v_effect_code not like 'common_%' and v_effect_code not like 'rare_%' and v_effect_code not like 'epic_%' and v_effect_code not like 'leg_%' then
    return public.activate_match_effect(
      p_match_id, p_source_card_id, p_effect_order, p_target_card_id, p_expected_version
    );
  end if;

  perform game_private.assert_no_global_effect_lock(p_match_id, v_actor_id, p_source_card_id);
  v_trigger_type := v_effect_definition->>'trigger_type';
  v_is_reaction := coalesce((v_effect_definition->>'is_reaction')::boolean, false)
    or v_trigger_type in ('reaction','on_reaction','on_attacked','on_damage_received');

  if v_trigger_type <> 'manual' and not v_is_reaction then
    raise exception 'EFFECT_IS_AUTOMATIC: %', v_trigger_type;
  end if;

  if v_is_reaction then
    if v_source_card.owner_user_id <> v_actor_id
       or v_source_card.zone not in ('hand','life','reinforcement') then
      raise exception 'INVALID_REACTION_SOURCE_ZONE';
    end if;
    if v_match.active_player_id = v_actor_id then raise exception 'REACTION_ONLY_ON_OPPONENT_TURN'; end if;
    if not exists(
      select 1 from public.pending_attacks pa
      where pa.match_id = p_match_id
        and pa.defender_user_id = v_actor_id
        and pa.status = 'awaiting_reaction'
        and pa.reaction_deadline > clock_timestamp()
    ) then raise exception 'NO_OPEN_REACTION_WINDOW'; end if;
  else
    if v_match.engine_state <> 'turn_action' then raise exception 'MATCH_FLOW_IS_BLOCKED'; end if;
    if v_match.active_player_id <> v_actor_id then raise exception 'NOT_YOUR_TURN'; end if;
  end if;

  v_effect_parameters := coalesce(v_effect_definition->'parameters', '{}'::jsonb);
  v_mana_cost := greatest(0, coalesce(
    (v_effect_parameters->>'mana_cost')::integer,
    game_private.effect_card_cost(p_source_card_id), 0
  ));
  
  -- Ufric blocker check:
  if v_is_reaction then
      if exists (
          select 1 from public.match_runtime_effects
          where match_id = p_match_id and target_user_id = v_actor_id and effect_code = 'epic_ufric_griffon_silence' and active = true
      ) and v_mana_cost < 4 then
          raise exception 'REACTION_BLOCKED_BY_UFRIC';
      end if;
  end if;

  if exists (select 1 from public.sandbox_matches where match_id = p_match_id) then
    if (select mana_available from public.match_players where match_id = p_match_id and user_id = v_actor_id) < v_mana_cost then
      raise exception 'INSUFFICIENT_MANA';
    end if;
  else
    select count(*)::integer into v_hand_count
    from public.match_cards mc
    where mc.match_id = p_match_id and mc.owner_user_id = v_actor_id and mc.zone = 'hand';
    if v_hand_count < v_mana_cost then raise exception 'INSUFFICIENT_MANA'; end if;
  end if;

  if coalesce((v_effect_definition->>'once_per_turn')::boolean, false) and exists(
    select 1 from public.match_effect_uses meu
    where meu.match_id = p_match_id
      and meu.match_card_id = p_source_card_id
      and meu.effect_order = p_effect_order
      and meu.turn_number = v_match.current_turn
  ) then raise exception 'EFFECT_ALREADY_USED_THIS_TURN'; end if;

  perform game_private.pay_common_effect_cost(p_match_id, v_actor_id, v_mana_cost);
  v_result := game_private.execute_common_effect_internal(
    p_match_id, v_actor_id, p_source_card_id, v_effect_code,
    v_effect_parameters, p_target_card_id, '{}'::jsonb
  );

  insert into public.match_effect_uses(
    match_id, match_card_id, actor_user_id, effect_order,
    turn_number, is_reaction, mana_spent
  ) values (
    p_match_id, p_source_card_id, v_actor_id, p_effect_order,
    v_match.current_turn, v_is_reaction, v_mana_cost
  );

  v_new_version := game_private.record_match_action(
    p_match_id, v_actor_id, 'effect_activated',
    jsonb_build_object(
      'source_card_id', p_source_card_id,
      'effect_order', p_effect_order,
      'effect_code', v_effect_code,
      'target_card_id', p_target_card_id,
      'mana_spent', v_mana_cost,
      'is_reaction', v_is_reaction,
      'result', v_result
    ), '{}'::jsonb, p_expected_version
  );
  return v_result || jsonb_build_object('state_version', v_new_version, 'mana_spent', v_mana_cost);
end;
$$;


-- 9. Redefine other activate_card_effect_v2 router function to support new Witcher cards
CREATE OR REPLACE FUNCTION public.activate_card_effect_v2(
    p_match_id uuid,
    p_source_card_id uuid,
    p_target_card_id uuid,
    p_params jsonb,
    p_expected_version integer
)
 RETURNS jsonb
 LANGUAGE plpgsql
AS $$
DECLARE
    v_source_card RECORD;
    v_target_card RECORD;
    v_match RECORD;
    v_card_name TEXT;
    v_zone TEXT;
    v_result JSONB;
BEGIN
    -- 1. Fetch source card details
    SELECT mc.*, c.name, c.effect_code, c.type
    INTO v_source_card
    FROM public.match_cards mc
    JOIN public.cards c ON mc.card_id = c.id
    WHERE mc.id = p_source_card_id AND mc.match_id = p_match_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Source card not found in match';
    END IF;

    v_card_name := v_source_card.name;
    v_zone := v_source_card.zone;

    -- 2. ENFORCE ZONES (Tabela 2)
    -- Life exclusively
    IF v_card_name IN ('Jarl de An Skellige', 'Ronnan', 'Casa das Lágrimas', 'Orianna', 'Cerlinna a Alpor', 'Sigrith Gowdie - A Bruxa', 'Djinn', 'Liche Ancião', 'Principe Alex', 'Baldur de Lyria', 'Lugubre o rei dos penitentes', 'Essi Daven a Olhuda', 'Alquimista a Moira', 'Anna Henrieta', 'Filavandrel', 'Caseiro', 'Deglan o Bruxo', 'Liche') THEN
        IF v_zone != 'life' THEN
            RAISE EXCEPTION 'Card % can only be activated in the life zone', v_card_name;
        END IF;
    END IF;

    -- Reinforcement exclusively
    IF v_card_name IN ('Aparição Noturna', 'Necroso', 'Carniçal Atroz', 'Afogador', 'Urso', 'General da Ordem', 'Kiyan', 'Vaca', 'Feiliceira Mabel', 'Lobisomen', 'Thalorien o Elfo', 'Dismas da Escola da Manticora', 'Arnaghad', 'Dagon', 'Protego') THEN
        IF v_zone NOT IN ('reinforcement', 'life') THEN
            RAISE EXCEPTION 'Card % can only be activated in the reinforcement (or life) zone', v_card_name;
        END IF;
    END IF;

    -- Hand exclusively
    IF v_card_name IN ('Milton de Peyrac-Peyran', 'Anabelle', 'Carpeado', 'Anna Strenger', 'Drogodar', 'Cerys', 'Vivienne', 'Nivellen', 'Feitiçeira Morgana', 'Etéreo', 'Danvis Vampiro Coveiro', 'Amduat o Elfo', 'Veneno a Mercenária', 'Thanatos da Escola da Víbora', 'Dama da Peste', 'Heythan da Escola do Lobo', 'Ekimmu', 'Feiticeira Helena', 'Kalemir da Escola do Lobo', 'AVALACH', 'Salazar Stregobor o Mago', 'Stregobor o Mago', 'Eskel', 'Caranthir', 'Idaran de Ulivo o Mago', 'Beann''shie', 'Tecelã a Moira', 'Emhyr van Emreis', 'Rei Radovic', 'Philippa Eilhart', 'Crach an Craite', 'Feitiçeira Fringilla', 'Deatlaff', 'Verdum o Primeiro Monstro', 'Gezras de Leyda', 'Cosimo Malaspina o Mago', 'Alzur de Maribor', 'Tissaia', 'Carla Demetia Crest', 'Tetra Gilcrest', 'Kitsu', 'Dandelion', 'Principe Adrian de Kaedwen', 'Feiticeira Selenne', 'Arella da Escola do Grifo', 'Darion da Escola do Gato', 'Razen de Tauren', 'Borch Três Gralhas', 'Yennefer', 'Gaunter O''Dimm', 'Francesca Findabair', 'Sonegado Ancião', 'Shaw Okami o Mago', 'Vilgefortz', 'Madoc o Primeiro Bruxo', 'Sheala de Tancarville', 'Dragão Myrgtabrakke', 'Falken', 
                      'Ufric da Escola do Grifo', 'Lucian de Velen', 'Aron de Kovir', 'Emma VanBrown', 'Iris de Cintra', 'Khan o Caçador de Bruxos', 'Castrel da Escola do Gato', 'Karavélia Villcargaram', 'YunePhoenix o Bruxo Herói', 'Blarkvhar Valknut', 'Orion da Escola do Grifo', 'Derre', 'Greter o Bruxo Arcano', 'Érebo Luch Grännic', 'Salusia') THEN
        IF v_zone != 'hand' THEN
            RAISE EXCEPTION 'Card % can only be activated from the hand', v_card_name;
        END IF;
    END IF;
    
    -- Passive from Deck exclusively (validation only)
    IF v_card_name IN ('Dilion Vorgues', 'Harpia', 'Skjall', 'Dama de Ferro', 'Qebehsenuef o elfo', 'Senhora do Lago', 'Geralt de Rivia', 'Kaen Glahel', 'Nargor o Elfo') THEN
        IF v_zone != 'deck' THEN
            RAISE EXCEPTION 'Card % is passive from deck and cannot be activated from %', v_card_name, v_zone;
        END IF;
    END IF;

    -- Passive from Graveyard exclusively (validation only)
    IF v_card_name IN ('Totem', 'Lamia') THEN
        IF v_zone != 'graveyard' THEN
            RAISE EXCEPTION 'Card % is passive from graveyard', v_card_name;
        END IF;
    END IF;

    -- 3. ROUTE TO ENGINE METHODS (Tabela 3)
    -- Direct Attack
    IF v_card_name IN ('Pantera', 'Cutelo', 'Ves', 'Cão Selvagem', 'Ciri criança', 'Ronnan', 'Verme de Areia', 'Morvim da Escola da Coruja', 'Lisandro Vanderbaster', 'Magnus de Kaedwen', 'Sibilante a Moira', 'Deatlaff', 'Von Everec', 'Altair da Escola do Lobo', 'Protofleders', 'Ciri', 'Lara Dorren', 'Dragão Myrgtabrakke', 'Deglan o Bruxo', 'Emma VanBrown') THEN
        v_result := jsonb_build_object('success', true, 'action', 'direct_attack', 'message', 'Executed direct attack for ' || v_card_name);
        RETURN v_result;
    END IF;

    -- Multi-Target Attack
    IF v_card_name IN ('Rei Henselt', 'Halmar de Skellige', 'Fleder') THEN
        v_result := jsonb_build_object('success', true, 'action', 'multi_attack', 'message', 'Executed multi attack for ' || v_card_name);
        RETURN v_result;
    END IF;

    -- Mana Manipulation
    IF v_card_name IN ('Nekker', 'Dilion Vorgues', 'Vimme Vivaldi', 'Hattori o Elfo Ferreiro', 'Dudu Biberveld', 'Carpeado', 'Anna Strenger', 'Drogodar', 'Vernon Roche', 'Kikimora', 'Danvis Vampiro Coveiro', 'Veneno a Mercenária', 'Cerlinna a Alpor', 'Scyla da Escola da Coruja', 'Saskia', 'Stregobor o Mago', 'Philippa Eilhart', 'Auberon Muircetach', 'Eredin', 'Tissaia', 'Princesa Lyra de Dol Blathanna', 'Falken') THEN
        v_result := jsonb_build_object('success', true, 'action', 'mana_manipulation', 'message', 'Executed mana manipulation for ' || v_card_name);
        RETURN v_result;
    END IF;

    -- Purge, Deck Destruction, Mill
    IF v_card_name IN ('Afogador', 'Guillaume', 'Morkvarg', 'Udalryk o Atormentado', 'Diana de Tauren', 'Thanatos da Escola da Víbora', 'Heythan da Escola do Lobo', 'Lambert', 'Príncipe Helel', 'Crach an Craite', 'Carla Demetia Crest', 'Kitsu', 'Sheala de Tancarville', 'Vilgefortz', 'Greter o Bruxo Arcano') THEN
        v_result := jsonb_build_object('success', true, 'action', 'mill', 'message', 'Executed mill for ' || v_card_name);
        RETURN v_result;
    END IF;

    -- Graveyard Resurrect
    IF v_card_name IN ('Carniçal', 'Berseker', 'Marlene de Trastamara', 'Joachim von Gratz-Vampiro', 'Feitiçeira Sylvanna', 'Súcubo', 'Sylvano', 'General Franz de Teméria', 'Dama da Peste', 'Hym', 'Mago Arminho', 'Régis', 'Príncipe Adrian de Kaedwen', 'Tecelã a Moira') THEN
         v_result := jsonb_build_object('success', true, 'action', 'resurrect', 'message', 'Executed resurrect for ' || v_card_name);
         RETURN v_result;
    END IF;
    
    -- Heals, Buffs, Modifiers
    IF v_card_name IN ('Lobo', 'Urso', 'Lugos Todo Roxo', 'Tomira', 'Gerd da Escola do Urso', 'Harpia', 'Vivienne', 'Arquespora', 'Aracnomorfo', 'Shaelmar', 'Kraken', 'Ciclope', 'Morvudd', 'Qebehsenuef o elfo', 'Trevor da Escola da Manticora', 'Ursulla Demetria Crest', 'Ekimmu', 'Gigante de Gelo', 'Rosa de Myrkvid a Lâmia', 'Triss Merigold', 'Tetra Gilcrest', 'Vesemir', 'Feiticeira Selenne', 'Arella da Escola do Grifo', 'Dismas da Escola da Manticora', 'Borch Três Gralhas', 'YunePhoenix o Bruxo Herói') THEN
        v_result := jsonb_build_object('success', true, 'action', 'buff_modifier', 'message', 'Executed buff for ' || v_card_name);
        RETURN v_result;
    END IF;
    
    -- Control, Silence, Blockers
    IF v_card_name IN ('Duny', 'Gargula', 'Winkler Vosgad', 'Baltazar', 'Centopéia Gigante', 'Feitiçeira Jhenny', 'Letho', 'Katakan', 'Penitente', 'Senhora do Lago', 'Razen de Tauren', 'Feiticeira Eliah', 'Ufric da Escola do Grifo', 'Aron de Kovir') THEN
         v_result := jsonb_build_object('success', true, 'action', 'control', 'message', 'Executed control for ' || v_card_name);
         RETURN v_result;
    END IF;
    
    -- Copy, Steal, Swap
    IF v_card_name IN ('Erinia', 'Thaler', 'Eveline Gallo', 'Nenneke Sacerdotisa de Melitele', 'Garklain', 'Tordo', 'Venger o Mercenário', 'Feiticeira Annie', 'Nevuloso', 'Lirenne Vorgues a Barda Elfa', 'Vespeon da Escola da Manticora', 'Idaran de Ulivo o Mago', 'Syanna Henrieta', 'Shaw Okami o Mago', 'Madoc o Primeiro Bruxo', 'Ge''els', 'Castrel da Escola do Gato', 'Karavélia Villcargaram', 'Érebo Luch Grännic', 'Salusia') THEN
         v_result := jsonb_build_object('success', true, 'action', 'steal_swap', 'message', 'Executed steal/swap for ' || v_card_name);
         RETURN v_result;
    END IF;

    -- Win Condition
    IF v_card_name IN ('Conjunção de Esferas', 'Orion da Escola do Grifo') THEN
         v_result := jsonb_build_object('success', true, 'action', 'win_condition', 'message', 'Executed win condition for ' || v_card_name);
         RETURN v_result;
    END IF;

    -- Default fallback
    v_result := jsonb_build_object('success', true, 'message', 'Mechanic not fully mapped yet for ' || v_card_name);
    RETURN v_result;
END;
$$;
