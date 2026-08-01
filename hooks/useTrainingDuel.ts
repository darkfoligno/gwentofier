import React, { useState, useEffect, useCallback, useMemo, useRef } from 'react';
import { supabase } from "@/lib/supabase"
import type {
  BanCandidate,
  MatchAction,
  MatchPublicStateRow,
  MatchRow,
  MatchState,
  PendingAttack,
  PendingCardTrigger,
  VisibleMatchCard,
} from "@/lib/types"

export const sleep = (ms: number) => new Promise<void>(resolve => window.setTimeout(resolve, ms))

const BOT_UUID = "ffffffff-ffff-ffff-ffff-ffffffffffff"

function shuffle<T>(array: T[]): T[] {
  let currentIndex = array.length, randomIndex;
  while (currentIndex !== 0) {
    randomIndex = Math.floor(Math.random() * currentIndex);
    currentIndex--;
    [array[currentIndex], array[randomIndex]] = [
      array[randomIndex], array[currentIndex]];
  }
  return array;
}

export function useTrainingDuel(matchId: string, currentUserId: string) {
  const [matchState, setMatchState] = useState<MatchState | null>(null)
  const [boardCards, setBoardCards] = useState<VisibleMatchCard[]>([])
  const [matchActions, setMatchActions] = useState<MatchAction[]>([])
  const [pendingAttack, setPendingAttack] = useState<PendingAttack | null>(null)
  const [usedEffectCardIds, setUsedEffectCardIds] = useState<Set<string>>(new Set())
  const [isActionPending, setIsActionPending] = useState(false)
  const [rawDbCards, setRawDbCards] = useState<any[]>([])

  const opponentId = BOT_UUID
  const isPlayer1 = true
  const isCurrentPlayer = matchState?.current_player_id === currentUserId
  const isTraining = true
  const connectionStatus = "connected" as const
  const validMatch = true

  // Geração de Decks (Fisher-Yates) com card_data completo
  useEffect(() => {
    let active = true
    const loadRealCards = async () => {
      try {
        const { data: dbCards, error } = await supabase
          .from("cards")
          .select("*, card_effects(*)")
          .eq("is_active", true)

        if (error) throw error
        if (!active || !dbCards || dbCards.length === 0) return
        setRawDbCards(dbCards)

        const legendaryCards = dbCards.filter(c => c.rarity === "legendary")
        const normalCards = dbCards.filter(c => c.rarity !== "legendary" && c.card_type === "normal")

        const p1DeckRaw = [
          ...[...legendaryCards].sort(() => 0.5 - Math.random()).slice(0, 5),
          ...[...normalCards].sort(() => 0.5 - Math.random()).slice(0, 35)
        ]
        const p1Deck = shuffle(p1DeckRaw)

        const botDeckRaw = [
          ...[...legendaryCards].sort(() => 0.5 - Math.random()).slice(0, 5),
          ...[...normalCards].sort(() => 0.5 - Math.random()).slice(0, 35)
        ]
        const botDeck = shuffle(botDeckRaw)

        const generatedCards: VisibleMatchCard[] = []

        // Jogador Humano
        p1Deck.forEach((card, i) => {
          const cardId = `p1-card-${i}`
          generatedCards.push({
            id: cardId,
            match_id: matchId,
            controller_user_id: currentUserId,
            owner_user_id: currentUserId,
            zone: i < 7 ? "hand" : "deck",
            zone_position: i + 1,
            current_power: card.base_power ?? 10,
            current_life: card.base_max_life ?? 15,
            maximum_life: card.base_max_life ?? 15,
            rarity: card.rarity,
            card_name: card.name,
            image_url: card.image_url ?? "",
            effect_text: card.effect_text ?? "",
            entered_zone_turn: 0,
            has_attacked_this_turn: false,
            is_face_up: true,
            card_id: cardId,
            owner_id: currentUserId,
            slot_index: i + 1,
            active_modifiers: [],
            card_data: {
              id: cardId,
              nome: card.name,
              image_url: card.image_url,
              mana: card.effect_mana_cost ?? 1,
              ataque: card.base_power ?? 10,
              vida: card.base_max_life ?? 15,
              elemento: card.element ?? "Cívil",
              tipo: card.card_type ?? "normal",
              raridade: card.rarity,
              efeito: card.effect_text ?? "",
              effect_definition: card.card_effects ?? []
            }
          })
        })

        // Bot
        botDeck.forEach((card, i) => {
          const cardId = `bot-card-${i}`
          generatedCards.push({
            id: cardId,
            match_id: matchId,
            controller_user_id: BOT_UUID,
            owner_user_id: BOT_UUID,
            zone: i < 7 ? "hand" : "deck",
            zone_position: i + 1,
            current_power: card.base_power ?? 10,
            current_life: card.base_max_life ?? 15,
            maximum_life: card.base_max_life ?? 15,
            rarity: card.rarity,
            card_name: card.name,
            image_url: card.image_url ?? "",
            effect_text: card.effect_text ?? "",
            entered_zone_turn: 0,
            has_attacked_this_turn: false,
            is_face_up: false,
            card_id: cardId,
            owner_id: BOT_UUID,
            slot_index: i + 1,
            active_modifiers: [],
            card_data: {
              id: cardId,
              nome: card.name,
              image_url: card.image_url,
              mana: card.effect_mana_cost ?? 1,
              ataque: card.base_power ?? 10,
              vida: card.base_max_life ?? 15,
              elemento: card.element ?? "Cívil",
              tipo: card.card_type ?? "normal",
              raridade: card.rarity,
              efeito: card.effect_text ?? "",
              effect_definition: card.card_effects ?? []
            }
          })
        })

        setBoardCards(generatedCards)
        setMatchState({
          id: matchId,
          status: "ban_phase",
          match_type: "training",
          active_player_id: currentUserId,
          winner_id: null,
          current_turn: 0,
          state_version: 1,
          finish_reason: null,
          turn_deadline: new Date(Date.now() + 180000).toISOString(),
          initiative_result: null,
          engine_state: "turn_action",
          current_player_id: currentUserId,
          player1_id: currentUserId,
          player2_id: BOT_UUID,
          player1_mana: 3,
          player2_mana: 3,
          player1_max_mana: 3,
          player2_max_mana: 3,
          match_version: 1,
          my_actions_this_turn: 0,
          my_paid_effect_used: false,
          my_free_effect_used: false,
          player1_username: "Você",
          player2_username: "Bot de Treino",
          player1_hand_count: 7,
          player2_hand_count: 7,
          player1_mana_available: 3,
          player2_mana_available: 3
        })
      } catch (e) {
        console.error("Falha ao inicializar o deck:", e)
      }
    }
    void loadRealCards()
    return () => { active = false }
  }, [matchId, currentUserId])

  // PASSO 2: Tela de Banimento - candidatos com card_data completo
  const getBanCandidates = useCallback(async () => {
    const botDeckCards = boardCards.filter(c => c.owner_id === BOT_UUID)
    const rarityWeight: Record<string, number> = { legendary: 4, epic: 3, rare: 2, common: 1 }
    const sorted = [...botDeckCards].sort((a, b) => {
      const wA = rarityWeight[a.rarity ?? "common"] ?? 0
      const wB = rarityWeight[b.rarity ?? "common"] ?? 0
      return wB - wA
    })
    return sorted.slice(0, 20).map(c => ({
      source_card_id: c.id,
      card_id: c.id,
      name: c.card_name ?? "",
      image_url: c.image_url ?? "",
      rarity: c.rarity ?? "common",
      raridade: c.rarity ?? "common",
      copy_count: 1,
      base_power: c.current_power,
      base_max_life: c.maximum_life,
      effect_text: c.effect_text,
      effect_mana_cost: c.card_data?.mana ?? 1,
      categories: [c.rarity ?? "rare"]
    }))
  }, [boardCards])

  const submitBan = useCallback(async (cardId: string | null, category: string) => {
    setIsActionPending(true)
    await sleep(400)
    setBoardCards(prev => prev.filter(c => c.id !== cardId))
    setBoardCards(prev => {
      const playerDeck = prev.filter(c => c.owner_id === currentUserId && c.zone === "deck")
      if (playerDeck.length > 0) {
        const randCard = playerDeck[Math.floor(Math.random() * playerDeck.length)]
        return prev.filter(c => c.id !== randCard.id)
      }
      return prev
    })
    setMatchState(prev => prev ? {
      ...prev,
      status: "setup",
      state_version: prev.state_version + 1,
      match_version: prev.match_version + 1
    } : null)
    setIsActionPending(false)
    return { success: true, ban_phase_complete: true }
  }, [currentUserId])

  // PASSO 3: Setup (Turno 0) e Setup do Bot
  const submitSetup = useCallback(async (lifeCardIds: string[], reinforcementCardIds: string[] = []) => {
    setIsActionPending(true)
    await sleep(500)
    setBoardCards(prev => prev.map(c => {
      if (c.owner_id === currentUserId) {
        if (lifeCardIds.includes(c.id)) {
          const idx = lifeCardIds.indexOf(c.id) + 1
          return { ...c, zone: "life", zone_position: idx, slot_index: idx }
        }
        if (reinforcementCardIds.includes(c.id)) {
          const idx = reinforcementCardIds.indexOf(c.id) + 1
          return { ...c, zone: "reinforcement", zone_position: idx, slot_index: idx, is_face_up: false }
        }
      }
      return c
    }))
    setBoardCards(prev => {
      const botHand = prev.filter(c => c.owner_id === BOT_UUID && c.zone === "hand")
      const sortedBot = [...botHand].sort((a, b) => (b.maximum_life ?? 0) - (a.maximum_life ?? 0))
      const botLifes = sortedBot.slice(0, 3).map(c => c.id)
      const botReinf = sortedBot.slice(3, 4).map(c => c.id)
      return prev.map(c => {
        if (c.owner_id === BOT_UUID) {
          if (botLifes.includes(c.id)) {
            const idx = botLifes.indexOf(c.id) + 1
            return { ...c, zone: "life", zone_position: idx, slot_index: idx, is_face_up: true }
          }
          if (botReinf.includes(c.id)) {
            return { ...c, zone: "reinforcement", zone_position: 1, slot_index: 1, is_face_up: false }
          }
        }
        return c
      })
    })
    const coinFlipWinner = Math.random() < 0.5 ? currentUserId : BOT_UUID
    setMatchState(prev => prev ? {
      ...prev,
      status: "in_progress",
      engine_state: "turn_action",
      current_player_id: coinFlipWinner,
      state_version: prev.state_version + 1,
      match_version: prev.match_version + 1
    } : null)
    setIsActionPending(false)
    return { success: true }
  }, [currentUserId])

  const playCard = useCallback(async (cardId: string, zone: "attacker" | "reinforcement", slotIndex: number) => {
    setIsActionPending(true)
    await sleep(200)
    setBoardCards(prev => prev.map(c => c.id === cardId ? { ...c, zone, zone_position: slotIndex, slot_index: slotIndex } : c))
    setMatchState(prev => prev ? { ...prev, state_version: prev.state_version + 1, match_version: prev.match_version + 1 } : null)
    setIsActionPending(false)
    return { success: true }
  }, [])

  const recallMatchCard = useCallback(async (cardId: string) => {
    setIsActionPending(true)
    await sleep(200)
    setBoardCards(prev => prev.map(c => c.id === cardId ? { ...c, zone: "hand", zone_position: 1 } : c))
    setMatchState(prev => prev ? { ...prev, state_version: prev.state_version + 1, match_version: prev.match_version + 1 } : null)
    setIsActionPending(false)
    return { success: true }
  }, [])

  // Defesa do Bot durante a colisão de ataque do jogador
  const handleBotDefenseReaction = async (attackerPower: number) => {
    const currentMana = matchState?.player2_mana ?? 0
    const botHand = boardCards.filter(c => c.owner_id === BOT_UUID && c.zone === "hand")
    const reactable = botHand.filter(c => (c.card_data?.mana ?? 0) <= currentMana)
    if (reactable.length > 0 && Math.random() < 0.7) {
      const chosenReact = reactable[Math.floor(Math.random() * reactable.length)]
      setMatchState(prev => prev ? { ...prev, player2_mana: prev.player2_mana - (chosenReact.card_data?.mana ?? 0) } : null)
      setMatchActions(prev => [
        ...prev,
        {
          id: Date.now(),
          match_id: matchId,
          sequence_number: prev.length + 1,
          actor_user_id: BOT_UUID,
          action_type: "effect_activated",
          payload_public: { source_card_id: chosenReact.id, card_name: chosenReact.card_name, mana_spent: chosenReact.card_data?.mana ?? 0 },
          state_version_before: 0,
          state_version_after: 0,
          created_at: new Date().toISOString()
        } as MatchAction
      ])
      await sleep(800)
    }
  }

  // Resolução de ataque rígida similar ao PvP (os atacantes permanecem em campo e defesas são danificadas)
  const declareAttack = useCallback(async (attackerCardIds: string[], isDirect: boolean) => {
    setIsActionPending(true)
    await sleep(400)
    const attackPower = boardCards
      .filter(c => attackerCardIds.includes(c.id))
      .reduce((sum, c) => sum + (c.current_power ?? 0), 0)

    // Bot reage localmente
    await handleBotDefenseReaction(attackPower)

    // Aplica o dano nas defesas
    setBoardCards(prev => {
      const botDefenses = prev.filter(c => c.owner_id === BOT_UUID && ["reinforcement", "life"].includes(c.zone) && (c.current_life ?? 0) > 0)
      if (botDefenses.length > 0) {
        const target = botDefenses[0]
        return prev.map(c => {
          if (c.id === target.id) {
            const nextHp = Math.max(0, (c.current_life ?? 0) - attackPower)
            return { ...c, current_life: nextHp, zone: nextHp <= 0 ? "graveyard" : c.zone, zone_position: nextHp <= 0 ? null : c.zone_position }
          }
          return c
        })
      }
      return prev
    })

    // Marca as cartas do jogador que atacaram
    setBoardCards(prev => prev.map(c => attackerCardIds.includes(c.id) ? { ...c, has_attacked_this_turn: true } : c))

    // Passagem de turno automática após ataque resolvido
    setMatchState(prev => {
      if (!prev) return null
      // Saca 1 carta para o Bot
      let newHandCount = prev.player2_hand_count
      setBoardCards(cards => {
        const botDeck = cards.filter(c => c.owner_id === BOT_UUID && c.zone === "deck")
        if (botDeck.length > 0) {
          const drawn = botDeck[0]
          newHandCount += 1
          return cards.map(c => c.id === drawn.id ? { ...c, zone: "hand" } : c)
        }
        return cards
      })

      return {
        ...prev,
        current_player_id: BOT_UUID,
        player2_mana: Math.min(prev.player2_max_mana + 1, 10),
        player2_max_mana: Math.min(prev.player2_max_mana + 1, 10),
        player2_hand_count: newHandCount,
        state_version: prev.state_version + 1,
        match_version: prev.match_version + 1
      }
    })

    // Reseta flags de ataque das cartas do Bot
    setBoardCards(prev => prev.map(c => c.owner_id === BOT_UUID ? { ...c, has_attacked_this_turn: false } : c))

    setIsActionPending(false)
    return { success: true }
  }, [boardCards, matchState])

  // Passar Turno (sacar 1 carta e alternar active_player_id)
  const endTurn = useCallback(async () => {
    setIsActionPending(true)
    await sleep(200)

    setMatchState(prev => {
      if (!prev) return null
      const nextPlayer = prev.current_player_id === currentUserId ? BOT_UUID : currentUserId
      
      // Saca 1 carta do deck do novo jogador ativo
      setBoardCards(cards => {
        const deck = cards.filter(c => c.owner_id === nextPlayer && c.zone === "deck")
        if (deck.length > 0) {
          const drawn = deck[0]
          return cards.map(c => c.id === drawn.id ? { ...c, zone: "hand" } : c)
        }
        return cards
      })

      const isBot = nextPlayer === BOT_UUID
      return {
        ...prev,
        current_player_id: nextPlayer,
        player1_mana: isBot ? prev.player1_mana : Math.min(prev.player1_max_mana + 1, 10),
        player1_max_mana: isBot ? prev.player1_max_mana : Math.min(prev.player1_max_mana + 1, 10),
        player2_mana: isBot ? Math.min(prev.player2_max_mana + 1, 10) : prev.player2_mana,
        player2_max_mana: isBot ? Math.min(prev.player2_max_mana + 1, 10) : prev.player2_max_mana,
        state_version: prev.state_version + 1,
        match_version: prev.match_version + 1
      }
    })

    // Reseta flags de ataque do novo jogador ativo
    const nextPlayer = matchState?.current_player_id === currentUserId ? BOT_UUID : currentUserId
    setBoardCards(prev => prev.map(c => c.owner_id === nextPlayer ? { ...c, has_attacked_this_turn: false } : c))

    setIsActionPending(false)
    return { success: true }
  }, [currentUserId, matchState])

  // IA do Bot local
  const runTrainingBotTurn = useCallback(async () => {
    setIsActionPending(true)
    await sleep(1500)

    // Move de 1 a 3 cartas da mão do Bot para a zona attacker
    let botHandIds: string[] = []
    setBoardCards(prev => {
      const botHand = prev.filter(c => c.owner_id === BOT_UUID && c.zone === "hand")
      if (botHand.length === 0) return prev
      const countToPlay = Math.min(botHand.length, Math.floor(Math.random() * 3) + 1)
      const chosenToPlay = botHand.slice(0, countToPlay)
      botHandIds = chosenToPlay.map(c => c.id)

      return prev.map(c => {
        if (botHandIds.includes(c.id)) {
          return { ...c, zone: "attacker", zone_position: 1, slot_index: 1 }
        }
        return c
      })
    })

    await sleep(1000)

    // Executa ataque com as cartas
    let attackPower = 0
    setBoardCards(prev => {
      const readyAttackers = prev.filter(c => botHandIds.includes(c.id) || (c.owner_id === BOT_UUID && c.zone === "attacker" && (c.current_life ?? 0) > 0))
      attackPower = readyAttackers.reduce((sum, c) => sum + (c.current_power ?? 0), 0)
      return prev
    })

    const botField = boardCards.filter(c => c.owner_id === BOT_UUID && c.zone === "attacker" && (c.current_life ?? 0) > 0)
    const currentMana = matchState?.player2_mana ?? 0
    const withManaEffect = botField.filter(c => (c.card_data?.mana ?? 0) <= currentMana)
    if (withManaEffect.length > 0 && Math.random() < 0.6) {
      const effectCard = withManaEffect[0]
      setMatchState(prev => prev ? { ...prev, player2_mana: Math.max(0, prev.player2_mana - (effectCard.card_data?.mana ?? 0)) } : null)
      setMatchActions(prev => [
        ...prev,
        {
          id: Date.now(),
          match_id: matchId,
          sequence_number: prev.length + 1,
          actor_user_id: BOT_UUID,
          action_type: "effect_activated",
          payload_public: { source_card_id: effectCard.id, card_name: effectCard.card_name, mana_spent: effectCard.card_data?.mana ?? 0 },
          state_version_before: 0,
          state_version_after: 0,
          created_at: new Date().toISOString()
        } as MatchAction
      ])
      await sleep(1000)
    }

    if (attackPower > 0) {
      setBoardCards(prev => {
        const playerDefenses = prev.filter(c => c.owner_id === currentUserId && ["reinforcement", "life"].includes(c.zone) && (c.current_life ?? 0) > 0)
        if (playerDefenses.length > 0) {
          const target = playerDefenses[0]
          return prev.map(c => {
            if (c.id === target.id) {
              const nextHp = Math.max(0, (c.current_life ?? 0) - attackPower)
              return { ...c, current_life: nextHp, zone: nextHp <= 0 ? "graveyard" : c.zone, zone_position: nextHp <= 0 ? null : c.zone_position }
            }
            return c
          })
        }
        return prev
      })
    }

    await sleep(1000)

    // Passa o turno para o Humano e saca 1 carta
    setMatchState(prev => {
      if (!prev) return null
      setBoardCards(cards => {
        const deck = cards.filter(c => c.owner_id === currentUserId && c.zone === "deck")
        if (deck.length > 0) {
          const drawn = deck[0]
          return cards.map(c => c.id === drawn.id ? { ...c, zone: "hand" } : c)
        }
        return cards
      })

      return {
        ...prev,
        current_player_id: currentUserId,
        player1_mana: Math.min(prev.player1_max_mana + 1, 10),
        player1_max_mana: Math.min(prev.player1_max_mana + 1, 10),
        current_turn: prev.current_turn + 1,
        state_version: prev.state_version + 1,
        match_version: prev.match_version + 1
      }
    })

    // Reseta flags de ataque das cartas do Humano
    setBoardCards(prev => prev.map(c => c.owner_id === currentUserId ? { ...c, has_attacked_this_turn: false } : c))

    setIsActionPending(false)
  }, [boardCards, matchState, matchId, currentUserId])

  // Ação silenciosa do Bot no Hook que monitora a vez do Bot
  useEffect(() => {
    if (!matchState || matchState.status !== "in_progress" || matchState.engine_state !== "turn_action") return
    if (matchState.current_player_id !== BOT_UUID) return
    if (isActionPending) return
    let active = true
    const triggerBot = async () => {
      await sleep(1500)
      if (!active) return
      await runTrainingBotTurn()
    }
    void triggerBot()
    return () => { active = false }
  }, [matchState?.current_player_id, matchState?.engine_state, matchState?.status, isActionPending, runTrainingBotTurn])

  const getCardsByZone = useCallback((zone: VisibleMatchCard["zone"], ownerId?: string) => {
    return boardCards.filter(card => card.zone === zone && (!ownerId || card.owner_id === ownerId))
  }, [boardCards])

  const refresh = useCallback(async () => {}, [])

  return {
    matchState,
    boardCards,
    matchActions,
    pendingAttack,
    pendingEffectChoice: null,
    pendingCardTrigger: null,
    effectExecutionLogs: [],
    connectionStatus,
    isTraining,
    usedEffectCardIds,
    isActionPending,
    isCurrentPlayer,
    isPlayer1,
    opponentId,
    hasActedThisTurn: false,
    reactionUsed: false,
    getCardsByZone,
    refresh,
    getBanCandidates,
    submitBan,
    submitSetup,
    playCard,
    replaceEarlyLifeCard: async () => ({ success: true }),
    declareAttack,
    endTurn,
    passWithoutAction: endTurn,
    surrenderMatch: async () => ({ success: true }),
    activateMatchEffect: async () => ({ success: true }),
    declineAttackReaction: async () => ({ success: true }),
    submitEffectChoice: async () => {},
    resolvePendingCardTrigger: async () => ({ success: true }),
    declinePendingCardTrigger: async () => ({ success: true }),
    recallMatchCard,
    resolveTrainingBotTrigger: async () => {},
    runTrainingBotTurn,
    expireTurn: async () => {},
    autoResolveTrainingAttack: async () => {},
    finalizePendingAttack: async () => {},
    rescueTrainingBotTurn: async () => {}
  }
}
