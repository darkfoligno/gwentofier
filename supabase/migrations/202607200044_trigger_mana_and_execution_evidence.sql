-- Corrige o núcleo de gatilhos usado tanto por partidas reais quanto pelo
-- laboratório: mana é comparada com mana_available (não com tamanho da mão)
-- e toda resolução aceita produz evidência técnica consultável.
begin;

create or replace function public.resolve_pending_card_trigger(
  p_trigger_id uuid,
  p_activate boolean,
  p_target_card_id uuid default null,
  p_expected_version bigint default 0
) returns jsonb language plpgsql security definer set search_path='' as $$
declare
  v_actor uuid:=game_private.require_authenticated();
  v_trigger public.pending_card_triggers;
  v_match public.matches;
  v_source public.match_cards;
  v_params jsonb;
  v_result jsonb:='{}'::jsonb;
  v_version bigint;
  v_target uuid:=p_target_card_id;
  v_mana integer;
  v_effect_id uuid;
  v_is_reaction boolean:=false;
begin
  select pct.* into v_trigger
  from public.pending_card_triggers pct
  where pct.id=p_trigger_id and pct.owner_user_id=v_actor and pct.status='pending'
  for update;
  if not found then raise exception 'PENDING_TRIGGER_NOT_FOUND'; end if;

  select m.* into v_match from public.matches m where m.id=v_trigger.match_id for update;
  if v_match.state_version<>p_expected_version then raise exception 'STALE_MATCH_VERSION'; end if;
  if v_trigger.expires_at<=clock_timestamp() then
    update public.pending_card_triggers set status='expired',resolved_at=clock_timestamp() where id=v_trigger.id;
    perform game_private.refresh_match_engine_state(v_trigger.match_id);
    raise exception 'PENDING_TRIGGER_EXPIRED';
  end if;
  if not p_activate then
    update public.pending_card_triggers set status='declined',resolved_at=clock_timestamp() where id=v_trigger.id;
    v_version:=game_private.record_match_action(v_trigger.match_id,v_actor,'effect_trigger_declined',
      jsonb_build_object('source_card_id',v_trigger.source_match_card_id,'effect_code',v_trigger.effect_code,'trigger_type',v_trigger.trigger_type),'{}'::jsonb,p_expected_version);
    perform game_private.refresh_match_engine_state(v_trigger.match_id);
    return jsonb_build_object('activated',false,'state_version',v_version);
  end if;

  select mp.mana_available into v_mana from public.match_players mp
  where mp.match_id=v_trigger.match_id and mp.user_id=v_actor for update;
  if coalesce(v_mana,0)<v_trigger.mana_cost then raise exception 'INSUFFICIENT_MANA'; end if;

  select mc.* into v_source from public.match_cards mc
  where mc.id=v_trigger.source_match_card_id and mc.match_id=v_trigger.match_id and mc.owner_user_id=v_actor for update;
  if not found then raise exception 'EFFECT_SOURCE_NOT_FOUND'; end if;

  select coalesce(x.value->'parameters','{}'::jsonb),ce.id,ce.is_reaction
  into v_params,v_effect_id,v_is_reaction
  from public.match_deck_cards d
  cross join lateral jsonb_array_elements(d.effect_definition) x(value)
  left join public.card_effects ce on ce.card_id=v_source.source_card_id and ce.effect_order=v_trigger.effect_order
  where d.id=v_source.match_deck_card_id and (x.value->>'effect_order')::integer=v_trigger.effect_order
  limit 1;

  if v_target is null and v_trigger.target_mode='graveyard' then
    select mc.id into v_target from public.match_cards mc
    where mc.match_id=v_trigger.match_id and mc.owner_user_id=v_actor and mc.zone='graveyard'
      and mc.id<>v_trigger.source_match_card_id order by random() limit 1;
  end if;

  perform game_private.pay_common_effect_cost(v_trigger.match_id,v_actor,v_trigger.mana_cost);
  v_result:=game_private.execute_common_effect_internal(v_trigger.match_id,v_actor,
    v_trigger.source_match_card_id,v_trigger.effect_code,coalesce(v_params,'{}'::jsonb),v_target,v_trigger.event_payload);

  insert into public.match_effect_uses(match_id,match_card_id,actor_user_id,effect_order,turn_number,is_reaction,mana_spent)
  values(v_trigger.match_id,v_trigger.source_match_card_id,v_actor,v_trigger.effect_order,v_match.current_turn,
    coalesce(v_is_reaction,false),v_trigger.mana_cost) on conflict do nothing;
  insert into public.match_effect_execution_log(match_id,event_id,source_match_card_id,card_effect_id,effect_code,result)
  values(v_trigger.match_id,v_trigger.event_id,v_trigger.source_match_card_id,v_effect_id,v_trigger.effect_code,
    coalesce(v_result,'{}'::jsonb)||jsonb_build_object('trigger_type',v_trigger.trigger_type,'mana_spent',v_trigger.mana_cost));

  update public.pending_card_triggers set status='activated',resolution_action='activate',resolved_at=clock_timestamp() where id=v_trigger.id;
  v_version:=game_private.record_match_action(v_trigger.match_id,v_actor,'effect_activated',
    jsonb_build_object('source_card_id',v_trigger.source_match_card_id,'effect_order',v_trigger.effect_order,
      'effect_code',v_trigger.effect_code,'trigger_type',v_trigger.trigger_type,'mana_spent',v_trigger.mana_cost,'result',v_result),
    '{}'::jsonb,p_expected_version);
  perform game_private.refresh_match_engine_state(v_trigger.match_id);
  return v_result||jsonb_build_object('activated',true,'state_version',v_version,'mana_spent',v_trigger.mana_cost);
end $$;

-- Anabelle troca a identidade completa das instâncias nas mãos. O executor
-- original alterava apenas source_card_id, deixando arte, atributos, mana e
-- efeitos antigos no snapshot imutável exibido pela Arena.
create or replace function game_private.sync_anabelle_hand_snapshots_v20()
returns trigger language plpgsql security definer set search_path='' as $$
declare v_card public.cards;v_effects jsonb;v_row record;
begin
  if new.action_type<>'effect_activated' or new.payload_public->>'effect_code'<>'common_anabelle_transform_hands' then return new;end if;
  select c.* into v_card from public.cards c where c.name='Aparição Noturna' and c.is_active order by c.version desc limit 1;
  if not found then raise exception 'NIGHT_WRAITH_CATALOG_CARD_REQUIRED';end if;
  select coalesce(jsonb_agg(jsonb_build_object('effect_order',e.effect_order,'trigger_type',e.trigger_type,'effect_code',e.effect_code,'target_mode',e.target_mode,'parameters',e.parameters,'priority',e.priority,'is_reaction',e.is_reaction,'once_per_turn',e.once_per_turn,'is_active',e.is_active) order by e.effect_order),'[]'::jsonb)
  into v_effects from public.card_effects e where e.card_id=v_card.id and e.is_active;
  for v_row in select mc.id,mc.match_deck_card_id from public.match_cards mc where mc.match_id=new.match_id and mc.zone='hand' loop
    update public.match_deck_cards set source_card_id=v_card.id,card_version=v_card.version,card_name=v_card.name,image_url=v_card.image_url,
      element=v_card.element,rarity=v_card.rarity,card_type=v_card.card_type,is_golden=v_card.is_golden,base_power=v_card.base_power,
      base_max_life=greatest(1,v_card.base_max_life),effect_mana_cost=v_card.effect_mana_cost,tier=v_card.tier,
      leader_cooldown=v_card.leader_cooldown,effect_definition=v_effects where id=v_row.match_deck_card_id;
    update public.match_cards set source_card_id=v_card.id,base_power=v_card.base_power,maximum_power=v_card.base_power,current_power=v_card.base_power,
      base_max_life=greatest(1,v_card.base_max_life),maximum_life=greatest(1,v_card.base_max_life),current_life=greatest(1,v_card.base_max_life),
      metadata=metadata||jsonb_build_object('transformed_by','common_anabelle_transform_hands') where id=v_row.id;
  end loop;
  return new;
end $$;
drop trigger if exists match_actions_sync_anabelle_v20 on public.match_actions;
create trigger match_actions_sync_anabelle_v20 after insert on public.match_actions for each row execute function game_private.sync_anabelle_hand_snapshots_v20();

-- Reynold precisa realmente concluir o ataque forçado. A ponte V10 retirava o
-- Anão do deck, mas parava antes do dano e, portanto, não cumpria o texto.
create or replace function game_private.resolve_reynold_forced_attack_v20()
returns trigger language plpgsql security definer set search_path='' as $$
declare v_dwarf public.match_cards;v_target uuid;v_turn integer;v_damage jsonb;v_destroyed boolean;
begin
  if new.effect_code<>'common_reynold_forced_dwarf_attack' or new.target_match_card_id is null then return new;end if;
  select mc.* into v_dwarf from public.match_cards mc where mc.id=new.target_match_card_id for update;
  if not found then return new;end if;
  select mc.id into v_target from public.match_cards mc where mc.match_id=new.match_id and mc.controller_user_id<>new.owner_user_id and mc.zone='life' and mc.current_life>0 order by mc.current_life,mc.zone_position limit 1;
  if v_target is null then return new;end if;
  select current_turn into v_turn from public.matches where id=new.match_id;
  v_damage:=game_private.apply_damage_internal(new.match_id,v_target,greatest(0,v_dwarf.current_power),v_turn);
  v_destroyed:=coalesce((v_damage->>'destroyed')::boolean,false);
  if not v_destroyed then
    update public.match_cards mc set zone='banished',zone_position=null,is_face_up=true
    from public.match_deck_cards d where d.id=mc.match_deck_card_id and mc.match_id=new.match_id and mc.owner_user_id=new.owner_user_id and d.card_name='Reynold Longmes';
  end if;
  insert into public.match_effect_execution_log(match_id,source_match_card_id,effect_code,result)
  values(new.match_id,new.source_match_card_id,new.effect_code,jsonb_build_object('forced_attacker_id',v_dwarf.id,'target_card_id',v_target,'damage',v_damage,'reynolds_banished',not v_destroyed));
  return new;
end $$;
drop trigger if exists match_runtime_effects_reynold_attack_v20 on public.match_runtime_effects;
create trigger match_runtime_effects_reynold_attack_v20 after insert on public.match_runtime_effects for each row execute function game_private.resolve_reynold_forced_attack_v20();

revoke all on function public.resolve_pending_card_trigger(uuid,boolean,uuid,bigint) from public,anon;
grant execute on function public.resolve_pending_card_trigger(uuid,boolean,uuid,bigint) to authenticated;
notify pgrst,'reload schema';
commit;
