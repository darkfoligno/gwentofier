"use client"

import { useEffect, useMemo, useRef, useState } from "react"
import { motion } from "framer-motion"
import { ShieldAlert, Swords, Timer, Zap } from "lucide-react"
import type { PendingAttack, VisibleMatchCard } from "@/lib/types"
import { GameCard } from "./game-card"

interface ReactionModalProps {
  attack: PendingAttack
  attackerCards: VisibleMatchCard[]
  defenses: VisibleMatchCard[]
  reactionCards: VisibleMatchCard[]
  mana: number
  reactionUsed: boolean
  onActivate: (cardId: string) => Promise<unknown>
  onDecline: () => Promise<unknown>
}

export function ReactionModal({ attack, attackerCards, defenses, reactionCards, mana, reactionUsed, onActivate, onDecline }: ReactionModalProps) {
  const deadline = useMemo(() => attack.reaction_deadline ? new Date(attack.reaction_deadline).getTime() : new Date(attack.created_at).getTime()+30_000,[attack.created_at,attack.reaction_deadline])
  const [seconds,setSeconds]=useState(()=>Math.max(0,Math.ceil((deadline-Date.now())/1000)))
  const [busy,setBusy]=useState(false)
  const declined=useRef(false)
  const simulation=useMemo(()=>{
    let remaining=attack.declared_power
    return [...defenses].sort((a,b)=>a.slot_index-b.slot_index).map((card,index)=>{
      const before=Math.max(0,card.current_life??0);const incoming=Math.max(0,remaining);const damage=Math.min(incoming,before)
      remaining=Math.max(0,incoming-before)
      return {card,index,before,incoming,damage,remaining,destroyed:incoming>=before&&before>0,untouched:incoming<=0,after:Math.max(0,before-incoming)}
    })
  },[attack.declared_power,defenses])

  useEffect(()=>{const tick=()=>setSeconds(Math.max(0,Math.ceil((deadline-Date.now())/1000)));tick();const timer=window.setInterval(tick,250);return()=>window.clearInterval(timer)},[deadline])
  useEffect(()=>{if(seconds!==0||declined.current)return;declined.current=true;setBusy(true);void onDecline().finally(()=>setBusy(false))},[onDecline,seconds])
  const react=async(cardId:string)=>{if(busy||reactionUsed)return;setBusy(true);try{await onActivate(cardId)}finally{setBusy(false)}}
  const decline=async()=>{if(declined.current||busy)return;declined.current=true;setBusy(true);try{await onDecline()}finally{setBusy(false)}}

  return <motion.div initial={{opacity:0}} animate={{opacity:1}} exit={{opacity:0}} className="fixed inset-0 z-[180] overflow-y-auto bg-[radial-gradient(circle_at_top,rgba(127,29,29,.9),rgba(0,0,0,.98)_60%)] p-4 backdrop-blur-lg">
    <div className="mx-auto flex min-h-full w-full max-w-[1500px] flex-col justify-center py-4">
      <header className="mb-4 flex items-center justify-between rounded-2xl border-2 border-red-400/70 bg-black/80 p-4 shadow-[0_0_60px_rgba(239,68,68,.35)]"><h2 className="flex items-center gap-2 font-serif text-xl font-black uppercase text-red-100"><ShieldAlert/> Ataque recebido · escolha sua resposta</h2><div className="flex items-center gap-2 rounded-full border-2 border-red-300 bg-red-950 px-5 py-2 font-mono text-2xl font-black text-red-100"><Timer size={20}/>{seconds}s</div></header>
      <div className="grid gap-4 xl:grid-cols-[.8fr_1.2fr_1fr]">
        <section className="rounded-2xl border border-red-500/60 bg-stone-950/90 p-4"><h3 className="mb-4 text-center font-serif text-lg font-black uppercase text-red-200">1 · A ameaça</h3><div className="flex flex-wrap justify-center gap-3">{attackerCards.map(card=><div key={card.id} className="relative aspect-[2/3] w-28"><GameCard card={card.card_data??undefined} enableZoom/><span className="absolute -bottom-2 left-1/2 -translate-x-1/2 rounded-full border-2 border-red-200 bg-red-800 px-3 py-1 text-sm font-black text-white shadow-[0_0_16px_#ef4444]">⚔ {card.current_power??0}</span></div>)}</div><div className="mx-auto mt-7 flex w-fit items-center gap-3 rounded-xl border-2 border-red-300 bg-red-950 px-5 py-3"><Swords size={28}/><strong className="font-serif text-2xl text-red-50">PODER TOTAL: {attack.declared_power}</strong></div></section>
        <section className="rounded-2xl border border-amber-500/60 bg-stone-950/90 p-4"><h3 className="mb-4 text-center font-serif text-lg font-black uppercase text-amber-200">2 · Linha de colisão</h3><div className="flex flex-wrap items-start justify-center gap-4">{simulation.map(step=>{const percentage=step.before>0?Math.max(0,Math.min(100,step.after/step.before*100)):0;return <motion.article initial={{y:18,opacity:0}} animate={{y:0,opacity:1}} transition={{delay:step.index*.1}} key={step.card.id} className={`w-32 rounded-xl border p-2 ${step.destroyed?"border-red-500 bg-red-950/35":step.untouched?"border-stone-700 bg-stone-900/60":"border-emerald-400 bg-emerald-950/30"}`}><div className="relative aspect-[2/3] w-full"><GameCard card={step.card.card_data??undefined}/><span className="absolute left-1 top-1 rounded bg-black/90 px-2 py-1 text-[10px] font-black text-white">#{step.index+1}</span></div><div className="mt-3 h-3 overflow-hidden rounded-full border border-red-300/60 bg-red-950"><motion.div initial={{width:"100%"}} animate={{width:`${percentage}%`}} transition={{duration:.7}} className={`h-full ${step.destroyed?"bg-red-600":"bg-emerald-500"}`}/></div><p className="mt-1 text-center text-[10px] font-black text-stone-100">{step.untouched?`${step.before} HP · INTACTA`:`${step.before} → ${step.after} HP`}</p></motion.article>})}{!simulation.length&&<div className="rounded-xl border border-red-500 bg-red-950/40 p-8 text-center font-black text-red-100">LINHA DE DEFESA VAZIA</div>}</div></section>
        <section className="rounded-2xl border border-cyan-500/60 bg-stone-950/90 p-4"><h3 className="flex items-center justify-center gap-2 font-serif text-lg font-black uppercase text-cyan-200"><Zap/> 3 · Acionamento</h3><p className="mt-1 text-center text-xs text-stone-400">Mana disponível: {mana}</p><div className="mt-4 space-y-3">{reactionCards.map(card=>{const effect=card.card_data?.effect_definition?.find(item=>["reaction","on_reaction","on_attacked"].includes(item.trigger_type??"")||item.is_reaction);const cost=Number(effect?.parameters?.mana_cost??card.card_data?.mana??0);return <article key={card.id} className="grid grid-cols-[72px_1fr] gap-3 rounded-xl border border-cyan-400/50 bg-blue-950/45 p-3"><div className="aspect-[2/3] w-[72px]"><GameCard card={card.card_data??undefined}/></div><div><b className="text-sm text-cyan-100">{card.card_data?.nome}</b><p className="mt-1 text-[11px] leading-relaxed text-stone-300">{card.card_data?.efeito||effect?.description||"Reação defensiva"}</p><button disabled={busy||reactionUsed||mana<cost} onClick={()=>void react(card.id)} className="mt-3 w-full rounded-lg border-2 border-yellow-200 bg-gradient-to-r from-amber-900 via-yellow-600 to-amber-900 px-2 py-3 text-[10px] font-black uppercase text-yellow-50 shadow-[0_0_20px_rgba(250,204,21,.65)] transition hover:scale-[1.02] hover:brightness-125 disabled:border-stone-600 disabled:bg-stone-800 disabled:opacity-35">⚡ Ativar efeito de {card.card_data?.nome} (Custo: {cost} Mana)</button></div></article>})}</div>{!reactionCards.length&&<p className="mt-5 rounded-lg border border-stone-600 bg-black/60 p-5 text-center text-sm font-bold text-stone-300">Nenhuma reação válida disponível</p>}<button disabled={busy} onClick={()=>void decline()} className="mt-5 w-full rounded-lg border-2 border-red-400 bg-gradient-to-r from-red-950 via-red-800 to-red-950 px-4 py-4 font-serif font-black uppercase text-red-50 disabled:opacity-50">{busy?"RESOLVENDO NO SERVIDOR…":"ACEITAR IMPACTO"}</button></section>
      </div>
    </div>
  </motion.div>
}
