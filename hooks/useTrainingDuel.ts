"use client"
// HOOK DO MODO TREINO PVE - SIMULADOR LOCAL DO DUELO

import { useCallback, useEffect, useMemo, useRef, useState } from "react"
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

export function useTrainingDuel(matchId: string, currentUserId: string) {
  // Estado local que simula a partida para evitar colisões e Erros 400
  const [localMatchState, setLocalMatchState] = useState<MatchState | null>(null)
  const [localCards, setLocalCards] = useState<VisibleMatchCard[]>([])
  const [localActions, setLocalActions] = useState<MatchAction[]>([])
  const [localPendingAttack, setLocalPendingAttack] = useState<PendingAttack | null>(null)
  const [localUsedEffectCardIds, setLocalUsedEffectCardIds] = useState<Set<string>>(new Set())
  const [isActionPending, setIsActionPending] = useState(false)

  const botUserId = "00000000-0000-4000-8000-000000000071"
  const isPlayer1 = true
  const opponentId = botUserId
  const isCurrentPlayer = localMatchState?.current_player_id === currentUserId

  // Inicialização local e carga de cartas do catálogo do jogador
  useEffect(() => {
    let active = true
    const init = async () => {
      try {
        // Carrega um deck base do usuário para simular a partida local
        const { data: deckCards } = await supabase
          .from("profiles")
          .select("id")
          .eq("id", currentUserId)
          .maybeSingle()

        if (!active) return

        // Massa de teste inicial: 10 cartas para o jogador e 10 para o Bot
        const testNames = ["Anão Guerreiro", "Elfo Caçador", "Fada da Floresta", "Nekker Brutal", "Geralt de Rivia", "Yennefer", "Ciri", "Dandelion", "Triss", "Zoltan"]
        const generatedCards: VisibleMatchCard[] = []

        // Gerar cartas do Jogador
        for (let i = 0; i < 10; i++) {
          const cardId = `p1-card-${i}`
          generatedCards.push({
            id: cardId,
            match_id: matchId,
            controller_user_id: currentUserId,
            owner_user_id: currentUserId,
            zone: i < 7 ? "hand" : "deck",
            zone_position: i + 1,
            current_power: 10 + i * 5,
            current_life: 20 + i * 5,
            maximum_life: 20 + i * 5,
            rarity: i > 7 ? "legendary" : i > 5 ? "epic" : "common",
            card_name: testNames[i],
            image_url: "",
            effect_text: "Efeito Simulado Localmente.",
            entered_zone_turn: 0,
            has_attacked_this_turn: false,
            is_face_up: true,
            card_id: cardId,
            owner_id: currentUserId,
            slot_index: i + 1,
            active_modifiers: [],
            card_data: {
              id: cardId,
              nome: testNames[i],
              mana: 1 + (i % 3),
              ataque: 10 + i * 5,
              vida: 20 + i * 5,
              elemento: "Cívil",
              tipo: "normal",
              raridade: i > 7 ? "legendary" : i > 5 ? "epic" : "common",
              efeito: "Efeito Simulado Localmente.",
              effect_definition: []
            }
          })
        }

        // Gerar cartas do Bot
        for (let i = 0; i < 10; i++) {
          const cardId = `bot-card-${i}`
          generatedCards.push({
            id: cardId,
            match_id: matchId,
            controller_user_id: botUserId,
            owner_user_id: botUserId,
            zone: i < 7 ? "hand" : "deck",
            zone_position: i + 1,
            current_power: 12 + i * 4,
            current_life: 18 + i * 6,
            maximum_life: 18 + i * 6,
            rarity: i > 7 ? "legendary" : i > 5 ? "epic" : "common",
            card_name: `Bot ${testNames[i]}`,
            image_url: "",
            effect_text: "Efeito Inimigo Simulado.",
            entered_zone_turn: 0,
            has_attacked_this_turn: false,
            is_face_up: false,
            card_id: cardId,
            owner_id: botUserId,
            slot_index: i + 1,
            active_modifiers: [],
            card_data: {
              id: cardId,
              nome: `Bot ${testNames[i]}`,
              mana: 1 + (i % 3),
              ataque: 12 + i * 4,
              vida: 18 + i * 6,
              elemento: "Cívil",
              tipo: "normal",
              raridade: i > 7 ? "legendary" : i > 5 ? "epic" : "common",
              efeito: "Efeito Inimigo Simulado.",
              effect_definition: []
            }
          })
        }

        setLocalCards(generatedCards)
        setLocalMatchState({
          id: matchId,
          status: "ban_phase",
          match_type: "training",
          active_player_id: currentUserId,
          winner_id: null,
          current_turn: 0,
          state_version: 1,
          finish_reason: null,
          turn_deadline: new Date(Date.now() + 60000).toISOString(),
          initiative_result: null,
          engine_state: "lifecycle",
          current_player_id: currentUserId,
          player1_id: currentUserId,
          player2_id: botUserId,
          player1_mana: 3,
          player2_mana: 3,
          player1_max_mana: 3,
          player2_max_mana: 3,
          match_version: 1,
          my_actions_this_turn: 0,
          my_paid_effect_used: false,
          my_free_effect_used: false,
          player1_username: "Você",
          player2_username: "Bot Autômato",
          player1_hand_count: 7,
          player2_hand_count: 7,
          player1_mana_available: 3,
          player2_mana_available: 3
        })
      } catch (e) {
        console.error("Erro na carga inicial do simulador:", e)
      }
    }
    void init()
    return () => { active = false }
  }, [matchId, currentUserId])

  // Retorna os candidatos a banimento locais (cartas do deck do Bot)
  const getBanCandidates = useCallback(async () => {
    return localCards
      .filter(c => c.owner_id === botUserId)
      .map(c => ({
        source_card_id: c.id,
        card_id: c.id,
        name: c.card_name ?? "",
        image_url: c.image_url ?? "",
        rarity: c.rarity ?? "common",
        raridade: c.rarity ?? "common",
        copy_count: 1
      }))
  }, [localCards])

  // Submissão do banimento local (Remove a carta do deck do Bot)
  const submitBan = useCallback(async (cardId: string | null, category: string) => {
    setIsActionPending(true)
    await sleep(400)
    setLocalCards(prev => prev.filter(c => c.id !== cardId))
    setLocalMatchState(prev => prev ? { ...prev, status: "setup", state_version: prev.state_version + 1, match_version: prev.match_version + 1 } : null)
    setIsActionPending(false)
    return { success: true }
  }, [])

  // Submissão do Tabuleiro Humano e Autopreenchimento do Bot
  const submitSetup = useCallback(async (lifeCardIds: string[], reinforcementCardIds: string[] = []) => {
    setIsActionPending(true)
    await sleep(500)

    setLocalCards(prev => {
      return prev.map(c => {
        // Aloca jogador humano
        if (c.owner_id === currentUserId) {
          if (lifeCardIds.includes(c.id)) {
            const idx = lifeCardIds.indexOf(c.id) + 1
            return { ...c, zone: "life", zone_position: idx, slot_index: idx }
          }
          if (reinforcementCardIds.includes(c.id)) {
            const idx = reinforcementCardIds.indexOf(c.id) + 1
            return { ...c, zone: "reinforcement", zone_position: idx, slot_index: idx }
          }
        }
        return c
      })
    })

    // Turno 0 Bot local: Pega as 3 cartas com mais HP da mão do Bot e coloca na zona life
    setLocalCards(prev => {
      const botHand = prev.filter(c => c.owner_id === botUserId && c.zone === "hand")
      const sortedBot = [...botHand].sort((a, b) => (b.maximum_life ?? 0) - (a.maximum_life ?? 0))
      const targetBotLifeIds = sortedBot.slice(0, 3).map(c => c.id)

      return prev.map(c => {
        if (c.owner_id === botUserId && targetBotLifeIds.includes(c.id)) {
          const idx = targetBotLifeIds.indexOf(c.id) + 1
          return { ...c, zone: "life", zone_position: idx, slot_index: idx, is_face_up: true }
        }
        return c
      })
    })

    setLocalMatchState(prev => prev ? {
      ...prev,
      status: "in_progress",
      engine_state: "turn_action",
      current_player_id: currentUserId,
      state_version: prev.state_version + 1,
      match_version: prev.match_version + 1
    } : null)

    setIsActionPending(false)
    return { success: true }
  }, [currentUserId])

  // Jogar carta da mão para o campo
  const playCard = useCallback(async (cardId: string, zone: "attacker" | "reinforcement", slotIndex: number) => {
    setIsActionPending(true)
    await sleep(200)
    setLocalCards(prev => prev.map(c => c.id === cardId ? { ...c, zone, zone_position: slotIndex, slot_index: slotIndex } : c))
    setLocalMatchState(prev => prev ? { ...prev, state_version: prev.state_version + 1 } : null)
    setIsActionPending(false)
    return { success: true }
  }, [])

  // Recuar carta para a mão
  const recallMatchCard = useCallback(async (cardId: string) => {
    setIsActionPending(true)
    await sleep(200)
    setLocalCards(prev => prev.map(c => c.id === cardId ? { ...c, zone: "hand", zone_position: 1 } : c))
    setLocalMatchState(prev => prev ? { ...prev, state_version: prev.state_version + 1 } : null)
    setIsActionPending(false)
    return { success: true }
  }, [])

  // Declarar ataque contra o Bot
  const declareAttack = useCallback(async (attackerCardIds: string[], isDirect: boolean) => {
    setIsActionPending(true)
    await sleep(500)

    const attackPower = localCards
      .filter(c => attackerCardIds.includes(c.id))
      .reduce((sum, c) => sum + (c.current_power ?? 0), 0)

    // Defesas do bot
    const botDefenses = localCards.filter(c => c.owner_id === botUserId && ["reinforcement", "life"].includes(c.zone) && (c.current_life ?? 0) > 0)
    
    if (botDefenses.length > 0) {
      // Aplica dano à primeira carta de defesa do bot
      const target = botDefenses[0]
      setLocalCards(prev => prev.map(c => {
        if (c.id === target.id) {
          const newLife = Math.max(0, (c.current_life ?? 0) - attackPower)
          return { ...c, current_life: newLife, zone: newLife <= 0 ? "graveyard" : c.zone }
        }
        return c
      }))
    }

    setLocalMatchState(prev => prev ? {
      ...prev,
      current_player_id: botUserId,
      state_version: prev.state_version + 1
    } : null)

    setIsActionPending(false)
    return { success: true }
  }, [localCards])

  // Finalizar o turno do jogador e transferir o controle
  const endTurn = useCallback(async () => {
    setIsActionPending(true)
    await sleep(300)
    setLocalMatchState(prev => prev ? {
      ...prev,
      current_player_id: botUserId,
      state_version: prev.state_version + 1
    } : null)
    setIsActionPending(false)
    return { success: true }
  }, [])

  // Execução do turno do Bot local PVE
  const runTrainingBotTurn = useCallback(async () => {
    if (isActionPending) return
    setIsActionPending(true)
    await sleep(1500)

    // IA do bot: joga 1 reforço se vazio, joga 1 atacante se possível, ataca, passa turno
    setLocalCards(prev => {
      const botHand = prev.filter(c => c.owner_id === botUserId && c.zone === "hand")
      const botReinforcement = prev.filter(c => c.owner_id === botUserId && c.zone === "reinforcement")
      const botAttackers = prev.filter(c => c.owner_id === botUserId && c.zone === "attacker")

      let updated = [...prev]

      // 1. Coloca 1 reforço se estiver vazio
      if (botReinforcement.length === 0 && botHand.length > 0) {
        const cardToPlay = botHand[0]
        updated = updated.map(c => c.id === cardToPlay.id ? { ...c, zone: "reinforcement", zone_position: 1, slot_index: 1 } : c)
      }

      // 2. Coloca 1 atacante se possível
      const currentBotHand = updated.filter(c => c.owner_id === botUserId && c.zone === "hand")
      if (botAttackers.length === 0 && currentBotHand.length > 0) {
        const cardToPlay = currentBotHand[0]
        updated = updated.map(c => c.id === cardToPlay.id ? { ...c, zone: "attacker", zone_position: 1, slot_index: 1 } : c)
      }

      return updated
    })

    // Executa ataque simples contra o HP do jogador
    setLocalCards(prev => {
      const botAttackers = prev.filter(c => c.owner_id === botUserId && c.zone === "attacker" && (c.current_life ?? 0) > 0)
      const playerDefenses = prev.filter(c => c.owner_id === currentUserId && ["reinforcement", "life"].includes(c.zone) && (c.current_life ?? 0) > 0)
      
      if (botAttackers.length > 0 && playerDefenses.length > 0) {
        const power = botAttackers.reduce((s, c) => s + (c.current_power ?? 0), 0)
        const target = playerDefenses[0]
        return prev.map(c => {
          if (c.id === target.id) {
            const nextHp = Math.max(0, (c.current_life ?? 0) - power)
            return { ...c, current_life: nextHp, zone: nextHp <= 0 ? "graveyard" : c.zone }
          }
          return c
        })
      }
      return prev
    })

    // Retorna a vez para o jogador
    setLocalMatchState(prev => prev ? {
      ...prev,
      current_player_id: currentUserId,
      current_turn: prev.current_turn + 1,
      state_version: prev.state_version + 1
    } : null)

    setIsActionPending(false)
  }, [isActionPending, currentUserId, localCards])

  const getCardsByZone = useCallback((zone: VisibleMatchCard["zone"], ownerId?: string) => {
    return localCards.filter(card => card.zone === zone && (!ownerId || card.owner_id === ownerId))
  }, [localCards])

  const refresh = useCallback(async () => {}, [])

  return {
    matchState: localMatchState,
    boardCards: localCards,
    matchActions: localActions,
    pendingAttack: localPendingAttack,
    pendingEffectChoice: null,
    pendingCardTrigger: null,
    effectExecutionLogs: [],
    connectionStatus: "connected" as const,
    isTraining: true,
    usedEffectCardIds: localUsedEffectCardIds,
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
    passWithoutAction: async () => ({ success: true }),
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
