"use client"

import { useEffect, useMemo, useRef, useState } from "react"
import { AnimatePresence, motion } from "framer-motion"
import { BookOpen, Crown, Flag, Hand, Heart, Hourglass, Layers, Loader2, Shield, Skull, Sparkles, Sword, Swords, Wifi, WifiOff, X, Zap } from "lucide-react"
import { GameCard } from "./game-card"
import { ReactionModal } from "./reaction-modal"
import { useDuelRealtime } from "@/hooks/useDuelRealtime"
import { supabase } from "@/lib/supabase"
import type { BanCandidate, MatchAction, MatchCardZone, MatchState, VisibleMatchCard } from "@/lib/types"

function EmptySlot({ label, onClick, danger = false }: { label: string; onClick?: () => void; danger?: boolean }) {
  return <button aria-label={label} disabled={!onClick} onClick={onClick} className={`aspect-[2/3] w-[clamp(54px,6.5vw,92px)] shrink-0 rounded-[45%] border bg-[radial-gradient(ellipse,rgba(245,158,11,.10),transparent_65%)] backdrop-blur-sm transition-all ${danger ? "border-red-500/20 shadow-[inset_0_0_22px_rgba(239,68,68,.08)]" : "border-amber-300/20 shadow-[inset_0_0_22px_rgba(245,158,11,.10)]"} ${onClick ? "animate-pulse border-amber-300/80 bg-amber-400/10 shadow-[0_0_24px_rgba(245,158,11,.35)]" : ""}`} />
}

const miniRarity = { common:"border-emerald-400 shadow-emerald-500/30",rare:"border-blue-400 shadow-blue-500/35",epic:"border-purple-400 shadow-purple-500/40",legendary:"border-yellow-300 shadow-amber-400/50",collab:"border-pink-400 shadow-pink-500/40" }
function MiniCard({ row, hidden=false }: { row: VisibleMatchCard; hidden?: boolean }) {
  if(hidden || !row.card_data) return <div className="relative h-full w-full overflow-hidden rounded-lg border-2 border-amber-800 bg-[radial-gradient(circle,#713f12,#09090b_65%)]"><div className="absolute inset-[18%] rotate-45 border border-amber-400/40" /><span className="absolute inset-0 flex items-center justify-center font-serif text-2xl text-amber-300/60">𓂀</span></div>
  const card=row.card_data
  return <div className={`relative h-full w-full overflow-hidden rounded-lg border-[3px] bg-black shadow-lg ${miniRarity[card.raridade]}`}>
    {card.image_url ? <img src={card.image_url} alt={card.nome} className="h-full w-full object-cover object-center" /> : <div className="h-full bg-stone-900" />}
    <div className="absolute inset-0 bg-gradient-to-b from-black/20 via-transparent to-black/80" />
    <span className="absolute left-1 top-1 flex h-6 w-6 rotate-45 items-center justify-center border border-cyan-200 bg-blue-950 text-[9px] font-black text-cyan-50 shadow-[0_0_10px_#22d3ee]"><b className="-rotate-45">{card.mana}</b></span>
    <span className="absolute bottom-1 left-1 flex h-7 min-w-7 items-center justify-center rounded-full border-2 border-amber-300 bg-stone-950 px-1 text-[9px] font-black text-amber-100"><Sword size={9}/>{row.current_power ?? card.ataque}</span>
    <span className="absolute bottom-1 right-1 flex h-7 min-w-7 items-center justify-center rounded-t-xl rounded-b-md border-2 border-red-300 bg-red-950 px-1 text-[9px] font-black text-red-50"><Heart size={9} fill="currentColor"/>{row.current_life ?? card.vida}</span>
  </div>
}

function CardView({ row, hidden = false, selected = false, onClick, onEffect, onInspect, ownerPreview = false }: { row: VisibleMatchCard; hidden?: boolean; selected?: boolean; onClick?: () => void; onEffect?: () => void; onInspect?: (card:VisibleMatchCard)=>void; ownerPreview?: boolean }) {
  return <motion.div layout className={`relative aspect-[2/3] w-[clamp(54px,6.5vw,92px)] shrink-0 rounded-xl transition-all ${selected ? "ring-2 ring-red-400 shadow-[0_0_24px_rgba(248,113,113,.8)]" : ""}`}>
    <button type="button" onMouseEnter={() => { if(onInspect) window.setTimeout(()=>onInspect(row),300) }} onFocus={() => onInspect?.(row)} onClick={() => { onInspect?.(row); onClick?.() }} className="h-full w-full"><MiniCard row={row} hidden={hidden} /></button>
    {ownerPreview && hidden && row.card_data && <div className="pointer-events-none absolute inset-1 rounded-lg border border-cyan-200/20 bg-cyan-400/5" />}
    {onEffect && !hidden && <button type="button" onClick={event => { event.stopPropagation(); onEffect() }} className="absolute -right-2 -top-2 z-50 flex h-7 w-7 items-center justify-center rounded-full border-2 border-cyan-200 bg-blue-800 text-cyan-50 shadow-[0_0_14px_#22d3ee]" title="Ativar efeito"><Zap size={13}/></button>}
  </motion.div>
}

function Zone({ label, cards, slots = 4, hidden = false, selected, onCard, onEffect, onInspect, onEmpty, onDropCard, danger = false, ownerPreview = false }: { label: string; cards: VisibleMatchCard[]; slots?: number; hidden?: boolean; selected?: Set<string>; onCard?: (card: VisibleMatchCard) => void; onEffect?: (card: VisibleMatchCard) => void; onInspect?: (card:VisibleMatchCard)=>void; onEmpty?: (position: number) => void; onDropCard?: (cardId: string, position: number) => void; danger?: boolean; ownerPreview?: boolean }) {
  const occupied = new Set(cards.map(card => card.slot_index))
  return <section aria-label={label} className="min-h-0 min-w-0"><div className="flex h-[clamp(82px,12vh,144px)] items-center justify-center gap-3 overflow-hidden px-2 py-1">
    {cards.map(card => <CardView key={card.id} row={card} hidden={hidden && !card.is_face_up} selected={selected?.has(card.id)} onInspect={onInspect} onClick={onCard ? () => onCard(card) : undefined} onEffect={onEffect && card.card_data?.effect_definition?.some(effect => ["manual","reaction"].includes(effect.trigger_type ?? "")) ? () => onEffect(card) : undefined} ownerPreview={ownerPreview} />)}
    {Array.from({ length: slots }, (_, index) => index + 1).filter(position => !occupied.has(position)).map(position => <div key={position} onDragOver={event => { if(onDropCard){ event.preventDefault(); event.dataTransfer.dropEffect="move" } }} onDrop={event => { if(!onDropCard)return; event.preventDefault(); const id=event.dataTransfer.getData("text/card-id"); if(id)onDropCard(id,position) }}><EmptySlot label={label} danger={danger} onClick={onEmpty ? () => onEmpty(position) : undefined} /></div>)}
  </div></section>
}

function Pile({ label, count, graveyard = false, onClick }: { label: string; count: number; graveyard?: boolean; onClick?: () => void }) {
  const Icon = graveyard ? Skull : Layers
  return <button onClick={onClick} className="group flex items-center gap-3 rounded-lg border border-amber-700/30 bg-black/35 p-2 text-left shadow-lg backdrop-blur-md"><div className="relative flex aspect-[2/3] w-12 items-center justify-center rounded border border-amber-600/50 bg-gradient-to-br from-stone-900 to-amber-950"><Icon className="text-amber-300/70" size={20} /><span className="absolute -right-2 -top-2 rounded-full border border-amber-400 bg-black px-2 py-0.5 text-xs font-black text-amber-200">{count}</span></div><div><p className="font-serif text-[10px] font-black uppercase text-amber-200">{label}</p><p className="text-[9px] text-stone-400">{graveyard ? "Cartas destruídas" : "Cartas restantes"}</p></div></button>
}

function GraveyardModal({ cards, onClose }: { cards: VisibleMatchCard[]; onClose: () => void }) {
  return <motion.div initial={{ opacity: 0 }} animate={{ opacity: 1 }} exit={{ opacity: 0 }} onClick={onClose} className="fixed inset-0 z-[160] flex items-center justify-center bg-black/85 p-6 backdrop-blur-md"><div onClick={event => event.stopPropagation()} className="relative max-h-[80vh] w-full max-w-4xl overflow-y-auto rounded-xl border border-amber-500/50 bg-stone-950 p-6"><button onClick={onClose} className="absolute right-4 top-4 text-amber-200"><X /></button><h2 className="mb-5 font-serif text-xl font-black text-amber-200">Cemitério</h2><div className="grid grid-cols-3 gap-4 sm:grid-cols-5 lg:grid-cols-7">{cards.map(card => <CardView key={card.id} row={card} />)}</div></div></motion.div>
}

function CardPileModal({ title, cards, hidden = false, onClose }: { title: string; cards: VisibleMatchCard[]; hidden?: boolean; onClose: () => void }) {
  return <motion.div initial={{ opacity: 0 }} animate={{ opacity: 1 }} exit={{ opacity: 0 }} onClick={onClose} className="fixed inset-0 z-[160] flex items-center justify-center bg-black/90 p-5 backdrop-blur-md"><div onClick={e => e.stopPropagation()} className="relative max-h-[88vh] w-full max-w-6xl overflow-y-auto rounded-xl border border-amber-500/50 bg-stone-950 p-6"><button onClick={onClose} className="absolute right-4 top-4 text-amber-200"><X /></button><h2 className="mb-5 font-serif text-2xl font-black text-amber-200">{title} · {cards.length}</h2><div className="grid grid-cols-3 gap-4 sm:grid-cols-5 md:grid-cols-7 xl:grid-cols-10">{cards.map(card => <CardView key={card.id} row={card} hidden={hidden && !card.is_face_up} />)}</div>{!cards.length && <p className="py-14 text-center text-stone-500">Nenhuma carta nesta pilha.</p>}</div></motion.div>
}

function ArenaPreview() {
  const slots = (label: string, count: number) => <div className="flex justify-center gap-2">{Array.from({ length: count }, (_, index) => <EmptySlot key={index} label={label} />)}</div>
  return <main className="relative h-screen overflow-hidden bg-[url('/yang-69TcSUVhbmY-unsplash.jpg')] bg-cover bg-center text-stone-100"><div className="absolute inset-0 bg-black/65 backdrop-blur-[2px]" /><div className="relative z-10 flex h-full flex-col p-3 pt-16"><div className="mb-2 rounded border border-blue-400/40 bg-blue-950/70 p-2 text-center text-xs text-blue-100">Prévia visual — mão inicial: 7 de no máximo 10 cartas. Nenhuma ação será enviada ao servidor.</div><div className="grid min-h-0 flex-1 grid-cols-[150px_minmax(620px,1fr)_150px] gap-3 overflow-x-auto"><aside className="flex flex-col justify-between rounded-xl border border-amber-800/30 bg-stone-950/70 p-2"><Pile label="Deck rival" count={33} /><Pile label="Cemitério rival" count={0} graveyard /><Pile label="Seu cemitério" count={0} graveyard /><Pile label="Seu deck" count={33} /></aside><section className="flex min-h-0 flex-col justify-around overflow-y-auto rounded-xl border border-amber-700/30 bg-black/30 p-2"><div><p className="mb-1 text-center font-serif text-[9px] uppercase tracking-widest text-amber-300">Campo de Defesa do oponente</p>{slots("Carta", 4)}</div><div><p className="mb-1 text-center font-serif text-[9px] uppercase tracking-widest text-amber-300">Cartas de Vida do oponente</p>{slots("Carta", 3)}</div><div><p className="mb-1 text-center font-serif text-[9px] uppercase tracking-widest text-amber-300">Campo de Ataque do oponente</p>{slots("Carta", 4)}</div><div className="flex items-center justify-between border-y border-amber-700/50 bg-stone-950/95 px-4 py-2"><ManaOrb label="Rival" /><b className="font-serif text-amber-200">Turno 0</b><div className="flex gap-2"><button disabled className="rounded border border-amber-500 bg-amber-800 px-3 py-1 text-[9px] font-black opacity-60">ENCERRAR TURNO</button><button disabled className="rounded border border-blue-400 bg-blue-900 px-3 py-1 text-[9px] font-black opacity-60">PASSAR TURNO</button></div><ManaOrb label="Você" /></div><div><p className="mb-1 text-center font-serif text-[9px] uppercase tracking-widest text-amber-300">Campo de Ataque</p>{slots("Carta", 4)}</div><div><p className="mb-1 text-center font-serif text-[9px] uppercase tracking-widest text-amber-300">Campo de Defesa</p>{slots("Carta", 4)}</div><div><p className="mb-1 text-center font-serif text-[9px] uppercase tracking-widest text-amber-300">Suas cartas de vida</p>{slots("Carta", 3)}</div></section><aside className="flex flex-col justify-between rounded-xl border border-amber-800/30 bg-stone-950/70 p-3"><EmptySlot label="Carta que você baniu" danger /><span className="rounded-full border border-blue-400/50 bg-blue-950 p-2 text-center text-[9px] text-blue-200">PRÉVIA LOCAL</span><EmptySlot label="Sua carta banida pelo rival" danger /></aside></div><div className="mx-auto mt-2 flex h-24 w-full max-w-4xl items-end justify-center -space-x-2 rounded-t-3xl border border-amber-700/30 bg-black/65 p-2">{Array.from({ length: 7 }, (_, index) => <EmptySlot key={index} label="Carta" />)}</div></div></main>
}

function ManaOrb({ label }: { label: string }) { return <div className="flex items-center gap-2 text-[10px]"><span className="flex h-9 w-9 items-center justify-center rounded-full border-2 border-cyan-300 bg-[radial-gradient(circle_at_35%_25%,#67e8f9,#1d4ed8_55%,#172554)] font-black shadow-[0_0_18px_rgba(34,211,238,.65)]">0</span><span className="text-stone-400">{label}</span></div> }

type MatchBanView = { id: string; banned_by_user_id: string; target_user_id: string; source_card_id: string | null; is_skipped: boolean; cards: { name: string; image_url: string } | null }
function BannedCard({ ban, label }: { ban?: MatchBanView; label: string }) { return <div><p className="mb-2 text-center font-serif text-[9px] font-black uppercase text-amber-300">{label}</p>{ban?.cards ? <div className="overflow-hidden rounded-lg border border-red-500/60 bg-black"><img src={ban.cards.image_url} alt={ban.cards.name} className="aspect-[2/3] w-full object-cover opacity-75 grayscale-[30%]" /><p className="border-t border-red-700 p-1 text-center text-[8px] font-bold text-red-200">BANIDA · {ban.cards.name}</p></div> : <EmptySlot label={ban?.is_skipped ? "Banimento dispensado" : "Aguardando banimento"} danger />}</div> }

function Inspector({ card }: { card: VisibleMatchCard | null }) {
  if(!card?.card_data) return <div className="flex h-full flex-col items-center justify-center text-center text-stone-500"><BookOpen className="mb-3 text-amber-700" size={36}/><b className="font-serif text-amber-200/70">Grimório de Inspeção</b><p className="mt-2 text-[10px]">Selecione uma carta revelada para examinar seus detalhes.</p></div>
  const labels:Record<string,string>={status:"STATUS",immunity:"ESCUDO PROTETOR",buff:"BUFF",debuff:"DEBUFF",damage:"DANO",heal:"CURA",set_power:"PODER ALTERADO",set_max_life:"VIDA ALTERADA",deterioration:"DETERIORAÇÃO"}
  return <div className="flex h-full min-h-0 flex-col"><h2 className="mb-2 flex items-center gap-2 font-serif text-sm font-black uppercase text-amber-200"><BookOpen size={16}/> Grimório</h2><div className="mx-auto aspect-[2/3] w-full max-w-[210px] min-h-0"><GameCard card={{...card.card_data,ataque:card.current_power ?? card.card_data.ataque,vida:card.current_life ?? card.card_data.vida}} enableZoom={false}/></div><section className="mt-3 min-h-0 overflow-y-auto rounded-lg border border-purple-700/30 bg-black/45 p-2"><h3 className="mb-2 text-[9px] font-black uppercase tracking-wider text-purple-200">Modificadores ativos</h3><div className="flex flex-wrap gap-1">{card.active_modifiers?.map(mod => <span key={mod.id} title={JSON.stringify(mod.metadata)} className={`rounded-full border px-2 py-1 text-[8px] font-black ${mod.modifier_type==="buff"?"border-emerald-400 bg-emerald-950 text-emerald-200":mod.modifier_type==="debuff"||mod.modifier_type==="damage"?"border-red-400 bg-red-950 text-red-200":"border-purple-400 bg-purple-950 text-purple-200"}`}>{labels[mod.modifier_type]??mod.modifier_type.toUpperCase()}{mod.power_delta?` ${mod.power_delta>0?"+":""}${mod.power_delta} ATK`:""}{mod.max_life_delta?` ${mod.max_life_delta>0?"+":""}${mod.max_life_delta} VIDA`:""}</span>)}{!card.active_modifiers?.length && <span className="text-[9px] text-stone-600">Nenhum modificador ativo.</span>}</div></section></div>
}

function actionText(action: MatchAction, state: MatchState | null) {
  const p=action.payload_public??{}; const actor=action.actor_user_id===state?.player1_id?state.player1_username:state?.player2_username; const turn=String((p.turn as number|undefined)??state?.current_turn??"?")
  if(action.action_type==="card_played") return `Turno ${turn}: ${actor??"Jogador"} jogou uma carta na linha de ${String(p.destination_zone??"campo")}.`
  if(action.action_type==="attack_declared") return `Turno ${turn}: ${actor??"Jogador"} declarou um ataque de ${String(p.declared_power??p.total_power??"?")} de poder.`
  if(action.action_type==="attack_resolved") return `Turno ${turn}: o ataque causou ${String(p.total_power??"?")} de dano e foi resolvido.`
  if(action.action_type==="effect_activated") return `Turno ${turn}: ${actor??"Jogador"} ativou ${String(p.effect_code??"um efeito")}.`
  if(action.action_type==="card_banned") return `${actor??"Jogador"} baniu uma carta do duelo.`
  if(action.action_type==="turn_ended") return `Turno ${turn}: ${actor??"Jogador"} encerrou o turno.`
  if(action.action_type==="turn_passed_without_action") return `Turno ${turn}: ${actor??"Jogador"} passou sem realizar ação e comprou uma carta.`
  return `Turno ${turn}: ${action.action_type.replaceAll("_"," ")}.`
}

export function ArenaScreen() {
  const [matchId, setMatchId] = useState("")
  const [preview, setPreview] = useState(false)
  const [userId, setUserId] = useState("")
  const [selectedHand, setSelectedHand] = useState<string | null>(null)
  const [selectedAttackers, setSelectedAttackers] = useState<Set<string>>(new Set())
  const [graveyardOpen, setGraveyardOpen] = useState(false)
  const [pileOpen, setPileOpen] = useState<{ title: string; cards: VisibleMatchCard[]; hidden?: boolean } | null>(null)
  const [setupCards, setSetupCards] = useState<Set<string>>(new Set())
  const [secondsLeft, setSecondsLeft] = useState(180)
  const [banCandidates, setBanCandidates] = useState<BanCandidate[]>([])
  const [banBusy, setBanBusy] = useState(false)
  const [banError, setBanError] = useState<string | null>(null)
  const [matchBans, setMatchBans] = useState<MatchBanView[]>([])
  const [effectSelection, setEffectSelection] = useState<{ sourceId: string; order: number; zone?: MatchCardZone } | null>(null)
  const [effectMessage, setEffectMessage] = useState<string | null>(null)
  const [inspectedCard, setInspectedCard] = useState<VisibleMatchCard | null>(null)
  const [visualCards, setVisualCards] = useState<VisibleMatchCard[]>([])
  const [showcaseQueue, setShowcaseQueue] = useState<MatchAction[]>([])
  const [showcase, setShowcase] = useState<{ action:MatchAction; card:VisibleMatchCard|null } | null>(null)
  const [screenShake, setScreenShake] = useState(false)
  const botRunning = useRef(false)
  const seenAction = useRef<number | null>(null)
  const logEnd = useRef<HTMLDivElement | null>(null)

  useEffect(() => { const params = new URLSearchParams(window.location.search); setMatchId(params.get("matchId") ?? ""); setPreview(params.get("preview") === "1"); void supabase.auth.getUser().then(({ data }) => setUserId(data.user?.id ?? "")) }, [])
  const duel = useDuelRealtime(matchId, userId)
  const { matchState, boardCards, matchActions, pendingAttack, pendingEffectChoice, connectionStatus, isTraining, isCurrentPlayer, isPlayer1, opponentId, hasActedThisTurn, reactionUsed } = duel

  useEffect(() => {
    if(!showcase && !showcaseQueue.length) setVisualCards(boardCards)
    if(inspectedCard) setInspectedCard(boardCards.find(card=>card.id===inspectedCard.id)??inspectedCard)
  },[boardCards,showcase,showcaseQueue.length])
  useEffect(() => {
    if(!matchActions.length)return
    const max=Math.max(...matchActions.map(action=>action.sequence_number))
    if(seenAction.current===null){seenAction.current=max;return}
    const incoming=matchActions.filter(action=>action.sequence_number>(seenAction.current??0)&&action.actor_user_id!==userId)
    if(incoming.length)setShowcaseQueue(previous=>[...previous,...incoming.filter(action=>!previous.some(old=>old.id===action.id))])
    seenAction.current=Math.max(seenAction.current,max)
    logEnd.current?.scrollIntoView({behavior:"smooth"})
  },[matchActions,userId])
  useEffect(() => {
    if(showcase||!showcaseQueue.length)return
    const action=showcaseQueue[0]; const p=action.payload_public??{}
    const raw=(p.match_card_id??p.source_card_id??p.attacker_card_id??(Array.isArray(p.attacker_card_ids)?p.attacker_card_ids[0]:null)) as string|null
    const card=boardCards.find(item=>item.id===raw)??null
    setShowcase({action,card}); setShowcaseQueue(previous=>previous.slice(1))
    const impact=window.setTimeout(()=>setScreenShake(true),1200)
    const finish=window.setTimeout(()=>{setScreenShake(false);setShowcase(null);setVisualCards(boardCards)},1800)
    return()=>{window.clearTimeout(impact);window.clearTimeout(finish)}
  },[boardCards,showcase,showcaseQueue])

  useEffect(() => {
    if (!isTraining || !matchState || matchState.status !== "in_progress" || isCurrentPlayer || botRunning.current) return
    botRunning.current = true
    setEffectMessage("O Autômato de Ofier está calculando a jogada…")
    const timer = window.setTimeout(() => {
      void duel.runTrainingBotTurn().then(() => duel.refresh()).catch(error => setEffectMessage(error?.message ?? "Falha no turno do Autômato.")).finally(() => { botRunning.current = false })
    }, 900)
    return () => window.clearTimeout(timer)
  }, [isCurrentPlayer, isTraining, matchState?.match_version, matchState?.status])

  useEffect(() => {
    if (!matchState?.turn_deadline || matchState.status !== "in_progress") { setSecondsLeft(180); return }
    const update = () => {
      const left = Math.max(0, Math.ceil((new Date(matchState.turn_deadline!).getTime() - Date.now()) / 1000)); setSecondsLeft(left)
      if (left === 0) void duel.expireTurn().catch(() => undefined)
    }
    update(); const timer = window.setInterval(update, 1000); return () => window.clearInterval(timer)
  }, [isCurrentPlayer, matchState?.match_version, matchState?.status, matchState?.turn_deadline])

  useEffect(() => { if (matchState?.status !== "ban_phase") { setBanCandidates([]); return } void duel.getBanCandidates().then(setBanCandidates).catch(console.error) }, [matchId, matchState?.status])
  useEffect(() => {
    if (!matchId || preview) return
    const load = async () => { const { data } = await supabase.from("match_bans").select("id,banned_by_user_id,target_user_id,source_card_id,is_skipped,cards:source_card_id(name,image_url)").eq("match_id", matchId); setMatchBans((data ?? []) as unknown as MatchBanView[]) }
    void load()
    const channel = supabase.channel(`match-bans:${matchId}`).on("postgres_changes", { event: "*", schema: "public", table: "match_bans", filter: `match_id=eq.${matchId}` }, () => void load()).subscribe()
    return () => { void supabase.removeChannel(channel) }
  }, [matchId, preview])

  const mine = (zone: MatchCardZone) => visualCards.filter(card=>card.zone===zone&&card.owner_id===userId)
  const theirs = (zone: MatchCardZone) => visualCards.filter(card=>card.zone===zone&&card.owner_id===opponentId)
  const hand = mine("hand")
  const attackers = mine("attacker")
  const selectedPower = useMemo(() => attackers.filter(card => selectedAttackers.has(card.id)).reduce((sum, card) => sum + (card.current_power ?? 0), 0), [attackers, selectedAttackers])
  const myMana = matchState ? (isPlayer1 ? matchState.player1_mana : matchState.player2_mana) : 0
  const theirMana = matchState ? (isPlayer1 ? matchState.player2_mana : matchState.player1_mana) : 0
  const selectedCard = hand.find(card => card.id === selectedHand)
  const playSelected = (zone: "attacker" | "reinforcement", position: number) => selectedCard && void duel.playCard(selectedCard.id, zone, position).then(() => setSelectedHand(null))
  const dropCard = (cardId: string, zone: "attacker" | "reinforcement", position: number) => {
    if (!isCurrentPlayer || matchState?.status !== "in_progress") return
    setEffectMessage(`Movendo carta para ${zone === "attacker" ? "o Campo de Ataque" : "o Campo de Defesa"}…`)
    void duel.playCard(cardId, zone, position).then(() => { setSelectedHand(null); setEffectMessage("Carta posicionada. A ação foi registrada no servidor.") }).catch(error => setEffectMessage(error?.message ?? "Jogada recusada pelo servidor."))
  }
  const toggleAttacker = (card: VisibleMatchCard) => setSelectedAttackers(previous => { const next = new Set(previous); next.has(card.id) ? next.delete(card.id) : next.add(card.id); return next })
  const activateEffect = (card: VisibleMatchCard) => {
    const effect = card.card_data?.effect_definition?.find(item => item.trigger_type === "manual")
    if (!effect) return
    const order = effect.effect_order ?? 1
    if (["selected", "ally", "enemy", "deck", "hand", "graveyard"].includes(effect.target_mode ?? "")) { const zone = ["deck", "hand", "graveyard"].includes(effect.target_mode ?? "") ? effect.target_mode as MatchCardZone : undefined; setEffectSelection({ sourceId: card.id, order, zone }); setEffectMessage(zone ? `Selecione uma carta em ${zone}.` : "Selecione a carta-alvo no tabuleiro."); return }
    void duel.activateMatchEffect(card.id, order).then(() => { setEffectMessage("Efeito ativado."); void duel.refresh() }).catch(error => setEffectMessage(error?.message ?? "Falha ao ativar efeito."))
  }
  const chooseEffectTarget = (card: VisibleMatchCard) => { if (!effectSelection) return false; const selection = effectSelection; setEffectSelection(null); void duel.activateMatchEffect(selection.sourceId, selection.order, card.id).then(() => { setEffectMessage("Efeito resolvido."); void duel.refresh() }).catch(error => setEffectMessage(error?.message ?? "Alvo inválido.")); return true }
  const reactions = boardCards.filter(card => card.controller_user_id === userId && ["life", "reinforcement", "attacker", "leader"].includes(card.zone) && (card.current_life ?? 0) > 0)
  const toggleSetup = (id: string) => setSetupCards(previous => { const next = new Set(previous); if (next.has(id)) next.delete(id); else if (next.size < 3) next.add(id); return next })
  const submitBan = async (cardId: string) => {
    if (banBusy) return
    setBanBusy(true); setBanError(null)
    try { await duel.submitBan(cardId); await duel.refresh() }
    catch (cause) {
      const error = cause as { message?: string; details?: string; hint?: string; code?: string }
      const full = [error.message, error.details, error.hint, error.code && `Código: ${error.code}`].filter(Boolean).join(" · ") || "O servidor recusou o banimento sem fornecer detalhes."
      setBanError(full); setEffectMessage(`Falha no banimento: ${full}`)
    } finally { setBanBusy(false) }
  }
  const commitTurn = async () => {
    if (!isCurrentPlayer) return
    try {
      if (attackers.length) {
        setEffectMessage(`Ataque automático declarado com ${attackers.length} carta(s).`)
        const attack = await duel.declareAttack(attackers.map(card => card.id), false) as { state_version?: number }
        if (isTraining && attack.state_version != null) await duel.autoResolveTrainingAttack(attack.state_version)
      } else await duel.endTurn()
      await duel.refresh()
    } catch (error) { setEffectMessage((error as Error)?.message ?? "O servidor recusou o encerramento do turno.") }
  }

  if (preview) return <ArenaPreview />
  if (!matchId) return <div className="flex min-h-screen items-center justify-center bg-stone-950 text-center text-amber-200"><div><Swords className="mx-auto mb-4" size={40} /><h1 className="font-serif text-xl font-black">Nenhuma batalha selecionada</h1><p className="mt-2 text-sm text-stone-400">Abra a Arena a partir de uma partida encontrada no Hub.</p></div></div>

  return <motion.main animate={screenShake?{x:[0,-8,7,-5,3,0],y:[0,4,-3,2,0]}:{x:0,y:0}} transition={{duration:.35}} className="relative h-screen overflow-hidden bg-[url('/yang-69TcSUVhbmY-unsplash.jpg')] bg-cover bg-center bg-no-repeat text-stone-100"><div className="absolute inset-0 bg-gradient-to-b from-black/80 via-black/60 to-black/85 backdrop-blur-[2px]" />
    <div className="relative z-10 grid h-[calc(100vh-132px)] grid-cols-[190px_minmax(580px,1fr)_170px] gap-2 overflow-x-auto p-2">
      <aside className="flex min-h-0 flex-col gap-3 rounded-xl border border-amber-800/30 bg-stone-950/55 p-3 backdrop-blur-md">
        <div className="flex items-center gap-2 rounded-lg border border-red-900/50 bg-black/60 p-2">{(isPlayer1 ? matchState?.player2_avatar_url : matchState?.player1_avatar_url) ? <img src={(isPlayer1 ? matchState?.player2_avatar_url : matchState?.player1_avatar_url) ?? ""} alt="" className="h-10 w-10 rounded-full border border-red-400 object-cover" /> : <div className="h-10 w-10 rounded-full bg-red-950" />}<div><p className="text-[9px] uppercase text-red-300">Oponente</p><b className="text-xs text-stone-100">{isPlayer1 ? matchState?.player2_username : matchState?.player1_username}</b></div></div>
        <Pile label="Deck rival" count={isPlayer1 ? matchState?.player2_deck_count ?? 0 : matchState?.player1_deck_count ?? 0} onClick={() => setPileOpen({ title: "Deck rival", cards: theirs("deck"), hidden: true })} /><Pile label="Cemitério rival" graveyard count={theirs("graveyard").length} onClick={() => setPileOpen({ title: "Cemitério rival", cards: theirs("graveyard") })} />
        <div className="min-h-0 flex-1 rounded-lg border border-amber-500/20 bg-black/50 p-2"><div className="mb-2 flex justify-between text-[9px] font-black uppercase text-amber-300"><span>Crônica da Batalha</span><span>v{matchState?.match_version ?? 0}</span></div><div className="h-full overflow-y-auto pr-1 text-[9px] leading-relaxed text-stone-300">{matchActions.map(action => <p key={action.id} className="border-b border-white/5 py-1.5"><span className="mr-1 text-amber-500">#{action.sequence_number}</span>{actionText(action,matchState)}</p>)}<div ref={logEnd}/></div></div>
        <Pile label="Seu cemitério" graveyard count={mine("graveyard").length} onClick={() => setGraveyardOpen(true)} /><Pile label="Seu deck" count={isPlayer1 ? matchState?.player1_deck_count ?? 0 : matchState?.player2_deck_count ?? 0} onClick={() => setPileOpen({ title: "Seu deck", cards: mine("deck") })} />
        <div className="flex items-center gap-2 rounded-lg border border-emerald-800/50 bg-black/60 p-2">{(isPlayer1 ? matchState?.player1_avatar_url : matchState?.player2_avatar_url) ? <img src={(isPlayer1 ? matchState?.player1_avatar_url : matchState?.player2_avatar_url) ?? ""} alt="" className="h-10 w-10 rounded-full border border-emerald-400 object-cover" /> : <div className="h-10 w-10 rounded-full bg-emerald-950" />}<div><p className="text-[9px] uppercase text-emerald-300">Você</p><b className="text-xs text-stone-100">{isPlayer1 ? matchState?.player1_username : matchState?.player2_username}</b></div></div>
      </aside>

      <section className="flex min-w-[580px] min-h-0 flex-col justify-between overflow-hidden rounded-xl border border-amber-700/20 bg-black/20 px-2">
        {effectMessage && <button onClick={() => { setEffectMessage(null); setEffectSelection(null) }} className="sticky top-0 z-50 w-full rounded border border-cyan-500/50 bg-blue-950/95 p-2 text-xs text-cyan-100">{effectMessage}</button>}
        <Zone label="Campo de Defesa do oponente" cards={theirs("reinforcement")} hidden onInspect={setInspectedCard} onCard={effectSelection ? chooseEffectTarget : undefined} /><Zone label="Cartas de Vida do oponente" cards={theirs("life")} slots={3} danger={Boolean(pendingAttack)} onInspect={setInspectedCard} onCard={effectSelection ? chooseEffectTarget : undefined} /><Zone label="Campo de Ataque do oponente" cards={theirs("attacker")} onInspect={setInspectedCard} onCard={effectSelection ? chooseEffectTarget : undefined} />
        <div className="z-40 my-1 flex items-center justify-between gap-3 border-y border-amber-700/50 bg-stone-950/95 px-4 py-2 shadow-2xl">
          <div className="flex items-center gap-2 text-xs"><span className="h-7 w-7 rounded-full border border-blue-300 bg-blue-700 shadow-[0_0_14px_rgba(59,130,246,.8)]" /><b>{theirMana}</b><span className="text-stone-500">Rival</span></div>
          <div className={`rounded px-3 py-1 text-center text-xs font-black ${isCurrentPlayer ? "bg-emerald-950 text-emerald-200 ring-1 ring-emerald-400" : "bg-red-950 text-red-200 ring-1 ring-red-500"}`}><span className="block">{isCurrentPlayer ? "SUA VEZ" : `VEZ DE ${isPlayer1 ? matchState?.player2_username : matchState?.player1_username}`}</span><span className={secondsLeft <= 30 ? "animate-pulse text-red-300" : "text-amber-200"}><Hourglass className="mr-1 inline" size={13} />Turno {matchState?.current_turn ?? 0} · {Math.floor(secondsLeft/60)}:{String(secondsLeft%60).padStart(2,"0")}</span>{matchState?.initiative_result?.player1 && matchState.current_turn===1 && <small className="block text-stone-400">D20: {matchState.initiative_result.player1} × {matchState.initiative_result.player2}</small>}</div>
          <div className="flex items-center gap-2">{isCurrentPlayer ? hasActedThisTurn || attackers.length ? <button onClick={() => void commitTurn()} className="rounded border border-amber-400 bg-amber-700 px-4 py-2 text-[10px] font-black text-amber-100 shadow-[0_0_15px_rgba(245,158,11,.3)] hover:bg-amber-600">{attackers.length ? `ENCERRAR E ATACAR (${attackers.length})` : "ENCERRAR TURNO"}</button> : <button onClick={() => void duel.passWithoutAction()} className="rounded border border-blue-400 bg-blue-900 px-4 py-2 text-[10px] font-black text-blue-100">PASSAR TURNO</button> : <span className="rounded border border-stone-700 bg-black/60 px-4 py-2 text-[10px] font-black text-stone-500">AGUARDE O OPONENTE</span>}<button disabled={!isCurrentPlayer} onClick={() => void duel.surrenderMatch()} className="rounded border border-red-800 bg-red-950 px-2 py-2 text-red-300 disabled:opacity-30" title="Se render"><Flag size={14} /></button></div>
          <div className="flex items-center gap-2 text-xs"><span className="text-stone-500">Você</span><b>{myMana}</b><span className="h-7 w-7 rounded-full border border-blue-300 bg-blue-700 shadow-[0_0_14px_rgba(59,130,246,.8)]" /></div>
        </div>
        <Zone label="Campo de Ataque" cards={attackers} selected={selectedAttackers} onInspect={setInspectedCard} onCard={effectSelection ? chooseEffectTarget : undefined} onEffect={activateEffect} onEmpty={position => playSelected("attacker", position)} onDropCard={(id,position) => dropCard(id,"attacker",position)} /><Zone label="Campo de Defesa" cards={mine("reinforcement")} hidden ownerPreview onInspect={setInspectedCard} onCard={effectSelection ? chooseEffectTarget : undefined} onEffect={activateEffect} onEmpty={position => playSelected("reinforcement", position)} onDropCard={(id,position) => dropCard(id,"reinforcement",position)} /><Zone label="Suas cartas de vida" cards={mine("life")} slots={3} danger onInspect={setInspectedCard} onCard={effectSelection ? chooseEffectTarget : undefined} onEffect={activateEffect} onEmpty={selectedCard && matchState && matchState.current_turn > 0 && matchState.current_turn < 4 ? position => void duel.replaceEarlyLifeCard(selectedCard.id, position).then(() => setSelectedHand(null)) : undefined} />
      </section>

      <aside className="flex min-h-0 flex-col rounded-xl border border-amber-800/30 bg-stone-950/75 p-3 backdrop-blur-md">{matchState?.status==="ban_phase"?<><BannedCard ban={matchBans.find(ban => ban.banned_by_user_id === userId)} label="Carta que você baniu" /><div className="flex-1"/><BannedCard ban={matchBans.find(ban => ban.target_user_id === userId)} label="Sua carta banida pelo rival" /></>:<Inspector card={inspectedCard}/>}<div className={`mt-2 rounded-full border px-2 py-1 text-center text-[9px] font-bold ${connectionStatus === "connected" ? "border-emerald-400/50 bg-emerald-950/70 text-emerald-300" : "border-red-500/50 bg-red-950/70 text-red-300"}`}>{connectionStatus === "connected" ? <Wifi className="mr-1 inline" size={11} /> : connectionStatus === "syncing" ? <Loader2 className="mr-1 inline animate-spin" size={11} /> : <WifiOff className="mr-1 inline" size={11} />}{connectionStatus === "connected" ? "Realtime conectado" : connectionStatus === "syncing" ? "Sincronizando" : "Desconectado"}</div></aside>
    </div>

    <div className="absolute bottom-0 left-1/2 z-50 flex h-[132px] w-[min(900px,88vw)] -translate-x-1/2 items-end justify-center overflow-x-auto rounded-t-[30px] border-x border-t border-amber-600/30 bg-black/55 px-12 pb-2 pt-4 backdrop-blur-md"><div className="flex justify-center -space-x-7 transition-all duration-300 hover:space-x-1">{hand.map(card => <div draggable={isCurrentPlayer} onDragStart={event => { event.dataTransfer.effectAllowed="move"; event.dataTransfer.setData("text/card-id",card.id) }} key={card.id} className={`relative aspect-[2/3] w-20 shrink-0 origin-bottom transition-transform duration-200 ${isCurrentPlayer ? "cursor-grab active:cursor-grabbing hover:z-50 hover:-translate-y-6 hover:scale-125" : "opacity-70"} ${selectedHand === card.id ? "z-40 -translate-y-4 rounded-xl ring-2 ring-amber-300" : ""}`}><button disabled={!isCurrentPlayer} onMouseEnter={()=>setInspectedCard(card)} onClick={() => {setInspectedCard(card);if (!chooseEffectTarget(card)) setSelectedHand(card.id)}} className="h-full w-full"><MiniCard row={card}/></button>{card.card_data?.effect_definition?.some(effect => effect.trigger_type === "manual") && <button disabled={!isCurrentPlayer} onClick={() => activateEffect(card)} className="absolute -right-2 -top-2 z-50 flex h-7 w-7 items-center justify-center rounded-full border-2 border-cyan-200 bg-blue-800 text-cyan-50 shadow-[0_0_14px_rgba(34,211,238,.8)] disabled:opacity-30" title="Ativar efeito"><Zap size={13}/></button>}</div>)}</div></div>

    <AnimatePresence>{showcase && <motion.div initial={{opacity:0}} animate={{opacity:1}} exit={{opacity:0}} className="pointer-events-none fixed inset-0 z-[155] flex items-center justify-center bg-black/55 backdrop-blur-[2px]"><motion.div initial={{scale:.6,x:280,rotate:8}} animate={{scale:1,x:0,rotate:0}} transition={{type:"spring",stiffness:180,damping:18}} className="relative flex items-center gap-8"><div className="absolute -inset-20 bg-[radial-gradient(circle,rgba(245,158,11,.35),transparent_65%)]" />{showcase.card?.card_data?<div className="relative aspect-[2/3] w-44 drop-shadow-[0_0_28px_rgba(245,158,11,.8)]"><GameCard card={showcase.card.card_data} enableZoom={false}/></div>:<Sparkles className="relative text-amber-300" size={90}/>}<div className="relative max-w-lg border-y-2 border-amber-300 bg-gradient-to-r from-transparent via-black/90 to-transparent px-10 py-6"><p className="text-xs font-black uppercase tracking-[.35em] text-red-300">Ação do rival</p><h2 className="mt-2 font-serif text-3xl font-black uppercase text-amber-100">{showcase.action.action_type==="card_played"?`O RIVAL INVOCA${showcase.card?.card_data?`: ${showcase.card.card_data.nome}`:""}`:showcase.action.action_type==="effect_activated"?`O RIVAL ATIVA EFEITO${showcase.card?.card_data?`: ${showcase.card.card_data.nome}`:""}`:showcase.action.action_type.includes("attack")?"O RIVAL DESFERE UM ATAQUE":actionText(showcase.action,matchState)}</h2></div><motion.div initial={{x:-120,opacity:0,scaleX:.2}} animate={{x:260,opacity:[0,1,1,0],scaleX:1}} transition={{delay:.8,duration:.55}} className="absolute left-1/3 top-1/2 h-2 w-72 origin-left bg-gradient-to-r from-amber-100 via-yellow-400 to-red-500 shadow-[0_0_24px_#f59e0b]" /></motion.div></motion.div>}</AnimatePresence>
    <AnimatePresence>{graveyardOpen && <GraveyardModal cards={mine("graveyard")} onClose={() => setGraveyardOpen(false)} />}</AnimatePresence>
    <AnimatePresence>{pileOpen && <CardPileModal title={pileOpen.title} cards={pileOpen.cards} hidden={pileOpen.hidden} onClose={() => setPileOpen(null)} />}</AnimatePresence>
    <AnimatePresence>{effectSelection?.zone && <motion.div initial={{ opacity: 0 }} animate={{ opacity: 1 }} exit={{ opacity: 0 }} className="fixed inset-0 z-[165] flex items-center justify-center bg-black/85 p-6"><div className="max-h-[80vh] w-full max-w-5xl overflow-y-auto rounded-xl border border-cyan-500/50 bg-stone-950 p-6"><button onClick={() => setEffectSelection(null)} className="float-right text-cyan-200"><X /></button><h2 className="mb-5 font-serif text-xl font-black text-cyan-100">Escolha uma carta — {effectSelection.zone}</h2><div className="grid grid-cols-3 gap-4 sm:grid-cols-5 lg:grid-cols-8">{mine(effectSelection.zone).map(card => <CardView key={card.id} row={card} onClick={() => chooseEffectTarget(card)} />)}</div></div></motion.div>}</AnimatePresence>
    <AnimatePresence>{pendingEffectChoice && <motion.div initial={{ opacity: 0 }} animate={{ opacity: 1 }} className="fixed inset-0 z-[168] flex items-center justify-center bg-black/85 p-6"><div className="max-h-[80vh] w-full max-w-5xl overflow-y-auto rounded-xl border border-purple-400/60 bg-stone-950 p-6"><h2 className="font-serif text-xl font-black text-purple-100">Escolha exigida pelo efeito</h2><p className="mb-5 mt-2 text-sm text-stone-300">{pendingEffectChoice.public_prompt}</p><div className="grid grid-cols-3 gap-4 sm:grid-cols-5 lg:grid-cols-8">{boardCards.filter(card => pendingEffectChoice.candidate_ids.includes(card.id)).map(card => <CardView key={card.id} row={card} onClick={() => void duel.submitEffectChoice(pendingEffectChoice.id,[card.id]).then(() => duel.refresh()).catch(error => setEffectMessage(error?.message ?? "Escolha inválida."))} />)}</div></div></motion.div>}</AnimatePresence>
    <AnimatePresence>{pendingAttack && pendingAttack.defender_user_id === userId && <ReactionModal attack={pendingAttack} reactionCards={reactions} mana={myMana} reactionUsed={reactionUsed} onActivate={async(cardId: string) => { const result=await duel.activateMatchEffect(cardId) as { state_version?: number }; if(result.state_version!=null) await duel.finalizePendingAttack(pendingAttack.id,result.state_version) }} onDecline={duel.declineAttackReaction} />}</AnimatePresence>
    <AnimatePresence>{matchState?.status === "ban_phase" && <motion.div initial={{ opacity: 0 }} animate={{ opacity: 1 }} className="fixed inset-0 z-[170] flex items-center justify-center bg-black/90 p-6"><div className="max-h-[90vh] w-full max-w-5xl overflow-y-auto rounded-xl border border-amber-500 bg-stone-950 p-6"><h2 className="mb-1 text-center font-serif text-2xl font-black text-amber-200">Banimento Ofieri</h2><p className="mb-4 text-center text-sm text-stone-400">Escolha uma carta entre as de maior raridade encontradas no deck adversário. Todas as cópias serão banidas desta batalha.</p>{banBusy && <p className="mb-4 rounded border border-blue-500/50 bg-blue-950 p-3 text-center text-sm text-blue-100"><Loader2 className="mr-2 inline animate-spin" size={15} />Validando o banimento no servidor…</p>}{banError && <div className="mb-4 rounded border border-red-500 bg-red-950/80 p-3 text-sm text-red-100"><b className="block uppercase">Banimento recusado</b><span className="break-words">{banError}</span></div>}<div className="grid grid-cols-2 gap-5 sm:grid-cols-4 lg:grid-cols-6">{banCandidates.map(card => <button disabled={banBusy} key={card.card_id} onClick={() => void submitBan(card.card_id)} className="overflow-hidden rounded-lg border border-amber-500/50 bg-black transition hover:-translate-y-1 hover:border-red-400 disabled:pointer-events-none disabled:opacity-40"><img src={card.image_url} alt={card.name} className="aspect-[2/3] w-full object-contain" /><span className="block p-2 font-serif text-xs font-bold text-amber-200">{card.name}<small className="block text-stone-500">{card.rarity} · {card.copy_count}x</small></span></button>)}</div></div></motion.div>}</AnimatePresence>
    <AnimatePresence>{matchState?.status === "setup" && <motion.div initial={{ opacity: 0 }} animate={{ opacity: 1 }} className="fixed inset-0 z-[172] flex items-center justify-center bg-black/95 p-5"><div className="max-h-[92vh] w-full max-w-6xl overflow-y-auto rounded-xl border border-emerald-500/60 bg-stone-950 p-6"><h2 className="text-center font-serif text-3xl font-black text-emerald-200">Turno 0 · Preparação</h2><p className="mt-2 text-center text-stone-300">Arraste exatamente 3 cartas da mão para o Campo de Defesa. Também é possível selecionar clicando.</p><div onDragOver={e => e.preventDefault()} onDrop={e => { e.preventDefault(); const id=e.dataTransfer.getData("text/card-id"); if(id && !setupCards.has(id) && setupCards.size<3) setSetupCards(previous => new Set([...previous,id])) }} className="mx-auto my-5 flex min-h-32 max-w-xl items-center justify-center gap-4 rounded-xl border-2 border-dashed border-emerald-500/60 bg-emerald-950/20 p-3">{[...setupCards].map(id => { const card=hand.find(item => item.id===id); return card ? <button key={id} onClick={() => toggleSetup(id)} className="w-20 rounded ring-2 ring-emerald-300"><GameCard card={card.card_data ?? undefined} /></button> : null })}{Array.from({length:3-setupCards.size},(_,i)=><div key={i} className="flex aspect-[2/3] w-20 items-center justify-center rounded border border-dashed border-emerald-400/40 text-center text-[8px] uppercase text-emerald-300/60">Solte aqui</div>)}</div><div className="grid grid-cols-3 gap-5 sm:grid-cols-4 md:grid-cols-7">{hand.map(card => <button draggable onDragStart={e => { e.dataTransfer.effectAllowed="move"; e.dataTransfer.setData("text/card-id",card.id) }} key={card.id} onClick={() => toggleSetup(card.id)} className={`rounded-xl p-1 transition ${setupCards.has(card.id) ? "opacity-35 ring-2 ring-emerald-300" : "bg-stone-900 hover:bg-stone-800"}`}><GameCard card={card.card_data ?? undefined} interactive /></button>)}</div><button disabled={setupCards.size!==3} onClick={() => void duel.submitSetup([...setupCards]).then(() => { setSetupCards(new Set()); void duel.refresh() }).catch(error => setEffectMessage(error?.message ?? "Falha na preparação."))} className="mx-auto mt-7 block rounded-lg border border-emerald-300 bg-emerald-800 px-8 py-3 font-black text-white disabled:opacity-40">CONFIRMAR 3 CARTAS DE VIDA</button></div></motion.div>}</AnimatePresence>
    <AnimatePresence>{matchState?.status === "finished" && <motion.div initial={{ opacity: 0 }} animate={{ opacity: 1 }} className="fixed inset-0 z-[190] flex items-center justify-center bg-black/90"><div className="rounded-xl border border-amber-400 bg-stone-950 p-10 text-center"><Crown className="mx-auto mb-4 text-amber-300" size={48} /><h2 className="font-serif text-3xl font-black text-amber-200">{matchState.winner_id === userId ? "Vitória" : "Derrota"}</h2></div></motion.div>}</AnimatePresence>
  </motion.main>
}
