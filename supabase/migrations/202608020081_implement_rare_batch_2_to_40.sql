-- Migration 202608020081_implement_rare_batch_2_to_40.sql

BEGIN;

ALTER FUNCTION game_private.execute_common_effect_internal(uuid, uuid, uuid, text, jsonb, uuid, jsonb)
    RENAME TO execute_common_effect_internal_v29_core;

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
    v_player_id uuid;
    v_opponent_id uuid;
    v_state jsonb;
    v_player_state jsonb;
    v_opponent_state jsonb;
    v_hand jsonb;
    v_deck jsonb;
    v_grave jsonb;
    v_life jsonb;
    v_reinforcement jsonb;
    v_opp_hand jsonb;
    v_opp_deck jsonb;
    v_opp_grave jsonb;
    v_opp_life jsonb;
    v_opp_reinforcement jsonb;
    v_turn integer;
    v_log_msg text;
    
    v_target_card jsonb;
    v_min_cost int;
    v_count int;
    v_idx int;
    v_cost int;
    i int;
    v_new_hand jsonb;
    v_new_deck jsonb;
    v_item jsonb;
BEGIN
    SELECT player_id INTO v_player_id FROM public.match_players WHERE match_id = p_match_id AND player_id = p_actor;
    SELECT player_id INTO v_opponent_id FROM public.match_players WHERE match_id = p_match_id AND player_id != p_actor LIMIT 1;
    
    SELECT state INTO v_state FROM public.matches WHERE id = p_match_id;
    v_player_state := v_state->'players'->(v_player_id::text);
    v_opponent_state := v_state->'players'->(v_opponent_id::text);
    
    v_hand := COALESCE(v_player_state->'hand', '[]');
    v_deck := COALESCE(v_player_state->'deck', '[]');
    v_grave := COALESCE(v_player_state->'graveyard', '[]');
    v_life := COALESCE(v_player_state->'life_cards', '[]');
    v_reinforcement := COALESCE(v_player_state->'reinforcement_cards', '[]');

    v_opp_hand := COALESCE(v_opponent_state->'hand', '[]');
    v_opp_deck := COALESCE(v_opponent_state->'deck', '[]');
    v_opp_grave := COALESCE(v_opponent_state->'graveyard', '[]');
    v_opp_life := COALESCE(v_opponent_state->'life_cards', '[]');
    v_opp_reinforcement := COALESCE(v_opponent_state->'reinforcement_cards', '[]');

    v_turn := COALESCE((v_state->>'turn')::int, 1);

    IF p_code = 'rare_jhenny_uninterruptible_mf' THEN
        v_state := jsonb_set(v_state, array['players', v_player_id::text, 'flags', 'jhenny_active'], 'true'::jsonb, true);
        PERFORM game_private.update_match_state(p_match_id, v_state, 'Feitiçeira Jhenny ativada: Oponente não pode reagir a efeitos M&F.');

    ELSIF p_code = 'rare_kraken_damage_cap_spill' THEN
        v_state := jsonb_set(v_state, array['players', v_player_id::text, 'flags', 'kraken_active'], 'true'::jsonb, true);
        PERFORM game_private.update_match_state(p_match_id, v_state, 'Kraken: Proteção contra dano massivo ativada.');

    ELSIF p_code = 'rare_fiend_peek_hand' THEN
        v_state := jsonb_set(v_state, array['players', v_player_id::text, 'visible_opp_hand'], 'true'::jsonb, true);
        PERFORM game_private.update_match_state(p_match_id, v_state, 'Demônio: Você pode ver a mão do oponente.');

    ELSIF p_code = 'rare_fleder_turn1_triple_strike' THEN
        IF v_turn = 1 THEN
            v_opp_grave := v_opp_grave || v_opp_life;
            v_opp_life := '[]'::jsonb;
            v_state := jsonb_set(v_state, array['players', v_opponent_id::text, 'graveyard'], v_opp_grave);
            v_state := jsonb_set(v_state, array['players', v_opponent_id::text, 'life_cards'], v_opp_life);
            PERFORM game_private.update_match_state(p_match_id, v_state, 'Fleder atacou todas as Cartas de Vida do oponente.');
        END IF;

    ELSIF p_code = 'rare_yrsa_discard_lowest_mana' THEN
        IF jsonb_array_length(v_opp_hand) > 0 THEN
            v_min_cost := 999;
            v_idx := -1;
            FOR i IN 0..jsonb_array_length(v_opp_hand) - 1 LOOP
                v_cost := COALESCE((v_opp_hand->i->>'effect_mana_cost')::int, 0);
                IF v_cost < v_min_cost THEN
                    v_min_cost := v_cost;
                    v_idx := i;
                END IF;
            END LOOP;
            IF v_idx >= 0 THEN
                v_target_card := v_opp_hand->v_idx;
                v_opp_hand := v_opp_hand - v_idx;
                v_opp_grave := v_opp_grave || v_target_card;
                v_state := jsonb_set(v_state, array['players', v_opponent_id::text, 'hand'], v_opp_hand);
                v_state := jsonb_set(v_state, array['players', v_opponent_id::text, 'graveyard'], v_opp_grave);
                PERFORM game_private.update_match_state(p_match_id, v_state, 'Yrsa descartou ' || (v_target_card->>'name') || ' da mão do oponente.');
            END IF;
        END IF;

    ELSIF p_code = 'rare_elemental_lock_high_power' THEN
        v_state := jsonb_set(v_state, array['flags', 'lock_power_4000'], 'true'::jsonb, true);
        PERFORM game_private.update_match_state(p_match_id, v_state, 'Elemental de Vida: Bloqueio de invocações acima de 4000 ativado.');

    ELSIF p_code = 'rare_diana_trade_life_for_elites' THEN
        IF jsonb_array_length(v_opp_life) > 0 THEN
            v_target_card := v_opp_life->0;
            v_opp_life := v_opp_life - 0;
            v_opp_grave := v_opp_grave || v_target_card;
            v_state := jsonb_set(v_state, array['players', v_opponent_id::text, 'life_cards'], v_opp_life);
            v_state := jsonb_set(v_state, array['players', v_opponent_id::text, 'graveyard'], v_opp_grave);
            v_log_msg := 'Diana destruiu ' || (v_target_card->>'name') || ' do oponente.';
        ELSE
            v_log_msg := 'Diana ativada, mas oponente não tinha Cartas de Vida.';
        END IF;
        v_new_deck := '[]'::jsonb;
        FOR i IN 0..jsonb_array_length(v_deck) - 1 LOOP
            v_item := v_deck->i;
            IF v_item->>'rarity' IN ('epic', 'legendary') THEN
                v_grave := v_grave || v_item;
            ELSE
                v_new_deck := v_new_deck || v_item;
            END IF;
        END LOOP;
        v_state := jsonb_set(v_state, array['players', v_player_id::text, 'deck'], v_new_deck);
        v_state := jsonb_set(v_state, array['players', v_player_id::text, 'graveyard'], v_grave);
        PERFORM game_private.update_match_state(p_match_id, v_state, v_log_msg || ' Suas cartas épicas e lendárias foram destruídas do deck.');

    ELSIF p_code = 'rare_scalet_summon_beast_attacker' THEN
        v_idx := -1;
        FOR i IN 0..jsonb_array_length(v_deck) - 1 LOOP
            IF v_deck->i->>'element' = 'Bestiário' THEN
                v_idx := i;
                EXIT;
            END IF;
        END LOOP;
        IF v_idx >= 0 THEN
            v_target_card := v_deck->v_idx;
            v_deck := v_deck - v_idx;
            v_reinforcement := v_reinforcement || v_target_card;
            v_state := jsonb_set(v_state, array['players', v_player_id::text, 'deck'], v_deck);
            v_state := jsonb_set(v_state, array['players', v_player_id::text, 'reinforcement_cards'], v_reinforcement);
            PERFORM game_private.update_match_state(p_match_id, v_state, 'Feiticeira Scalet invocou ' || (v_target_card->>'name') || ' do deck para atacar.');
        END IF;

    ELSIF p_code = 'rare_morvran_ursulla_direct_snipes' THEN
        v_count := 0;
        FOR i IN 0..jsonb_array_length(v_opp_deck) - 1 LOOP
            IF v_opp_deck->i->>'name' ILIKE '%Ursulla%' THEN
                v_count := v_count + 1;
            END IF;
        END LOOP;
        IF v_count > 0 THEN
            FOR i IN 1..v_count LOOP
                IF jsonb_array_length(v_opp_life) > 0 THEN
                    v_target_card := v_opp_life->0;
                    v_opp_life := v_opp_life - 0;
                    v_opp_grave := v_opp_grave || v_target_card;
                END IF;
            END LOOP;
            v_state := jsonb_set(v_state, array['players', v_opponent_id::text, 'life_cards'], v_opp_life);
            v_state := jsonb_set(v_state, array['players', v_opponent_id::text, 'graveyard'], v_opp_grave);
            PERFORM game_private.update_match_state(p_match_id, v_state, 'Morvim destruiu ' || v_count || ' Cartas de Vida devido às Ursullas no deck inimigo.');
        END IF;

    ELSIF p_code = 'rare_house_of_tears_effect_immunity' THEN
        v_state := jsonb_set(v_state, array['players', v_player_id::text, 'flags', 'house_of_tears_immune'], 'true'::jsonb, true);
        PERFORM game_private.update_match_state(p_match_id, v_state, 'Casa das Lágrimas ativada. Imunidade a efeitos ativada.');

    ELSIF p_code = 'rare_kikimore_witcher_death_discount' THEN
        IF jsonb_array_length(v_hand) > 0 THEN
            v_hand := jsonb_set(v_hand, '{0, current_mana_cost}', '0'::jsonb, true);
            v_state := jsonb_set(v_state, array['players', v_player_id::text, 'hand'], v_hand);
            PERFORM game_private.update_match_state(p_match_id, v_state, 'Kikimora reduziu o custo de uma carta na sua mão para 0.');
        END IF;

    ELSIF p_code = 'rare_thrush_bounce_life_swap' THEN
        IF jsonb_array_length(v_opp_life) > 0 AND jsonb_array_length(v_opp_hand) > 0 THEN
            v_target_card := v_opp_life->0;
            v_opp_life := v_opp_life - 0;
            v_opp_hand := v_opp_hand || v_target_card;
            
            v_item := v_opp_hand->0;
            v_opp_hand := v_opp_hand - 0;
            v_opp_life := v_opp_life || v_item;

            v_state := jsonb_set(v_state, array['players', v_opponent_id::text, 'life_cards'], v_opp_life);
            v_state := jsonb_set(v_state, array['players', v_opponent_id::text, 'hand'], v_opp_hand);
            PERFORM game_private.update_match_state(p_match_id, v_state, 'Tordo trocou ' || (v_target_card->>'name') || ' por ' || (v_item->>'name') || ' na Vida do oponente.');
        END IF;

    ELSIF p_code = 'rare_ice_troll_midgame_banish' THEN
        IF jsonb_array_length(v_deck) > 0 THEN
            v_deck := v_deck - 0;
        END IF;
        IF jsonb_array_length(v_opp_deck) > 0 THEN
            v_opp_deck := v_opp_deck - 0;
        END IF;
        v_state := jsonb_set(v_state, array['players', v_player_id::text, 'deck'], v_deck);
        v_state := jsonb_set(v_state, array['players', v_opponent_id::text, 'deck'], v_opp_deck);
        PERFORM game_private.update_match_state(p_match_id, v_state, 'Troll de Gelo baniu uma carta de cada deck.');

    ELSIF p_code = 'rare_morgana_skip_entire_round' THEN
        v_state := jsonb_set(v_state, array['players', v_opponent_id::text, 'flags', 'skip_next_turn'], 'true'::jsonb, true);
        PERFORM game_private.update_match_state(p_match_id, v_state, 'Feitiçeira Morgana fez o oponente perder a próxima rodada.');

    ELSIF p_code = 'rare_ethereal_tutor_pairs' THEN
        IF jsonb_array_length(v_deck) >= 2 THEN
            v_target_card := v_deck->0;
            v_hand := v_hand || v_target_card;
            v_deck := v_deck - 0;
            v_target_card := v_deck->0;
            v_hand := v_hand || v_target_card;
            v_deck := v_deck - 0;
            v_state := jsonb_set(v_state, array['players', v_player_id::text, 'hand'], v_hand);
            v_state := jsonb_set(v_state, array['players', v_player_id::text, 'deck'], v_deck);
            PERFORM game_private.update_match_state(p_match_id, v_state, 'Etéreo puxou 2 cópias do deck.');
        END IF;

    ELSIF p_code = 'rare_reed_select_rare_tutor' THEN
        v_idx := -1;
        FOR i IN 0..jsonb_array_length(v_deck) - 1 LOOP
            IF v_deck->i->>'rarity' = 'rare' THEN
                v_idx := i;
                EXIT;
            END IF;
        END LOOP;
        IF v_idx >= 0 THEN
            v_target_card := v_deck->v_idx;
            v_deck := v_deck - v_idx;
            v_hand := v_hand || v_target_card;
            v_state := jsonb_set(v_state, array['players', v_player_id::text, 'deck'], v_deck);
            v_state := jsonb_set(v_state, array['players', v_player_id::text, 'hand'], v_hand);
            PERFORM game_private.update_match_state(p_match_id, v_state, 'Canoleta comprou ' || (v_target_card->>'name') || ' do deck.');
        END IF;

    ELSIF p_code = 'rare_zoltan_trample_blind_destroy' THEN
        IF jsonb_array_length(v_opp_reinforcement) > 0 THEN
            v_target_card := v_opp_reinforcement->0;
            v_opp_reinforcement := v_opp_reinforcement - 0;
            v_opp_grave := v_opp_grave || v_target_card;
            v_state := jsonb_set(v_state, array['players', v_opponent_id::text, 'reinforcement_cards'], v_opp_reinforcement);
            v_state := jsonb_set(v_state, array['players', v_opponent_id::text, 'graveyard'], v_opp_grave);
            PERFORM game_private.update_match_state(p_match_id, v_state, 'Zoltan destruiu reforços em cadeia.');
        END IF;

    ELSIF p_code = 'rare_danvis_tax_hand' THEN
        v_new_hand := '[]'::jsonb;
        FOR i IN 0..jsonb_array_length(v_opp_hand) - 1 LOOP
            v_item := v_opp_hand->i;
            v_cost := COALESCE((v_item->>'current_mana_cost')::int, (v_item->>'effect_mana_cost')::int, 0) + 1;
            v_item := jsonb_set(v_item, '{current_mana_cost}', to_jsonb(v_cost));
            v_new_hand := v_new_hand || v_item;
        END LOOP;
        v_state := jsonb_set(v_state, array['players', v_opponent_id::text, 'hand'], v_new_hand);
        PERFORM game_private.update_match_state(p_match_id, v_state, 'Danvis aumentou o custo de mana da mão do oponente.');

    ELSIF p_code = 'rare_lagaz_force_reinforcement_fill' THEN
        WHILE jsonb_array_length(v_opp_reinforcement) < 5 AND jsonb_array_length(v_opp_hand) > 0 LOOP
            v_target_card := v_opp_hand->0;
            v_opp_hand := v_opp_hand - 0;
            v_opp_reinforcement := v_opp_reinforcement || v_target_card;
        END LOOP;
        v_state := jsonb_set(v_state, array['players', v_opponent_id::text, 'hand'], v_opp_hand);
        v_state := jsonb_set(v_state, array['players', v_opponent_id::text, 'reinforcement_cards'], v_opp_reinforcement);
        PERFORM game_private.update_match_state(p_match_id, v_state, 'Lagaz preencheu os reforços do oponente.');

    ELSIF p_code = 'rare_succubus_graveyard_treason_strike' THEN
        IF jsonb_array_length(v_opp_grave) > 0 THEN
            v_target_card := v_opp_grave->(jsonb_array_length(v_opp_grave) - 1);
            v_opp_grave := v_opp_grave - (jsonb_array_length(v_opp_grave) - 1);
            v_opp_grave := v_opp_grave || v_opp_life;
            v_opp_life := '[]'::jsonb;
            v_state := jsonb_set(v_state, array['players', v_opponent_id::text, 'graveyard'], v_opp_grave);
            v_state := jsonb_set(v_state, array['players', v_opponent_id::text, 'life_cards'], v_opp_life);
            PERFORM game_private.update_match_state(p_match_id, v_state, 'Súcubo reanimou ' || (v_target_card->>'name') || ' para atacar a Vida do oponente.');
        END IF;

    ELSE
        PERFORM game_private.execute_common_effect_internal_v29_core(p_match_id, p_actor, p_source, p_code, p_params, p_target, p_event);
    END IF;
END;
$$;

COMMIT;
