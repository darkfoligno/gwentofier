# Auditoria mecânica — cartas comuns do Discord

Este documento não considera `effect_text` como implementação. Cada linha descreve o gatilho, a mecânica autoritativa necessária e o handler sugerido. Códigos marcados como **existente** já possuem resolução básica no SQL; todos os demais precisam ser implementados e testados no servidor antes de ativar a carta.

## Bloqueios de importação

- `cards.image_url` e `cards.element` são obrigatórios.
- `cards.base_max_life` aceita apenas valores de 1 a 20.000. As cartas 0, 23, 28, 33, 39, 64 e 67 possuem vida 0; Berseker possui vida e poder indefinidos.
- `rarity` deve ser `common`; `card_type` precisa ser `normal` ou `leader`.
- “Defesa” foi interpretada como uma carta nas zonas `life` ou `reinforcement` conforme o texto específico; isso deve ser confirmado onde estiver ambíguo.
- Efeitos de escolha exigem uma janela de seleção no front-end; RNG deve ser feito no PostgreSQL, nunca no cliente.

## Inventário carta por carta

| # | Carta | Gatilho | Handler/mecânica proposta | Situação |
|---:|---|---|---|---|
| 0 | Filho da Puta Junior | passiva na mão | `block_owner_draw_while_in_hand`; token invocado, fora do gacha | Novo; requer suporte a token e bloqueio de compra |
| 1 | Dijkistra | `on_discard` | `draw_filtered` quantidade 3, raridade common | Novo filtro sobre `draw` existente |
| 2 | Duny | passiva em campo | `graveyard_lock`; impede `revive` e `return_to_hand` de destruídas | Novo efeito contínuo |
| 3 | Javali | declaração/resolução de ataque | `attack_hand_rarity_gate` + `suppress_reinforcement_reveal` | Novo; altera pipeline de ataque |
| 4 | Erinia | manual | `steal_hand_by_rarity` + `discard_selected_own` | Novo fluxo composto e seleção |
| 5 | Endriuga | manual | `damage_scaled_by_zone_count`, alvo life, escala por reinforcement inimigo | Novo cálculo; usa dano interno |
| 6 | Rei Henselt | manual | `multi_attack_life_if_no_reinforcement`, até 3 alvos | Novo handler multi-alvo |
| 7 | Aparição Diurna | ataque | `direct_attack_random_life_if_graveyard_count` > 4 | Novo condicionador de ataque |
| 8 | Aparição Noturna | `on_destroyed` em reinforcement | `silence_random_hand_card` inimiga | Novo status de silêncio |
| 9 | Keira Metz | `on_destroyed` em life | `replace_life_from_deck_filtered`, common | Novo movimento deck→life |
| 10 | Carniçal | `on_destroyed` simultâneo | `revive_if_same_name_destroyed_together` | Novo detector de lote; revive base existente |
| 11 | Elemental | reaction ao receber ataque | `prevent_attack_damage_if_element`, M&F | Novo modificador de dano |
| 12 | Troll | manual | `discard_all_own_hand_then_draw`, quantidade 2 | Novo composto; draw existente |
| 13 | Berseker | manual | `copy_random_graveyard_stats` inimigo | Novo; atributos ainda indefinidos |
| 14 | Gargula | reaction | `cancel_attack_if_attacker_count`, exatamente 1 | Novo pipeline de ataque |
| 15 | Puero | manual | `destroy_random_field_by_rarity`, legendary, ambos os lados | Novo RNG; destroy existente |
| 16 | Necroso | `on_destroyed` em life/reinforcement | `destroy_random_hand_by_power_below_source_life` | Novo filtro/RNG |
| 17 | Fada | `on_turn_start` enquanto em campo | `extra_draw` 1 | Requer despachante automático; draw existente |
| 18 | Shani | `on_destroyed` | `redeploy_to_lower_life_slot_full_health` | Novo substituto de destruição |
| 19 | Barghest | `on_destroyed` por ataque | `return_destroyed_to_deck_if_overkill_ratio`, 3x | Novo pós-dano |
| 20 | Barroso | saída forçada da mão | `discard_all_opponent_hand` | Novo gatilho de mudança de zona |
| 21 | Carniçal Atroz | `on_attack_resolved` sobrevivendo em reinforcement | `draw_filtered`, epic | Novo filtro sobre draw |
| 22 | Pantera | ataque | `direct_attack_life_if_hand_advantage` | Novo condicionador |
| 23 | Rei dos Mendigos | manual | `destroy_life_if_only_card_in_hand` | Novo condicionador; vida 0 inválida |
| 24 | Cutelo | antes do ataque | `discard_cost_enable_direct_attack`, custo 3 cartas | Novo custo alternativo |
| 25 | Lugos Todo Roxo | manual/passivo de próxima compra | `next_draw_permanent_power_multiplier_filtered`, Civil, x2 | Novo efeito adiado |
| 26 | Nekker | `on_destroyed` | `next_turn_mana_bonus_if_deck_name`, +1 | Novo efeito agendado |
| 27 | Afogador | `on_destroyed` em reinforcement | `mill_opponent`, 1 | Novo deck→graveyard |
| 28 | Lobo | `on_attack_resolved` contra life | `deck_name_power_multiplier`, Lobo, x2 | Novo modificador de snapshots; vida 0 inválida |
| 29 | Urso | `on_attack_resolved` sobrevivendo em reinforcement | `double_life_then_replace_lower_life` | Novo movimento/transformação |
| 30 | Winkler Vosgad | manual | `silence_field_card_filtered`, Elfica | Novo silêncio |
| 31 | Baltazar | reaction a ataque direto | `discard_cost_cancel_direct_attack`, custo 1 | Novo pipeline de reação |
| 32 | General da Ordem | destruição simultânea | `permanent_max_mana_delta`, -1, requer Civil junto | Novo recurso de mana máxima |
| 33 | Totem | `on_destroyed` | `tutor_all_names_zero_cost_if_graveyard_name_count`, Liche/Liche Ancião | Novo tutor e modificador de custo; vida 0 inválida |
| 34 | Dilion Vorgues | manual | `deck_mana_cost_delta_all`, -1 | Novo modificador persistente |
| 35 | Reynold Longmes | manual | `deck_card_forced_attack`; se falhar, `ban_deck_name` | Novo ataque virtual e banimento |
| 36 | Tamara Stranger | manual | `tutor_choose_filtered`, rare | Novo modal de seleção |
| 37 | Jarl de An Skellige | manual em life | `global_effect_lock_by_rarity`, legendary | Novo efeito contínuo |
| 38 | Halmar de Skellige | manual | `random_direct_attack_branch`, 55% inimigo/45% duas life próprias | Novo RNG/multi-alvo |
| 39 | Dudu Biberveld | manual | `copy_random_opponent_hand_effect_with_cost_delta`, +2 | Novo efeito dinâmico; vida 0 no texto? consta 1000, válida |
| 40 | Thaler | manual | `steal_opponent_deck_to_own_graveyard` | Novo controle/propriedade |
| 41 | Vimme Vivaldi | manual | `mutual_tutor_choose_with_cost_delta`, +2 | Novo fluxo de escolhas para ambos |
| 42 | Casimir Bassi | manual | `destroy_life_if_deck_smaller` | Novo condicionador; destroy existente |
| 43 | Hattori | manual | `discard_random_own_then_next_draw_cost_reduction` | Novo efeito adiado |
| 44 | Milton de Peyrac-Peyran | manual | `return_source_to_hand_at_turn_end` | Novo agendamento; return existente |
| 45 | Síle de Tansarville | manual | `tutor_highest_mana_filtered`, M&F | Novo tutor determinístico |
| 46 | Gaetan | `on_attack_resolved` destruiu sozinho | `discard_all_opponent_hand_if_element`, Witcher | Novo condicionador/purge |
| 47 | Tomira | manual | `heal_damaged_life` | Usa `heal` existente com validação de zona/dano |
| 48 | Ves | ataque | `random_direct_attack_if_only_paid_card_in_hand` | Novo condicionador; texto ambíguo |
| 49 | Kiyan | reaction no turno da destruição | `grant_deck_card_effect_cost_immunity`, M&F aleatória | Novo escudo persistente |
| 50 | Corine | manual | `reveal_random_opponent_hand_to_actor` | Novo payload privado temporário |
| 51 | Guillaume | `on_attack_resolved` destruiu sozinho | `destroy_opponent_deck_filtered`, common/rare | Novo deck destruction |
| 52 | Anabelle | manual | `transform_all_hands_to_card`, Aparição Noturna | Novo sistema de transformação |
| 53 | Vlodimir von Everec | manual | `replace_highest_rarity_life_from_lowest_rarity_deck_both` | Novo composto bilateral; texto ambíguo (“troque”) |
| 54 | Joachim von Gratz | manual em life | `revive_random_filtered`, epic | Filtro novo sobre `revive` existente |
| 55 | Gerd | manual em life | `double_source_life_if_opponent_ever_passed` | Usa `max_life_delta` com histórico de passe |
| 56 | Cão Selvagem | ataque | `direct_attack_selected_life_if_active_element_life`, Bestiário | Novo condicionador |
| 57 | Harpia | manual/ataque | `absorb_deck_name_power_then_attack_farthest_life` | Novo agregador + ataque |
| 58 | Vaca | `on_destroyed` em reinforcement | `tutor_name_from_deck_or_graveyard`, Chorabashe | Novo tutor multizona |
| 59 | Ciri criança | manual | `attack_all_life` com custo dinâmico por Witcher no deck | Novo multi-ataque e custo calculado |
| 60 | Barnabas | manual | `draw_if_life_ever_destroyed`, 1 | Condicionador sobre draw existente |
| 61 | Eveline Gallo | manual | `steal_highest_mana_hand_card` | Novo controle/propriedade |
| 62 | Nenneke | manual | `life_steal_nonlethal`, 1000, alvos aleatórios | Novo dano não letal + cura |
| 63 | Carpeado | manual | `temporary_hand_mana_override_both`, 0 até próximo turno de cada um | Novo modificador com expiração por jogador |
| 64 | Marlene | manual da mão ou life | `transform_source_from_opponent_graveyard_filtered`, Bestiário aleatório | Novo sistema de transformação; vida 0 inválida |
| 65 | Anna Strenger | manual | `hand_mana_cost_delta_both`, +1 | Novo modificador bilateral |
| 66 | Skjall | passiva no deck | `substitute_named_card_destruction_from_deck`, nome contém Ciri | Novo interceptor global de destruição |
| 67 | Morkvarg | `on_destroyed` | `curse_opponent_hand_token`, máximo 4, não jogável/descartável | Novo bloqueio de carta; vida 0 inválida |
| 68 | Udalryk | manual | `discard_opponent_hand_then_random_self_to_life`, 35% | Novo composto/RNG |
| 69 | Ida Emean | manual | `peek_opponent_deck_top`, 2 | Novo payload privado |
| 70 | Mestre da Arena | manual se não houver reinforcement | `destroy_life_filtered`, common | Novo condicionador/filtro |
| 71 | Feiticeira Mabel | manual | `destroy_random_field_filtered`, Witcher inimigo | Novo filtro/RNG sobre destroy |

## Famílias novas necessárias

1. **Despachante de eventos:** processar `on_play`, `on_destroyed`, `on_turn_start`, `on_turn_end`, `on_draw`, `on_discard`, `on_attack_declared` e `on_attack_resolved` dentro da mesma transação da ação causadora.
2. **Efeitos contínuos:** registrar bloqueios, imunidades e alterações de regra com origem, escopo, início e expiração.
3. **Efeitos agendados:** “próxima compra”, “próximo turno” e “fim do turno”.
4. **Filtros e seletores autoritativos:** nome, elemento, raridade, mana, zona, maior/menor e RNG PostgreSQL.
5. **Transformação/token:** criar instâncias temporárias sem contaminar `user_cards` ou o catálogo comercial.
6. **Informação privada:** revelar mão/topo somente ao jogador autorizado, sem publicar em `match_public_states`.
7. **Ataques especiais:** ataque direto, multi-alvo, cancelamento, prevenção e substituição de dano integrados a `pending_attacks`.
8. **Custos alternativos:** descarte de cartas e custo dinâmico antes da resolução.
9. **Composição atômica:** efeitos com duas ou mais etapas precisam falhar integralmente se alguma etapa for inválida.

## Ordem segura de implementação

1. Criar staging e resolver dados ausentes.
2. Implementar o despachante e uma fila interna de eventos com limite anti-loop.
3. Implementar seletores/filtros e modificadores temporários.
4. Integrar reações e ataques especiais ao motor consolidado.
5. Implementar transformação, tokens e informação privada.
6. Criar testes SQL por carta: sucesso, alvo inválido, mana insuficiente, turno errado, repetição e concorrência.
7. Somente então publicar registros em `cards`/`card_effects` com `is_active=true`.
