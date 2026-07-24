-- Migration 202608020082_implement_rare_batch_3_to_60.sql

BEGIN;

ALTER FUNCTION game_private.execute_common_effect_internal(uuid, uuid, uuid, text, jsonb, uuid, jsonb)
    RENAME TO execute_common_effect_internal_v30_core;

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
    j int;
    v_new_hand jsonb;
    v_new_deck jsonb;
    v_item jsonb;
    
    v_max_power int;
    v_has_req boolean;
    v_idx2 int;
    v_card_id text;
    v_seen_cards jsonb := '[]'::jsonb;
    v_is_dup boolean;
    v_rand_idx int;
    v_hp_add int;
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

    IF p_code = 'rare_morvudd_stat_invert' THEN
        IF jsonb_array_length(v_opp_reinforcement) > 0 THEN
            v_target_card := v_opp_reinforcement->0;
            v_idx := COALESCE((v_target_card->>'current_life')::int, (v_target_card->>'base_max_life')::int, 0);
            v_cost := COALESCE((v_target_card->>'current_power')::int, (v_target_card->>'base_power')::int, 0);
            v_target_card := jsonb_set(v_target_card, '{current_power}', to_jsonb(v_idx));
            v_target_card := jsonb_set(v_target_card, '{current_life}', to_jsonb(v_cost));
            v_opp_reinforcement := jsonb_set(v_opp_reinforcement, '{0}', v_target_card);
            v_state := jsonb_set(v_state, array['players', v_opponent_id::text, 'reinforcement_cards'], v_opp_reinforcement);
            PERFORM game_private.update_match_state(p_match_id, v_state, 'Morvudd inverteu os atributos da carta de defesa inimiga.');
        END IF;

    ELSIF p_code = 'rare_amduat_purge_hand_duplicates' THEN
        v_new_hand := '[]'::jsonb;
        FOR i IN 0..jsonb_array_length(v_opp_hand) - 1 LOOP
            v_item := v_opp_hand->i;
            v_card_id := v_item->>'id';
            v_is_dup := false;
            FOR j IN 0..jsonb_array_length(v_seen_cards) - 1 LOOP
                IF v_seen_cards->>j = v_card_id THEN
                    v_is_dup := true;
                    EXIT;
                END IF;
            END LOOP;
            IF v_is_dup THEN
                v_opp_grave := v_opp_grave || v_item;
            ELSE
                v_seen_cards := v_seen_cards || to_jsonb(v_card_id);
                v_new_hand := v_new_hand || v_item;
            END IF;
        END LOOP;
        v_state := jsonb_set(v_state, array['players', v_opponent_id::text, 'hand'], v_new_hand);
        v_state := jsonb_set(v_state, array['players', v_opponent_id::text, 'graveyard'], v_opp_grave);
        PERFORM game_private.update_match_state(p_match_id, v_state, 'Amduat destruiu as cartas repetidas da mão do oponente.');

    ELSIF p_code = 'rare_iron_maiden_guaranteed_opener' THEN
        PERFORM game_private.update_match_state(p_match_id, v_state, 'Dama de Ferro garantida na mão inicial.');

    ELSIF p_code = 'rare_sylvano_beast_revive_tutor' THEN
        v_idx := -1;
        FOR i IN 0..jsonb_array_length(v_grave) - 1 LOOP
            v_item := v_grave->i;
            IF v_item->>'element' = 'Bestiário' AND COALESCE((v_item->>'base_power')::int, 0) > 2800 THEN
                v_idx := i;
                EXIT;
            END IF;
        END LOOP;
        IF v_idx >= 0 THEN
            v_target_card := v_grave->v_idx;
            v_grave := v_grave - v_idx;
            v_hand := v_hand || v_target_card;
            v_state := jsonb_set(v_state, array['players', v_player_id::text, 'graveyard'], v_grave);
            v_state := jsonb_set(v_state, array['players', v_player_id::text, 'hand'], v_hand);
            PERFORM game_private.update_match_state(p_match_id, v_state, 'Sylvano puxou ' || (v_target_card->>'name') || ' do cemitério.');
        END IF;

    ELSIF p_code = 'rare_archgriffin_double_edge_snipe' THEN
        IF jsonb_array_length(v_life) > 0 AND jsonb_array_length(v_opp_life) > 0 THEN
            v_target_card := v_life->0;
            v_life := v_life - 0;
            v_grave := v_grave || v_target_card;
            
            v_item := v_opp_life->0;
            v_opp_life := v_opp_life - 0;
            v_opp_grave := v_opp_grave || v_item;

            v_state := jsonb_set(v_state, array['players', v_player_id::text, 'life_cards'], v_life);
            v_state := jsonb_set(v_state, array['players', v_player_id::text, 'graveyard'], v_grave);
            v_state := jsonb_set(v_state, array['players', v_opponent_id::text, 'life_cards'], v_opp_life);
            v_state := jsonb_set(v_state, array['players', v_opponent_id::text, 'graveyard'], v_opp_grave);
            PERFORM game_private.update_match_state(p_match_id, v_state, 'ArqueGriffo atacou uma Vida de cada lado.');
        END IF;

    ELSIF p_code = 'rare_orianna_reinforcement_throttle' THEN
        v_state := jsonb_set(v_state, array['players', v_opponent_id::text, 'flags', 'orianna_throttle'], 'true'::jsonb, true);
        PERFORM game_private.update_match_state(p_match_id, v_state, 'Orianna: Oponente restrito a 1 reforço por rodada.');

    ELSIF p_code = 'rare_qebehsenuef_scale_by_enemy_commons' THEN
        v_count := 0;
        FOR i IN 0..jsonb_array_length(v_opp_deck) - 1 LOOP
            IF v_opp_deck->i->>'rarity' = 'common' THEN
                v_count := v_count + 1;
            END IF;
        END LOOP;
        v_hp_add := v_count * 250;
        FOR i IN 0..jsonb_array_length(v_life) - 1 LOOP
            IF v_life->i->>'code' = 'RARE_047' THEN
                v_cost := COALESCE((v_life->i->>'current_life')::int, (v_life->i->>'base_max_life')::int, 0) + v_hp_add;
                v_life := jsonb_set(v_life, array[i::text, 'current_life'], to_jsonb(v_cost));
                v_state := jsonb_set(v_state, array['players', v_player_id::text, 'life_cards'], v_life);
                EXIT;
            END IF;
        END LOOP;
        PERFORM game_private.update_match_state(p_match_id, v_state, 'Qebehsenuef ganhou vida extra.');

    ELSIF p_code = 'rare_thalorien_survive_double_hp' THEN
        FOR i IN 0..jsonb_array_length(v_reinforcement) - 1 LOOP
            IF v_reinforcement->i->>'code' = 'RARE_048' THEN
                v_cost := COALESCE((v_reinforcement->i->>'current_life')::int, (v_reinforcement->i->>'base_max_life')::int, 0) * 2;
                v_reinforcement := jsonb_set(v_reinforcement, array[i::text, 'current_life'], to_jsonb(v_cost));
                v_state := jsonb_set(v_state, array['players', v_player_id::text, 'reinforcement_cards'], v_reinforcement);
                EXIT;
            END IF;
        END LOOP;
        PERFORM game_private.update_match_state(p_match_id, v_state, 'Thalorien dobrou sua Vida após sobreviver.');

    ELSIF p_code = 'rare_venom_tax_random_card' THEN
        IF jsonb_array_length(v_opp_hand) > 0 THEN
            v_idx := floor(random() * jsonb_array_length(v_opp_hand))::int;
            v_item := v_opp_hand->v_idx;
            v_cost := COALESCE((v_item->>'current_mana_cost')::int, (v_item->>'effect_mana_cost')::int, 0) + 1;
            v_item := jsonb_set(v_item, '{current_mana_cost}', to_jsonb(v_cost));
            v_opp_hand := jsonb_set(v_opp_hand, array[v_idx::text], v_item);
            v_state := jsonb_set(v_state, array['players', v_opponent_id::text, 'hand'], v_opp_hand);
            PERFORM game_private.update_match_state(p_match_id, v_state, 'Veneno aumentou o custo de mana de uma carta na mão inimiga.');
        END IF;

    ELSIF p_code = 'rare_cerlinna_discount_varuss' THEN
        FOR i IN 0..jsonb_array_length(v_deck) - 1 LOOP
            IF v_deck->i->>'code' = 'RARE_051' THEN
                v_item := v_deck->i;
                v_item := jsonb_set(v_item, '{current_mana_cost}', '0'::jsonb);
                v_deck := jsonb_set(v_deck, array[i::text], v_item);
                v_state := jsonb_set(v_state, array['players', v_player_id::text, 'deck'], v_deck);
            END IF;
        END LOOP;
        PERFORM game_private.update_match_state(p_match_id, v_state, 'Cerlinna zerou o custo de Varuss no seu deck.');

    ELSIF p_code = 'rare_varuss_execute_life' THEN
        v_has_req := false;
        FOR i IN 0..jsonb_array_length(v_grave) - 1 LOOP
            IF v_grave->i->>'code' = 'RARE_050' THEN
                v_has_req := true;
                EXIT;
            END IF;
        END LOOP;
        IF v_has_req AND jsonb_array_length(v_opp_life) > 0 THEN
            v_target_card := v_opp_life->0;
            v_opp_life := v_opp_life - 0;
            v_opp_grave := v_opp_grave || v_target_card;
            v_state := jsonb_set(v_state, array['players', v_opponent_id::text, 'life_cards'], v_opp_life);
            v_state := jsonb_set(v_state, array['players', v_opponent_id::text, 'graveyard'], v_opp_grave);
            PERFORM game_private.update_match_state(p_match_id, v_state, 'Varuss destruiu uma Carta de Vida do oponente.');
        END IF;

    ELSIF p_code = 'rare_thanatos_purge_highest_witchers' THEN
        v_max_power := -1; v_idx := -1;
        FOR i IN 0..jsonb_array_length(v_deck) - 1 LOOP
            v_item := v_deck->i;
            IF v_item->>'element' = 'Witcher' THEN
                v_cost := COALESCE((v_item->>'base_power')::int, 0);
                IF v_cost > v_max_power THEN v_max_power := v_cost; v_idx := i; END IF;
            END IF;
        END LOOP;
        IF v_idx >= 0 THEN
            v_target_card := v_deck->v_idx; v_deck := v_deck - v_idx; v_grave := v_grave || v_target_card;
            v_state := jsonb_set(v_state, array['players', v_player_id::text, 'deck'], v_deck);
            v_state := jsonb_set(v_state, array['players', v_player_id::text, 'graveyard'], v_grave);
        END IF;
        
        v_max_power := -1; v_idx2 := -1;
        FOR i IN 0..jsonb_array_length(v_opp_deck) - 1 LOOP
            v_item := v_opp_deck->i;
            IF v_item->>'element' = 'Witcher' THEN
                v_cost := COALESCE((v_item->>'base_power')::int, 0);
                IF v_cost > v_max_power THEN v_max_power := v_cost; v_idx2 := i; END IF;
            END IF;
        END LOOP;
        IF v_idx2 >= 0 THEN
            v_target_card := v_opp_deck->v_idx2; v_opp_deck := v_opp_deck - v_idx2; v_opp_grave := v_opp_grave || v_target_card;
            v_state := jsonb_set(v_state, array['players', v_opponent_id::text, 'deck'], v_opp_deck);
            v_state := jsonb_set(v_state, array['players', v_opponent_id::text, 'graveyard'], v_opp_grave);
        END IF;
        PERFORM game_private.update_match_state(p_match_id, v_state, 'Thanatos destruiu os Witchers mais fortes de ambos os decks.');

    ELSIF p_code = 'rare_jansen_tutor_witcher' THEN
        v_has_req := false;
        FOR i IN 0..jsonb_array_length(v_hand) - 1 LOOP
            IF v_hand->i->>'name' ILIKE '%Morvim da Escola da Coruja%' THEN v_has_req := true; EXIT; END IF;
        END LOOP;
        IF v_has_req THEN
            v_idx := -1;
            FOR i IN 0..jsonb_array_length(v_deck) - 1 LOOP
                IF v_deck->i->>'element' = 'Witcher' THEN v_idx := i; EXIT; END IF;
            END LOOP;
            IF v_idx >= 0 THEN
                v_target_card := v_deck->v_idx; v_deck := v_deck - v_idx; v_hand := v_hand || v_target_card;
                v_state := jsonb_set(v_state, array['players', v_player_id::text, 'deck'], v_deck);
                v_state := jsonb_set(v_state, array['players', v_player_id::text, 'hand'], v_hand);
                PERFORM game_private.update_match_state(p_match_id, v_state, 'Jansen comprou ' || (v_target_card->>'name') || ' do deck.');
            END IF;
        END IF;

    ELSIF p_code = 'rare_franz_graveyard_bounce' THEN
        IF jsonb_array_length(v_grave) > 0 THEN
            v_grave := v_grave - 0;
            v_state := jsonb_set(v_state, array['players', v_player_id::text, 'graveyard'], v_grave);
            PERFORM game_private.update_match_state(p_match_id, v_state, 'Franz baniu uma carta do cemitério e retornou.');
        END IF;

    ELSIF p_code = 'rare_enel_legendary_tutor' THEN
        v_idx := -1;
        FOR i IN 0..jsonb_array_length(v_deck) - 1 LOOP
            IF v_deck->i->>'rarity' = 'legendary' THEN v_idx := i; EXIT; END IF;
        END LOOP;
        IF v_idx >= 0 THEN
            v_target_card := v_deck->v_idx; v_deck := v_deck - v_idx; v_hand := v_hand || v_target_card;
            v_state := jsonb_set(v_state, array['players', v_player_id::text, 'deck'], v_deck);
            v_state := jsonb_set(v_state, array['players', v_player_id::text, 'hand'], v_hand);
            PERFORM game_private.update_match_state(p_match_id, v_state, 'Enel comprou ' || (v_target_card->>'name') || ' do deck.');
        END IF;

    ELSIF p_code = 'rare_sigrith_graveyard_engine' THEN
        IF jsonb_array_length(v_grave) > 0 THEN
            v_target_card := v_grave->0; v_grave := v_grave - 0; v_hand := v_hand || v_target_card;
            v_state := jsonb_set(v_state, array['players', v_player_id::text, 'graveyard'], v_grave);
            v_state := jsonb_set(v_state, array['players', v_player_id::text, 'hand'], v_hand);
            PERFORM game_private.update_match_state(p_match_id, v_state, 'Sigrith Gowdie comprou uma carta do cemitério.');
        END IF;

    ELSIF p_code = 'rare_venger_life_swap' THEN
        IF jsonb_array_length(v_life) > 0 AND jsonb_array_length(v_opp_life) > 0 THEN
            v_target_card := v_life->0; v_life := v_life - 0;
            v_item := v_opp_life->0; v_opp_life := v_opp_life - 0;
            v_life := v_life || v_item; v_opp_life := v_opp_life || v_target_card;
            v_state := jsonb_set(v_state, array['players', v_player_id::text, 'life_cards'], v_life);
            v_state := jsonb_set(v_state, array['players', v_opponent_id::text, 'life_cards'], v_opp_life);
            PERFORM game_private.update_match_state(p_match_id, v_state, 'Venger trocou uma Carta de Vida de cada lado.');
        END IF;

    ELSIF p_code = 'rare_trevor_heal_half' THEN
        FOR i IN 0..jsonb_array_length(v_life) - 1 LOOP
            v_item := v_life->i;
            v_cost := COALESCE((v_item->>'current_life')::int, 0);
            v_max_power := COALESCE((v_item->>'base_max_life')::int, 0);
            IF v_cost < v_max_power THEN
                v_cost := LEAST(v_max_power, v_cost + (v_max_power / 2));
                v_item := jsonb_set(v_item, '{current_life}', to_jsonb(v_cost));
                v_life := jsonb_set(v_life, array[i::text], v_item);
                v_state := jsonb_set(v_state, array['players', v_player_id::text, 'life_cards'], v_life);
                PERFORM game_private.update_match_state(p_match_id, v_state, 'Trevor restaurou 50% da Vida de ' || (v_item->>'name'));
                EXIT;
            END IF;
        END LOOP;

    ELSIF p_code = 'rare_plague_maiden_purge_enemy_graveyard' THEN
        v_state := jsonb_set(v_state, array['players', v_opponent_id::text, 'graveyard'], '[]'::jsonb);
        PERFORM game_private.update_match_state(p_match_id, v_state, 'Dama da Peste expurgou o cemitério inimigo.');

    ELSIF p_code = 'rare_heythan_discard_common' THEN
        v_idx := -1;
        FOR i IN 0..jsonb_array_length(v_opp_hand) - 1 LOOP
            IF v_opp_hand->i->>'rarity' = 'common' THEN v_idx := i; EXIT; END IF;
        END LOOP;
        IF v_idx >= 0 THEN
            v_target_card := v_opp_hand->v_idx; v_opp_hand := v_opp_hand - v_idx; v_opp_grave := v_opp_grave || v_target_card;
            v_state := jsonb_set(v_state, array['players', v_opponent_id::text, 'hand'], v_opp_hand);
            v_state := jsonb_set(v_state, array['players', v_opponent_id::text, 'graveyard'], v_opp_grave);
            PERFORM game_private.update_match_state(p_match_id, v_state, 'Heythan descartou ' || (v_target_card->>'name') || ' comum da mão inimiga.');
        END IF;

    ELSE
        PERFORM game_private.execute_common_effect_internal_v30_core(p_match_id, p_actor, p_source, p_code, p_params, p_target, p_event);
    END IF;
END;
$$;

COMMIT;
