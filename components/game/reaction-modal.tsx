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
  const deadline = useMemo(() => attack.reaction_deadline ? new Date(attack.reaction_deadline).getTime() : new Date(attack.created_at).getTime()+20_000,[attack.created_at,attack.reaction_deadline])
  const [seconds,setSeconds]=useState(()=>Math.max(0,Math.ceil((deadline-Date.now())/1000)))
  const [busy,setBusy]=useState(false)
  const declined=useRef(false)
  const simulation=useMemo(()=>{
    let remaining=attack.declared_power
    return [...defenses].sort((a,b)=>a.slot_index-b.slot_index).map((card,index)=>{
      const before=Math.max(0,card.current_life??0);const incoming=Math.max(0,remaining);const damage=Math.min(incoming,before)
      remaining=Math.max(0,incoming-before)
      return {card,index,incoming,damage,remaining,destroyed:incoming>=before&&before>0,untouched:incoming<=0,after:Math.max(0,before-incoming)}
    })
  },[attack.declared_power,defenses])

  useEffect(()=>{const tick=()=>setSeconds(Math.max(0,Math.ceil((deadline-Date.now())/1000)));tick();const timer=window.setInterval(tick,250);return()=>window.clearInterval(timer)},[deadline])
  useEffect(()=>{if(seconds!==0||declined.current)return;declined.current=true;setBusy(true);void onDecline().finally(()=>setBusy(false))},[onDecline,seconds])
  const react=async(cardId:string)=>{if(busy||reactionUsed)return;setBusy(true);try{await onActivate(cardId)}finally{setBusy(false)}}
  const decline=async()=>{if(declined.current||busy)return;declined.current=true;setBusy(true);try{await onDecline()}finally{setBusy(false)}}

  return <motion.div initial={{opacity:0}} animate={{opacity:1}} exit={{opacity:0}} className="fixed inset-0 z-[180] overflow-y-auto bg-[radial-gradient(circle_at_top,rgba(127,29,29,.88),rgba(0,0,0,.98)_58%)] p-4 backdrop-blur-lg">
    <div className="mx-auto flex min-h-full w-full max-w-7xl flex-col justify-center py-4">
      <header className="mb-4 rounded-2xl border-2 border-red-400/70 bg-black/75 p-4 text-center shadow-[0_0_60px_rgba(239,68,68,.35)]">
        <div className="flex items-center justify-between"><h2 className="flex items-center gap-2 font-serif text-xl font-black uppercase text-red-200"><ShieldAlert/> Janela tática de reação</h2><div className="flex items-center gap-2 rounded-full border border-red-300 bg-red-950 px-4 py-1 font-mono text-2xl font-black text-red-200"><Timer size={19}/>{seconds}s</div></div>
        <div className="mt-4 flex flex-wrap items-center justify-center gap-3">{attackerCards.map(card=><div key={card.id} className="flex items-center gap-2"><div className="aspect-[2/3] w-24"><GameCard card={card.card_data??undefined} enableZoom/></div><b className="text-2xl text-amber-200">{card.current_power??0}{card!==attackerCards.at(-1)?" + ":""}</b></div>)}<Swords className="text-red-300" size={34}/><strong className="font-serif text-2xl text-red-100">TOTAL DE {attack.declared_power} DE PODER</strong></div>
      </header>
      <div className="grid gap-4 lg:grid-cols-[1.25fr_.75fr]">
        <section className="rounded-2xl border border-amber-500/50 bg-stone-950/90 p-5"><h3 className="mb-4 font-serif text-lg font-black uppercase text-amber-200">Simulação da cadeia de impacto</h3><div className="space-y-3">{simulation.map(step=><motion.div initial={{x:-18,opacity:0}} animate={{x:0,opacity:1}} transition={{delay:step.index*.12}} key={step.card.id} className={`flex items-center gap-4 rounded-xl border p-3 ${step.destroyed?"border-red-500 bg-red-950/45":step.untouched?"border-stone-700 bg-stone-900/50":"border-emerald-500 bg-emerald-950/35"}`}><div className="aspect-[2/3] w-16 shrink-0"><GameCard card={step.card.card_data??undefined}/></div><div><b className="text-sm text-stone-100">{step.index+1}º {step.card.zone==="reinforcement"?"Reforço":"Carta de Vida"} · {step.card.card_data?.nome??"Carta oculta"}</b><p className="mt-1 text-xs text-stone-300">{step.untouched?"INTACTO · não será revelado":`Receberá ${step.damage} de dano${step.destroyed?` · SERÁ DESTRUÍDO · sobram ${step.remaining}`:` · SOBREVIVERÁ COM ${step.after} DE VIDA`}`}</p></div></motion.div>)}{!simulation.length&&<p className="rounded border border-red-500/50 bg-red-950/40 p-4 text-red-200">Não existem defesas válidas; o impacto será resolvido pelo servidor.</p>}</div></section>
        <section className="rounded-2xl border border-cyan-500/50 bg-stone-950/90 p-5"><h3 className="flex items-center gap-2 font-serif text-lg font-black uppercase text-cyan-200"><Zap/> Combos acionáveis</h3><p className="mt-1 text-xs text-stone-400">Mana dinâmica disponível: {mana} carta(s) na mão.</p><div className="mt-4 grid grid-cols-2 gap-3">{reactionCards.map(card=>{const effect=card.card_data?.effect_definition?.find(item=>item.trigger_type==="reaction"||item.is_reaction);const cost=Number(effect?.parameters?.mana_cost??card.card_data?.mana??0);return <button key={card.id} disabled={busy||reactionUsed||mana<cost} onClick={()=>void react(card.id)} className="rounded-xl border border-cyan-400/50 bg-blue-950/50 p-2 text-left transition hover:-translate-y-1 hover:border-cyan-200 disabled:opacity-35"><div className="mx-auto aspect-[2/3] w-24"><GameCard card={card.card_data??undefined}/></div><b className="mt-2 block text-xs text-cyan-100">{card.card_data?.nome}</b><span className="text-[10px] text-blue-300">Ativar reação · custo {cost}</span></button>})}</div>{!reactionCards.length&&<p className="mt-5 rounded-lg border border-stone-600 bg-black/60 p-5 text-center text-sm font-bold text-stone-300">Nenhuma reação válida disponível para este ataque</p>}<button disabled={busy} onClick={()=>void decline()} className="mt-5 w-full rounded-lg border-2 border-red-400 bg-gradient-to-r from-red-950 via-red-800 to-red-950 px-4 py-4 font-serif font-black uppercase text-red-50 disabled:opacity-50">{busy?"RESOLVENDO NO SERVIDOR…":"ACEITAR IMPACTO"}</button></section>
      </div>
    </div>
  </motion.div>
}
