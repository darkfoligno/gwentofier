-- Migration 202608010060_arena_rescue_guards_and_rpc_fixes.sql
-- V35.0: Resgate da Arena, Trava de Colisão, Fim do Erro 404 e Roteador de Efeitos Corrigido

BEGIN;

-- ==========================================
-- PILAR 1.1: ERRADICAÇÃO DO ERRO 404
-- ==========================================
CREATE TABLE IF NOT EXISTS public.match_private_reveals (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    match_id uuid REFERENCES public.matches(id) ON DELETE CASCADE,
    user_id uuid REFERENCES auth.users(id) ON DELETE CASCADE,
    card_id uuid REFERENCES public.match_cards(id) ON DELETE CASCADE,
    revealed_at timestamptz DEFAULT now()
);

CREATE OR REPLACE FUNCTION get_my_active_private_reveals(p_match_id uuid)
RETURNS SETOF public.match_private_reveals
LANGUAGE sql
SECURITY DEFINER
AS $$ 
    SELECT * FROM public.match_private_reveals 
    WHERE match_id = p_match_id AND user_id = auth.uid() 
    ORDER BY revealed_at DESC; 
$$;

-- ==========================================
-- PILAR 1.2: A LEI DA COLISÃO (TRAVA)
-- ==========================================
CREATE OR REPLACE FUNCTION public.declare_attack(
    p_match_id uuid,
    p_attacker_card_id uuid,
    p_target_card_id uuid,
    p_is_direct boolean default false,
    p_expected_version bigint default 0
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    v_user_id uuid:=game_private.require_authenticated();
    v_match public.matches;
    v_attacker public.match_cards;
    v_target public.match_cards;
    v_target_old_zone text;
    v_result jsonb;
    v_new_version bigint;
    v_remaining integer;
    v_target_player uuid;
    v_winner boolean:=false;
    v_has_direct_attack boolean:=false;
BEGIN
    v_match:=game_private.lock_match_for_action(p_match_id,p_expected_version,array['in_progress']);
    if v_match.active_player_id<>v_user_id then raise exception 'NOT_YOUR_TURN'; end if;

    select * into v_attacker from public.match_cards where id=p_attacker_card_id and match_id=p_match_id and controller_user_id=v_user_id and zone='attacker' and current_life>0 and has_attacked_this_turn=false for update;
    if not found then raise exception 'INVALID_ATTACKER'; end if;
    select * into v_target from public.match_cards where id=p_target_card_id and match_id=p_match_id and controller_user_id<>v_user_id and zone in ('reinforcement','life') and current_life>0 for update;
    if not found then raise exception 'INVALID_ATTACK_TARGET'; end if;
    
    v_target_player:=v_target.controller_user_id;
    v_target_old_zone:=v_target.zone;

    select exists (
        select 1 from jsonb_array_elements(coalesce((select effect_definition from public.match_deck_cards where id=v_attacker.match_deck_card_id), '[]'::jsonb)) as e(value)
        where e.value->>'effect_code' in ('direct_attack','attack_direct') or coalesce((e.value->'parameters'->>'ignore_reinforcement')::boolean,false)
    ) into v_has_direct_attack;

    -- Trava estrita de Colisão 
    IF v_target_old_zone = 'life' AND NOT v_has_direct_attack THEN
        IF EXISTS (
            SELECT 1 FROM public.match_cards 
            WHERE match_id = p_match_id AND owner_user_id = v_target_player 
              AND zone = 'reinforcement' AND current_life > 0
        ) THEN
            RAISE EXCEPTION 'Regra de Colisão violada: Você deve destruir a linha de Reforço do oponente antes de atacar suas Cartas de Vida!';
        END IF;
    END IF;

    if p_is_direct and not v_has_direct_attack then raise exception 'ATTACKER_HAS_NO_DIRECT_ATTACK_EFFECT'; end if;
    if p_is_direct and v_target.zone <> 'life' then raise exception 'DIRECT_ATTACK_REQUIRES_LIFE_TARGET'; end if;

    if v_target.zone='life' then
        if v_target.zone_position<>(select min(zone_position) from public.match_cards where match_id=p_match_id and controller_user_id=v_target_player and zone='life' and current_life>0) then raise exception 'ONLY_NEAREST_LIFE_CARD_CAN_BE_ATTACKED'; end if;
        if (select life_destroyed_this_turn from public.match_players where match_id=p_match_id and user_id=v_user_id) then raise exception 'ONLY_ONE_LIFE_CARD_MAY_BE_DESTROYED_PER_TURN'; end if;
    end if;

    if v_target.zone='reinforcement' then update public.match_cards set is_face_up=true where id=v_target.id; end if;
    v_result:=game_private.apply_damage_internal(p_match_id,v_target.id,v_attacker.current_power,v_match.current_turn);
    update public.match_cards set zone='graveyard',zone_position=null,is_face_up=true,has_attacked_this_turn=true where id=v_attacker.id;
    update public.match_players set actions_this_turn=actions_this_turn+1 where match_id=p_match_id and user_id=v_user_id;

    if v_target_old_zone='life' and coalesce((v_result->>'destroyed')::boolean,false) then
        update public.match_players set destroyed_life_count=destroyed_life_count+1 where match_id=p_match_id and user_id=v_target_player;
        update public.match_players set life_destroyed_this_turn=true where match_id=p_match_id and user_id=v_user_id;
    end if;

    select count(*)::integer into v_remaining from public.match_cards where match_id=p_match_id and controller_user_id=v_target_player and zone='life' and current_life>0;
    v_winner:=(v_remaining=0);
    v_new_version:=game_private.record_match_action(p_match_id,v_user_id,'attack_resolved',jsonb_build_object('attacker_card_id',p_attacker_card_id,'target_card_id',p_target_card_id,'direct',p_is_direct,'damage',v_attacker.current_power,'target_result',v_result,'life_remaining',v_remaining,'match_finished',v_winner),'{}'::jsonb,p_expected_version);
    if v_winner then perform game_private.finish_match(p_match_id,v_user_id,'all_life_cards_destroyed'); end if;
    return jsonb_build_object('target',v_result,'life_remaining',v_remaining,'match_finished',v_winner,'winner_id',case when v_winner then v_user_id else null end,'state_version',v_new_version);
END;
$$;


-- ==========================================
-- PILAR 2: CORREÇÃO DE ERRO 400 NO ROTEADOR (activate_card_effect_v2)
-- ==========================================
create or replace function public.activate_card_effect_v2(p_match_id uuid,p_source_card_id uuid,p_effect_order integer default 1,p_target_card_id uuid default null,p_expected_version bigint default 0)
returns jsonb language plpgsql security definer set search_path='' as $$
declare actor uuid:=game_private.require_authenticated();src public.match_cards;def jsonb;code text;params jsonb;trig text;reaction boolean;cost integer;result jsonb;new_version bigint;v_witchers integer;
begin
 select * into src from game_private.assert_common_effect_source(p_match_id,actor,p_source_card_id,p_expected_version,true);
 select x into def from public.match_deck_cards d cross join lateral jsonb_array_elements(d.effect_definition) x where d.id=src.match_deck_card_id and (x->>'effect_order')::integer=p_effect_order;
 if def is null then raise exception 'EFFECT_NOT_FOUND';end if;
 code:=def->>'effect_code';
 if code not like 'common_%' then return public.activate_match_effect(p_match_id,p_source_card_id,p_effect_order,p_target_card_id,p_expected_version);end if;
 perform game_private.assert_no_global_effect_lock(p_match_id,actor,p_source_card_id);
 trig:=def->>'trigger_type';
 -- CORREÇÃO DO ERRO 400: Se não tiver is_reaction, deduzir do trigger_type = 'reaction'
 reaction:=coalesce((def->>'is_reaction')::boolean, trig = 'reaction');
 if trig not in('manual','reaction') then raise exception 'EFFECT_IS_AUTOMATIC: %',trig;end if;
 if reaction and (select active_player_id from public.matches where id=p_match_id)=actor then raise exception 'REACTION_ONLY_ON_OPPONENT_TURN';end if;
 if reaction and not exists(select 1 from public.pending_attacks where match_id=p_match_id and defender_user_id=actor and status='awaiting_reaction') then raise exception 'NO_PENDING_ATTACK_FOR_REACTION';end if;
 if not reaction and (select active_player_id from public.matches where id=p_match_id)<>actor then raise exception 'NOT_YOUR_TURN';end if;
 params:=coalesce(def->'parameters','{}');
 if code='common_child_ciri_attack_all_life' then
  select count(*) into v_witchers from public.match_cards mc join public.match_deck_cards d on d.id=mc.match_deck_card_id where mc.match_id=p_match_id and mc.owner_user_id=actor and mc.zone='deck' and (d.element='Witcher' or d.card_name ilike '%witcher%');
  cost:=greatest(0,15-v_witchers);
 else
  cost:=coalesce((params->>'mana_cost')::integer,game_private.effect_card_cost(p_source_card_id),0);
 end if;
 if coalesce((def->>'once_per_turn')::boolean,false) and exists(select 1 from public.match_effect_uses where match_id=p_match_id and match_card_id=p_source_card_id and effect_order=p_effect_order and turn_number=(select current_turn from public.matches where id=p_match_id)) then raise exception 'EFFECT_ALREADY_USED_THIS_TURN';end if;
 perform game_private.pay_common_effect_cost(p_match_id,actor,cost);
 result:=game_private.execute_common_effect_internal(p_match_id,actor,p_source_card_id,code,params,p_target_card_id,'{}');
 insert into public.match_effect_uses(match_id,match_card_id,actor_user_id,effect_order,turn_number,is_reaction,mana_spent) values(p_match_id,p_source_card_id,actor,p_effect_order,(select current_turn from public.matches where id=p_match_id),reaction,cost);
 new_version:=game_private.record_match_action(p_match_id,actor,'effect_activated',jsonb_build_object('source_card_id',p_source_card_id,'effect_order',p_effect_order,'effect_code',code,'target_card_id',p_target_card_id,'mana_spent',cost,'result',result),'{}',p_expected_version);
 return result||jsonb_build_object('state_version',new_version,'mana_spent',cost);
end $$;

-- Aplicar a mesma correção no roteador não-common (activate_match_effect)
CREATE OR REPLACE FUNCTION public.activate_match_effect(
    p_match_id uuid,
    p_source_card_id uuid,
    p_effect_order integer,
    p_target_card_id uuid default null,
    p_expected_version bigint default 0
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    v_user_id uuid:=game_private.require_authenticated();
    v_match public.matches;
    v_source public.match_cards;
    v_data public.match_deck_cards;
    v_effect jsonb;
    v_code text;
    v_target_mode text;
    v_params jsonb;
    v_is_reaction boolean;
    v_once boolean;
    v_cost integer;
    v_amount integer;
    v_target public.match_cards;
    v_result jsonb:='{}'::jsonb;
    v_new_version bigint;
    v_cap integer;
    v_random_id uuid;
    v_target_old_zone text;
    v_target_player uuid;
    v_remaining integer;
    v_match_finished boolean:=false;
    v_winner_id uuid;
BEGIN
    v_match:=game_private.lock_match_for_action(p_match_id,p_expected_version,array['in_progress']);
    select * into v_source from public.match_cards where id=p_source_card_id and match_id=p_match_id and controller_user_id=v_user_id and zone in ('life','reinforcement','attacker','leader') and current_life>0 for update;
    if not found then raise exception 'EFFECT_SOURCE_NOT_ACTIVE'; end if;
    select * into v_data from public.match_deck_cards where id=v_source.match_deck_card_id;
    select e.value into v_effect from jsonb_array_elements(v_data.effect_definition) e(value) where (e.value->>'effect_order')::integer=p_effect_order limit 1;
    if v_effect is null then raise exception 'EFFECT_NOT_FOUND'; end if;

    v_code:=v_effect->>'effect_code';
    v_target_mode:=coalesce(v_effect->>'target_mode','none');
    v_params:=coalesce(v_effect->'parameters','{}'::jsonb);
    -- CORREÇÃO DO ERRO 400
    v_is_reaction:=coalesce((v_effect->>'is_reaction')::boolean, (v_effect->>'trigger_type') = 'reaction');
    v_once:=coalesce((v_effect->>'once_per_turn')::boolean,false);
    
    -- Correção: extração correta de custo de mana para não falhar por nulo
    v_cost:=coalesce((v_params->>'mana_cost')::integer,v_data.effect_mana_cost,0);
    v_amount:=coalesce((v_params->>'amount')::integer,0);
    select stat_cap into v_cap from public.game_rule_versions where id=v_match.rule_version_id;

    if v_is_reaction then
        if v_match.active_player_id=v_user_id then raise exception 'REACTION_ONLY_ON_OPPONENT_TURN'; end if;
        if (select reaction_used_this_opponent_turn from public.match_players where match_id=p_match_id and user_id=v_user_id) then
            raise exception 'REACTION_ALREADY_USED';
        end if;
    elsif v_match.active_player_id<>v_user_id then
        raise exception 'NOT_YOUR_TURN';
    end if;

    if v_source.zone='reinforcement' and not v_source.is_face_up and not v_is_reaction then
        raise exception 'HIDDEN_REINFORCEMENT_EFFECT_REQUIRES_REACTION';
    end if;

    if v_once and exists(select 1 from public.match_effect_uses where match_id=p_match_id and match_card_id=p_source_card_id and effect_order=p_effect_order and turn_number=v_match.current_turn) then
        raise exception 'EFFECT_ALREADY_USED_THIS_TURN';
    end if;
    if (select mana_available from public.match_players where match_id=p_match_id and user_id=v_user_id)<v_cost then
        raise exception 'INSUFFICIENT_MANA';
    end if;

    if v_target_mode='self' then
        if p_target_card_id is not null and p_target_card_id<>v_source.id then raise exception 'SELF_TARGET_REQUIRED'; end if;
        p_target_card_id:=v_source.id;
    elsif v_target_mode='nearest_life' and p_target_card_id is null then
        select id into p_target_card_id from public.match_cards where match_id=p_match_id and controller_user_id<>v_user_id and zone='life' and current_life>0 order by zone_position limit 1;
        if p_target_card_id is null then raise exception 'NO_VALID_TARGET'; end if;
    elsif v_target_mode<>'none' and p_target_card_id is null then
        raise exception 'TARGET_REQUIRED';
    end if;

    if p_target_card_id is not null then
        select * into v_target from public.match_cards where id=p_target_card_id and match_id=p_match_id for update;
        if not found then raise exception 'INVALID_TARGET'; end if;
    end if;

    if v_code='damage' then
        v_result:=game_private.apply_damage_internal(p_match_id,v_target.id,v_amount,v_match.current_turn);
    elsif v_code='heal' then
        v_result:=game_private.apply_healing_internal(p_match_id,v_target.id,v_amount);
    elsif v_code='buff_power' then
        update public.match_cards set current_power=least(v_cap,current_power+v_amount),maximum_power=least(v_cap,maximum_power+v_amount) where id=v_target.id;
        v_result:=jsonb_build_object('success',true,'power_gained',v_amount);
    elsif v_code='mana_ramp' then
        update public.match_players set mana_snapshot=least(10,mana_snapshot+v_amount),mana_available=least(10,mana_available+v_amount) where match_id=p_match_id and user_id=v_user_id;
        v_result:=jsonb_build_object('success',true,'mana_gained',v_amount);
    else
        raise exception 'UNSUPPORTED_EFFECT_CODE: %',v_code;
    end if;

    if v_cost>0 then
        update public.match_players set mana_available=mana_available-v_cost,mana_spent_this_turn=mana_spent_this_turn+v_cost,paid_effect_used_this_turn=true where match_id=p_match_id and user_id=v_user_id;
    else
        update public.match_players set free_effect_used_this_turn=true where match_id=p_match_id and user_id=v_user_id;
    end if;
    if v_is_reaction then
        update public.match_players set reaction_used_this_opponent_turn=true where match_id=p_match_id and user_id=v_user_id;
    end if;

    insert into public.match_effect_uses(match_id,match_card_id,actor_user_id,effect_order,turn_number,is_reaction,mana_spent)
    values(p_match_id,p_source_card_id,v_user_id,p_effect_order,v_match.current_turn,v_is_reaction,v_cost);

    v_new_version:=game_private.record_match_action(p_match_id,v_user_id,'effect_activated',jsonb_build_object('source_card_id',p_source_card_id,'effect_order',p_effect_order,'effect_code',v_code,'target_card_id',p_target_card_id,'mana_spent',v_cost,'result',v_result),'{}'::jsonb,p_expected_version);

    if p_target_card_id is not null and coalesce((v_result->>'destroyed')::boolean,false) and v_target.zone='life' then
        select count(*)::integer into v_remaining from public.match_cards where match_id=p_match_id and controller_user_id=v_target.controller_user_id and zone='life' and current_life>0;
        v_match_finished:=(v_remaining=0);
        if v_match_finished then
            v_winner_id:=case when v_target.controller_user_id=v_user_id then (select active_player_id from public.matches where id=p_match_id and active_player_id<>v_user_id limit 1) else v_user_id end;
            perform game_private.finish_match(p_match_id,v_winner_id,'all_life_cards_destroyed');
        end if;
    end if;
    return v_result||jsonb_build_object('state_version',v_new_version,'mana_spent',v_cost,'match_finished',v_match_finished);
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_my_active_private_reveals TO authenticated;

COMMIT;
