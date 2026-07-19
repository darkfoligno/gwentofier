# Instalação manual do motor das 72 cartas comuns

Docker não é necessário. Use o **SQL Editor** do projeto Supabase e execute um arquivo por vez. Espere a mensagem de sucesso antes de seguir; se algum arquivo falhar, pare e copie o erro completo.

## Antes de começar

1. Faça um backup do banco no painel do Supabase.
2. Confirme que os dois SQLs oficiais do projeto já foram aplicados.
3. O catálogo `202607170005_common_cards_catalog.sql` já foi executado. Não é necessário repeti-lo, mas ele é idempotente.

## Ordem exata

1. `supabase/migrations/202607170006_effect_runtime_foundation.sql`
2. `supabase/migrations/202607170007_common_card_effect_definitions.sql`
3. `supabase/migrations/202607170008_effect_choices_and_contract.sql`
4. `supabase/migrations/202607170009_effect_engine_helpers.sql`
5. `supabase/migrations/202607170010_common_effect_executor.sql`
6. `supabase/migrations/202607170011_common_effect_event_bridge.sql`
7. `supabase/migrations/202607170012_common_effect_runtime_guards.sql`
8. `supabase/migrations/202607170013_effect_visibility_security_realtime.sql`
9. `supabase/migrations/202607170014_common_attack_rules.sql`
10. `supabase/migrations/202607170015_effect_engine_installation_audit.sql`
11. `supabase/migrations/202607180016_fix_create_match_invite_code.sql`
12. `supabase/migrations/202607180017_training_match_and_rls_fix.sql`
13. `supabase/migrations/202607180018_training_bot_turn.sql`
14. `supabase/migrations/202607180019_unified_ban_setup_timer.sql`
15. `supabase/migrations/202607180020_initiative_and_attack_commit.sql`
16. `supabase/migrations/202607180021_safe_action_feed_and_modifiers.sql`
17. `supabase/migrations/202607180022_initial_draw_guard_fix.sql`
18. `supabase/migrations/202607180023_bot_rescue_and_nonfatal_draw_lock.sql`
19. `supabase/migrations/202607180024_strict_v2_blocking_engine.sql`

O arquivo 015 é a trava final: ele aborta se não encontrar as 72 cartas, os 72 códigos, as funções e os gatilhos obrigatórios.

## Verificação no painel

Execute, nesta ordem:

1. `supabase/tests/common_cards_preflight.sql`
2. `supabase/tests/common_cards_catalog_only_check.sql`
3. `supabase/tests/common_effect_engine_check.sql`

Todos os itens de `audit_common_effect_engine()` precisam retornar `ok = true`. O preflight precisa retornar:

- `catalog_cards = 72`
- `missing_cards = 0`
- `cards_without_effect = 0`
- `inactive_cards = 0`
- `missing_images = 0`
- `invalid_elements = 0`

## Teste funcional manual

1. Crie uma partida de treino nova; partidas antigas não recebem retroativamente os snapshots das cartas.
2. Jogue uma carta com gatilho `on_play` e confira `match_effect_execution_log`.
3. Ative uma carta `manual`; confirme o desconto de mana e uma linha em `match_effect_uses`.
4. Declare um ataque com uma carta que possua regra de ataque.
5. Abra outra sessão/conta e confirme a janela de reação e a escolha pendente.
6. Consulte `supabase/tests/common_effect_engine_check.sql`; eventos com `result.failed = true` mostram o SQLSTATE e a mensagem exata.

## Verificação adicional da especificação V2.0

Depois da migração 024, execute `supabase/tests/strict_v2_engine_check.sql`. Todos os itens devem retornar `ok = true`. Crie uma partida de treino nova: partidas antigas preservam seus snapshots e não são uma validação confiável do setup atualizado.

## Git depois do Supabase

Somente depois de todos os checks retornarem verdes:

```powershell
git add .
git commit -m "feat: motor autoritativo para as 72 cartas comuns"
git push -u origin main
```

Não use `--force`: ele não é necessário para esta entrega e pode apagar histórico remoto.
