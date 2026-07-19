"use client"

import { useMemo, useState } from "react"
import { motion } from "framer-motion"
import { FastForward, Sparkles, Zap } from "lucide-react"
import type { VisibleMatchCard } from "@/lib/types"
import { GameCard } from "./game-card"

const effectOf=(card:VisibleMatchCard)=>card.card_data?.effect_definition?.find(effect=>effect.trigger_type==="manual"&&!effect.is_reaction)
const costOf=(card:VisibleMatchCard)=>Number(effectOf(card)?.parameters?.mana_cost??card.card_data?.mana??0)

export function PreCombatModal({ cards, mana, busy, freeUsed, paidUsed, onActivate, onContinue, onClose }: {
  cards: VisibleMatchCard[]
  mana: number
  busy: boolean
  freeUsed: boolean
  paidUsed: boolean
  onActivate: (card: VisibleMatchCard) => void
  onContinue: () => void
  onClose: () => void
}) {
  const [selectedId,setSelectedId]=useState<string|null>(cards[0]?.id??null)
  const selected=useMemo(()=>cards.find(card=>card.id===selectedId)??cards[0]??null,[cards,selectedId])
  const activate=(kind:"free"|"paid",card=selected)=>{if(!card||busy)return;const cost=costOf(card);if(kind==="free"&&cost!==0)return;if(kind==="paid"&&(cost<=0||cost>mana))return;if((kind==="free"&&freeUsed)||(kind==="paid"&&paidUsed))return;onActivate(card)}
  const drop=(event:React.DragEvent<HTMLButtonElement>,kind:"free"|"paid")=>{event.preventDefault();const card=cards.find(item=>item.id===event.dataTransfer.getData("text/effect-card-id"));activate(kind,card)}

  return <motion.div initial={{opacity:0}} animate={{opacity:1}} exit={{opacity:0}} className="fixed inset-0 z-[178] overflow-y-auto bg-black/95 p-5 backdrop-blur-md">
    <motion.section initial={{scale:.92,y:25}} animate={{scale:1,y:0}} className="mx-auto w-full max-w-[1450px] rounded-2xl border-2 border-purple-300 bg-[radial-gradient(circle_at_top,#3b0764,#09090b_65%)] p-5 shadow-[0_0_70px_rgba(192,132,252,.45)]">
      <Sparkles className="mx-auto text-purple-200" size={34}/><h2 className="mt-1 text-center font-serif text-2xl font-black uppercase text-purple-50">🔮 Cadeia Tática Pré-Combate</h2><p className="mt-1 text-center text-xs text-purple-200">Inspecione a carta e arraste-a para a zona correspondente. Regra 13: uma conjuração grátis e uma paga por turno.</p>
      <div className="mt-5 grid gap-5 xl:grid-cols-[1fr_300px_1fr]">
        <section className="min-w-0 rounded-xl border border-purple-400/30 bg-black/45 p-4"><h3 className="mb-3 text-xs font-black uppercase text-purple-200">Cartas elegíveis · arraste ou selecione</h3><div className="flex min-h-56 gap-4 overflow-x-auto pb-3">{cards.map(card=><button draggable key={card.id} onDragStart={event=>{event.dataTransfer.effectAllowed="move";event.dataTransfer.setData("text/effect-card-id",card.id)}} onClick={()=>setSelectedId(card.id)} className={`w-32 shrink-0 rounded-xl border p-2 transition hover:-translate-y-2 ${selected?.id===card.id?"border-yellow-200 bg-yellow-900/25 shadow-[0_0_22px_rgba(250,204,21,.45)]":"border-purple-300/40 bg-purple-950/35"}`}><div className="aspect-[2/3] w-full"><GameCard card={card.card_data??undefined} enableZoom={false}/></div><b className="mt-2 block text-[10px] text-purple-100">{card.card_data?.nome}</b><span className="text-[9px] font-black text-cyan-200">⚡ Custo {costOf(card)}</span></button>)}{!cards.length&&<p className="m-auto text-sm text-stone-400">Nenhum efeito de turno disponível.</p>}</div></section>
        <aside className="rounded-xl border border-amber-300/40 bg-black/65 p-4 text-center"><h3 className="font-serif text-sm font-black uppercase text-amber-200">Inspeção integral</h3>{selected?.card_data?<><button className="mx-auto mt-3 block aspect-[2/3] w-52 cursor-zoom-in"><GameCard card={selected.card_data} enableZoom/></button><h4 className="mt-3 font-serif text-lg font-black text-amber-100">{selected.card_data.nome}</h4><p className="mt-2 max-h-24 overflow-y-auto text-left text-[11px] leading-relaxed text-stone-200"><b className="text-yellow-300">EFEITO:</b> {selected.card_data.efeito}</p></>:<p className="py-24 text-stone-500">Selecione uma carta.</p>}</aside>
        <section className="space-y-4"><button onDragOver={event=>event.preventDefault()} onDrop={event=>drop(event,"free")} onClick={()=>activate("free")} disabled={busy||freeUsed||!selected||costOf(selected)!==0} className="flex min-h-40 w-full flex-col items-center justify-center rounded-2xl border-2 border-dashed border-emerald-300 bg-emerald-950/45 p-5 text-center shadow-[inset_0_0_35px_rgba(52,211,153,.12)] disabled:border-stone-600 disabled:bg-stone-900/60 disabled:opacity-50"><Zap className="text-emerald-300"/><b className="mt-2 font-serif text-sm uppercase text-emerald-100">🟢 Zona 1: Conjurar efeito de custo 0</b><span className="mt-1 text-xs text-emerald-300">{freeUsed?"1/1 utilizado no turno":"0/1 no turno · solte a carta aqui"}</span></button><button onDragOver={event=>event.preventDefault()} onDrop={event=>drop(event,"paid")} onClick={()=>activate("paid")} disabled={busy||paidUsed||!selected||costOf(selected)<=0||costOf(selected)>mana} className="flex min-h-40 w-full flex-col items-center justify-center rounded-2xl border-2 border-dashed border-cyan-300 bg-blue-950/45 p-5 text-center shadow-[inset_0_0_35px_rgba(34,211,238,.12)] disabled:border-stone-600 disabled:bg-stone-900/60 disabled:opacity-50"><Zap className="text-cyan-300"/><b className="mt-2 font-serif text-sm uppercase text-cyan-100">🔵 Zona 2: Conjurar efeito pago com mana</b><span className="mt-1 text-xs text-cyan-300">{paidUsed?"1/1 utilizado no turno":`0/1 no turno · Mana disponível: ${mana}`}</span></button></section>
      </div>
      <div className="mt-5 grid gap-3 sm:grid-cols-[.3fr_1fr]"><button disabled={busy} onClick={onClose} className="rounded-lg border border-stone-500 bg-stone-900 px-4 py-3 text-xs font-black text-stone-300">VOLTAR AO TABULEIRO</button><button disabled={busy} onClick={onContinue} className="rounded-lg border-2 border-yellow-200 bg-gradient-to-r from-amber-900 via-yellow-600 to-amber-900 px-5 py-4 font-serif text-sm font-black uppercase text-yellow-50 shadow-[0_0_24px_rgba(250,204,21,.5)]"><FastForward className="mr-2 inline" size={18}/> ⚔️ Avançar para as Areias de Combate (fim das conjurações)</button></div>
    </motion.section>
  </motion.div>
}
