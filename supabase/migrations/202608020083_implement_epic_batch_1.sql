-- Migration 202608020083_implement_epic_batch_1.sql
-- Chain of Responsibility: Rename current function and create a new one wrapping it for Epic Batch 1.

BEGIN;

ALTER FUNCTION game_private.execute_common_effect_internal(uuid, uuid, uuid, text, jsonb, uuid, jsonb) 
RENAME TO execute_common_effect_internal_v31_core;

CREATE OR REPLACE FUNCTION game_private.execute_common_effect_internal(
    p_match_id uuid,
    p_actor uuid,
    p_source uuid,
    p_code text,
    p_params jsonb,
    p_target uuid DEFAULT NULL,
    p_event jsonb DEFAULT NULL
) RETURNS void
LANGUAGE plpgsql
AS $$
DECLARE
    v_opponent uuid;
    v_source_card jsonb;
    v_source_state jsonb;
    v_target_card jsonb;
    v_target_state jsonb;
    v_state jsonb;
    v_data jsonb;
    v_target_owner uuid;
    v_value int;
    v_zone text;
    v_source_instance_id uuid;
    
    -- Variables for specific effects
    v_mf_count int;
    v_bestiario_count int;
    v_target_id uuid;
    v_card record;
    v_card_data jsonb;
    v_has_sigrith boolean;
    v_has_witcher boolean;
    v_has_mf boolean;
    v_cem_count int;
    v_turn int;
    v_history jsonb;
    v_past_effect record;
BEGIN
    -- Determine opponent
    SELECT p1_id, p2_id INTO v_data
    FROM public.matches
    WHERE id = p_match_id;

    IF v_data IS NULL THEN
        RAISE EXCEPTION 'Match not found';
    END IF;

    IF v_data->>'p1_id' = p_actor::text THEN
        v_opponent := (v_data->>'p2_id')::uuid;
    ELSE
        v_opponent := (v_data->>'p1_id')::uuid;
    END IF;

    -- Fetch match state
    SELECT state INTO v_state
    FROM public.matches
    WHERE id = p_match_id;

    -- Fetch source card details
    SELECT instance_id, card_id, card_data, state INTO v_source_instance_id, v_source_card, v_data, v_source_state
    FROM public.match_cards
    WHERE match_id = p_match_id AND instance_id = p_source;

    IF p_code = 'epic_djinn_lock_mf_attack' THEN
        -- EPIC_001
        -- Ao ativar no Campo de Vida, o oponente fica impedido de usar qualquer carta do tipo M&F na linha de ataque até o Djinn ser destruído.
        UPDATE public.matches
        SET state = jsonb_set(
            jsonb_set(COALESCE(state, '{}'::jsonb), '{modifiers}', COALESCE(state->'modifiers', '{}'::jsonb)),
            array['modifiers', v_opponent::text],
            jsonb_set(COALESCE(state->'modifiers'->(v_opponent::text), '{}'::jsonb), '{cant_attack_mf_djinn_lock}', to_jsonb(p_source::text))
        )
        WHERE id = p_match_id;

    ELSIF p_code = 'epic_ursulla_dynamic_scaling' THEN
        -- EPIC_002
        -- Passivo automático. Logo ao ser comprada/sacada, a Vida desta carta se torna = 100 * [número de cartas M&F no deck do jogador], e seu Poder se torna = 250 * [número de cartas Bestiário no deck do jogador].
        SELECT COUNT(*) INTO v_mf_count
        FROM public.match_cards
        WHERE match_id = p_match_id AND owner_id = p_actor AND zone = 'deck' AND card_data->>'element' = 'M&F';

        SELECT COUNT(*) INTO v_bestiario_count
        FROM public.match_cards
        WHERE match_id = p_match_id AND owner_id = p_actor AND zone = 'deck' AND card_data->>'element' = 'Bestiário';

        UPDATE public.match_cards
        SET state = jsonb_set(
            jsonb_set(
                COALESCE(state, '{}'::jsonb),
                '{life}', to_jsonb(v_mf_count * 100)
            ),
            '{power}', to_jsonb(v_bestiario_count * 250)
        )
        WHERE instance_id = p_source;

    ELSIF p_code = 'epic_ekimmu_siphon_hand' THEN
        -- EPIC_003
        -- "rouba" 1000 de Vida e 1000 de Poder de TODAS as cartas presentes na mão do jogador oponente.
        v_value := 0;
        FOR v_card IN 
            SELECT instance_id, state 
            FROM public.match_cards 
            WHERE match_id = p_match_id AND owner_id = v_opponent AND zone = 'hand'
        LOOP
            UPDATE public.match_cards
            SET state = jsonb_set(
                jsonb_set(
                    COALESCE(state, '{}'::jsonb),
                    '{power}', to_jsonb(GREATEST(0, COALESCE((state->>'power')::int, 0) - 1000))
                ),
                '{life}', to_jsonb(GREATEST(0, COALESCE((state->>'life')::int, 0) - 1000))
            )
            WHERE instance_id = v_card.instance_id;
            v_value := v_value + 1;
        END LOOP;

        IF v_value > 0 THEN
            UPDATE public.match_cards
            SET state = jsonb_set(
                jsonb_set(
                    COALESCE(v_source_state, '{}'::jsonb),
                    '{power}', to_jsonb(COALESCE((v_source_state->>'power')::int, 0) + (1000 * v_value))
                ),
                '{life}', to_jsonb(COALESCE((v_source_state->>'life')::int, 0) + (1000 * v_value))
            )
            WHERE instance_id = p_source;
        END IF;

    ELSIF p_code = 'epic_ancient_lich_hand_bleed' THEN
        -- EPIC_004
        -- Em todo início de rodada do oponente, ele será forçado a descartar uma carta à escolha dele da mão até o Liche ser destruído.
        UPDATE public.matches
        SET state = jsonb_set(
            jsonb_set(COALESCE(state, '{}'::jsonb), '{modifiers}', COALESCE(state->'modifiers', '{}'::jsonb)),
            array['modifiers', v_opponent::text],
            jsonb_set(COALESCE(state->'modifiers'->(v_opponent::text), '{}'::jsonb), '{lich_hand_bleed}', to_jsonb(p_source::text))
        )
        WHERE id = p_match_id;

    ELSIF p_code = 'epic_eliah_effect_immortality' THEN
        -- EPIC_005
        -- esta carta torna-se imune a destruição por efeitos ou feitiços ativados pelo oponente até o fim da partida.
        UPDATE public.match_cards
        SET state = jsonb_set(
            COALESCE(state, '{}'::jsonb),
            '{immune_to_effects}', 'true'::jsonb
        )
        WHERE instance_id = p_source;

    ELSIF p_code = 'epic_annie_mimic_past_effect' THEN
        -- EPIC_006
        -- seleciona e ativa aleatoriamente o efeito de uma carta que o seu oponente já tenha ativado durante a partida atual.
        SELECT ce.effect_code INTO v_past_effect
        FROM public.match_cards mc
        JOIN public.card_effects ce ON mc.card_id = ce.card_id
        WHERE mc.match_id = p_match_id AND mc.owner_id = v_opponent AND ce.trigger_type = 'manual'
        ORDER BY random() LIMIT 1;

        IF v_past_effect IS NOT NULL THEN
            PERFORM game_private.execute_common_effect_internal(p_match_id, p_actor, p_source, (v_past_effect).effect_code, '{}'::jsonb, NULL, NULL);
        END IF;

    ELSIF p_code = 'epic_saskia_deck_discount_loop' THEN
        -- EPIC_007
        -- Saskia retorna para dentro do seu deck e ativa o feitiço: reduz em -2 o custo de mana de TODAS as cartas do seu deck até ela retornar para sua mão novamente.
        UPDATE public.match_cards
        SET zone = 'deck', position = floor(random() * 100)::int
        WHERE instance_id = p_source;

        UPDATE public.matches
        SET state = jsonb_set(
            jsonb_set(COALESCE(state, '{}'::jsonb), '{modifiers}', COALESCE(state->'modifiers', '{}'::jsonb)),
            array['modifiers', p_actor::text],
            jsonb_set(COALESCE(state->'modifiers'->(p_actor::text), '{}'::jsonb), '{saskia_discount}', to_jsonb(p_source::text))
        )
        WHERE id = p_match_id;

    ELSIF p_code = 'epic_alex_auto_reinforce' THEN
        -- EPIC_008
        -- No início de cada rodada sua, o sistema verifica se há um espaço vago de reforço e adiciona automaticamente 1 carta aleatória revelada como reforço no seu campo.
        SELECT COUNT(*) INTO v_value FROM public.match_cards WHERE match_id = p_match_id AND owner_id = p_actor AND zone = 'reinforcement';
        IF v_value < 5 THEN
            SELECT instance_id INTO v_target_id FROM public.match_cards WHERE match_id = p_match_id AND owner_id = p_actor AND zone = 'deck' ORDER BY random() LIMIT 1;
            IF v_target_id IS NOT NULL THEN
                UPDATE public.match_cards SET zone = 'reinforcement', revealed = true WHERE instance_id = v_target_id;
            END IF;
        END IF;

    ELSIF p_code = 'epic_foglet_duplicate_hand' THEN
        -- EPIC_009
        -- duplificar exata e integralmente uma carta da sua própria mão.
        IF p_target IS NOT NULL THEN
            SELECT card_id, card_data INTO v_target_id, v_data FROM public.match_cards WHERE instance_id = p_target AND zone = 'hand';
            IF v_target_id IS NOT NULL THEN
                INSERT INTO public.match_cards (match_id, owner_id, card_id, instance_id, zone, position, card_data, state, revealed)
                VALUES (p_match_id, p_actor, v_target_id, gen_random_uuid(), 'hand', 99, v_data, '{}'::jsonb, true);
            END IF;
        END IF;

    ELSIF p_code = 'epic_magnus_sigrith_bounce_snipe' THEN
        -- EPIC_010
        -- ataca diretamente uma Carta de Vida aleatória do oponente e retorna intacta para a mão do jogador enquanto ele controlar a carta "Sigrith Gowdie - A Bruxa" em seu Campo de Vida.
        SELECT COUNT(*) > 0 INTO v_has_sigrith FROM public.match_cards WHERE match_id = p_match_id AND owner_id = p_actor AND zone = 'life' AND card_data->>'name' = 'Sigrith Gowdie - A Bruxa';
        IF v_has_sigrith THEN
            SELECT instance_id INTO v_target_id FROM public.match_cards WHERE match_id = p_match_id AND owner_id = v_opponent AND zone = 'life' ORDER BY random() LIMIT 1;
            IF v_target_id IS NOT NULL THEN
                UPDATE public.match_cards SET state = jsonb_set(COALESCE(state, '{}'::jsonb), '{life}', to_jsonb(0)) WHERE instance_id = v_target_id;
            END IF;
            UPDATE public.match_cards SET zone = 'hand' WHERE instance_id = p_source;
        END IF;

    ELSIF p_code = 'epic_letho_summon_restriction' THEN
        -- EPIC_011
        -- Esta carta não pode ser invocada para o campo enquanto houver qualquer carta do tipo Witcher revelada no campo de reforço ou no campo de vida de NENHUM dos jogadores.
        NULL; -- handled externally

    ELSIF p_code = 'epic_katakan_suppress_blind_reinforcements' THEN
        -- EPIC_012
        -- anula o feitiço de todas as cartas de reforço viradas para baixo (ocultas) do oponente
        UPDATE public.match_cards
        SET state = jsonb_set(COALESCE(state, '{}'::jsonb), '{suppressed}', 'true'::jsonb)
        WHERE match_id = p_match_id AND owner_id = v_opponent AND zone = 'reinforcement' AND revealed = false;

    ELSIF p_code = 'epic_baldur_mf_deck_return' THEN
        -- EPIC_013
        -- Enquanto houver uma carta do tipo M&F no seu Campo de Vida, Baldur sempre retorna da mesa para dentro do seu deck ao final de cada rodada.
        SELECT COUNT(*) > 0 INTO v_has_mf FROM public.match_cards WHERE match_id = p_match_id AND owner_id = p_actor AND zone = 'life' AND card_data->>'element' = 'M&F';
        IF v_has_mf THEN
            UPDATE public.match_cards SET zone = 'deck' WHERE instance_id = p_source;
        END IF;

    ELSIF p_code = 'epic_lisandro_triple_direct_strike' THEN
        -- EPIC_014
        -- ataque diretamente as 3 Cartas de Vida do oponente de uma só vez.
        FOR v_card IN SELECT instance_id FROM public.match_cards WHERE match_id = p_match_id AND owner_id = v_opponent AND zone = 'life' ORDER BY position LIMIT 3 LOOP
            UPDATE public.match_cards SET state = jsonb_set(COALESCE(state, '{}'::jsonb), '{life}', to_jsonb(0)) WHERE instance_id = v_card.instance_id;
        END LOOP;

    ELSIF p_code = 'epic_penitent_graveyard_immortality' THEN
        -- EPIC_015
        -- só pode ser destruída se o oponente tiver pelo menos 6 cartas no próprio cemitério. Caso contrário, cura-se 100%.
        SELECT COUNT(*) INTO v_cem_count FROM public.match_cards WHERE match_id = p_match_id AND owner_id = v_opponent AND zone = 'graveyard';
        IF v_cem_count < 6 THEN
            UPDATE public.match_cards SET state = jsonb_set(COALESCE(state, '{}'::jsonb), '{life}', to_jsonb((card_data->>'base_max_life')::int)) WHERE instance_id = p_source;
        END IF;

    ELSIF p_code = 'epic_lambert_mill_random_deck' THEN
        -- EPIC_016
        -- destrua uma carta aleatória diretamente do deck do oponente.
        SELECT instance_id INTO v_target_id FROM public.match_cards WHERE match_id = p_match_id AND owner_id = v_opponent AND zone = 'deck' ORDER BY random() LIMIT 1;
        IF v_target_id IS NOT NULL THEN
            UPDATE public.match_cards SET zone = 'graveyard' WHERE instance_id = v_target_id;
        END IF;

    ELSIF p_code = 'epic_scyla_free_witcher_tutor' THEN
        -- EPIC_017
        -- compre uma carta do tipo Witcher aleatória do seu deck, alterando o custo de mana dela para = 0.
        SELECT instance_id INTO v_target_id FROM public.match_cards WHERE match_id = p_match_id AND owner_id = p_actor AND zone = 'deck' AND card_data->>'element' = 'Witcher' ORDER BY random() LIMIT 1;
        IF v_target_id IS NOT NULL THEN
            UPDATE public.match_cards SET zone = 'hand', state = jsonb_set(COALESCE(state, '{}'::jsonb), '{mana_cost}', '0'::jsonb) WHERE instance_id = v_target_id;
        END IF;

    ELSIF p_code = 'epic_ice_giant_turn5_scaling' THEN
        -- EPIC_018
        -- triplica sua própria Vida quando a partida ultrapassar o Turno 5.
        v_turn := COALESCE((v_state->>'turn')::int, 0);
        IF v_turn > 5 THEN
            UPDATE public.match_cards SET state = jsonb_set(COALESCE(state, '{}'::jsonb), '{life}', to_jsonb(COALESCE((state->>'life')::int, (card_data->>'base_max_life')::int) * 3)) WHERE instance_id = p_source;
        END IF;

    ELSIF p_code = 'epic_darko_hand_swap_endround' THEN
        -- EPIC_019
        -- agenda um feitiço transacional: ao final da rodada atual, todas as cartas presentes na sua mão serão permutadas pelas cartas da mão do oponente.
        UPDATE public.matches
        SET state = jsonb_set(
            jsonb_set(COALESCE(state, '{}'::jsonb), '{modifiers}', COALESCE(state->'modifiers', '{}'::jsonb)),
            array['modifiers', 'global'],
            jsonb_set(COALESCE(state->'modifiers'->'global', '{}'::jsonb), '{darko_hand_swap}', to_jsonb(p_actor::text))
        )
        WHERE id = p_match_id;

    ELSE
        PERFORM game_private.execute_common_effect_internal_v31_core(p_match_id, p_actor, p_source, p_code, p_params, p_target, p_event);
    END IF;
END;
$$;

COMMIT;
