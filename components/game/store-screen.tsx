"use client"

import { useCallback, useEffect, useState } from "react"
import { AnimatePresence, motion } from "framer-motion"
import { Coins, Gift, PackageOpen, Sparkles } from "lucide-react"
import { supabase } from "@/lib/supabase"
import type { GameCard as GameCardType, Rarity } from "@/lib/game-data"
import { GachaModal } from "./gacha-modal"

interface PackType { id: string; code: string; name: string; description: string | null; price_coins: number; cards_per_pack: number; is_daily: boolean }
interface PackResult { card_id: string; name: string; image_url: string; rarity: Rarity; is_golden: boolean }

export function StoreScreen() {
  const [packs, setPacks] = useState<PackType[]>([])
  const [coins, setCoins] = useState(0)
  const [cards, setCards] = useState<GameCardType[] | null>(null)
  const [busy, setBusy] = useState<string | null>(null)
  const [error, setError] = useState<string | null>(null)

  const refresh = useCallback(async () => {
    const [wallet, packRows] = await Promise.all([supabase.from("my_wallet").select("coins").maybeSingle(), supabase.from("pack_types").select("id,code,name,description,price_coins,cards_per_pack,is_daily").eq("is_active", true).gt("price_coins", 0).order("price_coins")])
    if (wallet.data) setCoins(wallet.data.coins)
    if (packRows.data) setPacks(packRows.data as PackType[])
  }, [])
  useEffect(() => { void refresh() }, [refresh])

  const hydrate = async (results: PackResult[]) => {
    const ids = results.map(card => card.card_id)
    const { data } = await supabase.from("cards").select("id,name,image_url,element,rarity,card_type,is_original_rpg,base_power,base_max_life,effect_mana_cost,effect_text,card_effects(effect_code)").in("id", ids)
    const byId = new Map((data ?? []).map((card: any) => [card.id, card]))
    return results.map(result => { const card: any = byId.get(result.card_id); return { id: result.card_id, nome: result.name, image_url: result.image_url, elemento: (["Bestiário", "M&F", "Witcher", "Elfica", "Cívil", "Vampiro"].includes(card?.element) ? card.element : "Bestiário") as GameCardType["elemento"], raridade: result.rarity, tipo: card?.element ?? "Bestiário", mana: card?.effect_mana_cost ?? 0, ataque: card?.base_power ?? 0, vida: card?.base_max_life ?? 1, efeito: card?.effect_text ?? "", effect_definition: card?.card_effects ?? [], is_original_rpg: card?.is_original_rpg ?? false } })
  }

  const openResult = async (result: any) => { setCards(await hydrate(result?.cards ?? [])); await refresh() }
  const purchase = async (pack: PackType) => { setBusy(pack.id); setError(null); const { data, error: rpcError } = await supabase.rpc("purchase_and_open_pack", { p_pack_type_id: pack.id, p_idempotency_key: crypto.randomUUID() }); setBusy(null); if (rpcError) { setError(rpcError.message.includes("INSUFFICIENT_COINS") ? "Moedas de Ofier insuficientes!" : rpcError.message); return } await openResult(data) }
  const daily = async () => { setBusy("daily"); setError(null); const { data, error: rpcError } = await supabase.rpc("claim_daily_reward", { p_idempotency_key: crypto.randomUUID() }); setBusy(null); if (rpcError) { setError(rpcError.message); return } await openResult(data) }

  return <main className="relative min-h-screen overflow-hidden bg-[url('/yang-69TcSUVhbmY-unsplash.jpg')] bg-cover bg-fixed bg-center p-6 text-stone-100"><div className="absolute inset-0 bg-black/80 backdrop-blur-[2px]" /><div className="relative mx-auto max-w-7xl">
    <header className="mb-6 flex items-center justify-between rounded-xl border border-amber-600/40 bg-stone-950/75 p-5"><div><h1 className="font-serif text-3xl font-black text-amber-200">Mercado de Ofier</h1><p className="text-sm text-stone-400">Relíquias, grimórios e cartas escolhidas pelo destino.</p></div><div className="flex items-center gap-3 rounded-full border border-amber-400/60 bg-black/70 px-5 py-2 shadow-[0_0_20px_rgba(245,158,11,.3)]"><Coins className="text-amber-300" /><strong className="text-xl text-amber-100">{coins.toLocaleString("pt-BR")}</strong></div></header>
    {error && <motion.div initial={{ y: -10, opacity: 0 }} animate={{ y: 0, opacity: 1 }} className="mb-5 rounded-lg border border-red-500 bg-red-950/80 p-3 text-center font-bold text-red-200">{error}</motion.div>}
    <button onClick={() => void daily()} disabled={Boolean(busy)} className="mb-7 flex w-full items-center justify-between rounded-xl border border-amber-400 bg-gradient-to-r from-amber-950 via-stone-950 to-amber-950 p-5 text-left shadow-[0_0_30px_rgba(245,158,11,.22)] disabled:opacity-50"><span className="flex items-center gap-4"><Gift className="text-amber-300" size={35} /><span><b className="block font-serif text-xl text-amber-100">Resgate Diário</b><span className="text-sm text-stone-400">Reivindique sua recompensa gratuita nas Areias.</span></span></span><span className="rounded bg-amber-700 px-5 py-2 text-xs font-black">{busy === "daily" ? "INVOCANDO..." : "RESGATAR"}</span></button>
    <div className="grid gap-5 md:grid-cols-2 xl:grid-cols-4">{packs.map((pack, index) => <motion.article key={pack.id} whileHover={{ y: -8 }} className="relative overflow-hidden rounded-xl border-2 border-amber-700 bg-stone-950/90 p-5 shadow-2xl"><div className="mb-5 flex h-44 items-center justify-center rounded-lg border border-amber-700/30 bg-[radial-gradient(circle,#78350f,#0c0a09_65%)]">{index === packs.length - 1 ? <Sparkles className="animate-pulse text-amber-300" size={70} /> : <PackageOpen className="text-amber-300/80" size={70} />}</div><h2 className="font-serif text-xl font-black text-amber-100">{pack.name}</h2><p className="mt-2 min-h-20 text-sm leading-relaxed text-stone-400">{pack.description ?? ""}</p><div className="mt-5 flex items-center justify-between"><span className="flex items-center gap-1 text-lg font-black text-amber-300"><Coins size={18} />{pack.price_coins}</span><button disabled={Boolean(busy)} onClick={() => void purchase(pack)} className="rounded border border-amber-400 bg-amber-700 px-4 py-2 text-[10px] font-black text-amber-50 disabled:opacity-40">{busy === pack.id ? "ABRINDO..." : "COMPRAR E ABRIR"}</button></div></motion.article>)}</div>
  </div><AnimatePresence>{cards && <GachaModal cards={cards} onCollect={() => { setCards(null); void refresh() }} />}</AnimatePresence></main>
}
