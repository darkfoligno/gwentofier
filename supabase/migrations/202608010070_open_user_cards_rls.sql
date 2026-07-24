-- Migration V36.1: Permitir leitura pública do inventário de cartas para inspeção no modal de contatos
begin;

drop policy if exists user_cards_own_read on public.user_cards;

create policy user_cards_public_read
on public.user_cards for select
to authenticated
using (true);

commit;
