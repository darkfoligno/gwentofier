# Implantação do catálogo comum e motor de efeitos

Execute no SQL Editor, um arquivo por vez, nesta ordem. Interrompa se qualquer arquivo retornar erro; não avance para o seguinte.

Arquivos já preparados, mas **ainda não execute** enquanto o executor e a ponte de eventos não estiverem presentes:

1. `202607170006_effect_runtime_foundation.sql`
2. `202607170007_common_card_effect_definitions.sql`

Diagnóstico disponível:

3. `tests/common_cards_preflight.sql` — somente leitura

O catálogo `202607170005_common_cards_catalog.sql` já foi aplicado. Ele é idempotente e pode ser reaplicado se necessário.

Resultado obrigatório do preflight:

- `catalog_cards = 72`
- `missing_cards = 0`
- `cards_without_effect = 0`
- `inactive_cards = 0`
- `missing_images = 0`
- `invalid_elements = 0`

Depois dos SQLs, faça o build do front-end e somente então commit/push.
