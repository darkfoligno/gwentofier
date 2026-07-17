"use client"

import { useEffect, useMemo, useState } from "react"
import { AnimatePresence, motion } from "framer-motion"
import { AlertTriangle, Crown, Flag, Hourglass, Layers, Loader2, Skull, Swords, Wifi, WifiOff, X } from "lucide-react"
import { GameCard } from "./game-card"
import { ReactionModal } from "./reaction-modal"
import { useDuelRealtime } from "@/hooks/useDuelRealtime"
import { supabase } from "@/lib/supabase"
import type { BanCandidate, MatchCardZone, VisibleMatchCard } from "@/lib/types"

function EmptySlot({ label, onClick, danger = false }: { label: string; onClick?: () => void; danger?: boolean }) {
  return <button disabled={!onClick} onClick={onClick} className={`flex aspect-[2/3] w-[72px] shrink-0 items-center justify-center rounded-lg border border-dashed bg-black/25 text-[8px] font-bold uppercase tracking-[.18em] backdrop-blur-sm transition-all lg:w-[86px] ${danger ? "border-red-500/60 text-red-300 shadow-[inset_0_0_18px_rgba(239,68,68,.14)]" : "border-amber-500/40 text-amber-300/60 shadow-[inset_0_0_18px_rgba(245,158,11,.12)]"} ${onClick ? "hover:border-amber-300 hover:bg-amber-950/30" : ""}`}>{label}</button>
}

function CardView({ row, hidden = false, selected = false, onClick, ownerPreview = false }: { row: VisibleMatchCard; hidden?: boolean; selected?: boolean; onClick?: () => void; ownerPreview?: boolean }) {
  return <motion.button layout type="button" onClick={onClick} className={`relative aspect-[2/3] w-[72px] shrink-0 rounded-xl transition-all lg:w-[86px] ${selected ? "ring-2 ring-red-400 shadow-[0_0_24px_rgba(248,113,113,.8)]" : ""}`}>
    <GameCard card={row.card_data ?? undefined} isFaceDown={hidden} interactive={Boolean(onClick)} />
    {ownerPreview && hidden && row.card_data && <div className="pointer-events-none absolute inset-1 overflow-hidden rounded-lg opacity-20"><GameCard card={row.card_data} /></div>}
  </motion.button>
}

function Zone({ label, cards, slots = 4, hidden = false, selected, onCard, onEmpty, danger = false, ownerPreview = false }: { label: string; cards: VisibleMatchCard[]; slots?: number; hidden?: boolean; selected?: Set<string>; onCard?: (card: VisibleMatchCard) => void; onEmpty?: (position: number) => void; danger?: boolean; ownerPreview?: boolean }) {
  const occupied = new Set(cards.map(card => card.slot_index))
  return <section className="min-w-0"><div className="mb-1 flex items-center gap-2"><span className="h-px flex-1 bg-gradient-to-r from-transparent to-amber-600/30" /><h3 className="font-serif text-[9px] font-black uppercase tracking-[.24em] text-amber-200/70">{label}</h3><span className="h-px flex-1 bg-gradient-to-l from-transparent to-amber-600/30" /></div><div className="flex min-h-[108px] items-center justify-center gap-2 overflow-x-auto px-2 py-1 lg:min-h-[132px]">
    {cards.map(card => <CardView key={card.id} row={card} hidden={hidden && !card.is_face_up} selected={selected?.has(card.id)} onClick={onCard ? () => onCard(card) : undefined} ownerPreview={ownerPreview} />)}
    {Array.from({ length: slots }, (_, index) => index + 1).filter(position => !occupied.has(position)).map(position => <EmptySlot key={position} label={label} danger={danger} onClick={onEmpty ? () => onEmpty(position) : undefined} />)}
  </div></section>
}

function Pile({ label, count, graveyard = false, onClick }: { label: string; count: number; graveyard?: boolean; onClick?: () => void }) {
  const Icon = graveyard ? Skull : Layers
  return <button onClick={onClick} className="group flex items-center gap-3 rounded-lg border border-amber-700/30 bg-black/35 p-2 text-left shadow-lg backdrop-blur-md"><div className="relative flex aspect-[2/3] w-12 items-center justify-center rounded border border-amber-600/50 bg-gradient-to-br from-stone-900 to-amber-950"><Icon className="text-amber-300/70" size={20} /><span className="absolute -right-2 -top-2 rounded-full border border-amber-400 bg-black px-2 py-0.5 text-xs font-black text-amber-200">{count}</span></div><div><p className="font-serif text-[10px] font-black uppercase text-amber-200">{label}</p><p className="text-[9px] text-stone-400">{graveyard ? "Cartas destruídas" : "Cartas restantes"}</p></div></button>
}

function GraveyardModal({ cards, onClose }: { cards: VisibleMatchCard[]; onClose: () => void }) {
  return <motion.div initial={{ opacity: 0 }} animate={{ opacity: 1 }} exit={{ opacity: 0 }} onClick={onClose} className="fixed inset-0 z-[160] flex items-center justify-center bg-black/85 p-6 backdrop-blur-md"><div onClick={event => event.stopPropagation()} className="relative max-h-[80vh] w-full max-w-4xl overflow-y-auto rounded-xl border border-amber-500/50 bg-stone-950 p-6"><button onClick={onClose} className="absolute right-4 top-4 text-amber-200"><X /></button><h2 className="mb-5 font-serif text-xl font-black text-amber-200">Cemitério</h2><div className="grid grid-cols-3 gap-4 sm:grid-cols-5 lg:grid-cols-7">{cards.map(card => <CardView key={card.id} row={card} />)}</div></div></motion.div>
}

export function ArenaScreen() {
  const [matchId, setMatchId] = useState("")
  const [userId, setUserId] = useState("")
  const [selectedHand, setSelectedHand] = useState<string | null>(null)
  const [selectedAttackers, setSelectedAttackers] = useState<Set<string>>(new Set())
  const [graveyardOpen, setGraveyardOpen] = useState(false)
  const [banCandidates, setBanCandidates] = useState<BanCandidate[]>([])

  useEffect(() => { setMatchId(new URLSearchParams(window.location.search).get("matchId") ?? ""); void supabase.auth.getUser().then(({ data }) => setUserId(data.user?.id ?? "")) }, [])
  const duel = useDuelRealtime(matchId, userId)
  const { matchState, boardCards, matchActions, pendingAttack, connectionStatus, isCurrentPlayer, isPlayer1, opponentId, hasActedThisTurn, reactionUsed, getCardsByZone } = duel

  useEffect(() => { if (matchState?.status !== "ban_phase") { setBanCandidates([]); return } void duel.getBanCandidates().then(cards => setBanCandidates(cards.filter(card => card.rarity === "legendary" && card.is_golden))).catch(console.error) }, [matchId, matchState?.status])

  const mine = (zone: MatchCardZone) => getCardsByZone(zone, userId)
  const theirs = (zone: MatchCardZone) => getCardsByZone(zone, opponentId)
  const hand = mine("hand")
  const attackers = mine("attacker")
  const selectedPower = useMemo(() => attackers.filter(card => selectedAttackers.has(card.id)).reduce((sum, card) => sum + (card.current_power ?? 0), 0), [attackers, selectedAttackers])
  const myMana = matchState ? (isPlayer1 ? matchState.player1_mana : matchState.player2_mana) : 0
  const theirMana = matchState ? (isPlayer1 ? matchState.player2_mana : matchState.player1_mana) : 0
  const selectedCard = hand.find(card => card.id === selectedHand)
  const playSelected = (zone: "attacker" | "reinforcement", position: number) => selectedCard && void duel.playCard(selectedCard.id, zone, position).then(() => setSelectedHand(null))
  const toggleAttacker = (card: VisibleMatchCard) => setSelectedAttackers(previous => { const next = new Set(previous); next.has(card.id) ? next.delete(card.id) : next.add(card.id); return next })
  const reactions = boardCards.filter(card => card.controller_user_id === userId && ["life", "reinforcement", "attacker", "leader"].includes(card.zone) && (card.current_life ?? 0) > 0)

  if (!matchId) return <div className="flex min-h-screen items-center justify-center bg-stone-950 text-center text-amber-200"><div><Swords className="mx-auto mb-4" size={40} /><h1 className="font-serif text-xl font-black">Nenhuma batalha selecionada</h1><p className="mt-2 text-sm text-stone-400">Abra a Arena a partir de uma partida encontrada no Hub.</p></div></div>

  return <main className="relative h-screen overflow-hidden bg-[url('/yang-69TcSUVhbmY-unsplash.jpg')] bg-cover bg-center bg-no-repeat text-stone-100"><div className="absolute inset-0 bg-gradient-to-b from-black/80 via-black/60 to-black/85 backdrop-blur-[2px]" />
    <div className="relative z-10 grid h-[calc(100vh-150px)] grid-cols-[220px_minmax(620px,1fr)_190px] gap-3 overflow-x-auto p-3">
      <aside className="flex min-h-0 flex-col gap-3 rounded-xl border border-amber-800/30 bg-stone-950/55 p-3 backdrop-blur-md">
        <Pile label="Deck rival" count={isPlayer1 ? matchState?.player2_deck_count ?? 0 : matchState?.player1_deck_count ?? 0} /><Pile label="Cemitério rival" graveyard count={theirs("graveyard").length} />
        <div className="min-h-0 flex-1 rounded-lg border border-white/10 bg-black/30 p-2"><div className="mb-2 flex justify-between text-[9px] uppercase text-amber-300"><span>Log de batalha</span><span>v{matchState?.match_version ?? 0}</span></div><div className="h-full overflow-y-auto text-[9px] text-stone-400">{matchActions.map(action => <p key={action.id} className="border-b border-white/5 py-1"><span className="text-amber-500">#{action.sequence_number}</span> {action.action_type.replaceAll("_", " ")}</p>)}</div></div>
        <Pile label="Seu cemitério" graveyard count={mine("graveyard").length} onClick={() => setGraveyardOpen(true)} /><Pile label="Seu deck" count={isPlayer1 ? matchState?.player1_deck_count ?? 0 : matchState?.player2_deck_count ?? 0} />
      </aside>

      <section className="min-w-[620px] overflow-y-auto rounded-xl border border-amber-700/20 bg-black/20 px-2">
        <Zone label="Reforços do oponente" cards={theirs("reinforcement")} hidden /><Zone label="Vida do oponente" cards={theirs("life")} slots={3} danger={Boolean(pendingAttack)} /><Zone label="Atacantes do oponente" cards={theirs("attacker")} />
        <div className="sticky top-0 z-40 my-2 flex items-center justify-between gap-3 border-y border-amber-700/50 bg-stone-950/95 px-4 py-2 shadow-2xl">
          <div className="flex items-center gap-2 text-xs"><span className="h-7 w-7 rounded-full border border-blue-300 bg-blue-700 shadow-[0_0_14px_rgba(59,130,246,.8)]" /><b>{theirMana}</b><span className="text-stone-500">Rival</span></div>
          <div className={`flex items-center gap-2 rounded px-2 py-1 text-xs font-black ${matchState && matchState.current_turn >= 8 ? "animate-pulse bg-red-950 text-red-300" : "text-amber-200"}`}>{matchState && matchState.current_turn >= 8 ? <AlertTriangle size={15} /> : <Hourglass size={15} />} Turno {matchState?.current_turn ?? 0}</div>
          <div className="flex items-center gap-2"><button disabled={!isCurrentPlayer} onClick={() => void duel.endTurn()} className="rounded border border-amber-400 bg-amber-700 px-4 py-2 text-[10px] font-black text-amber-100 shadow-[0_0_15px_rgba(245,158,11,.3)] hover:bg-amber-600 disabled:opacity-40">ENCERRAR TURNO</button><button disabled={!isCurrentPlayer || hasActedThisTurn} onClick={() => void duel.passWithoutAction()} className="rounded border border-blue-400 bg-blue-900 px-4 py-2 text-[10px] font-black text-blue-100 disabled:opacity-40">PASSAR E COMPRAR</button><button onClick={() => void duel.surrenderMatch()} className="rounded border border-red-800 bg-red-950 px-2 py-2 text-red-300"><Flag size={14} /></button></div>
          <div className="flex items-center gap-2 text-xs"><span className="text-stone-500">Você</span><b>{myMana}</b><span className="h-7 w-7 rounded-full border border-blue-300 bg-blue-700 shadow-[0_0_14px_rgba(59,130,246,.8)]" /></div>
        </div>
        <Zone label="Seus atacantes" cards={attackers} selected={selectedAttackers} onCard={toggleAttacker} onEmpty={position => playSelected("attacker", position)} /><Zone label="Suas cartas de vida" cards={mine("life")} slots={3} danger onEmpty={selectedCard && matchState && matchState.current_turn > 0 && matchState.current_turn < 4 ? position => void duel.replaceEarlyLifeCard(selectedCard.id, position).then(() => setSelectedHand(null)) : undefined} /><Zone label="Seus reforços" cards={mine("reinforcement")} hidden ownerPreview onEmpty={position => playSelected("reinforcement", position)} />
        <button disabled={!selectedAttackers.size || !isCurrentPlayer} onClick={() => void duel.declareAttack([...selectedAttackers], false).then(() => setSelectedAttackers(new Set()))} className="fixed bottom-40 left-1/2 z-50 -translate-x-1/2 rounded-full border border-red-400 bg-red-900 px-5 py-2 text-xs font-black shadow-[0_0_22px_rgba(239,68,68,.55)] disabled:hidden"><Swords className="mr-2 inline" size={15} />ATACAR · {selectedPower}</button>
      </section>

      <aside className="flex flex-col justify-between rounded-xl border border-amber-800/30 bg-stone-950/55 p-3 backdrop-blur-md"><div><p className="mb-2 text-center font-serif text-[10px] font-black uppercase text-amber-300">Líder rival</p>{theirs("leader")[0] ? <CardView row={theirs("leader")[0]} /> : <EmptySlot label="Líder" />}</div><div className={`rounded-full border px-3 py-2 text-center text-[10px] font-bold ${connectionStatus === "connected" ? "border-emerald-400/50 bg-emerald-950/70 text-emerald-300" : "border-red-500/50 bg-red-950/70 text-red-300"}`}>{connectionStatus === "connected" ? <Wifi className="mr-1 inline" size={13} /> : connectionStatus === "syncing" ? <Loader2 className="mr-1 inline animate-spin" size={13} /> : <WifiOff className="mr-1 inline" size={13} />}{connectionStatus === "connected" ? "Conectado às Areias" : connectionStatus === "syncing" ? "Sincronizando" : "Desconectado"}</div><div><p className="mb-2 text-center font-serif text-[10px] font-black uppercase text-amber-300">Seu líder</p>{mine("leader")[0] ? <CardView row={mine("leader")[0]} onClick={() => void duel.activateMatchEffect(mine("leader")[0].id)} /> : <EmptySlot label="Líder" />}</div></aside>
    </div>

    <div className="absolute bottom-0 left-1/2 z-50 flex h-[150px] w-[min(900px,90vw)] -translate-x-1/2 items-end justify-center overflow-x-auto rounded-t-[30px] border-x border-t border-amber-600/30 bg-black/55 px-12 pb-2 pt-6 backdrop-blur-md"><div className="flex justify-center -space-x-8 transition-all duration-300 hover:space-x-2">{hand.map(card => <button key={card.id} onClick={() => setSelectedHand(card.id)} className={`aspect-[2/3] w-24 shrink-0 origin-bottom cursor-pointer transition-transform duration-200 hover:z-50 hover:-translate-y-10 hover:scale-110 ${selectedHand === card.id ? "z-40 -translate-y-6 ring-2 ring-amber-300 rounded-xl" : ""}`}><GameCard card={card.card_data ?? undefined} interactive /></button>)}</div></div>

    <AnimatePresence>{graveyardOpen && <GraveyardModal cards={mine("graveyard")} onClose={() => setGraveyardOpen(false)} />}</AnimatePresence>
    <AnimatePresence>{pendingAttack && pendingAttack.defender_user_id === userId && <ReactionModal attack={pendingAttack} reactionCards={reactions} mana={myMana} reactionUsed={reactionUsed} onActivate={duel.activateMatchEffect} onDecline={duel.declineAttackReaction} />}</AnimatePresence>
    <AnimatePresence>{matchState?.status === "ban_phase" && <motion.div initial={{ opacity: 0 }} animate={{ opacity: 1 }} className="fixed inset-0 z-[170] flex items-center justify-center bg-black/90 p-6"><div className="w-full max-w-3xl rounded-xl border border-amber-500 bg-stone-950 p-6"><h2 className="mb-1 text-center font-serif text-2xl font-black text-amber-200">Banimento Ofieri</h2><p className="mb-6 text-center text-sm text-stone-400">Escolha uma lendária dourada do oponente.</p><div className="grid grid-cols-2 gap-4 sm:grid-cols-4">{banCandidates.map(card => <button key={card.card_id} onClick={() => void duel.submitBan(card.card_id)} className="overflow-hidden rounded-lg border border-amber-500/50 bg-black"><img src={card.image_url} alt={card.name} className="aspect-[2/3] w-full object-cover" /><span className="block p-2 font-serif text-xs font-bold text-amber-200">{card.name}</span></button>)}</div></div></motion.div>}</AnimatePresence>
    <AnimatePresence>{matchState?.status === "finished" && <motion.div initial={{ opacity: 0 }} animate={{ opacity: 1 }} className="fixed inset-0 z-[190] flex items-center justify-center bg-black/90"><div className="rounded-xl border border-amber-400 bg-stone-950 p-10 text-center"><Crown className="mx-auto mb-4 text-amber-300" size={48} /><h2 className="font-serif text-3xl font-black text-amber-200">{matchState.winner_id === userId ? "Vitória" : "Derrota"}</h2></div></motion.div>}</AnimatePresence>
  </main>
}
