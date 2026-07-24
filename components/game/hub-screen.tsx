"use client"

import { useEffect, useMemo, useState } from "react"
import { motion } from "framer-motion"
import { Beaker, Coins, Gem, Library, ScrollText, Search, Shield, Swords, Trophy, Users, Layers } from "lucide-react"
import { supabase } from "@/lib/supabase"
import { filtrosElemento, filtrosRaridade, type GameCard as GameCardType, type OfficialCardType, type Rarity } from "@/lib/game-data"
import type { Screen } from "@/lib/types"
import { GameCard } from "./game-card"
import { secureImageUrl } from "@/lib/secure-url"

interface Profile { username: string; avatar_url: string | null }
interface Stats { wins: number; losses: number; draws: number; ranked_rating: number; current_win_streak: number }

export function HubScreen({ onEnter }: { onEnter: (screen: Screen) => void }) {
  const [profile, setProfile] = useState<Profile | null>(null)
  const [stats, setStats] = useState<Stats | null>(null)
  const [coins, setCoins] = useState(0)
  const [cards, setCards] = useState<GameCardType[]>([])
  const [activeTab, setActiveTab] = useState<"library" | "decks">("library")
  const [showAlphaWarning, setShowAlphaWarning] = useState(false)
  const [rarity, setRarity] = useState<Rarity | null>(null)
  const [cardType, setCardType] = useState<OfficialCardType | null>(null)
  const [query, setQuery] = useState("")
  const [training, setTraining] = useState(false)
  const [error, setError] = useState<string | null>(null)
  const [trainingStep, setTrainingStep] = useState<string | null>(null)
  const [matchmaking, setMatchmaking] = useState(false)

  useEffect(() => {
    void supabase.auth.getUser().then(async ({ data }) => {
      if (!data.user) return
      const [profileResult, statsResult, walletResult, cardsResult] = await Promise.all([
        supabase.from("profiles").select("username,avatar_url").eq("id", data.user.id).single(),
        supabase.from("my_stats").select("wins,losses,draws,ranked_rating,current_win_streak").maybeSingle(),
        supabase.from("my_wallet").select("coins").maybeSingle(),
        supabase.from("cards").select("id,name,image_url,element,rarity,card_type,is_original_rpg,base_power,base_max_life,effect_mana_cost,effect_text,card_effects(effect_code)").eq("is_active", true).order("name"),
      ])
      if (profileResult.data) setProfile(profileResult.data)
      if (statsResult.data) setStats(statsResult.data)
      if (walletResult.data) setCoins(walletResult.data.coins)
      setCards((cardsResult.data ?? []).map((card: any) => ({ id: card.id, nome: card.name, image_url: card.image_url, elemento: card.element as OfficialCardType, raridade: card.rarity as Rarity, tipo: card.element, mana: card.effect_mana_cost, ataque: card.base_power, vida: card.base_max_life, efeito: card.effect_text ?? "", effect_definition: card.card_effects ?? [], is_original_rpg: card.is_original_rpg })))
    })
  }, [])

  const filtered = useMemo(() => cards.filter(card => (!rarity || card.raridade === rarity) && (!cardType || card.elemento === cardType) && (!query || card.nome.toLowerCase().includes(query.toLowerCase()))), [cardType, cards, query, rarity])
  const startTraining = async () => {
    setTraining(true); setError(null)
    try {
      setTrainingStep("Verificando sua sessão…")
      const { data: sessionData, error: sessionError } = await supabase.auth.getSession()
      if (sessionError) throw sessionError
      if (!sessionData.session) throw new Error("Sessão expirada. Entre novamente.")
      setTrainingStep("Montando dois decks de teste com 40 cartas…")
      const { data: trainingResult, error: matchError } = await supabase.rpc("create_training_match", { p_deck_size: 40 })
      if (matchError) throw matchError
      const matchId = typeof trainingResult === "string" ? trainingResult : trainingResult?.match_id
      if (!matchId) throw new Error("O servidor não retornou o match_id da nova partida.")
      const url = new URL(window.location.href); url.searchParams.set("screen", "arena"); url.searchParams.set("matchId", matchId); window.history.pushState({}, "", url); onEnter("arena")
    } catch (cause) {
      const issue = cause as { message?: string }
      if (issue?.message?.includes("CARD_CATALOG_EMPTY")) {
        const url = new URL(window.location.href); url.searchParams.set("screen", "arena"); url.searchParams.set("preview", "1"); url.searchParams.delete("matchId"); window.history.pushState({}, "", url); onEnter("arena")
      } else setError(describeError(cause))
    } finally { setTraining(false); setTrainingStep(null) }
  }

  const searchOpponent = async () => {
    setMatchmaking(true); setError(null)
    try {
      const { data: decks, error: deckError } = await supabase.from("decks").select("id").eq("is_valid", true).order("updated_at", { ascending: false }).limit(1)
      if (deckError) throw deckError
      if (!decks?.[0]?.id) throw new Error("Você precisa de um deck válido para buscar um oponente.")
      const { data: queueId, error: queueError } = await supabase.rpc("enqueue_matchmaking", { p_deck_id: decks[0].id, p_match_type: "friendly" })
      if (queueError) throw queueError
      setError(`Busca iniciada com sucesso. Fila: ${queueId}`)
    } catch (cause) { setError(describeError(cause)) } finally { setMatchmaking(false) }
  }

  return <main className="min-h-screen bg-stone-950 p-5 text-stone-100"><div className="mx-auto max-w-[1600px]">
    <header className="mb-5 flex flex-wrap items-center justify-between gap-4 rounded-xl border border-amber-700/40 bg-black/50 p-5">
      <div className="flex items-center gap-3">{profile?.avatar_url ? <img src={secureImageUrl(profile.avatar_url)} alt="" className="h-14 w-14 rounded-full border border-amber-400 object-cover" /> : <div className="flex h-14 w-14 items-center justify-center rounded-full border border-amber-500 bg-amber-950"><Shield /></div>}<div><h1 className="font-serif text-xl font-black text-amber-200">{profile?.username ?? "Jogador"}</h1>{stats && <p className="text-xs text-stone-400">Rating {stats.ranked_rating} · {stats.wins} vitórias · {stats.losses} derrotas · {stats.draws} empates</p>}</div></div>
      <nav className="flex flex-1 flex-wrap items-center justify-end gap-2" aria-label="Atalhos do lobby"><span className="flex items-center gap-2 rounded-full border border-amber-500/50 bg-black px-4 py-2 font-black text-amber-200"><Coins size={18} />{coins.toLocaleString("pt-BR")}</span><TopAction icon={Swords} label={training ? "CRIANDO…" : "MODO TREINO"} onClick={() => setShowAlphaWarning(true)} disabled={training} featured /><TopAction icon={Users} label={matchmaking ? "BUSCANDO…" : "BUSCAR OPONENTE"} onClick={() => void searchOpponent()} disabled={matchmaking} featured /><TopAction icon={Gem} label="LOJA" onClick={() => onEnter("store")} /><TopAction icon={Layers} label="MEUS DECKS" onClick={() => onEnter("decks")} /><TopAction icon={Library} label="CARTAS ADQUIRIDAS" onClick={() => onEnter("collection")} /><TopAction icon={Users} label="CONTATOS" onClick={() => onEnter("friends")} /><TopAction icon={ScrollText} label="ATUALIZAÇÕES" onClick={() => onEnter("patch-notes")} /></nav>
    </header>
    {error && <div className="mb-4 rounded border border-red-500/50 bg-red-950/60 p-3 text-red-200"><strong className="block text-xs uppercase tracking-wider">Aviso do lobby</strong>{error}</div>}
    {trainingStep && <div className="mb-4 rounded border border-blue-500/40 bg-blue-950/50 p-3 text-sm text-blue-100">{trainingStep}</div>}
    {stats && <div className="mb-5 grid grid-cols-2 gap-3 md:grid-cols-4"><Stat icon={Trophy} label="Vitórias" value={stats.wins} /><Stat icon={Shield} label="Derrotas" value={stats.losses} /><Stat icon={Swords} label="Empates" value={stats.draws} /><Stat icon={Trophy} label="Sequência atual" value={stats.current_win_streak} /></div>}
    <section className="rounded-xl border border-amber-800/30 bg-black/35 p-4"><div className="mb-4 flex flex-wrap items-center gap-2"><div className="relative min-w-60 flex-1"><Search className="absolute left-3 top-1/2 -translate-y-1/2 text-stone-500" size={16} /><input value={query} onChange={event => setQuery(event.target.value)} placeholder="Pesquisar no grimório" className="w-full rounded border border-amber-800/40 bg-black py-2 pl-9 pr-3 text-sm" /></div>{filtrosRaridade.map(filter => <button key={filter.key} onClick={() => setRarity(rarity === filter.key ? null : filter.key)} className={`rounded-full border px-3 py-1 text-xs ${rarity === filter.key ? "border-amber-300 text-amber-200" : "border-stone-700 text-stone-400"}`}>{filter.label}</button>)}</div>
      <div className="mb-5 flex flex-wrap gap-2">{filtrosElemento.map(filter => <button key={filter.key} onClick={() => setCardType(cardType === filter.key ? null : filter.key)} className={`rounded border px-3 py-1 text-xs ${cardType === filter.key ? "border-blue-400 bg-blue-950 text-blue-200" : "border-stone-700 text-stone-400"}`}>{filter.label}</button>)}</div>
      {filtered.length ? <div className="grid grid-cols-2 gap-4 sm:grid-cols-3 md:grid-cols-5 lg:grid-cols-7 xl:grid-cols-9">{filtered.map(card => <GameCard key={card.id} card={card} interactive />)}</div> : <div className="flex h-48 items-center justify-center rounded-lg border border-dashed border-amber-800/40 font-serif text-amber-200/70">Nenhuma carta encontrada no grimório</div>}
    </section>
    
    {showAlphaWarning && (
      <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/80 backdrop-blur-sm">
        <div className="w-[450px] max-w-[90vw] rounded-xl border border-amber-500/50 bg-stone-900 p-6 shadow-2xl">
          <h2 className="mb-4 text-center font-serif text-2xl font-black tracking-widest text-amber-500">AVISO DE FASE ALFA</h2>
          <p className="mb-6 text-center text-sm leading-relaxed text-stone-300">
            O Gwentofier está em fase Alfa de testes de engine. A maioria dos efeitos de cartas complexas pode não responder corretamente e a partida pode sofrer instabilidades ou travamentos. Nesta arena, você jogará contra o Autômato de Ofier utilizando decks aleatórios.
          </p>
          <div className="flex gap-4">
            <button onClick={() => setShowAlphaWarning(false)} className="flex-1 rounded border border-stone-600 bg-stone-800 py-3 font-bold text-stone-300 hover:bg-stone-700 transition-colors">CANCELAR</button>
            <button onClick={() => { setShowAlphaWarning(false); void startTraining(); }} className="flex-1 rounded border border-amber-600 bg-amber-900 py-3 font-bold text-amber-200 hover:bg-amber-800 shadow-[0_0_15px_rgba(217,119,6,0.3)] transition-colors">ENTRAR NA ARENA MESMO ASSIM</button>
          </div>
        </div>
      </div>
    )}
  </div></main>
}

function Stat({ icon: Icon, label, value }: { icon: typeof Trophy; label: string; value: number }) { return <motion.div whileHover={{ y: -2 }} className="rounded-lg border border-amber-800/30 bg-black/40 p-3"><Icon className="mb-2 text-amber-400" size={18} /><p className="text-xs text-stone-500">{label}</p><p className="text-xl font-black text-amber-100">{value}</p></motion.div> }
function TopAction({ icon: Icon, label, onClick, featured = false, disabled = false }: { icon: typeof Swords; label: string; onClick: () => void; featured?: boolean; disabled?: boolean }) { return <motion.button disabled={disabled} whileHover={{ y: -2 }} onClick={onClick} className={`rounded border px-3 py-2 text-[10px] font-black disabled:opacity-50 ${featured ? "border-emerald-400 bg-emerald-950 text-emerald-100" : "border-amber-700/60 bg-stone-900 text-amber-100"}`}><Icon className="mr-1 inline" size={14} />{label}</motion.button> }

function describeError(cause: unknown) { if (cause instanceof Error) return cause.message; if (cause && typeof cause === "object") { const issue = cause as { message?: string; details?: string; hint?: string; code?: string }; const parts = [issue.message, issue.details, issue.hint, issue.code ? `Código: ${issue.code}` : null].filter(Boolean); if (parts.length) return parts.join(" · ") } return `Erro desconhecido: ${String(cause)}` }
