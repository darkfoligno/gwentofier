"use client"

import { useEffect, useMemo, useState } from "react"
import { AnimatePresence, motion } from "framer-motion"
import { BookOpen, Coins, Gem, Library, ScrollText, Search, Shield, Swords, Trophy, Users, Layers } from "lucide-react"
import { supabase } from "@/lib/supabase"
import { filtrosElemento, filtrosRaridade, type GameCard as GameCardType, type OfficialCardType, type Rarity } from "@/lib/game-data"
import type { Screen } from "@/lib/types"
import { GameCard } from "./game-card"

interface Profile { username: string; avatar_url: string | null }
interface Stats { wins: number; losses: number; draws: number; ranked_rating: number; current_win_streak: number }

export function HubScreen({ onEnter }: { onEnter: (screen: Screen) => void }) {
  const [profile, setProfile] = useState<Profile | null>(null)
  const [stats, setStats] = useState<Stats | null>(null)
  const [coins, setCoins] = useState(0)
  const [cards, setCards] = useState<GameCardType[]>([])
  const [rarity, setRarity] = useState<Rarity | null>(null)
  const [cardType, setCardType] = useState<OfficialCardType | null>(null)
  const [query, setQuery] = useState("")
  const [training, setTraining] = useState(false)
  const [error, setError] = useState<string | null>(null)
  const [patchNotesOpen, setPatchNotesOpen] = useState(false)

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
      setCards((cardsResult.data ?? []).map((card: any) => ({ id: card.id, nome: card.name, image_url: card.image_url, elemento: card.element as OfficialCardType, raridade: card.rarity as Rarity, tipo: card.card_type, mana: card.effect_mana_cost, ataque: card.base_power, vida: card.base_max_life, efeito: card.effect_text ?? "", effect_definition: card.card_effects ?? [], is_original_rpg: card.is_original_rpg })))
    })
  }, [])

  const filtered = useMemo(() => cards.filter(card => (!rarity || card.raridade === rarity) && (!cardType || card.elemento === cardType) && (!query || card.nome.toLowerCase().includes(query.toLowerCase()))), [cardType, cards, query, rarity])
  const startTraining = async () => {
    setTraining(true); setError(null)
    try {
      const { data: sessionData } = await supabase.auth.getSession()
      if (!sessionData.session) throw new Error("Sessão expirada. Entre novamente.")
      const { data: decks, error: deckError } = await supabase.from("decks").select("id").eq("is_valid", true).order("updated_at", { ascending: false }).limit(1)
      if (deckError) throw deckError
      let deckId = decks?.[0]?.id
      if (!deckId) {
        const { data, error: starterError } = await supabase.rpc("claim_starter_deck", { p_deck_name: "Deck Inicial" })
        if (starterError) throw starterError
        deckId = data?.deck_id
      }
      if (!deckId) throw new Error("Não foi possível obter um deck válido.")
      const { data: matchId, error: matchError } = await supabase.rpc("create_match", { p_deck_id: deckId, p_match_type: "friendly", p_is_private: true })
      if (matchError) throw matchError
      const url = new URL(window.location.href); url.searchParams.set("screen", "arena"); url.searchParams.set("matchId", matchId); window.history.pushState({}, "", url); onEnter("arena")
    } catch (cause) { setError(cause instanceof Error ? cause.message : "Não foi possível iniciar o treino.") } finally { setTraining(false) }
  }

  return <main className="min-h-screen bg-stone-950 p-5 text-stone-100"><div className="mx-auto max-w-[1600px]">
    <header className="mb-5 flex flex-wrap items-center justify-between gap-4 rounded-xl border border-amber-700/40 bg-black/50 p-5">
      <div className="flex items-center gap-3">{profile?.avatar_url ? <img src={profile.avatar_url} alt="" className="h-14 w-14 rounded-full border border-amber-400 object-cover" /> : <div className="flex h-14 w-14 items-center justify-center rounded-full border border-amber-500 bg-amber-950"><Shield /></div>}<div><h1 className="font-serif text-xl font-black text-amber-200">{profile?.username ?? "Jogador"}</h1>{stats && <p className="text-xs text-stone-400">Rating {stats.ranked_rating} · {stats.wins} vitórias · {stats.losses} derrotas · {stats.draws} empates</p>}</div></div>
      <div className="flex items-center gap-3"><span className="flex items-center gap-2 rounded-full border border-amber-500/50 bg-black px-4 py-2 font-black text-amber-200"><Coins size={18} />{coins.toLocaleString("pt-BR")}</span><button onClick={() => onEnter("store")} className="rounded border border-purple-500 bg-purple-950 px-4 py-2 text-xs font-black text-purple-200"><Gem className="mr-1 inline" size={15} /> LOJA</button><button disabled={training} onClick={() => void startTraining()} className="rounded border border-blue-400 bg-blue-950 px-4 py-2 text-xs font-black text-blue-100 disabled:opacity-50"><Swords className="mr-1 inline" size={15} /> {training ? "CRIANDO..." : "MODO TREINO"}</button></div>
    </header>
    {error && <div className="mb-4 rounded border border-red-500/50 bg-red-950/60 p-3 text-red-200">{error}</div>}
    <section className="mb-5 grid gap-3 sm:grid-cols-2 lg:grid-cols-4">
      <LobbyAction featured icon={Swords} title="MODO TREINO (VS IA / TESTE)" onClick={() => void startTraining()} disabled={training} />
      <LobbyAction icon={Gem} title="LOJA DE OFIER" onClick={() => onEnter("store")} />
      <LobbyAction icon={Layers} title="MEUS DECKS" onClick={() => setError("O construtor de decks ainda não possui uma tela dedicada.")} />
      <LobbyAction icon={Library} title="MINHAS CARTAS" onClick={() => window.scrollTo({ top: document.body.scrollHeight, behavior: "smooth" })} />
      <LobbyAction icon={Users} title="DUELOS EM ANDAMENTO" onClick={() => onEnter("spectator")} />
      <LobbyAction icon={Users} title="AMIGOS & CONVITES" onClick={() => setError("O lobby de contatos ainda não possui uma tela dedicada.")} />
      <LobbyAction icon={BookOpen} title="MODO HISTÓRIA (CAMPANHA)" onClick={() => setError("Nenhuma campanha foi selecionada.")} />
      <LobbyAction icon={ScrollText} title="NOTAS DE ATUALIZAÇÃO" onClick={() => setPatchNotesOpen(true)} />
    </section>
    {stats && <div className="mb-5 grid grid-cols-2 gap-3 md:grid-cols-4"><Stat icon={Trophy} label="Vitórias" value={stats.wins} /><Stat icon={Shield} label="Derrotas" value={stats.losses} /><Stat icon={Swords} label="Empates" value={stats.draws} /><Stat icon={Trophy} label="Sequência atual" value={stats.current_win_streak} /></div>}
    <section className="rounded-xl border border-amber-800/30 bg-black/35 p-4"><div className="mb-4 flex flex-wrap items-center gap-2"><div className="relative min-w-60 flex-1"><Search className="absolute left-3 top-1/2 -translate-y-1/2 text-stone-500" size={16} /><input value={query} onChange={event => setQuery(event.target.value)} placeholder="Pesquisar no grimório" className="w-full rounded border border-amber-800/40 bg-black py-2 pl-9 pr-3 text-sm" /></div>{filtrosRaridade.map(filter => <button key={filter.key} onClick={() => setRarity(rarity === filter.key ? null : filter.key)} className={`rounded-full border px-3 py-1 text-xs ${rarity === filter.key ? "border-amber-300 text-amber-200" : "border-stone-700 text-stone-400"}`}>{filter.label}</button>)}</div>
      <div className="mb-5 flex flex-wrap gap-2">{filtrosElemento.map(filter => <button key={filter.key} onClick={() => setCardType(cardType === filter.key ? null : filter.key)} className={`rounded border px-3 py-1 text-xs ${cardType === filter.key ? "border-blue-400 bg-blue-950 text-blue-200" : "border-stone-700 text-stone-400"}`}>{filter.label}</button>)}</div>
      {filtered.length ? <div className="grid grid-cols-2 gap-4 sm:grid-cols-3 md:grid-cols-5 lg:grid-cols-7 xl:grid-cols-9">{filtered.map(card => <GameCard key={card.id} card={card} interactive />)}</div> : <div className="flex h-48 items-center justify-center rounded-lg border border-dashed border-amber-800/40 font-serif text-amber-200/70">Nenhuma carta encontrada no grimório</div>}
    </section>
    <AnimatePresence>{patchNotesOpen && <motion.div initial={{ opacity: 0 }} animate={{ opacity: 1 }} exit={{ opacity: 0 }} onClick={() => setPatchNotesOpen(false)} className="fixed inset-0 z-[350] flex items-center justify-center bg-black/85 p-5"><div onClick={event => event.stopPropagation()} className="w-full max-w-lg rounded-xl border border-amber-500/50 bg-stone-950 p-6"><h2 className="font-serif text-2xl font-black text-amber-200">ofieri-1.0</h2><p className="mt-4 leading-relaxed text-stone-300">Interface autoritativa com Arena, Loja de Ofier, gestão de perfil e modo espectador baseado exclusivamente no estado público das partidas.</p><button onClick={() => setPatchNotesOpen(false)} className="mt-6 rounded border border-amber-500 bg-amber-800 px-5 py-2 text-xs font-black">FECHAR</button></div></motion.div>}</AnimatePresence>
  </div></main>
}

function Stat({ icon: Icon, label, value }: { icon: typeof Trophy; label: string; value: number }) { return <motion.div whileHover={{ y: -2 }} className="rounded-lg border border-amber-800/30 bg-black/40 p-3"><Icon className="mb-2 text-amber-400" size={18} /><p className="text-xs text-stone-500">{label}</p><p className="text-xl font-black text-amber-100">{value}</p></motion.div> }
function LobbyAction({ icon: Icon, title, onClick, featured = false, disabled = false }: { icon: typeof Swords; title: string; onClick: () => void; featured?: boolean; disabled?: boolean }) { return <motion.button disabled={disabled} whileHover={{ y: -3 }} onClick={onClick} className={`flex min-h-24 items-center gap-3 rounded-xl border p-4 text-left shadow-xl disabled:opacity-50 ${featured ? "border-emerald-400 bg-gradient-to-br from-amber-900/70 to-emerald-950 text-amber-100" : "border-amber-800/40 bg-gradient-to-br from-stone-900 to-black text-stone-200"}`}><span className="rounded-lg border border-amber-500/40 bg-black/40 p-3"><Icon className={featured ? "text-emerald-300" : "text-amber-400"} /></span><b className="font-serif text-xs leading-relaxed">{title}</b></motion.button> }
