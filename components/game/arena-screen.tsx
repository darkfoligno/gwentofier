"use client"

import { useState, useEffect } from "react"
import { motion, AnimatePresence } from "framer-motion"
import { Crown, Skull, Layers, Hexagon, Coins, X, Hand } from "lucide-react"
import { collection } from "@/lib/game-data"
import { GameCard } from "./game-card"

/* card footprint used across the board */
const CARD_W = "w-16 md:w-20 lg:w-22"
const LIFE_W = "w-18 md:w-22 lg:w-24"

/* ---------- Empty carved slot ---------- */
function CardSlot({ label, accent = "#d4af37" }: { label: string; accent?: string }) {
  return (
    <div
      className={`relative ${CARD_W} flex aspect-[2.5/3.5] items-center justify-center rounded-md border-2 border-dashed`}
      style={{
        borderColor: `${accent}55`,
        background: "rgba(0,0,0,0.45)",
        boxShadow: "inset 0 4px 12px rgba(0,0,0,0.9)",
      }}
    >
      <Hexagon size={24} style={{ color: `${accent}33` }} strokeWidth={1} />
      <span className="absolute bottom-1 left-1/2 -translate-x-1/2 text-[8px] font-serif text-amber-600/40 tracking-widest uppercase">
        {label}
      </span>
    </div>
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

function CemeteryModal({ onClose }: { onClose: () => void }) {
  const dead = collection.slice(0, 8)
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
          {dead.map((c) => (
            <GameCard key={c.id} card={c} />
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
  const [currentTurn, setCurrentTurn] = useState(0)
  const [sandParticles, setSandParticles] = useState<Array<{
    id: number
    x: number
    y: number
    size: number
    duration: number
    delay: number
  }>>([])
  const [isMounted, setIsMounted] = useState(false)

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
  
  // Local Player State
  const [localPlayer, setLocalPlayer] = useState<PlayerState>({
    name: "Cavaleiro de Velen",
    rank: "#8 Guardião Real",
    mana: 6,
    maxMana: 10,
    hand: collection.slice(0, 6),
    lifeCards: [
      { label: "Defesa 1 [Frente]", att: 4500, vida: 8000 },
      { label: "Defesa 2", att: 3800, vida: 9500 },
      { label: "Defesa 3 [Base]", att: 3000, vida: 12000 },
    ],
    reinforcements: [
      { cardIndex: 1, isFaceDown: true, isFlipped: flippedCards.has(3) },
      { cardIndex: null, isFaceDown: true, isFlipped: false },
      { cardIndex: null, isFaceDown: true, isFlipped: false },
      { cardIndex: null, isFaceDown: true, isFlipped: false },
    ],
    attackers: [
      { cardIndex: 0 },
      { cardIndex: null },
      { cardIndex: 4 },
      { cardIndex: null },
    ],
    deckCount: 34,
    maxDeck: 40,
  })

  // Opponent State
  const [opponent, setOpponent] = useState<PlayerState>({
    name: "Bruxo de Yggdrasil",
    rank: "#12 Mestre de Ofieri",
    mana: 7,
    maxMana: 10,
    hand: collection.slice(6, 13), // Hidden from view
    lifeCards: [
      { label: "Defesa 1", att: 5000, vida: 6000 },
      { label: "Defesa 2", att: 4200, vida: 7500 },
      { label: "Defesa 3", att: 3000, vida: 9000 },
    ],
    reinforcements: [
      { cardIndex: 0, isFaceDown: true, isFlipped: flippedCards.has(0) },
      { cardIndex: 1, isFaceDown: true, isFlipped: flippedCards.has(1) },
      { cardIndex: 2, isFaceDown: true, isFlipped: flippedCards.has(2) },
      { cardIndex: null, isFaceDown: true, isFlipped: false },
    ],
    attackers: [
      { cardIndex: 3 },
      { cardIndex: 9 },
      { cardIndex: null },
      { cardIndex: null },
    ],
    deckCount: 33,
    maxDeck: 40,
  })

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

  return (
    <div
      className="relative w-full h-screen overflow-hidden flex flex-col justify-between bg-stone-950 sandstone-texture select-none"
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
      {/* Main 3-Column Grid Layout */}
      <div className="grid grid-cols-[minmax(160px,200px)_1fr_minmax(160px,200px)] w-full flex-1 max-w-[1800px] mx-auto px-3 py-1 gap-3 items-center overflow-hidden">
        
        {/* ============ LEFT COLUMN ============ */}
        <div className="flex flex-col justify-between h-full py-2 gap-2">
          {/* Top-Left: Opponent Profile */}
          <ProfileBanner
            name={opponent.name}
            rank={opponent.rank}
            mana={opponent.maxMana}
            hand={opponent.hand.length}
            isPlayer={false}
          />

          {/* Center-Left: Graveyard */}
          <div className="flex-1 flex items-center justify-center">
            <Graveyard count={12} onClick={() => setCemeteryOpen(true)} />
          </div>

          {/* Bottom-Left: Player Profile & Leader */}
          <ProfileBanner
            name={localPlayer.name}
            rank={localPlayer.rank}
            mana={localPlayer.maxMana}
            hand={localPlayer.hand.length}
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
              {opponent.lifeCards.map((life, i) => (
                <LifeCard key={i} label={life.label} att={life.att} vida={life.vida} interactive={false} />
              ))}
            </Row>

            {/* Row 2: Reinforcements */}
            <div className="text-center">
              <span className="text-[8px] font-serif text-amber-600/40 tracking-widest uppercase">[ REFORÇO ]</span>
            </div>
            <Row tight>
              {opponent.reinforcements.map((reinforcement, i) => 
                reinforcement.cardIndex !== null ? (
                  <FaceDownCard 
                    key={i} 
                    isFlipped={flippedCards.has(i)} 
                    onFlip={() => toggleFlip(i)} 
                  />
                ) : (
                  <CardSlot key={i} label="REFORÇO" accent="#8c6820" />
                )
              )}
            </Row>

            {/* Row 3: Attackers */}
            <div className="text-center">
              <span className="text-[8px] font-serif text-amber-600/40 tracking-widest uppercase">[ ATAQUE ]</span>
            </div>
            <Row tight>
              {opponent.attackers.map((attacker, i) => 
                attacker.cardIndex !== null ? (
                  <BoardCard key={i} index={attacker.cardIndex} playerMana={opponent.mana} />
                ) : (
                  <CardSlot key={i} label="ATAQUE" accent="#dc2626" />
                )
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

              <motion.button
                whileHover={{ scale: 1.05 }}
                whileTap={{ scale: 0.95, rotate: -2 }}
                className="gold-trim rounded-md px-4 py-1 font-serif text-xs font-black uppercase tracking-wide text-wood-darkest shadow-[0_4px_12px_rgba(0,0,0,0.7),inset_0_1px_2px_rgba(255,255,255,0.5)] border-2 border-gold-dark/50"
              >
                PASSAR TURNO
              </motion.button>
            </div>
          </div>

          {/* PLAYER ZONE */}
          <div className="flex flex-col gap-1">
            {/* Row 1: Attackers */}
            <div className="text-center">
              <span className="text-[8px] font-serif text-amber-600/40 tracking-widest uppercase">[ ATAQUE ]</span>
            </div>
            <Row tight>
              {localPlayer.attackers.map((attacker, i) => 
                attacker.cardIndex !== null ? (
                  <BoardCard key={i} index={attacker.cardIndex} playerMana={localPlayer.mana} />
                ) : (
                  <CardSlot key={i} label="ATAQUE" />
                )
              )}
            </Row>

            {/* Row 2: Reinforcements */}
            <div className="text-center">
              <span className="text-[8px] font-serif text-amber-600/40 tracking-widest uppercase">[ REFORÇO ]</span>
            </div>
            <Row tight>
              {localPlayer.reinforcements.map((reinforcement, i) => 
                reinforcement.cardIndex !== null ? (
                  <FaceDownCard 
                    key={i} 
                    isFlipped={flippedCards.has(i + 3)} 
                    onFlip={() => toggleFlip(i + 3)} 
                  />
                ) : (
                  <CardSlot key={i} label="REFORÇO" accent="#8c6820" />
                )
              )}
            </Row>

            {/* Row 3: Life Cards */}
            <div className="text-center">
              <span className="text-[8px] font-serif text-amber-600/40 tracking-widest uppercase">[ DEFESA ]</span>
            </div>
            <Row tight>
              {localPlayer.lifeCards.map((life, i) => (
                <LifeCard 
                  key={i} 
                  label={life.label} 
                  att={life.att} 
                  vida={life.vida} 
                  interactive={true}
                  onClick={() => {
                    if (localPlayer.mana >= 2) {
                      console.log(`Defesa ativada: ${life.label}`)
                    }
                  }}
                />
              ))}
            </Row>
          </div>
        </div>

        {/* ============ RIGHT COLUMN ============ */}
        <div className="flex flex-col justify-between h-full py-2 gap-2">
          {/* Top-Right: Opponent Deck */}
          <Deck current={opponent.deckCount} max={opponent.maxDeck} isOpponent={true} />

          {/* Spacer */}
          <div className="flex-1" />

          {/* Bottom-Right: Player Deck */}
          <Deck current={localPlayer.deckCount} max={localPlayer.maxDeck} isOpponent={false} />
        </div>
      </div>

      {/* ============ BOTTOM OVERLAY: PLAYER HAND ============ */}
      <div className="pointer-events-none fixed bottom-1 left-1/2 -translate-x-1/2 z-50 flex justify-center">
        <div className="pointer-events-auto flex items-end gap-1">
          {localPlayer.hand.map((card, i) => {
            const mid = (localPlayer.hand.length - 1) / 2
            const offset = i - mid
            return (
              <motion.div
                key={card.id}
                className="w-16 origin-bottom"
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
                <GameCard card={card} interactive={true} playerMana={localPlayer.mana} />
              </motion.div>
            )
          })}
        </div>
      </div>

      <AnimatePresence>{cemeteryOpen && <CemeteryModal onClose={() => setCemeteryOpen(false)} />}</AnimatePresence>
    </div>
  )
}
