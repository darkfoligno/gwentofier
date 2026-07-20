"use client"

import { motion } from "framer-motion"
import { Loader2, Lock, Sparkles, Zap } from "lucide-react"
import type { PendingCardTrigger, VisibleMatchCard } from "@/lib/types"
import { GameCard } from "./game-card"

const triggerLabels:Record<string,string>={on_destroyed:"DESTRUIÇÃO",on_turn_start:"INÍCIO DE TURNO",on_draw:"SAQUE",on_discard:"DESCARTE",on_attack_declared:"ATAQUE DECLARADO",on_attack_resolved:"ATAQUE RESOLVIDO",on_play:"INVOCAÇÃO",on_revealed:"REVELAÇÃO",on_turn_end:"FIM DE TURNO"}

export function TriggerPromptModal({trigger,card,mana,busy,onAccept,onDecline}:{trigger:PendingCardTrigger;card:VisibleMatchCard|undefined;mana:number;busy:boolean;onAccept:()=>void;onDecline:()=>void}){
  const enough=mana>=trigger.mana_cost
  const name=trigger.card_name??card?.card_data?.nome??`ID ${trigger.source_match_card_id}`
  const effect=trigger.effect_text||trigger.description||card?.card_data?.efeito||"Texto preservado no contrato autoritativo."
  const reason=triggerLabels[trigger.trigger_type]??trigger.trigger_type
  const fallback=card?.card_data??{id:trigger.source_match_card_id,nome:name,image_url:trigger.image_url,mana:trigger.mana_cost,ataque:trigger.power??0,vida:trigger.life??1,elemento:(trigger.element??"Cívil") as "Cívil",tipo:"normal",raridade:"common" as const,efeito:effect}
  return <motion.div initial={{opacity:0}} animate={{opacity:1}} exit={{opacity:0}} className="fixed inset-0 z-[196] flex items-center justify-center overflow-y-auto bg-black/85 p-5 backdrop-blur-md">
    <div className="pointer-events-none absolute inset-0 overflow-hidden">{Array.from({length:18},(_,index)=><motion.i key={index} className="absolute h-1.5 w-1.5 rounded-full bg-yellow-200 shadow-[0_0_14px_#facc15]" style={{left:`${8+(index*17)%88}%`,top:`${12+(index*29)%76}%`}} animate={{opacity:[.15,1,.15],scale:[.5,1.8,.5],y:[0,-25,0]}} transition={{duration:2+(index%4)*.4,repeat:Infinity,delay:index*.08}}/>)}</div>
    <motion.section initial={{scale:.72,y:100}} animate={{scale:1,y:0}} transition={{type:"spring",stiffness:150,damping:17}} className="relative grid w-full max-w-6xl gap-8 rounded-2xl border-2 border-yellow-200 bg-[radial-gradient(circle_at_top,#4c1d95,#09090b_62%)] p-7 shadow-[0_0_100px_rgba(168,85,247,.7)] md:grid-cols-[320px_1fr]">
      <motion.div initial={{x:-300,rotate:-12,scale:.45}} animate={{x:0,rotate:0,scale:1.2}} transition={{type:"spring",stiffness:125,damping:16}} className="mx-auto aspect-[2/3] w-full max-w-[260px] self-center drop-shadow-[0_0_45px_rgba(250,204,21,.9)]"><GameCard card={fallback} enableZoom/></motion.div>
      <div className="flex flex-col justify-center rounded-xl border-2 border-amber-700/70 bg-[linear-gradient(135deg,rgba(28,25,23,.96),rgba(69,26,3,.88))] p-6 shadow-[inset_0_0_35px_rgba(245,158,11,.12)]"><Sparkles className="text-yellow-200" size={46}/><p className="mt-3 text-xs font-black uppercase tracking-[.32em] text-purple-200">Corrente de efeito autoritativa</p><h2 className="mt-2 font-serif text-3xl font-black uppercase leading-tight text-yellow-100">⚡ GATILHO DE CONJURAÇÃO ACIONADO!</h2><p className="mt-3 text-sm text-stone-200">A carta <b className="text-amber-200">{name}</b> reagiu ao evento de: <b className="text-purple-200">{reason}</b>.</p><div className="mt-5 grid grid-cols-2 gap-2 rounded-lg border border-stone-600 bg-black/55 p-4 text-sm text-stone-200"><span>Nome: <b className="text-amber-100">{name}</b></span><span>Mana: <b className="text-cyan-200">{trigger.mana_cost}</b></span><span>Elemento: <b>{trigger.element??card?.card_data?.elemento??"Cívil"}</b></span><span>ATK/HP: <b>{trigger.power??card?.current_power??"?"} / {trigger.life??card?.current_life??"?"}</b></span><p className="col-span-2 mt-2 border-t border-amber-800 pt-3 font-bold leading-relaxed text-yellow-300">{effect}</p></div><div className={`mt-5 rounded-xl border-2 p-4 text-center font-black ${enough?"border-cyan-300 bg-blue-950/60 text-cyan-100":"border-stone-600 bg-stone-950 text-stone-400"}`}><Zap className="mr-2 inline"/>Custo: {trigger.mana_cost} Mana · Atual: {mana}</div>
        <button disabled={busy||!enough} onClick={onAccept} className="mt-5 rounded-xl border-2 border-yellow-100 bg-gradient-to-r from-amber-900 via-yellow-500 to-amber-900 px-5 py-4 font-serif text-sm font-black uppercase text-yellow-50 shadow-[0_0_34px_rgba(250,204,21,.7)] disabled:border-stone-700 disabled:bg-stone-900 disabled:text-stone-500 disabled:shadow-none">{busy?<><Loader2 className="mr-2 inline animate-spin"/>PROCESSANDO DECISÃO…</>:enough?`✨ CONJURAR EFEITO (Pagar ${trigger.mana_cost} de Mana)`:<><Lock className="mr-2 inline"/>MANA INSUFICIENTE PARA CONJURAÇÃO (Requer {trigger.mana_cost} | Atual: {mana})</>}</button>
        <button disabled={busy} onClick={onDecline} className="mt-3 rounded-xl border border-stone-400 bg-gradient-to-r from-stone-950 via-stone-700 to-stone-950 px-5 py-4 text-sm font-black uppercase text-stone-100 disabled:opacity-40">🚫 RECUSAR E PASSAR A VEZ</button>
      </div>
    </motion.section>
  </motion.div>
}
