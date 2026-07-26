# AUDITORIA TÉCNICA DO GRIMÓRIO - PARTE 2 (ÉPICAS E LENDÁRIAS)

Este documento apresenta a ficha técnica e a lógica de resolução de todas as cartas de raridade **ÉPICA (EPIC)** e **LENDÁRIA (LEGENDARY)** ativas no ecossistema do Gwentofier.

---

## 🃏 CARTAS ÉPICAS (EPIC)

### 🃏 Alquimista a Moira (ID: `5c69cca7-f9dc-4444-bef8-aabf01eb228b` / Efeito: `epic_alchemist_moira_life_decay`)
* **Raridade:** `epic` | **Elemento/Tipo:** `Bestiario`
* **Atributos Base:** 💎 Mana: `2` | ⚔️ Poder (ATK): `2000` | ❤️ Vida (HP): `4000`
* **Descrição do Efeito:** *"Ativável no Campo de Vida. TODAS as Cartas de Vida vivas no campo do oponente sofrem uma redução imediata de 30% na Vida atual."*
* **Mecânica e Gatilhos:**
  * **Tipo de Gatilho:** `manual`
  * **Zona Permitida para Ativação:** `life`
* **Comportamento e Resolução:** Quando ativada a partir da zona de vida, a engine executa um `UPDATE` em todas as cartas do oponente que possuam `zone = 'life'`, subtraindo `30%` do seu valor de `current_life` ativo.

### 🃏 Anna Henrieta (ID: `8d51f054-23d7-4b07-bfae-e10c8cbbdc8a` / Efeito: `epic_anna_henrietta_hand_toll`)
* **Raridade:** `epic` | **Elemento/Tipo:** `Civil`
* **Atributos Base:** 💎 Mana: `6` | ⚔️ Poder (ATK): `2400` | ❤️ Vida (HP): `4000`
* **Descrição do Efeito:** *"Ativável no Campo de Vida. Pedágio contínuo: no início de cada rodada inimiga, ele escolhe 1 carta da mão e entrega para você."*
* **Mecânica e Gatilhos:**
  * **Tipo de Gatilho:** `manual` / `on_turn_start`
  * **Zona Permitida para Ativação:** `life`
* **Comportamento e Resolução:** Enquanto Anna Henriqueta estiver ativa como carta de vida, o início de cada turno de ação do oponente dispara uma restrição que exige que ele escolha um card de sua mão e mude sua posse/dono para o jogador conjurador.

### 🃏 AVALACH (ID: `3b5dd913-500f-4383-a2f5-2ea7c81a043a` / Efeito: `epic_avallach_random_legendary_tutor`)
* **Raridade:** `epic` | **Elemento/Tipo:** `Elfica`
* **Atributos Base:** 💎 Mana: `2` | ⚔️ Poder (ATK): `2000` | ❤️ Vida (HP): `4000`
* **Descrição do Efeito:** *"Ao ativar, compra uma carta Lendária aleatória do seu deck."*
* **Mecânica e Gatilhos:**
  * **Tipo de Gatilho:** `manual`
  * **Zona Permitida para Ativação:** `hand`
* **Comportamento e Resolução:** Busca uma carta aleatória com `rarity = 'legendary'` que ainda esteja localizada no deck do jogador e a transfere diretamente para a mão (`zone = 'hand'`).

### 🃏 Baldur de Lyria (ID: `e258b730-5244-4c6a-ac72-9daca1dcf2fb` / Efeito: `epic_baldur_mf_deck_return`)
* **Raridade:** `epic` | **Elemento/Tipo:** `Witcher`
* **Atributos Base:** 💎 Mana: `0` | ⚔️ Poder (ATK): `4000` | ❤️ Vida (HP): `4000`
* **Descrição do Efeito:** *"Passivo automático. Enquanto houver uma carta do tipo M&F no seu Campo de Vida, Baldur sempre retorna da mesa para dentro do seu deck ao final de cada rodada."*
* **Mecânica e Gatilhos:**
  * **Tipo de Gatilho:** `on_turn_end`
  * **Zona Permitida para Ativação:** `field`
* **Comportamento e Resolução:** O auto-engine de fim de turno valida se existe algum card aliado de elemento `M&F` na zona `life`. Em caso afirmativo, move Baldur de volta do campo de batalha para o deck do jogador.

### 🃏 Beann'shie (ID: `8d582db6-1b42-4599-9de9-574150c4f613` / Efeito: `epic_banshee_hand_graveyard_recycle`)
* **Raridade:** `epic` | **Elemento/Tipo:** `Bestiario`
* **Atributos Base:** 💎 Mana: `3` | ⚔️ Poder (ATK): `3000` | ❤️ Vida (HP): `3000`
* **Descrição do Efeito:** *"Descarta sua mão atual e compra do seu próprio cemitério exatamente a mesma quantidade de cartas aleatórias."*
* **Mecânica e Gatilhos:**
  * **Tipo de Gatilho:** `manual`
  * **Zona Permitida para Ativação:** `hand`
* **Comportamento e Resolução:** Altera a zona de todas as cartas na mão do jogador para `graveyard`, conta quantas cartas foram afetadas (`X`), e move `X` cartas aleatórias da zona `graveyard` de volta para a mão.

### 🃏 Caranthir (ID: `96c349b6-1f09-4c7b-a996-10486c1aef7d` / Efeito: `epic_caranthir_purge_all_reinforcements`)
* **Raridade:** `epic` | **Elemento/Tipo:** `Elfica`
* **Atributos Base:** 💎 Mana: `4` | ⚔️ Poder (ATK): `3000` | ❤️ Vida (HP): `3000`
* **Descrição do Efeito:** *"Ao ativar, expurga da mesa e envia para o cemitério TODAS as cartas de reforço posicionadas em ambos os campos."*
* **Mecânica e Gatilhos:**
  * **Tipo de Gatilho:** `manual`
  * **Zona Permitida para Ativação:** `hand`
* **Comportamento e Resolução:** Limpa a fileira de defensores (`reinforcement`) inteira de ambos os lados, enviando todas as cartas ali alocadas direto para seus respectivos cemitérios.

### 🃏 Celenia Vorgues a Elfa (ID: `30e50966-1e5c-4dc1-b684-bcde60f7cebb` / Efeito: `epic_celenia_reset_life_cooldown`)
* **Raridade:** `epic` | **Elemento/Tipo:** `Elfica`
* **Atributos Base:** 💎 Mana: `3` | ⚔️ Poder (ATK): `1000` | ❤️ Vida (HP): `5000`
* **Descrição do Efeito:** *"Ao ativar, seleciona uma Carta de Vida aliada esgotada e purga sua trava de ativação, permitindo novo uso no mesmo turno."*
* **Mecânica e Gatilhos:**
  * **Tipo de Gatilho:** `manual`
  * **Zona Permitida para Ativação:** `hand`
* **Comportamento e Resolução:** Reinicia o estado de cooldown do efeito de uma carta de vida aliada, limpando a flag que impede ativações múltiplas por rodada.

### 🃏 Chorabash (ID: `25e36093-5750-4dec-9798-04ba11998a79` / Efeito: `epic_chorabash_beast_suppress_halve`)
* **Raridade:** `epic` | **Elemento/Tipo:** `Bestiario`
* **Atributos Base:** 💎 Mana: `4` | ⚔️ Poder (ATK): `4000` | ❤️ Vida (HP): `3500`
* **Descrição do Efeito:** *"Ao ativar em um turno de ataque, se a carta alvo inimiga for do elemento Bestiário, seu feitiço/passiva é suprimido imediatamente e sua Vida é reduzida à metade antes da colisão de combate. Sinergia: Se Vaca (COMMON_001) estiver no cemitério do conjurador, Chorabash ganha +1000 ATK/HP permanentes."*
* **Mecânica e Gatilhos:**
  * **Tipo de Gatilho:** `manual`
  * **Zona Permitida para Ativação:** `attacker`
* **Comportamento e Resolução:** Se a unidade inimiga alvejada for do elemento `Bestiario`, remove seus efeitos ativos e divide seu `current_life` por 2. Caso haja uma carta com nome "Vaca" no cemitério aliado, adiciona `+1000` aos atributos de Chorabash.

### 🃏 Conjunção de Esferas (ID: `e5040559-65db-4351-98d3-c2e638b47ecc` / Efeito: `epic_conjunction_instant_win`)
* **Raridade:** `epic` | **Elemento/Tipo:** `Elfica`
* **Atributos Base:** 💎 Mana: `6` | ⚔️ Poder (ATK): `1` | ❤️ Vida (HP): `1`
* **Descrição do Efeito:** *"Só pode ser ativada direto da sua mão se você possuir exatamente 3 cópias idênticas desta carta na sua mão. Ao pagar 6 de Mana e ativar o feitiço, você vence a partida imediatamente."*
* **Mecânica e Gatilhos:**
  * **Tipo de Gatilho:** `manual`
  * **Zona Permitida para Ativação:** `hand`
* **Comportamento e Resolução:** A engine valida se há exatamente 3 instâncias de "Conjunção de Esferas" na mão do jogador. Em caso afirmativo, finaliza o duelo (`status = 'finished'`) e declara o jogador ativo como vencedor.

### 🃏 Crach an Craite (ID: `5ed84249-0444-4916-b2f9-8c7f533d9cbf` / Efeito: `epic_crach_mill_triple_deck`)
* **Raridade:** `epic` | **Elemento/Tipo:** `Civil`
* **Atributos Base:** 💎 Mana: `4` | ⚔️ Poder (ATK): `4000` | ❤️ Vida (HP): `4000`
* **Descrição do Efeito:** *"Seleciona e destrói 3 cartas aleatórias diretamente do deck do oponente, enviando-as ao cemitério."*
* **Mecânica e Gatilhos:**
  * **Tipo de Gatilho:** `manual`
  * **Zona Permitida para Ativação:** `hand`
* **Comportamento e Resolução:** Altera a zona de 3 cartas aleatórias da zona `deck` do oponente para a zona `graveyard`.

### 🃏 Darko o Elfo (ID: `8b155f04-39a7-4c49-b99a-96424a58db5e` / Efeito: `epic_darko_hand_swap_endround`)
* **Raridade:** `epic` | **Elemento/Tipo:** `Elfica`
* **Atributos Base:** 💎 Mana: `4` | ⚔️ Poder (ATK): `2900` | ❤️ Vida (HP): `5000`
* **Descrição do Efeito:** *"Ao ativar, agenda um feitiço transacional: ao final da rodada atual, todas as cartas presentes na sua mão serão permutadas pelas cartas da mão do oponente."*
* **Mecânica e Gatilhos:**
  * **Tipo de Gatilho:** `manual` / `on_turn_end`
  * **Zona Permitida para Ativação:** `hand`
* **Comportamento e Resolução:** Registra um efeito diferido. Quando a rodada termina, a engine troca todas as cartas na zona `hand` do jogador pelas da zona `hand` do oponente.

### 🃏 Djinn (ID: `bd4213d6-c736-498d-8132-663ccd6481d2` / Efeito: `epic_djinn_lock_mf_attack`)
* **Raridade:** `epic` | **Elemento/Tipo:** `Bestiario`
* **Atributos Base:** 💎 Mana: `1` | ⚔️ Poder (ATK): `5000` | ❤️ Vida (HP): `2000`
* **Descrição do Efeito:** *"Ao ativar no Campo de Vida, o oponente fica impedido de usar qualquer carta do tipo M&F na linha de ataque até o Djinn ser destruído. Efeito passivo: se o Djinn for usado para atacar, o jogador perde permanentemente 1 de Mana Máxima até o fim do jogo."*
* **Mecânica e Gatilhos:**
  * **Tipo de Gatilho:** `manual` / `passive`
  * **Zona Permitida para Ativação:** `life`
* **Comportamento e Resolução:** Trava a inserção de cartas `M&F` na zona `attacker` do oponente enquanto Djinn estiver na zona `life`. Se o Djinn atacar, a mana máxima do jogador controlador sofre redutor permanente de -1.

### 🃏 Ekimmu (ID: `be85f335-f299-4094-af13-ae6c7c0230a1` / Efeito: `epic_ekimmu_siphon_hand`)
* **Raridade:** `epic` | **Elemento/Tipo:** `Vampiro`
* **Atributos Base:** 💎 Mana: `3` | ⚔️ Poder (ATK): `3000` | ❤️ Vida (HP): `4000`
* **Descrição do Efeito:** *"Ao ativar, esta carta \"rouba\" 1000 de Vida e 1000 de Poder de TODAS as cartas presentes na mão do jogador oponente."*
* **Mecânica e Gatilhos:**
  * **Tipo de Gatilho:** `manual`
  * **Zona Permitida para Ativação:** `hand`
* **Comportamento e Resolução:** Reduz o ATK e o HP máximo de todas as cartas na mão do oponente em `1000` pontos, somando o valor total drenado aos atributos de Ekimmu.

### 🃏 Emhyr van Emreis (ID: `99c8b1ca-32ba-459b-8d6b-0c22e92b29c0` / Efeito: `epic_emhyr_asymmetric_hand_wipe`)
* **Raridade:** `epic` | **Elemento/Tipo:** `Civil`
* **Atributos Base:** 💎 Mana: `4` | ⚔️ Poder (ATK): `3000` | ❤️ Vida (HP): `3000`
* **Descrição do Efeito:** *"Descarta ambas as mãos. Você compra a mesma quantidade descartada; o oponente compra a metade."*
* **Mecânica e Gatilhos:**
  * **Tipo de Gatilho:** `manual`
  * **Zona Permitida para Ativação:** `hand`
* **Comportamento e Resolução:** Move todas as cartas das mãos dos jogadores para os respectivos cemitérios. Em seguida, saca cartas para o jogador conjurador na mesma quantidade descartada por ele, e metade dessa quantidade para o oponente.

### 🃏 Eskel (ID: `f575d6eb-44f9-4491-a90e-9c45eacfca06` / Efeito: `epic_eskel_double_draw`)
* **Raridade:** `epic` | **Elemento/Tipo:** `Witcher`
* **Atributos Base:** 💎 Mana: `4` | ⚔️ Poder (ATK): `1000` | ❤️ Vida (HP): `4000`
* **Descrição do Efeito:** *"Ao ativar, compra imediatamente 2 cartas do topo do seu deck."*
* **Mecânica e Gatilhos:**
  * **Tipo de Gatilho:** `manual`
  * **Zona Permitida para Ativação:** `hand`
* **Comportamento e Resolução:** Executa o saque de duas cartas (`draw_internal(p_match_id, p_actor, 2)`) adicionando-as à mão do jogador.

### 🃏 Essi Daven a Olhuda (ID: `63e35ac3-8667-4d95-a034-b0fbbb5fef72` / Efeito: `epic_essi_permanent_draw_peek`)
* **Raridade:** `epic` | **Elemento/Tipo:** `Civil`
* **Atributos Base:** 💎 Mana: `5` | ⚔️ Poder (ATK): `1000` | ❤️ Vida (HP): `1500`
* **Descrição do Efeito:** *"Ativável no Campo de Vida. Você ganha visão permanente: todas as cartas que o oponente comprar do deck dele são reveladas."*
* **Mecânica e Gatilhos:**
  * **Tipo de Gatilho:** `passive`
  * **Zona Permitida para Ativação:** `life`
* **Comportamento e Resolução:** Enquanto Essi Daven estiver ativa em um slot de vida, todas as cartas compradas pelo oponente no decorrer da partida são reveladas publicamente para o jogador.

### 🃏 Feiticeira Annie (ID: `f84fb8f5-9c31-49e6-96fb-bb96a7918427` / Efeito: `epic_annie_mimic_past_effect`)
* **Raridade:** `epic` | **Elemento/Tipo:** `M&F`
* **Atributos Base:** 💎 Mana: `4` | ⚔️ Poder (ATK): `2600` | ❤️ Vida (HP): `2300`
* **Descrição do Efeito:** *"Ao ativar, seleciona e ativa aleatoriamente o efeito de uma carta que o seu oponente já tenha ativado durante a partida atual."*
* **Mecânica e Gatilhos:**
  * **Tipo de Gatilho:** `manual`
  * **Zona Permitida para Ativação:** `hand`
* **Comportamento e Resolução:** Pesquisa no histórico de ações da partida (`match_actions`) as cartas cujos efeitos foram executados pelo oponente, selecionando um aleatoriamente para re-executá-lo do lado do conjurador.

### 🃏 Feiticeira Eliah (ID: `f195f54d-4268-4c25-9ce7-422c7951be52` / Efeito: `epic_eliah_effect_immortality`)
* **Raridade:** `epic` | **Elemento/Tipo:** `M&F`
* **Atributos Base:** 💎 Mana: `4` | ⚔️ Poder (ATK): `500` | ❤️ Vida (HP): `4000`
* **Descrição do Efeito:** *"Ative de qualquer local do campo ou da sua mão: esta carta torna-se imune a destruição por efeitos ou feitiços ativados pelo oponente até o fim da partida."*
* **Mecânica e Gatilhos:**
  * **Tipo de Gatilho:** `manual`
  * **Zona Permitida para Ativação:** `hand` / `field`
* **Comportamento e Resolução:** Atribui um modificador persistente que impede que qualquer efeito direto ou dano proveniente de feitiços de cartas adversárias destrua a Feiticeira Eliah.

### 🃏 Feitiçeira Fringilla (ID: `7b11c636-7ec8-46aa-917a-d47ff19b456f` / Efeito: `epic_fringilla_deck_invert_reveal`)
* **Raridade:** `epic` | **Elemento/Tipo:** `M&F`
* **Atributos Base:** 💎 Mana: `3` | ⚔️ Poder (ATK): `2500` | ❤️ Vida (HP): `2500`
* **Descrição do Efeito:** *"Inverte a ordem do baralho do oponente e revela publicamente a nova carta do topo."*
* **Mecânica e Gatilhos:**
  * **Tipo de Gatilho:** `manual`
  * **Zona Permitida para Ativação:** `hand`
* **Comportamento e Resolução:** Inverte a ordenação (`deck_position`) do deck do oponente e altera a propriedade do novo card do topo para ser exibido a ambos os jogadores.

### 🃏 Feiticeira Helena (ID: `e95f53a6-781d-431a-9d3a-f52390271041` / Efeito: `epic_helena_hand_size_squeeze`)
* **Raridade:** `epic` | **Elemento/Tipo:** `M&F`
* **Atributos Base:** 💎 Mana: `6` | ⚔️ Poder (ATK): `3000` | ❤️ Vida (HP): `2700`
* **Descrição do Efeito:** *"Ao ativar, altera permanentemente a regra de limite da mão de ambos os jogadores: de 7 para 4 cartas até o fim do jogo."*
* **Mecânica e Gatilhos:**
  * **Tipo de Gatilho:** `manual`
  * **Zona Permitida para Ativação:** `hand`
* **Comportamento e Resolução:** Altera o limite máximo da mão nas configurações da partida. Qualquer compra que exceda 4 cartas na mão passa a descartar as cartas excedentes direto para o cemitério.

### 🃏 Fetulho (ID: `ad134cc4-4209-44e3-93be-bf88fe3e658a` / Efeito: `epic_botchling_retaliation_draw_curse`)
* **Raridade:** `epic` | **Elemento/Tipo:** `Bestiario`
* **Atributos Base:** 💎 Mana: `4` | ⚔️ Poder (ATK): `1` | ❤️ Vida (HP): `1`
* **Descrição do Efeito:** *"Compre cartas igual ao número usado no último ataque inimigo. Sinergia: Injeta 1 Filho da Puta Júnior (COMMON_013) na mão do oponente."*
* **Mecânica e Gatilhos:**
  * **Tipo de Gatilho:** `manual`
  * **Zona Permitida para Ativação:** `hand`
* **Comportamento e Resolução:** Conta o número de atacantes na última ação de ataque inimiga resolvida. Saca essa mesma quantidade de cartas do deck e cria 1 cópia de "Filho da Puta Júnior" na mão do oponente.

### 🃏 Gigante de Gelo (ID: `9b0923b8-dad3-4165-b915-17e020b0456b` / Efeito: `epic_ice_giant_turn5_scaling`)
* **Raridade:** `epic` | **Elemento/Tipo:** `Bestiario`
* **Atributos Base:** 💎 Mana: `0` | ⚔️ Poder (ATK): `2800` | ❤️ Vida (HP): `4000`
* **Descrição do Efeito:** *"Passivo automático. Esta carta triplica sua própria Vida quando a partida ultrapassar o Turno 5."*
* **Mecânica e Gatilhos:**
  * **Tipo de Gatilho:** `passive`
  * **Zona Permitida para Ativação:** `field`
* **Comportamento e Resolução:** Quando a partida alcança o turno global 5, o auto-engine de transição multiplica o HP máximo e atual do Gigante de Gelo por 3 (`12000` HP).

### 🃏 Hym (ID: `55d93b82-1f2c-4809-ad37-2bcae6823682` / Efeito: `epic_hym_graveyard_hijack`)
* **Raridade:** `epic` | **Elemento/Tipo:** `Bestiario`
* **Atributos Base:** 💎 Mana: `4` | ⚔️ Poder (ATK): `3000` | ❤️ Vida (HP): `4000`
* **Descrição do Efeito:** *"Ao ativar, rouba TODAS as cartas do cemitério do oponente, transferindo-as para o seu próprio cemitério."*
* **Mecânica e Gatilhos:**
  * **Tipo de Gatilho:** `manual`
  * **Zona Permitida para Ativação:** `hand`
* **Comportamento e Resolução:** Realiza transferência em lote mudando o proprietário de todas as cartas na zona `graveyard` do oponente para o jogador conjurador.

### 🃏 Idaran de Ulivo o Mago (ID: `5c70a4f2-6b48-4dab-b9be-e3604b65edfe` / Efeito: `epic_idaran_transmute_enemy_field`)
* **Raridade:** `epic` | **Elemento/Tipo:** `M&F`
* **Atributos Base:** 💎 Mana: `5` | ⚔️ Poder (ATK): `1200` | ❤️ Vida (HP): `1000`
* **Descrição do Efeito:** *"Transmuta (substitui) 1 carta do campo do oponente por 1 carta de mesma raridade dentro do deck dele."*
* **Mecânica e Gatilhos:**
  * **Tipo de Gatilho:** `manual`
  * **Zona Permitida para Ativação:** `hand`
* **Comportamento e Resolução:** Exige a seleção de um card em campo do oponente. Esse card é descartado, e a engine busca uma unidade de raridade idêntica no deck dele para ocupar o slot vago.

### 🃏 Imlerith (ID: `d2addfd8-886a-4bbc-b584-54b0585de55c` / Efeito: `epic_imlerith_round_bleed`)
* **Raridade:** `epic` | **Elemento/Tipo:** `Elfica`
* **Atributos Base:** 💎 Mana: `0` | ⚔️ Poder (ATK): `2000` | ❤️ Vida (HP): `11000`
* **Descrição do Efeito:** *"Passivo automático. Imlerith perde 1000 de Vida ao final de cada rodada do jogo."*
* **Mecânica e Gatilhos:**
  * **Tipo de Gatilho:** `on_turn_end`
  * **Zona Permitida para Ativação:** `field`
* **Comportamento e Resolução:** Ao final de cada turno global de ação, o auto-engine inflige `1000` de dano puro a Imlerith caso esteja posicionado em campo.

### 🃏 Iris Von Everec (ID: `33174b6e-0a2f-482d-9669-11d9c043f4d7` / Efeito: `epic_iris_execute_damaged_life`)
* **Raridade:** `epic` | **Elemento/Tipo:** `Civil`
* **Atributos Base:** 💎 Mana: `2` | ⚔️ Poder (ATK): `2000` | ❤️ Vida (HP): `2000`
* **Descrição do Efeito:** *"Se retornou do cemitério, destrói instantaneamente uma Carta de Vida inimiga danificada (Vida < Vida Máxima)."*
* **Mecânica e Gatilhos:**
  * **Tipo de Gatilho:** `manual`
  * **Zona Permitida para Ativação:** `hand` (Após retornar do `graveyard`)
* **Comportamento e Resolução:** Se reanimada do cemitério, permite escolher uma carta de vida adversária danificada (`current_life < base_max_life`) e a destrói sumariamente.

### 🃏 Kalemir da Escola do Lobo (ID: `c001bc46-55c7-4238-a370-2186734efff9` / Efeito: `epic_kalemir_witcher_hand_reload`)
* **Raridade:** `epic` | **Elemento/Tipo:** `Witcher`
* **Atributos Base:** 💎 Mana: `3` | ⚔️ Poder (ATK): `2900` | ❤️ Vida (HP): `1500`
* **Descrição do Efeito:** *"Ao ativar, embaralha sua mão no deck. Em seguida, busca no deck o mesmo número de cartas devolvidas, escolhendo apenas Witcher."*
* **Mecânica e Gatilhos:**
  * **Tipo de Gatilho:** `manual`
  * **Zona Permitida para Ativação:** `hand`
* **Comportamento e Resolução:** Devolve toda a mão para o deck (`zone = 'deck'`), conta quantas cartas foram enviadas (`N`), e saca do deck `N` cartas que possuam o elemento `Witcher`.

### 🃏 Katakan (ID: `e40d2319-559c-4da9-bd61-579f319697ad` / Efeito: `epic_katakan_suppress_blind_reinforcements`)
* **Raridade:** `epic` | **Elemento/Tipo:** `Vampiro`
* **Atributos Base:** 💎 Mana: `4` | ⚔️ Poder (ATK): `2800` | ❤️ Vida (HP): `2100`
* **Descrição do Efeito:** *"Ao ativar, esta carta \"remove e anula\" o feitiço de todas as cartas de reforço viradas para baixo (ocultas) do oponente, impossibilitando-as de reagirem ou ativarem efeitos defensivos ao serem atacadas."*
* **Mecânica e Gatilhos:**
  * **Tipo de Gatilho:** `manual`
  * **Zona Permitida para Ativação:** `hand`
* **Comportamento e Resolução:** Silencia preventivamente todos os defensores ocultos do oponente, removendo suas habilidades de reação e revelação caso venham a ser atacados.

### 🃏 Lambert (ID: `45e85506-8a4c-4f1a-84b0-562797b9c767` / Efeito: `epic_lambert_mill_random_deck`)
* **Raridade:** `epic` | **Elemento/Tipo:** `Witcher`
* **Atributos Base:** 💎 Mana: `2` | ⚔️ Poder (ATK): `3100` | ❤️ Vida (HP): `2600`
* **Descrição do Efeito:** *"Ative este efeito e destrua uma carta aleatória diretamente do deck do oponente."*
* **Mecânica e Gatilhos:**
  * **Tipo de Gatilho:** `manual`
  * **Zona Permitida para Ativação:** `hand`
* **Comportamento e Resolução:** Seleciona aleatoriamente um card no deck do oponente e altera sua zona para `graveyard`. Retorna no payload JSON o nome da carta triturada para fins de animação.

### 🃏 Letho (ID: `ad1ec989-8348-49ed-aa27-aaf0e596dde8` / Efeito: `epic_letho_summon_restriction`)
* **Raridade:** `epic` | **Elemento/Tipo:** `Witcher`
* **Atributos Base:** 💎 Mana: `0` | ⚔️ Poder (ATK): `5000` | ❤️ Vida (HP): `8000`
* **Descrição do Efeito:** *"Passivo automático. Esta carta não pode ser invocada para o campo enquanto houver qualquer carta do tipo Witcher revelada no campo de reforço ou no campo de vida de NENHUM dos jogadores."*
* **Mecânica e Gatilhos:**
  * **Tipo de Gatilho:** `passive`
  * **Zona Permitida para Ativação:** `hand`
* **Comportamento e Resolução:** A engine de conjuração verifica a mesa. Se houver alguma unidade com tipo `Witcher` em jogo de qualquer um dos lados, bloqueia a invocação de Letho.

### 🃏 Liche (ID: `c1801638-616d-46ee-81bb-2e00505dcbf1` / Efeito: `epic_lich_lock_rare_summons`)
* **Raridade:** `epic` | **Elemento/Tipo:** `Bestiario`
* **Atributos Base:** 💎 Mana: `2` | ⚔️ Poder (ATK): `2900` | ❤️ Vida (HP): `4000`
* **Descrição do Efeito:** *"Só pode ser ativado se estiver no Campo de Vida. Ao ativar, o oponente fica totalmente impedido de invocar ou jogar qualquer carta de raridade Rara direto do deck para a mesa até o Liche ser destruído. Sinergia: Totem (COMMON_033)."*
* **Mecânica e Gatilhos:**
  * **Tipo de Gatilho:** `manual` / `passive`
  * **Zona Permitida para Ativação:** `life`
* **Comportamento e Resolução:** Impõe uma restrição de invocação. O oponente não pode puxar ou baixar nenhuma unidade com `rarity = 'rare'` enquanto o Liche estiver na zona de vida.

### 🃏 Liche Ancião (ID: `07dcfecb-401c-469f-bf0e-4626c8e4f663` / Efeito: `epic_ancient_lich_hand_bleed`)
* **Raridade:** `epic` | **Elemento/Tipo:** `Bestiario`
* **Atributos Base:** 💎 Mana: `0` | ⚔️ Poder (ATK): `4000` | ❤️ Vida (HP): `3500`
* **Descrição do Efeito:** *"Só pode ser ativada no Campo de Vida. Após ativar, em todo início de rodada do oponente, ele será forçado a descartar uma carta à escolha dele da mão até o Liche ser destruído."*
* **Mecânica e Gatilhos:**
  * **Tipo de Gatilho:** `manual` / `on_turn_start`
  * **Zona Permitida para Ativação:** `life`
* **Comportamento e Resolução:** A cada início de turno do oponente, força-o a selecionar e descartar 1 card de sua própria mão.

### 🃏 Lirenne Vorgues a Barda Elfa (ID: `a8783e8b-cccb-4c16-99e1-7c3185851cc8` / Efeito: `epic_lirenne_hand_life_swap`)
* **Raridade:** `epic` | **Elemento/Tipo:** `Elfica`
* **Atributos Base:** 💎 Mana: `2` | ⚔️ Poder (ATK): `1200` | ❤️ Vida (HP): `3000`
* **Descrição do Efeito:** *"Ao ativar, seleciona uma carta da mão e permuta com uma Carta de Vida atualmente em campo."*
* **Mecânica e Gatilhos:**
  * **Tipo de Gatilho:** `manual`
  * **Zona Permitida para Ativação:** `hand`
* **Comportamento e Resolução:** Exige seleção dupla: uma carta na mão e uma na zona de vida. Realiza a troca das zonas físicas das duas cartas envolvidas.

### 🃏 Lisandro Vanderbaster (ID: `a28fa8e8-ab19-4fc7-809d-b8246bf01652` / Efeito: `epic_lisandro_triple_direct_strike`)
* **Raridade:** `epic` | **Elemento/Tipo:** `Elfica`
* **Atributos Base:** 💎 Mana: `6` | ⚔️ Poder (ATK): `3000` | ❤️ Vida (HP): `3000`
* **Descrição do Efeito:** *"Ative este efeito e ataque diretamente as 3 Cartas de Vida do oponente de uma só vez."*
* **Mecânica e Gatilhos:**
  * **Tipo de Gatilho:** `manual`
  * **Zona Permitida para Ativação:** `hand` / `attacker`
* **Comportamento e Resolução:** Ao atacar, inflige `3000` de dano contra todas as 3 vidas ativas do oponente em paralelo, contornando a fileira de defensores.

### 🃏 Lobisomen (ID: `a6269b7c-bacc-4bd8-ab35-90673ed37c19` / Efeito: `epic_werewolf_defensive_power_nullify`)
* **Raridade:** `epic` | **Elemento/Tipo:** `Bestiario`
* **Atributos Base:** 💎 Mana: `4` | ⚔️ Poder (ATK): `3200` | ❤️ Vida (HP): `5000`
* **Descrição do Efeito:** *"Só pode ser ativada na janela de reação defensiva, estando posicionada como carta de reforço. Se o oponente declarou ataque utilizando mais de 3 cartas, cancela e zera completamente o Poder de uma dessas atacantes aleatoriamente."*
* **Mecânica e Gatilhos:**
  * **Tipo de Gatilho:** `reaction`
  * **Zona Permitida para Ativação:** `reinforcement`
* **Comportamento e Resolução:** Se atacado por um conjunto de `>= 3` atacantes, o Lobisomem anula e reduz a 0 a força de ataque de uma dessas unidades inimigas aleatoriamente.

### 🃏 Lucius da Escola do Gato (ID: `0960cced-5e08-4c35-a819-6b3fe5e9c66e` / Efeito: `epic_lucius_scale_by_turns`)
* **Raridade:** `epic` | **Elemento/Tipo:** `Witcher`
* **Atributos Base:** 💎 Mana: `1` | ⚔️ Poder (ATK): `2000` | ❤️ Vida (HP): `1200`
* **Descrição do Efeito:** *"Ao ativar, aumenta permanentemente seu Poder in +1000 para cada rodada que já se passou na partida."*
* **Mecânica e Gatilhos:**
  * **Tipo de Gatilho:** `manual`
  * **Zona Permitida para Ativação:** `hand`
* **Comportamento e Resolução:** Multiplica a rodada atual por `1000` e adiciona o valor resultante ao poder base de Lucius permanentemente.

### 🃏 Lugubre o rei dos penitentes (ID: `9f530b6a-aef3-46db-8633-16c81ec577e3` / Efeito: `epic_mourntart_graveyard_draw_curse`)
* **Raridade:** `epic` | **Elemento/Tipo:** `Bestiario`
* **Atributos Base:** 💎 Mana: `5` | ⚔️ Poder (ATK): `2700` | ❤️ Vida (HP): `4000`
* **Descrição do Efeito:** *"Ativável no Campo de Vida. O oponente, na compra obrigatória, sacará do próprio cemitério (se houver cartas) em vez do deck."*
* **Mecânica e Gatilhos:**
  * **Tipo de Gatilho:** `passive` / `on_draw`
  * **Zona Permitida para Ativação:** `life`
* **Comportamento e Resolução:** Altera o comportamento do saque do oponente. Qualquer compra dele passa a retirar cards de sua zona `graveyard` ao invés do `deck`.

### 🃏 Magnus de Kaedwen (ID: `2c9c0f3d-4352-4804-ba3e-41b7f8423616` / Efeito: `epic_magnus_sigrith_bounce_snipe`)
* **Raridade:** `epic` | **Elemento/Tipo:** `Witcher`
* **Atributos Base:** 💎 Mana: `0` | ⚔️ Poder (ATK): `1500` | ❤️ Vida (HP): `2000`
* **Descrição do Efeito:** *"Passivo. Esta carta ataca diretamente uma Carta de Vida aleatória do oponente e retorna intacta para a mão do jogador enquanto ele controlar a carta \"Sigrith Gowdie - A Bruxa\" em seu Campo de Vida."*
* **Mecânica e Gatilhos:**
  * **Tipo de Gatilho:** `passive`
  * **Zona Permitida para Ativação:** `hand` / `attacker`
* **Comportamento e Resolução:** Se Sigrith estiver na zona `life` aliada, Magnus ataca a vida inimiga diretamente e retorna à mão sem sofrer dano no contra-ataque.

### 🃏 Morvim da Escola do Lince (ID: `8a8e4dc5-60ea-4e0c-8b18-7029b5a791be` / Efeito: `epic_morvran_lynx_banish_slain`)
* **Raridade:** `epic` | **Elemento/Tipo:** `Witcher`
* **Atributos Base:** 💎 Mana: `0` | ⚔️ Poder (ATK): `2500` | ❤️ Vida (HP): `1800`
* **Descrição do Efeito:** *"Ao ativar em combate, qualquer carta inimiga destruída por Morvim é imediatamente exilada em vez de ir para o cemitério."*
* **Mecânica e Gatilhos:**
  * **Tipo de Gatilho:** `on_attack_resolved`
  * **Zona Permitida para Ativação:** `attacker`
* **Comportamento e Resolução:** Altera a zona física de qualquer defensor derrotado por Morvim para `exiled` (fora do jogo), impedindo qualquer reanimação.

### 🃏 Nargor o Elfo (ID: `1b9ac316-3d6e-4c63-9efe-869395854369` / Efeito: `epic_nargor_deck_hand_seal`)
* **Raridade:** `epic` | **Elemento/Tipo:** `Elfica`
* **Atributos Base:** 💎 Mana: `4` | ⚔️ Poder (ATK): `2000` | ❤️ Vida (HP): `3000`
* **Descrição do Efeito:** *"Efeito passivo operando do DECK. No início de cada rodada do oponente, 1 carta aleatória da mão inimiga é bloqueada de ser jogada. Apenas 1 carta é bloqueada por rodada, independentemente de cópias."*
* **Mecânica e Gatilhos:**
  * **Tipo de Gatilho:** `passive`
  * **Zona Permitida para Ativação:** `deck`
* **Comportamento e Resolução:** Enquanto no deck, a cada novo turno adversário, a engine escolhe um card aleatório da mão inimiga e o marca como inutilizável para a rodada corrente.

### 🃏 Nevuloso (ID: `c35798b1-c2bf-430b-b1b5-05127771d69c` / Efeito: `epic_foglet_duplicate_hand`)
* **Raridade:** `epic` | **Elemento/Tipo:** `Bestiario`
* **Atributos Base:** 💎 Mana: `6` | ⚔️ Poder (ATK): `3000` | ❤️ Vida (HP): `1000`
* **Descrição do Efeito:** *"Ao ativar, abra o modal de seleção para escolher e duplificar exata e integralmente uma carta da sua própria mão."*
* **Mecânica e Gatilhos:**
  * **Tipo de Gatilho:** `manual`
  * **Zona Permitida para Ativação:** `hand`
* **Comportamento e Resolução:** Abre interface de cópia da mão. Clona a carta escolhida, gerando uma réplica idêntica e a inserindo na mão do jogador.

### 🃏 Noldorath o Elfo Navegador (ID: `fb998665-9799-4706-9bbf-3526daba298b` / Efeito: `epic_noldorath_absolute_tutor`)
* **Raridade:** `epic` | **Elemento/Tipo:** `Elfica`
* **Atributos Base:** 💎 Mana: `5` | ⚔️ Poder (ATK): `2500` | ❤️ Vida (HP): `2500`
* **Descrição do Efeito:** *"Abre modal interativo do deck. Você escolhe exatamente a carta que quiser e ela é movida para a sua mão."*
* **Mecânica e Gatilhos:**
  * **Tipo de Gatilho:** `manual`
  * **Zona Permitida para Ativação:** `hand`
* **Comportamento e Resolução:** Abre a listagem completa de cards do deck e permite a escolha de 1 card para ser sacado diretamente para a mão.

### 🃏 Penitente (ID: `d30f22c5-eccd-47ca-bb71-6c98373b3390` / Efeito: `epic_penitent_graveyard_immortality`)
* **Raridade:** `epic` | **Elemento/Tipo:** `Bestiario`
* **Atributos Base:** 💎 Mana: `0` | ⚔️ Poder (ATK): `2500` | ❤️ Vida (HP): `2500`
* **Descrição do Efeito:** *"Passivo automático. Esta carta só pode ser destruída do campo como reforço ou vida se o oponente tiver pelo menos 6 cartas no próprio cemitério. Caso contrário, o dano letal é anulado, a carta permanece em campo e cura-se 100% ao fim da rodada."*
* **Mecânica e Gatilhos:**
  * **Tipo de Gatilho:** `on_destroyed`
  * **Zona Permitida para Ativação:** `field`
* **Comportamento e Resolução:** Intercepta a morte de Penitente. Se o cemitério inimigo tiver `< 6` cartas, cancela o dano letal e recupera totalmente seu HP ao final do turno.

### 🃏 Philippa Eilhart (ID: `fab7cde7-80aa-4517-b237-a057a2d0e729` / Efeito: `epic_philippa_double_mf_mana`)
* **Raridade:** `epic` | **Elemento/Tipo:** `M&F`
* **Atributos Base:** 💎 Mana: `0` | ⚔️ Poder (ATK): `2800` | ❤️ Vida (HP): `3000`
* **Descrição do Efeito:** *"Dobra permanentemente o custo de mana de TODAS as cartas M&F na mão do oponente."*
* **Mecânica e Gatilhos:**
  * **Tipo de Gatilho:** `manual`
  * **Zona Permitida para Ativação:** `hand`
* **Comportamento e Resolução:** Dobra o custo de mana de todas as unidades com `element = 'M&F'` localizadas na mão do oponente.

### 🃏 Principe Alex (ID: `e6a1aabb-dc98-4c6c-b476-4eaccbaea79f` / Efeito: `epic_alex_auto_reinforce`)
* **Raridade:** `epic` | **Elemento/Tipo:** `Civil`
* **Atributos Base:** 💎 Mana: `5` | ⚔️ Poder (ATK): `2900` | ❤️ Vida (HP): `2700`
* **Descrição do Efeito:** *"Só pode ser ativado como Carta de Vida. No início de cada rodada sua, o sistema verifica se há um espaço vago de reforço e adiciona automaticamente 1 carta aleatória revelada como reforço no seu campo."*
* **Mecânica e Gatilhos:**
  * **Tipo de Gatilho:** `passive` / `on_turn_start`
  * **Zona Permitida para Ativação:** `life`
* **Comportamento e Resolução:** Enquanto Alex for vida, a cada novo turno dele, a engine busca 1 card aleatório do deck e o joga revelado na zona `reinforcement`.

### 🃏 Principe Helel (ID: `9d7f3fa2-a609-4765-8230-4ac9ad34cd44` / Efeito: `epic_helel_surgical_eradication`)
* **Raridade:** `epic` | **Elemento/Tipo:** `M&F`
* **Atributos Base:** 💎 Mana: `3` | ⚔️ Poder (ATK): `2800` | ❤️ Vida (HP): `2400`
* **Descrição do Efeito:** *"Ao ativar, abre o modal interativo para ver o deck do oponente. O jogador seleciona 1 carta; o servidor exila (bana) aquela carta E TODAS as cópias idênticas a ela presentes no baralho e no campo inimigo."*
* **Mecânica e Gatilhos:**
  * **Tipo de Gatilho:** `manual`
  * **Zona Permitida para Ativação:** `hand`
* **Comportamento e Resolução:** Permite visualizar o deck do oponente, escolher 1 card, e exilar todas as cópias daquela carta do deck e do campo de batalha adversário.

### 🃏 Protego (ID: `17d0f770-f84e-4a67-ac97-25c9bcf749e7` / Efeito: `epic_protego_life_replacement_once`)
* **Raridade:** `epic` | **Elemento/Tipo:** `Bestiario`
* **Atributos Base:** 💎 Mana: `4` | ⚔️ Poder (ATK): `0` | ❤️ Vida (HP): `4000`
* **Descrição do Efeito:** *"Só ativável no Campo de Vida. Ao ser destruído, substitua-o automaticamente por uma carta aleatória Bestiário do seu cemitério. Limite estrito de 1 ressurreição por jogo para este slot."*
* **Mecânica e Gatilhos:**
  * **Tipo de Gatilho:** `on_destroyed`
  * **Zona Permitida para Ativação:** `life`
* **Comportamento e Resolução:** Ao ser eliminado como vida, saca um card de elemento `Bestiario` do cemitério aliado para ocupar o slot vazio (máximo de 1 ocorrência por partida).

### 🃏 Razen de Tauren (ID: `bfe2a21b-9444-4327-aa8d-2046961a6017` / Efeito: `comp_razen_destroy_anti_direct_attackers`)
* **Raridade:** `epic` | **Elemento/Tipo:** `Witcher`
* **Atributos Base:** 💎 Mana: `2` | ⚔️ Poder (ATK): `2800` | ❤️ Vida (HP): `2700`
* **Descrição do Efeito:** *"Ative e destrua instantaneamente TODAS as cartas em campo cujos feitiços ou passivas impeçam ou bloqueiem ataques diretos à Vida."*
* **Mecânica e Gatilhos:**
  * **Tipo de Gatilho:** `manual`
  * **Zona Permitida para Ativação:** `hand`
* **Comportamento e Resolução:** Localiza e destrói na mesa todas as unidades com efeitos ativos que bloqueiam ataques diretos à vida (ex: Ronnan, Deglan, etc.).

### 🃏 Rei Radovic (ID: `385cc3a6-9015-4210-bfc4-eff4e8bfed00` / Efeito: `epic_radovid_punish_hand_duplicates`)
* **Raridade:** `epic` | **Elemento/Tipo:** `Civil`
* **Atributos Base:** 💎 Mana: `4` | ⚔️ Poder (ATK): `2000` | ❤️ Vida (HP): `2000`
* **Descrição do Efeito:** *"Se o oponente possuir carta duplicada na mão, destrói 1 Carta de Vida do oponente à sua escolha."*
* **Mecânica e Gatilhos:**
  * **Tipo de Gatilho:** `manual`
  * **Zona Permitida para Ativação:** `hand`
* **Comportamento e Resolução:** Analisa os cards na mão inimiga. Se houver duplicatas, destrói uma carta de vida inimiga selecionada.

### 🃏 Rosa de Myrkvid a Lâmia (ID: `d3a8bb06-7ad9-4d32-aa1b-47d46af561e7` / Efeito: `epic_rosa_attack_bounce_buff`)
* **Raridade:** `epic` | **Elemento/Tipo:** `Vampiro`
* **Atributos Base:** 💎 Mana: `0` | ⚔️ Poder (ATK): `2500` | ❤️ Vida (HP): `2500`
* **Descrição do Efeito:** *"Ao ativar durante um ataque, aborta o combate, retorna à mão e recebe +500 Vida/Poder permanente."*
* **Mecânica e Gatilhos:**
  * **Tipo de Gatilho:** `manual`
  * **Zona Permitida para Ativação:** `attacker`
* **Comportamento e Resolução:** Interrompe a colisão de ataque em andamento, recolhe a Lâmia de volta à mão e concede a ela um buff permanente de `+500` ATK/HP.

### 🃏 Salazar o Mago (ID: `5ec3b95d-c2a8-434c-b350-a22b6df7cc01` / Efeito: `epic_salazar_mass_life_hand_swap`)
* **Raridade:** `epic` | **Elemento/Tipo:** `M&F`
* **Atributos Base:** 💎 Mana: `4` | ⚔️ Poder (ATK): `2600` | ❤️ Vida (HP): `2600`
* **Descrição do Efeito:** *"Permuta simultaneamente TODAS as Cartas de Vida em campo por um número idêntico de cartas aleatórias das respectivas mãos de ambos os jogadores."*
* **Mecânica e Gatilhos:**
  * **Tipo de Gatilho:** `manual`
  * **Zona Permitida para Ativação:** `hand`
* **Comportamento e Resolução:** Move todas as cartas de vida ativas no tabuleiro de volta para as mãos de seus respectivos donos, e posiciona cards aleatórios das mãos para ocuparem a fileira de vida.

### 🃏 Saskia (ID: `1e6164d3-f04f-4412-8c4b-e7a4a8de35a0` / Efeito: `epic_saskia_deck_discount_loop`)
* **Raridade:** `epic` | **Elemento/Tipo:** `Bestiario`
* **Atributos Base:** 💎 Mana: `5` | ⚔️ Poder (ATK): `2000` | ❤️ Vida (HP): `2000`
* **Descrição do Efeito:** *"Ative direto da sua mão apenas. Saskia retorna para dentro do seu deck e ativa o feitiço: reduz em -2 o custo de mana de TODAS as cartas do seu deck até ela retornar para sua mão novamente."*
* **Mecânica e Gatilhos:**
  * **Tipo de Gatilho:** `manual`
  * **Zona Permitida para Ativação:** `hand`
* **Comportamento e Resolução:** Saskia é movida da mão para o deck, reduzindo em -2 o custo de mana de todas as cartas restantes do deck até que ela seja sacada novamente pelo jogador.

### 🃏 Scyla da Escola da Coruja (ID: `437fc698-7eb0-41b9-869e-505d5dd0fc22` / Efeito: `epic_scyla_free_witcher_tutor`)
* **Raridade:** `epic` | **Elemento/Tipo:** `Witcher`
* **Atributos Base:** 💎 Mana: `4` | ⚔️ Poder (ATK): `2950` | ❤️ Vida (HP): `3000`
* **Descrição do Efeito:** *"Ative este efeito e compre (saque para a mão) uma carta do tipo Witcher aleatória do seu deck, alterando o custo de mana dela para = 0."*
* **Mecânica e Gatilhos:**
  * **Tipo de Gatilho:** `manual`
  * **Zona Permitida para Ativação:** `hand`
* **Comportamento e Resolução:** Localiza um card do elemento `Witcher` aleatório no deck do jogador, redefine seu custo de mana para `0` e o saca para a mão.

### 🃏 Sibilante a Moira (ID: `b9f50efb-5184-4904-bd12-6004776c2a42` / Efeito: `epic_whispering_moira_direct_snipe`)
* **Raridade:** `epic` | **Elemento/Tipo:** `Bestiario`
* **Atributos Base:** 💎 Mana: `4` | ⚔️ Poder (ATK): `3000` | ❤️ Vida (HP): `3000`
* **Descrição do Efeito:** *"Em combate, ataca diretamente uma Carta de Vida aleatória do oponente, ignorando qualquer reforço."*
* **Mecânica e Gatilhos:**
  * **Tipo de Gatilho:** `manual`
  * **Zona Permitida para Ativação:** `attacker`
* **Comportamento e Resolução:** Quando ataca, ignora as unidades posicionadas na zona `reinforcement` e golpeia uma carta de vida inimiga aleatória.

### 🃏 Stregobor o Mago (ID: `83dbcc78-9a40-474e-9c75-2b86577c3579` / Efeito: `epic_stregobor_tax_enemy_deck`)
* **Raridade:** `epic` | **Elemento/Tipo:** `M&F`
* **Atributos Base:** 💎 Mana: `3` | ⚔️ Poder (ATK): `3300` | ❤️ Vida (HP): `2250`
* **Descrição do Efeito:** *"Ao ativar, uma carta aleatória no deck do seu oponente tem o custo de mana permanentemente alterado para = 8."*
* **Mecânica e Gatilhos:**
  * **Tipo de Gatilho:** `manual`
  * **Zona Permitida para Ativação:** `hand`
* **Comportamento e Resolução:** Escolhe aleatoriamente um card no deck do oponente e altera seu custo de mana de forma fixa e permanente para `8`.

### 🃏 Syanna Henrieta (ID: `b204a92b-9fcd-497e-a4d0-969ca3312b06` / Efeito: `epic_syanna_mimic_random_global_effect`)
* **Raridade:** `epic` | **Elemento/Tipo:** `Civil`
* **Atributos Base:** 💎 Mana: `2` | ⚔️ Poder (ATK): `2800` | ❤️ Vida (HP): `2000`
* **Descrição do Efeito:** *"Passivo na mão. Syanna inspeciona o catálogo, copia e adquire o efeito de qualquer carta aleatória, preservando seu custo de 2 de Mana."*
* **Mecânica e Gatilhos:**
  * **Tipo de Gatilho:** `on_draw`
  * **Zona Permitida para Ativação:** `hand`
* **Comportamento e Resolução:** Ao ser sacada, a engine escolhe um efeito ativo aleatório de qualquer card do jogo e o atribui temporariamente a Syanna.

### 🃏 Tecelã a Moira (ID: `9803887d-ccb9-4a1a-a3a6-9b48cbd9b55c` / Efeito: `epic_weavess_revive_whispering`)
* **Raridade:** `epic` | **Elemento/Tipo:** `Bestiario`
* **Atributos Base:** 💎 Mana: `2` | ⚔️ Poder (ATK): `2700` | ❤️ Vida (HP): `3000`
* **Descrição do Efeito:** *"Ativável direto da mão. Resgata a carta Sibilante a Moira do cemitério direto para a sua mão."*
* **Mecânica e Gatilhos:**
  * **Tipo de Gatilho:** `manual`
  * **Zona Permitida para Ativação:** `hand`
* **Comportamento e Resolução:** Localiza a unidade "Sibilante a Moira" na zona `graveyard` do jogador e a devolve para a zona `hand`.

### 🃏 Teshar de Zangreb da Escola do Urso (ID: `4a85488e-ceb8-4612-a8b6-937e21f529ec` / Efeito: `epic_teshar_beast_damage_resistance`)
* **Raridade:** `epic` | **Elemento/Tipo:** `Witcher`
* **Atributos Base:** 💎 Mana: `0` | ⚔️ Poder (ATK): `2700` | ❤️ Vida (HP): `3500`
* **Descrição do Efeito:** *"Passivo. Recebe apenas 50% de todo dano originado por cartas do elemento Bestiário."*
* **Mecânica e Gatilhos:**
  * **Tipo de Gatilho:** `passive`
  * **Zona Permitida para Ativação:** `field`
* **Comportamento e Resolução:** Quando atacado por uma unidade cujo elemento seja `Bestiario`, reduz o dano sofrido à metade antes de deduzir sua vida.

### 🃏 Ursulla Demetria Crest (ID: `4dcae9cf-3159-4cb4-aea3-64aad67c0c25` / Efeito: `epic_ursulla_dynamic_scaling`)
* **Raridade:** `epic` | **Elemento/Tipo:** `M&F`
* **Atributos Base:** 💎 Mana: `0` | ⚔️ Poder (ATK): `100` | ❤️ Vida (HP): `100`
* **Descrição do Efeito:** *"Passivo automático. Logo ao ser comprada/sacada, a Vida desta carta se torna = 100 * [número de cartas M&F no deck do jogador], e seu Poder se torna = 250 * [número de cartas Bestiário no deck do jogador]."*
* **Mecânica e Gatilhos:**
  * **Tipo de Gatilho:** `on_draw`
  * **Zona Permitida para Ativação:** `hand`
* **Comportamento e Resolução:** Calcula seus atributos no momento do saque: `HP = 100 * [Qtd de M&F no deck]`, `ATK = 250 * [Qtd de Bestiários no deck]`.

### 🃏 Vespeon da Escola da Manticora (ID: `a7689ea4-b436-4575-bbb8-7c35ab394c37` / Efeito: `epic_vespeon_steal_beast_to_deck`)
* **Raridade:** `epic` | **Elemento/Tipo:** `Witcher`
* **Atributos Base:** 💎 Mana: `4` | ⚔️ Poder (ATK): `2800` | ❤️ Vida (HP): `3000`
* **Descrição do Efeito:** *"Ative na sua rodada de ataque: retorna à sua mão e sequestra uma carta aleatória Bestiário do deck do oponente, inserindo-a no seu deck."*
* **Mecânica e Gatilhos:**
  * **Tipo de Gatilho:** `manual`
  * **Zona Permitida para Ativação:** `attacker`
* **Comportamento e Resolução:** Em combate, Vespeon aborta a colisão, retorna à mão do jogador, escolhe uma unidade `Bestiario` do deck inimigo e a enfia no deck do conjurador.

---

## 🃏 CARTAS LENDÁRIAS (LEGENDARY)

### 🃏 Alzur de Maribor (ID: `f6293673-e751-46ce-bd37-51daf57a4caa` / Efeito: `leg_alzur_global_field_bounce_reset`)
* **Raridade:** `legendary` | **Elemento/Tipo:** `M&F`
* **Atributos Base:** 💎 Mana: `2` | ⚔️ Poder (ATK): `4000` | ❤️ Vida (HP): `4000`
* **Descrição do Efeito:** *"Devolve TODOS os reforços e Cartas de Vida de ambos os jogadores às mãos. Abre tela de alocação obrigatória para recolocarem as Cartas de Vida."*
* **Mecânica e Gatilhos:**
  * **Tipo de Gatilho:** `manual`
  * **Zona Permitida para Ativação:** `hand`
* **Comportamento e Resolução:** Esvazia todo o tabuleiro, alterando a zona de todas as unidades aliadas e inimigas para `hand`. A partida retorna ao estado de setup de alocação de vidas.

### 🃏 Arnaghad (ID: `ad411a4a-f9e4-43d1-8177-78285b08fa75` / Efeito: `leg_arnaghad_clone_reinforcements`)
* **Raridade:** `legendary` | **Elemento/Tipo:** `Witcher`
* **Atributos Base:** 💎 Mana: `4` | ⚔️ Poder (ATK): `4000` | ❤️ Vida (HP): `4000`
* **Descrição do Efeito:** *"Ativável no campo de reforço. Transmuta todas as outras cartas de reforço aliadas na sua linha defensiva em cópias exatas e idênticas de Arnaghad."*
* **Mecânica e Gatilhos:**
  * **Tipo de Gatilho:** `manual`
  * **Zona Permitida para Ativação:** `reinforcement`
* **Comportamento e Resolução:** Sobrescreve as propriedades de todas as outras unidades aliadas na fileira `reinforcement` transformando-as em clones de Arnaghad.

### 🃏 Auberon Muircetach (ID: `296f20af-0161-4778-baa6-406b6561ca20` / Efeito: `leg_auberon_double_enemy_elf_mana`)
* **Raridade:** `legendary` | **Elemento/Tipo:** `Elfica`
* **Atributos Base:** 💎 Mana: `4` | ⚔️ Poder (ATK): `4000` | ❤️ Vida (HP): `4000`
* **Descrição do Efeito:** *"Dobra permanentemente o custo de mana de TODAS as cartas do elemento Elfica dentro do deck do oponente."*
* **Mecânica e Gatilhos:**
  * **Tipo de Gatilho:** `manual`
  * **Zona Permitida para Ativação:** `hand`
* **Comportamento e Resolução:** Dobra o custo de mana base de todos os cards com `element = 'Elfica'` que estiverem no deck ou mão do oponente.

### 🃏 Borch Três Gralhas (ID: `45badffd-491b-4773-a575-3e0da786540d` / Efeito: `leg_borch_zero_enemy_hand_stats`)
* **Raridade:** `legendary` | **Elemento/Tipo:** `Bestiario`
* **Atributos Base:** 💎 Mana: `5` | ⚔️ Poder (ATK): `4000` | ❤️ Vida (HP): `7000`
* **Descrição do Efeito:** *"Ao ativar, zera completamente a Vida e o Poder de TODAS as cartas atualmente presentes na mão do oponente."*
* **Mecânica e Gatilhos:**
  * **Tipo de Gatilho:** `manual`
  * **Zona Permitida para Ativação:** `hand`
* **Comportamento e Resolução:** Executa um `UPDATE` de redução a 0 de `current_power`, `current_life` e `maximum_life` para todos os cards localizados na mão adversária.

### 🃏 Carla Demetia Crest (ID: `f9130dbd-9f2a-4130-9044-73248399b0ea` / Efeito: `leg_carla_mill_ten_enemy_beasts`)
* **Raridade:** `legendary` | **Elemento/Tipo:** `M&F`
* **Atributos Base:** 💎 Mana: `2` | ⚔️ Poder (ATK): `3800` | ❤️ Vida (HP): `2800`
* **Descrição do Efeito:** *"Seleciona e destrói exatamente 10 cartas do elemento Bestiario presentes no deck do seu oponente."*
* **Mecânica e Gatilhos:**
  * **Tipo de Gatilho:** `manual`
  * **Zona Permitida para Ativação:** `hand`
* **Comportamento e Resolução:** Remove do deck do oponente até 10 cards cujo elemento seja `Bestiario` e altera suas zonas para `graveyard`.

### 🃏 Caseiro (ID: `91d4a2fd-a0dc-47c7-b8e9-314d9d58988c` / Efeito: `leg_caretaker_endturn_direct_snipe`)
* **Raridade:** `legendary` | **Elemento/Tipo:** `Bestiario`
* **Atributos Base:** 💎 Mana: `5` | ⚔️ Poder (ATK): `1800` | ❤️ Vida (HP): `7000`
* **Descrição do Efeito:** *"Ativável no Campo de Vida. Ao término de cada turno do jogo, esta carta ataca com o seu Poder atual diretamente uma Carta de Vida aleatória do oponente."*
* **Mecânica e Gatilhos:**
  * **Tipo de Gatilho:** `on_turn_end`
  * **Zona Permitida para Ativação:** `life`
* **Comportamento e Resolução:** Enquanto estiver na zona `life`, a cada final de turno, desfere um golpe automático contra uma vida inimiga aleatória equivalente à força do Caseiro.

### 🃏 Ciri (ID: `7400acca-149d-47bd-a948-a2eeb61d5f51` / Efeito: `leg_ciri_direct_snipe_deck_bounce`)
* **Raridade:** `legendary` | **Elemento/Tipo:** `Elfica`
* **Atributos Base:** 💎 Mana: `5` | ⚔️ Poder (ATK): `5000` | ❤️ Vida (HP): `1700`
* **Descrição do Efeito:** *"Ao ativar, desfere um ataque direto contra 1 Carta de Vida do oponente à sua escolha (ignorando reforços). Imediatamente após o dano, Ciri retorna ao seu deck, tendo 50% de chance de ser posicionada compulsoriamente no topo do baralho."*
* **Mecânica e Gatilhos:**
  * **Tipo de Gatilho:** `manual`
  * **Zona Permitida para Ativação:** `attacker`
* **Comportamento e Resolução:** Ataca diretamente a vida selecionada do inimigo. Em seguida, retorna para a zona `deck` do jogador (com `50%` de chance de ficar no topo do deck).

### 🃏 Cosimo Malaspina o Mago (ID: `53a36936-568b-4fae-8a54-0a51ca0ad66e` / Efeito: `leg_cosimo_reduce_enemy_witchers_to_one`)
* **Raridade:** `legendary` | **Elemento/Tipo:** `Civil`
* **Atributos Base:** 💎 Mana: `4` | ⚔️ Poder (ATK): `1000` | ❤️ Vida (HP): `4000`
* **Descrição do Efeito:** *"Reduz e fixa compulsoriamente a Vida de TODAS as cartas do elemento Witcher presentes no campo do oponente em exatamente = 1."*
* **Mecânica e Gatilhos:**
  * **Tipo de Gatilho:** `manual`
  * **Zona Permitida para Ativação:** `hand`
* **Comportamento e Resolução:** Sobrescreve a coluna `current_life` de todas as unidades `Witcher` ativas no campo adversário para exatamente `1`.

### 🃏 Dagon (ID: `cb7a2c9d-405c-42fb-bb6f-c010564acca3` / Efeito: `leg_dagon_reactive_deck_bounce_double`)
* **Raridade:** `legendary` | **Elemento/Tipo:** `Bestiario`
* **Atributos Base:** 💎 Mana: `4` | ⚔️ Poder (ATK): `4000` | ❤️ Vida (HP): `4000`
* **Descrição do Efeito:** *"Reação (Reforço). Se atacado e o oponente já tiver ativado efeito neste turno, Dagon aborta o ataque e retorna ao deck com atributos dobrados."*
* **Mecânica e Gatilhos:**
  * **Tipo de Gatilho:** `reaction`
  * **Zona Permitida para Ativação:** `reinforcement`
* **Comportamento e Resolução:** Se atacado por um jogador que já ativou efeitos de feitiço no turno corrente, Dagon cancela o combate, retorna ao deck e dobra seu ATK e HP máximos.

### 🃏 Dandelion (ID: `44ea442e-cfb3-4cdb-a8b9-66fdc84b1ddd` / Efeito: `leg_dandelion_forced_hand_trade`)
* **Raridade:** `legendary` | **Elemento/Tipo:** `Civil`
* **Atributos Base:** 💎 Mana: `5` | ⚔️ Poder (ATK): `1500` | ❤️ Vida (HP): `3000`
* **Descrição do Efeito:** *"Ganhe visão da mão inimiga. Selecione qualquer número de cartas da sua mão e a mesma quantidade na mão do inimigo para uma permuta forçada e imediata."*
* **Mecânica e Gatilhos:**
  * **Tipo de Gatilho:** `manual`
  * **Zona Permitida para Ativação:** `hand`
* **Comportamento e Resolução:** Exibe a mão do inimigo e permite selecionar `K` cartas de cada lado para trocar fisicamente suas posses na tabela de cartas.

### 🃏 Deatlaff (ID: `fd4bf107-0258-4af2-afed-4630ef20cd18` / Efeito: `leg_dettlaff_multi_direct_strike`)
* **Raridade:** `legendary` | **Elemento/Tipo:** `Vampiro`
* **Atributos Base:** 💎 Mana: `5` | ⚔️ Poder (ATK): `3000` | ❤️ Vida (HP): `2900`
* **Descrição do Efeito:** *"Ao ativar, realiza ataques diretos simultâneos contra Cartas de Vida do oponente (ignorando reforços) igual à quantidade de suas Cartas de Vida vivas em campo."*
* **Mecânica e Gatilhos:**
  * **Tipo de Gatilho:** `manual`
  * **Zona Permitida para Ativação:** `attacker`
* **Comportamento e Resolução:** Conta as cartas de vida ativas do conjurador. Para cada uma delas, desfere um golpe direto de `3000` de dano contra a vida inimiga.

### 🃏 Deglan o Bruxo (ID: `1c32497e-900f-4afd-b1e3-655edecb9e35` / Efeito: `leg_deglan_block_direct_attacks`)
* **Raridade:** `legendary` | **Elemento/Tipo:** `Witcher`
* **Atributos Base:** 💎 Mana: `2` | ⚔️ Poder (ATK): `2800` | ❤️ Vida (HP): `4000`
* **Descrição do Efeito:** *"Só pode ser ativada como Carta de Vida. Enquanto Deglan estiver vivo em seu campo de vida, o oponente fica totalmente bloqueado de ativar feitiços ou ataques diretos ignorando reforços."*
* **Mecânica e Gatilhos:**
  * **Tipo de Gatilho:** `passive`
  * **Zona Permitida para Ativação:** `life`
* **Comportamento e Resolução:** Enquanto posicionado na zona de vida, impede toda declaração e execução de habilidades/ações de ataque direto do oponente.

### 🃏 Dragão Myrgtabrakke (ID: `6bfc824b-168c-4ea4-8469-083439229fc2` / Efeito: `leg_myrgtabrakke_tutor_snipers`)
* **Raridade:** `legendary` | **Elemento/Tipo:** `Bestiario`
* **Atributos Base:** 💎 Mana: `5` | ⚔️ Poder (ATK): `5000` | ❤️ Vida (HP): `5500`
* **Descrição do Efeito:** *"Ao ativar, inspeciona seu deck, seleciona aleatoriamente 2 cartas que possuam ataques diretos à Vida e compra-as."*
* **Mecânica e Gatilhos:**
  * **Tipo de Gatilho:** `manual`
  * **Zona Permitida para Ativação:** `hand`
* **Comportamento e Resolução:** Localiza todos os cards no deck que possuem habilidades de ataque direto, saca 2 deles aleatoriamente para a mão do jogador.

### 🃏 Eredin (ID: `9c6e6709-991f-4655-8de0-c8a1a8f37b6b` / Efeito: `leg_eredin_solo_attack_bleed_tax`)
* **Raridade:** `legendary` | **Elemento/Tipo:** `Elfica`
* **Atributos Base:** 💎 Mana: `4` | ⚔️ Poder (ATK): `6000` | ❤️ Vida (HP): `4500`
* **Descrição do Efeito:** *"Sempre que atacar SOZINHO, reduz -1000 de Vida de TODAS as Cartas de Vida vivas do oponente e aumenta em +1 o custo de mana delas."*
* **Mecânica e Gatilhos:**
  * **Tipo de Gatilho:** `on_attack_resolved`
  * **Zona Permitida para Ativação:** `attacker`
* **Comportamento e Resolução:** Ao atacar sem outros aliados declarados atacantes, remove `1000` de HP de todas as cartas de vida do oponente e incrementa em +1 seus custos de mana.

### 🃏 Erland de Larvik (ID: `01d0484d-29f4-4a15-9d1a-e2ec6efbee90` / Efeito: `leg_erland_slay_mana_ramp`)
* **Raridade:** `legendary` | **Elemento/Tipo:** `Witcher`
* **Atributos Base:** 💎 Mana: `0` | ⚔️ Poder (ATK): `3000` | ❤️ Vida (HP): `3000`
* **Descrição do Efeito:** *"Ao ativar durante um ataque liderado por Erland, ganha para o início do próximo turno +1 de Mana Máxima para cada carta inimiga destruída no ataque."*
* **Mecânica e Gatilhos:**
  * **Tipo de Gatilho:** `on_attack_resolved`
  * **Zona Permitida para Ativação:** `attacker`
* **Comportamento e Resolução:** Se o ataque destruir cartas defensivas/vida inimigas, concede `+1` de mana máxima temporária por carta derrubada para o próximo turno do jogador.

### 🃏 Falken (ID: `31589c5d-023b-4fa7-9368-dcc088fefc3f` / Efeito: `leg_falken_sacrifice_civilians_for_mana`)
* **Raridade:** `legendary` | **Elemento/Tipo:** `Civil`
* **Atributos Base:** 💎 Mana: `2` | ⚔️ Poder (ATK): `4000` | ❤️ Vida (HP): `2700`
* **Descrição do Efeito:** *"Destrói todas as cartas do elemento Civil da sua mão. Ganha permanentemente +1 de Mana Máxima e Mana Atual para cada uma."*
* **Mecânica e Gatilhos:**
  * **Tipo de Gatilho:** `manual`
  * **Zona Permitida para Ativação:** `hand`
* **Comportamento e Resolução:** Localiza todas as cartas de elemento `Civil` na mão, move-as ao cemitério, e incrementa permanentemente em +1 a mana do jogador para cada uma delas.

### 🃏 Filavandrel (ID: `78473a98-dcd9-48cf-8550-df4ba6c30b0e` / Efeito: `leg_filavandrel_elf_hijack_to_deck`)
* **Raridade:** `legendary` | **Elemento/Tipo:** `Elfica`
* **Atributos Base:** 💎 Mana: `3` | ⚔️ Poder (ATK): `2000` | ❤️ Vida (HP): `5000`
* **Descrição do Efeito:** *"Ativável no Campo de Vida. TODAS as cartas do elemento Elfica do oponente destruídas em combate vão compulsoriamente para o seu deck em vez do cemitério dele."*
* **Mecânica e Gatilhos:**
  * **Tipo de Gatilho:** `passive`
  * **Zona Permitida para Ativação:** `life`
* **Comportamento e Resolução:** Enquanto ativo como vida, intercepta a destruição de qualquer card `Elfica` inimigo, transferindo sua zona física diretamente para o deck do jogador.

### 🃏 Francesca Findabair (ID: `5d5bc2ef-052f-4632-9db5-4453720192f9` / Efeito: `leg_francesca_retaliation_ward`)
* **Raridade:** `legendary` | **Elemento/Tipo:** `M&F`
* **Atributos Base:** 💎 Mana: `6` | ⚔️ Poder (ATK): `5000` | ❤️ Vida (HP): `5000`
* **Descrição do Efeito:** *"Ao ativar, protege permanentemente uma Carta de Vida aliada à sua escolha. Quando essa carta protegida for destruída, seu feitiço de vingança destrói TODA a mão do oponente e remove 50% da Vida atual de todas as Cartas de Vida inimigas restantes."*
* **Mecânica e Gatilhos:**
  * **Tipo de Gatilho:** `manual` / `on_destroyed` (do alvo protegido)
  * **Zona Permitida para Ativação:** `hand`
* **Comportamento e Resolução:** Cria uma marca de proteção em um card de vida aliado. Se esse card for destruído, destrói instantaneamente toda a mão inimiga e reduz em `50%` as vidas adversárias restantes.

### 🃏 Gaunter O'Dimm (ID: `7258635f-0be9-47ba-8257-6c4ae95067f0` / Efeito: `leg_gaunter_apocalyptic_board_wipe`)
* **Raridade:** `legendary` | **Elemento/Tipo:** `Bestiario`
* **Atributos Base:** 💎 Mana: `8` | ⚔️ Poder (ATK): `2600` | ❤️ Vida (HP): `6000`
* **Descrição do Efeito:** *"Ao ativar, destrói e purga absolutamente TODO O CAMPO do inimigo (todos os Reforços e todas as Cartas de Vida), deixando compulsoriamente apenas a última (1) Carta de Vida dele viva na mesa."*
* **Mecânica e Gatilhos:**
  * **Tipo de Gatilho:** `manual`
  * **Zona Permitida para Ativação:** `hand`
* **Comportamento e Resolução:** Deleta todas as unidades de reforço e cartas de vida do inimigo, preservando apenas uma única carta de vida ativa em campo.

### 🃏 Ge'els (ID: `595472e6-8b8c-489d-8f63-490f90200b68` / Efeito: `leg_geels_double_surgical_swap`)
* **Raridade:** `legendary` | **Elemento/Tipo:** `Elfica`
* **Atributos Base:** 💎 Mana: `0` | ⚔️ Poder (ATK): `3000` | ❤️ Vida (HP): `4000`
* **Descrição do Efeito:** *"Selecione 1 Carta de Vida aliada para trocar por qualquer carta do seu deck. Em transação simultânea, troque 1 carta da sua mão por outra do deck."*
* **Mecânica e Gatilhos:**
  * **Tipo de Gatilho:** `manual`
  * **Zona Permitida para Ativação:** `hand`
* **Comportamento e Resolução:** Permite escolher uma vida em campo e uma carta da mão para trocarem com dois cards buscados cirurgicamente de dentro do deck.

### 🃏 Geralt de Rivia (ID: `9f37cb0e-09a0-4117-a258-4a49f6d2540a` / Efeito: `leg_geralt_double_scry_draw`)
* **Raridade:** `legendary` | **Elemento/Tipo:** `Witcher`
* **Atributos Base:** 💎 Mana: `0` | ⚔️ Poder (ATK): `5000` | ❤️ Vida (HP): `3000`
* **Descrição do Efeito:** *"Efeito passivo automático operando APENAS do deck. Sempre que você iniciar o turno, em vez da compra comum, o servidor abre um modal de seleção exibindo 2 cartas aleatórias do seu deck para você escolher qual deseja sacar para a mão."*
* **Mecânica e Gatilhos:**
  * **Tipo de Gatilho:** `on_draw`
  * **Zona Permitida para Ativação:** `deck`
* **Comportamento e Resolução:** Se Geralt estiver no deck no início do turno, substitui o draw comum por uma escolha dupla interativa de cards do deck.

### 🃏 Gezras de Leyda (ID: `d5fbb840-689e-4a72-8cef-fccc7dbb4388` / Efeito: `leg_gezras_hijack_enemy_deck_card`)
* **Raridade:** `legendary` | **Elemento/Tipo:** `Witcher`
* **Atributos Base:** 💎 Mana: `0` | ⚔️ Poder (ATK): `2500` | ❤️ Vida (HP): `2500`
* **Descrição do Efeito:** *"Abre modal interativo para inspecionar o deck inimigo. Selecione 1 carta à sua escolha e ela é sequestrada diretamente para a sua mão."*
* **Mecânica e Gatilhos:**
  * **Tipo de Gatilho:** `manual`
  * **Zona Permitida para Ativação:** `hand`
* **Comportamento e Resolução:** Exibe os cards do deck inimigo, permitindo ao jogador selecionar e transferir um deles direto para a sua mão.

### 🃏 Kaen Glahel (ID: `cb283e2d-5646-4035-81a1-fa70b2aa884e` / Efeito: `leg_kaen_glahel_extra_draw_from_deck`)
* **Raridade:** `legendary` | **Elemento/Tipo:** `Elfica`
* **Atributos Base:** 💎 Mana: `0` | ⚔️ Poder (ATK): `2500` | ❤️ Vida (HP): `6000`
* **Descrição do Efeito:** *"Efeito passivo automático operando APENAS do deck. Enquanto esta carta estiver dentro do seu baralho, você compra compulsoriamente uma carta a mais em todo início de rodada."*
* **Mecânica e Gatilhos:**
  * **Tipo de Gatilho:** `on_turn_end` / `on_turn_start`
  * **Zona Permitida para Ativação:** `deck`
* **Comportamento e Resolução:** Enquanto Kaen estiver no deck do jogador, executa um draw adicional de 1 carta a cada início de rodada.

### 🃏 Kagma o Herói de Mahakan (ID: `dd4305b6-5d0f-4b4b-8bd1-bfa84ba67dbf` / Efeito: `leg_kagma_discard_retaliation_snipe`)
* **Raridade:** `legendary` | **Elemento/Tipo:** `Anao`
* **Atributos Base:** 💎 Mana: `0` | ⚔️ Poder (ATK): `6000` | ❤️ Vida (HP): `3000`
* **Descrição do Efeito:** *"Efeito passivo. Se esta carta for descartada da sua mão para o cemitério, destrói instantaneamente 1 Carta de Vida do oponente."*
* **Mecânica e Gatilhos:**
  * **Tipo de Gatilho:** `on_destroyed` (Via descarte da mão)
  * **Zona Permitida para Ativação:** `hand`
* **Comportamento e Resolução:** Quando Kagma sofre gatilho de descarte, executa a eliminação automática de uma das vidas do adversário.

### 🃏 Kitsu (ID: `c23a4d42-7e3c-4afa-a213-e5fbbfaf6827` / Efeito: `leg_kitsu_transmute_half_enemy_deck`)
* **Raridade:** `legendary` | **Elemento/Tipo:** `Elfica`
* **Atributos Base:** 💎 Mana: `0` | ⚔️ Poder (ATK): `2900` | ❤️ Vida (HP): `2500`
* **Descrição do Efeito:** *"Conta as cartas restantes no deck do oponente e transmuta exatamente a metade desse baralho em cartas aleatórias de raridade Rara."*
* **Mecânica e Gatilhos:**
  * **Tipo de Gatilho:** `manual`
  * **Zona Permitida para Ativação:** `hand`
* **Comportamento e Resolução:** Altera as propriedades de 50% das cartas remanescentes no deck adversário para cards aleatórios de `rarity = 'rare'`.

### 🃏 Lara Dorren (ID: `83db427c-3663-4939-a2e1-1c375193c96c` / Efeito: `leg_lara_dorren_rng_multi_strike`)
* **Raridade:** `legendary` | **Elemento/Tipo:** `Elfica`
* **Atributos Base:** 💎 Mana: `6` | ⚔️ Poder (ATK): `2000` | ❤️ Vida (HP): `5000`
* **Descrição do Efeito:** *"Ao ativar, sorteia um número de 1 a 3. Desfere essa quantidade de ataques diretos sucessivos (2000 cada) contra Cartas de Vida inimigas aleatórias."*
* **Mecânica e Gatilhos:**
  * **Tipo de Gatilho:** `manual`
  * **Zona Permitida para Ativação:** `hand` / `attacker`
* **Comportamento e Resolução:** Sorteia um número de ataques `N = trunc(random() * 3) + 1`. Executa `N` golpes diretos de `2000` contra vidas do oponente.

### 🃏 Madoc o Primeiro Bruxo (ID: `d0f26f38-0bf3-4826-aff2-0d6dcd34a8d0` / Efeito: `leg_madoc_mimic_past_witcher_effect`)
* **Raridade:** `legendary` | **Elemento/Tipo:** `Witcher`
* **Atributos Base:** 💎 Mana: `0` | ⚔️ Poder (ATK): `3000` | ❤️ Vida (HP): `2000`
* **Descrição do Efeito:** *"Ao ativar, lista todos os efeitos Witcher já usados na partida e permite que você reexecute 1 deles gratuitamente."*
* **Mecânica e Gatilhos:**
  * **Tipo de Gatilho:** `manual`
  * **Zona Permitida para Ativação:** `hand`
* **Comportamento e Resolução:** Filtra no log os efeitos ativados de cartas Witcher e permite ao jogador escolher um para repetir o seu feitiço.

### 🃏 Princesa Lyra de Dol Blathanna (ID: `67a27fe5-9dbe-40cd-8aba-cc4c610a1399` / Efeito: `comp_lyra_cap_highest_deck_mana`)
* **Raridade:** `legendary` | **Elemento/Tipo:** `Elfica`
* **Atributos Base:** 💎 Mana: `0` | ⚔️ Poder (ATK): `2500` | ❤️ Vida (HP): `2500`
* **Descrição do Efeito:** *"Passivo na mão. Enquanto Lyra estiver na sua mão, a carta com o custo de mana originalmente mais caro dentro do seu deck terá o seu custo fixado em = 5."*
* **Mecânica e Gatilhos:**
  * **Tipo de Gatilho:** `passive`
  * **Zona Permitida para Ativação:** `hand`
* **Comportamento e Resolução:** Enquanto Lyra estiver na mão, localiza o card de maior custo de mana no deck e o força temporariamente para `5`.

### 🃏 Régis (ID: `d4bc15d0-a59a-452d-82ec-23cfbea1ea50` / Efeito: `leg_regis_vampire_mass_tutor_revive`)
* **Raridade:** `legendary` | **Elemento/Tipo:** `Vampiro`
* **Atributos Base:** 💎 Mana: `4` | ⚔️ Poder (ATK): `4300` | ❤️ Vida (HP): `4000`
* **Descrição do Efeito:** *"Reação (Vida ou Reforço). Se sobreviver ao dano, resgata compulsoriamente TODAS as cartas do elemento Vampiro do seu deck e cemitério para a sua mão."*
* **Mecânica e Gatilhos:**
  * **Tipo de Gatilho:** `reaction`
  * **Zona Permitida para Ativação:** `reinforcement` / `life`
* **Comportamento e Resolução:** Se atacado e sobreviver com `current_life > 0`, transfere todos os cards de elemento `Vampiro` localizados no deck e cemitério direto para a mão do jogador.

### 🃏 Senhora do Lago (ID: `a636d90c-3695-4f66-b1a5-ef38d49b91dc` / Efeito: `leg_lady_of_lake_deck_protection`)
* **Raridade:** `legendary` | **Elemento/Tipo:** `Civil`
* **Atributos Base:** 💎 Mana: `0` | ⚔️ Poder (ATK): `2200` | ❤️ Vida (HP): `7000`
* **Descrição do Efeito:** *"Todas as cartas no seu deck tornam-se imunes a serem afetadas, transmutadas, destruídas ou alteradas em custo por qualquer efeito inimigo até o fim da partida."*
* **Mecânica e Gatilhos:**
  * **Tipo de Gatilho:** `manual`
  * **Zona Permitida para Ativação:** `hand`
* **Comportamento e Resolução:** Aplica trava de imunidade permanente ao deck aliado. Impede a destruição, trituração, alteração de custo ou transmutação de cartas no deck por mágicas do oponente.

### 🃏 Shaw Okami o Mago (ID: `6a78cfed-ba62-467a-81ed-5c3e24e4226a` / Efeito: `leg_shaw_okami_clone_five_to_deck`)
* **Raridade:** `legendary` | **Elemento/Tipo:** `M&F`
* **Atributos Base:** 💎 Mana: `2` | ⚔️ Poder (ATK): `2900` | ❤️ Vida (HP): `2900`
* **Descrição do Efeito:** *"Ao ativar, seleciona 1 carta do seu deck e gera compulsoriamente 5 cópias exatas e idênticas dessa carta, misturando-as dentro do seu baralho."*
* **Mecânica e Gatilhos:**
  * **Tipo de Gatilho:** `manual`
  * **Zona Permitida para Ativação:** `hand`
* **Comportamento e Resolução:** Gera 5 novos registros de carta idênticos à carta selecionada e os insere no deck do jogador.

### 🃏 Sheala de Tancarville (ID: `b4543eda-4eee-4123-a995-78327919c0e1` / Efeito: `leg_sheala_discard_expensive_enemy_hand`)
* **Raridade:** `legendary` | **Elemento/Tipo:** `M&F`
* **Atributos Base:** 💎 Mana: `1` | ⚔️ Poder (ATK): `2500` | ❤️ Vida (HP): `2900`
* **Descrição do Efeito:** *"Ao ativar, destrói instantaneamente todas as cartas da mão do oponente cujo Custo de Mana seja maior que o custo desta carta (mana > 1)."*
* **Mecânica e Gatilhos:**
  * **Tipo de Gatilho:** `manual`
  * **Zona Permitida para Ativação:** `hand`
* **Comportamento e Resolução:** Move todas as cartas com custo de mana `> 1` na mão do oponente diretamente para o cemitério adversário.

### 🃏 Sonegado Ancião (ID: `cc06e8f4-8e7a-4c52-91dd-7918a41c588f` / Efeito: `leg_unseen_elder_destroy_unrevealed`)
* **Raridade:** `legendary` | **Elemento/Tipo:** `Vampiro`
* **Atributos Base:** 💎 Mana: `0` | ⚔️ Poder (ATK): `4000` | ❤️ Vida (HP): `4000`
* **Descrição do Efeito:** *"Ao ativar, varre a mesa e destrói instantaneamente todas as cartas NÃO REVELADAS do oponente, sem abrir janela de reação ou permitir ativação de efeitos."*
* **Mecânica e Gatilhos:**
  * **Tipo de Gatilho:** `manual`
  * **Zona Permitida para Ativação:** `hand`
* **Comportamento e Resolução:** Localiza todos os defensores ocultos (`is_face_up = false`) do oponente e os destrói sem permitir reações ou ativação de efeitos de morte.

### 🃏 Tetra Gilcrest (ID: `2d93b01a-0246-42f0-a1bf-8b70b69ed035` / Efeito: `leg_tetra_execute_weaker_lives`)
* **Raridade:** `legendary` | **Elemento/Tipo:** `M&F`
* **Atributos Base:** 💎 Mana: `6` | ⚔️ Poder (ATK): `5000` | ❤️ Vida (HP): `3000`
* **Descrição do Efeito:** *"Destrói compulsoriamente todas as Cartas de Vida vivas na mesa (aliadas ou inimigas) cuja Vida Atual seja inferior à Vida Atual de Tetra no momento da ativação."*
* **Mecânica e Gatilhos:**
  * **Tipo de Gatilho:** `manual`
  * **Zona Permitida para Ativação:** `hand` / `field`
* **Comportamento e Resolução:** Verifica a vida atual de Tetra. Executa a destruição instantânea de todas as cartas de vida em jogo com HP atual inferior a esse limite.

### 🃏 Tissaia (ID: `7d94673c-c6e0-48ac-8c93-783b7e211f25` / Efeito: `leg_tissaia_tutor_discount_yennefers`)
* **Raridade:** `legendary` | **Elemento/Tipo:** `M&F`
* **Atributos Base:** 💎 Mana: `6` | ⚔️ Poder (ATK): `5000` | ❤️ Vida (HP): `3000`
* **Descrição do Efeito:** *"Busca em seu deck todas as cópias da carta Yennefer (LEGENDARY_025), compra-as compulsoriamente e reduz pela metade o custo de mana de cada uma delas."*
* **Mecânica e Gatilhos:**
  * **Tipo de Gatilho:** `manual`
  * **Zona Permitida para Ativação:** `hand`
* **Comportamento e Resolução:** Localiza todos os cards chamados "Yennefer" no deck, saca-os e reduz seus custos de mana em `50%`.

### 🃏 Triss Merigold (ID: `385fcc7c-cd1d-4c1e-8d3c-54ecc7519c85` / Efeito: `leg_triss_double_reinforcement_hp`)
* **Raridade:** `legendary` | **Elemento/Tipo:** `M&F`
* **Atributos Base:** 💎 Mana: `4` | ⚔️ Poder (ATK): `2300` | ❤️ Vida (HP): `6000`
* **Descrição do Efeito:** *"Passivo na mesa. Enquanto Triss estiver viva no campo (vida ou reforço), todas as suas cartas na zona de Reforço têm sua Vida atual e Vida máxima dobradas."*
* **Mecânica e Gatilhos:**
  * **Tipo de Gatilho:** `passive`
  * **Zona Permitida para Ativação:** `field`
* **Comportamento e Resolução:** Enquanto Triss estiver ativa, duplica o HP atual e máximo de todas as unidades aliadas na fileira de defesa (`reinforcement`).

### 🃏 Verdum o Primeiro Monstro (ID: `4b5b3922-1621-4218-bd75-cd5771334532` / Efeito: `leg_verdum_legendary_generator_loop`)
* **Raridade:** `legendary` | **Elemento/Tipo:** `Bestiario`
* **Atributos Base:** 💎 Mana: `2` | ⚔️ Poder (ATK): `1` | ❤️ Vida (HP): `1`
* **Descrição do Efeito:** *"Ative uma única vez. A partir de então, no início de TODA rodada, o sistema gera e adiciona compulsoriamente uma carta Lendária aleatória ao seu deck."*
* **Mecânica e Gatilhos:**
  * **Tipo de Gatilho:** `manual` / `on_turn_start`
  * **Zona Permitida para Ativação:** `hand`
* **Comportamento e Resolução:** Inicia um loop de geração de recursos. A cada início de rodada do jogador, gera um card aleatório de `rarity = 'legendary'` e o insere no deck.

### 🃏 Vesemir (ID: `b95fa893-65a8-48c7-8f6d-bb4a9ae17ebf` / Efeito: `leg_vesemir_hand_buff_loop`)
* **Raridade:** `legendary` | **Elemento/Tipo:** `Witcher`
* **Atributos Base:** 💎 Mana: `0` | ⚔️ Poder (ATK): `2800` | ❤️ Vida (HP): `4000`
* **Descrição do Efeito:** *"Efeito passivo automático operando da mão. Enquanto esta carta estiver na sua mão, no término de cada rodada, todas as outras cartas presentes na sua mão ganham permanentemente +1000 de Poder e +1000 de Vida."*
* **Mecânica e Gatilhos:**
  * **Tipo de Gatilho:** `on_turn_end`
  * **Zona Permitida para Ativação:** `hand`
* **Comportamento e Resolução:** O auto-engine ao final do turno varre a mão do jogador. Se Vesemir estiver nela, adiciona `+1000 ATK/HP` de forma permanente a todas as outras cartas na mão.

### 🃏 Vilgefortz (ID: `1260c248-0b79-4c67-a5a7-bb1271133d52` / Efeito: `leg_vilgefortz_purge_weaker_cards`)
* **Raridade:** `legendary` | **Elemento/Tipo:** `M&F`
* **Atributos Base:** 💎 Mana: `5` | ⚔️ Poder (ATK): `4000` | ❤️ Vida (HP): `4000`
* **Descrição do Efeito:** *"Ao ativar, destrói instantaneamente TODAS as cartas presentes na mão, no cemitério e na linha de reforço do oponente cujo Poder original ou atual seja inferior a 4000."*
* **Mecânica e Gatilhos:**
  * **Tipo de Gatilho:** `manual`
  * **Zona Permitida para Ativação:** `hand`
* **Comportamento e Resolução:** Purgador de massa. Varre a mão, cemitério e linha de defesa do oponente, destruindo e removendo qualquer unidade com força de ataque `< 4000`.

### 🃏 Von Everec (ID: `218729f7-aec7-4404-93af-e267ab99ace0` / Efeito: `leg_von_everec_solo_bounce_discount`)
* **Raridade:** `legendary` | **Elemento/Tipo:** `Bestiario`
* **Atributos Base:** 💎 Mana: `3` | ⚔️ Poder (ATK): `4000` | ❤️ Vida (HP): `3000`
* **Descrição do Efeito:** *"Se atacar SOZINHO, após concluir o ataque retorna intacto para a sua mão e reduz em -1 o custo de mana de TODAS as outras cartas atualmente presentes na sua mão."*
* **Mecânica e Gatilhos:**
  * **Tipo de Gatilho:** `on_attack_resolved`
  * **Zona Permitida para Ativação:** `attacker`
* **Comportamento e Resolução:** Se atacar isoladamente, ao resolver o ataque, retorna para a mão e concede um redutor de `-1` no custo de mana de todas as outras cartas na mão.

### 🃏 Yennefer (ID: `9776b274-1e90-4a8d-bfcf-891c03738e20` / Efeito: `leg_yennefer_execute_enemy_life`)
* **Raridade:** `legendary` | **Elemento/Tipo:** `M&F`
* **Atributos Base:** 💎 Mana: `6` | ⚔️ Poder (ATK): `3300` | ❤️ Vida (HP): `4000`
* **Descrição do Efeito:** *"Ative este efeito e destrua instantaneamente (execute direto para o cemitério) uma Carta de Vida do oponente à sua escolha na mesa."*
* **Mecânica e Gatilhos:**
  * **Tipo de Gatilho:** `manual`
  * **Zona Permitida para Ativação:** `hand`
* **Comportamento e Resolução:** Executador de vida. Permite escolher e destruir sumariamente um card de vida inimigo em campo.
