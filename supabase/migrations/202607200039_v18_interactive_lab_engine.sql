-- V18.0: fluxo manual por fases e proibição de aprovação sem mutação comprovada.
begin;

alter table public.lab_unit_test_runs add column if not exists interaction_phase text not null default 'WAITING_USER_INPUT';
alter table public.lab_unit_test_runs add column if not exists current_state jsonb;

create or replace function game_private.prepare_interactive_lab_run_v18()
returns trigger language plpgsql security definer set search_path='' as $$
begin
  if new.action_type='declare_attack' then
    new.state_before:=jsonb_set(new.state_before,'{audited_card,zone}','"hand"'::jsonb);
    new.state_before:=jsonb_set(new.state_before,'{enemy_deck_count}','3'::jsonb);
    new.interaction_phase:='WAITING_CARD_PLACEMENT';
  else new.interaction_phase:='WAITING_USER_INPUT';end if;
  new.current_state:=new.state_before;return new;
end $$;
drop trigger if exists lab_run_prepare_interactive_v18 on public.lab_unit_test_runs;
create trigger lab_run_prepare_interactive_v18 before insert on public.lab_unit_test_runs for each row execute function game_private.prepare_interactive_lab_run_v18();

do $$ begin
  if to_regprocedure('public.create_lab_unit_test_v16_core(varchar)') is null then
    alter function public.create_lab_unit_test(varchar) rename to create_lab_unit_test_v16_core;
  end if;
end $$;
revoke all on function public.create_lab_unit_test_v16_core(varchar) from public,anon,authenticated;
create or replace function public.create_lab_unit_test(p_card_id varchar)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_result jsonb;v_run public.lab_unit_test_runs;
begin
  v_result:=public.create_lab_unit_test_v16_core(p_card_id);
  if v_result->>'test_id' is null then return v_result;end if;
  select r.* into v_run from public.lab_unit_test_runs r where r.id=(v_result->>'test_id')::uuid and r.owner_user_id=auth.uid();
  return v_result||jsonb_build_object('before',v_run.current_state,'interaction_phase',v_run.interaction_phase,'status','WAITING_USER_INPUT');
end $$;

create or replace function public.play_lab_unit_test_card(p_test_id uuid,p_target_zone varchar)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_actor uuid:=game_private.require_authenticated();v_run public.lab_unit_test_runs;v_state jsonb;
begin
  select r.* into v_run from public.lab_unit_test_runs r where r.id=p_test_id and r.owner_user_id=v_actor for update;
  if not found then return jsonb_build_object('success',false,'reason','LAB_TEST_NOT_FOUND');end if;
  if v_run.status<>'ready' or v_run.interaction_phase<>'WAITING_CARD_PLACEMENT' then return jsonb_build_object('success',false,'reason','LAB_CARD_PLACEMENT_NOT_ALLOWED','phase',v_run.interaction_phase);end if;
  if lower(trim(p_target_zone))<>'attacker' then return jsonb_build_object('success',false,'reason','LAB_TARGET_ZONE_MUST_BE_ATTACKER');end if;
  v_state:=jsonb_set(v_run.current_state,'{audited_card,zone}','"attacker"'::jsonb);
  update public.lab_unit_test_runs set current_state=v_state,interaction_phase='WAITING_USER_INPUT' where id=v_run.id;
  return jsonb_build_object('success',true,'http_status',200,'test_id',v_run.id,'interaction_phase','WAITING_USER_INPUT','state',v_state,'mutation',jsonb_build_object('card_zone','hand -> attacker'));
end $$;

create or replace function game_private.finish_interactive_lab_action_v18(p_test_id uuid,p_action_type text,p_action jsonb)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_actor uuid:=game_private.require_authenticated();v_run public.lab_unit_test_runs;v_result jsonb;v_after jsonb;v_before jsonb;v_mutated boolean;v_cost integer:=0;
begin
  select r.* into v_run from public.lab_unit_test_runs r where r.id=p_test_id and r.owner_user_id=v_actor for update;
  if not found then return jsonb_build_object('success',false,'approved',false,'reason','LAB_TEST_NOT_FOUND');end if;
  if v_run.status<>'ready' or v_run.interaction_phase<>'WAITING_USER_INPUT' then return jsonb_build_object('success',false,'approved',false,'reason','LAB_NOT_WAITING_USER_INPUT','phase',v_run.interaction_phase);end if;
  if v_run.action_type<>p_action_type then return jsonb_build_object('success',false,'approved',false,'reason','LAB_ACTION_MISMATCH','expected',v_run.action_type,'received',p_action_type);end if;
  update public.lab_unit_test_runs set state_before=current_state where id=v_run.id;
  v_result:=public.execute_lab_unit_test(p_test_id,p_action||jsonb_build_object('type',p_action_type));
  v_before:=coalesce(v_result->'before','{}'::jsonb);v_after:=coalesce(v_result->'after','{}'::jsonb);
  if p_action_type='activate_effect' then
    select greatest(0,coalesce((ce.parameters->>'mana_cost')::integer,c.effect_mana_cost,0)) into v_cost from public.cards c left join public.card_effects ce on ce.card_id=c.id and ce.is_active where c.id=v_run.card_id order by ce.effect_order limit 1;
    v_after:=jsonb_set(v_after,'{mana_available}',to_jsonb(greatest(0,coalesce((v_before->>'mana_available')::integer,0)-v_cost)),true);
    v_result:=jsonb_set(v_result,'{after}',v_after,true)||jsonb_build_object('mana_paid',v_cost);
  end if;
  if v_run.effect_code='common_guillaume_destroy_deck'
     and coalesce((v_after#>>'{practice_dummy,life}')::integer,-1)=0
     and coalesce((v_after->>'enemy_deck_count')::integer,-1)=coalesce((v_before->>'enemy_deck_count')::integer,0)-1 then
    v_result:=v_result||jsonb_build_object('approved',true,'status','approved','message','Guillaume destruiu a defesa e removeu exatamente 1 carta comum do deck inimigo.');
    update public.lab_unit_test_runs set status='approved',error_dump=null where id=p_test_id;
  end if;
  v_mutated:=v_before is distinct from v_after;
  if coalesce((v_result->>'approved')::boolean,false) and (not v_mutated or v_result->'proof' ? 'handler_registered') then
    update public.lab_unit_test_runs set status='failed',interaction_phase='COMPLETED',current_state=v_after,error_dump=jsonb_build_object('reason','NO_PROVABLE_STATE_MUTATION','original_result',v_result) where id=p_test_id;
    return v_result||jsonb_build_object('success',true,'approved',false,'status','failed','http_status',200,'reason','NO_PROVABLE_STATE_MUTATION','message','O handler respondeu, mas nenhuma consequência mecânica visível foi comprovada.');
  end if;
  update public.lab_unit_test_runs set interaction_phase='COMPLETED',current_state=v_after where id=p_test_id;
  return v_result||jsonb_build_object('http_status',200,'interaction_phase','COMPLETED','state_mutated',v_mutated);
end $$;

create or replace function public.lab_activate_card_effect(p_test_id uuid,p_action jsonb default '{}'::jsonb)
returns jsonb language sql security definer set search_path='' as $$select game_private.finish_interactive_lab_action_v18(p_test_id,'activate_effect',coalesce(p_action,'{}'::jsonb))$$;
create or replace function public.lab_declare_attack(p_test_id uuid,p_action jsonb default '{}'::jsonb)
returns jsonb language sql security definer set search_path='' as $$select game_private.finish_interactive_lab_action_v18(p_test_id,'declare_attack',coalesce(p_action,'{}'::jsonb))$$;

revoke all on function public.execute_lab_unit_test(uuid,jsonb),public.create_lab_unit_test(varchar),public.play_lab_unit_test_card(uuid,varchar),public.lab_activate_card_effect(uuid,jsonb),public.lab_declare_attack(uuid,jsonb) from public,anon;
revoke execute on function public.execute_lab_unit_test(uuid,jsonb) from authenticated;
grant execute on function public.create_lab_unit_test(varchar),public.play_lab_unit_test_card(uuid,varchar),public.lab_activate_card_effect(uuid,jsonb),public.lab_declare_attack(uuid,jsonb) to authenticated;
notify pgrst,'reload schema';
commit;
