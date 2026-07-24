BEGIN;

-- =========================================================================
-- PILAR 1: RESGATE DIÁRIO CALENDÁRIO (FIM DO COOLDOWN DE 24 HORAS)
-- =========================================================================
CREATE OR REPLACE FUNCTION claim_daily_login_reward(p_user_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_wallet_record record;
    v_days_missed integer;
    v_coins_reward integer;
    v_packs_reward integer;
BEGIN
    SELECT * INTO v_wallet_record FROM public.player_wallets WHERE user_id = p_user_id FOR UPDATE;
    
    IF NOT FOUND THEN
        v_days_missed := 1;
        INSERT INTO public.player_wallets (user_id, coins, last_claim_date) VALUES (p_user_id, 150, now());
        v_coins_reward := 150;
        v_packs_reward := 1;
    ELSE
        IF v_wallet_record.last_claim_date IS NULL THEN
            v_days_missed := 1;
        ELSE
            IF v_wallet_record.last_claim_date::date >= CURRENT_DATE THEN
                RETURN jsonb_build_object('success', false, 'error', 'Already claimed today');
            END IF;
            
            v_days_missed := (CURRENT_DATE - v_wallet_record.last_claim_date::date)::integer;
            IF v_days_missed < 1 THEN v_days_missed := 1; END IF;
        END IF;

        v_coins_reward := v_days_missed * 150;
        v_packs_reward := v_days_missed * 1;
        UPDATE public.player_wallets SET coins = coins + v_coins_reward, last_claim_date = now() WHERE user_id = p_user_id;
    END IF;

    INSERT INTO public.user_pack_balances (user_id, pack_type_id, quantity)
    SELECT p_user_id, id, v_packs_reward FROM public.pack_types WHERE code = 'daily_pack'
    ON CONFLICT (user_id, pack_type_id) DO UPDATE SET quantity = user_pack_balances.quantity + v_packs_reward;

    RETURN jsonb_build_object(
        'success', true, 
        'coins_reward', v_coins_reward, 
        'packs_reward', v_packs_reward, 
        'days_accumulated', v_days_missed
    );
END;
$$;


-- =========================================================================
-- PILAR 2: SANEAMENTO E BLINDAGEM DO MODO TREINO (Trava de Stats/Moedas)
-- =========================================================================
CREATE OR REPLACE FUNCTION game_private.finish_match(
    p_match_id uuid,
    p_winner_id uuid,
    p_reason text
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    v_match public.matches;
    v_player record;
    v_common_pack uuid;
    v_leader_pack uuid;
    v_universal_pack uuid;
    v_attempt public.campaign_attempts;
    v_boss public.campaign_bosses;
    v_completion_card uuid;
BEGIN
    SELECT * INTO v_match FROM public.matches WHERE id=p_match_id FOR UPDATE;
    IF NOT FOUND OR v_match.status='finished' THEN RETURN; END IF;

    UPDATE public.matches
    SET status='finished',winner_id=p_winner_id,finish_reason=p_reason,
        finished_at=now(),active_player_id=null
    WHERE id=p_match_id;

    -- BLOQUEIO DO MODO TREINO: Nao acumula vitorias, derrotas ou altera streaks
    IF v_match.match_type <> 'training' THEN
        FOR v_player IN SELECT user_id FROM public.match_players WHERE match_id=p_match_id LOOP
            UPDATE public.player_stats
            SET wins=wins+CASE WHEN v_player.user_id=p_winner_id THEN 1 ELSE 0 END,
                losses=losses+CASE WHEN p_winner_id IS NOT NULL AND v_player.user_id<>p_winner_id THEN 1 ELSE 0 END,
                draws=draws+CASE WHEN p_winner_id IS NULL THEN 1 ELSE 0 END,
                current_win_streak=CASE WHEN v_player.user_id=p_winner_id THEN current_win_streak+1 ELSE 0 END,
                best_win_streak=CASE WHEN v_player.user_id=p_winner_id THEN GREATEST(best_win_streak,current_win_streak+1) ELSE best_win_streak END,
                last_match_at=now()
            WHERE user_id=v_player.user_id;
        END LOOP;
    END IF;

    -- MODO FRIENDLY: Wallet e Pacotes (Treino nao entra aqui)
    IF v_match.match_type='friendly' THEN
        SELECT id INTO v_common_pack FROM public.pack_types WHERE code='common_reward';
        SELECT id INTO v_leader_pack FROM public.pack_types WHERE code='leader_reward';
        SELECT id INTO v_universal_pack FROM public.pack_types WHERE code='universal_500';

        FOR v_player IN SELECT user_id FROM public.match_players WHERE match_id=p_match_id LOOP
            PERFORM game_private.adjust_wallet(
                v_player.user_id,50,'match_reward','match',p_match_id,p_match_id,
                'Participação em duelo amistoso'
            );
            IF v_common_pack IS NOT NULL THEN
                PERFORM game_private.adjust_pack_balance(v_player.user_id,v_common_pack,1,'match_reward',p_match_id,p_match_id,'Pacote comum do duelo');
            END IF;
            IF v_leader_pack IS NOT NULL THEN
                PERFORM game_private.adjust_pack_balance(v_player.user_id,v_leader_pack,1,'match_reward',p_match_id,p_match_id,'Pacote de líder do duelo');
            END IF;
            INSERT INTO public.match_rewards(match_id,user_id,coins_awarded,granted_at,idempotency_key)
            VALUES(p_match_id,v_player.user_id,50,now(),p_match_id)
            ON CONFLICT(match_id,user_id) DO NOTHING;
        END LOOP;
        IF p_winner_id IS NOT NULL AND v_universal_pack IS NOT NULL THEN
            PERFORM game_private.adjust_pack_balance(p_winner_id,v_universal_pack,1,'match_reward',p_match_id,p_match_id,'Pacote universal da vitória');
        END IF;
    END IF;

    -- MODO CAMPANHA: Treino nao entra aqui
    IF v_match.match_type='campaign' THEN
        SELECT * INTO v_attempt FROM public.campaign_attempts WHERE match_id=p_match_id FOR UPDATE;
        IF FOUND THEN
            SELECT * INTO v_boss FROM public.campaign_bosses WHERE id=v_attempt.boss_id;
            UPDATE public.campaign_attempts
            SET result=CASE WHEN p_winner_id=v_attempt.user_id THEN 'win' ELSE 'loss' END,
                finished_at=now()
            WHERE id=v_attempt.id;

            INSERT INTO public.campaign_progress(user_id,boss_id,attempts,victories,is_defeated,last_attempt_at)
            VALUES(v_attempt.user_id,v_attempt.boss_id,1,
                CASE WHEN p_winner_id=v_attempt.user_id THEN 1 ELSE 0 END,
                p_winner_id=v_attempt.user_id,now())
            ON CONFLICT(user_id,boss_id) DO UPDATE SET
                attempts=public.campaign_progress.attempts+1,
                victories=public.campaign_progress.victories+CASE WHEN p_winner_id=v_attempt.user_id THEN 1 ELSE 0 END,
                is_defeated=public.campaign_progress.is_defeated OR p_winner_id=v_attempt.user_id,
                first_defeated_at=CASE
                    WHEN p_winner_id=v_attempt.user_id THEN COALESCE(public.campaign_progress.first_defeated_at,now())
                    ELSE public.campaign_progress.first_defeated_at END,
                last_attempt_at=now();

            IF p_winner_id=v_attempt.user_id AND v_boss.reward_card_id IS NOT NULL AND NOT EXISTS(
                SELECT 1 FROM public.campaign_progress
                WHERE user_id=v_attempt.user_id AND boss_id=v_attempt.boss_id AND reward_granted=true
            ) THEN
                PERFORM game_private.adjust_inventory(v_attempt.user_id,v_boss.reward_card_id,1,'campaign_reward',v_attempt.id,v_attempt.id,'Recompensa do chefe');
                UPDATE public.campaign_progress SET reward_granted=true
                WHERE user_id=v_attempt.user_id AND boss_id=v_attempt.boss_id;
                UPDATE public.player_stats SET campaign_wins=campaign_wins+1 WHERE user_id=v_attempt.user_id;
            END IF;

            IF p_winner_id=v_attempt.user_id AND (
                SELECT COUNT(*) FROM public.campaign_progress cp
                JOIN public.campaign_bosses cb ON cb.id=cp.boss_id AND cb.is_active=true
                WHERE cp.user_id=v_attempt.user_id AND cp.is_defeated=true
            ) >= 20 THEN
                SELECT golden_completion_reward_card_id INTO v_completion_card
                FROM public.campaign_bosses
                WHERE golden_completion_reward_card_id IS NOT NULL
                ORDER BY tier DESC LIMIT 1;
                IF v_completion_card IS NOT NULL AND NOT EXISTS(
                    SELECT 1 FROM public.inventory_transactions
                    WHERE user_id=v_attempt.user_id AND card_id=v_completion_card
                      AND source_type='campaign_reward' AND description='Conclusão dos 20 chefes'
                ) THEN
                    PERFORM game_private.adjust_inventory(v_attempt.user_id,v_completion_card,1,'campaign_reward',v_attempt.id,null,'Conclusão dos 20 chefes');
                END IF;
            END IF;
        END IF;
    END IF;

    PERFORM game_private.recalculate_match_public_state(p_match_id);
END;
$$;

COMMIT;
