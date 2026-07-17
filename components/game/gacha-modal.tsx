"use client"

import { useMemo, useState } from "react"
import { AnimatePresence, motion } from "framer-motion"
import { Sparkles } from "lucide-react"
import { GameCard } from "./game-card"
import type { GameCard as GameCardType } from "@/lib/game-data"

export function GachaModal({ cards, onCollect }: { cards: GameCardType[]; onCollect: () => void }) {
  const [opened, setOpened] = useState(false)
  const [revealed, setRevealed] = useState<Set<number>>(new Set())
  const allRevealed = cards.length > 0 && revealed.size === cards.length
  const particles = useMemo(() => Array.from({ length: 24 }, (_, i) => ({ id: i, x: (i * 37) % 100, delay: (i % 8) * .08 })), [])
  const reveal = (index: number) => setRevealed(previous => new Set(previous).add(index))

  return <motion.div initial={{ opacity: 0 }} animate={{ opacity: 1 }} exit={{ opacity: 0 }} className="fixed inset-0 z-[300] flex flex-col items-center justify-center overflow-hidden bg-black/95 p-5 backdrop-blur-md">
    <div className="absolute inset-0 bg-[radial-gradient(circle_at_center,rgba(245,158,11,.16),transparent_55%)]" />
    {!opened ? <motion.button onClick={() => setOpened(true)} whileHover={{ scale: 1.04 }} whileTap={{ x: [-8, 8, -6, 6, 0], scale: .98 }} className="relative z-10 flex h-72 w-52 flex-col items-center justify-center rounded-xl border-2 border-amber-400 bg-gradient-to-br from-amber-950 via-stone-950 to-yellow-950 shadow-[0_0_70px_rgba(245,158,11,.45)]">
      <div className="absolute inset-3 border border-amber-600/40" /><Sparkles className="mb-5 text-amber-300" size={48} /><div className="flex h-20 w-20 items-center justify-center rounded-full border-4 border-amber-500 bg-red-950 font-serif text-4xl text-amber-200 shadow-[0_0_35px_rgba(245,158,11,.7)]">𓂀</div><span className="mt-7 font-serif text-sm font-black uppercase tracking-[.22em] text-amber-100">Romper o selo</span>
    </motion.button> : <div className="relative z-10 w-full max-w-6xl">
      <motion.div initial={{ scale: 1.8, opacity: 0 }} animate={{ scale: 1, opacity: 1 }} className="grid grid-cols-2 gap-4 md:grid-cols-4 md:gap-6">{cards.map((card, index) => {
        const isRevealed = revealed.has(index)
        const legendary = isRevealed && card.raridade === "legendary"
        const epic = isRevealed && card.raridade === "epic"
        return <motion.button key={`${card.id}-${index}`} onClick={() => reveal(index)} animate={legendary ? { x: [0, -4, 4, -2, 2, 0] } : {}} className={`relative mx-auto aspect-[2/3] w-full max-w-48 [perspective:1000px] ${legendary ? "drop-shadow-[0_0_35px_rgba(245,158,11,.95)]" : epic ? "drop-shadow-[0_0_30px_rgba(168,85,247,.8)]" : ""}`}>
          {legendary && particles.map(p => <motion.span key={p.id} initial={{ opacity: 0, y: 0 }} animate={{ opacity: [0, 1, 0], y: -140 }} transition={{ duration: 1.2, delay: p.delay, repeat: Infinity }} style={{ left: `${p.x}%` }} className="absolute bottom-1/2 z-30 h-1.5 w-1.5 rounded-full bg-amber-300" />)}
          <motion.div className="relative h-full w-full [transform-style:preserve-3d]" animate={{ rotateY: isRevealed ? 180 : 0 }} transition={{ duration: .7, type: "spring" }}><div className="absolute inset-0 [backface-visibility:hidden]"><GameCard isFaceDown /></div><div className="absolute inset-0 [backface-visibility:hidden] [transform:rotateY(180deg)]"><GameCard card={card} /></div></motion.div>
        </motion.button>
      })}</motion.div>
      <button onClick={() => allRevealed ? onCollect() : setRevealed(new Set(cards.map((_, index) => index)))} className="mx-auto mt-8 block rounded-lg border border-amber-400 bg-amber-700 px-8 py-3 font-serif text-sm font-black uppercase tracking-wider text-amber-50 shadow-[0_0_22px_rgba(245,158,11,.4)]">{allRevealed ? "Coletar para o inventário" : "Revelar todas"}</button>
    </div>}
  </motion.div>
}
