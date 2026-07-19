"use client"

import { useCallback, useEffect, useMemo, useRef, useState } from "react"
import type { PostgrestError } from "@supabase/supabase-js"
import { supabase } from "@/lib/supabase"
import type {
  BanCandidate,
  MatchAction,
  MatchPublicStateRow,
  MatchRow,
  MatchState,
  PendingAttack,
  VisibleMatchCard,
  VisibleMatchCardRow,
} from "@/lib/types"

type ConnectionStatus = "connected" | "syncing" | "disconnected"
const NIL_UUID = "00000000-0000-0000-0000-000000000000"
const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i

function requiredUuid(value: unknown, field: string) {
  if (typeof value !== "string" || !UUID.test(value) || value === NIL_UUID) throw new Error(`PAYLOAD_UUID_INVALID: ${field}`)
  return value
}
function requiredVersion(value: unknown) {
  const parsed = typeof value === "number" ? value : Number(value)
  if (!Number.isSafeInteger(parsed) || parsed < 0) throw new Error("PAYLOAD_VERSION_INVALID: p_expected_version")
  return parsed
}

function isStaleVersion(error: PostgrestError | Error | null) {
  return Boolean(error && (error.message.includes("STALE_MATCH_VERSION") || ("details" in error && error.details?.includes("STALE_MATCH_VERSION"))))
}
function readableRpcError(error: PostgrestError) {
  const raw=[error.message,error.details,error.hint].filter(Boolean).join(" ")
  const translations:Record<string,string>={DRAW_BLOCKED_BY_COMMON_000:"Compra bloqueada pelo efeito passivo de Filho da Puta Junior!",INSUFFICIENT_MANA:"Mana insuficiente para ativar este efeito.",EFFECT_ALREADY_USED_THIS_TURN:"Este efeito já foi utilizado neste turno.",NOT_YOUR_TURN:"Aguarde o seu turno para realizar esta ação.",STALE_MATCH_VERSION:"O duelo avançou em outro dispositivo. Sincronizando novamente…"}
  const key=Object.keys(translations).find(code=>raw.includes(code))
  const message=key?translations[key]:error.code==="P0001"?`O servidor recusou a ação: ${error.message}`:error.message
  return Object.assign(new Error(message),{code:error.code,details:error.details,hint:error.hint,original:error})
}

async function reportDuelError(matchId: string, operation: string, error: PostgrestError | Error) {
  const issue = error as PostgrestError
  await supabase.rpc("report_client_error", { p_area: "arena", p_operation: operation, p_error_code: issue.code ?? null, p_error_message: error.message, p_error_details: issue.details ?? null, p_match_id: UUID.test(matchId) ? matchId : null, p_client_context: { online: typeof navigator !== "undefined" ? navigator.onLine : null } })
}

export function useDuelRealtime(matchId: string, currentUserId: string) {
  const [matchState, setMatchState] = useState<MatchState | null>(null)
  const [boardCards, setBoardCards] = useState<VisibleMatchCard[]>([])
  const [matchActions, setMatchActions] = useState<MatchAction[]>([])
  const [pendingAttack, setPendingAttack] = useState<PendingAttack | null>(null)
  const [pendingEffectChoice, setPendingEffectChoice] = useState<{ id: string; effect_code: string; choice_type: string; min_choices: number; max_choices: number; candidate_ids: string[]; public_prompt: string; expected_state_version: number } | null>(null)
  const [connectionStatus, setConnectionStatus] = useState<ConnectionStatus>("disconnected")
  const [isTraining, setIsTraining] = useState(false)
  const [usedEffectCardIds,setUsedEffectCardIds]=useState<Set<string>>(new Set())
  const [isActionPending,setIsActionPending]=useState(false)
  const actionPending = useRef(false)
  const mounted = useRef(true)
  const validMatch = UUID.test(matchId) && matchId !== NIL_UUID

  const fetchMatchState = useCallback(async () => {
    if (!validMatch) return
    const [matchResult, publicResult, trainingResult,usageResult] = await Promise.all([
      supabase.from("matches").select("id,status,active_player_id,winner_id,current_turn,state_version,finish_reason,turn_deadline,initiative_result,engine_state").eq("id", matchId).single(),
      supabase.from("match_public_states").select("*").eq("match_id", matchId).single(),
      supabase.from("training_matches").select("match_id").eq("match_id", matchId).maybeSingle(),
      supabase.rpc("get_my_turn_usage",{p_match_id:matchId}),
    ])
    if (matchResult.error) throw matchResult.error
    if (publicResult.error) throw publicResult.error
    if (trainingResult.error) throw trainingResult.error
    if (usageResult.error && !["42883","PGRST202"].includes(usageResult.error.code??"")) throw usageResult.error
    if (mounted.current) setIsTraining(Boolean(trainingResult.data))
    const match = matchResult.data as MatchRow
    const state = publicResult.data as MatchPublicStateRow
    const usage=Array.isArray(usageResult.data)?usageResult.data[0]:usageResult.data
    if (mounted.current) setMatchState({
      ...match, ...state,
      current_player_id: match.active_player_id,
      player1_id: state.player1_user_id ?? "",
      player2_id: state.player2_user_id ?? "",
      player1_mana: state.player1_mana_available,
      player2_mana: state.player2_mana_available,
      player1_max_mana: state.player1_hand_count,
      player2_max_mana: state.player2_hand_count,
      match_version: match.state_version,
      my_actions_this_turn:usage?.actions_this_turn??0,
      my_paid_effect_used:usage?.paid_effect_used??false,
      my_free_effect_used:usage?.free_effect_used??false,
    })
  }, [matchId, validMatch])

  const fetchBoardCards = useCallback(async () => {
    if (!validMatch) return
    const [{ data, error }, effectsResult, modifiersResult,detailsResult] = await Promise.all([
      supabase.from("visible_match_cards").select("*").eq("match_id", matchId).order("zone_position", { nullsFirst: false }),
      supabase.from("visible_match_card_effects").select("match_card_id,element,effect_mana_cost,effect_text,effect_definition").eq("match_id", matchId),
      supabase.from("visible_match_card_modifiers").select("id,match_card_id,modifier_type,power_delta,max_life_delta,current_life_delta,multiplier,is_permanent,metadata").eq("match_id",matchId),
      supabase.from("visible_match_card_details").select("match_card_id,base_power,base_max_life,effect_mana_cost,element,card_type,is_original_rpg,is_collab").eq("match_id",matchId),
    ])
    if (error) throw error
    if (effectsResult.error) throw effectsResult.error
    if (modifiersResult.error && !["42P01","PGRST205"].includes(modifiersResult.error.code ?? "")) throw modifiersResult.error
    if (detailsResult.error && !["42P01","PGRST205"].includes(detailsResult.error.code ?? "")) throw detailsResult.error
    const effects = new Map((effectsResult.data ?? []).map((item: any) => [item.match_card_id, item]))
    const modifiers = new Map<string, any[]>()
    const details=new Map((detailsResult.data??[]).map((item:any)=>[item.match_card_id,item]))
    for (const item of modifiersResult.data ?? []) modifiers.set(item.match_card_id, [...(modifiers.get(item.match_card_id) ?? []), item])
    const rows = (data ?? []) as VisibleMatchCardRow[]
    if (mounted.current) setBoardCards(rows.map(row => ({
      ...row,...(details.get(row.id)??{}),
      card_id: row.id,
      owner_id: row.controller_user_id,
      slot_index: row.zone_position ?? 0,
      active_modifiers: modifiers.get(row.id) ?? [],
      card_data: row.card_name == null ? null : {
        id: row.id,
        nome: row.card_name,
        image_url: row.image_url ?? undefined,
        mana: details.get(row.id)?.effect_mana_cost ?? effects.get(row.id)?.effect_mana_cost ?? 0,
        ataque: row.current_power ?? 0,
        vida: row.current_life ?? 0,
        elemento: (details.get(row.id)?.element ?? effects.get(row.id)?.element ?? "Cívil") as "Bestiário" | "M&F" | "Witcher" | "Elfica" | "Cívil" | "Vampiro",
        tipo: details.get(row.id)?.card_type ?? "normal",
        raridade: (["common", "rare", "epic", "legendary", "collab"].includes(row.rarity ?? "") ? row.rarity : "common") as "common" | "rare" | "epic" | "legendary" | "collab",
        efeito: effects.get(row.id)?.effect_text ?? row.effect_text ?? "",
        effect_definition: effects.get(row.id)?.effect_definition ?? [],
      },
    })))
  }, [matchId, validMatch])

  const fetchActions = useCallback(async () => {
    if (!validMatch) return
    const feed = await supabase.from("match_action_feed").select("action_id,match_id,sequence_number,actor_user_id,action_type,payload_public,state_version_before,state_version_after,created_at").eq("match_id", matchId).order("sequence_number", { ascending: true }).limit(100)
    if (!feed.error) { if (mounted.current) setMatchActions((feed.data ?? []).map(row => ({ ...row, id: row.action_id })) as MatchAction[]); return }
    if (!["42P01","PGRST205"].includes(feed.error.code ?? "")) throw feed.error
    const fallback = await supabase.from("visible_match_actions").select("*").eq("match_id",matchId).order("sequence_number",{ascending:true}).limit(100)
    if(fallback.error)throw fallback.error
    if(mounted.current)setMatchActions((fallback.data??[]) as MatchAction[])
  }, [matchId, validMatch])

  const fetchPendingAttack = useCallback(async () => {
    if (!validMatch || !currentUserId) return
    const { data, error } = await supabase.from("pending_attacks").select("*").eq("match_id", matchId).in("status", ["awaiting_reaction","reaction_used","reaction_declined","resolving"]).order("created_at", { ascending: false }).limit(1).maybeSingle()
    if (error) throw error
    if (mounted.current) setPendingAttack(data as PendingAttack | null)
  }, [currentUserId, matchId, validMatch])
  const fetchPendingEffectChoice = useCallback(async () => { if (!validMatch) return; const { data, error } = await supabase.rpc("get_my_pending_effect_choice", { p_match_id: matchId }); if (error) throw error; const row = Array.isArray(data) ? data[0] : data; if (mounted.current) setPendingEffectChoice(row ?? null) }, [matchId, validMatch])
  const fetchEffectUses=useCallback(async()=>{if(!validMatch||!matchState)return;const {data,error}=await supabase.from("match_effect_uses").select("match_card_id").eq("match_id",matchId).eq("turn_number",matchState.current_turn);if(error)throw error;if(mounted.current)setUsedEffectCardIds(new Set((data??[]).map(row=>row.match_card_id)))},[matchId,matchState?.current_turn,validMatch])

  const refresh = useCallback(async () => {
    if (!validMatch) return
    setConnectionStatus("syncing")
    try {
      await Promise.all([fetchMatchState(), fetchBoardCards(), fetchActions(), fetchPendingAttack(), fetchPendingEffectChoice(),fetchEffectUses()])
      if (mounted.current) setConnectionStatus("connected")
    } catch (error) {
      console.error("Falha ao sincronizar a partida autoritativa", error)
      void reportDuelError(matchId, "realtime_refresh", error as PostgrestError | Error)
      if (mounted.current) setConnectionStatus("disconnected")
    }
  }, [fetchActions, fetchBoardCards, fetchMatchState, fetchPendingAttack, fetchPendingEffectChoice,fetchEffectUses, matchId, validMatch])

  const rpc = useCallback(async <T,>(name: string, args: Record<string, unknown>) => {
    if (actionPending.current) throw new Error("ACTION_IN_PROGRESS: aguarde a confirmação do servidor.")
    actionPending.current = true
    if (mounted.current) setIsActionPending(true)
    try {
    const clean = Object.fromEntries(Object.entries(args).filter(([,value]) => value !== undefined && value !== ""))
    if ("p_match_id" in clean) clean.p_match_id = requiredUuid(clean.p_match_id, "p_match_id")
    if ("p_expected_version" in clean) clean.p_expected_version = requiredVersion(clean.p_expected_version)
    for (const key of ["p_source_card_id","p_match_card_id","p_target_card_id","p_pending_attack_id","p_choice_id"])
      if (key in clean && clean[key] !== null) clean[key] = requiredUuid(clean[key], key)
    console.error(`[Duel RPC] ${name}`, { payload: clean, matchVersion: matchState?.match_version, at: new Date().toISOString() })
    const { data, error } = await supabase.rpc(name, clean)
    if (error) {
      if (isStaleVersion(error)) await refresh()
      void reportDuelError(matchId, name, error)
      throw readableRpcError(error)
    }
    return data as T
    } finally {
      actionPending.current = false
      if (mounted.current) setIsActionPending(false)
    }
  }, [matchId, refresh])

  const versioned = useCallback((extra: Record<string, unknown> = {}) => ({
    p_match_id: requiredUuid(matchId,"p_match_id"),
    p_expected_version: requiredVersion(matchState?.match_version ?? 0),
    ...extra,
  }), [matchId, matchState?.match_version])

  useEffect(() => {
    mounted.current = true
    if (!validMatch) return
    void refresh()
    const channel = supabase.channel(`match:${matchId}`)
      .on("postgres_changes", { event: "*", schema: "public", table: "matches", filter: `id=eq.${matchId}` }, payload => {
        const next = payload.new as MatchRow
        setMatchState(previous => previous ? { ...previous, ...next, current_player_id: next.active_player_id, match_version: next.state_version } : previous)
        void Promise.all([fetchMatchState(), fetchBoardCards(), fetchActions()])
      })
      .on("postgres_changes", { event: "*", schema: "public", table: "match_public_states", filter: `match_id=eq.${matchId}` }, payload => {
        const next = payload.new as MatchPublicStateRow
        setMatchState(previous => previous ? { ...previous, ...next, player1_mana: next.player1_mana_available, player2_mana: next.player2_mana_available } : previous)
        void Promise.all([fetchMatchState(), fetchBoardCards(), fetchActions()])
      })
      .on("postgres_changes", { event: "*", schema: "public", table: "pending_attacks", filter: `match_id=eq.${matchId}` }, payload => {
        const next = payload.new as PendingAttack
        setPendingAttack(["awaiting_reaction","reaction_used","reaction_declined","resolving"].includes(next.status) ? next : null)
        void Promise.all([fetchPendingAttack(), fetchMatchState(), fetchBoardCards(), fetchActions()])
      })
      .on("postgres_changes", { event: "*", schema: "public", table: "pending_effect_choices", filter: `match_id=eq.${matchId}` }, () => { void fetchPendingEffectChoice(); void fetchBoardCards() })
      .subscribe(status => setConnectionStatus(status === "SUBSCRIBED" ? "connected" : status === "CHANNEL_ERROR" || status === "CLOSED" ? "disconnected" : "syncing"))
    const actionChannel=supabase.channel(`match-actions:${matchId}`)
      .on("postgres_changes", { event: "INSERT", schema: "public", table: "match_action_feed", filter: `match_id=eq.${matchId}` }, payload => {
        const row = payload.new as Omit<MatchAction,"id"> & { action_id: number }
        setMatchActions(previous => previous.some(item => item.id === row.action_id) ? previous : [...previous,{ ...row,id:row.action_id }].slice(-100))
        void Promise.all([fetchMatchState(),fetchBoardCards()])
      })
      .subscribe()
    return () => {
      mounted.current = false
      void supabase.removeChannel(channel)
      void supabase.removeChannel(actionChannel)
    }
  }, [fetchActions, fetchBoardCards, fetchMatchState, fetchPendingAttack, fetchPendingEffectChoice, matchId, refresh, validMatch])

  const isPlayer1 = matchState?.player1_id === currentUserId
  const opponentId = isPlayer1 ? matchState?.player2_id : matchState?.player1_id
  const isCurrentPlayer = matchState?.current_player_id === currentUserId
  const getCardsByZone = useCallback((zone: VisibleMatchCard["zone"], ownerId?: string) => boardCards.filter(card => card.zone === zone && (!ownerId || card.owner_id === ownerId)), [boardCards])
  const hasActedThisTurn = useMemo(() => matchActions.some(action => action.actor_user_id === currentUserId && action.state_version_after === matchState?.match_version), [currentUserId, matchActions, matchState?.match_version])
  const reactionUsed = pendingAttack?.status === "reaction_used"

  return {
    matchState, boardCards, matchActions, pendingAttack, pendingEffectChoice, connectionStatus, isTraining,usedEffectCardIds,isActionPending,
    isCurrentPlayer, isPlayer1, opponentId, hasActedThisTurn, reactionUsed, getCardsByZone, refresh,
    getBanCandidates: () => rpc<BanCandidate[]>("get_match_ban_candidates", { p_match_id: matchId }),
    submitBan: (cardId: string) => rpc("submit_match_ban", versioned({ p_source_card_id: cardId, p_ban_category: "highest_rarity" })),
    submitSetup: (lifeCardIds: string[], reinforcementCardIds: string[] = []) => isTraining ? rpc("submit_training_setup", versioned({ p_life_card_ids: lifeCardIds, p_reinforcement_card_ids: reinforcementCardIds })) : rpc("submit_match_setup", versioned({ p_life_card_ids: lifeCardIds, p_reinforcement_card_ids: reinforcementCardIds, p_leader_card_id: null })),
    playCard: (cardId: string, zone: "attacker" | "reinforcement", slotIndex: number) => rpc("play_match_card", versioned({ p_match_card_id: cardId, p_destination_zone: zone, p_destination_position: slotIndex })),
    replaceEarlyLifeCard: (cardId: string, slotIndex: number) => rpc("replace_early_life_card", versioned({ p_match_card_id: cardId, p_life_position: slotIndex })),
    declareAttack: (attackerCardIds: string[], isDirect: boolean) => rpc("declare_attack", versioned({ p_attacker_card_ids: attackerCardIds, p_is_direct: isDirect })),
    endTurn: () => rpc("end_turn", versioned()),
    passWithoutAction: () => rpc("pass_without_action", versioned()),
    surrenderMatch: () => rpc("surrender_match", versioned()),
    activateMatchEffect: (cardId: string, effectOrder = 1, targetCardId?: string) => rpc("activate_card_effect_v2", versioned({ p_source_card_id: cardId, p_effect_order: effectOrder, p_target_card_id: targetCardId ?? null })),
    declineAttackReaction: async () => {
      const declined = await rpc<{ state_version: number }>("decline_attack_reaction", { p_pending_attack_id: pendingAttack?.id, p_expected_version: matchState?.match_version ?? 0 })
      return rpc("finalize_pending_attack_turn", { p_pending_attack_id: pendingAttack?.id, p_expected_version: declined.state_version })
    },
    submitEffectChoice: (choiceId: string, selectedIds: string[]) => rpc("submit_effect_choice", { p_choice_id: choiceId, p_selected_ids: selectedIds, p_expected_version: matchState?.match_version ?? 0 }),
    runTrainingBotTurn: () => rpc("run_training_bot_turn", versioned()),
    expireTurn: () => rpc("expire_match_turn", versioned()),
    autoResolveTrainingAttack: (expectedVersion: number) => rpc("auto_resolve_training_attack", { p_match_id: matchId, p_expected_version: expectedVersion }),
    finalizePendingAttack: (attackId: string, expectedVersion: number) => rpc("finalize_pending_attack_turn", { p_pending_attack_id: attackId, p_expected_version: expectedVersion }),
    rescueTrainingBotTurn: () => rpc("rescue_training_bot_turn", versioned()),
  }
}
