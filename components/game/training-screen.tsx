"use client"
// MODO TREINO PVE - TELA COMPLETA COM IMPORTS CORRIGIDOS

import React, { useState, useEffect, useCallback, useMemo, useRef } from 'react';
import { AnimatePresence, motion } from "framer-motion"
import { BookOpen, Crown, Flag, Heart, Hourglass, Layers, Loader2, Shield, Skull, Sparkles, Sword, Swords, Wifi, WifiOff, X, Zap } from "lucide-react"
import { GameCard } from "./game-card"
import { ReactionModal } from "./reaction-modal"
import { PreCombatModal } from "./pre-combat-modal"
import { TriggerPromptModal } from "./trigger-prompt-modal"
import { CoinFlip } from "./coin-flip"
import { sleep, useTrainingDuel } from "@/hooks/useTrainingDuel"
import { supabase } from "@/lib/supabase"
import type { BanCandidate, MatchAction, MatchCardZone, MatchState, VisibleMatchCard } from "@/lib/types"
import { highlightEffectText } from "@/lib/effect-parser"
import { secureImageUrl } from "@/lib/secure-url"

// Dicionário de narração de zonas
const zoneNarrative: Record<string, string> = {
  hand: "Mão",
  life: "Vida",
  reinforcement: "Reforço",
  attacker: "Ataque",
  leader: "Líder",
  graveyard: "Cemitério",
  banished: "Banimento",
  temporary: "Limbo Temporário"
}

// Retorna a descrição de resultado dos efeitos
function effectOutcome(action: MatchAction, cards: VisibleMatchCard[]): string {
  const p = action.payload_public || {}
  const res = p.result || {}
  const card = (id: string | null) => cards.find(item => item.id === id)
  const nameOf = (id: string | null) => id ? card(id)?.card_data?.nome ?? "Unidade" : "Alguém"
  
  if (p.effect_code === "common_beggar_king_destroy_life") {
    return `👑 O Rei dos Mendigos decapita a Carta de Vida inimiga ${nameOf(p.p_target_card_id)} instantaneamente!`
  }
  if (res.damage_dealt) {
    const targets = Array.isArray(res.target_card_ids) 
      ? res.target_card_ids.map((id: string) => nameOf(id)).join(", ")
      : nameOf(p.p_target_card_id)
    return `💥 Descarrega ${res.damage_dealt} de dano sobre ${targets || "o alvo"}!`
  }
  if (res.power_stolen) {
    return `🧬 Drena ${res.power_stolen} de poder de ${nameOf(p.p_target_card_id)} e incorpora ao seu próprio ataque!`
  }
  return res.message ? String(res.message) : "Executa uma ação tática de suporte no campo."
}

// Gera a linha descritiva para cada ação registrada na crônica da batalha
function actionChronicleLines(action: MatchAction, state: MatchState | null, cards: VisibleMatchCard[]): string[] {
  const p = action.payload_public || {}
  const actor = action.actor_user_id === state?.player1_id ? state?.player1_username : state?.player2_username
  const card = (id: string | null) => cards.find(item => item.id === id)
  const nameOf = (id: string | null) => id ? card(id)?.card_data?.nome ?? "Unidade" : "Alguém"
  
  if (action.action_type === "match_created") return ["🎮 Combate iniciado nas areias lendárias."]
  if (action.action_type === "card_banned") {
    return [`🚫 ${actor ?? "Combatente"} bane ${nameOf(p.source_card_id)} do catálogo adversário.`]
  }
  if (action.action_type === "setup_submitted") {
    return [`📦 ${actor ?? "Combatente"} alocou suas defesas nas trincheiras e concluiu sua preparação.`]
  }
  if (action.action_type === "card_drawn") {
    return [`🃏 Compra realizada do deck.`]
  }
  if (action.action_type === "card_played") {
    const dest = p.destination_zone === "attacker" ? "Linha de Ataque" : "Linha de Reforço"
    return [`⚔️ ${actor ?? "Combatente"} posiciona ${nameOf(p.match_card_id)} de sua mão na ${dest} (posição ${p.destination_position}).`]
  }
  return []
}

function BannedCard({ ban, label }: { ban?: any; label: string }) {
  return (
    <div className="rounded border border-stone-800 bg-stone-900/50 p-2 text-center text-xs">
      <span className="block text-stone-500 font-bold">{label}</span>
      <span className="block text-stone-300 font-mono mt-1">{ban?.source_card_id ? "Unidade Excluída" : "Disponível"}</span>
    </div>
  )
}

function BanPhaseModal({ candidates, selected, busy, error, onSelect, onBan, onRefetch, onSkip }: { candidates: BanCandidate[]; selected: BanCandidate | null; busy: boolean; error: string | null; onSelect: (card: BanCandidate) => void; onBan: (id: string, rarity: string) => void; onRefetch: () => void; onSkip: () => void }) {
  const [showTimeout, setShowTimeout] = useState(false)
  const [selectedCardForReview, setSelectedCardForReview] = useState<any>(null)
  
  useEffect(() => {
    if (candidates.length > 0) return
    const timer = setTimeout(() => setShowTimeout(true), 3000)
    return () => clearTimeout(timer)
  }, [candidates.length])

  if (!candidates.length) {
    return (
      <div className="fixed inset-0 z-[170] flex flex-col items-center justify-center bg-black/95 p-5 text-amber-100">
        <Loader2 className="animate-spin mb-4 text-amber-400" size={48} />
        <h2 className="font-serif text-2xl font-black mb-6">Identificando o Grimório Adversário...</h2>
        {showTimeout && (
          <div className="flex flex-col items-center gap-3">
            <button onClick={() => { setShowTimeout(false); onRefetch() }} className="rounded border border-amber-500 bg-amber-900 px-6 py-2 text-sm font-black text-amber-100">RECARREGAR GRIMÓRIO</button>
            <button onClick={onSkip} className="rounded border border-stone-600 bg-stone-900 px-6 py-2 text-xs font-black text-stone-400 mt-2">PULAR BANIMENTO (TREINO)</button>
          </div>
        )}
      </div>
    )
  }

  return (
    <motion.div initial={{ opacity: 0 }} animate={{ opacity: 1 }} className="fixed inset-0 z-[170] flex flex-col items-center justify-center bg-black/95 p-5">
      <div className="w-full max-w-6xl rounded-2xl border border-amber-400 bg-stone-950 p-6 shadow-2xl flex flex-col max-h-[95vh]">
        <h2 className="text-center font-serif text-3xl font-black text-amber-100 mb-2">Banimento Estratégico</h2>
        <p className="text-center text-sm text-stone-400 mb-6">Inspecione o deck inimigo e clique em qualquer carta para bani-la imediatamente.</p>
        
        <div className="flex-1 flex gap-6 overflow-hidden min-h-0">
          <div className="flex-1 overflow-y-auto pr-2">
            <div className="grid grid-cols-3 sm:grid-cols-4 md:grid-cols-5 gap-4">
              {candidates.map(card => (
                <button
                  disabled={busy}
                  key={card.card_id}
                  onClick={() => {
                    onSelect(card)
                    setSelectedCardForReview(card)
                    onBan(card.card_id, card.rarity ?? "common")
                  }}
                  className={`relative overflow-hidden rounded-xl border-2 transition-all hover:scale-105 ${selectedCardForReview?.card_id === card.card_id ? "border-red-500 shadow-[0_0_20px_rgba(248,113,113,0.7)] z-10 scale-105" : "border-amber-700/40 opacity-80"}`}
                >
                  <img src={secureImageUrl(card.image_url)} alt={card.name} className="aspect-[2/3] w-full object-cover" />
                  <div className="absolute inset-x-0 bottom-0 bg-black/80 px-1 py-2 text-center">
                    <span className="block truncate text-[10px] font-black text-amber-100">{card.name}</span>
                    <span className="block text-[9px] uppercase text-stone-400">{card.rarity} · {card.copy_count}x</span>
                  </div>
                </button>
              ))}
            </div>
          </div>

          {selectedCardForReview && (
            <div className="w-80 border-l border-amber-900/40 pl-6 flex flex-col justify-between shrink-0 overflow-y-auto bg-black/35 p-4 rounded-xl">
              <div>
                <img src={secureImageUrl(selectedCardForReview.image_url)} alt={selectedCardForReview.name} className="w-full aspect-[2/3] object-cover rounded-lg border-2 border-red-500/60 mb-4" />
                <h3 className="font-serif text-xl font-bold text-amber-200">{selectedCardForReview.name}</h3>
                <p className="text-xs text-stone-400 uppercase tracking-widest mt-1">{selectedCardForReview.rarity}</p>
              </div>
              <div className="mt-4 pt-4 border-t border-stone-800">
                <button
                  disabled={busy}
                  onClick={() => onBan(selectedCardForReview.card_id, selectedCardForReview.rarity ?? "common")}
                  className="w-full rounded-lg border-2 border-red-500 bg-red-900 px-4 py-3 font-black text-white text-xs"
                >
                  BANIR ESTA CARTA
                </button>
              </div>
            </div>
          )}
        </div>
      </div>
    </motion.div>
  )
}

export function TrainingScreen() {
  const [matchId, setMatchId] = useState("")
  const [userId, setUserId] = useState("")
  const [inspectCard, setInspectedCard] = useState<VisibleMatchCard | null>(null)
  const [effectMessage, setEffectMessage] = useState<string | null>(null)
  const [selectedAttackers, setSelectedAttackers] = useState<Set<string>>(new Set())
  const [setupCards, setSetupCards] = useState<Set<string>>(new Set())
  const [setupReinforcements, setSetupReinforcements] = useState<Set<string>>(new Set())
  const [setupBusy, setSetupBusy] = useState(false)
  const [banCandidates, setBanCandidates] = useState<BanCandidate[]>([])
  const [selectedBan, setSelectedBan] = useState<BanCandidate | null>(null)
  const [banBusy, setBanBusy] = useState(false)
  const [banError, setBanError] = useState<string | null>(null)
  const [preCombatOpen, setPreCombatOpen] = useState(false)
  const [graveyardOpen, setGraveyardOpen] = useState(false)
  const [pileOpen, setPileOpen] = useState<{ title: string; cards: VisibleMatchCard[]; hidden?: boolean } | null>(null)
  
  const botActionRunning = useRef(false)
  
  useEffect(() => {
    const params = new URLSearchParams(window.location.search)
    const mid = params.get("matchId")
    if (mid) setMatchId(mid)
    void supabase.auth.getUser().then(({ data }) => setUserId(data.user?.id ?? "human-player-id"))
  }, [])
  
  const duel = useTrainingDuel(matchId, userId)
  const { matchState, boardCards, matchActions, pendingAttack, connectionStatus, isTraining, isCurrentPlayer, isPlayer1, opponentId, usedEffectCardIds, isActionPending } = duel

  // Gatilho automático da IA do Bot PVE local
  useEffect(() => {
    if (!isTraining || !matchState || matchState.status !== "in_progress" || matchState.current_player_id !== opponentId) return
    if (botActionRunning.current || isActionPending) return

    let active = true
    const runBot = async () => {
      botActionRunning.current = true
      await sleep(1000)
      if (!active) return
      try {
        await duel.runTrainingBotTurn()
      } catch (err) {
        console.error("Erro no autômato do Bot:", err)
      } finally {
        botActionRunning.current = false
      }
    }
    void runBot()
    return () => { active = false }
  }, [isTraining, matchState?.status, matchState?.current_player_id, opponentId, isActionPending])

  useEffect(() => {
    if (matchState?.status !== "ban_phase") return
    duel.getBanCandidates().then(c => {
      setBanCandidates(c)
      if (c.length > 0) setSelectedBan(c[0])
    })
  }, [matchState?.status])

  const submitBan = async (cardId: string | null, category: string) => {
    if (banBusy) return
    setBanBusy(true)
    try {
      await duel.submitBan(cardId, category)
    } catch (e: any) {
      setBanError(e.message || "Falha no banimento.")
    } finally {
      setBanBusy(false)
    }
  }

  const confirmPreparation = async () => {
    if (setupCards.size !== 3 || setupBusy) return
    setSetupBusy(true)
    try {
      await duel.submitSetup(Array.from(setupCards), Array.from(setupReinforcements))
    } catch (e) {
      console.error("Erro no setup:", e)
    } finally {
      setSetupBusy(false)
    }
  }

  const toggleSetup = (id: string) => setSetupCards(prev => {
    const next = new Set(prev)
    if (next.has(id)) next.delete(id)
    else if (next.size < 3) next.add(id)
    return next
  })

  const toggleSetupReinforcement = (id: string) => setSetupReinforcements(prev => {
    const next = new Set(prev)
    if (next.has(id)) next.delete(id)
    else if (next.size < 4) next.add(id)
    return next
  })

  const playSelected = (cardId: string, zone: "attacker" | "reinforcement", slotIndex: number) => {
    void duel.playCard(cardId, zone, slotIndex)
  }

  const recallCard = (card: VisibleMatchCard) => {
    void duel.recallMatchCard(card.id)
  }

  const submitTurn = async () => {
    if (selectedAttackers.size > 0) {
      await duel.declareAttack(Array.from(selectedAttackers), false)
      setSelectedAttackers(new Set())
    } else {
      await duel.endTurn()
    }
  }

  const mine = (zone: VisibleMatchCard["zone"]) => boardCards.filter(c => c.owner_id === userId && c.zone === zone)
  const theirs = (zone: VisibleMatchCard["zone"]) => boardCards.filter(c => c.owner_id === opponentId && c.zone === zone)
  
  const myHp = mine("life").reduce((sum, c) => sum + (c.current_life ?? 0), 0)
  const theirHp = theirs("life").reduce((sum, c) => sum + (c.current_life ?? 0), 0)
  const myMana = isPlayer1 ? matchState?.player1_mana ?? 0 : matchState?.player2_mana ?? 0
  const theirMana = isPlayer1 ? matchState?.player2_mana ?? 0 : matchState?.player1_mana ?? 0

  const hand = mine("hand")

  return (
    <main className="relative min-h-screen bg-stone-950 font-serif text-stone-100">
      <header className="flex items-center justify-between border-b border-amber-900/30 bg-stone-950/80 px-6 py-3">
        <h2 className="text-sm font-black uppercase text-amber-200">Arena de Treino PvE (Offline Local)</h2>
        <div className="flex gap-4 text-xs font-mono">
          <span>Sua Vida: <b className="text-emerald-400">{myHp} HP</b></span>
          <span>Vida do Bot: <b className="text-red-400">{theirHp} HP</b></span>
        </div>
      </header>

      <div className="grid grid-cols-[200px_1fr_200px] h-[calc(100vh-100px)] p-4 gap-4">
        {/* Lado Esquerdo */}
        <aside className="border border-stone-800 bg-stone-900/30 p-3 rounded-lg flex flex-col justify-between">
          <div>
            <h4 className="text-xs uppercase text-stone-500 font-bold mb-2">Defesas Adversárias</h4>
            <div className="text-xs text-stone-300">Bot Deck: {theirs("deck").length} cartas</div>
            <div className="text-xs text-stone-300">Bot Cemitério: {theirs("graveyard").length} cartas</div>
          </div>
          <button onClick={() => void duel.surrenderMatch()} className="w-full py-2 bg-red-950 border border-red-800 text-red-200 rounded text-xs">RENDER-SE</button>
        </aside>

        {/* Tabuleiro de Duelo */}
        <section className="flex flex-col justify-between bg-black/20 rounded-xl p-4 border border-stone-900">
          {/* Bot Tabuleiro */}
          <div className="grid grid-cols-3 gap-2 border-b border-stone-900 pb-4">
            {theirs("life").map(c => <div key={c.id} className="border border-red-900/50 p-2 rounded text-center"><p className="text-[10px] text-stone-500">{c.card_name}</p><b className="text-red-400">{c.current_life} HP</b></div>)}
          </div>

          <div className="text-center py-2 text-stone-600 text-xs uppercase font-mono">Linha de Defesa / Combate</div>

          {/* Jogador Tabuleiro */}
          <div className="grid grid-cols-3 gap-2 border-t border-stone-900 pt-4">
            {mine("life").map(c => <div key={c.id} onClick={() => setInspectedCard(c)} className="border border-emerald-900/50 p-2 rounded text-center cursor-pointer"><p className="text-[10px] text-stone-500">{c.card_name}</p><b className="text-emerald-400">{c.current_life} HP</b></div>)}
          </div>
        </section>

        {/* Inspetor de Cartas */}
        <aside className="border border-stone-800 bg-stone-900/30 p-3 rounded-lg">
          {inspectCard ? (
            <div>
              <h4 className="font-bold text-amber-200 text-sm">{inspectCard.card_name}</h4>
              <p className="text-xs text-stone-400 mt-1">{inspectCard.rarity}</p>
              <div className="mt-2 text-xs border-y border-stone-800 py-1.5 font-mono">
                Poder: {inspectCard.current_power} / HP: {inspectCard.current_life}
              </div>
              {inspectCard.zone === "attacker" && (
                <button onClick={() => recallCard(inspectCard)} className="mt-3 w-full py-1.5 bg-stone-850 border border-stone-700 text-xs rounded hover:bg-stone-800">Recuar Carta</button>
              )}
            </div>
          ) : (
            <p className="text-stone-500 text-xs text-center py-12">Selecione uma carta para inspecionar.</p>
          )}
        </aside>
      </div>

      {/* Mão e Controles */}
      <footer className="fixed bottom-0 inset-x-0 bg-stone-900/90 border-t border-amber-900/30 p-4 flex items-center justify-between">
        <div className="flex gap-2 overflow-x-auto">
          {hand.map(card => (
            <div key={card.id} className="relative group">
              <button onClick={() => setInspectedCard(card)} className="border border-stone-700 bg-stone-950 px-3 py-4 rounded text-xs hover:border-amber-500">
                {card.card_name}
              </button>
              {isCurrentPlayer && (
                <div className="absolute -top-6 inset-x-0 hidden group-hover:flex justify-center gap-1">
                  <button onClick={() => playSelected(card.id, "life", 1)} className="bg-emerald-800 px-1 py-0.5 rounded text-[9px] text-white">Jogar</button>
                </div>
              )}
            </div>
          ))}
        </div>
        <div className="flex items-center gap-2">
          {isCurrentPlayer ? (
            <button onClick={submitTurn} className="bg-amber-700 border border-amber-500 px-6 py-2 rounded font-bold text-sm text-amber-100">CONFIRMAR JOGADA</button>
          ) : (
            <span className="text-stone-500 text-xs uppercase font-mono">Bot Jogando...</span>
          )}
        </div>
      </footer>

      {/* Modal de Banimento */}
      <AnimatePresence>
        {matchState?.status === "ban_phase" && (
          <BanPhaseModal
            candidates={banCandidates}
            selected={selectedBan}
            busy={banBusy}
            error={banError}
            onSelect={setSelectedBan}
            onBan={submitBan}
            onRefetch={() => {}}
            onSkip={() => submitBan(null, "rare")}
          />
        )}
      </AnimatePresence>

      {/* Modal de Setup (Turno 0) */}
      <AnimatePresence>
        {matchState?.status === "setup" && (
          <div className="fixed inset-0 z-[172] flex items-center justify-center bg-black/95 p-5">
            <div className="bg-stone-950 border border-stone-800 rounded-xl p-6 max-w-2xl w-full">
              <h3 className="text-xl font-bold text-center text-emerald-300 font-serif mb-2">Turno 0 - Alocação das Trincheiras</h3>
              <p className="text-center text-xs text-stone-400 mb-6">Escolha exatamente 3 Cartas de Vida de sua mão.</p>
              
              <div className="grid grid-cols-4 gap-2 mb-6">
                {hand.map(card => {
                  const selected = setupCards.has(card.id)
                  return (
                    <button key={card.id} onClick={() => toggleSetup(card.id)} className={`p-3 rounded border text-xs text-center \${selected ? "border-emerald-500 bg-emerald-950/30 text-white" : "border-stone-850 bg-stone-900 text-stone-400"}`}>
                      {card.card_name}
                    </button>
                  )
                })}
              </div>

              <button
                disabled={setupCards.size !== 3}
                onClick={confirmPreparation}
                className="w-full py-3 bg-emerald-800 border border-emerald-500 text-white font-bold rounded hover:bg-emerald-700 disabled:opacity-40"
              >
                CONFIRMAR E INICIAR COMBATE (\${setupCards.size}/3)
              </button>
            </div>
          </div>
        )}
      </AnimatePresence>
    </main>
  )
}
