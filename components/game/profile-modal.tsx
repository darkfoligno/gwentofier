"use client"

import { useState } from "react"
import { motion } from "framer-motion"
import { KeyRound, Save, UserRound, X } from "lucide-react"
import { supabase } from "@/lib/supabase"

export interface ProfileSummary { username: string; avatar_url: string | null }

export function ProfileModal({ profile, email, onClose, onSaved }: { profile: ProfileSummary; email: string; onClose: () => void; onSaved: (profile: ProfileSummary) => void }) {
  const [username, setUsername] = useState(profile.username)
  const [avatarUrl, setAvatarUrl] = useState(profile.avatar_url ?? "")
  const [message, setMessage] = useState<string | null>(null)
  const [busy, setBusy] = useState(false)
  const validName = username.trim().length >= 3 && username.trim().length <= 24 && /^[A-Za-zÀ-ÿ0-9_ -]+$/.test(username.trim())
  const save = async () => { if (!validName) return; setBusy(true); setMessage(null); const { data, error } = await supabase.rpc("update_my_profile", { p_username: username.trim(), p_avatar_url: avatarUrl.trim() || null }); setBusy(false); if (error) { setMessage(error.message); return } const saved = data as ProfileSummary; onSaved(saved); setMessage("Perfil atualizado.") }
  const resetPassword = async () => { setBusy(true); const { error } = await supabase.auth.resetPasswordForEmail(email); setBusy(false); setMessage(error ? error.message : "E-mail de redefinição enviado.") }
  return <motion.div initial={{ opacity: 0 }} animate={{ opacity: 1 }} exit={{ opacity: 0 }} onClick={onClose} className="fixed inset-0 z-[400] flex items-center justify-center bg-black/85 p-4 backdrop-blur-md"><motion.section initial={{ scale: .94, y: 18 }} animate={{ scale: 1, y: 0 }} onClick={event => event.stopPropagation()} className="relative w-full max-w-lg rounded-xl border border-amber-500/50 bg-stone-950 p-6 shadow-[0_0_50px_rgba(245,158,11,.2)]"><button onClick={onClose} className="absolute right-4 top-4 text-stone-400 hover:text-amber-200"><X /></button><h2 className="mb-6 flex items-center gap-2 font-serif text-2xl font-black text-amber-200"><UserRound /> Perfil</h2>
    <label className="mb-4 block text-xs font-bold uppercase text-stone-400">Nome de usuário<input value={username} onChange={event => setUsername(event.target.value)} maxLength={24} className="mt-2 w-full rounded border border-amber-800/50 bg-black p-3 text-sm normal-case text-stone-100" /></label>{!validName && <p className="-mt-2 mb-4 text-xs text-red-300">Use de 3 a 24 caracteres: letras, números, espaço, _ ou -.</p>}
    <label className="mb-5 block text-xs font-bold uppercase text-stone-400">URL do avatar<input value={avatarUrl} onChange={event => setAvatarUrl(event.target.value)} type="url" className="mt-2 w-full rounded border border-amber-800/50 bg-black p-3 text-sm normal-case text-stone-100" /></label>
    {message && <p className="mb-4 rounded border border-amber-700/40 bg-amber-950/30 p-2 text-center text-xs text-amber-100">{message}</p>}<div className="flex flex-wrap gap-3"><button disabled={busy || !validName} onClick={() => void save()} className="flex flex-1 items-center justify-center gap-2 rounded border border-amber-400 bg-amber-700 px-4 py-3 text-xs font-black disabled:opacity-40"><Save size={15} /> SALVAR PERFIL</button><button disabled={busy} onClick={() => void resetPassword()} className="flex flex-1 items-center justify-center gap-2 rounded border border-blue-500 bg-blue-950 px-4 py-3 text-xs font-black text-blue-200 disabled:opacity-40"><KeyRound size={15} /> REDEFINIR SENHA</button></div>
  </motion.section></motion.div>
}
