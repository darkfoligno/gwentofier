"use client"

import { useEffect, useMemo, useRef, useState } from "react"
import { motion } from "framer-motion"
import { ShieldAlert, Timer } from "lucide-react"
import type { PendingAttack, VisibleMatchCard } from "@/lib/types"

interface ReactionModalProps {
  attack: PendingAttack
  reactionCards: VisibleMatchCard[]
  mana: number
  reactionUsed: boolean
  onActivate: (cardId: string) => Promise<unknown>
  onDecline: () => Promise<unknown>
}

export function ReactionModal({ attack, reactionCards, mana, reactionUsed, onActivate, onDecline }: ReactionModalProps) {
  const deadline = useMemo(() => {
    if (attack.reaction_deadline) return new Date(attack.reaction_deadline).getTime()
    return new Date(attack.created_at).getTime() + 20_000
  }, [attack.created_at, attack.reaction_deadline])
  const [seconds, setSeconds] = useState(() => Math.max(0, Math.ceil((deadline - Date.now()) / 1000)))
  const [busy, setBusy] = useState(false)
  const declined = useRef(false)

  useEffect(() => {
    const tick = () => setSeconds(Math.max(0, Math.ceil((deadline - Date.now()) / 1000)))
    tick()
    const timer = window.setInterval(tick, 250)
    return () => window.clearInterval(timer)
  }, [deadline])

  useEffect(() => {
    if (seconds !== 0 || declined.current) return
    declined.current = true
    setBusy(true)
    void onDecline().finally(() => setBusy(false))
  }, [onDecline, seconds])

  const react = async (cardId: string) => {
    setBusy(true)
    try { await onActivate(cardId) } finally { setBusy(false) }
  }

  const decline = async () => {
    if (declined.current) return
    declined.current = true
    setBusy(true)
    try { await onDecline() } finally { setBusy(false) }
  }

  return (
    <motion.div initial={{ opacity: 0 }} animate={{ opacity: 1 }} exit={{ opacity: 0 }} className="fixed inset-0 z-[180] flex items-center justify-center bg-red-950/70 p-4 backdrop-blur-md">
      <motion.section initial={{ scale: .9, y: 24 }} animate={{ scale: 1, y: 0 }} className="w-full max-w-2xl rounded-xl border-2 border-red-500 bg-stone-950 p-6 shadow-[0_0_60px_rgba(239,68,68,.45)]">
        <div className="mb-4 flex items-center justify-between">
          <h2 className="flex items-center gap-2 font-serif text-xl font-black uppercase text-red-300"><ShieldAlert /> Janela de reação</h2>
          <div className="flex items-center gap-2 rounded-full border border-red-400 px-3 py-1 font-mono text-xl font-black text-red-300"><Timer size={18} /> {seconds}s</div>
        </div>
        <p className="mb-4 text-sm text-stone-300">Um ataque foi declarado. Ative um efeito válido ou aceite o dano antes que o tempo termine.</p>
        <p className="mb-4 text-xs text-amber-300">Poder declarado pelo servidor: {attack.declared_power}</p>
        <div className="mb-6 grid grid-cols-2 gap-2 sm:grid-cols-4">
          {reactionCards.map(card => {
            const cost = card.card_data?.mana ?? Number.POSITIVE_INFINITY
            const disabled = busy || reactionUsed || mana < cost
            return <button key={card.id} disabled={disabled} onClick={() => void react(card.card_id)} className="rounded-lg border border-gold/40 bg-stone-900 p-3 text-left disabled:opacity-40">
              <span className="block font-serif text-sm font-bold text-gold">{card.card_data?.nome ?? "Efeito"}</span>
              <span className="text-xs text-blue-300">{cost} mana</span>
            </button>
          })}
        </div>
        <button disabled={busy} onClick={() => void decline()} className="w-full rounded-md border border-red-400 bg-red-900/50 px-4 py-3 font-serif font-black uppercase text-red-100 disabled:opacity-50">Aceitar dano / Sem reação</button>
      </motion.section>
    </motion.div>
  )
}
