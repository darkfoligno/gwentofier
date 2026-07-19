# Auditoria geral das 72 cartas comuns

Escopo auditado: catálogo `COMMON_000` a `COMMON_071`, definições em `card_effects`, executor especializado, pontes automáticas, guardas persistentes, regras de ataque e RPC de ativação V10.

## Legenda

- **100% OPERACIONAL VIA SQL**: execução direta pelo executor/RPC, com validação, custo e registro autoritativos.
- **DEPENDENTE DE TRIGGER**: execução completa, mas disparada por evento de zona, turno, ataque, reação ou guarda persistente.
- Não há código sem definição nem carta sem handler registrado. O banco deve receber as migrações em ordem, incluindo `202607190032_v10_effect_bridge_and_bot_setup.sql`.

| Código | Nome | Mana | Categoria | effect_code | Status |
|---|---|---:|---|---|---|
| COMMON_000 | Filho da Puta Junior | 0 | Passivo | `common_block_draw_in_hand` | DEPENDENTE DE TRIGGER |
| COMMON_001 | Dijkistra | 0 | Automático | `common_draw_three_common` | DEPENDENTE DE TRIGGER |
| COMMON_002 | Duny | 0 | Passivo | `common_graveyard_return_lock` | DEPENDENTE DE TRIGGER |
| COMMON_003 | Javali | 0 | Ataque | `common_javali_attack_rules` | DEPENDENTE DE TRIGGER |
| COMMON_004 | Erinia | 0 | Manual | `common_erinia_exchange` | 100% OPERACIONAL VIA SQL |
| COMMON_005 | Endriuga | 2 | Manual | `common_endriuga_scaled_damage` | 100% OPERACIONAL VIA SQL |
| COMMON_006 | Rei Henselt | 7 | Manual | `common_henselt_attack_all_life` | 100% OPERACIONAL VIA SQL |
| COMMON_007 | Aparição Diurna | 2 | Ataque | `common_day_wraith_direct_attack` | DEPENDENTE DE TRIGGER |
| COMMON_008 | Aparição Noturna | 1 | Automático | `common_night_wraith_silence_hand` | DEPENDENTE DE TRIGGER |
| COMMON_009 | Keira Metz | 3 | Automático | `common_keira_replace_life` | DEPENDENTE DE TRIGGER |
| COMMON_010 | Carniçal | 2 | Automático | `common_ghoul_group_revive` | DEPENDENTE DE TRIGGER |
| COMMON_011 | Elemental | 3 | Reação | `common_elemental_prevent_damage` | DEPENDENTE DE TRIGGER |
| COMMON_012 | Troll | 2 | Manual | `common_troll_discard_draw` | 100% OPERACIONAL VIA SQL |
| COMMON_013 | Berseker | 0 | Manual | `common_berserker_copy_stats` | 100% OPERACIONAL VIA SQL |
| COMMON_014 | Gargula | 2 | Reação | `common_gargoyle_cancel_single_attack` | DEPENDENTE DE TRIGGER |
| COMMON_015 | Puero | 3 | Manual | `common_puero_destroy_random_legendary` | 100% OPERACIONAL VIA SQL |
| COMMON_016 | Necroso | 2 | Automático | `common_necrophage_destroy_hand` | DEPENDENTE DE TRIGGER |
| COMMON_017 | Fada | 2 | Automático | `common_fairy_extra_draw` | DEPENDENTE DE TRIGGER |
| COMMON_018 | Shani | 4 | Automático | `common_shani_redeploy_life` | DEPENDENTE DE TRIGGER |
| COMMON_019 | Barghest | 2 | Automático | `common_barghest_overkill_to_deck` | DEPENDENTE DE TRIGGER |
| COMMON_020 | Barroso | 0 | Automático | `common_barroso_purge_enemy_hand` | DEPENDENTE DE TRIGGER |
| COMMON_021 | Carniçal Atroz | 3 | Ataque | `common_atrocious_ghoul_draw_epic` | DEPENDENTE DE TRIGGER |
| COMMON_022 | Pantera | 4 | Ataque | `common_panther_direct_life` | DEPENDENTE DE TRIGGER |
| COMMON_023 | Rei dos Mendigos | 0 | Manual | `common_beggar_king_destroy_life` | 100% OPERACIONAL VIA SQL |
| COMMON_024 | Cutelo | 0 | Ataque | `common_cleaver_discard_for_direct` | DEPENDENTE DE TRIGGER |
| COMMON_025 | Lugos Todo Roxo | 0 | Manual | `common_lugos_next_civil_double_power` | 100% OPERACIONAL VIA SQL |
| COMMON_026 | Nekker | 2 | Automático | `common_nekker_next_turn_mana` | DEPENDENTE DE TRIGGER |
| COMMON_027 | Afogador | 0 | Automático | `common_drowner_mill` | DEPENDENTE DE TRIGGER |
| COMMON_028 | Lobo | 0 | Ataque | `common_wolf_buff_deck` | DEPENDENTE DE TRIGGER |
| COMMON_029 | Urso | 2 | Ataque | `common_bear_promote_to_life` | DEPENDENTE DE TRIGGER |
| COMMON_030 | Winkler Vosgad | 4 | Manual | `common_winkler_silence_elf` | 100% OPERACIONAL VIA SQL |
| COMMON_031 | Baltazar | 3 | Reação | `common_baltazar_cancel_direct` | DEPENDENTE DE TRIGGER |
| COMMON_032 | General da Ordem | 3 | Automático | `common_general_reduce_max_mana` | DEPENDENTE DE TRIGGER |
| COMMON_033 | Totem | 0 | Automático | `common_totem_tutor_liches` | DEPENDENTE DE TRIGGER |
| COMMON_034 | Dilion Vorgues | 4 | Manual | `common_dilion_reduce_deck_cost` | 100% OPERACIONAL VIA SQL |
| COMMON_035 | Reynold Longmes | 1 | Manual | `common_reynold_forced_dwarf_attack` | 100% OPERACIONAL VIA SQL |
| COMMON_036 | Tamara Stranger | 4 | Manual | `common_tamara_choose_rare` | 100% OPERACIONAL VIA SQL |
| COMMON_037 | Jarl de An Skellige | 3 | Manual | `common_jarl_lock_legendary_effects` | 100% OPERACIONAL VIA SQL |
| COMMON_038 | Halmar de Skellige | 0 | Manual | `common_halmar_coin_attack` | 100% OPERACIONAL VIA SQL |
| COMMON_039 | Dudu Biberveld | 0 | Manual | `common_dudu_copy_hand_effect` | 100% OPERACIONAL VIA SQL |
| COMMON_040 | Thaler | 1 | Manual | `common_thaler_steal_deck_to_graveyard` | 100% OPERACIONAL VIA SQL |
| COMMON_041 | Vimme Vivaldi | 1 | Manual | `common_vivaldi_mutual_tutor` | 100% OPERACIONAL VIA SQL |
| COMMON_042 | Casimir Bassi | 4 | Manual | `common_casimir_destroy_life` | 100% OPERACIONAL VIA SQL |
| COMMON_043 | Hattori o Elfo Ferreiro | 3 | Manual | `common_hattori_discard_next_discount` | 100% OPERACIONAL VIA SQL |
| COMMON_044 | Milton de Peyrac-Peyran | 0 | Manual | `common_milton_return_turn_end` | 100% OPERACIONAL VIA SQL |
| COMMON_045 | Síle de Tansarville | 3 | Manual | `common_sile_tutor_highest_mana` | 100% OPERACIONAL VIA SQL |
| COMMON_046 | Gaetan | 3 | Ataque | `common_gaetan_purge_hand` | DEPENDENTE DE TRIGGER |
| COMMON_047 | Tomira | 4 | Manual | `common_tomira_full_heal` | 100% OPERACIONAL VIA SQL |
| COMMON_048 | Ves | 3 | Ataque | `common_ves_direct_random` | DEPENDENTE DE TRIGGER |
| COMMON_049 | Kiyan – Bruxo da Escola do Gato | 2 | Automático | `common_kiyan_protect_deck_card` | DEPENDENTE DE TRIGGER |
| COMMON_050 | Corine | 2 | Manual | `common_corine_peek_hand` | 100% OPERACIONAL VIA SQL |
| COMMON_051 | Guillaume | 0 | Ataque | `common_guillaume_destroy_deck` | DEPENDENTE DE TRIGGER |
| COMMON_052 | Anabelle | 5 | Manual | `common_anabelle_transform_hands` | 100% OPERACIONAL VIA SQL |
| COMMON_053 | Vlodimir von Everec | 2 | Manual | `common_vlodimir_replace_highest_life` | 100% OPERACIONAL VIA SQL |
| COMMON_054 | Joachim von Gratz-Vampiro | 2 | Manual | `common_joachim_revive_epic` | 100% OPERACIONAL VIA SQL |
| COMMON_055 | Gerd da Escola do Urso | 2 | Manual | `common_gerd_double_life` | 100% OPERACIONAL VIA SQL |
| COMMON_056 | Cão Selvagem | 1 | Ataque | `common_wild_dog_direct_life` | DEPENDENTE DE TRIGGER |
| COMMON_057 | Harpia | 3 | Manual | `common_harpy_absorb_and_attack` | 100% OPERACIONAL VIA SQL |
| COMMON_058 | Vaca | 3 | Automático | `common_cow_tutor_chorabashe` | DEPENDENTE DE TRIGGER |
| COMMON_059 | Ciri criança | 15 | Manual | `common_child_ciri_attack_all_life` | 100% OPERACIONAL VIA SQL |
| COMMON_060 | Barnabas o Mordomo | 0 | Manual | `common_barnabas_draw` | 100% OPERACIONAL VIA SQL |
| COMMON_061 | Eveline Gallo | 5 | Manual | `common_eveline_steal_highest_mana` | 100% OPERACIONAL VIA SQL |
| COMMON_062 | Nenneke Sacerdotisa de Melitele | 4 | Manual | `common_nenneke_nonlethal_steal` | 100% OPERACIONAL VIA SQL |
| COMMON_063 | Carpeado | 4 | Manual | `common_carpeado_zero_hand_costs` | 100% OPERACIONAL VIA SQL |
| COMMON_064 | Marlene de Trastamara | 2 | Manual | `common_marlene_transform` | 100% OPERACIONAL VIA SQL |
| COMMON_065 | Anna Strenger | 2 | Manual | `common_anna_increase_hand_costs` | 100% OPERACIONAL VIA SQL |
| COMMON_066 | Skjall | 0 | Passivo | `common_skjall_substitute_ciri` | DEPENDENTE DE TRIGGER |
| COMMON_067 | Morkvarg | 4 | Automático | `common_morkvarg_curse_hand` | DEPENDENTE DE TRIGGER |
| COMMON_068 | Udalryk o Atormentado | 0 | Manual | `common_udalryk_discard_coin_life` | 100% OPERACIONAL VIA SQL |
| COMMON_069 | Ida Emean | 4 | Manual | `common_ida_peek_deck` | 100% OPERACIONAL VIA SQL |
| COMMON_070 | Mestre da Arena | 6 | Manual | `common_arena_master_destroy_life` | 100% OPERACIONAL VIA SQL |
| COMMON_071 | Feiticeira Mabel | 2 | Manual | `common_mabel_destroy_witcher` | 100% OPERACIONAL VIA SQL |

## Resultado de integridade

- 72/72 códigos de catálogo presentes.
- 72/72 definições de efeito presentes.
- Todas as definições `common_*` entram no executor especializado ou em um consumidor autoritativo de trigger/guarda.
- A V10 corrige o despacho plural de `attacker_card_ids`, preserva compatibilidade com o payload singular legado e encaminha sobreviventes atingidos.
- Os efeitos de ataque direto de Aparição Diurna, Pantera, Cutelo, Ves e Cão Selvagem agora promovem o ataque automaticamente quando a condição é satisfeita.
- A Harpia exige ativação válida antes de absorver poder, e o runtime é consumido após o ataque.
- A IA mantém a regra de não baixar a mão abaixo de duas cartas durante o combate; a interface agenda cada decisão em cadência de quatro segundos.
