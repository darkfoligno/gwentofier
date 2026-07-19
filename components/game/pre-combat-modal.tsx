"use client"

import { motion } from "framer-motion"
import { FastForward, Sparkles } from "lucide-react"
import type { VisibleMatchCard } from "@/lib/types"
import { GameCard } from "./game-card"

export function PreCombatModal({ cards, mana, busy, onActivate, onContinue, onClose }: {
  cards: VisibleMatchCard[]
  mana: number
  busy: boolean
  onActivate: (card: VisibleMatchCard) => void
  onContinue: () => void
  onClose: () => void
}) {
  return <motion.div initial={{opacity:0}} animate={{opacity:1}} exit={{opacity:0}} className="fixed inset-0 z-[178] flex items-center justify-center bg-black/90 p-5 backdrop-blur-md">
    <motion.section initial={{scale:.88,y:30}} animate={{scale:1,y:0}} className="w-full max-w-6xl rounded-2xl border-2 border-purple-300 bg-[radial-gradient(circle_at_top,#3b0764,#09090b_65%)] p-6 shadow-[0_0_70px_rgba(192,132,252,.45)]">
      <Sparkles className="mx-auto text-purple-200" size={38}/><h2 className="mt-2 text-center font-serif text-2xl font-black uppercase text-purple-50">🔮 Cadeia Tática Pré-Combate</h2>
      <p className="mx-auto mt-2 max-w-3xl text-center text-sm text-purple-200">Deseja ativar algum efeito de campo antes de submeter seu exército à Janela de Reação do oponente?</p>
      <p className="mt-2 text-center text-xs font-bold text-cyan-200">Mana disponível: {mana}</p>
      <div className="my-6 flex min-h-48 items-start gap-4 overflow-x-auto rounded-xl border border-purple-400/30 bg-black/45 p-4">
        {cards.map(card=>{const effect=card.card_data?.effect_definition?.find(item=>item.trigger_type==="manual"&&!item.is_reaction);const cost=Number(effect?.parameters?.mana_cost??card.card_data?.mana??0);return <button key={card.id} disabled={busy||cost>mana} onClick={()=>onActivate(card)} className="w-32 shrink-0 rounded-xl border border-purple-300/50 bg-purple-950/45 p-2 transition hover:-translate-y-2 hover:border-yellow-200 disabled:opacity-35"><div className="aspect-[2/3] w-full"><GameCard card={card.card_data??undefined} enableZoom={false}/></div><b className="mt-2 block text-[10px] text-purple-100">{card.card_data?.nome}</b><span className="text-[9px] font-black text-cyan-200">⚡ Custo {cost}</span></button>})}
        {!cards.length&&<div className="m-auto text-center text-sm text-stone-400">Nenhum efeito de turno ainda disponível. Você pode seguir com segurança para o combate.</div>}
      </div>
      <div className="grid gap-3 sm:grid-cols-[.35fr_1fr]"><button disabled={busy} onClick={onClose} className="rounded-lg border border-stone-500 bg-stone-900 px-4 py-3 text-xs font-black text-stone-300">VOLTAR AO TABULEIRO</button><button disabled={busy} onClick={onContinue} className="rounded-lg border-2 border-yellow-200 bg-gradient-to-r from-amber-900 via-yellow-600 to-amber-900 px-5 py-4 font-serif text-sm font-black uppercase text-yellow-50 shadow-[0_0_24px_rgba(250,204,21,.5)]"><FastForward className="mr-2 inline" size={18}/> Seguir para o combate (sem mais ações)</button></div>
    </motion.section>
  </motion.div>
}
