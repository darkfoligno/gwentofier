-- Migration 202608030250_cron_resolution_attacks.sql
-- Habilita pg_cron, agenda resolução de ataques expirados e garante permissões para o fallback do cliente

-- 1. Habilitar a extensão pg_cron
CREATE EXTENSION IF NOT EXISTS pg_cron;

-- 2. Agendar a rotina no pg_cron para rodar a cada 1 minuto (resolução autônoma)
SELECT cron.schedule(
    'resolve-expired-attacks-cron',
    '* * * * *',
    'SELECT public.resolve_expired_pending_attacks();'
);

-- 3. Conceder permissão de execução para usuários autenticados (necessário para o fallback do frontend)
GRANT EXECUTE ON FUNCTION public.resolve_expired_pending_attacks() TO authenticated;
