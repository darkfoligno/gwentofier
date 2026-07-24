"use client"
import { useEffect, useMemo, useState } from "react"
import { Search } from "lucide-react"
import { supabase } from "@/lib/supabase"
import { GameCard } from "./game-card"
import type { GameCard as Card, OfficialCardType, Rarity } from "@/lib/game-data"

export function CollectionScreen() {
  const [owned, setOwned] = useState<Array<{ id: string; quantity: number; owner: string; card: Card }>>([]), [query, setQuery] = useState(""), [error, setError] = useState("")
  useEffect(() => {
    void supabase.from("user_cards").select("user_id,quantity,profiles(username),cards(id,name,image_url,element,rarity,is_original_rpg,base_power,base_max_life,effect_mana_cost,effect_text,card_effects(effect_code))").gt("quantity", 0).then(({ data, error: issue }) => {
      if (issue) return setError(issue.message)
      setOwned((data ?? []).flatMap((row: any) => row.cards ? [{ id: `${row.user_id}_${row.cards.id}`, quantity: row.quantity, owner: row.profiles?.username || "Desconhecido", card: { id: row.cards.id, nome: row.cards.name, image_url: row.cards.image_url, elemento: row.cards.element as OfficialCardType, tipo: row.cards.element, raridade: row.cards.rarity as Rarity, mana: row.cards.effect_mana_cost, ataque: row.cards.base_power, vida: row.cards.base_max_life, efeito: row.cards.effect_text ?? "", effect_definition: row.cards.card_effects ?? [], is_original_rpg: row.cards.is_original_rpg } }] : []))
    })
  }, [])
  const shown = useMemo(() => owned.filter(item => item.card.nome.toLowerCase().includes(query.toLowerCase()) || item.owner.toLowerCase().includes(query.toLowerCase())), [owned, query])
  return <main className="min-h-screen bg-stone-950 p-6 pt-20 text-stone-100"><div className="mx-auto max-w-[1500px]"><h1 className="font-serif text-3xl font-black text-amber-200">Cartas Adquiridas Pelos Jogadores</h1><p className="text-sm text-stone-400">Galeria global mostrando todas as cartas já tiradas nos pacotes pelos jogadores de Gwentofier.</p><div className="relative my-5"><Search className="absolute left-3 top-1/2 -translate-y-1/2 text-stone-500" size={16} /><input value={query} onChange={e => setQuery(e.target.value)} placeholder="Pesquisar por carta ou por jogador" className="w-full rounded border border-amber-800/40 bg-black py-3 pl-10" /></div>{error && <p className="rounded border border-red-600 bg-red-950 p-3">{error}</p>}<div className="grid grid-cols-2 gap-4 sm:grid-cols-3 md:grid-cols-5 lg:grid-cols-7 xl:grid-cols-9">{shown.map(({ id, card, quantity, owner }) => <div key={id} className="relative group cursor-pointer transition-transform hover:scale-105"><GameCard card={card} interactive enableZoom /><div className="absolute inset-0 z-30 flex flex-col items-center justify-center bg-black/80 opacity-0 backdrop-blur-sm transition-opacity group-hover:opacity-100 rounded-lg"><span className="mb-1 text-[10px] font-bold text-stone-300 uppercase tracking-wider">Pertence a:</span><span className="text-center font-serif text-lg font-black text-amber-300 px-2">{owner}</span><span className="mt-2 rounded-full border border-amber-600 bg-amber-950/80 px-3 py-1 text-xs font-bold text-amber-100">Quantidade: {quantity}</span></div></div>)}</div>{!shown.length && !error && <p className="py-20 text-center text-stone-500">Nenhuma carta encontrada com esses filtros.</p>}</div></main>
}
