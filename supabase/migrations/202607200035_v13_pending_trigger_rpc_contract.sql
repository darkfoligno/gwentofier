-- V13.0: contrato JSONB não ambíguo para gatilhos pendentes.
begin;

drop function if exists public.get_my_pending_card_trigger(uuid);
drop function if exists public.get_my_pending_card_trigger(uuid,uuid);

create function public.get_my_pending_card_trigger(p_match_id uuid,p_user_id uuid)
returns jsonb language plpgsql security definer set search_path='' as $$
declare
  v_pending_id uuid;
  v_card_id uuid;
  v_card_name text;
  v_image_url text;
  v_effect_code text;
  v_effect_text text;
  v_element text;
  v_power integer;
  v_life integer;
  v_mana_cost integer;
  v_trigger_reason text;
  v_effect_order integer;
  v_target_mode text;
  v_expected_version bigint;
  v_expires_at timestamptz;
begin
  if p_match_id is null or p_user_id is null then return null::jsonb; end if;
  if auth.uid() is null or auth.uid()<>p_user_id then return null::jsonb; end if;

  update public.pending_card_triggers as expired_pt
  set status='expired',resolved_at=clock_timestamp()
  where expired_pt.match_id=p_match_id and expired_pt.owner_user_id=p_user_id
    and expired_pt.status='pending' and expired_pt.expires_at<=clock_timestamp();
  perform game_private.refresh_match_engine_state(p_match_id);

  select pt.id,pt.source_match_card_id,mdc.card_name,mdc.image_url,
         pt.effect_code,coalesce(pt.description,c.effect_text,''),mdc.element,mc.current_power,mc.current_life,pt.mana_cost,
         pt.trigger_type,pt.effect_order,pt.target_mode,pt.expected_state_version,pt.expires_at
  into v_pending_id,v_card_id,v_card_name,v_image_url,v_effect_code,v_effect_text,
       v_element,v_power,v_life,v_mana_cost,v_trigger_reason,v_effect_order,v_target_mode,v_expected_version,v_expires_at
  from public.pending_card_triggers as pt
  join public.match_cards as mc on mc.id=pt.source_match_card_id and mc.match_id=pt.match_id
  join public.match_deck_cards as mdc on mdc.id=mc.match_deck_card_id
  left join public.cards as c on c.id=mc.source_card_id
  where pt.match_id=p_match_id and pt.owner_user_id=p_user_id and pt.status='pending'
  order by pt.created_at,pt.id limit 1;

  if v_pending_id is null then return null::jsonb; end if;
  return jsonb_build_object(
    'trigger_id',v_pending_id,'card_id',v_card_id,'card_name',v_card_name,
    'image_url',v_image_url,'effect_code',v_effect_code,'effect_text',v_effect_text,
    'element',v_element,'power',v_power,'life',v_life,
    'mana_cost',v_mana_cost,'trigger_reason',v_trigger_reason,
    'effect_order',v_effect_order,'target_mode',v_target_mode,
    'expected_state_version',v_expected_version,'expires_at',v_expires_at,
    'match_id',p_match_id,'owner_user_id',p_user_id
  );
end $$;

create or replace function public.resolve_pending_trigger(p_trigger_id uuid,p_expected_version bigint)
returns jsonb language sql security definer set search_path='' as $$
  select public.resolve_pending_card_trigger(p_trigger_id,false,null,p_expected_version)
$$;

revoke all on function public.get_my_pending_card_trigger(uuid,uuid),public.resolve_pending_trigger(uuid,bigint) from public,anon;
grant execute on function public.get_my_pending_card_trigger(uuid,uuid),public.resolve_pending_trigger(uuid,bigint) to authenticated;
notify pgrst,'reload schema';
commit;
