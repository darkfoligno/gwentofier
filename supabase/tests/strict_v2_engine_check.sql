-- Auditoria estrutural, somente leitura, do contrato V2.0.
select 'engine_state_column' as check_name,
  exists(select 1 from information_schema.columns where table_schema='public' and table_name='matches' and column_name='engine_state') as ok;
select 'dynamic_mana_trigger' as check_name,
  exists(select 1 from pg_trigger where tgname='match_cards_sync_dynamic_mana' and not tgisinternal) as ok;
select 'blocking_attack_state_trigger' as check_name,
  exists(select 1 from pg_trigger where tgname='pending_attacks_sync_engine_state' and not tgisinternal) as ok;
select 'training_setup_v2_signature' as check_name,
  to_regprocedure('public.submit_training_setup(uuid,uuid[],uuid[],bigint)') is not null as ok;
select 'single_paid_and_free_effect_guard' as check_name,
  exists(select 1 from pg_trigger where tgname='validate_match_effect_use_trigger' and not tgisinternal) as ok;
select 'reaction_window_20_seconds' as check_name,
  reaction_window_seconds=20 as ok from public.game_rule_versions where version_name='ofieri-1.0';
select 'turn_8_config' as check_name,
  deterioration_start_turn=8 and deterioration_mode='halve_life_once' as ok from public.game_rule_versions where version_name='ofieri-1.0';
