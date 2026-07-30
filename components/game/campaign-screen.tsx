"use client"

import { useState } from "react"
import { Shield, Lock, Compass, ArrowLeft, Gamepad2, Swords } from "lucide-react"
import { PreMatchModal } from "./pre-match-modal"
import { supabase } from "@/lib/supabase"

interface Boss {
  id: number
  name: string
  image: string
  difficulty: string
  unlocked: boolean
  description: string
}

export function CampaignScreen({ onEnter }: { onEnter: (screen: any) => void }) {
  const [preMatchMode, setPreMatchMode] = useState<"campaign" | null>(null)
  const [error, setError] = useState<string | null>(null)
  const [loading, setLoading] = useState(false)

  const bosses: Boss[] = [
    {
      id: 1,
      name: "Rei dos Mendigos",
      image: "https://encrypted-tbn0.gstatic.com/images?q=tbn:ANd9GcRB0UVe8FIIUHH42tXKmU3PvpPBpGrsIW4UD_bxw_ARMA&s=10",
      difficulty: "Fácil",
      unlocked: true,
      description: "Líder implacável dos becos de Novigrad. Ele esvazia sua própria mão rapidamente e conta com guarda-costas robustos."
    },
    {
      id: 2,
      name: "Caleb Menge",
      image: "",
      difficulty: "Médio",
      unlocked: false,
      description: "Derrote o chefe anterior para liberar."
    },
    {
      id: 3,
      name: "Whoreson Junior",
      image: "",
      difficulty: "Médio",
      unlocked: false,
      description: "Derrote o chefe anterior para liberar."
    },
    {
      id: 4,
      name: "Sigismund Dijkstra",
      image: "",
      difficulty: "Difícil",
      unlocked: false,
      description: "Derrote o chefe anterior para liberar."
    },
    {
      id: 5,
      name: "Filippa Eilhart",
      image: "",
      difficulty: "Difícil",
      unlocked: false,
      description: "Derrote o chefe anterior para liberar."
    },
    {
      id: 6,
      name: "Letho de Gulet",
      image: "",
      difficulty: "Pesadelo",
      unlocked: false,
      description: "Derrote o chefe anterior para liberar."
    },
    {
      id: 7,
      name: "Dettlaff",
      image: "",
      difficulty: "Pesadelo",
      unlocked: false,
      description: "Derrote o chefe anterior para liberar."
    },
    {
      id: 8,
      name: "Eredin Bréacc Glas",
      image: "",
      difficulty: "Divino",
      unlocked: false,
      description: "Derrote o chefe anterior para liberar."
    },
    {
      id: 9,
      name: "Gaunter O'Dimm",
      image: "",
      difficulty: "Divino",
      unlocked: false,
      description: "Derrote o chefe anterior para liberar."
    },
    {
      id: 10,
      name: "O Espelho do Destino",
      image: "",
      difficulty: "Impossível",
      unlocked: false,
      description: "Derrote o chefe anterior para liberar."
    }
  ]

  const handlePreMatchConfirm = async (deckId: string, isMobile: boolean) => {
    setPreMatchMode(null)
    setLoading(true)
    setError(null)
    try {
      const cleanDeckId = deckId === "SYSTEM_GENERATED" ? "00000000-0000-0000-0000-000000000072" : deckId
      // Let's use start_campaign_match RPC
      const { data: matchId, error: campaignError } = await supabase.rpc("start_campaign_match", { p_deck_id: cleanDeckId })
      if (campaignError) throw campaignError
      
      if (isMobile) window.localStorage.setItem('arena_mobile', 'true');
      else window.localStorage.removeItem('arena_mobile');
      
      await new Promise(r => setTimeout(r, 600))
      
      const url = new URL(window.location.href)
      url.searchParams.set("screen", "arena")
      url.searchParams.set("matchId", matchId)
      url.searchParams.delete("preview")
      window.history.pushState({}, "", url)
      onEnter("arena")
    } catch (cause: any) {
      setError(cause?.message || "Ocorreu um erro ao iniciar a campanha.")
    } finally {
      setLoading(false)
    }
  }

  return (
    <main className="min-h-screen bg-stone-950 p-6 text-stone-100 font-serif">
      <div className="mx-auto max-w-7xl">
        <header className="mb-8 flex items-center justify-between border-b border-amber-900/40 pb-5">
          <div className="flex items-center gap-4">
            <button 
              onClick={() => onEnter("hub")} 
              className="rounded-lg border border-amber-700/50 bg-black/40 hover:bg-stone-900 p-2.5 text-amber-200 transition-colors"
            >
              <ArrowLeft size={18} />
            </button>
            <div>
              <h1 className="text-3xl font-black text-amber-200 tracking-wider">MODO CAMPANHA</h1>
              <p className="text-xs font-sans text-stone-400 mt-1">Derrote os 10 chefes de Novigrad e prove ser o maior duelista.</p>
            </div>
          </div>
          <div className="flex items-center gap-2 rounded-full border border-amber-500/30 bg-amber-950/20 px-4 py-2 text-xs font-bold text-amber-300">
            <Compass className="animate-spin-slow" size={14} /> FASE 1: OS SUBÚRBIOS
          </div>
        </header>

        {error && (
          <div className="mb-6 rounded-xl border border-red-500/50 bg-red-950/30 p-4 text-sm font-sans text-red-200 shadow-lg">
            <strong className="block text-xs uppercase tracking-wider text-red-400 font-bold mb-1">Erro de Entrada</strong>
            {error}
          </div>
        )}

        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-5 gap-6">
          {bosses.map((boss) => (
            <div 
              key={boss.id} 
              className={`relative overflow-hidden rounded-2xl border-2 transition-all duration-300 ${
                boss.unlocked 
                  ? "border-amber-600/50 bg-stone-900 shadow-[0_0_15px_rgba(245,158,11,0.1)] hover:border-amber-400 hover:shadow-[0_0_25px_rgba(245,158,11,0.2)]" 
                  : "border-stone-800 bg-stone-950/40 opacity-50"
              }`}
            >
              <div className="relative aspect-[3/4] w-full bg-black">
                {boss.unlocked && boss.image ? (
                  <img 
                    src={boss.image} 
                    alt={boss.name} 
                    className="h-full w-full object-cover object-center transition-transform duration-500 hover:scale-105"
                  />
                ) : (
                  <div className="flex h-full w-full flex-col items-center justify-center p-4 text-center">
                    <Lock size={32} className="text-stone-700 mb-2" />
                    <span className="text-[10px] uppercase font-sans tracking-widest text-stone-600 font-bold">Bloqueado</span>
                  </div>
                )}
                <div className="absolute inset-0 bg-gradient-to-t from-stone-950 via-stone-950/30 to-transparent" />
                
                <div className="absolute top-3 left-3">
                  <span className={`text-[8px] font-sans font-black uppercase px-2 py-0.5 rounded border ${
                    boss.unlocked 
                      ? "border-amber-500/30 bg-black/80 text-amber-400" 
                      : "border-stone-800 bg-black/50 text-stone-600"
                  }`}>
                    Chefe {boss.id}
                  </span>
                </div>
              </div>

              <div className="p-4 flex flex-col justify-between h-[180px] border-t border-amber-950/20 bg-gradient-to-b from-stone-900 to-stone-950">
                <div>
                  <h3 className="font-serif text-lg font-black text-amber-100 tracking-wide">{boss.name}</h3>
                  <p className="text-[11px] font-sans text-stone-400 mt-1 leading-relaxed line-clamp-3">{boss.description}</p>
                </div>

                <div className="mt-4 flex items-center justify-between gap-2">
                  <span className="text-[10px] font-sans text-stone-500">
                    Dificuldade: <span className="font-bold text-amber-500">{boss.difficulty}</span>
                  </span>
                  
                  {boss.unlocked ? (
                    <button 
                      onClick={() => setPreMatchMode("campaign")}
                      disabled={loading}
                      className="rounded-lg border border-amber-500 bg-amber-700/80 hover:bg-amber-600 px-4 py-2 text-xs font-black uppercase text-amber-100 tracking-wider transition-colors shadow-md flex items-center gap-1.5"
                    >
                      <Swords size={12} /> Batalhar
                    </button>
                  ) : (
                    <span className="text-[9px] font-sans font-bold text-stone-600 uppercase tracking-wider">Bloqueado</span>
                  )}
                </div>
              </div>
            </div>
          ))}
        </div>
      </div>

      {preMatchMode && (
        <PreMatchModal 
          mode={preMatchMode} 
          onCancel={() => setPreMatchMode(null)} 
          onConfirm={handlePreMatchConfirm} 
        />
      )}
    </main>
  )
}
