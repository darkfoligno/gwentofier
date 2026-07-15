"use client"

import { motion } from "framer-motion"
import { Flame, Snowflake, Sparkles, Leaf, Moon, Sword, Shield, Droplets, Zap } from "lucide-react"
import { type GameCard as GameCardType, raridadeCor, raridadeLabel } from "@/lib/game-data"
import { cn } from "@/lib/utils"

const elementIcons = {
  fogo: Flame,
  gelo: Snowflake,
  arcano: Sparkles,
  natureza: Leaf,
  sombra: Moon,
}

const elementColor = {
  fogo: "#ff7a33",
  gelo: "#66d9ff",
  arcano: "#c084fc",
  natureza: "#66dd88",
  sombra: "#b28ce8",
}

export function GameCard({
  card,
  interactive = false,
  className,
  isFaceDown = false,
  playerMana = 0,
}: {
  card: GameCardType
  interactive?: boolean
  className?: string
  isFaceDown?: boolean
  playerMana?: number
}) {
  const ElementIcon = elementIcons[card.elemento]
  const rarColor = raridadeCor[card.raridade]
  const isSpell = card.tipo.startsWith("Feitiço")
  const canActivate = playerMana >= card.mana

  if (isFaceDown) {
    return (
      <motion.div
        className={cn("group relative", className)}
        whileHover={interactive ? { scale: 1.05 } : undefined}
        transition={{ type: "spring", stiffness: 300, damping: 22 }}
      >
        <div className="relative flex aspect-[2.5/3.5] w-full flex-col overflow-hidden rounded-lg shadow-xl border-2 border-amber-600/60 egyptian-card-back">
          <div className="absolute inset-0 flex items-center justify-center">
            <div className="relative">
              {/* Egyptian scarab pattern */}
              <div className="flex h-16 w-16 items-center justify-center rounded-full border-2 border-gold/40 bg-stone-900/80">
                <div className="h-8 w-8 rounded-full bg-gradient-to-br from-gold to-amber-700 sun-glow" />
              </div>
              {/* Geometric patterns */}
              <div className="absolute -top-6 -left-6 h-4 w-4 border border-gold/30 rotate-45" />
              <div className="absolute -top-6 -right-6 h-4 w-4 border border-gold/30 rotate-45" />
              <div className="absolute -bottom-6 -left-6 h-4 w-4 border border-gold/30 rotate-45" />
              <div className="absolute -bottom-6 -right-6 h-4 w-4 border border-gold/30 rotate-45" />
            </div>
          </div>
          {/* Hieroglyphic-like symbols */}
          <div className="absolute top-2 left-2 text-gold/20 text-[8px]">𓂀</div>
          <div className="absolute top-2 right-2 text-gold/20 text-[8px]">𓃭</div>
          <div className="absolute bottom-2 left-2 text-gold/20 text-[8px]">𓆣</div>
          <div className="absolute bottom-2 right-2 text-gold/20 text-[8px]">𓋹</div>
        </div>
      </motion.div>
    )
  }

  return (
    <motion.div
      className={cn("group relative", className)}
      whileHover={
        interactive
          ? { scale: 1.15, y: -10, zIndex: 50, rotate: 0 }
          : undefined
      }
      transition={{ type: "spring", stiffness: 300, damping: 22 }}
    >
      <div
        className="relative flex aspect-[2.5/3.5] w-full flex-col overflow-hidden rounded-lg shadow-xl border-2 border-amber-600/60 bg-stone-900"
        style={{
          background: `linear-gradient(150deg, ${rarColor}33, #1c1917 60%, ${rarColor}22)`,
          boxShadow:
            card.raridade === "legendary" || card.raridade === "collab"
              ? `0 0 20px ${rarColor}66, 0 8px 24px rgba(0,0,0,0.8)`
              : "0 8px 24px rgba(0,0,0,0.8)",
        }}
      >
        <div className="relative flex h-full flex-col rounded-[6px] bg-stone-900/95">
          {/* Top Bar: Card Name + Element Icon */}
          <div className="flex items-center justify-between px-2 pt-2 pb-1">
            <div className="flex items-center gap-1.5">
              <p className="font-serif text-xs font-bold leading-tight text-gold truncate max-w-[100px]">
                {card.nome}
              </p>
              <ElementIcon size={14} style={{ color: elementColor[card.elemento] }} />
            </div>
            {/* Top-Left: Mana Cost */}
            <div
              className="flex h-7 w-7 items-center justify-center rounded-full text-[11px] font-bold text-white"
              style={{
                background: "radial-gradient(circle at 30% 30%, #3b82f6, #1e3a8a)",
                boxShadow: "0 0 10px rgba(30, 58, 138, 0.6), inset 0 1px 2px rgba(255,255,255,0.3)",
                border: "2px solid rgba(194, 155, 56, 0.4)",
              }}
            >
              <Droplets size={10} className="mr-0.5" />
              {card.mana}
            </div>
          </div>

          {/* Center Area: Artwork (50-60% of card) */}
          <div className="relative mx-2 mt-1 flex-[3] overflow-hidden rounded-sm border border-gold/30">
            <div
              className="absolute inset-0"
              style={{
                background: `radial-gradient(circle at 50% 30%, ${elementColor[card.elemento]}44, transparent 70%), linear-gradient(160deg, #292524, #0c0a09)`,
              }}
            />
            <div className="absolute inset-0 flex items-center justify-center">
              <ElementIcon
                size={64}
                style={{ color: elementColor[card.elemento], opacity: 0.6 }}
              />
            </div>
            {/* Rarity foil sheen */}
            <div className="absolute inset-0 bg-gradient-to-tr from-transparent via-white/8 to-transparent opacity-0 transition-opacity duration-300 group-hover:opacity-100" />
          </div>

          {/* Visual Divider */}
          <div className="mx-2 my-1 h-[1px]" style={{ background: `linear-gradient(90deg, transparent, ${rarColor}66, transparent)` }} />

          {/* Bottom Section: Effect Text */}
          <div className="mx-2 mb-1 flex-1">
            <p className="text-[9px] leading-snug text-muted-foreground line-clamp-2">
              {card.efeito}
            </p>
          </div>

          {/* Bottom Action Button */}
          <div className="px-2 pb-2">
            <motion.button
              className={`w-full rounded-md px-2 py-1 text-[9px] font-bold uppercase tracking-wide transition-all ${
                canActivate
                  ? "bg-gradient-to-r from-amber-500 to-amber-600 text-stone-900 shadow-[0_0_12px_rgba(245,158,11,0.5)]"
                  : "bg-stone-800 text-stone-500 cursor-not-allowed"
              }`}
              whileHover={canActivate ? { scale: 1.05 } : {}}
              whileTap={canActivate ? { scale: 0.95 } : {}}
              disabled={!canActivate}
            >
              <div className="flex items-center justify-center gap-1">
                <Zap size={10} />
                {canActivate ? "ATIVAR" : "SEM MANA"}
              </div>
            </motion.button>
          </div>
        </div>
      </div>

      {/* hover tooltip with effect */}
      {interactive && (
        <div className="pointer-events-none absolute -top-2 left-1/2 z-50 w-52 -translate-x-1/2 -translate-y-full rounded-lg border border-gold/40 bg-stone-950/95 p-3 opacity-0 shadow-[0_12px_36px_rgba(0,0,0,0.9)] backdrop-blur-md transition-opacity duration-200 group-hover:opacity-100">
          <p className="font-serif text-sm font-bold text-gold">{card.nome}</p>
          <p className="mb-1 text-[10px] uppercase tracking-wide" style={{ color: rarColor }}>
            {raridadeLabel[card.raridade]} · {card.tipo}
          </p>
          <p className="text-xs leading-snug text-muted-foreground">{card.efeito}</p>
        </div>
      )}
    </motion.div>
  )
}
