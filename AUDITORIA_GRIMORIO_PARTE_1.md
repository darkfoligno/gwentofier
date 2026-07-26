# AUDITORIA TÉCNICA DO GRIMÓRIO - PARTE 1 (COMUNS E RARAS)

Este documento apresenta a ficha técnica e a lógica de resolução de todas as cartas de raridade **COMUM** e **RARA** ativas no ecossistema do Gwentofier.

---

## 🃏 CARTAS COMUNS (COMMON)

### 🃏 Afogador (ID: `32fd7f68-994b-44b8-8551-c664dad9e531` / Efeito: `common_drowner_mill`)
* **Raridade:** `common` | **Elemento/Tipo:** `Bestiario`
* **Atributos Base:** 💎 Mana: `0` | ⚔️ Poder (ATK): `350` | ❤️ Vida (HP): `800`
* **Descrição do Efeito:** *"Quando destruída como reforço, envie uma carta do deck inimigo ao cemitério."*
* **Mecânica e Gatilhos:**
  * **Tipo de Gatilho:** `on_destroyed`
  * **Zona Permitida para Ativação:** `reinforcement`
* **Comportamento e Resolução:** Quando o Afogador é destruído no campo de reforço, a engine intercepta o evento, seleciona a carta do topo do deck do oponente e a move para a zona `graveyard`.

### 🃏 Anabelle (ID: `d021ec8f-eeae-4aa4-90ec-e8099a4c15d6` / Efeito: `common_anabelle_transform_hands`)
* **Raridade:** `common` | **Elemento/Tipo:** `Civil`
* **Atributos Base:** 💎 Mana: `5` | ⚔️ Poder (ATK): `2000` | ❤️ Vida (HP): `2500`
* **Descrição do Efeito:** *"Transforme todas as cartas das duas mãos em Aparição Noturna."*
* **Mecânica e Gatilhos:**
  * **Tipo de Gatilho:** `manual`
  * **Zona Permitida para Ativação:** `hand`
* **Comportamento e Resolução:** A ativação manual remove ou substitui o código de todas as cartas na zona `hand` dos dois jogadores, alterando suas propriedades e IDs no banco para o ID de "Aparição Noturna".

### 🃏 Anna Strenger (ID: `75f4768e-f534-4d33-bd51-377eef503310` / Efeito: `common_anna_increase_hand_costs`)
* **Raridade:** `common` | **Elemento/Tipo:** `Cívil`
* **Atributos Base:** 💎 Mana: `2` | ⚔️ Poder (ATK): `800` | ❤️ Vida (HP): `1600`
* **Descrição do Efeito:** *"Aumente em 1 o custo de todas as cartas nas duas mãos."*
* **Mecânica e Gatilhos:**
  * **Tipo de Gatilho:** `manual`
  * **Zona Permitida para Ativação:** `hand`
* **Comportamento e Resolução:** Executa um `UPDATE` no banco em todas as `match_cards` onde a `zone = 'hand'`, incrementando a coluna correspondente ao custo temporário de mana em +1.

### 🃏 Aparição Diurna (ID: `0717c4bc-24e5-4852-8fea-9502ce19d70a` / Efeito: `common_day_wraith_direct_attack`)
* **Raridade:** `common` | **Elemento/Tipo:** `Bestiario`
* **Atributos Base:** 💎 Mana: `2` | ⚔️ Poder (ATK): `1950` | ❤️ Vida (HP): `1950`
* **Descrição do Efeito:** *"Ataque uma Carta de Vida inimiga aleatória se seu cemitério tiver mais de 4 cartas."*
* **Mecânica e Gatilhos:**
  * **Tipo de Gatilho:** `manual`
  * **Zona Permitida para Ativação:** `hand` / `attacker`
* **Comportamento e Resolução:** Verifica se o cemitério do conjurador possui contagem superior a 4 cartas. Em caso afirmativo, aplica dano de `1950` contra um alvo selecionado aleatoriamente na zona `life` adversária.

### 🃏 Aparição Noturna (ID: `06fa0fe8-eabb-4c46-92b9-2a17479a34b4` / Efeito: `common_night_wraith_silence_hand`)
* **Raridade:** `common` | **Elemento/Tipo:** `Bestiario`
* **Atributos Base:** 💎 Mana: `1` | ⚔️ Poder (ATK): `1500` | ❤️ Vida (HP): `1000`
* **Descrição do Efeito:** *"Se destruída como reforço, bloqueie o efeito de uma carta aleatória da mão inimiga."*
* **Mecânica e Gatilhos:**
  * **Tipo de Gatilho:** `on_destroyed`
  * **Zona Permitida para Ativação:** `reinforcement`
* **Comportamento e Resolução:** No momento da destruição em zona de reforço, seleciona uma carta aleatória na mão do inimigo e desabilita ou limpa temporariamente seus efeitos.

### 🃏 Baltazar (ID: `468273d5-a91a-4401-ad34-9e1ed222a63e` / Efeito: `common_baltazar_cancel_direct`)
* **Raridade:** `common` | **Elemento/Tipo:** `M&F`
* **Atributos Base:** 💎 Mana: `3` | ⚔️ Poder (ATK): `0` | ❤️ Vida (HP): `3000`
* **Descrição do Efeito:** *"Cancele um ataque direto descartando uma carta da mão."*
* **Mecânica e Gatilhos:**
  * **Tipo de Gatilho:** `reaction`
  * **Zona Permitida para Ativação:** `reinforcement` / `hand`
* **Comportamento e Resolução:** Quando um ataque direto é declarado pelo oponente, o jogador pode descartar 1 carta da mão para anular totalmente o ataque e preservar a carta de vida alvejada.

### 🃏 Barghest (ID: `a121e8d5-1d1a-44d6-b828-a1ad18c30ac1` / Efeito: `common_barghest_overkill_to_deck`)
* **Raridade:** `common` | **Elemento/Tipo:** `Bestiario`
* **Atributos Base:** 💎 Mana: `2` | ⚔️ Poder (ATK): `2000` | ❤️ Vida (HP): `2000`
* **Descrição do Efeito:** *"Se destruída por ataque de poder igual ou maior a três vezes sua vida, retorne ao deck."*
* **Mecânica e Gatilhos:**
  * **Tipo de Gatilho:** `on_destroyed`
  * **Zona Permitida para Ativação:** `field`
* **Comportamento e Resolução:** Verifica se o dano letal recebido foi de magnitude overkill (ATK do atacante >= 6000). Caso positivo, altera a zona da carta para `deck` ao invés de `graveyard`.

### 🃏 Barnabas o Mordomo (ID: `49ec623c-387c-48d7-bdfe-ecd83eb363e9` / Efeito: `common_barnabas_draw`)
* **Raridade:** `common` | **Elemento/Tipo:** `Cívil`
* **Atributos Base:** 💎 Mana: `0` | ⚔️ Poder (ATK): `50` | ❤️ Vida (HP): `2000`
* **Descrição do Efeito:** *"Se você já perdeu uma Carta de Vida, compre uma carta."*
* **Mecânica e Gatilhos:**
  * **Tipo de Gatilho:** `manual`
  * **Zona Permitida para Ativação:** `hand`
* **Comportamento e Resolução:** A engine conta as cartas de vida ativas (`zone = 'life'`). Se o total de cartas de vida do jogador for menor que 3, executa o saque de 1 carta (`draw_internal`).

### 🃏 Barroso (ID: `c8f31e9d-0931-454a-b025-d3a9e076e04b` / Efeito: `common_barroso_purge_enemy_hand`)
* **Raridade:** `common` | **Elemento/Tipo:** `Bestiario`
* **Atributos Base:** 💎 Mana: `0` | ⚔️ Poder (ATK): `900` | ❤️ Vida (HP): `1300`
* **Descrição do Efeito:** *"Se descartada, destruída ou roubada da mão por efeito, descarte toda a mão adversária."*
* **Mecânica e Gatilhos:**
  * **Tipo de Gatilho:** `on_discard` / `on_destroyed`
  * **Zona Permitida para Ativação:** `hand` / `field`
* **Comportamento e Resolução:** Quando descartada ou removida de forma não-combate (efeito de trituração ou descarte forçado), a engine descarta imediatamente todas as cartas da mão inimiga.

### 🃏 Berseker (ID: `d2a5ff96-13e0-435c-bc6e-d367ca076a70` / Efeito: `common_berserker_copy_stats`)
* **Raridade:** `common` | **Elemento/Tipo:** `Bestiario`
* **Atributos Base:** 💎 Mana: `0` | ⚔️ Poder (ATK): `1` | ❤️ Vida (HP): `1`
* **Descrição do Efeito:** *"Copie a vida e o poder de uma carta aleatória do cemitério inimigo."*
* **Mecânica e Gatilhos:**
  * **Tipo de Gatilho:** `manual` / `reaction`
  * **Zona Permitida para Ativação:** `hand` / `reinforcement`
* **Comportamento e Resolução:** Seleciona aleatoriamente um card da zona `graveyard` do oponente, sobrescrevendo os valores de poder e vida atual do Berserker com as propriedades clonadas.

### 🃏 Cão Selvagem (ID: `3054c628-1292-4d3c-9baa-59e8e5e42696` / Efeito: `common_wild_dog_direct_life`)
* **Raridade:** `common` | **Elemento/Tipo:** `Bestiario`
* **Atributos Base:** 💎 Mana: `1` | ⚔️ Poder (ATK): `1300` | ❤️ Vida (HP): `500`
* **Descrição do Efeito:** *"Ataque diretamente uma Carta de Vida escolhida se você possuir uma Carta de Vida Bestiário ativa."*
* **Mecânica e Gatilhos:**
  * **Tipo de Gatilho:** `on_attack_declared`
  * **Zona Permitida para Ativação:** `attacker`
* **Comportamento e Resolução:** Valida a presença de pelo menos uma carta de vida com elemento `Bestiario` do lado do atacante. Se houver, ignora defensores e ataca a vida adversária diretamente.

### 🃏 Carniçal (ID: `6eb7d8c6-2ee8-4fe5-b27a-d032b6c61d22` / Efeito: `common_ghoul_group_revive`)
* **Raridade:** `common` | **Elemento/Tipo:** `Bestiario`
* **Atributos Base:** 💎 Mana: `2` | ⚔️ Poder (ATK): `800` | ❤️ Vida (HP): `2500`
* **Descrição do Efeito:** *"Se destruída junto de outro Carniçal, retorne uma carta do seu cemitério à mão."*
* **Mecânica e Gatilhos:**
  * **Tipo de Gatilho:** `on_destroyed`
  * **Zona Permitida para Ativação:** `field`
* **Comportamento e Resolução:** Ao ir para o cemitério, verifica se outra unidade homônima (Carniçal) foi destruída na mesma rodada/ação. Permite puxar uma carta escolhida do cemitério à mão.

### 🃏 Carniçal Atroz (ID: `efe518ae-3a33-405f-ab72-a5c12e4dbbe3` / Efeito: `common_atrocious_ghoul_draw_epic`)
* **Raridade:** `common` | **Elemento/Tipo:** `Bestiario`
* **Atributos Base:** 💎 Mana: `3` | ⚔️ Poder (ATK): `1200` | ❤️ Vida (HP): `3000`
* **Descrição do Efeito:** *"Se sobreviver a um ataque como reforço, compre uma carta épica do deck."*
* **Mecânica e Gatilhos:**
  * **Tipo de Gatilho:** `on_attack_resolved`
  * **Zona Permitida para Ativação:** `reinforcement`
* **Comportamento e Resolução:** Se a carta for atacada e seu `current_life` permanecer `> 0`, a engine vasculha o deck em busca de uma carta com `rarity = 'epic'` e a transfere para a mão do jogador.

### 🃏 Carpeado (ID: `7ace7082-f707-4611-999b-636792b9f89a` / Efeito: `common_carpeado_zero_hand_costs`)
* **Raridade:** `common` | **Elemento/Tipo:** `Bestiario`
* **Atributos Base:** 💎 Mana: `4` | ⚔️ Poder (ATK): `1000` | ❤️ Vida (HP): `1600`
* **Descrição do Efeito:** *"As cartas das duas mãos custam 0 até o próximo turno de cada jogador."*
* **Mecânica e Gatilhos:**
  * **Tipo de Gatilho:** `manual`
  * **Zona Permitida para Ativação:** `hand`
* **Comportamento e Resolução:** Sobrescreve o custo de mana de todas as cartas nas mãos para `0`. Efeitos de expiração são agendados para restaurar os custos originais após os turnos imediatos de cada jogador.

### 🃏 Casimir Bassi (ID: `ae14f1d7-c39f-4291-9716-917c8f074968` / Efeito: `common_casimir_destroy_life`)
* **Raridade:** `common` | **Elemento/Tipo:** `Anao`
* **Atributos Base:** 💎 Mana: `4` | ⚔️ Poder (ATK): `1800` | ❤️ Vida (HP): `1200`
* **Descrição do Efeito:** *"Destrua uma Carta de Vida inimiga se o deck adversário tiver menos cartas."*
* **Mecânica e Gatilhos:**
  * **Tipo de Gatilho:** `manual`
  * **Zona Permitida para Ativação:** `hand`
* **Comportamento e Resolução:** Compara a contagem de cartas no deck aliado vs deck adversário. Se o deck do oponente for menor, uma carta de vida inimiga (selecionada aleatoriamente ou por ID) é destruída.

### 🃏 Ciri criança (ID: `744e489a-55a0-41cc-9345-3551935978d0` / Efeito: `common_child_ciri_attack_all_life`)
* **Raridade:** `common` | **Elemento/Tipo:** `Elfica`
* **Atributos Base:** 💎 Mana: `15` | ⚔️ Poder (ATK): `1500` | ❤️ Vida (HP): `1000`
* **Descrição do Efeito:** *"Ataque todas as Cartas de Vida inimigas; custa 1 a menos por Witcher no seu deck."*
* **Mecânica e Gatilhos:**
  * **Tipo de Gatilho:** `manual`
  * **Zona Permitida para Ativação:** `hand`
* **Comportamento e Resolução:** A engine calcula a redução de custo baseando-se em `cards.element = 'Witcher'` presentes no deck. Ao ser conjurada, inflige `1500` de dano contra todas as 3 cartas de vida inimigas.

### 🃏 Corine (ID: `a951bc8b-a584-4b68-9efa-fb05fd96670a` / Efeito: `common_corine_peek_hand`)
* **Raridade:** `common` | **Elemento/Tipo:** `M&F`
* **Atributos Base:** 💎 Mana: `2` | ⚔️ Poder (ATK): `700` | ❤️ Vida (HP): `2200`
* **Descrição do Efeito:** *"Veja uma carta aleatória da mão adversária."*
* **Mecânica e Gatilhos:**
  * **Tipo de Gatilho:** `manual`
  * **Zona Permitida para Ativação:** `hand`
* **Comportamento e Resolução:** Retorna nos metadados de execução da RPC as informações completas (nome, imagem, raridade) de um card aleatório localizado na mão do adversário.

### 🃏 Cutelo (ID: `e1f3727a-c9ae-46ef-accd-d30bab2e39a3` / Efeito: `common_cleaver_discard_for_direct`)
* **Raridade:** `common` | **Elemento/Tipo:** `Anao`
* **Atributos Base:** 💎 Mana: `0` | ⚔️ Poder (ATK): `2200` | ❤️ Vida (HP): `250`
* **Descrição do Efeito:** *"Descarte 3 cartas da mão para permitir um ataque direto."*
* **Mecânica e Gatilhos:**
  * **Tipo de Gatilho:** `manual`
  * **Zona Permitida para Ativação:** `hand` / `attacker`
* **Comportamento e Resolução:** Move 3 cartas escolhidas da mão do conjurador para a pilha `graveyard`, liberando permissão de ataque direto contra a vida inimiga para a ação subsequente.

### 🃏 Dijkistra (ID: `1c224f7d-52e8-4793-8a38-fe9f30d8bb3b` / Efeito: `common_draw_three_common`)
* **Raridade:** `common` | **Elemento/Tipo:** `Cívil`
* **Atributos Base:** 💎 Mana: `0` | ⚔️ Poder (ATK): `1600` | ❤️ Vida (HP): `2100`
* **Descrição do Efeito:** *"Se descartada por um efeito, compre 3 cartas comuns do seu deck."*
* **Mecânica e Gatilhos:**
  * **Tipo de Gatilho:** `on_discard`
  * **Zona Permitida para Ativação:** `hand`
* **Comportamento e Resolução:** Se descartada da mão por efeitos, realiza busca ativa no deck e saca 3 cartas que possuam `rarity = 'common'`.

### 🃏 Duny (ID: `a30c204e-96ca-4a99-99d0-79026e95eaa9` / Efeito: `common_graveyard_return_lock`)
* **Raridade:** `common` | **Elemento/Tipo:** `Cívil`
* **Atributos Base:** 💎 Mana: `0` | ⚔️ Poder (ATK): `1600` | ❤️ Vida (HP): `720`
* **Descrição do Efeito:** *"Impede que cartas destruídas no campo retornem à mão ou ao campo."*
* **Mecânica e Gatilhos:**
  * **Tipo de Gatilho:** `passive`
  * **Zona Permitida para Ativação:** `field`
* **Comportamento e Resolução:** Enquanto Duny estiver ativo na arena de combate, todas as ações que tentem reviver, retornar ou mover cartas da zona `graveyard` para a mão/campo são imediatamente rejeitadas pela engine de regras.

### 🃏 Elemental (ID: `8657fa82-7225-4cca-86d6-86ec59abbf47` / Efeito: `common_elemental_prevent_damage`)
* **Raridade:** `common` | **Elemento/Tipo:** `Bestiario`
* **Atributos Base:** 💎 Mana: `3` | ⚔️ Poder (ATK): `500` | ❤️ Vida (HP): `2500`
* **Descrição do Efeito:** *"Cancele o dano se for atacada por uma carta M&F."*
* **Mecânica e Gatilhos:**
  * **Tipo de Gatilho:** `reaction`
  * **Zona Permitida para Ativação:** `reinforcement` / `life`
* **Comportamento e Resolução:** Intercepta a resolução do combate. Se a carta atacante for do tipo `M&F`, anula o dano recebido pelo Elemental na totalidade.

### 🃏 Endriuga (ID: `d3dfc41b-6a9d-4e48-9efc-ce68eb21fd58` / Efeito: `common_endriuga_scaled_damage`)
* **Raridade:** `common` | **Elemento/Tipo:** `Bestiario`
* **Atributos Base:** 💎 Mana: `2` | ⚔️ Poder (ATK): `600` | ❤️ Vida (HP): `600`
* **Descrição do Efeito:** *"Cause 500 de dano multiplicado pela quantidade de reforços inimigos a uma Carta de Vida escolhida."*
* **Mecânica e Gatilhos:**
  * **Tipo de Gatilho:** `manual`
  * **Zona Permitida para Ativação:** `hand`
* **Comportamento e Resolução:** Conta o número de cartas posicionadas na zona `reinforcement` do oponente. Multiplica essa quantidade por `500` e aplica o total como dano contra a carta de vida inimiga escolhida.

### 🃏 Erinia (ID: `a0a82d31-2094-4256-92b9-8bc58c9ba311` / Efeito: `common_erinia_exchange`)
* **Raridade:** `common` | **Elemento/Tipo:** `Bestiario`
* **Atributos Base:** 💎 Mana: `0` | ⚔️ Poder (ATK): `600` | ❤️ Vida (HP): `1300`
* **Descrição do Efeito:** *"Roube a carta de menor raridade da mão adversária e descarte uma carta da sua mão."*
* **Mecânica e Gatilhos:**
  * **Tipo de Gatilho:** `manual`
  * **Zona Permitida para Ativação:** `hand`
* **Comportamento e Resolução:** Busca o card de menor peso/raridade da mão inimiga, altera seu dono para o conjurador (movendo para sua `hand`), e força o descarte de uma de suas próprias cartas originais.

### 🃏 Eveline Gallo (ID: `7f581583-b477-4677-b897-045ad8a67f9b` / Efeito: `common_eveline_steal_highest_mana`)
* **Raridade:** `common` | **Elemento/Tipo:** `Cívil`
* **Atributos Base:** 💎 Mana: `5` | ⚔️ Poder (ATK): `1400` | ❤️ Vida (HP): `1200`
* **Descrição do Efeito:** *"Roube a carta de maior custo de mana da mão adversária."*
* **Mecânica e Gatilhos:**
  * **Tipo de Gatilho:** `manual`
  * **Zona Permitida para Ativação:** `hand`
* **Comportamento e Resolução:** Identifica e transfere o card de maior custo de mana da mão adversária diretamente para a mão do jogador.

### 🃏 Fada (ID: `e51e89af-88f2-4202-81b3-b43fa95e90b0` / Efeito: `common_fairy_extra_draw`)
* **Raridade:** `common` | **Elemento/Tipo:** `Bestiario`
* **Atributos Base:** 💎 Mana: `2` | ⚔️ Poder (ATK): `500` | ❤️ Vida (HP): `1500`
* **Descrição do Efeito:** *"Compre uma carta adicional no início de cada turno enquanto permanecer em campo."*
* **Mecânica e Gatilhos:**
  * **Tipo de Gatilho:** `passive` (Monitorado pelo auto-engine `on_turn_start`)
  * **Zona Permitida para Ativação:** `field`
* **Comportamento e Resolução:** A cada início de turno, a rotina `trigger_auto_engines` verifica se há alguma Fada em campo e realiza uma compra extra (`draw_internal`) para seu controlador.

### 🃏 Feiticeira Mabel (ID: `052a7d48-49ae-42b1-8b9e-44ddd883c5be` / Efeito: `common_mabel_destroy_witcher`)
* **Raridade:** `common` | **Elemento/Tipo:** `M&F`
* **Atributos Base:** 💎 Mana: `2` | ⚔️ Poder (ATK): `1800` | ❤️ Vida (HP): `1400`
* **Descrição do Efeito:** *"Destrua aleatoriamente uma Witcher no campo adversário."*
* **Mecânica e Gatilhos:**
  * **Tipo de Gatilho:** `manual`
  * **Zona Permitida para Ativação:** `hand`
* **Comportamento e Resolução:** Busca cartas de elemento `Witcher` no campo do oponente e destrói uma delas aleatoriamente, alterando sua zona para `graveyard`.

### 🃏 Filho da Puta Junior (ID: `cc998bd0-2723-4967-95a1-c3648f9f346f` / Efeito: `common_block_draw_in_hand`)
* **Raridade:** `common` | **Elemento/Tipo:** `Cívil`
* **Atributos Base:** 💎 Mana: `15` | ⚔️ Poder (ATK): `0` | ❤️ Vida (HP): `1`
* **Descrição do Efeito:** *"Você não pode comprar cartas enquanto esta carta estiver na sua mão."*
* **Mecânica e Gatilhos:**
  * **Tipo de Gatilho:** `passive`
  * **Zona Permitida para Ativação:** `hand`
* **Comportamento e Resolução:** Enquanto esse card estiver na zona `hand` do jogador, qualquer rotina de saque (`draw_internal`) é bloqueada e retorna 0 cartas.

### 🃏 Gaetan (ID: `be345ece-e5f6-44da-8bd2-9382744fc868` / Efeito: `common_gaetan_purge_hand`)
* **Raridade:** `common` | **Elemento/Tipo:** `Witcher`
* **Atributos Base:** 💎 Mana: `3` | ⚔️ Poder (ATK): `1700` | ❤️ Vida (HP): `1200`
* **Descrição do Efeito:** *"Descarte toda a mão inimiga se esta carta destruir sozinha uma Witcher."*
* **Mecânica e Gatilhos:**
  * **Tipo de Gatilho:** `on_attack_resolved`
  * **Zona Permitida para Ativação:** `attacker`
* **Comportamento e Resolução:** Se Gaetan desferir dano letal a um defensor do tipo `Witcher` sem assistência externa, move todas as cartas da mão inimiga para o `graveyard`.

### 🃏 Gargula (ID: `0b75b24c-138d-4b76-8596-638f5a534946` / Efeito: `common_gargoyle_cancel_single_attack`)
* **Raridade:** `common` | **Elemento/Tipo:** `Bestiario`
* **Atributos Base:** 💎 Mana: `2` | ⚔️ Poder (ATK): `200` | ❤️ Vida (HP): `2500`
* **Descrição do Efeito:** *"Bloqueie o ataque inimigo se ele tiver apenas uma carta atacante."*
* **Mecânica e Gatilhos:**
  * **Tipo de Gatilho:** `reaction`
  * **Zona Permitida para Ativação:** `reinforcement`
* **Comportamento e Resolução:** Quando o inimigo ataca com exatamente 1 carta na zona `attacker`, a Gargula reage cancelando a fase de dano daquele ataque.

### 🃏 General da Ordem (ID: `d6de7590-2a41-4f95-b744-a4ae627b11f4` / Efeito: `common_general_reduce_max_mana`)
* **Raridade:** `common` | **Elemento/Tipo:** `Cívil`
* **Atributos Base:** 💎 Mana: `3` | ⚔️ Poder (ATK): `1700` | ❤️ Vida (HP): `2000`
* **Descrição do Efeito:** *"Se destruída como reforço junto de uma Civil, reduza a mana máxima inimiga em 1 permanentemente."*
* **Mecânica e Gatilhos:**
  * **Tipo de Gatilho:** `on_destroyed`
  * **Zona Permitida para Ativação:** `reinforcement`
* **Comportamento e Resolução:** Ao ser enviada para o cemitério, verifica se havia uma carta `Civil` aliada também sendo destruída ou presente no campo. Reduz o limite máximo de mana do oponente em 1 ponto.

### 🃏 Gerd da Escola do Urso (ID: `faf99423-79bf-4df4-9f1d-02246b288516` / Efeito: `common_gerd_double_life`)
* **Raridade:** `common` | **Elemento/Tipo:** `Witcher`
* **Atributos Base:** 💎 Mana: `2` | ⚔️ Poder (ATK): `1600` | ❤️ Vida (HP): `2000`
* **Descrição do Efeito:** *"Quando em vida, dobre sua vida se o adversário já tiver passado um turno."*
* **Mecânica e Gatilhos:**
  * **Tipo de Gatilho:** `manual`
  * **Zona Permitida para Ativação:** `life`
* **Comportamento e Resolução:** Se ativada da zona de vida e o oponente já passou a vez de ação na rodada, dobra seu HP atual e máximo para `4000`.

### 🃏 Guillaume (ID: `88ae13ea-0bc8-4402-b3d3-c1e35d1aa43b` / Efeito: `common_guillaume_destroy_deck`)
* **Raridade:** `common` | **Elemento/Tipo:** `Cívil`
* **Atributos Base:** 💎 Mana: `0` | ⚔️ Poder (ATK): `1800` | ❤️ Vida (HP): `1400`
* **Descrição do Efeito:** *"Ao destruir sozinho em ataque, destrua uma comum ou rara do deck adversário."*
* **Mecânica e Gatilhos:**
  * **Tipo de Gatilho:** `on_attack_resolved`
  * **Zona Permitida para Ativação:** `attacker`
* **Comportamento e Resolução:** Se destruir um defensor, localiza um card aleatório de raridade `common` ou `rare` no deck do oponente e o envia diretamente para o cemitério.

### 🃏 Halmar de Skellige (ID: `9dca32b8-4950-452e-954d-d3aaee087241` / Efeito: `common_halmar_coin_attack`)
* **Raridade:** `common` | **Elemento/Tipo:** `Cívil`
* **Atributos Base:** 💎 Mana: `0` | ⚔️ Poder (ATK): `1700` | ❤️ Vida (HP): `1300`
* **Descrição do Efeito:** *"Ataque uma Carta de Vida inimiga; há 45% de chance de atacar duas Cartas de Vida próprias aleatórias."*
* **Mecânica e Gatilhos:**
  * **Tipo de Gatilho:** `manual`
  * **Zona Permitida para Ativação:** `hand` / `attacker`
* **Comportamento e Resolução:** Sorteia um valor `random()`. Se for `< 0.45`, ataca 2 cartas de vida do próprio jogador. Caso contrário, desfere ataque normal contra a vida inimiga.

### 🃏 Harpia (ID: `0cb72709-5ff3-47e5-a0cc-be1246fdeaa1` / Efeito: `common_harpy_absorb_and_attack`)
* **Raridade:** `common` | **Elemento/Tipo:** `Bestiario`
* **Atributos Base:** 💎 Mana: `3` | ⚔️ Poder (ATK): `200` | ❤️ Vida (HP): `100`
* **Descrição do Efeito:** *"Some o poder das Harpias do deck a esta carta e ataque a Carta de Vida inimiga mais distante."*
* **Mecânica e Gatilhos:**
  * **Tipo de Gatilho:** `manual`
  * **Zona Permitida para Ativação:** `hand` / `attacker`
* **Comportamento e Resolução:** Soma o ATK de todas as cartas com nome "Harpia" ainda presentes no deck ao poder atual do atacante, desferindo ataque contra a vida inimiga mais distante (slot 1 ou 3).

### 🃏 Hattori o Elfo Ferreiro (ID: `126a4c87-38ba-4727-b031-3949d49205cf` / Efeito: `common_hattori_discard_next_discount`)
* **Raridade:** `common` | **Elemento/Tipo:** `Elfica`
* **Atributos Base:** 💎 Mana: `3` | ⚔️ Poder (ATK): `1700` | ❤️ Vida (HP): `2200`
* **Descrição do Efeito:** *"Descarte uma carta aleatória da sua mão e reduza seu custo da próxima carta comprada."*
* **Mecânica e Gatilhos:**
  * **Tipo de Gatilho:** `manual`
  * **Zona Permitida para Ativação:** `hand`
* **Comportamento e Resolução:** Descarta 1 card aleatório da mão. Adiciona um efeito temporário que reduzirá em 2 o custo de mana da próxima unidade que entrar na mão do jogador.

### 🃏 Ida Emean (ID: `df14d4b8-12e4-4f8f-9b07-dbacbb379ad1` / Efeito: `common_ida_peek_deck`)
* **Raridade:** `common` | **Elemento/Tipo:** `M&F`
* **Atributos Base:** 💎 Mana: `4` | ⚔️ Poder (ATK): `1300` | ❤️ Vida (HP): `2000`
* **Descrição do Efeito:** *"Veja as duas próximas cartas do deck adversário."*
* **Mecânica e Gatilhos:**
  * **Tipo de Gatilho:** `manual`
  * **Zona Permitida para Ativação:** `hand`
* **Comportamento e Resolução:** Retorna ao cliente a identidade visual e metadados das duas cartas localizadas no topo do deck do oponente.

### 🃏 Jarl de An Skellige (ID: `de8a6984-e1c7-4d4f-bf50-5760156d6bd2` / Efeito: `common_jarl_lock_legendary_effects`)
* **Raridade:** `common` | **Elemento/Tipo:** `Cívil`
* **Atributos Base:** 💎 Mana: `3` | ⚔️ Poder (ATK): `2000` | ❤️ Vida (HP): `2100`
* **Descrição do Efeito:** *"Enquanto ativada como Carta de Vida, efeitos de lendárias não podem ser ativados."*
* **Mecânica e Gatilhos:**
  * **Tipo de Gatilho:** `manual` / `passive`
  * **Zona Permitida para Ativação:** `life`
* **Comportamento e Resolução:** Cria um bloqueio global na engine de efeitos. Qualquer ativação vinda de uma carta de raridade `legendary` é rejeitada se Jarl estiver na zona `life`.

### 🃏 Joachim von Gratz-Vampiro (ID: `b73066fc-1cfc-4c09-ab03-45ea8c9855e3` / Efeito: `common_joachim_revive_epic`)
* **Raridade:** `common` | **Elemento/Tipo:** `Vampiro`
* **Atributos Base:** 💎 Mana: `2` | ⚔️ Poder (ATK): `1900` | ❤️ Vida (HP): `1900`
* **Descrição do Efeito:** *"Quando em vida, retorne aleatoriamente uma épica do seu cemitério à mão."*
* **Mecânica e Gatilhos:**
  * **Tipo de Gatilho:** `manual`
  * **Zona Permitida para Ativação:** `life`
* **Comportamento e Resolução:** Quando ativada a partir de um slot de vida, seleciona uma carta de raridade `epic` do cemitério do jogador e a retorna para sua mão.

### 🃏 Keira Metz (ID: `4b829aa3-eda3-4585-b33e-f3580a9807ec` / Efeito: `common_keira_replace_life`)
* **Raridade:** `common` | **Elemento/Tipo:** `M&F`
* **Atributos Base:** 💎 Mana: `3` | ⚔️ Poder (ATK): `1200` | ❤️ Vida (HP): `2500`
* **Descrição do Efeito:** *"Se destruída como Carta de Vida, substitua-a automaticamente por uma comum do deck."*
* **Mecânica e Gatilhos:**
  * **Tipo de Gatilho:** `on_destroyed`
  * **Zona Permitida para Ativação:** `life`
* **Comportamento e Resolução:** Ao receber dano letal na zona `life`, a engine busca no deck uma carta `common` e a posiciona imediatamente no mesmo slot, evitando a perda de uma vida.

### 🃏 Kiyan – Bruxo da Escola do Gato (ID: `43f24138-c822-46e1-8486-514132f584e3` / Efeito: `common_kiyan_protect_deck_card`)
* **Raridade:** `common` | **Elemento/Tipo:** `Witcher`
* **Atributos Base:** 💎 Mana: `2` | ⚔️ Poder (ATK): `1400` | ❤️ Vida (HP): `1250`
* **Descrição do Efeito:** *"Ao ser destruída como reforço ou vida, proteja uma M&F aleatória do deck contra alteração ou cancelamento de mana e efeito."*
* **Mecânica e Gatilhos:**
  * **Tipo de Gatilho:** `on_destroyed`
  * **Zona Permitida para Ativação:** `reinforcement` / `life`
* **Comportamento e Resolução:** Ao ser destruído, insere uma flag de proteção em um card aleatório com elemento `M&F` no deck, tornando-o imune a efeitos de silenciamento ou taxação de mana.

### 🃏 Lobo (ID: `c820fad3-30c4-4b32-9fd5-d13a092e2abc` / Efeito: `common_wolf_buff_deck`)
* **Raridade:** `common` | **Elemento/Tipo:** `Bestiario`
* **Atributos Base:** 💎 Mana: `0` | ⚔️ Poder (ATK): `1000` | ❤️ Vida (HP): `1`
* **Descrição do Efeito:** *"Ao atingir uma Carta de Vida, dobre o poder de todos os outros Lobos do seu deck."*
* **Mecânica e Gatilhos:**
  * **Tipo de Gatilho:** `on_attack_resolved`
  * **Zona Permitida para Ativação:** `attacker`
* **Comportamento e Resolução:** Se o Lobo atingir com sucesso uma carta de vida adversária, a engine executa um buff multiplicativo (poder * 2) em todos os cards denominados "Lobo" localizados no deck.

### 🃏 Lugos Todo Roxo (ID: `5eabc8db-4160-4681-9d4e-1bec9b224f02` / Efeito: `common_lugos_next_civil_double_power`)
* **Raridade:** `common` | **Elemento/Tipo:** `Cívil`
* **Atributos Base:** 💎 Mana: `0` | ⚔️ Poder (ATK): `500` | ❤️ Vida (HP): `500`
* **Descrição do Efeito:** *"Dobre permanentemente o poder da próxima carta Civil comprada."*
* **Mecânica e Gatilhos:**
  * **Tipo de Gatilho:** `manual`
  * **Zona Permitida para Ativação:** `hand`
* **Comportamento e Resolução:** Registra um modificador de compra para o jogador. Quando o próximo card com elemento `Civil` for sacado do deck, seu poder base é permanentemente dobrado.

### 🃏 Marlene de Trastamara (ID: `96eb30b7-9e96-4773-9bee-b54792d536d0` / Efeito: `common_marlene_transform`)
* **Raridade:** `common` | **Elemento/Tipo:** `M&F`
* **Atributos Base:** 💎 Mana: `2` | ⚔️ Poder (ATK): `0` | ❤️ Vida (HP): `1`
* **Descrição do Efeito:** *"Transforme-se completamente em um Bestiário aleatório do cemitério inimigo quando ativada da mão ou como vida."*
* **Mecânica e Gatilhos:**
  * **Tipo de Gatilho:** `manual`
  * **Zona Permitida para Ativação:** `hand` / `life`
* **Comportamento e Resolução:** Substitui todas as propriedades (Nome, Poder, Vida, Efeitos) do card da Marlene pela cópia de um card do elemento `Bestiario` selecionado do cemitério do oponente.

### 🃏 Mestre da Arena (ID: `a1611f4b-b7b4-434c-9764-2250f9879e59` / Efeito: `common_arena_master_destroy_life`)
* **Raridade:** `common` | **Elemento/Tipo:** `Bestiario`
* **Atributos Base:** 💎 Mana: `6` | ⚔️ Poder (ATK): `2300` | ❤️ Vida (HP): `1600`
* **Descrição do Efeito:** *"Se não houver reforços inimigos, destrua uma Carta de Vida comum adversária."*
* **Mecânica e Gatilhos:**
  * **Tipo de Gatilho:** `manual`
  * **Zona Permitida para Ativação:** `hand`
* **Comportamento e Resolução:** Verifica se o campo de reforço do oponente está vazio. Caso esteja, escolhe uma das cartas de vida do oponente de raridade `common` e a move para o cemitério.

### 🃏 Milton de Peyrac-Peyran (ID: `b9c5de35-976a-4033-ad25-443528169caf` / Efeito: `common_milton_return_turn_end`)
* **Raridade:** `common` | **Elemento/Tipo:** `Cívil`
* **Atributos Base:** 💎 Mana: `0` | ⚔️ Poder (ATK): `1500` | ❤️ Vida (HP): `1500`
* **Descrição do Efeito:** *"Ao ativar, esta carta retorna à mão no fim do turno."*
* **Mecânica e Gatilhos:**
  * **Tipo de Gatilho:** `manual` / `on_turn_end`
  * **Zona Permitida para Ativação:** `field`
* **Comportamento e Resolução:** Após ser jogada e participar das interações do turno, a engine recolhe Milton de volta para a zona `hand` do jogador no processamento de encerramento do turno.

### 🃏 Morkvarg (ID: `3c0b027d-908a-40b7-9418-20a8d99abaa0` / Efeito: `common_morkvarg_curse_hand`)
* **Raridade:** `common` | **Elemento/Tipo:** `Cívil`
* **Atributos Base:** 💎 Mana: `4` | ⚔️ Poder (ATK): `0` | ❤️ Vida (HP): `1`
* **Descrição do Efeito:** *"Quando destruída, ocupe a mão adversária sem poder ser jogada, descartada ou reativada; limite 4, excedentes vão ao cemitério."*
* **Mecânica e Gatilhos:**
  * **Tipo de Gatilho:** `on_destroyed`
  * **Zona Permitida para Ativação:** `field`
* **Comportamento e Resolução:** Ao ser destruído, gera até 4 cópias do card "Maldição de Morkvarg" diretamente na mão do oponente. Esses cards não possuem custo de mana utilizável e reduzem o limite de cartas úteis do inimigo.

### 🃏 Necroso (ID: `eff0ac44-a3e4-467f-bfdc-2042c4523701` / Efeito: `common_necrophage_destroy_hand`)
* **Raridade:** `common` | **Elemento/Tipo:** `Bestiario`
* **Atributos Base:** 💎 Mana: `2` | ⚔️ Poder (ATK): `0` | ❤️ Vida (HP): `3000`
* **Descrição do Efeito:** *"Quando destruída como reforço ou vida, destrua uma carta aleatória da mão inimiga com poder menor que a vida desta carta."*
* **Mecânica e Gatilhos:**
  * **Tipo de Gatilho:** `on_destroyed`
  * **Zona Permitida para Ativação:** `reinforcement` / `life`
* **Comportamento e Resolução:** Ao morrer, avalia sua vida base/máxima e busca na mão do oponente cartas que tenham `base_power < 3000`. Destrói uma delas aleatoriamente.

### 🃏 Nekker (ID: `82277f4a-492c-4496-a0d8-e2516abbc64e` / Efeito: `common_nekker_next_turn_mana`)
* **Raridade:** `common` | **Elemento/Tipo:** `Bestiario`
* **Atributos Base:** 💎 Mana: `2` | ⚔️ Poder (ATK): `1000` | ❤️ Vida (HP): `2500`
* **Descrição do Efeito:** *"Quando destruída, ganhe 1 mana no próximo turno se houver outro Nekker no deck."*
* **Mecânica e Gatilhos:**
  * **Tipo de Gatilho:** `on_destroyed`
  * **Zona Permitida para Ativação:** `field`
* **Comportamento e Resolução:** Ao ser enviado para o cemitério, varre o deck em busca de outro card com nome "Nekker". Se encontrado, insere um buff de mana extra (+1) na conta do jogador para o início do próximo turno.

### 🃏 Nenneke Sacerdotisa de Melitele (ID: `86a2283c-4514-409c-b582-a1653e48ea70` / Efeito: `common_nenneke_nonlethal_steal`)
* **Raridade:** `common` | **Elemento/Tipo:** `M&F`
* **Atributos Base:** 💎 Mana: `4` | ⚔️ Poder (ATK): `1000` | ❤️ Vida (HP): `2500`
* **Descrição do Efeito:** *"Roube 1000 de vida de uma Carta de Vida inimiga aleatória e cure uma aliada aleatória; falha sem efeito se o alvo não puder sobreviver."*
* **Mecânica e Gatilhos:**
  * **Tipo de Gatilho:** `manual`
  * **Zona Permitida para Ativação:** `hand`
* **Comportamento e Resolução:** Seleciona um alvo de vida do oponente. Se ele possuir `current_life > 1000`, retira 1000 HP dele e os adiciona a um card de vida aliado. Caso contrário, a conjuração falha sem causar dano letal.

### 🃏 Pantera (ID: `cc6cc445-8484-470f-a71e-3e63dbf0008d` / Efeito: `common_panther_direct_life`)
* **Raridade:** `common` | **Elemento/Tipo:** `Bestiario`
* **Atributos Base:** 💎 Mana: `4` | ⚔️ Poder (ATK): `1300` | ❤️ Vida (HP): `1800`
* **Descrição do Efeito:** *"Ataque diretamente uma Carta de Vida se sua mão for maior que a mão adversária."*
* **Mecânica e Gatilhos:**
  * **Tipo de Gatilho:** `manual`
  * **Zona Permitida para Ativação:** `attacker`
* **Comportamento e Resolução:** Compara o tamanho da mão aliada vs inimiga. Caso a do jogador seja maior, concede permissão para desferir ataque direto ignorando a fileira de defesa.

### 🃏 Principe Adrian de Kaedwen (ID: `652bd87d-facb-4dbc-b956-490444cdd1df` / Efeito: `comp_adrian_common_revive_hand`)
* **Raridade:** `common` | **Elemento/Tipo:** `Civil`
* **Atributos Base:** 💎 Mana: `2` | ⚔️ Poder (ATK): `1600` | ❤️ Vida (HP): `1500`
* **Descrição do Efeito:** *"Ative este efeito e traga uma carta de raridade comum (rarity = 'common') à sua escolha do seu cemitério de volta para a sua mão."*
* **Mecânica e Gatilhos:**
  * **Tipo de Gatilho:** `manual`
  * **Zona Permitida para Ativação:** `hand`
* **Comportamento e Resolução:** Permite ao jogador escolher uma unidade com `rarity = 'common'` de seu `graveyard` e a transfere diretamente para a zona `hand`.

### 🃏 Puero (ID: `249fba9e-4b5b-4550-b2aa-7a1c09a962bb` / Efeito: `common_puero_destroy_random_legendary`)
* **Raridade:** `common` | **Elemento/Tipo:** `Bestiario`
* **Atributos Base:** 💎 Mana: `3` | ⚔️ Poder (ATK): `200` | ❤️ Vida (HP): `1700`
* **Descrição do Efeito:** *"Destrua aleatoriamente uma lendária de qualquer lado do campo."*
* **Mecânica e Gatilhos:**
  * **Tipo de Gatilho:** `manual`
  * **Zona Permitida para Ativação:** `hand`
* **Comportamento e Resolução:** Varre a mesa do jogo inteira (ambos os lados) buscando cartas com `rarity = 'legendary'`. Destrói uma delas aleatoriamente.

### 🃏 Rei dos Mendigos (ID: `a5dcdb5a-92d9-42ef-89ef-1ccbbecada40` / Efeito: `common_beggar_king_destroy_life`)
* **Raridade:** `common` | **Elemento/Tipo:** `Cívil`
* **Atributos Base:** 💎 Mana: `0` | ⚔️ Poder (ATK): `1450` | ❤️ Vida (HP): `1`
* **Descrição do Efeito:** *"Destrua uma Carta de Vida inimiga se esta for a única carta em sua mão."*
* **Mecânica e Gatilhos:**
  * **Tipo de Gatilho:** `manual`
  * **Zona Permitida para Ativação:** `hand`
* **Comportamento e Resolução:** Se conjurada quando a mão do jogador contém apenas o Rei dos Mendigos, destrói uma carta de vida escolhida do adversário de forma fulminante.

### 🃏 Rei Henselt (ID: `2f6fbc9a-ff32-4c18-98f6-b8f6599aa06e` / Efeito: `common_henselt_attack_all_life`)
* **Raridade:** `common` | **Elemento/Tipo:** `Cívil`
* **Atributos Base:** 💎 Mana: `7` | ⚔️ Poder (ATK): `2500` | ❤️ Vida (HP): `2500`
* **Descrição do Efeito:** *"Ataque as 3 Cartas de Vida do oponente se ele não possuir reforços."*
* **Mecânica e Gatilhos:**
  * **Tipo de Gatilho:** `manual`
  * **Zona Permitida para Ativação:** `hand` / `attacker`
* **Comportamento e Resolução:** Verifica a fileira `reinforcement` do oponente. Caso não haja defensores ativos, o ataque de Henselt atinge todas as 3 vidas adversárias em paralelo.

### 🃏 Reynold Longmes (ID: `4cc39837-6f12-4125-83e2-8a4e267223e5` / Efeito: `common_reynold_forced_dwarf_attack`)
* **Raridade:** `common` | **Elemento/Tipo:** `Witcher`
* **Atributos Base:** 💎 Mana: `1` | ⚔️ Poder (ATK): `0` | ❤️ Vida (HP): `2000`
* **Descrição do Efeito:** *"Puxe um Anão do deck para atacar uma Carta de Vida aleatória; se não destruir, bana os outros Reynold Longmes do deck."*
* **Mecânica e Gatilhos:**
  * **Tipo de Gatilho:** `manual`
  * **Zona Permitida para Ativação:** `hand`
* **Comportamento e Resolução:** Invoca uma unidade do elemento `Anao` do deck direto para o campo de ataque. Caso o golpe não elimine a vida alvejada, localiza e remove do jogo (`exílio`) todas as outras cópias de Reynold do deck.

### 🃏 Shani (ID: `43f3a065-700b-42df-ab98-c40002b93930` / Efeito: `common_shani_redeploy_life`)
* **Raridade:** `common` | **Elemento/Tipo:** `Cívil`
* **Atributos Base:** 💎 Mana: `4` | ⚔️ Poder (ATK): `50` | ❤️ Vida (HP): `3000`
* **Descrição do Efeito:** *"Ao ser destruída, ocupe aleatoriamente um slot de vida com carta de vida menor e volte com vida cheia."*
* **Mecânica e Gatilhos:**
  * **Tipo de Gatilho:** `on_destroyed`
  * **Zona Permitida para Ativação:** `field`
* **Comportamento e Resolução:** No momento de sua morte, Shani é reposicionada em um slot de vida aliado danificado com seus atributos de vida completamente restaurados.

### 🃏 Síle de Tansarville (ID: `78a12f3f-43d6-462a-82c7-43df0149a806` / Efeito: `common_sile_tutor_highest_mana`)
* **Raridade:** `common` | **Elemento/Tipo:** `M&F`
* **Atributos Base:** 💎 Mana: `3` | ⚔️ Poder (ATK): `0` | ❤️ Vida (HP): `2200`
* **Descrição do Efeito:** *"Compre do deck sua carta M&F de maior custo de mana."*
* **Mecânica e Gatilhos:**
  * **Tipo de Gatilho:** `manual`
  * **Zona Permitida para Ativação:** `hand`
* **Comportamento e Resolução:** Busca ativamente no deck o card de elemento `M&F` com a maior coluna de custo de mana e o insere na mão do jogador.

### 🃏 Skjall (ID: `1d95d0fa-0d89-4b21-b614-2bbac32e2d02` / Efeito: `common_skjall_substitute_ciri`)
* **Raridade:** `common` | **Elemento/Tipo:** `Cívil`
* **Atributos Base:** 💎 Mana: `0` | ⚔️ Poder (ATK): `2000` | ❤️ Vida (HP): `1700`
* **Descrição do Efeito:** *"Enquanto no deck, seja destruída no lugar de uma carta Ciri e retorne a Ciri à mão."*
* **Mecânica e Gatilhos:**
  * **Tipo de Gatilho:** `passive`
  * **Zona Permitida para Ativação:** `deck`
* **Comportamento e Resolução:** Se uma unidade com nome "Ciri" estiver prestes a ser destruída em campo, Skjall é consumido diretamente do deck para o cemitério, enviando a Ciri de volta para a segurança da mão.

### 🃏 Tamara Stranger (ID: `98438929-4dc8-48cd-a827-02704962f6d2` / Efeito: `common_tamara_choose_rare`)
* **Raridade:** `common` | **Elemento/Tipo:** `M&F`
* **Atributos Base:** 💎 Mana: `4` | ⚔️ Poder (ATK): `500` | ❤️ Vida (HP): `2600`
* **Descrição do Efeito:** *"Escolha e compre uma carta rara do seu deck."*
* **Mecânica e Gatilhos:**
  * **Tipo de Gatilho:** `manual`
  * **Zona Permitida para Ativação:** `hand`
* **Comportamento e Resolução:** Abre a gaveta de busca no deck para seleção do jogador, filtrando exclusivamente unidades de `rarity = 'rare'`.

### 🃏 Thaler (ID: `9299adfb-97db-46d8-94da-a982cf3f5639` / Efeito: `common_thaler_steal_deck_to_graveyard`)
* **Raridade:** `common` | **Elemento/Tipo:** `Cívil`
* **Atributos Base:** 💎 Mana: `1` | ⚔️ Poder (ATK): `1600` | ❤️ Vida (HP): `1500`
* **Descrição do Efeito:** *"Roube uma carta do deck adversário e adicione-a ao seu cemitério."*
* **Mecânica e Gatilhos:**
  * **Tipo de Gatilho:** `manual`
  * **Zona Permitida para Ativação:** `hand`
* **Comportamento e Resolução:** Transfere uma carta aleatória do deck inimigo diretamente para a zona `graveyard` do jogador (alimentando efeitos baseados em contagem de cemitério).

### 🃏 Tomira (ID: `66d0f400-141a-4591-9c1a-f4400be91bc9` / Efeito: `common_tomira_full_heal`)
* **Raridade:** `common` | **Elemento/Tipo:** `Cívil`
* **Atributos Base:** 💎 Mana: `4` | ⚔️ Poder (ATK): `0` | ❤️ Vida (HP): `3000`
* **Descrição do Efeito:** *"Restaure completamente uma Carta de Vida aliada danificada."*
* **Mecânica e Gatilhos:**
  * **Tipo de Gatilho:** `manual`
  * **Zona Permitida para Ativação:** `hand`
* **Comportamento e Resolução:** Sobrescreve a coluna `current_life` de uma carta de vida aliada selecionada com o valor de seu `base_max_life`.

### 🃏 Totem (ID: `f6bcd9d7-ec02-406d-93d4-cc283493594b` / Efeito: `common_totem_tutor_liches`)
* **Raridade:** `common` | **Elemento/Tipo:** `Bestiario`
* **Atributos Base:** 💎 Mana: `0` | ⚔️ Poder (ATK): `0` | ❤️ Vida (HP): `1`
* **Descrição do Efeito:** *"Ao ser destruído com ao menos 3 outros Totens no cemitério, leve todos os Liches e Liches Anciãos do deck à mão com custo 0."*
* **Mecânica e Gatilhos:**
  * **Tipo de Gatilho:** `on_destroyed`
  * **Zona Permitida para Ativação:** `field`
* **Comportamento e Resolução:** Se o cemitério contiver `>= 3` cartas chamadas "Totem" no momento de sua morte, localiza "Liche" e "Liche Ancião" no deck, zera seus custos de mana e os saca para a mão.

### 🃏 Troll (ID: `396784cd-e61b-4f7e-8fba-3757eaca72a4` / Efeito: `common_troll_discard_draw`)
* **Raridade:** `common` | **Elemento/Tipo:** `Bestiario`
* **Atributos Base:** 💎 Mana: `2` | ⚔️ Poder (ATK): `500` | ❤️ Vida (HP): `2500`
* **Descrição do Efeito:** *"Descarte toda a sua mão para comprar duas cartas."*
* **Mecânica e Gatilhos:**
  * **Tipo de Gatilho:** `manual` / `reaction`
  * **Zona Permitida para Ativação:** `hand` / `reinforcement`
* **Comportamento e Resolução:** Esvazia totalmente a mão do jogador e executa `draw_internal` para comprar duas novas cartas do deck.

### 🃏 Udalryk o Atormentado (ID: `58f04ead-dfa9-4fba-b155-76d336beb0d1` / Efeito: `common_udalryk_discard_coin_life`)
* **Raridade:** `common` | **Elemento/Tipo:** `Cívil`
* **Atributos Base:** 💎 Mana: `0` | ⚔️ Poder (ATK): `1700` | ❤️ Vida (HP): `800`
* **Descrição do Efeito:** *"Descarte uma carta da mão adversária; há 35% de chance de esta carta ocupar uma Carta de Vida própria."*
* **Mecânica e Gatilhos:**
  * **Tipo de Gatilho:** `manual`
  * **Zona Permitida para Ativação:** `hand`
* **Comportamento e Resolução:** Executa o descarte de 1 card aleatório da mão inimiga. Sob probabilidade de 35% (`random() < 0.35`), Udalryk é forçado a ocupar o slot de uma de suas próprias vidas.

### 🃏 Urso (ID: `692bdbfb-1cf3-4e49-ba84-2f307abee4db` / Efeito: `common_bear_promote_to_life`)
* **Raridade:** `common` | **Elemento/Tipo:** `Bestiario`
* **Atributos Base:** 💎 Mana: `2` | ⚔️ Poder (ATK): `0` | ❤️ Vida (HP): `2000`
* **Descrição do Efeito:** *"Se sobreviver como reforço, dobre sua vida e substitua uma Carta de Vida com menos vida."*
* **Mecânica e Gatilhos:**
  * **Tipo de Gatilho:** `on_attack_resolved`
  * **Zona Permitida para Ativação:** `reinforcement`
* **Comportamento e Resolução:** Caso sobreviva ao ataque inimigo na zona de defesa, seu HP é dobrado para `4000` e ele é promovido para a zona `life` no lugar de uma carta aliada com menor HP atual.

### 🃏 Vaca (ID: `bcc35118-de4e-4454-99ef-c7adb9a351dc` / Efeito: `common_cow_tutor_chorabashe`)
* **Raridade:** `common` | **Elemento/Tipo:** `Bestiario`
* **Atributos Base:** 💎 Mana: `3` | ⚔️ Poder (ATK): `100` | ❤️ Vida (HP): `1000`
* **Descrição do Efeito:** *"Quando destruída como reforço, leve Chorabashe do deck ou cemitério à mão."*
* **Mecânica e Gatilhos:**
  * **Tipo de Gatilho:** `on_destroyed`
  * **Zona Permitida para Ativação:** `reinforcement`
* **Comportamento e Resolução:** Ao ir a óbito, realiza busca por "Chorabashe" no deck ou cemitério, invocando a fera diretamente para a mão do jogador.

### 🃏 Ves (ID: `eb3a66bd-b41a-44b0-a2e4-3205da3a88c8` / Efeito: `common_ves_direct_random`)
* **Raridade:** `common` | **Elemento/Tipo:** `Cívil`
* **Atributos Base:** 💎 Mana: `3` | ⚔️ Poder (ATK): `2000` | ❤️ Vida (HP): `2000`
* **Descrição do Efeito:** *"Ataque diretamente um alvo aleatório se for a única carta com mana maior que zero na sua mão."*
* **Mecânica e Gatilhos:**
  * **Tipo de Gatilho:** `on_attack_declared`
  * **Zona Permitida para Ativação:** `attacker`
* **Comportamento e Resolução:** Se Ves for a única carta restante na mão com custo de mana ativo, seu ataque é direcionado contra uma carta de vida aleatória do oponente, ignorando totalmente a presença de defensores.

### 🃏 Vimme Vivaldi (ID: `de13b29b-13b9-4def-b426-7d1c9da0f31a` / Efeito: `common_vivaldi_mutual_tutor`)
* **Raridade:** `common` | **Elemento/Tipo:** `Anao`
* **Atributos Base:** 💎 Mana: `1` | ⚔️ Poder (ATK): `1200` | ❤️ Vida (HP): `2500`
* **Descrição do Efeito:** *"Cada jogador escolhe uma carta do próprio deck para comprar com custo aumentado em 2."*
* **Mecânica e Gatilhos:**
  * **Tipo de Gatilho:** `manual`
  * **Zona Permitida para Ativação:** `hand`
* **Comportamento e Resolução:** Dispara uma tela de seleção de deck para ambos os jogadores. Os cards selecionados são movidos para as mãos respectivas com custo incrementado em +2.

### 🃏 Vlodimir von Everec (ID: `7be9edc0-7bc8-407b-874e-cc9949af3249` / Efeito: `common_vlodimir_replace_highest_life`)
* **Raridade:** `common` | **Elemento/Tipo:** `Cívil`
* **Atributos Base:** 💎 Mana: `2` | ⚔️ Poder (ATK): `1000` | ❤️ Vida (HP): `1200`
* **Descrição do Efeito:** *"Substitua a Carta de Vida de maior raridade de cada lado pela carta de menor raridade do respectivo deck."*
* **Mecânica e Gatilhos:**
  * **Tipo de Gatilho:** `manual`
  * **Zona Permitida para Ativação:** `hand`
* **Comportamento e Resolução:** Localiza a carta de vida de maior raridade em campo de ambos os jogadores. Envia-as ao cemitério e posiciona em seus lugares os cards de menor raridade buscados em cada deck.

### 🃏 Winkler Vosgad (ID: `408f39c5-6af2-4bac-956a-7bd8a44eebf4` / Efeito: `common_winkler_silence_elf`)
* **Raridade:** `common` | **Elemento/Tipo:** `Witcher`
* **Atributos Base:** 💎 Mana: `4` | ⚔️ Poder (ATK): `1700` | ❤️ Vida (HP): `1450`
* **Descrição do Efeito:** *"Remova o efeito de uma carta Elfica no campo adversário."*
* **Mecânica e Gatilhos:**
  * **Tipo de Gatilho:** `manual`
  * **Zona Permitida para Ativação:** `hand`
* **Comportamento e Resolução:** Seleciona um card adversário em campo cujo elemento seja `Elfica` e limpa/desativa seus efeitos na tabela de execução da engine.

---

## 🃏 CARTAS RARAS (RARE)

### 🃏 Alpor (ID: `e0ea21e2-0922-4632-951e-b8c67d950087` / Efeito: `comp_alpor_lifesteal_tenth`)
* **Raridade:** `rare` | **Elemento/Tipo:** `Vampiro`
* **Atributos Base:** 💎 Mana: `3` | ⚔️ Poder (ATK): `2000` | ❤️ Vida (HP): `2000`
* **Descrição do Efeito:** *"Ao ativar este feitiço, durante o ataque desta rodada, 10% de todo dano causado por Alpor cura (aumenta a Vida atual) de uma Carta de Vida aliada aleatória no seu campo."*
* **Mecânica e Gatilhos:**
  * **Tipo de Gatilho:** `manual`
  * **Zona Permitida para Ativação:** `hand` / `attacker`
* **Comportamento e Resolução:** Registra um interceptor de combate. Ao resolver o dano do ataque de Alpor, calcula `10%` daquele valor e incrementa a vida de uma unidade na zona `life` aliada.

### 🃏 Altair da Escola do Lobo (ID: `a3e98443-4292-4744-ab5b-f5b0803da629` / Efeito: `comp_altair_selenne_direct_snipe`)
* **Raridade:** `rare` | **Elemento/Tipo:** `Witcher`
* **Atributos Base:** 💎 Mana: `2` | ⚔️ Poder (ATK): `1800` | ❤️ Vida (HP): `1500`
* **Descrição do Efeito:** *"Esta carta ataca diretamente uma Carta de Vida do oponente ignorando reforços, SE houver a carta \"Feiticeira Selenne\" (EXTRA_RARE_02) na sua mão."*
* **Mecânica e Gatilhos:**
  * **Tipo de Gatilho:** `manual`
  * **Zona Permitida para Ativação:** `attacker`
* **Comportamento e Resolução:** Verifica a mão do jogador. Se contiver o ID/código correspondente a Selenne, o ataque de Altair ignora a linha de defesa e atinge diretamente a vida inimiga.

### 🃏 Amduat o Elfo (ID: `8d7e94d0-d8c9-4677-93eb-d8da80ed1b2e` / Efeito: `rare_amduat_purge_hand_duplicates`)
* **Raridade:** `rare` | **Elemento/Tipo:** `Elfica`
* **Atributos Base:** 💎 Mana: `5` | ⚔️ Poder (ATK): `2200` | ❤️ Vida (HP): `3000`
* **Descrição do Efeito:** *"Ative este efeito e destrua todas as cartas repetidas/iguais presentes na mão do seu oponente."*
* **Mecânica e Gatilhos:**
  * **Tipo de Gatilho:** `manual`
  * **Zona Permitida para Ativação:** `hand`
* **Comportamento e Resolução:** Varre os cards na zona `hand` do oponente. Agrupa por nome/código e move todas as duplicatas encontradas para o cemitério, deixando apenas cópias únicas na mão inimiga.

### 🃏 Aracnomorfo (ID: `327b4510-c2e7-4c04-806e-4a11bce1c427` / Efeito: `rare_arachnomorph_legacy_power`)
* **Raridade:** `rare` | **Elemento/Tipo:** `Bestiario`
* **Atributos Base:** 💎 Mana: `3` | ⚔️ Poder (ATK): `3100` | ❤️ Vida (HP): `2500`
* **Descrição do Efeito:** *"Ative esse efeito e se essa carta for o único reforço no seu campo quando essa carta for destruida o poder dela será passada para uma carta em sua mão a sua escolha."*
* **Mecânica e Gatilhos:**
  * **Tipo de Gatilho:** `on_destroyed`
  * **Zona Permitida para Ativação:** `reinforcement`
* **Comportamento e Resolução:** Quando destruído, avalia se era a única unidade na zona `reinforcement` do jogador. Em caso positivo, o poder total acumulado de Aracnomorfo é transferido como buff a um card escolhido da mão.

### 🃏 Arella da Escola do Grifo (ID: `57c3d013-dc85-4e09-b39b-bcde48d25a64` / Efeito: `comp_arella_stat_inversion`)
* **Raridade:** `rare` | **Elemento/Tipo:** `Witcher`
* **Atributos Base:** 💎 Mana: `6` | ⚔️ Poder (ATK): `1200` | ❤️ Vida (HP): `2600`
* **Descrição do Efeito:** *"Inverta permanentemente os valores de Poder e Vida de alguma carta aliada presente na sua mão ou no seu campo à sua escolha."*
* **Mecânica e Gatilhos:**
  * **Tipo de Gatilho:** `manual`
  * **Zona Permitida para Ativação:** `hand`
* **Comportamento e Resolução:** Seleciona um card aliado. Realiza a troca matemática: `current_power` passa a ser `current_life` e vice-versa, de forma permanente para a partida.

### 🃏 ArqueGriffo (ID: `335646dc-6b0d-4f87-bb2e-f44ce9b675c2` / Efeito: `rare_archgriffin_double_edge_snipe`)
* **Raridade:** `rare` | **Elemento/Tipo:** `Bestiario`
* **Atributos Base:** 💎 Mana: `4` | ⚔️ Poder (ATK): `4000` | ❤️ Vida (HP): `1700`
* **Descrição do Efeito:** *"Ataque diretamente uma Carta de Vida do seu campo e uma Carta de Vida do campo do seu oponente à sua escolha (seleção dupla)."*
* **Mecânica e Gatilhos:**
  * **Tipo de Gatilho:** `manual`
  * **Zona Permitida para Ativação:** `hand` / `attacker`
* **Comportamento e Resolução:** Exige a seleção de duas metas. Inflige seu dano de ataque (`4000`) contra um card de vida aliado e um card de vida inimigo em paralelo.

### 🃏 Arquespora (ID: `f75a5c39-7ff0-4582-b0ac-2da3db50d240` / Efeito: `rare_arquespora_damage_reduce_tutor`)
* **Raridade:** `rare` | **Elemento/Tipo:** `Bestiario`
* **Atributos Base:** 💎 Mana: `0` | ⚔️ Poder (ATK): `600` | ❤️ Vida (HP): `2500`
* **Descrição do Efeito:** *"Reduza em 20% o dano total causado pelo ataque do oponente antes do calculo de dano do turno e traga outra arquespora do seu deck para sua mão."*
* **Mecânica e Gatilhos:**
  * **Tipo de Gatilho:** `reaction`
  * **Zona Permitida para Ativação:** `reinforcement`
* **Comportamento e Resolução:** Na fase de resolução de dano, reduz a força do ataque recebido em `20%` e realiza a busca e saque de outra carta chamada "Arquespora" direto do deck para a mão.

### 🃏 Barão Sanguinário (ID: `cb068893-6065-4437-9cdc-0a23dba9d833` / Efeito: `rare_bloody_baron_debuff_deck`)
* **Raridade:** `rare` | **Elemento/Tipo:** `Civil`
* **Atributos Base:** 💎 Mana: `4` | ⚔️ Poder (ATK): `2600` | ❤️ Vida (HP): `2600`
* **Descrição do Efeito:** *"Ao ativar essa carta todas as cartas do tipo Bestiario dentro do deck de seu oponente perderão 1000 de poder."*
* **Mecânica e Gatilhos:**
  * **Tipo de Gatilho:** `manual`
  * **Zona Permitida para Ativação:** `hand`
* **Comportamento e Resolução:** Aplica um `UPDATE` no deck adversário, aumentando ou reduzindo o poder de todas as cartas com `element = 'Bestiario'` em `-1000`.

### 🃏 Bruxa Áquatica (ID: `6fbf1647-cb10-4377-8ecf-53e1ddcd721a` / Efeito: `rare_water_hag_destroy_discard`)
* **Raridade:** `rare` | **Elemento/Tipo:** `Bestiario`
* **Atributos Base:** 💎 Mana: `3` | ⚔️ Poder (ATK): `2300` | ❤️ Vida (HP): `2900`
* **Descrição do Efeito:** *"Se essa carta for revelada e destruida por uma carta de ataque do oponente que tenha custo 0 ative esse efeito e forçe o oponente a descartar uma carta a escolha dele da mão dele."*
* **Mecânica e Gatilhos:**
  * **Tipo de Gatilho:** `on_destroyed`
  * **Zona Permitida para Ativação:** `reinforcement`
* **Comportamento e Resolução:** Se atacada e eliminada por um card de custo de mana `0`, ativa o gatilho forçando o adversário a descartar um card de sua própria mão.

### 🃏 Canoleta (ID: `dea23a53-7bb3-4882-afa6-e99407fa6f58` / Efeito: `rare_reed_select_rare_tutor`)
* **Raridade:** `rare` | **Elemento/Tipo:** `Civil`
* **Atributos Base:** 💎 Mana: `2` | ⚔️ Poder (ATK): `1000` | ❤️ Vida (HP): `2700`
* **Descrição do Efeito:** *"Compre uma carta do seu deck à sua escolha (abrindo tela de seleção) que seja de raridade rara (rarity = \"rare\")."*
* **Mecânica e Gatilhos:**
  * **Tipo de Gatilho:** `manual`
  * **Zona Permitida para Ativação:** `hand`
* **Comportamento e Resolução:** Abre a janela de seleção interativa, listando todas as cartas no deck com `rarity = 'rare'` e permitindo ao jogador escolher qual sacar.

### 🃏 Casa das Lágrimas (ID: `6e95b40e-e28f-4669-b202-22ca72cb5791` / Efeito: `rare_house_of_tears_effect_immunity`)
* **Raridade:** `rare` | **Elemento/Tipo:** `Bestiario`
* **Atributos Base:** 💎 Mana: `4` | ⚔️ Poder (ATK): `2800` | ❤️ Vida (HP): `3000`
* **Descrição do Efeito:** *"Só pode ser ativada quando estiver no campo como Carta de Vida. Ao ativar, esta carta só poderá ser destruída por dano de ataque normal convencional após o Turno 7 (imune a destruição por efeitos ou magias)."*
* **Mecânica e Gatilhos:**
  * **Tipo de Gatilho:** `manual`
  * **Zona Permitida para Ativação:** `life`
* **Comportamento e Resolução:** Aplica um estado de imunidade mágica. Até o turno global 7, ela não pode ser destruída ou danificada por efeitos/habilidades de outros cards.

### 🃏 Centopéia Gigante (ID: `65c75b95-f0d6-4e59-8c99-ed628653d45e` / Efeito: `rare_giant_centipede_survive_mill`)
* **Raridade:** `rare` | **Elemento/Tipo:** `Bestiario`
* **Atributos Base:** 💎 Mana: `3` | ⚔️ Poder (ATK): `1800` | ❤️ Vida (HP): `3500`
* **Descrição do Efeito:** *"se o oponente não conseguir destruir essa carta no turno de ataque dele,ou seja se essa carta sobreviver a um ataque no campo de reforço seu oponente perderá todas as cartas da mão dele."*
* **Mecânica e Gatilhos:**
  * **Tipo de Gatilho:** `on_attack_resolved`
  * **Zona Permitida para Ativação:** `reinforcement`
* **Comportamento e Resolução:** Se for defendida e seu `current_life` pós-combate for `> 0`, descarta integralmente todas as cartas na mão do oponente.

### 🃏 Cérbero da Caçada Selvagem (ID: `179e60f0-be17-4930-b884-341182fc1833` / Efeito: `rare_cerberus_deny_reaction`)
* **Raridade:** `rare` | **Elemento/Tipo:** `Bestiario`
* **Atributos Base:** 💎 Mana: `2` | ⚔️ Poder (ATK): `2900` | ❤️ Vida (HP): `2500`
* **Descrição do Efeito:** *"Ative essa carta no seu turno de ataque e seu oponente não terá a tela de reação,não podera reagir."*
* **Mecânica e Gatilhos:**
  * **Tipo de Gatilho:** `manual`
  * **Zona Permitida para Ativação:** `attacker`
* **Comportamento e Resolução:** Suprime temporariamente o estado de janela de reação (`reaction_window`), forçando a engine a saltar diretamente da fase de declaração de ataque para a colisão e cálculo de dano.

### 🃏 Cerlinna a Alpor (ID: `6ff7b791-60f2-4787-9aa0-bc179ee40a37` / Efeito: `rare_cerlinna_discount_varuss`)
* **Raridade:** `rare` | **Elemento/Tipo:** `Vampiro`
* **Atributos Base:** 💎 Mana: `4` | ⚔️ Poder (ATK): `1800` | ❤️ Vida (HP): `2800`
* **Descrição do Efeito:** *"Só pode ser ativado se estiver no campo como Carta de Vida. Altere o custo de mana da carta \"Varuss o Meio Elfo\" dentro do seu deck para =0."*
* **Mecânica e Gatilhos:**
  * **Tipo de Gatilho:** `manual`
  * **Zona Permitida para Ativação:** `life`
* **Comportamento e Resolução:** Localiza a unidade "Varuss o Meio Elfo" no deck do jogador e altera permanentemente seu custo de mana para `0`.

### 🃏 Cerys (ID: `e93c8483-00d5-4b23-92ce-5ac15e1cc345` / Efeito: `rare_cerys_hand_defender`)
* **Raridade:** `rare` | **Elemento/Tipo:** `Civil`
* **Atributos Base:** 💎 Mana: `6` | ⚔️ Poder (ATK): `3000` | ❤️ Vida (HP): `2000`
* **Descrição do Efeito:** *"Ative uma unica vez essa carta direto da sua mão e essa carta em todas as proximas rodadas e turnos ira defender junto de suas cartas de reforço no momento do turno de ataque do oponente e voltara para sua mão logo após intatca com a vida e poder cheios."*
* **Mecânica e Gatilhos:**
  * **Tipo de Gatilho:** `manual` / `reaction`
  * **Zona Permitida para Ativação:** `hand`
* **Comportamento e Resolução:** Cria um efeito passivo. Em todo combate, ela intercepta o ataque inimigo como defensora temporária sem deixar a mão, e recupera 100% de seus atributos após a resolução.

### 🃏 Ciclope (ID: `e3e7209a-485b-43c8-a4ce-47053e4f41e0` / Efeito: `rare_cyclops_bleed_or_discard`)
* **Raridade:** `rare` | **Elemento/Tipo:** `Bestiario`
* **Atributos Base:** 💎 Mana: `0` | ⚔️ Poder (ATK): `1500` | ❤️ Vida (HP): `6000`
* **Descrição do Efeito:** *"Efeito ativado automaticamente Essa carta perde 1000 de vida a cada fim de turno, para essa carta não perder os 1000 de vida descarte uma carta de sua mão no fim da rodada a sua escolha."*
* **Mecânica e Gatilhos:**
  * **Tipo de Gatilho:** `on_turn_end`
  * **Zona Permitida para Ativação:** `field`
* **Comportamento e Resolução:** Monitorado no final de cada turno. Se o jogador não descartar um card de sua mão, o Ciclope sofre 1000 pontos de dano puro direto na sua vida.

### 🃏 Dama da Peste (ID: `11fd40fa-587d-4d7f-aa69-934dce00ca5e` / Efeito: `rare_plague_maiden_purge_enemy_graveyard`)
* **Raridade:** `rare` | **Elemento/Tipo:** `Bestiario`
* **Atributos Base:** 💎 Mana: `4` | ⚔️ Poder (ATK): `2500` | ❤️ Vida (HP): `2000`
* **Descrição do Efeito:** *"Ative este efeito e limpe (purga total) todo o cemitério do oponente."*
* **Mecânica e Gatilhos:**
  * **Tipo de Gatilho:** `manual`
  * **Zona Permitida para Ativação:** `hand`
* **Comportamento e Resolução:** Deleta ou exila em massa todas as cartas do cemitério inimigo (`zone = 'graveyard'`), desfazendo mecânicas de reanimação.

### 🃏 Dama de Ferro (ID: `ae2fc8d1-6390-453f-b984-e324fbed6ac9` / Efeito: `rare_iron_maiden_guaranteed_opener`)
* **Raridade:** `rare` | **Elemento/Tipo:** `Civil`
* **Atributos Base:** 💎 Mana: `0` | ⚔️ Poder (ATK): `2500` | ❤️ Vida (HP): `2400`
* **Descrição do Efeito:** *"Efeito passivo que ativa direto do deck: esta carta sempre estará garantida na sua mão inicial no Turno 1."*
* **Mecânica e Gatilhos:**
  * **Tipo de Gatilho:** `passive`
  * **Zona Permitida para Ativação:** `deck`
* **Comportamento e Resolução:** Na fase de embaralhamento e compra inicial, a engine força o posicionamento da Dama de Ferro na mão do jogador antes da partida começar.

### 🃏 Danvis Vampiro Coveiro (ID: `431c3cda-33cf-4860-9892-c2f274cb39d9` / Efeito: `rare_danvis_tax_hand`)
* **Raridade:** `rare` | **Elemento/Tipo:** `Vampiro`
* **Atributos Base:** 💎 Mana: `3` | ⚔️ Poder (ATK): `2500` | ❤️ Vida (HP): `1400`
* **Descrição do Efeito:** *"Aumente o custo de mana de toda a mão atual do oponente em +1."*
* **Mecânica e Gatilhos:**
  * **Tipo de Gatilho:** `manual`
  * **Zona Permitida para Ativação:** `hand`
* **Comportamento e Resolução:** Incrementa em +1 o custo de mana temporário de todas as cartas localizadas no vetor de mão do oponente.

### 🃏 Darion da Escola do Gato (ID: `772fdd16-861f-4b8f-8974-69b00e0c3e66` / Efeito: `comp_darion_hand_robbery`)
* **Raridade:** `rare` | **Elemento/Tipo:** `Witcher`
* **Atributos Base:** 💎 Mana: `3` | ⚔️ Poder (ATK): `2000` | ❤️ Vida (HP): `1000`
* **Descrição do Efeito:** *"Ative este efeito e roube/sequestre compulsoriamente 1 carta aleatória da mão do oponente direto para a sua mão."*
* **Mecânica e Gatilhos:**
  * **Tipo de Gatilho:** `manual`
  * **Zona Permitida para Ativação:** `hand`
* **Comportamento e Resolução:** Seleciona aleatoriamente um card da mão do oponente e transfere a propriedade e posse do registro para a mão do jogador.

### 🃏 Demônio (ID: `117be7df-2666-4eb2-85fe-498b97a9378a` / Efeito: `rare_fiend_peek_hand`)
* **Raridade:** `rare` | **Elemento/Tipo:** `Bestiario`
* **Atributos Base:** 💎 Mana: `2` | ⚔️ Poder (ATK): `2000` | ❤️ Vida (HP): `2700`
* **Descrição do Efeito:** *"Veja todas as cartas da mão do seu oponente."*
* **Mecânica e Gatilhos:**
  * **Tipo de Gatilho:** `manual`
  * **Zona Permitida para Ativação:** `hand`
* **Comportamento e Resolução:** Retorna a listagem e detalhes completos de todos os cards da mão do oponente para renderização no cliente.

### 🃏 Diana de Tauren (ID: `4f17311a-ad66-4e16-a12d-c887070b6b05` / Efeito: `rare_diana_trade_life_for_elites`)
* **Raridade:** `rare` | **Elemento/Tipo:** `Civil`
* **Atributos Base:** 💎 Mana: `2` | ⚔️ Poder (ATK): `2750` | ❤️ Vida (HP): `2250`
* **Descrição do Efeito:** *"Ao ativar, uma Carta de Vida aleatória do oponente será destruída. Em contrapartida, todas as cartas de raridade lendária e épica do seu próprio deck serão destruídas e enviadas ao seu cemitério."*
* **Mecânica e Gatilhos:**
  * **Tipo de Gatilho:** `manual`
  * **Zona Permitida para Ativação:** `hand`
* **Comportamento e Resolução:** Executa a destruição instantânea de uma vida inimiga. Em paralelo, move todas as cartas com raridades `epic` ou `legendary` do deck do conjurador para seu cemitério.

### 🃏 Dismas da Escola da Manticora (ID: `c8f62192-19c2-46cf-a819-772a0fc1cc74` / Efeito: `comp_dismas_death_heal_adjacent_life`)
* **Raridade:** `rare` | **Elemento/Tipo:** `Witcher`
* **Atributos Base:** 💎 Mana: `2` | ⚔️ Poder (ATK): `1500` | ❤️ Vida (HP): `3000`
* **Descrição do Efeito:** *"Ao ser destruído no campo de reforço, cura (ou adiciona) +1000 de Vida diretamente à Carta de Vida aliada mais próxima de seu slot na mesa."*
* **Mecânica e Gatilhos:**
  * **Tipo de Gatilho:** `on_destroyed`
  * **Zona Permitida para Ativação:** `reinforcement`
* **Comportamento e Resolução:** No evento de destruição de Dismas em sua respectiva posição, cura a carta de vida aliada localizada no mesmo índice de slot (ou no mais próximo).

### 🃏 DROGODAR (ID: `007fca25-b793-43d4-81ad-c96126adfc5e` / Efeito: `rare_drogodar_set_deck_mana`)
* **Raridade:** `rare` | **Elemento/Tipo:** `Civil`
* **Atributos Base:** 💎 Mana: `6` | ⚔️ Poder (ATK): `2600` | ❤️ Vida (HP): `2600`
* **Descrição do Efeito:** *"Ao ativar o efeito dessa carta todas as suas cartas dentro do seu deck terão o custo de mana definidos em =4 até o fim do jogo."*
* **Mecânica e Gatilhos:**
  * **Tipo de Gatilho:** `manual`
  * **Zona Permitida para Ativação:** `hand`
* **Comportamento e Resolução:** Altera permanentemente na tabela de controle de deck os custos de mana de todos os cards restantes do jogador para exatamente `4`.

### 🃏 Enel Ducat - Agente de Inteligencia (ID: `71a5cf75-093b-4333-873b-3d9f6463321c` / Efeito: `rare_enel_legendary_tutor`)
* **Raridade:** `rare` | **Elemento/Tipo:** `Civil`
* **Atributos Base:** 💎 Mana: `0` | ⚔️ Poder (ATK): `700` | ❤️ Vida (HP): `2000`
* **Descrição do Efeito:** *"Só pode ser ativado se o oponente passou a rodada/turno anterior dele sem agir. Compre uma carta de raridade lendária do seu deck à sua escolha (seleção)."*
* **Mecânica e Gatilhos:**
  * **Tipo de Gatilho:** `manual`
  * **Zona Permitida para Ativação:** `hand`
* **Comportamento e Resolução:** Verifica se a última ação no histórico foi uma passagem de turno passiva do oponente. Em caso afirmativo, abre tela de busca no deck para o jogador selecionar e comprar uma carta `legendary`.

### 🃏 Etéreo (ID: `951c0b8e-a3de-4d52-9afd-8659459dfbd5` / Efeito: `rare_ethereal_tutor_pairs`)
* **Raridade:** `rare` | **Elemento/Tipo:** `Bestiario`
* **Atributos Base:** 💎 Mana: `4` | ⚔️ Poder (ATK): `2000` | ❤️ Vida (HP): `2500`
* **Descrição do Efeito:** *"Saque para sua mão duas cartas idênticas (que tenham mais de 2 cópias) que ainda estiverem no seu deck."*
* **Mecânica e Gatilhos:**
  * **Tipo de Gatilho:** `manual`
  * **Zona Permitida para Ativação:** `hand`
* **Comportamento e Resolução:** Varre o deck do jogador buscando cartas com mesma identificação/código com quantidade em estoque `>= 2` e as saca para a mão.

### 🃏 Feitiçeira Jhenny (ID: `23fadb63-8245-4893-abcd-12a1a26ac92a` / Efeito: `rare_jhenny_uninterruptible_mf`)
* **Raridade:** `rare` | **Elemento/Tipo:** `M&F`
* **Atributos Base:** 💎 Mana: `0` | ⚔️ Poder (ATK): `2800` | ❤️ Vida (HP): `2600`
* **Descrição do Efeito:** *"Ative esse efeito e impeça que o oponente consiga reagir ao efeito de custo de mana que você ativar de uma carta do tipo M&F."*
* **Mecânica e Gatilhos:**
  * **Tipo de Gatilho:** `manual`
  * **Zona Permitida para Ativação:** `hand`
* **Comportamento e Resolução:** Registra uma flag de interrupção na engine. A próxima mágica executada pelo jogador com tipo `M&F` não concede janela de reação ao oponente.

### 🃏 Feitiçeira Morgana (ID: `c3b0e53c-04eb-4ab5-92de-431ff79da2e6` / Efeito: `rare_morgana_skip_entire_round`)
* **Raridade:** `rare` | **Elemento/Tipo:** `M&F`
* **Atributos Base:** 💎 Mana: `6` | ⚔️ Poder (ATK): `2250` | ❤️ Vida (HP): `2500`
* **Descrição do Efeito:** *"Ative na sua rodada e faça o seu oponente perder a próxima rodada dele inteira."*
* **Mecânica e Gatilhos:**
  * **Tipo de Gatilho:** `manual`
  * **Zona Permitida para Ativação:** `hand`
* **Comportamento e Resolução:** Altera o status da engine de turnos, forçando o oponente a passar e concedendo uma rodada/ação adicional consecutiva para o conjurador.

### 🃏 Feiticeira Scalet (ID: `fe11a989-a26c-4f41-8a10-9e4bbfd6e41e` / Efeito: `rare_scalet_summon_beast_attacker`)
* **Raridade:** `rare` | **Elemento/Tipo:** `M&F`
* **Atributos Base:** 💎 Mana: `0` | ⚔️ Poder (ATK): `2000` | ❤️ Vida (HP): `2000`
* **Descrição do Efeito:** *"Puxe uma carta do tipo Bestiário aleatória do seu deck para o campo para atacar junto desta carta."*
* **Mecânica e Gatilhos:**
  * **Tipo de Gatilho:** `manual`
  * **Zona Permitida para Ativação:** `hand` / `attacker`
* **Comportamento e Resolução:** Saca uma carta aleatória do deck com `element = 'Bestiario'` e a posiciona diretamente na zona `attacker` para participar do combate imediatamente.

### 🃏 Feiticeira Selenne (ID: `220f1f5c-65db-4f19-8769-859ff66d738f` / Efeito: `comp_selenne_discard_scaling_buff`)
* **Raridade:** `rare` | **Elemento/Tipo:** `M&F`
* **Atributos Base:** 💎 Mana: `0` | ⚔️ Poder (ATK): `1000` | ❤️ Vida (HP): `1000`
* **Descrição do Efeito:** *"Ative e descarte quantas cartas você quiser da sua mão para o cemitério. Cada carta descartada aumenta permanentemente em +2000 a Vida e +2000 o Poder de Selenne."*
* **Mecânica e Gatilhos:**
  * **Tipo de Gatilho:** `manual`
  * **Zona Permitida para Ativação:** `hand`
* **Comportamento e Resolução:** Abre diálogo de seleção na mão do jogador. Descarta as cartas escolhidas e incrementa `+2000 ATK` e `+2000 HP` a Selenne para cada descarte computado.

### 🃏 Feitiçeira Sylvanna (ID: `53553446-9e27-4859-919a-3be3cc035677` / Efeito: `rare_sylvanna_random_revive_hand`)
* **Raridade:** `rare` | **Elemento/Tipo:** `Bestiario`
* **Atributos Base:** 💎 Mana: `2` | ⚔️ Poder (ATK): `1800` | ❤️ Vida (HP): `2800`
* **Descrição do Efeito:** *"Traga uma carta aleatoria de seu cemitério para sua mão."*
* **Mecânica e Gatilhos:**
  * **Tipo de Gatilho:** `manual`
  * **Zona Permitida para Ativação:** `hand`
* **Comportamento e Resolução:** Seleciona aleatoriamente qualquer card na zona `graveyard` do jogador e altera sua zona de volta para `hand`.

### 🃏 Fleder (ID: `9d3aee6e-92a7-45e4-a6ac-99c3cb098a2d` / Efeito: `rare_fleder_turn1_triple_strike`)
* **Raridade:** `rare` | **Elemento/Tipo:** `Vampiro`
* **Atributos Base:** 💎 Mana: `3` | ⚔️ Poder (ATK): `2100` | ❤️ Vida (HP): `2600`
* **Descrição do Efeito:** *"Só pode ser ativado no Turno 1 (primeiro turno do jogo). Esta carta ataca simultaneamente as 3 Cartas de Vida do oponente."*
* **Mecânica e Gatilhos:**
  * **Tipo de Gatilho:** `manual`
  * **Zona Permitida para Ativação:** `hand` / `attacker`
* **Comportamento e Resolução:** Se for o Turno 1, desfere um golpe de `2100` de dano contra todas as 3 vidas adversárias de uma única vez.

### 🃏 Garklain (ID: `fbe1a0fa-0265-47c1-81f8-89befe631ac0` / Efeito: `rare_garklain_steal_stats`)
* **Raridade:** `rare` | **Elemento/Tipo:** `Vampiro`
* **Atributos Base:** 💎 Mana: `2` | ⚔️ Poder (ATK): `2700` | ❤️ Vida (HP): `2700`
* **Descrição do Efeito:** *"Rouba 50% da Vida atual e do Poder atual de uma Carta de Vida do oponente que tenha ativado efeito neste turno ou no anterior, somando esses valores aos atributos desta carta antes do cálculo de dano (no ataque ou como reforço defensor)."*
* **Mecânica e Gatilhos:**
  * **Tipo de Gatilho:** `passive`
  * **Zona Permitida para Ativação:** `field`
* **Comportamento e Resolução:** Localiza a vida inimiga elegível (que conjurou habilidades recentemente). Subtrai `50%` do seu ATK e HP atuais e os adiciona ao poder/vida de Garklain.

### 🃏 General Franz de Teméria (ID: `e2b24737-8b31-4db1-a2a2-2b49554650bd` / Efeito: `rare_franz_graveyard_bounce`)
* **Raridade:** `rare` | **Elemento/Tipo:** `Civil`
* **Atributos Base:** 💎 Mana: `0` | ⚔️ Poder (ATK): `2000` | ❤️ Vida (HP): `2000`
* **Descrição do Efeito:** *"Após realizar um ataque com esta carta, escolha se quer exilar/limpar uma carta do seu cemitério para que Franz retorne imediatamente para a sua mão."*
* **Mecânica e Gatilhos:**
  * **Tipo de Gatilho:** `on_attack_resolved`
  * **Zona Permitida para Ativação:** `attacker`
* **Comportamento e Resolução:** Ao terminar a ação de ataque, se o cemitério não estiver vazio, permite exilar 1 card dali para retornar Franz diretamente para a zona `hand`.

### 🃏 Heythan da Escola do Lobo (ID: `dbf0e94b-d96d-4b05-bae0-3de01943c9c1` / Efeito: `rare_heythan_discard_common`)
* **Raridade:** `rare` | **Elemento/Tipo:** `Witcher`
* **Atributos Base:** 💎 Mana: `2` | ⚔️ Poder (ATK): `1800` | ❤️ Vida (HP): `1100`
* **Descrição do Efeito:** *"Ative este efeito e force o oponente a descartar para o cemitério uma carta aleatória da mão dele que seja especificamente de raridade comum (rarity = \"common\")."*
* **Mecânica e Gatilhos:**
  * **Tipo de Gatilho:** `manual`
  * **Zona Permitida para Ativação:** `hand`
* **Comportamento e Resolução:** Localiza os cards com `rarity = 'common'` na mão do oponente. Escolhe um aleatório e o transfere para o cemitério inimigo.

### 🃏 Hjalmar (ID: `ca5db2c9-8f02-4edf-82ff-0856f92a8a9a` / Efeito: `rare_hjalmar_scale_power`)
* **Raridade:** `rare` | **Elemento/Tipo:** `Civil`
* **Atributos Base:** 💎 Mana: `0` | ⚔️ Poder (ATK): `1250` | ❤️ Vida (HP): `1000`
* **Descrição do Efeito:** *"O Efeito dessa carta ativa sozinho automaticamente passivamente logo quando essa carta é comprada de seu deck a sua mão,no inicio de cada rodada essa carta ganha +500 de poder."*
* **Mecânica e Gatilhos:**
  * **Tipo de Gatilho:** `on_draw` / `on_turn_start`
  * **Zona Permitida para Ativação:** `hand`
* **Comportamento e Resolução:** Quando sacado ou a cada novo turno que permaneça sob a posse da mão, incrementa passivamente seu poder de ataque em `+500`.

### 🃏 Ifrit (ID: `8cbe0547-8b69-4dcb-97fb-a0b396bb2088` / Efeito: `rare_elemental_lock_high_power`)
* **Raridade:** `rare` | **Elemento/Tipo:** `Bestiario`
* **Atributos Base:** 💎 Mana: `2` | ⚔️ Poder (ATK): `1700` | ❤️ Vida (HP): `2900`
* **Descrição do Efeito:** *"Só pode ser ativado se esta carta estiver no campo como Carta de Vida. Ao ativar, nenhuma carta com Poder superior a 4000 poderá ser colocada em campo por nenhum jogador."*
* **Mecânica e Gatilhos:**
  * **Tipo de Gatilho:** `manual` / `passive`
  * **Zona Permitida para Ativação:** `life`
* **Comportamento e Resolução:** Aplica trava operacional na engine. Impede o posicionamento de qualquer card cuja força base ou atual exceda `4000` pontos em campo.

### 🃏 Jansen da Escola da Coruja (ID: `96a1140f-aa68-4483-a888-2e69940a2d1c` / Efeito: `rare_jansen_tutor_witcher`)
* **Raridade:** `rare` | **Elemento/Tipo:** `Witcher`
* **Atributos Base:** 💎 Mana: `3` | ⚔️ Poder (ATK): `1350` | ❤️ Vida (HP): `1900`
* **Descrição do Efeito:** *"Só pode ser ativado se houver uma carta \"Morvim da Escola da Coruja\" na sua mão. Compre (saque para a mão) uma carta do tipo Witcher à sua escolha do seu deck."*
* **Mecânica e Gatilhos:**
  * **Tipo de Gatilho:** `manual`
  * **Zona Permitida para Ativação:** `hand`
* **Comportamento e Resolução:** Valida a presença de Morvim na mão do jogador. Em caso positivo, busca e transfere qualquer card com elemento `Witcher` do deck para a mão.

### 🃏 Kikimora (ID: `18258d15-9f0f-42e9-935d-c9deb7a6a03a` / Efeito: `rare_kikimore_witcher_death_discount`)
* **Raridade:** `rare` | **Elemento/Tipo:** `Bestiario`
* **Atributos Base:** 💎 Mana: `3` | ⚔️ Poder (ATK): `2700` | ❤️ Vida (HP): `3000`
* **Descrição do Efeito:** *"Se esta carta for destruída por uma carta do tipo Witcher do oponente, mude o custo de mana de uma carta da sua mão à sua escolha para 0."*
* **Mecânica e Gatilhos:**
  * **Tipo de Gatilho:** `on_destroyed`
  * **Zona Permitida para Ativação:** `field`
* **Comportamento e Resolução:** Se a cause de sua morte for combate com um `Witcher` adversário, abre diálogo para zerar o custo de mana de um card na mão do jogador.

### 🃏 Kraken (ID: `375e19a9-8fd3-44da-a530-75afa7eea65a` / Efeito: `rare_kraken_damage_cap_spill`)
* **Raridade:** `rare` | **Elemento/Tipo:** `Bestiario`
* **Atributos Base:** 💎 Mana: `0` | ⚔️ Poder (ATK): `2400` | ❤️ Vida (HP): `3000`
* **Descrição do Efeito:** *"Passivo. Esta carta só perderá no máximo 1000 de Vida por turno. O dano excedente ultrapassará para a próxima carta de reforço, mas o Kraken permanece intocável no campo após sofrer esses 1000 de dano."*
* **Mecânica e Gatilhos:**
  * **Tipo de Gatilho:** `passive`
  * **Zona Permitida para Ativação:** `field`
* **Comportamento e Resolução:** Modifica o pipeline de dano recebido. Limita o impacto sofrido em `1000` HP, redirecionando qualquer dano restante/excedente do golpe para a unidade de reforço ao lado.

### 🃏 Lagaz (ID: `d0f4ffb0-a1af-4e25-b280-30279126476c` / Efeito: `rare_lagaz_force_reinforcement_fill`)
* **Raridade:** `rare` | **Elemento/Tipo:** `Bestiario`
* **Atributos Base:** 💎 Mana: `3` | ⚔️ Poder (ATK): `2200` | ❤️ Vida (HP): `2300`
* **Descrição do Efeito:** *"Ao ativar, todos os campos vagos de reforço do oponente são preenchidos compulsoriamente por cartas aleatórias da mão dele viradas para baixo."*
* **Mecânica e Gatilhos:**
  * **Tipo de Gatilho:** `manual`
  * **Zona Permitida para Ativação:** `hand`
* **Comportamento e Resolução:** Aloca de forma compulsória cards aleatórios da mão adversária para preencher todos os seus slots livres na fileira de defesa, mantendo-os ocultos (`is_face_up = false`).

### 🃏 Lamia (ID: `6d9632a4-b1f6-4993-832a-84b1608bba18` / Efeito: `comp_lamia_graveyard_return_loop`)
* **Raridade:** `rare` | **Elemento/Tipo:** `Vampiro`
* **Atributos Base:** 💎 Mana: `0` | ⚔️ Poder (ATK): `1800` | ❤️ Vida (HP): `2500`
* **Descrição do Efeito:** *"Passivo no cemitério. No início de cada rodada, se o jogador tiver menos cartas na mão do que o limite máximo atual, Lamia ressuscita do cemitério para a mão."*
* **Mecânica e Gatilhos:**
  * **Tipo de Gatilho:** `passive` / `on_turn_start`
  * **Zona Permitida para Ativação:** `graveyard`
* **Comportamento e Resolução:** Se localizada no cemitério no início de um turno, e a contagem de cards na mão do dono for inferior ao limite máximo, altera sua zona automaticamente para `hand`.

### 🃏 Mago Arminho (ID: `f0e84a86-5dfa-4cd5-8b19-46c0023d3552` / Efeito: `rare_ermion_purge_graveyards`)
* **Raridade:** `rare` | **Elemento/Tipo:** `M&F`
* **Atributos Base:** 💎 Mana: `1` | ⚔️ Poder (ATK): `1500` | ❤️ Vida (HP): `2500`
* **Descrição do Efeito:** *"Limpe todos os cemitérios do campo o seu e de seu oponente."*
* **Mecânica e Gatilhos:**
  * **Tipo de Gatilho:** `manual`
  * **Zona Permitida para Ativação:** `hand`
* **Comportamento e Resolução:** Deleta todas as instâncias e referências de cards associados à zona `graveyard` para ambos os duelistas.

### 🃏 Morvim da Escola da Coruja (ID: `8a464994-f624-477a-98b7-399a881dff4d` / Efeito: `rare_morvran_ursulla_direct_snipes`)
* **Raridade:** `rare` | **Elemento/Tipo:** `Witcher`
* **Atributos Base:** 💎 Mana: `0` | ⚔️ Poder (ATK): `1300` | ❤️ Vida (HP): `600`
* **Descrição do Efeito:** *"Ao ativar, ataque uma Carta de Vida diretamente aleatória do oponente para cada carta com o nome \"Ursulla\" presente no deck do oponente."*
* **Mecânica e Gatilhos:**
  * **Tipo de Gatilho:** `manual`
  * **Zona Permitida para Ativação:** `hand` / `attacker`
* **Comportamento e Resolução:** Conta as instâncias de "Ursulla" no deck adversário. Executa esse mesmo número de ataques diretos de `1300` contra vidas aleatórias do adversário.

### 🃏 Morvudd (ID: `c20f9e54-76d6-417f-af8c-186f81688ec6` / Efeito: `rare_morvudd_stat_invert`)
* **Raridade:** `rare` | **Elemento/Tipo:** `Bestiario`
* **Atributos Base:** 💎 Mana: `4` | ⚔️ Poder (ATK): `2300` | ❤️ Vida (HP): `2600`
* **Descrição do Efeito:** *"Ative este efeito e inverta a Vida atual e o Poder atual de uma carta de defesa do oponente à sua escolha (seleção interativa)."*
* **Mecânica e Gatilhos:**
  * **Tipo de Gatilho:** `manual`
  * **Zona Permitida para Ativação:** `hand`
* **Comportamento e Resolução:** Exige a seleção de uma unidade de defesa inimiga. Troca os valores das colunas `current_power` e `current_life` da unidade visada.

### 🃏 Nivellen (ID: `4f9eb63d-fb41-4d48-94d5-b1926882e7a1` / Efeito: `rare_nivellen_private_peek`)
* **Raridade:** `rare` | **Elemento/Tipo:** `Bestiario`
* **Atributos Base:** 💎 Mana: `1` | ⚔️ Poder (ATK): `2000` | ❤️ Vida (HP): `2500`
* **Descrição do Efeito:** *"Essa carta só pode ser ativa direto de sua mão,ative essa carta e revele(veja) os reforços não revelados ainda do campo inimigo."*
* **Mecânica e Gatilhos:**
  * **Tipo de Gatilho:** `manual`
  * **Zona Permitida para Ativação:** `hand`
* **Comportamento e Resolução:** Envia em caráter privado os dados de identificação visual das cartas de defesa viradas para baixo do oponente ao cliente do jogador.

### 🃏 Orianna (ID: `bdc2e63e-a2d2-4a46-8b13-cefc8e1d5404` / Efeito: `rare_orianna_reinforcement_throttle`)
* **Raridade:** `rare` | **Elemento/Tipo:** `Vampiro`
* **Atributos Base:** 💎 Mana: `4` | ⚔️ Poder (ATK): `2400` | ❤️ Vida (HP): `2000`
* **Descrição do Efeito:** *"Só pode ser ativada as Carta de Vida no campo. O oponente só poderá posicionar no máximo 1 carta de reforço no campo dele por rodada até Orianna ser destruída."*
* **Mecânica e Gatilhos:**
  * **Tipo de Gatilho:** `manual` / `passive`
  * **Zona Permitida para Ativação:** `life`
* **Comportamento e Resolução:** Enquanto Orianna estiver ativa as vida, o motor de regras limita as invocações de defesa (`reinforcement`) do oponente a no máximo 1 card por turno.

### 🃏 Protofleders (ID: `4a3083ee-9433-4f10-b32d-4d6eaf77bd5d` / Efeito: `comp_protofleders_coinflip_snipe`)
* **Raridade:** `rare` | **Elemento/Tipo:** `Vampiro`
* **Atributos Base:** 💎 Mana: `5` | ⚔️ Poder (ATK): `2900` | ❤️ Vida (HP): `2700`
* **Descrição do Efeito:** *"Ao ativar, 50% de chance de desferir um ataque direto com seu Poder (2900) contra uma Carta de Vida inimiga aleatória, e 50% de chance de falhar completamente."*
* **Mecânica e Gatilhos:**
  * **Tipo de Gatilho:** `manual`
  * **Zona Permitida para Ativação:** `hand` / `attacker`
* **Comportamento e Resolução:** Sorteia um número. Se `random() < 0.5`, desfere o ataque devastador direto à vida do oponente. Em caso contrário, a habilidade dissipa sem causar impacto.

### 🃏 Qebehsenuef o elfo (ID: `48ec3bf0-2587-41cc-a1c2-38aaf0ef36d7` / Efeito: `rare_qebehsenuef_scale_by_enemy_commons`)
* **Raridade:** `rare` | **Elemento/Tipo:** `Elfica`
* **Atributos Base:** 💎 Mana: `0` | ⚔️ Poder (ATK): `1300` | ❤️ Vida (HP): `1`
* **Descrição do Efeito:** *"Passivo automático. Esta carta ganha +250 de Vida para cada carta de raridade comum presente no deck do oponente."*
* **Mecânica e Gatilhos:**
  * **Tipo de Gatilho:** `passive`
  * **Zona Permitida para Ativação:** `field`
* **Comportamento e Resolução:** Ao entrar em jogo, conta a quantidade de cartas com `rarity = 'common'` no deck adversário e incrementa seu HP máximo em `(contagem * 250)`.

### 🃏 Rience (ID: `f1c9e952-ac48-4723-849f-559cd2f85947` / Efeito: `rare_rience_turn_skip_draw`)
* **Raridade:** `rare` | **Elemento/Tipo:** `M&F`
* **Atributos Base:** 💎 Mana: `4` | ⚔️ Poder (ATK): `2650` | ❤️ Vida (HP): `1200`
* **Descrição do Efeito:** *"Ative essa carta no seu turno de ataque e forçe o oponente a passar o turno dele porem ele comprará mais duas cartas extras do deck dele além da compra normal do turno."*
* **Mecânica e Gatilhos:**
  * **Tipo de Gatilho:** `manual`
  * **Zona Permitida para Ativação:** `attacker`
* **Comportamento e Resolução:** Pula a próxima fase de ação/turno do adversário, forçando-o a passar, mas adiciona 2 cartas de seu deck direto à sua mão.

### 🃏 Ronnan (ID: `6c033009-346e-4f76-acb3-184c780e45c8` / Efeito: `rare_ronnan_lock_direct_attack`)
* **Raridade:** `rare` | **Elemento/Tipo:** `Bestiario`
* **Atributos Base:** 💎 Mana: `2` | ⚔️ Poder (ATK): `2900` | ❤️ Vida (HP): `3200`
* **Descrição do Efeito:** *"Essa carta só pode ser ativada se estiver como carta de vida no campo,ative essa carta e nenhum jogador poderá ativar efeitos de ataque direto(efeito de atacar cartas de vida um dos outros)."*
* **Mecânica e Gatilhos:**
  * **Tipo de Gatilho:** `passive`
  * **Zona Permitida para Ativação:** `life`
* **Comportamento e Resolução:** Bloqueia a execução de habilidades que possuam lógica de ataque direto contra slots da zona `life`.

### 🃏 Shaelmar (ID: `0e36935e-eb9e-457e-9d4b-e94fab187880` / Efeito: `rare_shaelmar_trade_life`)
* **Raridade:** `rare` | **Elemento/Tipo:** `Bestiario`
* **Atributos Base:** 💎 Mana: `4` | ⚔️ Poder (ATK): `1800` | ❤️ Vida (HP): `3000`
* **Descrição do Efeito:** *"Ative essa carta e destrua uma carta de vida do oponente a sua escolha no campo dele e o oponente escolhera uma carta de vida no seu campo para ficar com vida=1000."*
* **Mecânica e Gatilhos:**
  * **Tipo de Gatilho:** `manual`
  * **Zona Permitida para Ativação:** `hand`
* **Comportamento e Resolução:** Destrói instantaneamente uma vida inimiga selecionada. Em compensação, o oponente seleciona uma vida do conjurador e reduz seu HP para exatamente `1000`.

### 🃏 Sigrith Gowdie - A Bruxa (ID: `cae465b1-3a06-4244-b27b-9f29a6b8002e` / Efeito: `rare_sigrith_graveyard_engine`)
* **Raridade:** `rare` | **Elemento/Tipo:** `M&F`
* **Atributos Base:** 💎 Mana: `5` | ⚔️ Poder (ATK): `2500` | ❤️ Vida (HP): `2500`
* **Descrição do Efeito:** *"Só pode ser ativada como Carta de Vida no campo. A cada início de rodada do jogador, ele comprará compulsoriamente uma carta do seu próprio cemitério para a mão até Sigrith ser destruída."*
* **Mecânica e Gatilhos:**
  * **Tipo de Gatilho:** `on_turn_start`
  * **Zona Permitida para Ativação:** `life`
* **Comportamento e Resolução:** No início de cada turno de ação do jogador, remove 1 card do cemitério aliado e o devolve para a mão do jogador.

### 🃏 Súcubo (ID: `790b1e7a-e7e3-4945-8026-391ed0cead4a` / Efeito: `rare_succubus_graveyard_treason_strike`)
* **Raridade:** `rare` | **Elemento/Tipo:** `Bestiario`
* **Atributos Base:** 💎 Mana: `6` | ⚔️ Poder (ATK): `2500` | ❤️ Vida (HP): `2500`
* **Descrição do Efeito:** *"Ao ativar, uma carta aleatória do cemitério do oponente é reanimada como espectro atacante e desgere um ataque contra todas as Cartas de Vida do próprio oponente."*
* **Mecânica e Gatilhos:**
  * **Tipo de Gatilho:** `manual`
  * **Zona Permitida para Ativação:** `hand`
* **Comportamento e Resolução:** Invoca temporariamente uma unidade do cemitério inimigo, que ataca as próprias cartas de vida do oponente original com sua força total.

### 🃏 Sylvano (ID: `e1574966-b7b6-4fa0-86d1-757813ac6d5b` / Efeito: `rare_sylvano_beast_revive_tutor`)
* **Raridade:** `rare` | **Elemento/Tipo:** `Bestiario`
* **Atributos Base:** 💎 Mana: `2` | ⚔️ Poder (ATK): `2800` | ❤️ Vida (HP): `1700`
* **Descrição do Efeito:** *"Ative este efeito e compre do seu cemitério uma carta à sua escolha (seleção) do tipo Bestiário que tenha o Poder maior que o desta carta (2800)."*
* **Mecânica e Gatilhos:**
  * **Tipo de Gatilho:** `manual`
  * **Zona Permitida para Ativação:** `hand`
* **Comportamento e Resolução:** Filtra e abre diálogo para escolher um card de elemento `Bestiario` no cemitério aliado que possua `base_power > 2800`, trazendo-o à mão.

### 🃏 Thalorien o Elfo (ID: `d6c06d4e-268e-4d6a-9e91-c480fdba2a63` / Efeito: `rare_thalorien_survive_double_hp`)
* **Raridade:** `rare` | **Elemento/Tipo:** `M&F`
* **Atributos Base:** 💎 Mana: `2` | ⚔️ Poder (ATK): `1800` | ❤️ Vida (HP): `3000`
* **Descrição do Efeito:** *"Ao ativar durante um ataque do oponente, se esta carta sobreviver ao golpe estando no campo de reforço, a Vida dela dobra imediatamente."*
* **Mecânica e Gatilhos:**
  * **Tipo de Gatilho:** `reaction`
  * **Zona Permitida para Ativação:** `reinforcement`
* **Comportamento e Resolução:** Se posicionada na defesa e sofrer um ataque que não reduza seu HP a `<= 0`, dobra seus atributos de HP atual e máximo instantaneamente.

### 🃏 Thanatos da Escola da Víbora (ID: `50b39e39-3a41-4158-b837-8e9c2081c00d` / Efeito: `rare_thanatos_purge_highest_witchers`)
* **Raridade:** `rare` | **Elemento/Tipo:** `Witcher`
* **Atributos Base:** 💎 Mana: `4` | ⚔️ Poder (ATK): `1700` | ❤️ Vida (HP): `1550`
* **Descrição do Efeito:** *"Ao ativar, a carta do tipo Witcher com o maior Poder dentro do deck de cada jogador será destruída e enviada ao cemitério."*
* **Mecânica e Gatilhos:**
  * **Tipo de Gatilho:** `manual`
  * **Zona Permitida para Ativação:** `hand`
* **Comportamento e Resolução:** Localiza o card com elemento `Witcher` de maior poder base de ataque em ambos os decks e os transfere para as respectivas pilhas de descarte.

### 🃏 Tordo (ID: `dc6067a7-1596-48eb-8a76-43303cb807ee` / Efeito: `rare_thrush_bounce_life_swap`)
* **Raridade:** `rare` | **Elemento/Tipo:** `Bestiario`
* **Atributos Base:** 💎 Mana: `0` | ⚔️ Poder (ATK): `2000` | ❤️ Vida (HP): `2000`
* **Descrição do Efeito:** *"Devolva uma Carta de Vida do campo do oponente para a mão dele e force-o imediatamente a colocar outra carta da mão dele no lugar."*
* **Mecânica e Gatilhos:**
  * **Tipo de Gatilho:** `manual`
  * **Zona Permitida para Ativação:** `hand`
* **Comportamento e Resolução:** Devolve uma vida inimiga selecionada para a mão do oponente e força a engine a posicionar outro card da mão dele no mesmo slot aberto.

### 🃏 Trevor da Escola da Manticora (ID: `5dbf0586-e15c-40ac-a86f-2cf7d948043b` / Efeito: `rare_trevor_heal_half`)
* **Raridade:** `rare` | **Elemento/Tipo:** `Witcher`
* **Atributos Base:** 💎 Mana: `2` | ⚔️ Poder (ATK): `1000` | ❤️ Vida (HP): `2400`
* **Descrição do Efeito:** *"Ative e restaure exatamente 50% da Vida máxima de uma Carta de Vida do seu campo que já esteja danificada (current_life < base_max_life)."*
* **Mecânica e Gatilhos:**
  * **Tipo de Gatilho:** `manual`
  * **Zona Permitida para Ativação:** `hand`
* **Comportamento e Resolução:** Restaura `50%` do HP total de uma carta de vida aliada danificada.

### 🃏 Troll de Gelo (ID: `7f7f2e2b-35ed-4071-bf54-03e1e12fce4e` / Efeito: `rare_ice_troll_midgame_banish`)
* **Raridade:** `rare` | **Elemento/Tipo:** `Bestiario`
* **Atributos Base:** 💎 Mana: `3` | ⚔️ Poder (ATK): `2100` | ❤️ Vida (HP): `2700`
* **Descrição do Efeito:** *"Abra outra tela de banimento neste momento para cada jogador banir outra carta que estiver nos decks de cada um."*
* **Mecânica e Gatilhos:**
  * **Tipo de Gatilho:** `manual`
  * **Zona Permitida para Ativação:** `hand`
* **Comportamento e Resolução:** Dispara um novo evento de banimento no meio da partida. Cada jogador seleciona um card do deck do rival para banir/exilar permanentemente.

### 🃏 Varuss o Meio Elfo (ID: `8d7457a0-8a8b-425b-81db-151050485bc0` / Efeito: `rare_varuss_execute_life`)
* **Raridade:** `rare` | **Elemento/Tipo:** `Elfica`
* **Atributos Base:** 💎 Mana: `7` | ⚔️ Poder (ATK): `1800` | ❤️ Vida (HP): `2000`
* **Descrição do Efeito:** *"Só pode ser ativado se houver uma carta \"Cerlinna a Alpor\" no seu cemitério. Destrua uma Carta de Vida do oponente à sua escolha (seleção interativa)."*
* **Mecânica e Gatilhos:**
  * **Tipo de Gatilho:** `manual`
  * **Zona Permitida para Ativação:** `hand`
* **Comportamento e Resolução:** Verifica se Cerlinna está na zona `graveyard` aliada. Se sim, destrói uma carta de vida inimiga selecionada.

### 🃏 Veneno a Mercenária (ID: `d968fa6b-ac0a-48b4-a678-c19bdb200d2a` / Efeito: `rare_venom_tax_random_card`)
* **Raridade:** `rare` | **Elemento/Tipo:** `Civil`
* **Atributos Base:** 💎 Mana: `0` | ⚔️ Poder (ATK): `1200` | ❤️ Vida (HP): `1000`
* **Descrição do Efeito:** *"Aumente em +1 o custo de mana de uma carta aleatória da mão do oponente."*
* **Mecânica e Gatilhos:**
  * **Tipo de Gatilho:** `manual`
  * **Zona Permitida para Ativação:** `hand`
* **Comportamento e Resolução:** Eleva em +1 o custo de mana de um card selecionado aleatoriamente da mão adversária.

### 🃏 Venger o Mercenário (ID: `27d0cffa-01b3-4798-acf9-9e019a1acf84` / Efeito: `rare_venger_life_swap`)
* **Raridade:** `rare` | **Elemento/Tipo:** `Civil`
* **Atributos Base:** 💎 Mana: `3` | ⚔️ Poder (ATK): `2400` | ❤️ Vida (HP): `1500`
* **Descrição do Efeito:** *"Ao ativar, os dois jogadores trocam uma Carta de Vida de seus campos pela do campo do oponente (seleção interativa para ambos ou troca direta por escolha do conjurador)."*
* **Mecânica e Gatilhos:**
  * **Tipo de Gatilho:** `manual`
  * **Zona Permitida para Ativação:** `hand`
* **Comportamento e Resolução:** Troca de lugar uma carta de vida aliada selecionada com uma do campo adversário.

### 🃏 Verme de Areia (ID: `35c905f1-5c27-4cac-baf4-833caaeed64c` / Efeito: `rare_sand_worm_multi_attack`)
* **Raridade:** `rare` | **Elemento/Tipo:** `Bestiario`
* **Atributos Base:** 💎 Mana: `4` | ⚔️ Poder (ATK): `2500` | ❤️ Vida (HP): `3800`
* **Descrição do Efeito:** *"Ative o efeito dessa carta em seu turno de ataque e essa carta realizara um ataque extra(com o poder calculado novamente no ataque total)pelo numero de cartas de vida no campo do inimigo."*
* **Mecânica e Gatilhos:**
  * **Tipo de Gatilho:** `manual`
  * **Zona Permitida para Ativação:** `attacker`
* **Comportamento e Resolução:** Conta o número de cartas de vida vivas no campo adversário. Concede esse exato número de ataques extras contra a fileira de defesa/vida adversária na resolução do turno.

### 🃏 Vernon Roche (ID: `1598c245-0b34-44fe-bd62-74fde42a6253` / Efeito: `rare_vernon_graveyard_mana_boost`)
* **Raridade:** `rare` | **Elemento/Tipo:** `Civil`
* **Atributos Base:** 💎 Mana: `0` | ⚔️ Poder (ATK): `3000` | ❤️ Vida (HP): `2500`
* **Descrição do Efeito:** *"Aumenta a mana maxima de sua mão em +1 na sua proxima rodada(e apenas na proxima rodada) por cada 5 cartas já em seu cemitério."*
* **Mecânica e Gatilhos:**
  * **Tipo de Gatilho:** `manual`
  * **Zona Permitida para Ativação:** `hand`
* **Comportamento e Resolução:** Conta as cartas no cemitério aliado. Para cada 5 cards, incrementa a mana temporária máxima do jogador em +1 para a próxima rodada da partida.

### 🃏 Vivienne (ID: `d4b09be2-ad2c-4310-9188-a8535addfb3a` / Efeito: `rare_vivienne_hand_heal`)
* **Raridade:** `rare` | **Elemento/Tipo:** `Civil`
* **Atributos Base:** 💎 Mana: `2` | ⚔️ Poder (ATK): `0` | ❤️ Vida (HP): `2000`
* **Descrição do Efeito:** *"Ative essa carta direto da sua mão e não de outro local dentro do campo e cure uma carta de vida sua no valor da vida dessa carta."*
* **Mecânica e Gatilhos:**
  * **Tipo de Gatilho:** `manual`
  * **Zona Permitida para Ativação:** `hand`
* **Comportamento e Resolução:** Ativada diretamente da mão. Transfere seu HP base (`2000`) como cura direta contra uma carta de vida aliada selecionada.

### 🃏 Yrsa de Hindar (ID: `19341afb-9957-4f7c-8f6d-4465a79249a9` / Efeito: `rare_yrsa_discard_lowest_mana`)
* **Raridade:** `rare` | **Elemento/Tipo:** `Civil`
* **Atributos Base:** 💎 Mana: `3` | ⚔️ Poder (ATK): `2500` | ❤️ Vida (HP): `1600`
* **Descrição do Efeito:** *"Ao ativar durante um turno de ataque, o oponente perderá (descarte para o cemitério) a carta de menor custo de mana da mão dele aleatoriamente."*
* **Mecânica e Gatilhos:**
  * **Tipo de Gatilho:** `manual`
  * **Zona Permitida para Ativação:** `attacker`
* **Comportamento e Resolução:** Identifica o card de menor custo de mana na mão do oponente e o descarta para a pilha de descarte inimiga.

### 🃏 Zoltan (ID: `f24e35b8-5ba4-4d7b-8b47-f7d86620bbcb` / Efeito: `rare_zoltan_trample_blind_destroy`)
* **Raridade:** `rare` | **Elemento/Tipo:** `Anao`
* **Atributos Base:** 💎 Mana: `3` | ⚔️ Poder (ATK): `2800` | ❤️ Vida (HP): `1000`
* **Descrição do Efeito:** *"Ao ativar durante um turno de ataque, se esta carta conseguir destruir sozinha o primeiro reforço do oponente, destrua o segundo reforço sem sequer revelá-lo ou dar a chance do oponente ativar um efeito de reação."*
* **Mecânica e Gatilhos:**
  * **Tipo de Gatilho:** `on_attack_resolved`
  * **Zona Permitida para Ativação:** `attacker`
* **Comportamento e Resolução:** Se Zoltan derrotar a unidade na primeira defesa inimiga, a engine destrói a unidade da segunda defesa inimiga diretamente, sem revelá-la e sem disparar janelas de reação.
