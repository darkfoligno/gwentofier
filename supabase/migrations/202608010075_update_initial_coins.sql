-- Migration V36.2: Aumentar o saldo inicial de novos jogadores para 1400 moedas
begin;

create or replace function public.on_auth_user_created()
returns trigger
language plpgsql
security definer set search_path = public
as $$
begin
    insert into public.profiles(id, username, avatar_url)
    values (
        new.id,
        coalesce(new.raw_user_meta_data->>'username', 'Jogador_' || substr(new.id::text, 1, 6)),
        coalesce(
            new.raw_user_meta_data->>'avatar_url',
            'https://api.dicebear.com/7.x/bottts/svg?seed=' || new.id::text
        )
    );

    insert into public.user_roles(user_id, role)
    values (new.id, 'player');

    insert into public.player_wallets(user_id, coins)
    values (new.id, 1400);

    insert into public.player_stats(user_id)
    values (new.id);

    insert into public.wallet_transactions(
        user_id, amount, balance_before, balance_after,
        transaction_type, description
    )
    values (
        new.id, 1400, 0, 1400,
        'initial_balance', 'Saldo inicial da conta (Bônus de Lançamento)'
    );

    return new;
end;
$$;

commit;
