"use client"

import { useState } from "react"
import { AnimatePresence, motion } from "framer-motion"
import { createPortal } from "react-dom"
import { Hand, Heart, Sword } from "lucide-react"
import type { GameCard as GameCardType, Rarity } from "@/lib/game-data"
import { cn } from "@/lib/utils"
import { highlightEffectText, parseEffectBadges } from "@/lib/effect-parser"

const rarity: Record<Rarity, string> = {
  common: "border-emerald-500 shadow-emerald-500/25",
  rare: "border-blue-500 shadow-blue-500/30",
  epic: "border-purple-600 shadow-purple-600/40",
  legendary: "border-amber-500 shadow-amber-500/50",
  collab: "border-pink-500 shadow-pink-500/40",
}
const raritySurface: Record<Rarity, string> = {
  common: "bg-gradient-to-b from-emerald-50 via-white to-emerald-100",
  rare: "bg-gradient-to-b from-blue-50 via-white to-blue-100",
  epic: "bg-gradient-to-b from-purple-50 via-white to-purple-100",
  legendary: "bg-gradient-to-b from-amber-50 via-white to-amber-100",
  collab: "bg-gradient-to-b from-pink-50 via-white to-pink-100",
}
const rarityFrame: Record<Rarity, string> = {
  common: "from-emerald-300 via-emerald-950 to-emerald-500",
  rare: "from-blue-300 via-blue-950 to-blue-500",
  epic: "from-purple-300 via-purple-950 to-purple-500",
  legendary: "from-yellow-200 via-amber-900 to-yellow-500",
  collab: "from-pink-300 via-pink-950 to-pink-500",
}
const rarityLine: Record<Rarity, string> = {
  common: "border-emerald-600",
  rare: "border-blue-600",
  epic: "border-purple-600",
  legendary: "border-amber-500",
  collab: "border-pink-600",
}

export function GameCard({ card, interactive = false, className, isFaceDown = false, enableZoom = true }: { card?: GameCardType; interactive?: boolean; className?: string; isFaceDown?: boolean; playerMana?: number; enableZoom?: boolean }) {
  const [artOpen, setArtOpen] = useState(false)
  if (isFaceDown) return <motion.div whileHover={interactive ? { y: -6, scale: 1.04 } : undefined} className={cn("relative aspect-[2/3] w-full overflow-hidden rounded-[10px] border-2 border-amber-700 bg-stone-950 p-1 shadow-2xl", className)}>
    <div className="relative flex h-full items-center justify-center overflow-hidden rounded-md border border-amber-500/50 bg-[radial-gradient(circle_at_center,#713f12_0,#1c1917_46%,#09090b_100%)]">
      <div className="absolute inset-2 border border-amber-600/30" /><div className="absolute h-2/3 w-2/3 rotate-45 border-2 border-amber-500/40" />
      <div className="z-10 flex h-16 w-16 items-center justify-center rounded-full border-2 border-amber-400/60 bg-black/70 shadow-[0_0_25px_rgba(245,158,11,.35)]"><span className="font-serif text-3xl text-amber-300">𓂀</span></div>
    </div>
  </motion.div>

  if (!card) return null
  const badges = parseEffectBadges(card.effect_definition)
  const allowedTypes = ["Bestiário", "M&F", "Witcher", "Elfica", "Cívil", "Civil", "Vampiro"]
  const rawType = allowedTypes.includes(card.tipo) ? card.tipo : card.elemento
  const displayType = rawType === "Cívil" ? "Civil" : rawType
  const nameSize = card.nome.length > 30 ? "text-[5px]" : card.nome.length > 20 ? "text-[6px]" : "text-[clamp(7px,.8vw,11px)]"
  const effectSize = card.efeito.length > 180 ? "text-[5px] leading-[1.05]" : card.efeito.length > 100 ? "text-[6px] leading-tight" : "text-[clamp(6px,.7vw,9px)] leading-snug"
  return <><motion.article whileHover={interactive ? { y: -10, scale: 1.06, zIndex: 60 } : undefined} transition={{ type: "spring", stiffness: 320, damping: 24 }} className={cn("group relative aspect-[2/3] w-full rounded-[11px] border-4 p-[2px] shadow-xl", rarity[card.raridade], className)}>
    <div className={cn("relative h-full overflow-hidden rounded-md bg-gradient-to-b p-1.5 shadow-inner", rarityFrame[card.raridade])}>
      <div className={cn("relative flex h-full flex-col overflow-hidden rounded-md text-slate-900 shadow-[inset_0_0_18px_rgba(120,80,25,.16)]", raritySurface[card.raridade])}>
        <div className={cn("relative z-20 ml-auto mr-2 mt-2 flex h-[12%] w-[76%] min-w-0 items-center justify-center overflow-hidden rounded border bg-white px-1 shadow-sm", rarityLine[card.raridade])}><h3 title={card.nome} className={`${nameSize} w-full break-words text-center font-serif font-black leading-[1.02]`}>{card.nome}</h3></div>
        <div className="absolute left-1 top-1 z-30"><div className="flex h-9 w-9 rotate-45 items-center justify-center border-2 border-amber-400 bg-blue-950 shadow-[0_0_10px_rgba(59,130,246,.6)]"><span className="-rotate-45 text-xs font-black text-blue-100"><Hand size={9} className="mx-auto" />{card.mana}</span></div><span className="mt-1 block rounded-sm bg-black px-1 text-center font-serif text-[6px] text-white">MANA</span></div>
        <div onClick={(event) => { event.stopPropagation(); if (enableZoom) setArtOpen(true) }} className={cn("relative mx-2 mt-1 flex h-[45%] items-center justify-center overflow-hidden border-2 border-double bg-black/90", rarityLine[card.raridade], enableZoom && "cursor-zoom-in")}>
          {card.image_url ? <img src={card.image_url} alt={card.nome} className="block h-full w-full object-contain object-center" /> : <div className="flex h-full items-center justify-center bg-[radial-gradient(circle,#92400e,#1c1917)] font-serif text-2xl text-amber-300/60">𓂀</div>}
          <div className="absolute inset-0 bg-gradient-to-tr from-transparent via-white/10 to-transparent opacity-0 transition-opacity group-hover:opacity-100" />
        </div>
        <div className={cn("relative mx-2 my-1 h-px border-t", rarityLine[card.raridade])}><span className={cn("absolute left-1/2 top-1/2 h-2 w-2 -translate-x-1/2 -translate-y-1/2 rotate-45 border bg-yellow-100", rarityLine[card.raridade])} /></div>
        <div className={cn(`relative mx-2 min-h-0 flex-1 overflow-hidden break-words border border-double bg-white/70 p-1 ${effectSize}`, rarityLine[card.raridade])}><strong>EFEITO: </strong>{highlightEffectText(card.efeito || "")}</div>
        <div className="absolute right-2 top-[52%] z-20 flex gap-1">{badges.slice(0, 3).map(({ code, label, description, Icon, className: badgeClass }) => <span key={code} title={`${label}: ${description}`} className={cn("rounded-full border p-1 shadow-lg", badgeClass)}><Icon size={10} /></span>)}</div>
        <div className="relative mt-1 flex h-[15%] items-end justify-between px-1 pb-1">
          <div className="flex h-9 w-9 flex-col items-center justify-center rounded-full border-2 border-amber-400 bg-gradient-to-br from-stone-800 to-black font-mono text-xs font-black leading-none text-amber-100 shadow-md"><Sword size={10} />{card.ataque}</div>
          <div className={cn("mb-1 max-w-[48%] break-words rounded border bg-white/75 px-2 py-0.5 text-center text-[6px] font-black uppercase leading-tight text-stone-900", rarityLine[card.raridade])}>{displayType}</div>
          <div className="flex h-9 w-9 flex-col items-center justify-center rounded-t-xl rounded-b-md border-2 border-amber-400 bg-gradient-to-br from-red-600 to-red-950 font-mono text-xs font-black leading-none text-white shadow-md"><Heart size={10} fill="currentColor" />{card.vida}</div>
        </div>
      </div>
    </div>
  </motion.article>{typeof document !== "undefined" && createPortal(<AnimatePresence>{artOpen && <motion.div initial={{ opacity: 0 }} animate={{ opacity: 1 }} exit={{ opacity: 0 }} onClick={(event) => { event.stopPropagation(); setArtOpen(false) }} className="fixed inset-0 z-[500] flex cursor-zoom-out items-center justify-center bg-black/90 p-6 backdrop-blur-md"><motion.div initial={{ scale: .75 }} animate={{ scale: 1 }} className="aspect-[2/3] w-[240px] origin-center scale-[1.35] sm:scale-[1.65] lg:scale-[1.9]" onClick={event => event.stopPropagation()}><GameCard card={card} enableZoom={false} /></motion.div></motion.div>}</AnimatePresence>, document.body)}</>
}
