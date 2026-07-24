-- Migration 202607310060_purge_inventory_and_mocks.sql
BEGIN;

-- Purga do inventário falso e banco zero
DELETE FROM public.user_cards;
DELETE FROM public.pack_opening_results;
-- Decks também devem ser limpos se referenciam cartas apagadas
DELETE FROM public.deck_cards;
DELETE FROM public.decks;

COMMIT;
