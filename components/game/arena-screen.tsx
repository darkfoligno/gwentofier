"use client"

import { useState, useEffect, useMemo } from "react"
import { motion, AnimatePresence } from "framer-motion"
import { Crown, Skull, Layers, Hexagon, Coins, X, Hand, Wifi, WifiOff, Loader2, AlertTriangle, Flag, Swords } from "lucide-react"
import { collection, type GameCard as GameCardType } from "@/lib/game-data"
import { GameCard } from "./game-card"
import { useDuelRealtime } from "@/hooks/useDuelRealtime"
import { ReactionModal } from "./reaction-modal"
import { supabase } from "@/lib/supabase"
import type { BanCandidate, VisibleMatchCard } from "@/lib/types"

/* card footprint used across the board */
const CARD_W = "w-16 md:w-20 lg:w-22"
const LIFE_W = "w-18 md:w-22 lg:w-24"

/* ---------- Empty carved slot ---------- */
function CardSlot({ label, accent = "#d4af37", onClick, active = false }: { label: string; accent?: string; onClick?: () => void; active?: boolean }) {
  return (
    <button
      type="button"
      onClick={onClick}
      disabled={!onClick}
      className={`relative ${CARD_W} flex aspect-[2.5/3.5] items-center justify-center rounded-md border-2 border-dashed`}
      style={{
        borderColor: `${accent}55`,
        background: "rgba(0,0,0,0.45)",
        boxShadow: active ? `0 0 18px ${accent}` : "inset 0 4px 12px rgba(0,0,0,0.9)",
      }}
    >
      <Hexagon size={24} style={{ color: `${accent}33` }} strokeWidth={1} />
      <span className="absolute bottom-1 left-1/2 -translate-x-1/2 text-[8px] font-serif text-amber-600/40 tracking-widest uppercase">
        {label}
      </span>
    </button>
  )
}

/* ---------- Face-down reinforcement card with flip animation ---------- */
function FaceDownCard({ isFlipped = false, onFlip }: { isFlipped?: boolean; onFlip?: () => void }) {
  return (
    <motion.div
      className={`relative ${CARD_W} aspect-[2.5/3.5]`}
      initial={false}
      animate={{ rotateY: isFlipped ? 0 : 180 }}
      transition={{ duration: 0.6, type: "spring", stiffness: 200, damping: 20 }}
      style={{ transformStyle: "preserve-3d" }}
      onClick={onFlip}
    >
      {/* Face-down side */}
      <motion.div
        className="absolute inset-0 backface-hidden"
        style={{ transform: "rotateY(180deg)" }}
      >
        <GameCard card={collection[0]} isFaceDown={true} />
      </motion.div>
      
      {/* Face-up side */}
      <motion.div className="absolute inset-0 backface-hidden">
        <GameCard card={collection[1]} interactive={true} />
      </motion.div>
    </motion.div>
  )
}

/* ---------- Life card ---------- */
function LifeCard({ label, att, vida, interactive = false, onClick }: { label: string; att: number; vida: number; interactive?: boolean; onClick?: () => void }) {
  return (
    <div
      className={`relative ${LIFE_W} flex aspect-[2.5/3.5] flex-col overflow-hidden rounded-md border-2 p-1 cursor-pointer transition-all hover:ring-2 hover:ring-amber-400 ${interactive ? '' : 'cursor-default'}`}
      style={{
        borderColor: "#dc2626aa",
        background:
          "radial-gradient(circle at 50% 20%, rgba(220,38,38,0.25), transparent 60%), linear-gradient(160deg, #292524, #0c0a09)",
        boxShadow: "0 0 12px rgba(220,38,38,0.35), inset 0 2px 8px rgba(0,0,0,0.8)",
      }}
      onClick={interactive ? onClick : undefined}
    >
      <div className="flex flex-1 items-center justify-center">
        <Crown size={24} className="text-rune-life/70" />
      </div>
      <div className="rounded bg-black/60 px-1 py-0.5 text-center">
        <p className="text-[8px] font-semibold uppercase leading-tight tracking-wide text-rune-life/90">{label}</p>
        <p className="text-[9px] font-bold leading-tight text-foreground">
          ATT: {att} <span className="text-rune-life">|</span> VIDA: {vida}
        </p>
      </div>
    </div>
  )
}

/* fixed-width board card wrapper */
function BoardCard({ index, playerMana }: { index: number; playerMana: number }) {
  return (
    <div className={CARD_W}>
      <GameCard card={collection[index]} interactive={true} playerMana={playerMana} />
    </div>
  )
}

function MatchBoardCard({ card, playerMana, selected = false, onClick }: { card: VisibleMatchCard; playerMana: number; selected?: boolean; onClick?: () => void }) {
  if (!card.card_data) return <FaceDownCard />
  return <button type="button" onClick={onClick} className={`${CARD_W} rounded-lg ${selected ? "ring-2 ring-red-400 shadow-[0_0_20px_rgba(248,113,113,.8)]" : ""}`}>
    <GameCard card={card.card_data as unknown as GameCardType} interactive={Boolean(onClick)} playerMana={playerMana} />
  </button>
}

function ManaHandCounter({ current, max }: { current: number; max: number }) {
  return (
    <div className="flex items-center gap-2 rounded-full border-2 border-gold/50 bg-stone-900/90 px-3 py-1.5 shadow-[0_0_16px_rgba(194,155,56,0.3),inset_0_2px_6px_rgba(0,0,0,0.9)]">
      <div className="relative flex h-8 w-8 items-center justify-center rounded-full bg-gradient-to-br from-lapis-lazuli to-blue-900 lapis-glow">
        <Hand size={16} className="text-white" />
      </div>
      <div className="flex flex-col">
        <span className="text-[9px] font-semibold uppercase text-gold/80">Mão/Mana</span>
        <span className="font-mono text-sm font-bold text-gold">{current}/{max}</span>
      </div>
    </div>
  )
}

function Row({ children, tight }: { children: React.ReactNode; tight?: boolean }) {
  return (
    <div className={`flex items-center justify-center gap-2 ${tight ? "gap-1.5" : ""}`}>
      {children}
    </div>
  )
}

function ZoneLabel({ children }: { children: React.ReactNode }) {
  return (
    <p className="text-center font-serif text-[9px] font-bold uppercase tracking-widest text-brass/70">{children}</p>
  )
}

function CemeteryModal({ onClose, cards }: { onClose: () => void; cards: VisibleMatchCard[] }) {
  return (
    <motion.div
      initial={{ opacity: 0 }}
      animate={{ opacity: 1 }}
      exit={{ opacity: 0 }}
      className="fixed inset-0 z-[100] flex items-center justify-center bg-black/80 p-6 backdrop-blur-sm"
      onClick={onClose}
    >
      <motion.div
        initial={{ scale: 0.9, y: 20 }}
        animate={{ scale: 1, y: 0 }}
        exit={{ scale: 0.9, y: 20 }}
        onClick={(e) => e.stopPropagation()}
        className="wood-grain relative max-h-[80vh] w-full max-w-2xl overflow-hidden rounded-xl border-2 border-gold/50 p-5 shadow-[0_20px_60px_rgba(0,0,0,0.9)]"
      >
        <button
          onClick={	onClose}
          className="absolute right-3 top-3 text-brass transition-colors hover:text-gold"
          aria-label="Fechar cemitério"
        >
          <X size={20} />
        </button>
        <h3 className="mb-4 flex items-center gap-2 font-serif text-lg font-black text-gold text-shadow-gold">
          <Skull size={20} /> Cemitério — Cartas Destruídas
        </h3>
        <div className="scrollbar-thin grid max-h-[60vh] grid-cols-4 gap-3 overflow-y-auto sm:grid-cols-6">
          {cards.filter(c => c.card_data).map((c) => (
            <GameCard key={c.id} card={c.card_data as unknown as GameCardType} />
          ))}
        </div>
      </motion.div>
    </motion.div>
  )
}

/* ---------- Profile Banner Component ---------- */
function ProfileBanner({ 
  name, 
  rank, 
  mana, 
  hand, 
  isPlayer = false,
  showLeader = false,
  leaderCooldown = 0
}: { 
  name: string
  rank: string
  mana: number
  hand: number
  isPlayer?: boolean
  showLeader?: boolean
  leaderCooldown?: number
}) {
  return (
    <div className="flex flex-col gap-2">
      <div className="wood-grain relative rounded-lg border-2 border-gold-dark/50 p-3 shadow-[0_8px_24px_rgba(0,0,0,0.8),inset_0_2px_8px_rgba(0,0,0,0.6)]">
        <div className="flex items-center gap-3">
          {/* Avatar */}
          <div className="relative flex h-14 w-14 shrink-0 items-center justify-center rounded-lg border-2 border-gold/60 bg-wood-darkest shadow-[inset_0_2px_8px_rgba(0,0,0,0.9)]">
            {isPlayer ? (
              <Crown size={24} className="text-gold" />
            ) : (
              <Skull size={24} className="text-rune-life" />
            )}
          </div>
          
          {/* Info */}
          <div className="flex-1">
            <p className="font-serif text-sm font-bold text-gold text-shadow-gold">{name}</p>
            <p className="text-[10px] uppercase tracking-wide text-brass">{rank}</p>
          </div>

          {/* Mana/Hand Counter */}
          <ManaHandCounter current={hand} max={mana} />
        </div>
      </div>

      {/* Leader Card Slot (Player Only) */}
      {showLeader && (
        <div className="flex flex-col items-center gap-1">
          <span className="font-serif text-[9px] font-bold uppercase tracking-widest text-brass/70">Líder</span>
          <div className="relative flex aspect-[3/4] w-16 flex-col items-center justify-center rounded-md border-2 border-gold/60 bg-gradient-to-b from-leather to-wood-darkest shadow-[0_0_14px_rgba(212,175,55,0.4)]">
            <Crown size={20} className="text-gold" />
            <span className="mt-0.5 rounded bg-black/60 px-1 text-[7px] font-semibold text-gold">
              Resfr.: {leaderCooldown} Turnos
            </span>
          </div>
        </div>
      )}
    </div>
  )
}

/* ---------- Graveyard Component ---------- */
function Graveyard({ count, onClick }: { count: number; onClick: () => void }) {
  return (
    <button
      onClick={onClick}
      className="group flex flex-col items-center gap-1.5"
      aria-label="Abrir cemitério"
    >
      <span className="font-serif text-[10px] font-bold uppercase tracking-widest text-brass">Cemitério</span>
      <div
        className="relative flex aspect-[3/4] w-20 items-center justify-center rounded-md border-2 border-gold-dark/60 shadow-[0_6px_18px_rgba(0,0,0,0.8),inset_0_2px_8px_rgba(0,0,0,0.9)] transition-transform group-hover:scale-105"
        style={{ background: "linear-gradient(160deg, #2c1e14, #140d07)" }}
      >
        <Skull size={32} className="text-gold/60" />
        <span className="absolute -right-2 -top-2 flex h-7 w-7 items-center justify-center rounded-full border-2 border-gold bg-wood-darkest text-[11px] font-bold text-gold shadow-[0_2px_8px_rgba(0,0,0,0.8)]">
          {count}
        </span>
      </div>
    </button>
  )
}

/* ---------- Deck Component ---------- */
function Deck({ current, max, isOpponent = false }: { current: number; max: number; isOpponent?: boolean }) {
  return (
    <div className={`flex flex-col items-center gap-1.5 ${isOpponent ? "order-first" : ""}`}>
      <span className="font-serif text-[10px] font-bold uppercase tracking-widest text-brass">
        {isOpponent ? "Deck Adversário" : "Seu Deck"}
      </span>
      <div className="relative aspect-[3/4] w-20">
        {[0, 1, 2, 3, 4].map((i) => (
          <div
            key={i}
            className="absolute inset-0 rounded-md border-2 border-gold-dark/60"
            style={{
              transform: `translate(${i * 3}px, ${i * -3}px)`,
              background: "repeating-linear-gradient(45deg, #2c1e14 0 6px, #1a120b 6px 12px)",
              boxShadow: "0 4px 10px rgba(0,0,0,0.6)",
            }}
          >
            {i === 4 && (
              <div className="absolute inset-0 flex items-center justify-center">
                <Layers size={24} className="text-gold/70" />
              </div>
            )}
          </div>
        ))}
        <span className="absolute -right-2 -top-2 z-10 flex h-7 items-center justify-center rounded-full border-2 border-gold bg-wood-darkest px-2 text-[11px] font-bold text-gold shadow-[0_2px_8px_rgba(0,0,0,0.8)]">
          {current}/{max}
        </span>
      </div>
      {!isOpponent && (
        <span className="text-[9px] uppercase text-brass">Compras</span>
      )}
    </div>
  )
}

interface PlayerState {
  name: string
  rank: string
  mana: number
  maxMana: number
  hand: typeof collection
  lifeCards: { label: string; att: number; vida: number }[]
  reinforcements: { cardIndex: number | null; isFaceDown: boolean; isFlipped: boolean }[]
  attackers: { cardIndex: number | null }[]
  deckCount: number
  maxDeck: number
}

export function ArenaScreen() {
  const [cemeteryOpen, setCemeteryOpen] = useState(false)
  const [flippedCards, setFlippedCards] = useState<Set<number>>(new Set())
  const [sandParticles, setSandParticles] = useState<Array<{
    id: number
    x: number
    y: number
    size: number
    duration: number
    delay: number
  }>>([])
  const [isMounted, setIsMounted] = useState(false)
  const [banPhaseOpen, setBanPhaseOpen] = useState(false)
  const [banCandidates, setBanCandidates] = useState<BanCandidate[]>([])
  const [matchId, setMatchId] = useState("")
  const [currentUserId, setCurrentUserId] = useState("")
  const [selectedHandCard, setSelectedHandCard] = useState<string | null>(null)
  const [selectedAttackers, setSelectedAttackers] = useState<Set<string>>(new Set())

  useEffect(() => {
    setMatchId(new URLSearchParams(window.location.search).get("matchId") ?? "")
    void supabase.auth.getUser().then(({ data }) => setCurrentUserId(data.user?.id ?? ""))
  }, [])

  // Use Supabase Realtime hook for authoritative multiplayer state
  const {
    matchState,
    boardCards,
    connectionStatus,
    isCurrentPlayer,
    isPlayer1,
    opponentId,
    getCardsByZone,
    playCard,
    declareAttack,
    endTurn,
    passWithoutAction,
    getBanCandidates,
    submitBan,
    replaceEarlyLifeCard,
    surrenderMatch,
    activateMatchEffect,
    declineAttackReaction,
    pendingAttack,
    hasActedThisTurn,
    reactionUsed,
  } = useDuelRealtime(matchId, currentUserId)

  // Generate sand particles only on client side to fix hydration error
  useEffect(() => {
    const particles = Array.from({ length: 20 }, (_, i) => ({
      id: i,
      x: Math.random() * 100,
      y: Math.random() * 100,
      size: Math.random() * 3 + 1,
      duration: Math.random() * 10 + 15,
      delay: Math.random() * 5,
    }))
    setSandParticles(particles)
    setIsMounted(true)
  }, [])

  // Handle ban phase logic
  useEffect(() => {
    if (matchState?.status === 'ban_phase' && !banPhaseOpen) {
      const fetchBanCandidates = async () => {
        try {
          const candidates = await getBanCandidates()
          setBanCandidates((candidates || []).filter(card => card.is_golden === true && card.rarity === "legendary"))
          setBanPhaseOpen(true)
        } catch (error) {
          console.error('Erro ao buscar candidatos de banimento:', error)
        }
      }
      fetchBanCandidates()
    } else if (matchState?.status !== 'ban_phase') {
      setBanPhaseOpen(false)
      setBanCandidates([])
    }
  }, [matchState?.status, banPhaseOpen, getBanCandidates])

  // Fallback to mock data if Supabase is not configured
  const useMockData = !matchId

  const currentTurn = matchState?.current_turn ?? 0
  const localPlayerMana = matchState ? (isPlayer1 ? matchState.player1_mana : matchState.player2_mana) : 6
  const localPlayerMaxMana = matchState ? (isPlayer1 ? matchState.player1_max_mana : matchState.player2_max_mana) : 10
  const opponentMana = matchState ? (isPlayer1 ? matchState.player2_mana : matchState.player1_mana) : 7

  const toggleFlip = (index: number) => {
    setFlippedCards(prev => {
      const newSet = new Set(prev)
      if (newSet.has(index)) {
        newSet.delete(index)
      } else {
        newSet.add(index)
      }
      return newSet
    })
  }

  // Get cards from authoritative database or fallback to mock
  const getLocalPlayerHand = () => {
    if (useMockData) return collection.slice(0, 6)
    return getCardsByZone('hand', currentUserId).filter(c => c.card_data).map(c => c.card_data as unknown as GameCardType)
  }

  const getLocalPlayerLifeCards = () => {
    if (useMockData) {
      return [
        { label: "Defesa 1 [Frente]", att: 4500, vida: 8000 },
        { label: "Defesa 2", att: 3800, vida: 9500 },
        { label: "Defesa 3 [Base]", att: 3000, vida: 12000 },
      ]
    }
    return getCardsByZone('life', currentUserId).map(c => ({
       label: c.card_data?.nome ?? "Carta de vida",
       att: c.card_data?.ataque ?? 0,
       vida: c.current_life ?? c.card_data?.vida ?? 0,
       slotIndex: c.slot_index,
    }))
  }

  const getOpponentLifeCards = () => {
    if (useMockData) {
      return [
        { label: "Defesa 1", att: 5000, vida: 6000 },
        { label: "Defesa 2", att: 4200, vida: 7500 },
        { label: "Defesa 3", att: 3000, vida: 9000 },
      ]
    }
    return getCardsByZone('life', opponentId).map(c => ({
      label: c.card_data?.nome ?? "Carta de vida",
      att: c.card_data?.ataque ?? 0,
      vida: c.current_life ?? c.card_data?.vida ?? 0,
    }))
  }

  const localHandRows = useMockData ? [] : getCardsByZone("hand", currentUserId)
  const localAttackers = useMockData ? [] : getCardsByZone("attacker", currentUserId)
  const attackPower = useMemo(() => localAttackers.filter(card => selectedAttackers.has(card.card_id)).reduce((sum, card) => sum + (card.card_data?.ataque ?? 0), 0), [localAttackers, selectedAttackers])
  const reactionCards = boardCards.filter(card => card.controller_user_id === currentUserId && ["life", "reinforcement", "attacker", "leader"].includes(card.zone) && (card.current_life ?? 0) > 0)

  return (
    <div
      className={`relative w-full h-screen overflow-hidden flex flex-col justify-between bg-stone-950 sandstone-texture select-none ${currentTurn >= 8 ? "ring-4 ring-inset ring-red-700 animate-pulse" : ""}`}
      style={{
        boxShadow: "inset 0 0 80px rgba(0,0,0,0.9)",
      }}
    >
      {/* Floating Sand Particles - only render after mount */}
      {isMounted && sandParticles.map((particle) => (
        <motion.div
          key={particle.id}
          className="absolute rounded-full pointer-events-none"
          style={{
            left: `${particle.x}%`,
            top: `${particle.y}%`,
            width: particle.size,
            height: particle.size,
            background: "radial-gradient(circle, rgba(194, 155, 56, 0.6), transparent)",
          }}
          animate={{
            y: [0, -100, 0],
            opacity: [0, 0.8, 0],
            scale: [1, 1.2, 1],
          }}
          transition={{
            duration: particle.duration,
            repeat: Number.POSITIVE_INFINITY,
            delay: particle.delay,
            ease: "easeInOut",
          }}
        />
      ))}

      {/* Sun Glare Effect */}
      <motion.div
        className="absolute top-0 left-1/2 -translate-x-1/2 w-full h-64 pointer-events-none"
        style={{
          background: "radial-gradient(ellipse at top, rgba(245, 158, 11, 0.15), transparent 70%)",
        }}
        animate={{
          opacity: [0.3, 0.6, 0.3],
          scale: [1, 1.1, 1],
        }}
        transition={{
          duration: 8,
          repeat: Number.POSITIVE_INFINITY,
          ease: "easeInOut",
        }}
      />
      {/* Realtime Connection Badge */}
      <div className="absolute top-2 right-4 z-50 flex items-center gap-2 rounded-full border border-gold/30 bg-stone-950/90 px-3 py-1.5 shadow-[0_0_12px_rgba(0,0,0,0.8)]">
        {connectionStatus === 'connected' && (
          <>
            <Wifi size={14} className="text-green-500" />
            <span className="text-[10px] font-serif text-green-500/90">Conectado à Areia</span>
          </>
        )}
        {connectionStatus === 'syncing' && (
          <>
            <Loader2 size={14} className="text-yellow-500 animate-spin" />
            <span className="text-[10px] font-serif text-yellow-500/90">Sincronizando...</span>
          </>
        )}
        {connectionStatus === 'disconnected' && (
          <>
            <WifiOff size={14} className="text-red-500" />
            <span className="text-[10px] font-serif text-red-500/90">Desconectado</span>
          </>
        )}
      </div>

      {currentTurn >= 8 && <div className="absolute left-1/2 top-2 z-50 flex -translate-x-1/2 items-center gap-2 rounded border border-red-500 bg-red-950/90 px-3 py-1 text-xs font-bold uppercase text-red-200"><AlertTriangle size={14} /> Deterioração ativa</div>}

      {/* Main 3-Column Grid Layout */}
      <div className="grid grid-cols-[minmax(160px,200px)_1fr_minmax(160px,200px)] w-full flex-1 max-w-[1800px] mx-auto px-3 py-1 gap-3 items-center overflow-hidden">
        
        {/* ============ LEFT COLUMN ============ */}
        <div className="flex flex-col justify-between h-full py-2 gap-2">
          {/* Top-Left: Opponent Profile */}
          <ProfileBanner
            name="Bruxo de Yggdrasil"
            rank="#12 Mestre de Ofieri"
            mana={10}
            hand={useMockData ? 7 : getCardsByZone('hand', opponentId).length}
            isPlayer={false}
          />

          {/* Center-Left: Graveyard */}
          <div className="flex-1 flex items-center justify-center">
            <Graveyard count={getCardsByZone("graveyard").length} onClick={() => setCemeteryOpen(true)} />
          </div>

          {/* Bottom-Left: Player Profile & Leader */}
          <ProfileBanner
            name="Cavaleiro de Velen"
            rank="#8 Guardião Real"
            mana={localPlayerMaxMana}
            hand={getLocalPlayerHand().length}
            isPlayer={true}
            showLeader={true}
            leaderCooldown={2}
          />
        </div>

        {/* ============ CENTER COLUMN (Battlefield) ============ */}
        <div className="flex flex-col justify-center h-full gap-1 py-1">
          
          {/* OPPONENT ZONE */}
          <div className="flex flex-col gap-1">
            {/* Row 1: Life Cards (Front) */}
            <div className="text-center">
              <span className="text-[8px] font-serif text-amber-600/40 tracking-widest uppercase">[ DEFESA ]</span>
            </div>
            <Row tight>
              {getOpponentLifeCards().map((life: any, i: number) => (
                <LifeCard key={i} label={life.label} att={life.att} vida={life.vida} interactive={false} />
              ))}
            </Row>

            {/* Row 2: Reinforcements */}
            <div className="text-center">
              <span className="text-[8px] font-serif text-amber-600/40 tracking-widest uppercase">[ REFORÇO ]</span>
            </div>
            <Row tight>
              {useMockData ? (
                <>
                  <FaceDownCard isFlipped={flippedCards.has(0)} onFlip={() => toggleFlip(0)} />
                  <FaceDownCard isFlipped={flippedCards.has(1)} onFlip={() => toggleFlip(1)} />
                  <FaceDownCard isFlipped={flippedCards.has(2)} onFlip={() => toggleFlip(2)} />
                  <CardSlot label="REFORÇO" accent="#8c6820" />
                </>
              ) : (
                getCardsByZone('reinforcement', opponentId).map((card: any, i: number) => (
                  !card.is_face_up ? (
                    <FaceDownCard
                      key={i} 
                      isFlipped={card.is_face_up}
                    />
                  ) : (
                    <MatchBoardCard key={i} card={card} playerMana={opponentMana} />
                  )
                ))
              )}
            </Row>

            {/* Row 3: Attackers */}
            <div className="text-center">
              <span className="text-[8px] font-serif text-amber-600/40 tracking-widest uppercase">[ ATAQUE ]</span>
            </div>
            <Row tight>
              {useMockData ? (
                <>
                  <BoardCard index={3} playerMana={opponentMana} />
                  <BoardCard index={9} playerMana={opponentMana} />
                  <CardSlot label="ATAQUE" accent="#dc2626" />
                  <CardSlot label="ATAQUE" accent="#dc2626" />
                </>
              ) : (
                getCardsByZone('attacker', opponentId).map((card: any, i: number) => (
                  <MatchBoardCard key={i} card={card} playerMana={opponentMana} />
                ))
              )}
            </Row>
          </div>

          {/* CENTER DIVIDER */}
          <div className="relative my-1 flex items-center justify-center py-1">
            <div
              className="absolute inset-x-0 top-1/2 h-[2px] -translate-y-1/2"
              style={{ background: "linear-gradient(90deg, transparent, #d4af3766, #d4af37, #d4af3766, transparent)" }}
            />
            <motion.div
              animate={{ rotate: 360 }}
              transition={{ duration: 40, repeat: Number.POSITIVE_INFINITY, ease: "linear" }}
              className="absolute left-1/2 h-12 w-12 -translate-x-1/2 rounded-full border border-gold/20"
              style={{ boxShadow: "0 0 30px rgba(212,175,55,0.15)" }}
            >
              <div className="absolute inset-2 rounded-full border border-gold/20" />
            </motion.div>

            <div className="relative z-10 flex items-center gap-3">
              <motion.div
                animate={{ rotateY: 360 }}
                transition={{ duration: 2.5, repeat: Number.POSITIVE_INFINITY, ease: "linear" }}
                className="flex h-8 w-8 items-center justify-center rounded-full border-2 border-gold bg-wood-darkest shadow-[0_0_12px rgba(212,175,55,0.5)]"
                style={{ transformStyle: "preserve-3d" }}
              >
                <Coins size={16} className="text-gold" />
              </motion.div>

              <div className="rounded-md border-2 border-gold/50 bg-wood-darkest/90 px-4 py-1 text-center shadow-[0_0_16px_rgba(212,175,55,0.3)]">
                <p className="font-serif text-xs font-black uppercase tracking-wider text-gold text-shadow-gold">
                  {currentTurn === 0 ? "CONFIGURAÇÃO" : `TURNO ${currentTurn}`}
                </p>
                <p className="text-[8px] uppercase tracking-widest text-rune-amber">
                  {currentTurn === 0 ? "Fase Inicial" : "Fase de Ataque"}
                </p>
              </div>

              <div className="flex gap-2">
                <motion.button
                  whileHover={{ scale: 1.05 }}
                  whileTap={{ scale: 0.95, rotate: -2 }}
                  disabled={!isCurrentPlayer}
                  onClick={() => void endTurn()}
                  className="gold-trim rounded-md px-3 py-1 font-serif text-[10px] font-black uppercase tracking-wide text-wood-darkest shadow-[0_4px_12px_rgba(0,0,0,0.7),inset_0_1px_2px_rgba(255,255,255,0.5)] border-2 border-gold-dark/50"
                >
                  ENCERRAR TURNO
                </motion.button>
                {!hasActedThisTurn && (
                  <motion.button
                    whileHover={{ scale: 1.05 }}
                    whileTap={{ scale: 0.95, rotate: -2 }}
                    disabled={!isCurrentPlayer}
                    onClick={() => void passWithoutAction()}
                    className="rounded-md px-3 py-1 font-serif text-[10px] font-black uppercase tracking-wide text-rune-amber shadow-[0_4px_12px_rgba(0,0,0,0.7),inset_0_1px_2px_rgba(255,255,255,0.5)] border-2 border-rune-amber/50"
                  >
                    PASSAR SEM AGIR
                  </motion.button>
                )}
                <button disabled={!selectedAttackers.size || !isCurrentPlayer} onClick={() => void declareAttack([...selectedAttackers], false).then(() => setSelectedAttackers(new Set()))} className="rounded-md border border-red-500 bg-red-950/70 px-3 py-1 text-[10px] font-black text-red-200 disabled:opacity-40"><Swords size={12} className="inline" /> ATACAR ({attackPower})</button>
              </div>
            </div>
          </div>

          {/* PLAYER ZONE */}
          <div className="flex flex-col gap-1">
            {/* Row 1: Attackers */}
            <div className="text-center">
              <span className="text-[8px] font-serif text-amber-600/40 tracking-widest uppercase">[ ATAQUE ]</span>
            </div>
            <Row tight>
              {useMockData ? (
                <>
                  <BoardCard index={0} playerMana={localPlayerMana} />
                  <CardSlot label="ATAQUE" />
                  <BoardCard index={4} playerMana={localPlayerMana} />
                  <CardSlot label="ATAQUE" />
                </>
              ) : (
                getCardsByZone('attacker', currentUserId).map((card: any, i: number) => (
                  <MatchBoardCard key={i} card={card} playerMana={localPlayerMana} selected={selectedAttackers.has(card.card_id)} onClick={() => setSelectedAttackers(previous => { const next = new Set(previous); next.has(card.card_id) ? next.delete(card.card_id) : next.add(card.card_id); return next })} />
                ))
              )}
              {!useMockData && [1, 2, 3, 4].filter(slot => !getCardsByZone("attacker", currentUserId).some(card => card.slot_index === slot)).map(slot => (
                <CardSlot key={`attacker-${slot}`} label="ATAQUE" accent="#dc2626" active={Boolean(selectedHandCard)} onClick={selectedHandCard && isCurrentPlayer ? () => void playCard(selectedHandCard, "attacker", slot).then(() => setSelectedHandCard(null)) : undefined} />
              ))}
            </Row>

            {/* Row 2: Reinforcements */}
            <div className="text-center">
              <span className="text-[8px] font-serif text-amber-600/40 tracking-widest uppercase">[ REFORÇO ]</span>
            </div>
            <Row tight>
              {useMockData ? (
                <>
                  <FaceDownCard isFlipped={flippedCards.has(3)} onFlip={() => toggleFlip(3)} />
                  <CardSlot label="REFORÇO" accent="#8c6820" />
                  <CardSlot label="REFORÇO" accent="#8c6820" />
                  <CardSlot label="REFORÇO" accent="#8c6820" />
                </>
              ) : (
                getCardsByZone('reinforcement', currentUserId).map((card: any, i: number) => (
                  !card.is_face_up ? (
                    <FaceDownCard 
                      key={i} 
                      isFlipped={false}
                    />
                  ) : (
                    <MatchBoardCard key={i} card={card} playerMana={localPlayerMana} />
                  )
                ))
              )}
              {!useMockData && [1, 2, 3, 4].filter(slot => !getCardsByZone("reinforcement", currentUserId).some(card => card.slot_index === slot)).map(slot => (
                <CardSlot key={`reinforcement-${slot}`} label="REFORÇO" accent="#8c6820" active={Boolean(selectedHandCard)} onClick={selectedHandCard && isCurrentPlayer ? () => void playCard(selectedHandCard, "reinforcement", slot).then(() => setSelectedHandCard(null)) : undefined} />
              ))}
            </Row>

            {/* Row 3: Life Cards */}
            <div className="text-center">
              <span className="text-[8px] font-serif text-amber-600/40 tracking-widest uppercase">[ DEFESA ]</span>
            </div>
            <Row tight>
              {getLocalPlayerLifeCards().map((life: any, i: number) => (
                <LifeCard 
                  key={i} 
                  label={life.label} 
                  att={life.att} 
                  vida={life.vida} 
                  interactive={false}
                />
              ))}
              {!useMockData && currentTurn > 0 && currentTurn < 4 && [1, 2, 3].filter(slot => !getCardsByZone("life", currentUserId).some(card => card.slot_index === slot)).map(slot => (
                <CardSlot key={slot} label="REPOR VIDA" accent="#dc2626" active={Boolean(selectedHandCard)} onClick={selectedHandCard ? () => void replaceEarlyLifeCard(selectedHandCard, slot).then(() => setSelectedHandCard(null)) : undefined} />
              ))}
            </Row>
          </div>
        </div>

        {/* ============ RIGHT COLUMN ============ */}
        <div className="flex flex-col justify-between h-full py-2 gap-2">
          {/* Top-Right: Opponent Deck */}
          <Deck current={33} max={40} isOpponent={true} />

          {/* Spacer */}
          <div className="flex-1" />

          {/* Bottom-Right: Player Deck */}
          <Deck current={34} max={40} isOpponent={false} />
        </div>
      </div>

      {/* ============ BOTTOM OVERLAY: PLAYER HAND ============ */}
      <div className="pointer-events-none fixed bottom-1 left-1/2 -translate-x-1/2 z-50 flex justify-center">
        <div className="pointer-events-auto flex items-end gap-1">
          {getLocalPlayerHand().map((card: any, i: number) => {
            const mid = (getLocalPlayerHand().length - 1) / 2
            const offset = i - mid
            return (
              <motion.div
                key={card.id || i}
                onClick={() => !useMockData && setSelectedHandCard(card.id)}
                className={`w-16 origin-bottom ${selectedHandCard === card.id ? "ring-2 ring-gold rounded-lg" : ""}`}
                style={{
                  rotate: offset * 4,
                  y: Math.abs(offset) * 4,
                  zIndex: 10 + i,
                }}
                whileHover={{ 
                  scale: 1.25, 
                  y: -24, 
                  zIndex: 60, 
                  rotate: 0 
                }}
                transition={{ type: "spring", stiffness: 300, damping: 22 }}
              >
                <GameCard card={card} interactive={true} playerMana={localPlayerMana} />
              </motion.div>
            )
          })}
        </div>
      </div>

      <AnimatePresence>{cemeteryOpen && <CemeteryModal cards={getCardsByZone("graveyard")} onClose={() => setCemeteryOpen(false)} />}</AnimatePresence>

      <button onClick={() => void surrenderMatch()} disabled={!matchState || matchState.status === "finished"} className="fixed bottom-3 right-3 z-[70] flex items-center gap-1 rounded border border-red-700 bg-black/80 px-3 py-2 text-[10px] font-bold uppercase text-red-300 disabled:opacity-40"><Flag size={13} /> Declarar derrota</button>

      <AnimatePresence>{pendingAttack && pendingAttack.defender_user_id === currentUserId && <ReactionModal attack={pendingAttack} reactionCards={reactionCards} mana={localPlayerMana} reactionUsed={reactionUsed} onActivate={activateMatchEffect} onDecline={declineAttackReaction} />}</AnimatePresence>

      <AnimatePresence>{matchState?.status === "finished" && <motion.div initial={{ opacity: 0 }} animate={{ opacity: 1 }} className="fixed inset-0 z-[190] flex items-center justify-center bg-black/85"><div className="rounded-xl border-2 border-gold bg-stone-950 p-8 text-center shadow-[0_0_50px_rgba(212,175,55,.4)]"><Crown className="mx-auto mb-3 text-gold" size={42} /><h2 className="font-serif text-2xl font-black uppercase text-gold">{matchState.winner_id === currentUserId ? "Vitória" : "Derrota"}</h2><p className="mt-2 text-sm text-stone-300">A partida foi encerrada pelo servidor.</p><button onClick={() => { window.history.replaceState({}, "", "/"); window.location.reload() }} className="mt-5 rounded bg-gold px-5 py-2 font-bold text-stone-950">Voltar ao Hub</button></div></motion.div>}</AnimatePresence>
      
      {/* Ban Phase Modal */}
      <AnimatePresence>
        {banPhaseOpen && (
          <motion.div
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
            exit={{ opacity: 0 }}
            className="fixed inset-0 z-[100] flex items-center justify-center bg-black/80 backdrop-blur-sm"
          >
            <motion.div
              initial={{ scale: 0.9, y: 20 }}
              animate={{ scale: 1, y: 0 }}
              exit={{ scale: 0.9, y: 20 }}
              className="relative max-w-2xl w-full mx-4 rounded-lg border-2 border-gold/50 bg-wood-darkest/95 p-6 shadow-[0_0_40px_rgba(212,175,55,0.3)]"
            >
              <h2 className="mb-4 font-serif text-xl font-bold uppercase tracking-wider text-gold text-shadow-gold text-center">
                Fase de Banimento
              </h2>
              <p className="mb-6 text-center font-serif text-sm text-rune-amber">
                Selecione uma carta lendária/dourada do oponente para banir
              </p>
              
              <div className="grid grid-cols-4 gap-4 mb-6">
                {banCandidates.map((card: any) => (
                  <motion.button
                    key={card.card_id}
                    whileHover={{ scale: 1.05 }}
                    whileTap={{ scale: 0.95 }}
                    onClick={async () => {
                      try {
                        await submitBan(card.card_id)
                        setBanPhaseOpen(false)
                        setBanCandidates([])
                      } catch (error) {
                        console.error('Erro ao banir carta:', error)
                      }
                    }}
                    className="relative aspect-[2.5/3.5] rounded-md border-2 border-gold/30 bg-stone-900/50 p-2 hover:border-gold hover:shadow-[0_0_20px_rgba(212,175,55,0.4)] transition-all"
                  >
                    <div className="h-full flex flex-col items-center justify-center">
                      <p className="text-[10px] font-serif text-center text-gold leading-tight">
                        {card.name}
                      </p>
                      <p className="text-[8px] font-serif text-center text-rune-amber mt-1">
                        {card.rarity}
                      </p>
                    </div>
                  </motion.button>
                ))}
              </div>

              {matchState?.status === 'ban_phase' && !isCurrentPlayer && (
                <div className="text-center">
                  <p className="font-serif text-sm text-rune-amber animate-pulse">
                    Aguardando oponente banir...
                  </p>
                </div>
              )}
            </motion.div>
          </motion.div>
        )}
      </AnimatePresence>
    </div>
  )
}
