"use client"

import { useEffect, useMemo, useState } from "react"
import { AnimatePresence, motion } from "framer-motion"
import { Coins, Gem, Library, ScrollText, Search, Shield, Swords, Trophy, Users, Layers, Lock, Wallet, ChevronRight, ArrowRightLeft, Gamepad2, Copy, Check, X } from "lucide-react"
import { useWallet } from "@/components/wallet-provider"
import { supabase } from "@/lib/supabase"
import { filtrosElemento, filtrosRaridade, type GameCard as GameCardType, type OfficialCardType, type Rarity } from "@/lib/game-data"
import type { Screen } from "@/lib/types"
import { GameCard } from "./game-card"
import { DailyRewardWidget } from "./daily-reward-widget"
import { PreMatchModal } from "./pre-match-modal"
import { secureImageUrl } from "@/lib/secure-url"
import { GachaModal } from "./gacha-modal"

interface Profile { id: string; username: string; avatar_url: string | null }
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
  const [inQueue, setInQueue] = useState(false)
  const [userId, setUserId] = useState<string | null>(null)
  const [gachaCards, setGachaCards] = useState<GameCardType[] | null>(null)
  const [inspectedCard, setInspectedCard] = useState<GameCardType | null>(null)
  const [copied, setCopied] = useState(false)

  const handleCopyId = async (id: string) => {
    try {
      await navigator.clipboard.writeText(id)
      setCopied(true)
      setTimeout(() => setCopied(false), 2000)
    } catch (cause) {
      console.error("Erro ao copiar ID", cause)
    }
  }

  const { coins, refresh: refreshWallet } = useWallet()

  const hydrateGacha = async (results: any[]) => {
    const ids = results.map(card => card.card_id)
    const { data } = await supabase.from("cards").select("id,name,image_url,element,rarity,card_type,is_original_rpg,base_power,base_max_life,effect_mana_cost,effect_text,card_effects(effect_code)").in("id", ids)
    const byId = new Map((data ?? []).map((card: any) => [card.id, card]))
    return results.map(result => { const card: any = byId.get(result.card_id); return { id: result.card_id, nome: result.name, image_url: result.image_url, elemento: (["Bestiário", "M&F", "Witcher", "Elfica", "Cívil", "Vampiro"].includes(card?.element) ? card.element : "Bestiário") as GameCardType["elemento"], raridade: result.rarity, tipo: card?.element ?? "Bestiário", mana: card?.effect_mana_cost ?? 0, ataque: card?.base_power ?? 0, vida: card?.base_max_life ?? 1, efeito: card?.effect_text ?? "", effect_definition: card?.card_effects ?? [], is_original_rpg: card?.is_original_rpg ?? false } })
  }

  const handleDailyRewardClaimSuccess = async (data: any) => {
    if (data && data.cards && data.cards.length > 0) {
      const hydrated = await hydrateGacha(data.cards)
      setGachaCards(hydrated)
    }
    await refreshWallet()
  }

  useEffect(() => {
    void supabase.auth.getUser().then(async ({ data }) => {
      if (!data.user) return
      setUserId(data.user.id)
      const [profileResult, statsResult, cardsResult] = await Promise.all([
        supabase.from("profiles").select("id,username,avatar_url").eq("id", data.user.id).single(),
        supabase.from("my_stats").select("wins,losses,draws,ranked_rating,current_win_streak").maybeSingle(),
        supabase.from("cards").select("id,name,image_url,element,rarity,card_type,is_original_rpg,base_power,base_max_life,effect_mana_cost,effect_text,card_effects(effect_code)").eq("is_active", true).order("name"),
      ])
      if (profileResult.data) setProfile(profileResult.data)
      if (statsResult.data) setStats(statsResult.data)
      setCards((cardsResult.data ?? []).map((card: any) => ({ id: card.id, nome: card.name, image_url: card.image_url, elemento: card.element as OfficialCardType, raridade: card.rarity as Rarity, tipo: card.element, mana: card.effect_mana_cost, ataque: card.base_power, vida: card.base_max_life, efeito: card.effect_text ?? "", effect_definition: card.card_effects ?? [], is_original_rpg: card.is_original_rpg })))
    })
  }, [])

  useEffect(() => {
    if (!inQueue || !userId) return

    console.log("[MATCHMAKING] Iniciando escuta realtime para o canal de fila do usuário:", userId)
    const channel = supabase.channel(`matchmaking:${userId}`)
      .on(
        "postgres_changes",
        {
          event: "UPDATE",
          schema: "public",
          table: "matchmaking_queue",
          filter: `user_id=eq.${userId}`
        },
        async (payload) => {
          console.log("[MATCHMAKING] Mudança na fila detectada:", payload)
          if (payload.new.status === "matched") {
            setError("Partida encontrada! Redirecionando para a Arena...")
            setInQueue(false)
            
            // Consultar a partida ativa correspondente do jogador para obter o match_id
            const { data, error: matchError } = await supabase
              .from("match_players")
              .select("match_id, matches!inner(status)")
              .eq("user_id", userId)
              .in("matches.status", ["ban_phase", "setup", "initiative", "in_progress"])
              .order("joined_at", { ascending: false })
              .limit(1)
              .maybeSingle()

            if (matchError) {
              console.error("Erro ao buscar match_id:", matchError)
              setError("Pareamento concluído, mas houve erro ao obter ID da sala.")
              return
            }

            const activeMatchId = data?.match_id
            if (activeMatchId) {
              const url = new URL(window.location.href)
              url.searchParams.set("screen", "arena")
              url.searchParams.set("matchId", activeMatchId)
              url.searchParams.delete("preview")
              window.history.pushState({}, "", url)
              onEnter("arena")
            } else {
              setError("Pareamento concluído, mas nenhuma sala ativa foi localizada.")
            }
          }
        }
      )
      .subscribe()

    return () => {
      console.log("[MATCHMAKING] Desinscrevendo canal realtime de matchmaking.")
      void supabase.removeChannel(channel)
    }
  }, [inQueue, userId, onEnter])

  const filtered = useMemo(() => cards.filter(card => (!rarity || card.raridade === rarity) && (!cardType || card.elemento === cardType) && (!query || card.nome.toLowerCase().includes(query.toLowerCase()) || (card.efeito || "").toLowerCase().includes(query.toLowerCase()))), [cardType, cards, query, rarity])
  
  const searchOpponent = async (deckId: string, isMobile: boolean) => {
    setMatchmaking(true); setError(null)
    try {
      const cleanDeckId = deckId === "SYSTEM_GENERATED" ? "00000000-0000-0000-0000-000000000000" : deckId
      const { data: queueId, error: queueError } = await supabase.rpc("enqueue_matchmaking", { p_deck_id: cleanDeckId, p_match_type: "friendly" })
      if (queueError) throw queueError
      setError(`Busca iniciada com sucesso. Fila ativa. Aguardando oponente...`)
      setInQueue(true)
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
      const url = new URL(window.location.href); url.searchParams.set("screen", "training"); url.searchParams.set("matchId", queueId); url.searchParams.delete("preview"); window.history.pushState({}, "", url); onEnter("training")
    } catch (cause) {
      const issue = cause as { message?: string }
      if (issue?.message?.includes("CARD_CATALOG_EMPTY")) {
        const url = new URL(window.location.href); url.searchParams.set("screen", "training"); url.searchParams.set("preview", "1"); url.searchParams.delete("matchId"); window.history.pushState({}, "", url); onEnter("training")
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
          onClick={() => { if (isTestUser) setPreMatchMode("training") }} 
          disabled={training || !isTestUser} 
          featured={isTestUser} 
          locked={!isTestUser}
        />
        {isTestUser && (
          <TopAction 
            icon={Gamepad2} 
            label="MODO CAMPANHA" 
            onClick={() => onEnter("campaign")} 
            featured 
          />
        )}
        <TopAction icon={Swords} label={matchmaking || inQueue ? "BUSCANDO…" : "BUSCAR OPONENTE"} onClick={() => setPreMatchMode("pvp")} disabled={matchmaking || inQueue} featured />
        <TopAction icon={Wallet} label="LOJA" onClick={() => onEnter("store")} />
        <TopAction icon={ArrowRightLeft} label="TRADE MARKETING" onClick={() => onEnter("trade")} />
        <TopAction icon={Layers} label="MINHAS CARTAS" onClick={() => onEnter("decks")} />
        <TopAction icon={Users} label="DUELISTAS" onClick={() => onEnter("friends")} />
        <TopAction icon={ScrollText} label="ATUALIZAÇÕES" onClick={() => onEnter("patch-notes")} />
      </nav>
    </header>
    {error && <div className="mb-4 rounded border border-red-500/50 bg-red-950/60 p-3 text-red-200"><strong className="block text-xs uppercase tracking-wider">Aviso do lobby</strong>{error}</div>}
    {trainingStep && <div className="mb-4 rounded border border-blue-500/40 bg-blue-950/50 p-3 text-sm text-blue-100">{trainingStep}</div>}
    <div className="mb-5">
      <DailyRewardWidget onClaimSuccess={handleDailyRewardClaimSuccess} />
    </div>
    {stats && <div className="mb-5 grid grid-cols-2 gap-3 md:grid-cols-4"><Stat icon={Trophy} label="Vitórias" value={stats.wins} /><Stat icon={Shield} label="Derrotas" value={stats.losses} /><Stat icon={Swords} label="Empates" value={stats.draws} /><Stat icon={Trophy} label="Sequência atual" value={stats.current_win_streak} /></div>}


    <section className="w-full h-full overflow-y-auto pb-32 rounded-xl border border-amber-800/30 bg-black/35 p-4">
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
      {filtered.length ? (
        <div className="grid grid-cols-2 gap-4 sm:grid-cols-3 md:grid-cols-5 lg:grid-cols-7 xl:grid-cols-9">
          {filtered.map(card => (
            <div key={card.id} onClick={() => setInspectedCard(card)} className="cursor-pointer">
              <GameCard card={card} interactive enableZoom={false} />
            </div>
          ))}
        </div>
      ) : <div className="flex h-48 items-center justify-center rounded-lg border border-dashed border-amber-800/40 font-serif text-amber-200/70">Nenhuma carta encontrada no grimório</div>}
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
    
    {inspectedCard && (
      <div className="fixed inset-0 z-[300] flex items-center justify-center bg-black/90 p-4 backdrop-blur-md" onClick={() => setInspectedCard(null)}>
        <div className="relative w-[750px] max-w-[95vw] rounded-2xl border-2 border-amber-500/60 bg-stone-900 shadow-2xl p-6 flex flex-col md:flex-row gap-6 items-center md:items-start text-stone-100" onClick={e => e.stopPropagation()}>
          <button onClick={() => setInspectedCard(null)} className="absolute -right-3 -top-3 rounded-full border border-red-500 bg-red-950/90 hover:bg-red-900 p-2 text-red-200 hover:text-white transition-colors shadow-lg z-50">
            <X size={16} />
          </button>
          
          {/* Left side: Card Render */}
          <div className="w-[240px] flex-shrink-0">
            <GameCard card={inspectedCard} enableZoom={false} />
          </div>

          {/* Right side: Detailed typography and info */}
          <div className="flex-1 flex flex-col h-full justify-between self-stretch">
            <div>
              <div className="flex items-center justify-between mb-2">
                <span className={`text-[10px] font-bold tracking-widest uppercase px-2.5 py-1 rounded border font-serif ${
                  inspectedCard.raridade === 'legendary' ? 'border-amber-500 bg-amber-950/40 text-amber-200 shadow-[0_0_8px_rgba(245,158,11,0.2)]' :
                  inspectedCard.raridade === 'epic' ? 'border-purple-500 bg-purple-950/40 text-purple-200 shadow-[0_0_8px_rgba(168,85,247,0.2)]' :
                  inspectedCard.raridade === 'rare' ? 'border-blue-500 bg-blue-950/40 text-blue-200 shadow-[0_0_8px_rgba(59,130,246,0.2)]' :
                  'border-zinc-700 bg-zinc-950/40 text-zinc-300'
                }`}>{inspectedCard.raridade}</span>
                <span className="text-[11px] font-serif font-bold tracking-widest uppercase text-stone-400">{inspectedCard.elemento}</span>
              </div>
              
              <div className="flex items-center justify-between gap-4 mb-4">
                <h2 className="font-serif text-2xl font-black text-amber-200 tracking-wider m-0">{inspectedCard.nome}</h2>
                <button 
                  onClick={() => handleCopyId(inspectedCard.id)}
                  className={`flex items-center gap-1.5 rounded-lg border px-3 py-1.5 font-serif text-[10px] font-black uppercase transition-all duration-200 ${
                    copied 
                      ? "border-emerald-500 bg-emerald-950/40 text-emerald-300 shadow-[0_0_10px_rgba(16,185,129,0.2)]"
                      : "border-stone-700 bg-black/40 text-stone-400 hover:border-amber-500/50 hover:text-amber-200"
                  }`}
                  title="Copiar ID da Carta"
                >
                  {copied ? <Check size={12} className="text-emerald-400" /> : <Copy size={12} />}
                  {copied ? "Copiado!" : "Copiar ID"}
                </button>
              </div>
              
              {/* Atributos / Stats Grid */}
              <div className="grid grid-cols-3 gap-3 mb-5">
                <div className="rounded-lg border border-blue-500/20 bg-blue-950/20 p-2 text-center shadow-inner">
                  <span className="block text-[9px] font-bold text-blue-400 uppercase tracking-widest mb-0.5">Mana</span>
                  <span className="text-lg font-bold font-mono text-blue-200">{inspectedCard.mana}</span>
                </div>
                <div className="rounded-lg border border-amber-500/20 bg-amber-950/20 p-2 text-center shadow-inner">
                  <span className="block text-[9px] font-bold text-amber-400 uppercase tracking-widest mb-0.5">Poder</span>
                  <span className="text-lg font-bold font-mono text-amber-200">{inspectedCard.ataque}</span>
                </div>
                <div className="rounded-lg border border-red-500/20 bg-red-950/20 p-2 text-center shadow-inner">
                  <span className="block text-[9px] font-bold text-red-400 uppercase tracking-widest mb-0.5">Vida</span>
                  <span className="text-lg font-bold font-mono text-red-200">{inspectedCard.vida}</span>
                </div>
              </div>

              <div className="border border-amber-900/30 bg-black/60 rounded-xl p-4 mb-6 shadow-inner">
                <h4 className="text-[10px] font-serif font-bold text-amber-500 uppercase tracking-widest mb-2">Efeito de Combate</h4>
                <p className="text-xs text-stone-300 leading-relaxed font-sans font-medium">{inspectedCard.efeito || "Sem efeito ativo."}</p>
              </div>
            </div>
          </div>
        </div>
      </div>
    )}

    <PreMatchModal mode={preMatchMode} onCancel={() => setPreMatchMode(null)} onConfirm={handlePreMatchConfirm} />
    <AnimatePresence>
      {gachaCards && (
        <GachaModal 
          cards={gachaCards} 
          onCollect={() => { 
            setGachaCards(null)
            void refreshWallet() 
          }} 
        />
      )}
    </AnimatePresence>
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
