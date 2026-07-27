"use client"
import { useEffect, useState } from "react"
import { Beaker, Coins, ArrowLeft, Loader2, Award, CheckCircle } from "lucide-react"
import { supabase } from "@/lib/supabase"
import type { GameCard as GameCardType, Rarity, OfficialCardType } from "@/lib/game-data"
import { GameCard } from "./game-card"
import type { Screen } from "@/lib/types"

export function LabScreen({ onEnter }: { onEnter: (screen: Screen) => void }) {
  const [labCards, setLabCards] = useState<GameCardType[]>([])
  const [claimedCardIds, setClaimedCardIds] = useState<string[]>([])
  const [loading, setLoading] = useState(true)
  const [testingCardId, setTestingCardId] = useState<string | null>(null)
  const [statusMessage, setStatusMessage] = useState("")

  const loadLabData = async () => {
    setLoading(true)
    const ids = [
      "66d0f400-141a-4591-9c1a-f4400be91bc9", // Tomira
      "cc6cc445-8484-470f-a71e-3e63dbf0008d", // Pantera
      "1c224f7d-52e8-4793-8a38-fe9f30d8bb3b", // Dijkistra
      "e0ea21e2-0922-4632-951e-b8c67d950087", // Alpor
      "cb068893-6065-4437-9cdc-0a23dba9d833", // Barão Sanguinário
      "be85f335-f299-4094-af13-ae6c7c0230a1", // Ekimmu
      "7b11c636-7ec8-46aa-917a-d47ff19b456f", // Feitiçeira Fringilla
      "a28fa8e8-ab19-4fc7-809d-b8246bf01652", // Lisandro Vanderbaster
      "7258635f-0be9-47ba-8257-6c4ae95067f0", // Gaunter O'Dimm
      "44ea442e-cfb3-4cdb-a8b9-66fdc84b1ddd", // Dandelion
    ]

    try {
      const { data: cardsResult, error: cardsError } = await supabase
        .from("cards")
        .select("id,name,image_url,element,rarity,card_type,is_original_rpg,base_power,base_max_life,effect_mana_cost,effect_text")
        .in("id", ids)
      
      if (cardsError) throw cardsError

      if (cardsResult) {
        const mapped = cardsResult.map((card: any) => ({
          id: card.id,
          nome: card.name,
          image_url: card.image_url,
          elemento: card.element as OfficialCardType,
          raridade: card.rarity as Rarity,
          tipo: card.element,
          mana: card.effect_mana_cost,
          ataque: card.base_power,
          vida: card.base_max_life,
          efeito: card.effect_text ?? "",
          effect_definition: [],
          is_original_rpg: card.is_original_rpg,
          quantity: 1
        }))
        const sorted = mapped.sort((a, b) => ids.indexOf(a.id) - ids.indexOf(b.id))
        setLabCards(sorted)
      }

      const { data: claimedResult, error: claimError } = await supabase.rpc("get_user_claimed_lab_cards")
      if (!claimError && claimedResult) {
        setClaimedCardIds(claimedResult)
      }
    } catch (err) {
      console.error("Erro ao carregar dados do laboratório:", err)
    } finally {
      setLoading(false)
    }
  }

  useEffect(() => {
    void loadLabData()
  }, [])

  const handleTestCard = async (cardId: string) => {
    setTestingCardId(cardId)
    setStatusMessage("Registrando simulação alquímica...")
    
    try {
      // 1. Process reward claim securely in database (anti-farm)
      const { data: rewardResult, error: rewardError } = await supabase.rpc("claim_lab_reward", { p_card_id: cardId })
      if (rewardError) throw rewardError

      const gotCoins = rewardResult?.first_time || false
      if (gotCoins) {
        setStatusMessage("🪙 +25 Moedas ganhas pela primeira análise!")
        await new Promise(r => setTimeout(r, 1200))
      }

      // 2. Start customized lab simulation match
      setStatusMessage("Iniciando Arena de Simulação (mana extra e carta na mão)...")
      const { data: matchId, error: matchError } = await supabase.rpc("start_lab_match", { p_test_card_id: cardId })
      if (matchError) throw matchError

      window.localStorage.removeItem('arena_mobile') // default PC version
      
      setStatusMessage("Abrindo Arena...")
      await new Promise(r => setTimeout(r, 600))

      // Navigate to arena
      const url = new URL(window.location.href)
      url.searchParams.set("screen", "arena")
      url.searchParams.set("matchId", matchId)
      url.searchParams.delete("preview")
      window.history.pushState({}, "", url)
      
      onEnter("arena")
    } catch (err: any) {
      console.error(err)
      alert("Erro ao iniciar teste: " + err.message)
      setTestingCardId(null)
    }
  }

  return (
    <main className="min-h-screen bg-stone-950 text-stone-100 p-6 pt-20 relative overflow-x-hidden">
      <div className="absolute inset-0 bg-[radial-gradient(circle_at_top,rgba(16,185,129,0.08),transparent_60%)] pointer-events-none" />
      
      <div className="relative mx-auto max-w-7xl">
        <header className="mb-8 flex flex-wrap items-center justify-between gap-4 rounded-xl border border-emerald-500/30 bg-black/60 p-6 shadow-[0_0_30px_rgba(16,185,129,0.1)]">
          <div className="flex items-center gap-4">
            <button 
              onClick={() => onEnter("hub")} 
              className="p-2.5 rounded-lg border border-stone-800 bg-stone-900/60 hover:bg-stone-850 hover:text-amber-200 transition-colors"
              aria-label="Voltar"
            >
              <ArrowLeft size={16} />
            </button>
            <div>
              <div className="flex items-center gap-2">
                <Beaker className="text-emerald-400" size={24} />
                <h1 className="font-serif text-2xl font-black text-emerald-200 uppercase tracking-widest">Laboratório Ofieri</h1>
              </div>
              <p className="text-xs text-stone-400 mt-1 leading-relaxed max-w-xl">
                Ambiente de simulação controlada. Teste o feitiço e o comportamento das cartas em combate e receba +25 moedas pela primeira análise de cada artefato.
              </p>
            </div>
          </div>
        </header>

        {loading ? (
          <div className="flex h-64 items-center justify-center text-emerald-400">
            <Loader2 className="animate-spin mr-2" />
            <span className="font-serif text-sm uppercase tracking-widest">Carregando Grimório de Simulações...</span>
          </div>
        ) : (
          <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-5 gap-6">
            {labCards.map(card => {
              const isClaimed = claimedCardIds.includes(card.id)
              const isTestingThis = testingCardId === card.id

              return (
                <div 
                  key={card.id} 
                  className="rounded-xl border border-emerald-900/30 bg-stone-900/40 p-4.5 flex flex-col justify-between items-center shadow-lg transition-all hover:border-emerald-600/40 hover:shadow-[0_0_20px_rgba(16,185,129,0.08)] relative overflow-hidden"
                >
                  {/* Top Badge: Claim status */}
                  <div className="absolute top-3.5 right-3.5 z-10">
                    {isClaimed ? (
                      <span className="flex items-center gap-1 rounded bg-stone-800/90 border border-stone-700 px-2 py-0.5 text-[9px] font-bold text-stone-400 uppercase tracking-wide">
                        <CheckCircle size={10} className="text-emerald-500" /> Concluído
                      </span>
                    ) : (
                      <span className="flex items-center gap-1 rounded bg-emerald-950/90 border border-emerald-500/40 px-2 py-0.5 text-[9px] font-bold text-emerald-300 uppercase tracking-wide shadow-[0_0_8px_rgba(16,185,129,0.2)]">
                        <Award size={10} /> 🪙 +25 Moedas
                      </span>
                    )}
                  </div>

                  {/* Card Display */}
                  <div className="w-[180px] mb-4">
                    <GameCard card={card} enableZoom={false} />
                  </div>

                  {/* Info and Test action */}
                  <div className="w-full mt-auto">
                    <h3 className="font-serif font-black text-center text-sm text-stone-200 truncate mb-2">{card.nome}</h3>
                    
                    <button
                      disabled={testingCardId !== null}
                      onClick={() => void handleTestCard(card.id)}
                      className={`w-full py-2.5 rounded-lg font-serif font-black text-xs uppercase tracking-widest transition-all duration-300 flex items-center justify-center gap-1.5 border ${
                        isTestingThis 
                          ? 'border-emerald-400 bg-emerald-950 text-emerald-200'
                          : testingCardId !== null 
                            ? 'border-stone-850 bg-stone-900/30 text-stone-600 cursor-not-allowed opacity-50'
                            : 'border-emerald-500 bg-emerald-950/60 hover:bg-emerald-900 text-emerald-300 hover:text-white shadow-[0_4px_12px_rgba(16,185,129,0.1)]'
                      }`}
                    >
                      {isTestingThis ? (
                        <>
                          <Loader2 className="animate-spin" size={12} />
                          <span>Simulando...</span>
                        </>
                      ) : (
                        <span>Testar Carta</span>
                      )}
                    </button>
                  </div>
                </div>
              )
            })}
          </div>
        )}
      </div>

      {/* Full-screen Loading Overlay for Simulation */}
      {testingCardId && (
        <div className="fixed inset-0 z-[500] flex flex-col items-center justify-center bg-black/95 backdrop-blur-md">
          <Beaker className="text-emerald-400 animate-pulse mb-4" size={60} />
          <p className="font-serif text-lg text-emerald-200 uppercase tracking-widest animate-pulse">{statusMessage}</p>
          <span className="text-xs text-stone-500 mt-2">Preparando arena isolada de simulação...</span>
        </div>
      )}
    </main>
  )
}
