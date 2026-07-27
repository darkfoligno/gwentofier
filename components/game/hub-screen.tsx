"use client"

import { useEffect, useMemo, useState } from "react"
import { motion } from "framer-motion"
import { Beaker, Coins, Gem, Library, ScrollText, Search, Shield, Swords, Trophy, Users, Layers, Lock } from "lucide-react"
import { useWallet } from "@/components/wallet-provider"
import { supabase } from "@/lib/supabase"
import { filtrosElemento, filtrosRaridade, type GameCard as GameCardType, type OfficialCardType, type Rarity } from "@/lib/game-data"
import type { Screen } from "@/lib/types"
import { GameCard } from "./game-card"
import { PreMatchModal } from "./pre-match-modal"
import { secureImageUrl } from "@/lib/secure-url"

interface Profile { username: string; avatar_url: string | null }
interface Stats { wins: number; losses: number; draws: number; ranked_rating: number; current_win_streak: number }

export function HubScreen({ onEnter }: { onEnter: (screen: Screen) => void }) {
  const [profile, setProfile] = useState<Profile | null>(null)
  const [stats, setStats] = useState<Stats | null>(null)
  const [cards, setCards] = useState<GameCardType[]>([])
  const [activeTab, setActiveTab] = useState<"library" | "decks">("library")
  const [showAlphaWarning, setShowAlphaWarning] = useState(false)
  const [rarity, setRarity] = useState<Rarity | null>(null)
  const [cardType, setCardType] = useState<OfficialCardType | null>(null)
  const [query, setQuery] = useState("")
  const [training, setTraining] = useState(false)
  const [error, setError] = useState<string | null>(null)
  const [trainingStep, setTrainingStep] = useState<string | null>(null)
  const [preMatchMode, setPreMatchMode] = useState<"pvp" | "training" | null>(null)
  const [matchmaking, setMatchmaking] = useState(false)
  const [userId, setUserId] = useState<string | null>(null)

  const { coins } = useWallet()

  useEffect(() => {
    void supabase.auth.getUser().then(async ({ data }) => {
      if (!data.user) return
      setUserId(data.user.id)
      const [profileResult, statsResult, cardsResult] = await Promise.all([
        supabase.from("profiles").select("username,avatar_url").eq("id", data.user.id).single(),
        supabase.from("my_stats").select("wins,losses,draws,ranked_rating,current_win_streak").maybeSingle(),
        supabase.from("cards").select("id,name,image_url,element,rarity,card_type,is_original_rpg,base_power,base_max_life,effect_mana_cost,effect_text,card_effects(effect_code)").eq("is_active", true).order("name"),
      ])
      if (profileResult.data) setProfile(profileResult.data)
      if (statsResult.data) setStats(statsResult.data)
      setCards((cardsResult.data ?? []).map((card: any) => ({ id: card.id, nome: card.name, image_url: card.image_url, elemento: card.element as OfficialCardType, raridade: card.rarity as Rarity, tipo: card.element, mana: card.effect_mana_cost, ataque: card.base_power, vida: card.base_max_life, efeito: card.effect_text ?? "", effect_definition: card.card_effects ?? [], is_original_rpg: card.is_original_rpg })))
    })
  }, [])

  const filtered = useMemo(() => cards.filter(card => (!rarity || card.raridade === rarity) && (!cardType || card.elemento === cardType) && (!query || card.nome.toLowerCase().includes(query.toLowerCase()))), [cardType, cards, query, rarity])
  
  const searchOpponent = async (deckId: string, isMobile: boolean) => {
    setMatchmaking(true); setError(null)
    try {
      const cleanDeckId = deckId === "SYSTEM_GENERATED" ? "00000000-0000-0000-0000-000000000000" : deckId
      const { data: queueId, error: queueError } = await supabase.rpc("enqueue_matchmaking", { p_deck_id: cleanDeckId, p_match_type: "friendly" })
      if (queueError) throw queueError
      setError(`Busca iniciada com sucesso. Fila: ${queueId}. (Mobile: ${isMobile})`)
      if (isMobile) window.localStorage.setItem('arena_mobile', 'true');
      else window.localStorage.removeItem('arena_mobile');
    } catch (cause) { setError(describeError(cause)) } finally { setMatchmaking(false) }
  }

  const startTrainingMatch = async (deckId: string, isMobile: boolean) => {
    setTraining(true); setError(null); setTrainingStep("Solicitando combate local ao servidor...")
    try {
      const { data: queueId, error: queueError } = await supabase.rpc("start_training_match", { p_deck_id: deckId })
      if (queueError) throw queueError
      setTrainingStep("Sala de treino criada. Abrindo arena...")
      if (isMobile) window.localStorage.setItem('arena_mobile', 'true');
      else window.localStorage.removeItem('arena_mobile');
      await new Promise(r => setTimeout(r, 600))
      const url = new URL(window.location.href); url.searchParams.set("screen", "arena"); url.searchParams.set("matchId", queueId); url.searchParams.delete("preview"); window.history.pushState({}, "", url); onEnter("arena")
    } catch (cause) {
      const issue = cause as { message?: string }
      if (issue?.message?.includes("CARD_CATALOG_EMPTY")) {
        const url = new URL(window.location.href); url.searchParams.set("screen", "arena"); url.searchParams.set("preview", "1"); url.searchParams.delete("matchId"); window.history.pushState({}, "", url); onEnter("arena")
      } else setError(describeError(cause))
    } finally { setTraining(false); setTrainingStep(null) }
  }

  const handlePreMatchConfirm = (deckId: string, isMobile: boolean) => {
    const mode = preMatchMode
    setPreMatchMode(null)
    if (mode === "pvp") void searchOpponent(deckId, isMobile)
    else if (mode === "training") void startTrainingMatch(deckId, isMobile)
  }

  const isTestUser = userId === "b6cd0821-39ae-451f-a8ca-25694c3e553c"

  return <main className="min-h-screen bg-stone-950 p-5 text-stone-100"><div className="mx-auto max-w-[1600px]">
    <header className="mb-5 flex flex-wrap items-center justify-between gap-4 rounded-xl border border-amber-700/40 bg-black/50 p-5">
      <div className="flex items-center gap-3">{profile?.avatar_url ? <img src={secureImageUrl(profile.avatar_url)} alt="" className="h-14 w-14 rounded-full border border-amber-400 object-cover" /> : <div className="flex h-14 w-14 items-center justify-center rounded-full border border-amber-500 bg-amber-950"><Shield /></div>}<div><h1 className="font-serif text-xl font-black text-amber-200">{profile?.username ?? "Jogador"}</h1>{stats && <p className="text-xs text-stone-400">Rating {stats.ranked_rating} · {stats.wins} vitórias · {stats.losses} derrotas · {stats.draws} empates</p>}</div></div>
      <nav className="flex flex-1 flex-wrap items-center justify-end gap-2" aria-label="Atalhos do lobby">
        <span className="flex items-center gap-2 rounded-full border border-amber-500/50 bg-black px-4 py-2 font-black text-amber-200"><Coins size={18} />{coins.toLocaleString("pt-BR")}</span>
        <TopAction 
          icon={isTestUser ? Swords : Lock} 
          label={training ? "CRIANDO…" : "MODO TREINO"} 
          onClick={() => { if (isTestUser) setShowAlphaWarning(true) }} 
          disabled={training || !isTestUser} 
          featured={isTestUser} 
          locked={!isTestUser}
        />
        <TopAction icon={Swords} label={matchmaking ? "BUSCANDO…" : "BUSCAR OPONENTE"} onClick={() => setPreMatchMode("pvp")} disabled={matchmaking} featured />
        <TopAction icon={Gem} label="LOJA" onClick={() => onEnter("store")} />
        <TopAction icon={Layers} label="MEUS DECKS" onClick={() => onEnter("decks")} />
        <TopAction icon={Users} label="DUELISTAS" onClick={() => onEnter("friends")} />
        <TopAction icon={ScrollText} label="ATUALIZAÇÕES" onClick={() => onEnter("patch-notes")} />
      </nav>
    </header>
    {error && <div className="mb-4 rounded border border-red-500/50 bg-red-950/60 p-3 text-red-200"><strong className="block text-xs uppercase tracking-wider">Aviso do lobby</strong>{error}</div>}
    {trainingStep && <div className="mb-4 rounded border border-blue-500/40 bg-blue-950/50 p-3 text-sm text-blue-100">{trainingStep}</div>}
    {stats && <div className="mb-5 grid grid-cols-2 gap-3 md:grid-cols-4"><Stat icon={Trophy} label="Vitórias" value={stats.wins} /><Stat icon={Shield} label="Derrotas" value={stats.losses} /><Stat icon={Swords} label="Empates" value={stats.draws} /><Stat icon={Trophy} label="Sequência atual" value={stats.current_win_streak} /></div>}
    <section className="rounded-xl border border-amber-800/30 bg-black/35 p-4">
      <div className="mb-4 flex flex-wrap items-center gap-2">
        <div className="relative min-w-60 flex-1">
          <Search className="absolute left-3 top-1/2 -translate-y-1/2 text-stone-500" size={16} />
          <input value={query} onChange={event => setQuery(event.target.value)} placeholder="Pesquisar no grimório" className="w-full rounded border border-amber-800/40 bg-black py-2 pl-9 pr-3 text-sm" />
        </div>
        {filtrosRaridade.map(filter => (
          <button 
            key={filter.key} 
            onClick={() => setRarity(rarity === filter.key ? null : filter.key)} 
            className={`rounded-full border px-3.5 py-1 text-[11px] font-serif tracking-wider transition-all duration-200 ${
              rarity === filter.key 
                ? "border-amber-400 bg-amber-950/30 text-amber-200 shadow-[0_0_10px_rgba(245,158,11,0.25)]" 
                : "border-stone-800 bg-stone-950/50 text-stone-400 hover:border-stone-700 hover:text-stone-300"
            }`}
          >
            {filter.label}
          </button>
        ))}
      </div>
      <div className="mb-5 flex flex-wrap gap-2">
        {filtrosElemento.map(filter => (
          <button 
            key={filter.key} 
            onClick={() => setCardType(cardType === filter.key ? null : filter.key)} 
            className={`rounded border px-3.5 py-1 text-[11px] font-serif tracking-wider transition-all duration-200 ${
              cardType === filter.key 
                ? "border-amber-500 bg-amber-950/30 text-amber-200 shadow-[0_0_10px_rgba(194,155,56,0.2)]" 
                : "border-stone-800 bg-stone-950/50 text-stone-400 hover:border-stone-700 hover:text-stone-300"
            }`}
          >
            {filter.label}
          </button>
        ))}
      </div>
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
            <button onClick={() => setShowAlphaWarning(false)} className="flex-1 rounded border border-stone-600 bg-stone-800 py-3 text-xs font-black uppercase text-stone-300">
              VOLTAR
            </button>
            <button onClick={() => { setShowAlphaWarning(false); setPreMatchMode("training"); }} className="flex-1 rounded border border-amber-500 bg-amber-700 py-3 text-xs font-black uppercase text-amber-100 shadow-[0_0_15px_rgba(217,119,6,0.3)]">
              ACEITAR E CONTINUAR
            </button>
          </div>
        </div>
      </div>
    )}
    
    <PreMatchModal mode={preMatchMode} onCancel={() => setPreMatchMode(null)} onConfirm={handlePreMatchConfirm} />
  </div></main>
}

function Stat({ icon: Icon, label, value }: { icon: typeof Trophy; label: string; value: number }) { return <motion.div whileHover={{ y: -2 }} className="rounded-lg border border-amber-800/30 bg-black/40 p-3"><Icon className="mb-2 text-amber-400" size={18} /><p className="text-xs text-stone-500">{label}</p><p className="text-xl font-black text-amber-100">{value}</p></motion.div> }

function TopAction({ 
  icon: Icon, 
  label, 
  onClick, 
  featured = false, 
  disabled = false, 
  locked = false 
}: { 
  icon: any; 
  label: string; 
  onClick: () => void; 
  featured?: boolean; 
  disabled?: boolean; 
  locked?: boolean 
}) { 
  return (
    <motion.button 
      disabled={disabled} 
      whileHover={locked ? undefined : { y: -2, scale: 1.03 }} 
      whileTap={locked ? undefined : { scale: 0.97 }} 
      onClick={onClick} 
      className={`relative overflow-hidden rounded-lg px-4.5 py-2.5 text-[11px] font-serif font-black tracking-widest uppercase transition-all duration-300 flex items-center gap-1.5 shadow-[0_4px_12px_rgba(0,0,0,0.6)] border ${
        locked 
          ? "border-stone-850 bg-stone-900/30 text-stone-600 cursor-not-allowed opacity-50" 
          : featured 
            ? "border-emerald-500/80 bg-gradient-to-b from-stone-900 via-stone-950 to-emerald-950/40 text-emerald-300 hover:text-emerald-100 hover:border-emerald-400 hover:shadow-[0_0_15px_rgba(16,185,129,0.3)]" 
            : "border-amber-600/70 bg-gradient-to-b from-stone-900 via-stone-950 to-amber-950/20 text-amber-200 hover:text-amber-100 hover:border-amber-400 hover:shadow-[0_0_15px_rgba(194,155,56,0.3)]"
      }`}
    >
      {!locked && (
        <span className="absolute inset-x-0 bottom-0 h-[1.5px] bg-gradient-to-r from-transparent via-amber-500/30 to-transparent" />
      )}
      <Icon className={locked ? "text-stone-600" : "text-amber-500 transition-colors"} size={14} />
      <span>{label}</span>
    </motion.button>
  )
}

function describeError(cause: unknown) { if (cause instanceof Error) return cause.message; if (cause && typeof cause === "object") { const issue = cause as { message?: string; details?: string; hint?: string; code?: string }; const parts = [issue.message, issue.details, issue.hint, issue.code ? `Código: ${issue.code}` : null].filter(Boolean); if (parts.length) return parts.join(" · ") } return `Erro desconhecido: ${String(cause)}` }
