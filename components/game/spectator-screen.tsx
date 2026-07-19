"use client"

import { useCallback, useEffect, useState } from "react"
import { motion } from "framer-motion"
import { Eye, Hourglass, Users } from "lucide-react"
import { supabase } from "@/lib/supabase"
import type { MatchPublicStateRow } from "@/lib/types"
import { secureImageUrl } from "@/lib/secure-url"

interface PublicMatch { id: string; current_turn: number }
interface PublicBoardCard { instance_id: string | null; owner_user_id: string; controller_user_id: string; zone: string; position: number | null; is_face_up: boolean; name: string | null; image_url: string | null; rarity: string | null; current_power: number | null; current_life: number | null }

export function SpectatorScreen() {
  const [matches, setMatches] = useState<PublicMatch[]>([])
  const [selected, setSelected] = useState<string | null>(null)
  const [state, setState] = useState<MatchPublicStateRow | null>(null)
  useEffect(() => { void supabase.from("matches").select("id,current_turn").eq("status", "in_progress").eq("is_private", false).order("created_at", { ascending: false }).then(({ data }) => setMatches((data ?? []) as PublicMatch[])) }, [])
  const fetchPublicState = useCallback(async () => { if (!selected) return; const { data, error } = await supabase.from("match_public_states").select("*").eq("match_id", selected).single(); if (!error) setState(data as MatchPublicStateRow) }, [selected])
  useEffect(() => { if (!selected) return; void fetchPublicState(); const channel = supabase.channel(`spectator:${selected}`).on("postgres_changes", { event: "UPDATE", schema: "public", table: "match_public_states", filter: `match_id=eq.${selected}` }, payload => setState(payload.new as MatchPublicStateRow)).subscribe(); return () => { void supabase.removeChannel(channel) } }, [fetchPublicState, selected])
  const cards = ((state?.public_board as { cards?: PublicBoardCard[] } | null)?.cards ?? [])
  if (!selected) return <main className="min-h-screen bg-stone-950 p-8 text-stone-100"><div className="mx-auto max-w-5xl"><h1 className="mb-2 flex items-center gap-3 font-serif text-3xl font-black text-amber-200"><Eye /> Duelos em andamento</h1><p className="mb-6 text-sm text-stone-400">Visualização pública e somente leitura.</p>{matches.length ? <div className="grid gap-4 md:grid-cols-2">{matches.map(match => <button key={match.id} onClick={() => setSelected(match.id)} className="flex items-center justify-between rounded-xl border border-amber-700/40 bg-black/40 p-5 text-left"><span><Users className="mb-2 text-amber-400" /><b className="block font-serif text-amber-100">Duelo público</b><small className="text-stone-500">{match.id.slice(0, 8)}</small></span><span className="flex items-center gap-2 text-sm text-amber-300"><Hourglass size={15} /> Turno {match.current_turn}</span></button>)}</div> : <div className="rounded-xl border border-dashed border-amber-800/40 p-16 text-center text-stone-500">Nenhum duelo público em andamento.</div>}</div></main>
  const zones = ["reinforcement", "life", "attacker", "leader"]
  return <main className="min-h-screen bg-[url('/yang-69TcSUVhbmY-unsplash.jpg')] bg-cover bg-center p-6 text-stone-100"><div className="mx-auto max-w-6xl rounded-xl border border-amber-700/40 bg-black/80 p-5"><div className="mb-5 flex items-center justify-between"><div><h1 className="font-serif text-2xl font-black text-amber-200">{state?.player1_username ?? "Jogador 1"} vs {state?.player2_username ?? "Jogador 2"}</h1><p className="text-xs text-stone-500">Modo espectador · somente public_board</p></div><button onClick={() => { setSelected(null); setState(null) }} className="rounded border border-stone-600 px-3 py-2 text-xs">VOLTAR</button></div>{zones.map(zone => <section key={zone} className="mb-4"><h2 className="mb-2 text-center text-[10px] font-black uppercase tracking-widest text-amber-400">{zone}</h2><div className="flex min-h-36 justify-center gap-3 overflow-x-auto rounded-lg border border-white/5 bg-black/30 p-3">{cards.filter(card => card.zone === zone).map((card, index) => <motion.div layout key={card.instance_id ?? `${zone}-${index}`} className="relative aspect-[2/3] w-24 shrink-0 overflow-hidden rounded-lg border border-amber-700/50 bg-stone-900">{card.image_url && card.is_face_up ? <img src={secureImageUrl(card.image_url)} alt={card.name ?? "Carta pública"} className="h-full w-full object-cover" /> : <div className="flex h-full items-center justify-center font-serif text-3xl text-amber-600/50">𓂀</div>}{card.name && <div className="absolute inset-x-0 bottom-0 bg-black/85 p-1 text-center text-[8px] text-amber-100">{card.name}<br />{card.current_power ?? 0} / {card.current_life ?? 0}</div>}</motion.div>)}</div></section>)}</div></main>
}
