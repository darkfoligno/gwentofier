-- V15.0: reações não fatais, sigilo defensivo, slots de efeito e laboratório unitário.
begin;

-- Preserva o núcleo V8/V14 e publica uma fachada que transforma apenas
-- inelegibilidades esperadas em JSON HTTP 200.
do $$ begin
  if to_regprocedure('public.activate_card_effect_v2_v14_core(uuid,uuid,integer,uuid,bigint)') is null then
    alter function public.activate_card_effect_v2(uuid,uuid,integer,uuid,bigint) rename to activate_card_effect_v2_v14_core;
  end if;
end $$;
revoke all on function public.activate_card_effect_v2_v14_core(uuid,uuid,integer,uuid,bigint) from public,anon,authenticated;

create or replace function public.activate_card_effect_v2(
  p_match_id uuid,p_source_card_id uuid,p_effect_order integer default 1,
  p_target_card_id uuid default null,p_expected_version bigint default 0
) returns jsonb language plpgsql security definer set search_path='' as $$
declare
  v_actor_id uuid:=game_private.require_authenticated();v_effect jsonb;v_code text;v_cost integer:=0;
  v_is_reaction boolean:=false;v_is_direct boolean;v_paid_used boolean;v_free_used boolean;
  v_turn integer;v_result jsonb;v_message text;
begin
  select x.value into v_effect from public.match_cards mc join public.match_deck_cards d on d.id=mc.match_deck_card_id
  cross join lateral jsonb_array_elements(d.effect_definition)x(value)
  where mc.id=p_source_card_id and mc.match_id=p_match_id and mc.controller_user_id=v_actor_id
    and (x.value->>'effect_order')::integer=p_effect_order;
  if v_effect is null then return jsonb_build_object('success',false,'eligible',false,'reason','EFFECT_NOT_FOUND');end if;
  v_code:=v_effect->>'effect_code';v_is_reaction:=coalesce((v_effect->>'is_reaction')::boolean,false) or v_effect->>'trigger_type' in('reaction','on_reaction','on_attacked','on_damage_received');
  v_cost:=greatest(0,coalesce((v_effect->'parameters'->>'mana_cost')::integer,game_private.effect_card_cost(p_source_card_id),0));
  select mp.paid_effect_used_this_turn,mp.free_effect_used_this_turn,m.current_turn into v_paid_used,v_free_used,v_turn
  from public.match_players mp join public.matches m on m.id=mp.match_id where mp.match_id=p_match_id and mp.user_id=v_actor_id for update of mp,m;
  if v_cost>0 and v_paid_used then return jsonb_build_object('success',false,'eligible',false,'reason','PAID_EFFECT_ALREADY_USED_THIS_TURN');end if;
  if v_cost=0 and v_free_used then return jsonb_build_object('success',false,'eligible',false,'reason','FREE_EFFECT_ALREADY_USED_THIS_TURN');end if;
  if v_is_reaction then
    select pa.is_direct into v_is_direct from public.pending_attacks pa where pa.match_id=p_match_id and pa.defender_user_id=v_actor_id and pa.status='awaiting_reaction' order by pa.created_at desc limit 1;
    if v_code='common_baltazar_cancel_direct' and not coalesce(v_is_direct,false) then
      return jsonb_build_object('success',false,'eligible',false,'reason','REACTION_REQUIRES_DIRECT_ATTACK');
    end if;
  end if;
  begin
    v_result:=public.activate_card_effect_v2_v14_core(p_match_id,p_source_card_id,p_effect_order,p_target_card_id,p_expected_version);
  exception when others then
    v_message:=sqlerrm;
    if v_message in('REACTION_REQUIRES_DIRECT_ATTACK','REACTION_REQUIRES_SINGLE_ATTACKER','ATTACKER_IS_NOT_M_AND_F','NO_PENDING_ATTACK_FOR_REACTION','NO_OPEN_REACTION_WINDOW') then
      return jsonb_build_object('success',false,'eligible',false,'reason',v_message);
    end if;
    raise;
  end;
  update public.match_players mp set paid_effect_used_this_turn=case when v_cost>0 then true else mp.paid_effect_used_this_turn end,
    free_effect_used_this_turn=case when v_cost=0 then true else mp.free_effect_used_this_turn end
  where mp.match_id=p_match_id and mp.user_id=v_actor_id;
  if v_code in('common_gerd_double_life','common_baltazar_cancel_direct') and not exists(
    select 1 from public.match_card_modifiers mm where mm.match_card_id=p_source_card_id and mm.starts_on_turn=v_turn and mm.metadata->>'effect_code'=v_code
  ) then
    insert into public.match_card_modifiers(match_card_id,source_match_card_id,modifier_type,starts_on_turn,is_permanent,metadata)
    values(p_source_card_id,p_source_card_id,case when v_code='common_gerd_double_life' then 'buff' else 'immunity' end,v_turn,v_code='common_gerd_double_life',jsonb_build_object('effect_code',v_code,'activation_record',true));
  end if;
  return coalesce(v_result,'{}'::jsonb)||jsonb_build_object('success',true,'eligible',true);
end $$;

do $$ begin
  if to_regprocedure('public.resolve_pending_card_trigger_v14_core(uuid,varchar)') is null then
    alter function public.resolve_pending_card_trigger(uuid,varchar) rename to resolve_pending_card_trigger_v14_core;
  end if;
end $$;
revoke all on function public.resolve_pending_card_trigger_v14_core(uuid,varchar) from public,anon,authenticated;
create or replace function public.resolve_pending_card_trigger(p_trigger_id uuid,p_action varchar)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_actor uuid:=game_private.require_authenticated();v_cost integer;v_match_id uuid;v_paid boolean;v_free boolean;v_result jsonb;
begin
  select pt.match_id,pt.mana_cost into v_match_id,v_cost from public.pending_card_triggers pt where pt.id=p_trigger_id and pt.owner_user_id=v_actor and pt.status='pending' for update;
  if v_match_id is null then return jsonb_build_object('success',false,'eligible',false,'reason','PENDING_TRIGGER_NOT_FOUND');end if;
  select mp.paid_effect_used_this_turn,mp.free_effect_used_this_turn into v_paid,v_free from public.match_players mp where mp.match_id=v_match_id and mp.user_id=v_actor for update;
  if lower(trim(coalesce(p_action,'')))='activate' and v_cost>0 and v_paid then return jsonb_build_object('success',false,'eligible',false,'reason','PAID_EFFECT_ALREADY_USED_THIS_TURN');end if;
  if lower(trim(coalesce(p_action,'')))='activate' and v_cost=0 and v_free then return jsonb_build_object('success',false,'eligible',false,'reason','FREE_EFFECT_ALREADY_USED_THIS_TURN');end if;
  v_result:=public.resolve_pending_card_trigger_v14_core(p_trigger_id,p_action);
  if coalesce((v_result->>'success')::boolean,false) and lower(trim(coalesce(p_action,'')))='activate' then
    update public.match_players mp set paid_effect_used_this_turn=case when v_cost>0 then true else mp.paid_effect_used_this_turn end,free_effect_used_this_turn=case when v_cost=0 then true else mp.free_effect_used_this_turn end where mp.match_id=v_match_id and mp.user_id=v_actor;
  end if;
  return v_result||jsonb_build_object('eligible',coalesce((v_result->>'success')::boolean,false));
end $$;

-- Ações são públicas para os dois participantes: metadados de reforço oculto
-- precisam ser removidos no servidor, e não apenas escondidos com CSS.
create or replace function game_private.redact_hidden_reinforcement_action_v15()
returns trigger language plpgsql security definer set search_path='' as $$
begin
  if new.action_type='card_played' and new.payload_public->>'destination_zone'='reinforcement' then
    new.payload_public:=(new.payload_public-'card_name'-'element'-'rarity'-'atk'-'hp'-'effect_text')
      ||jsonb_build_object('target_zone_label','Campo de Reforço','is_hidden_reinforcement',true);
  end if;return new;
end $$;
drop trigger if exists zz_match_actions_redact_hidden_reinforcement_v15 on public.match_actions;
create trigger zz_match_actions_redact_hidden_reinforcement_v15 before insert on public.match_actions
for each row execute function game_private.redact_hidden_reinforcement_action_v15();

create table if not exists public.sandbox_matches(
  match_id uuid primary key references public.matches(id) on delete cascade,
  owner_user_id uuid not null references public.profiles(id) on delete cascade,
  tested_card_id uuid not null references public.cards(id) on delete restrict,
  objective text not null,created_at timestamptz not null default now()
);
alter table public.sandbox_matches enable row level security;
drop policy if exists sandbox_matches_owner_read on public.sandbox_matches;
create policy sandbox_matches_owner_read on public.sandbox_matches for select to authenticated using(owner_user_id=auth.uid());

create or replace function public.setup_sandbox_match(p_card_id varchar)
returns jsonb language plpgsql security definer set search_path='' as $$
declare
  v_actor uuid:=game_private.require_authenticated();v_bot constant uuid:='00000000-0000-4000-8000-000000000071';
  v_card public.cards;v_created jsonb;v_match_id uuid;v_test_mc uuid;v_test_d uuid;v_enemy_mc uuid;
  v_mode text:='combat';v_objective text;v_effects jsonb;v_row record;v_count integer:=0;
begin
  select c.* into v_card from public.cards c where c.is_active and (c.id::text=p_card_id or lower(c.code)=lower(p_card_id) or lower(c.name)=lower(p_card_id)) order by c.name limit 1;
  if not found then return jsonb_build_object('success',false,'reason','SANDBOX_CARD_NOT_FOUND');end if;
  select coalesce(jsonb_agg(jsonb_build_object('effect_order',ce.effect_order,'trigger_type',ce.trigger_type,'effect_code',ce.effect_code,'target_mode',ce.target_mode,'parameters',ce.parameters,'priority',ce.priority,'is_reaction',ce.is_reaction,'once_per_turn',ce.once_per_turn) order by ce.effect_order),'[]'::jsonb)
  into v_effects from public.card_effects ce where ce.card_id=v_card.id and ce.is_active;
  select coalesce(jsonb_agg(jsonb_set(e.value,'{parameters,mana_cost}','0'::jsonb,true)),'[]'::jsonb) into v_effects from jsonb_array_elements(v_effects)e(value);
  if v_effects::text like '%common_gerd_double_life%' or lower(v_card.name)='gerd' then v_mode:='life';
  elsif v_effects::text like '%common_harpy_absorb_and_attack%' or lower(v_card.name) in('harpia','harpy') then v_mode:='synergy';end if;
  v_created:=public.create_training_match(40);v_match_id:=(v_created->>'match_id')::uuid;
  perform game_private.deal_initial_hands(v_match_id);
  select mc.id,mc.match_deck_card_id into v_test_mc,v_test_d from public.match_cards mc where mc.match_id=v_match_id and mc.owner_user_id=v_actor and mc.zone='hand' order by mc.zone_position limit 1 for update;
  update public.match_deck_cards d set source_card_id=v_card.id,card_version=v_card.version,card_name=v_card.name,image_url=v_card.image_url,element=v_card.element,rarity=v_card.rarity,card_type=v_card.card_type,is_golden=v_card.is_golden,base_power=v_card.base_power,base_max_life=v_card.base_max_life,effect_mana_cost=0,tier=v_card.tier,leader_cooldown=v_card.leader_cooldown,effect_definition=v_effects where d.id=v_test_d;
  update public.match_cards mc set source_card_id=v_card.id,base_power=v_card.base_power,maximum_power=v_card.base_power,current_power=v_card.base_power,base_max_life=greatest(1,v_card.base_max_life),maximum_life=greatest(1,v_card.base_max_life),current_life=greatest(1,v_card.base_max_life),metadata=mc.metadata||jsonb_build_object('sandbox_card',true,'mana_cost_delta',-v_card.effect_mana_cost),entered_zone_turn=3 where mc.id=v_test_mc;
  with chosen as(select mc.id,row_number()over(order by mc.zone_position)pos from public.match_cards mc where mc.match_id=v_match_id and mc.owner_user_id=v_actor and mc.zone='hand' and mc.id<>v_test_mc limit 3)
  update public.match_cards mc set zone='life',zone_position=chosen.pos,is_face_up=true,entered_zone_turn=0 from chosen where mc.id=chosen.id;
  with chosen as(select mc.id,row_number()over(order by mc.zone_position)pos from public.match_cards mc where mc.match_id=v_match_id and mc.owner_user_id=v_bot and mc.zone='hand' limit 3)
  update public.match_cards mc set zone='life',zone_position=chosen.pos,is_face_up=true,entered_zone_turn=0 from chosen where mc.id=chosen.id;
  select mc.id into v_enemy_mc from public.match_cards mc where mc.match_id=v_match_id and mc.owner_user_id=v_bot and mc.zone='deck' order by mc.zone_position limit 1 for update;
  update public.match_cards set zone='reinforcement',zone_position=1,is_face_up=false,current_life=1000,maximum_life=1000,base_max_life=1000,current_power=500,maximum_power=500,base_power=500 where id=v_enemy_mc;
  if v_mode='life' then
    update public.match_cards set zone='graveyard',zone_position=null,is_face_up=true,is_destroyed=true,current_life=0 where match_id=v_match_id and owner_user_id=v_actor and zone='life' and zone_position=1;
    update public.match_cards set zone='life',zone_position=1,is_face_up=true,is_destroyed=false where id=v_test_mc;
    update public.match_players set passed_turn=true where match_id=v_match_id and user_id=v_bot;
    v_objective:='Ative o efeito de '||v_card.name||' no Campo de Vida e confirme o modificador persistente e a Vida resultante.';
  elsif v_mode='synergy' then
    update public.match_cards set zone='attacker',zone_position=1,is_face_up=true where id=v_test_mc;
    update public.match_cards set zone='graveyard',zone_position=null,is_face_up=true,is_destroyed=true,current_life=0 where match_id=v_match_id and owner_user_id=v_bot and zone='life' and zone_position=3;
    for v_row in select mc.id,mc.match_deck_card_id from public.match_cards mc where mc.match_id=v_match_id and mc.owner_user_id=v_actor and mc.zone='deck' order by mc.zone_position limit 10 loop
      update public.match_deck_cards d set source_card_id=v_card.id,card_version=v_card.version,card_name=v_card.name,image_url=v_card.image_url,element=v_card.element,rarity=v_card.rarity,card_type=v_card.card_type,is_golden=v_card.is_golden,base_power=v_card.base_power,base_max_life=v_card.base_max_life,effect_mana_cost=0,tier=v_card.tier,leader_cooldown=v_card.leader_cooldown,effect_definition=v_effects where d.id=v_row.match_deck_card_id;
      update public.match_cards set source_card_id=v_card.id,base_power=v_card.base_power,maximum_power=v_card.base_power,current_power=v_card.base_power,base_max_life=greatest(1,v_card.base_max_life),maximum_life=greatest(1,v_card.base_max_life),current_life=greatest(1,v_card.base_max_life) where id=v_row.id;v_count:=v_count+1;
    end loop;
    v_objective:='Use '||v_card.name||' no Campo de Ataque com 10 cópias no Deck e confronte as duas linhas de Vida inimigas.';
  else
    v_objective:='Jogue '||v_card.name||' com custo de Mana zerado, encerre a fase principal e confira o alvo defensivo de 1000 HP.';
  end if;
  update public.matches set status='in_progress',engine_state='turn_action',current_turn=3,active_player_id=v_actor,turn_deadline=clock_timestamp()+interval '30 minutes' where id=v_match_id;
  update public.match_players set setup_finished=true where match_id=v_match_id;
  update public.match_players set actions_this_turn=case when v_mode='synergy' then 1 else 0 end,mana_available=10,mana_snapshot=10,mana_spent_this_turn=0,paid_effect_used_this_turn=false,free_effect_used_this_turn=false where match_id=v_match_id and user_id=v_actor;
  insert into public.sandbox_matches(match_id,owner_user_id,tested_card_id,objective)values(v_match_id,v_actor,v_card.id,v_objective);
  perform game_private.recalculate_match_public_state(v_match_id);
  return jsonb_build_object('success',true,'match_id',v_match_id,'card_id',v_card.id,'mode',v_mode,'objective',v_objective);
exception when others then return jsonb_build_object('success',false,'reason',sqlerrm,'error_code',sqlstate);end $$;

revoke all on function public.activate_card_effect_v2(uuid,uuid,integer,uuid,bigint),public.resolve_pending_card_trigger(uuid,varchar),public.setup_sandbox_match(varchar) from public,anon;
grant execute on function public.activate_card_effect_v2(uuid,uuid,integer,uuid,bigint),public.resolve_pending_card_trigger(uuid,varchar),public.setup_sandbox_match(varchar) to authenticated;
notify pgrst,'reload schema';
commit;
