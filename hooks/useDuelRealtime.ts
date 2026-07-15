"use client"

import { useState, useEffect, useCallback, useRef } from 'react'
import { supabase } from '@/lib/supabase'

interface MatchCard {
  id: string
  match_id: string
  card_id: string
  owner_id: string
  zone: 'hand' | 'life' | 'reinforcement' | 'attacker' | 'graveyard'
  slot_index: number
  is_face_down: boolean
  is_revealed: boolean
  card_data: {
    id: string
    nome: string
    mana: number
    ataque: number
    vida: number
    elemento: string
    tipo: string
    raridade: string
    efeito: string
  }
}

interface MatchState {
  id: string
  current_turn: number
  current_player_id: string
  player1_id: string
  player2_id: string
  player1_life: number
  player2_life: number
  player1_mana: number
  player2_mana: number
  player1_max_mana: number
  player2_max_mana: number
  match_version: number
  status: 'setup' | 'active' | 'completed'
}

type ConnectionStatus = 'connected' | 'syncing' | 'disconnected'

export function useDuelRealtime(matchId: string, currentUserId: string) {
  const [matchState, setMatchState] = useState<MatchState | null>(null)
  const [boardCards, setBoardCards] = useState<MatchCard[]>([])
  const [connectionStatus, setConnectionStatus] = useState<ConnectionStatus>('disconnected')
  const channelRef = useRef<any>(null)

  // Fetch visible match cards from authoritative view
  const fetchBoardCards = useCallback(async () => {
    try {
      const { data, error } = await supabase
        .from('visible_match_cards')
        .select('*')
        .eq('match_id', matchId)

      if (error) throw error
      setBoardCards(data || [])
    } catch (error) {
      console.error('Erro ao buscar cartas do tabuleiro:', error)
    }
  }, [matchId])

  // Fetch match public state
  const fetchMatchState = useCallback(async () => {
    try {
      const { data, error } = await supabase
        .from('match_public_states')
        .select('*')
        .eq('match_id', matchId)
        .single()

      if (error) throw error
      setMatchState(data)
    } catch (error) {
      console.error('Erro ao buscar estado da partida:', error)
    }
  }, [matchId])

  // RPC: Play card to board
  const playCard = useCallback(async (cardId: string, zone: string, slotIndex: number, isFaceDown: boolean = false) => {
    try {
      const { data, error } = await supabase.rpc('play_match_card', {
        p_match_id: matchId,
        p_card_id: cardId,
        p_zone: zone,
        p_slot_index: slotIndex,
        p_is_face_down: isFaceDown
      })

      if (error) throw error
      return data
    } catch (error) {
      console.error('Erro ao jogar carta:', error)
      throw error
    }
  }, [matchId])

  // RPC: Declare attack
  const attackTarget = useCallback(async (attackerCardId: string, targetCardId: string) => {
    try {
      const { data, error } = await supabase.rpc('declare_attack', {
        p_match_id: matchId,
        p_attacker_card_id: attackerCardId,
        p_target_card_id: targetCardId
      })

      if (error) throw error
      return data
    } catch (error) {
      console.error('Erro ao declarar ataque:', error)
      throw error
    }
  }, [matchId])

  // RPC: Pass turn
  const endTurn = useCallback(async (expectedVersion: number) => {
    try {
      const { data, error } = await supabase.rpc('pass_turn', {
        p_match_id: matchId,
        p_expected_version: expectedVersion
      })

      if (error) throw error
      return data
    } catch (error) {
      console.error('Erro ao passar turno:', error)
      throw error
    }
  }, [matchId])

  // Setup realtime subscriptions
  useEffect(() => {
    setConnectionStatus('syncing')

    // Initial fetch
    Promise.all([fetchMatchState(), fetchBoardCards()])
      .then(() => setConnectionStatus('connected'))
      .catch(() => setConnectionStatus('disconnected'))

    // Create realtime channel
    const channel = supabase.channel(`match_room_${matchId}`)
    channelRef.current = channel

    // Subscribe to match state changes
    channel
      .on('postgres_changes', {
        event: '*',
        schema: 'public',
        table: 'match_public_states',
        filter: `match_id=eq.${matchId}`
      }, (payload) => {
        console.log('Estado da partida alterado:', payload)
        fetchMatchState()
      })
      .on('postgres_changes', {
        event: '*',
        schema: 'public',
        table: 'match_actions',
        filter: `match_id=eq.${matchId}`
      }, (payload) => {
        console.log('Ação de partida registrada:', payload)
        fetchBoardCards()
        fetchMatchState()
      })
      .subscribe((status) => {
        if (status === 'SUBSCRIBED') {
          setConnectionStatus('connected')
        } else if (status === 'CLOSED' || status === 'CHANNEL_ERROR') {
          setConnectionStatus('disconnected')
        }
      })

    return () => {
      if (channelRef.current) {
        supabase.removeChannel(channelRef.current)
      }
    }
  }, [matchId, fetchMatchState, fetchBoardCards])

  // Filter cards by zone for UI rendering
  const getCardsByZone = useCallback((zone: string, ownerId?: string) => {
    return boardCards.filter(card => 
      card.zone === zone && (!ownerId || card.owner_id === ownerId)
    )
  }, [boardCards])

  // Get current player's perspective
  const isCurrentPlayer = matchState?.current_player_id === currentUserId
  const isPlayer1 = matchState?.player1_id === currentUserId
  const opponentId = isPlayer1 ? matchState?.player2_id : matchState?.player1_id

  return {
    matchState,
    boardCards,
    connectionStatus,
    isCurrentPlayer,
    isPlayer1,
    opponentId,
    getCardsByZone,
    playCard,
    attackTarget,
    endTurn,
    refresh: () => {
      fetchMatchState()
      fetchBoardCards()
    }
  }
}
