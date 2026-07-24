"use client"

import { useState, useEffect } from "react"
import { motion } from "framer-motion"
import { Shield, Zap, Clock, Info } from "lucide-react"

interface ActionModalProps {
  availableMana: number
  eligibleCards: any[] // Cards you control that can be activated (cost <= mana)
  onConfirm: (selectedCardIds: string[]) => void
}

export function ActionModal({ availableMana, eligibleCards, onConfirm }: ActionModalProps) {
  const [selected, setSelected] = useState<string[]>([])
  
  const toggleSelection = (cardId: string, cost: number) => {
    if (selected.includes(cardId)) {
      setSelected(selected.filter(id => id !== cardId))
    } else {
      // The rules say: 1 card with cost 0 AND 1 card with cost > 0
      // For now, let's just restrict it to max 2 cards, and total cost <= availableMana
      // Full restriction: 
      const currentSelected = eligibleCards.filter(c => selected.includes(c.id))
      const hasZeroCost = currentSelected.some(c => c.effect_mana_cost === 0)
      const hasManaCost = currentSelected.some(c => c.effect_mana_cost > 0)
      
      if (cost === 0 && hasZeroCost) return // Already has a 0 cost
      if (cost > 0 && hasManaCost) return // Already has a > 0 cost
      
      const totalCost = currentSelected.reduce((sum, c) => sum + c.effect_mana_cost, 0)
      if (totalCost + cost > availableMana) return // Not enough mana
      
      setSelected([...selected, cardId])
    }
  }

  return (
    <div className="fixed inset-0 z-[200] flex items-center justify-center bg-black/90 p-4 backdrop-blur-sm">
      <motion.div initial={{ scale: 0.9, opacity: 0 }} animate={{ scale: 1, opacity: 1 }} className="flex h-[80vh] w-[90vw] max-w-5xl overflow-hidden rounded-2xl border border-amber-500/50 bg-stone-950 shadow-2xl">
        <div className="flex flex-1 flex-col p-6">
          <header className="mb-6 border-b border-stone-800 pb-4">
            <h2 className="font-serif text-3xl font-black uppercase text-amber-400">Ativação de Feitiços</h2>
            <p className="text-sm text-stone-400">Selecione até 1 mágica de custo 0 e 1 mágica de custo maior que 0.</p>
            <div className="mt-2 flex items-center gap-2 text-blue-300">
              <Zap size={18} />
              <span className="font-black">Mana Disponível: {availableMana}</span>
            </div>
          </header>
          
          <div className="flex-1 overflow-y-auto">
            {eligibleCards.length === 0 ? (
              <div className="flex h-32 items-center justify-center rounded-xl border border-dashed border-stone-800 text-stone-500">
                Nenhuma carta elegível para ativação.
              </div>
            ) : (
              <div className="grid grid-cols-2 gap-4 sm:grid-cols-3 md:grid-cols-4">
                {eligibleCards.map(card => {
                  const isSelected = selected.includes(card.id)
                  return (
                    <button
                      key={card.id}
                      onClick={() => toggleSelection(card.id, card.effect_mana_cost)}
                      className={`relative overflow-hidden rounded-xl border-2 p-2 transition-all ${isSelected ? "border-amber-400 bg-amber-900/30 shadow-[0_0_15px_rgba(251,191,36,0.3)]" : "border-stone-700 bg-stone-900 hover:border-amber-600/50"}`}
                    >
                      <img src={card.card_type_id?.image_url} alt={card.card_type_id?.name} className="aspect-[2/3] w-full rounded-md object-cover" />
                      <div className="mt-2 text-left">
                        <strong className="block truncate text-xs text-stone-200">{card.card_type_id?.name}</strong>
                        <span className="flex items-center gap-1 text-[10px] text-blue-400"><Zap size={10} /> {card.effect_mana_cost} Mana</span>
                      </div>
                      {isSelected && <div className="absolute inset-0 border-4 border-amber-400 rounded-xl" />}
                    </button>
                  )
                })}
              </div>
            )}
          </div>
          
          <footer className="mt-6 flex justify-end gap-4 border-t border-stone-800 pt-4">
            <button onClick={() => onConfirm(selected)} className="rounded-xl border border-amber-500 bg-amber-700 px-8 py-3 font-black uppercase text-amber-100 transition-transform active:scale-95 shadow-[0_0_15px_rgba(217,119,6,0.2)]">
              {selected.length > 0 ? "CONFIRMAR ATIVAÇÕES" : "CONTINUAR SEM ATIVAR"}
            </button>
          </footer>
        </div>
      </motion.div>
    </div>
  )
}

interface ReactionModalProps {
  availableMana: number
  eligibleCards: any[]
  onConfirm: (selectedCardId: string | null) => void
}

export function ReactionModal({ availableMana, eligibleCards, onConfirm }: ReactionModalProps) {
  const [timeLeft, setTimeLeft] = useState(60)
  const [selected, setSelected] = useState<string | null>(null)

  useEffect(() => {
    const timer = setInterval(() => {
      setTimeLeft(prev => {
        if (prev <= 1) {
          clearInterval(timer)
          onConfirm(selected) // Auto-confirm on timeout
          return 0
        }
        return prev - 1
      })
    }, 1000)
    return () => clearInterval(timer)
  }, [selected, onConfirm])

  return (
    <div className="fixed inset-0 z-[200] flex items-center justify-center bg-red-950/90 p-4 backdrop-blur-md">
      <motion.div initial={{ y: 50, opacity: 0 }} animate={{ y: 0, opacity: 1 }} className="flex h-[80vh] w-[90vw] max-w-5xl overflow-hidden rounded-2xl border border-red-500/50 bg-stone-950 shadow-[0_0_50px_rgba(220,38,38,0.3)]">
        <div className="flex flex-1 flex-col p-6">
          <header className="mb-6 flex items-center justify-between border-b border-red-900/50 pb-4">
            <div>
              <h2 className="flex items-center gap-2 font-serif text-3xl font-black uppercase text-red-500"><Shield /> Reação Defensiva</h2>
              <p className="text-sm text-red-300/70">Você está sendo atacado! Escolha exatamente 1 efeito para reagir.</p>
            </div>
            <div className="flex flex-col items-end">
              <div className={`flex items-center gap-2 text-2xl font-black ${timeLeft <= 10 ? "animate-pulse text-red-500" : "text-amber-400"}`}>
                <Clock size={24} /> 00:{timeLeft.toString().padStart(2, "0")}
              </div>
              <span className="text-xs text-blue-400 font-bold">Mana Disponível: {availableMana}</span>
            </div>
          </header>
          
          <div className="flex-1 overflow-y-auto">
            {eligibleCards.length === 0 ? (
              <div className="flex h-32 items-center justify-center rounded-xl border border-dashed border-red-900/50 text-red-500/70">
                Nenhuma carta elegível para reagir neste turno.
              </div>
            ) : (
              <div className="grid grid-cols-2 gap-4 sm:grid-cols-3 md:grid-cols-4">
                {eligibleCards.map(card => {
                  const isSelected = selected === card.id
                  return (
                    <button
                      key={card.id}
                      onClick={() => {
                        if (card.effect_mana_cost <= availableMana) {
                          setSelected(isSelected ? null : card.id)
                        }
                      }}
                      disabled={card.effect_mana_cost > availableMana}
                      className={`relative overflow-hidden rounded-xl border-2 p-2 transition-all ${isSelected ? "border-red-500 bg-red-900/40 shadow-[0_0_20px_rgba(239,68,68,0.4)]" : "border-stone-700 bg-stone-900 hover:border-red-900/50"} ${card.effect_mana_cost > availableMana ? "opacity-50 grayscale" : ""}`}
                    >
                      <img src={card.card_type_id?.image_url} alt={card.card_type_id?.name} className="aspect-[2/3] w-full rounded-md object-cover" />
                      <div className="mt-2 text-left">
                        <strong className="block truncate text-xs text-stone-200">{card.card_type_id?.name}</strong>
                        <span className={`flex items-center gap-1 text-[10px] ${card.effect_mana_cost > availableMana ? "text-red-500" : "text-blue-400"}`}><Zap size={10} /> {card.effect_mana_cost} Mana</span>
                      </div>
                      {isSelected && <div className="absolute inset-0 border-4 border-red-500 rounded-xl" />}
                    </button>
                  )
                })}
              </div>
            )}
          </div>
          
          <footer className="mt-6 flex justify-between border-t border-red-900/50 pt-4">
            <button onClick={() => onConfirm(null)} className="rounded-xl border border-stone-600 bg-stone-800 px-6 py-3 font-bold text-stone-300 transition-transform active:scale-95">
              AGIR SEM REAGIR
            </button>
            <button onClick={() => selected && onConfirm(selected)} disabled={!selected} className="rounded-xl border border-red-500 bg-red-700 px-8 py-3 font-black uppercase tracking-wider text-red-100 transition-transform active:scale-95 disabled:opacity-50 shadow-[0_0_15px_rgba(220,38,38,0.3)]">
              CONFIRMAR REAÇÃO
            </button>
          </footer>
        </div>
      </motion.div>
    </div>
  )
}
