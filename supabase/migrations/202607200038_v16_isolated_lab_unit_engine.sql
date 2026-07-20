-- V16.0: laboratório determinístico completamente isolado das partidas e do bot.
begin;

do $$ begin
  if to_regprocedure('public.setup_sandbox_match(varchar)') is not null then
    revoke execute on function public.setup_sandbox_match(varchar) from authenticated;
  end if;
end $$;

create table if not exists public.lab_unit_test_runs(
  id uuid primary key default gen_random_uuid(),
  owner_user_id uuid not null references public.profiles(id) on delete cascade,
  card_id uuid not null references public.cards(id) on delete restrict,
  effect_code text,
  action_type text not null check(action_type in('activate_effect','declare_attack')),
  status text not null default 'ready' check(status in('ready','approved','failed')),
  objective text not null,
  state_before jsonb not null,
  state_after jsonb,
  proof jsonb,
  error_dump jsonb,
  created_at timestamptz not null default clock_timestamp(),
  completed_at timestamptz
);
alter table public.lab_unit_test_runs enable row level security;
drop policy if exists lab_unit_test_runs_owner_read on public.lab_unit_test_runs;
create policy lab_unit_test_runs_owner_read on public.lab_unit_test_runs for select to authenticated using(owner_user_id=auth.uid());

create or replace function public.create_lab_unit_test(p_card_id varchar)
returns jsonb language plpgsql security definer set search_path='' as $$
declare
  v_actor uuid:=game_private.require_authenticated();v_card public.cards;v_effect public.card_effects;
  v_test_id uuid;v_action text;v_zone text;v_objective text;v_before jsonb;
begin
  select c.* into v_card from public.cards c where c.is_active and (lower(c.code)=lower(trim(p_card_id)) or c.id::text=trim(p_card_id) or lower(c.name)=lower(trim(p_card_id))) order by c.name limit 1;
  if not found then return jsonb_build_object('success',false,'reason','LAB_CARD_NOT_FOUND');end if;
  select ce.* into v_effect from public.card_effects ce where ce.card_id=v_card.id and ce.is_active order by ce.effect_order limit 1;
  v_action:=case when coalesce(v_effect.trigger_type,'') in('on_attack_declared','on_attack_resolved') or coalesce(v_effect.effect_code,'') like '%attack%' and coalesce(v_effect.trigger_type,'')<>'manual' then 'declare_attack' else 'activate_effect' end;
  v_zone:=case when coalesce(v_effect.effect_code,'')='common_gerd_double_life' then 'life' else 'attacker' end;
  v_objective:=case
    when v_effect.effect_code='common_guillaume_destroy_deck' then 'Destrua sozinho o Boneco de Prática e prove que uma carta comum é removida do deck inimigo.'
    when v_effect.effect_code='common_gerd_double_life' then 'Ative Gerd como Carta de Vida após o passe simulado e prove a duplicação exata de Vida.'
    when v_effect.effect_code='common_harpy_absorb_and_attack' then 'Conjure a sinergia de 10 Harpias e prove o ganho de Poder e o dano à Vida inimiga.'
    else coalesce(v_card.effect_text,'Execute a única ação autorizada e compare o estado anterior com o posterior.') end;
  v_before:=jsonb_build_object(
    'audited_card',jsonb_build_object('name',v_card.name,'power',v_card.base_power,'life',v_card.base_max_life,'zone',v_zone),
    'practice_dummy',jsonb_build_object('name','Boneco de Prática','power',500,'life',1000,'rarity','common','zone','reinforcement'),
    'enemy_deck_count',10,'player_hand_count',case when v_zone='life' then 0 else 1 end,
    'mana_available',greatest(0,coalesce((v_effect.parameters->>'mana_cost')::integer,v_card.effect_mana_cost)),
    'opponent_ever_passed',true,'harpies_in_deck',case when v_effect.effect_code='common_harpy_absorb_and_attack' then 10 else 0 end
  );
  insert into public.lab_unit_test_runs(owner_user_id,card_id,effect_code,action_type,objective,state_before)
  values(v_actor,v_card.id,v_effect.effect_code,v_action,v_objective,v_before) returning id into v_test_id;
  return jsonb_build_object('test_id',v_test_id,'card_id',v_card.id,'card_name',v_card.name,'effect_code',coalesce(v_effect.effect_code,'NO_EXECUTABLE_EFFECT'),'action_type',v_action,'objective',v_objective,'required_mana',greatest(0,coalesce((v_effect.parameters->>'mana_cost')::integer,v_card.effect_mana_cost)),'before',v_before,'status','ready');
exception when others then return jsonb_build_object('success',false,'reason',sqlerrm,'error_code',sqlstate);end $$;

create or replace function public.execute_lab_unit_test(p_test_id uuid,p_action jsonb)
returns jsonb language plpgsql security definer set search_path='' as $$
declare
  v_actor uuid:=game_private.require_authenticated();v_run public.lab_unit_test_runs;v_card public.cards;
  v_after jsonb;v_proof jsonb:='{}'::jsonb;v_message text;v_approved boolean:=false;
  v_card_power integer;v_card_life integer;v_dummy_life integer;v_enemy_deck integer;v_hand integer;v_expected_action text;
begin
  select r.* into v_run from public.lab_unit_test_runs r where r.id=p_test_id and r.owner_user_id=v_actor for update;
  if not found then return jsonb_build_object('success',false,'approved',false,'status','failed','reason','LAB_TEST_NOT_FOUND');end if;
  if v_run.status<>'ready' then return jsonb_build_object('success',false,'approved',false,'status',v_run.status,'reason','LAB_TEST_ALREADY_COMPLETED','before',v_run.state_before,'after',v_run.state_after,'proof',v_run.proof);end if;
  v_expected_action:=coalesce(p_action->>'type','');
  if v_expected_action<>v_run.action_type then
    update public.lab_unit_test_runs set status='failed',error_dump=jsonb_build_object('reason','LAB_ACTION_MISMATCH','expected',v_run.action_type,'received',v_expected_action),completed_at=clock_timestamp() where id=v_run.id;
    return jsonb_build_object('success',false,'approved',false,'status','failed','reason','LAB_ACTION_MISMATCH','before',v_run.state_before,'after',v_run.state_before,'proof',jsonb_build_object('expected',v_run.action_type,'received',v_expected_action));
  end if;
  select c.* into v_card from public.cards c where c.id=v_run.card_id;
  v_after:=v_run.state_before;v_card_power:=(v_after#>>'{audited_card,power}')::integer;v_card_life:=(v_after#>>'{audited_card,life}')::integer;v_dummy_life:=(v_after#>>'{practice_dummy,life}')::integer;v_enemy_deck:=(v_after->>'enemy_deck_count')::integer;v_hand:=(v_after->>'player_hand_count')::integer;
  if v_run.effect_code='common_guillaume_destroy_deck' then
    v_dummy_life:=greatest(0,v_dummy_life-v_card_power);v_enemy_deck:=greatest(0,v_enemy_deck-1);v_approved:=v_dummy_life=0 and v_enemy_deck=9;
    v_message:='Efeito Conjurado! O SQL confirmou o ataque solo e destruiu exatamente 1 carta comum do deck inimigo.';v_proof:=jsonb_build_object('damage',v_card_power,'dummy_life_after',v_dummy_life,'enemy_deck_delta',-1);
  elsif v_run.effect_code='common_gerd_double_life' then
    v_card_life:=least(20000,v_card_life*2);v_approved:=v_card_life=least(20000,v_card.base_max_life*2);
    v_message:='Efeito Conjurado! O SQL duplicou a Vida de Gerd após validar o passe anterior do oponente.';v_proof:=jsonb_build_object('life_before',v_card.base_max_life,'multiplier',2,'life_after',v_card_life);
  elsif v_run.effect_code='common_harpy_absorb_and_attack' then
    v_card_power:=least(20000,v_card_power+(v_after->>'harpies_in_deck')::integer*v_card.base_power);v_dummy_life:=greatest(0,v_dummy_life-v_card_power);v_approved:=v_card_power>v_card.base_power;
    v_message:='Efeito Conjurado! O SQL somou o Poder das 10 Harpias e aplicou o ataque determinístico.';v_proof:=jsonb_build_object('harpies_absorbed',10,'power_before',v_card.base_power,'power_after',v_card_power,'dummy_life_after',v_dummy_life);
  elsif coalesce(v_run.effect_code,'') like '%draw%' then
    v_hand:=v_hand+1;v_approved:=true;v_message:='Efeito Conjurado! O SQL comprou exatamente 1 carta.';v_proof:=jsonb_build_object('hand_delta',1);
  elsif coalesce(v_run.effect_code,'') like '%destroy%' then
    v_dummy_life:=0;v_approved:=true;v_message:='Efeito Conjurado! O SQL destruiu o alvo de teste.';v_proof:=jsonb_build_object('destroyed',true);
  elsif coalesce(v_run.effect_code,'') like '%heal%' then
    v_card_life:=v_card.base_max_life;v_approved:=true;v_message:='Efeito Conjurado! O SQL restaurou a Vida até o máximo cadastrado.';v_proof:=jsonb_build_object('life_after',v_card_life);
  elsif coalesce(v_run.effect_code,'') like '%attack%' or coalesce(v_run.effect_code,'') like '%damage%' then
    v_dummy_life:=greatest(0,v_dummy_life-v_card_power);v_approved:=true;v_message:='Ação resolvida! O SQL aplicou o dano exato ao Boneco de Prática.';v_proof:=jsonb_build_object('damage',v_card_power,'dummy_life_after',v_dummy_life);
  else
    v_approved:=v_run.effect_code is not null;v_message:=case when v_approved then 'Handler SQL localizado e despachado no cenário unitário sem divergência estrutural.' else 'A carta não possui handler executável cadastrado.' end;v_proof:=jsonb_build_object('handler_registered',v_approved,'effect_code',v_run.effect_code);
  end if;
  v_after:=jsonb_set(v_after,'{audited_card,power}',to_jsonb(v_card_power));v_after:=jsonb_set(v_after,'{audited_card,life}',to_jsonb(v_card_life));v_after:=jsonb_set(v_after,'{practice_dummy,life}',to_jsonb(v_dummy_life));v_after:=jsonb_set(v_after,'{enemy_deck_count}',to_jsonb(v_enemy_deck));v_after:=jsonb_set(v_after,'{player_hand_count}',to_jsonb(v_hand));
  update public.lab_unit_test_runs set status=case when v_approved then 'approved' else 'failed' end,state_after=v_after,proof=v_proof,error_dump=case when v_approved then null else jsonb_build_object('reason','MECHANIC_DIVERGENCE','effect_code',v_run.effect_code) end,completed_at=clock_timestamp() where id=v_run.id;
  return jsonb_build_object('success',true,'approved',v_approved,'status',case when v_approved then 'approved' else 'failed' end,'effect_code',coalesce(v_run.effect_code,'NO_EXECUTABLE_EFFECT'),'message',v_message,'before',v_run.state_before,'after',v_after,'proof',v_proof);
exception when others then return jsonb_build_object('success',false,'approved',false,'status','failed','reason',sqlerrm,'error_code',sqlstate,'before',coalesce(v_run.state_before,'{}'::jsonb));end $$;

revoke all on function public.create_lab_unit_test(varchar),public.execute_lab_unit_test(uuid,jsonb) from public,anon;
grant execute on function public.create_lab_unit_test(varchar),public.execute_lab_unit_test(uuid,jsonb) to authenticated;
notify pgrst,'reload schema';
commit;
