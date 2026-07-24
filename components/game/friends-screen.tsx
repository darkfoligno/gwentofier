"use client"

import { useCallback, useEffect, useState } from "react"
import { Check, UserPlus, Users, X } from "lucide-react"
import { supabase } from "@/lib/supabase"
import { secureImageUrl } from "@/lib/secure-url"

type Contact = { request_id?: string; user_id: string; username: string; avatar_url: string | null; status: string; direction: "friend" | "received" | "sent" }

export function FriendsScreen() {
  const [contacts, setContacts] = useState<Contact[]>([]), [username, setUsername] = useState(""), [message, setMessage] = useState(""), [busy, setBusy] = useState(false)
  const [allProfiles, setAllProfiles] = useState<any[]>([])
  const [inspectedUser, setInspectedUser] = useState<{username: string; avatarUrl: string | null; wins: number; losses: number; draws: number; deckCards: number} | null>(null)
  const load = useCallback(async () => {
    const { data: { user } } = await supabase.auth.getUser()
    const { data, error } = await supabase.rpc("get_my_social_connections"); 
    if (error) setMessage(readError(error)); else setContacts(Array.isArray(data) ? data : []) 
    const { data: profs } = await supabase.from("profiles").select("id, username, avatar_url")
    if (profs && user) setAllProfiles(profs.filter(p => p.id !== user.id))
  }, [])
  useEffect(() => { void load() }, [load])
  const send = async () => { if (!username.trim()) return; setBusy(true); setMessage(""); const { error } = await supabase.rpc("send_friend_request", { p_username: username.trim() }); setBusy(false); if (error) setMessage(readError(error)); else { setUsername(""); setMessage("Convite enviado."); void load() } }
  const respond = async (id: string, accept: boolean) => { setBusy(true); const { error } = await supabase.rpc("respond_friend_request", { p_request_id: id, p_accept: accept }); setBusy(false); if (error) setMessage(readError(error)); else void load() }
  const contactNames = new Set(contacts.map(c => c.username))
  const suggestions = allProfiles.filter(p => !contactNames.has(p.username))
  
  const inspectUser = async (userId: string, uname: string, avatar: string | null) => {
    setBusy(true)
    const [statsRes, deckRes] = await Promise.all([
      supabase.from('player_stats').select('wins, losses, draws').eq('user_id', userId).maybeSingle(),
      supabase.from('decks').select('total_cards').eq('user_id', userId).order('updated_at', { ascending: false }).limit(1).maybeSingle()
    ])
    setBusy(false)
    setInspectedUser({
      username: uname,
      avatarUrl: avatar,
      wins: statsRes.data?.wins || 0,
      losses: statsRes.data?.losses || 0,
      draws: statsRes.data?.draws || 0,
      deckCards: deckRes.data?.total_cards || 0
    })
  }
  
  return <main className="min-h-screen bg-stone-950 p-6 pt-20 text-stone-100"><div className="mx-auto max-w-5xl"><h1 className="font-serif text-3xl font-black text-amber-200"><Users className="mr-3 inline" />Contatos & Convites</h1><div className="my-6 flex gap-2 rounded-xl border border-amber-800/40 bg-black/50 p-4"><input value={username} onChange={e => setUsername(e.target.value)} placeholder="Nome exato do jogador" className="min-w-0 flex-1 rounded border border-stone-700 bg-stone-950 px-3 py-2" /><button disabled={busy} onClick={() => void send()} className="rounded border border-emerald-500 bg-emerald-950 px-4 font-bold"><UserPlus className="mr-2 inline" size={16} />CONVIDAR</button></div>{message && <p className="mb-4 rounded border border-amber-700/40 bg-amber-950/40 p-3 text-sm text-amber-100">{message}</p>}
  
  <h2 className="mb-3 font-serif text-xl font-bold text-amber-100">Meus Contatos</h2>
  <div className="grid gap-3 md:grid-cols-2">{contacts.map(contact => <article key={`${contact.direction}-${contact.user_id}`} onClick={() => void inspectUser(contact.user_id, contact.username, contact.avatar_url)} className="flex cursor-pointer items-center gap-3 rounded-lg border border-stone-700 bg-black/50 p-4 transition-colors hover:border-amber-500/50">{contact.avatar_url ? <img src={secureImageUrl(contact.avatar_url)} alt="" className="h-12 w-12 rounded-full object-cover" /> : <div className="h-12 w-12 rounded-full bg-amber-900" />}<div className="min-w-0 flex-1"><b className="block truncate text-amber-100">{contact.username}</b><span className="text-xs text-stone-400">{contact.direction === "friend" ? "Amigo" : contact.direction === "received" ? "Convite recebido" : "Convite enviado"}</span></div>{contact.direction === "received" && contact.request_id && <div className="flex gap-1"><button aria-label="Aceitar" disabled={busy} onClick={(e) => { e.stopPropagation(); void respond(contact.request_id!, true) }} className="rounded bg-emerald-800 p-2"><Check size={16} /></button><button aria-label="Recusar" disabled={busy} onClick={(e) => { e.stopPropagation(); void respond(contact.request_id!, false) }} className="rounded bg-red-900 p-2"><X size={16} /></button></div>}</article>)}</div>{!contacts.length && !message && <p className="py-10 text-center text-stone-500">Nenhum contato ou convite no momento.</p>}
  
  {suggestions.length > 0 && <>
    <h2 className="mb-3 mt-10 font-serif text-xl font-bold text-amber-100">Jogadores da Arena</h2>
    <div className="grid gap-3 md:grid-cols-2">{suggestions.map(p => <article key={p.id} onClick={() => void inspectUser(p.id, p.username, p.avatar_url)} className="flex cursor-pointer items-center gap-3 rounded-lg border border-stone-800 bg-stone-900/50 p-4 transition-colors hover:border-amber-500/50">{p.avatar_url ? <img src={secureImageUrl(p.avatar_url)} alt="" className="h-12 w-12 rounded-full object-cover" /> : <div className="h-12 w-12 rounded-full bg-stone-800" />}<div className="min-w-0 flex-1"><b className="block truncate text-stone-300">{p.username}</b></div><button aria-label="Convidar" disabled={busy} onClick={(e) => { e.stopPropagation(); setUsername(p.username); setTimeout(() => send(), 100) }} className="rounded bg-stone-800 p-2 text-stone-300 hover:bg-emerald-900 hover:text-emerald-100"><UserPlus size={16} /></button></article>)}</div>
  </>}
  
  {inspectedUser && (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/80 backdrop-blur-sm p-4">
      <div className="relative w-full max-w-sm rounded-2xl border border-amber-600/40 bg-zinc-950 p-6 shadow-2xl">
        <button onClick={() => setInspectedUser(null)} className="absolute right-4 top-4 rounded bg-stone-800 p-1 text-stone-400 hover:text-white"><X size={20} /></button>
        <div className="flex flex-col items-center">
          {inspectedUser.avatarUrl ? <img src={secureImageUrl(inspectedUser.avatarUrl)} className="mb-4 h-24 w-24 rounded-full border-2 border-amber-600 object-cover" alt="" /> : <div className="mb-4 h-24 w-24 rounded-full border-2 border-amber-600 bg-amber-900" />}
          <h3 className="font-serif text-2xl font-black text-amber-200">{inspectedUser.username}</h3>
          
          <div className="mt-6 w-full grid grid-cols-3 gap-2 text-center">
            <div className="rounded bg-emerald-950/40 border border-emerald-900/50 p-2">
              <span className="block text-[10px] text-emerald-400 font-bold uppercase">Vitórias</span>
              <b className="text-xl text-emerald-200">{inspectedUser.wins}</b>
            </div>
            <div className="rounded bg-red-950/40 border border-red-900/50 p-2">
              <span className="block text-[10px] text-red-400 font-bold uppercase">Derrotas</span>
              <b className="text-xl text-red-200">{inspectedUser.losses}</b>
            </div>
            <div className="rounded bg-stone-900 border border-stone-800 p-2">
              <span className="block text-[10px] text-stone-400 font-bold uppercase">Empates</span>
              <b className="text-xl text-stone-200">{inspectedUser.draws}</b>
            </div>
          </div>
          
          <div className="mt-4 w-full rounded border border-amber-800/30 bg-amber-950/20 p-3 text-center">
            <span className="block text-xs font-bold text-amber-500 uppercase tracking-widest">Cartas no Deck Ativo</span>
            <b className="text-2xl text-amber-100">{inspectedUser.deckCards}</b>
          </div>
        </div>
      </div>
    </div>
  )}

  </div></main>
}
function readError(error: { message: string; details?: string; hint?: string; code?: string }) { return [error.message, error.details, error.hint, error.code && `Código: ${error.code}`].filter(Boolean).join(" · ") }
