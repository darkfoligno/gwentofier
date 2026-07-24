"use client"

import { useState, useEffect } from "react"
import { motion } from "framer-motion"
import { Swords, Smartphone, Monitor, Layers, Bot, ChevronRight, Loader2 } from "lucide-react"
import { supabase } from "@/lib/supabase"

interface Deck {
  id: string
  name: string
  // Removido element pois não existe na tabela decks
  is_valid: boolean
}

export function PreMatchModal({
  mode,
  onCancel,
  onConfirm
}: {
  mode: "pvp" | "training" | null
  onCancel: () => void
  onConfirm: (deckId: string, isMobile: boolean) => void
}) {
  const [step, setStep] = useState<"deck" | "version">("deck")
  const [decks, setDecks] = useState<Deck[]>([])
  const [selectedDeck, setSelectedDeck] = useState<string | null>(null)
  const [loading, setLoading] = useState(true)
  const [busy, setBusy] = useState(false)

  useEffect(() => {
    if (!mode) return
    async function loadDecks() {
      const { data } = await supabase
        .from("decks")
        .select("id, name, is_valid")
        .eq("is_valid", true)
        .order("updated_at", { ascending: false })
      setDecks(data || [])
      if (data && data.length > 0) setSelectedDeck(data[0].id)
      setLoading(false)
    }
    void loadDecks()
  }, [mode])

  if (!mode) return null

  const handleGenerateDeck = async () => {
    setBusy(true)
    const { data, error } = await supabase.rpc("generate_system_deck")
    if (data && !error) {
      setSelectedDeck(data)
      setStep("version")
    }
    setBusy(false)
  }

  const handleConfirmDeck = () => {
    if (selectedDeck) setStep("version")
  }

  const handleConfirmVersion = (isMobile: boolean) => {
    if (selectedDeck) onConfirm(selectedDeck, isMobile)
  }

  return (
    <div className="fixed inset-0 z-[200] flex items-center justify-center bg-black/90 p-4 backdrop-blur-sm">
      <motion.div
        initial={{ scale: 0.95, opacity: 0 }}
        animate={{ scale: 1, opacity: 1 }}
        className="w-full max-w-xl overflow-hidden rounded-2xl border border-amber-600/40 bg-stone-950 shadow-[0_0_40px_rgba(217,119,6,0.15)]"
      >
        <header className="border-b border-amber-800/40 bg-black/50 p-5 text-center">
          <h2 className="font-serif text-2xl font-black uppercase text-amber-200">
            {mode === "pvp" ? "Arena de Duelos" : "Modo Treino (Sandbox)"}
          </h2>
          <p className="mt-1 text-sm text-stone-400">
            {step === "deck" ? "Selecione o seu Grimório de Batalha" : "Selecione a Interface da Arena"}
          </p>
        </header>

        <div className="p-6">
          {step === "deck" && (
            <div className="space-y-4">
              {loading ? (
                <div className="py-10 text-center text-amber-500"><Loader2 className="mx-auto animate-spin" /></div>
              ) : decks.length > 0 ? (
                <div className="grid max-h-60 gap-2 overflow-y-auto pr-2 scrollbar-thin">
                  {decks.map(d => (
                    <button
                      key={d.id}
                      onClick={() => setSelectedDeck(d.id)}
                      className={`flex items-center justify-between rounded-xl border p-4 text-left transition-all ${selectedDeck === d.id ? "border-amber-400 bg-amber-950/40 shadow-[0_0_15px_rgba(251,191,36,0.15)]" : "border-stone-800 bg-black/40 hover:border-amber-700/50"}`}
                    >
                      <div>
                        <b className="block font-serif text-amber-100">{d.name}</b>
                        <span className="text-xs text-stone-500">Cartas: Padrão</span>
                      </div>
                      {selectedDeck === d.id && <ChevronRight className="text-amber-400" />}
                    </button>
                  ))}
                </div>
              ) : (
                <div className="rounded-xl border border-dashed border-red-800/40 bg-red-950/20 p-6 text-center text-red-200">
                  <Layers className="mx-auto mb-3 opacity-50" size={32} />
                  <p>Você não possui nenhum deck válido construído.</p>
                </div>
              )}

              <div className="pt-4">
                {decks.length > 0 ? (
                  <button
                    onClick={handleConfirmDeck}
                    disabled={!selectedDeck || busy}
                    className="w-full rounded-xl border border-amber-500 bg-amber-700 py-4 font-black uppercase tracking-wider text-amber-100 transition-transform active:scale-95 disabled:opacity-50"
                  >
                    Confirmar Grimório
                  </button>
                ) : (
                  <button
                    onClick={() => void handleGenerateDeck()}
                    disabled={busy}
                    className="flex w-full items-center justify-center gap-3 rounded-xl border-2 border-emerald-500 bg-emerald-900 py-4 font-black uppercase tracking-wider text-emerald-100 shadow-[0_0_20px_rgba(16,185,129,0.2)] transition-transform active:scale-95 disabled:opacity-50"
                  >
                    {busy ? <Loader2 className="animate-spin" /> : <Bot />}
                    Jogar com Deck Gerado Pelo Sistema
                  </button>
                )}
              </div>
            </div>
          )}

          {step === "version" && (
            <div className="grid gap-4 sm:grid-cols-2">
              <button
                onClick={() => handleConfirmVersion(false)}
                className="group relative flex flex-col items-center gap-4 overflow-hidden rounded-xl border-2 border-stone-700 bg-stone-900 p-6 text-center transition-all hover:border-blue-400 hover:bg-blue-950 hover:shadow-[0_0_30px_rgba(96,165,250,0.15)]"
              >
                <Monitor size={48} className="text-stone-400 group-hover:text-blue-300" />
                <div>
                  <b className="block font-serif text-lg text-stone-200 group-hover:text-blue-100">Versão PC / Desktop</b>
                  <span className="mt-2 block text-xs text-stone-500 group-hover:text-blue-200/70">Layout AAA completo com crônica lateral e grimório acoplado.</span>
                </div>
              </button>
              
              <button
                onClick={() => handleConfirmVersion(true)}
                className="group relative flex flex-col items-center gap-4 overflow-hidden rounded-xl border-2 border-amber-600 bg-stone-900 p-6 text-center transition-all hover:border-amber-400 hover:bg-amber-950 hover:shadow-[0_0_30px_rgba(251,191,36,0.2)]"
              >
                <Smartphone size={48} className="text-amber-500 group-hover:text-amber-300" />
                <div>
                  <b className="block font-serif text-lg text-amber-500 group-hover:text-amber-300">Versão Mobile Otimizada</b>
                  <span className="mt-2 block text-xs text-amber-500/70 group-hover:text-amber-200/80">Gavetas laterais, zoom otimizado e área de cartas expandida.</span>
                </div>
              </button>
            </div>
          )}
        </div>

        <footer className="border-t border-stone-800 bg-black/60 p-4 text-center">
          <button
            onClick={() => {
              if (step === "version") setStep("deck")
              else onCancel()
            }}
            className="text-xs font-bold uppercase tracking-widest text-stone-500 hover:text-stone-300"
          >
            {step === "version" ? "← Voltar aos Decks" : "Cancelar"}
          </button>
        </footer>
      </motion.div>
    </div>
  )
}
