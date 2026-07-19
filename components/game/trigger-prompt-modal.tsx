"use client"

import { motion } from "framer-motion"
import { Loader2, Sparkles, Zap } from "lucide-react"
import type { PendingCardTrigger, VisibleMatchCard } from "@/lib/types"
import { GameCard } from "./game-card"

const triggerLabels:Record<string,string>={on_destroyed:"DESTRUIÇÃO",on_turn_start:"INÍCIO DE TURNO",on_draw:"SAQUE",on_discard:"DESCARTE",on_attack_declared:"ATAQUE DECLARADO",on_attack_resolved:"ATAQUE RESOLVIDO",on_play:"INVOCAÇÃO",on_revealed:"REVELAÇÃO",on_turn_end:"FIM DE TURNO"}

export function TriggerPromptModal({trigger,card,mana,busy,onAccept,onDecline}:{trigger:PendingCardTrigger;card:VisibleMatchCard|undefined;mana:number;busy:boolean;onAccept:()=>void;onDecline:()=>void}){
  const enough=mana>=trigger.mana_cost
  const name=card?.card_data?.nome??"Carta de Ofier"
  return <motion.div initial={{opacity:0}} animate={{opacity:1}} exit={{opacity:0}} className="fixed inset-0 z-[196] flex items-center justify-center overflow-y-auto bg-black/95 p-5 backdrop-blur-lg">
    <motion.section initial={{scale:.78,y:80}} animate={{scale:1,y:0}} className="grid w-full max-w-5xl gap-6 rounded-2xl border-2 border-yellow-200 bg-[radial-gradient(circle_at_top,#4c1d95,#09090b_62%)] p-6 shadow-[0_0_90px_rgba(250,204,21,.45)] md:grid-cols-[280px_1fr]">
      <div className="mx-auto aspect-[2/3] w-full max-w-[260px] drop-shadow-[0_0_36px_rgba(250,204,21,.75)]"><GameCard card={card?.card_data??undefined} enableZoom/></div>
      <div className="flex flex-col justify-center"><Sparkles className="text-yellow-200" size={42}/><p className="mt-3 text-xs font-black uppercase tracking-[.3em] text-purple-200">Corrente de efeito autoritativa</p><h2 className="mt-2 font-serif text-2xl font-black uppercase leading-tight text-yellow-100">⚡ Gatilho de {triggerLabels[trigger.trigger_type]??trigger.trigger_type}: o efeito de {name} pode ser ativado agora!</h2><p className="mt-5 rounded-xl border border-purple-300/35 bg-black/50 p-4 text-sm leading-relaxed text-stone-100"><b className="text-yellow-300">EFEITO:</b> {trigger.description||card?.card_data?.efeito||"Efeito registrado no servidor."}</p><div className={`mt-5 rounded-xl border-2 p-4 text-center font-black ${enough?"border-cyan-300 bg-blue-950/60 text-cyan-100":"border-red-400 bg-red-950/60 text-red-100"}`}><Zap className="mr-2 inline"/>Custo de Ativação: {trigger.mana_cost} Mana · Sua Mana Disponível: {mana}</div>
        <button disabled={busy||!enough} onClick={onAccept} className="mt-5 rounded-xl border-2 border-yellow-100 bg-gradient-to-r from-amber-900 via-yellow-600 to-amber-900 px-5 py-4 font-serif text-sm font-black uppercase text-yellow-50 shadow-[0_0_28px_rgba(250,204,21,.55)] disabled:border-stone-600 disabled:bg-stone-800 disabled:text-stone-400 disabled:opacity-65">{busy?<><Loader2 className="mr-2 inline animate-spin"/>PROCESSANDO DECISÃO…</>:enough?"✨ SIM, PAGAR MANA E ATIVAR EFEITO":"⚡ MANA INSUFICIENTE PARA ATIVAR ESTE GATILHO"}</button>
        <button disabled={busy} onClick={onDecline} className="mt-3 rounded-xl border border-stone-400 bg-stone-900 px-5 py-4 text-sm font-black uppercase text-stone-200 disabled:opacity-40">🚫 NÃO, RECUSAR ATIVAÇÃO</button>
      </div>
    </motion.section>
  </motion.div>
}
