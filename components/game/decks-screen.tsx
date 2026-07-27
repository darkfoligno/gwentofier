"use client"
import { useEffect, useState, useMemo } from "react"
import { Layers, Search, Settings, Save, Swords, Trash2, Plus, Minus, X } from "lucide-react"
import { supabase } from "@/lib/supabase"
import type { GameCard as GameCardType, Rarity, OfficialCardType } from "@/lib/game-data"
import { secureImageUrl } from "@/lib/secure-url"
import { GameCard } from "./game-card"

type DeckCard = { card_id: string; quantity: number; card: GameCardType }
type Deck = { id: string; name: string; is_valid: boolean; updated_at: string; is_active: boolean; deck_cards: DeckCard[] }

export function DecksScreen() {
  const [inventory, setInventory] = useState<(GameCardType & { quantity: number })[]>([])
  const [error, setError] = useState("")
  const [search, setSearch] = useState("")
  const [effectFilter, setEffectFilter] = useState("")
  const [rarityFilter, setRarityFilter] = useState<Rarity | null>(null)
  const [elementFilter, setElementFilter] = useState<OfficialCardType | null>(null)
  const [manaFilter, setManaFilter] = useState<number | null>(null)
  const [inspectedCard, setInspectedCard] = useState<GameCardType | null>(null)
  
  const [activeDeck, setActiveDeck] = useState<Deck | null>(null)
  const [deckName, setDeckName] = useState("Novo Deck")
  const [deckCards, setDeckCards] = useState<DeckCard[]>([])

  useEffect(() => {
    async function loadData() {
      const { data: { user } } = await supabase.auth.getUser()
      if (!user) return

      const { data: userCards, error: invError } = await supabase
        .from("user_cards")
        .select("quantity, cards(id,name,image_url,element,rarity,card_type,base_power,base_max_life,effect_mana_cost,effect_text)")
        .eq("user_id", user.id)
        .gt("quantity", 0)
      
      if (invError) { setError(invError.message); return }
      
      const mapped = (userCards ?? []).map((row: any) => ({
        id: row.cards.id,
        nome: row.cards.name,
        image_url: row.cards.image_url,
        elemento: row.cards.element,
        raridade: row.cards.rarity,
        tipo: row.cards.card_type,
        mana: row.cards.effect_mana_cost,
        ataque: row.cards.base_power,
        vida: row.cards.base_max_life,
        efeito: row.cards.effect_text,
        quantity: row.quantity
      }))
      setInventory(mapped)
    }
    void loadData()
  }, [])

  const filtered = useMemo(() => {
    return inventory.filter(c => {
      if (search && !c.nome.toLowerCase().includes(search.toLowerCase())) return false
      if (effectFilter && !c.efeito.toLowerCase().includes(effectFilter.toLowerCase())) return false
      if (rarityFilter && c.raridade !== rarityFilter) return false
      if (elementFilter && c.elemento !== elementFilter) return false
      if (manaFilter !== null) {
        if (manaFilter === 6 && c.mana < 6) return false
        if (manaFilter !== 6 && c.mana !== manaFilter) return false
      }
      return true
    })
  }, [inventory, search, effectFilter, rarityFilter, elementFilter, manaFilter])

  const totalCards = deckCards.reduce((sum, c) => sum + c.quantity, 0)
  
  const addCard = (card: GameCardType) => {
    const invItem = inventory.find(i => i.id === card.id)
    if (!invItem) return
    const existing = deckCards.find(c => c.card_id === card.id)
    const currentQty = existing?.quantity || 0
    if (currentQty >= invItem.quantity) return // cannot add more than owned
    if (currentQty >= 3 && card.raridade !== 'legendary') return // rules
    if (currentQty >= 1 && card.raridade === 'legendary') return
    
    if (existing) {
      setDeckCards(deckCards.map(c => c.card_id === card.id ? { ...c, quantity: c.quantity + 1 } : c))
    } else {
      setDeckCards([...deckCards, { card_id: card.id, quantity: 1, card }])
    }
  }

  const removeCard = (cardId: string) => {
    const existing = deckCards.find(c => c.card_id === cardId)
    if (!existing) return
    if (existing.quantity > 1) {
      setDeckCards(deckCards.map(c => c.card_id === cardId ? { ...c, quantity: c.quantity - 1 } : c))
    } else {
      setDeckCards(deckCards.filter(c => c.card_id !== cardId))
    }
  }

  const manaCurve = [0,1,2,3,4,5].map(cost => {
    if (cost === 5) return deckCards.filter(c => c.card.mana >= 5).reduce((s, c) => s + c.quantity, 0)
    return deckCards.filter(c => c.card.mana === cost).reduce((s, c) => s + c.quantity, 0)
  })
  const maxMana = Math.max(...manaCurve, 1)

  const saveDeck = async () => {
    const { data: { user } } = await supabase.auth.getUser()
    if (!user) return
    
    const total = deckCards.reduce((sum, c) => sum + c.quantity, 0)
    if (total < 20 || total > 40) {
      alert("O deck deve conter entre 20 e 40 cartas.")
      return
    }

    try {
      let deckId = activeDeck?.id;
      if (!deckId) {
        const { data, error } = await supabase.from('decks').insert({ user_id: user.id, name: deckName, total_cards: total, is_valid: true }).select().single()
        if (error) throw error
        deckId = data.id
      } else {
        const { error } = await supabase.from('decks').update({ name: deckName, total_cards: total, is_valid: true }).eq('id', deckId)
        if (error) throw error
      }

      await supabase.from('deck_cards').delete().eq('deck_id', deckId)
      
      if (deckCards.length > 0) {
        const inserts = deckCards.map(dc => ({ deck_id: deckId, card_id: dc.card_id, quantity: dc.quantity }))
        const { error: cErr } = await supabase.from('deck_cards').insert(inserts)
        if (cErr) throw cErr
      }
      
      alert("Deck salvo com sucesso no Grimório!")
      setActiveDeck({ id: deckId as string, name: deckName, is_valid: true, updated_at: new Date().toISOString(), is_active: false, deck_cards: deckCards })
    } catch (err: any) {
      console.error(err)
      alert("Erro ao salvar deck: " + err.message)
    }
  }

  return (
    <main className="min-h-screen bg-[url('/yang-69TcSUVhbmY-unsplash.jpg')] bg-cover bg-fixed bg-center p-6 pt-20 text-stone-100">
      <div className="absolute inset-0 bg-black/85 backdrop-blur-[4px]" />
      <div className="relative mx-auto grid max-w-[1800px] grid-cols-1 gap-6 lg:grid-cols-12">
        {/* Painel Esquerdo - Inventário */}
        <section className="lg:col-span-8">
          <header className="mb-6 rounded-xl border border-amber-600/30 bg-zinc-950/80 p-5 shadow-xl">
            <h1 className="font-serif text-3xl font-black text-amber-400">Grimório de Decks</h1>
            <p className="mb-4 text-sm text-zinc-400">Monte suas estratégias com as cartas do seu Acervo Pessoal.</p>
            <div className="flex flex-wrap items-center gap-3">
              <div className="relative flex-1 min-w-[200px]">
                <Search className="absolute left-3 top-1/2 -translate-y-1/2 text-zinc-500" size={16} />
                <input value={search} onChange={e => setSearch(e.target.value)} placeholder="Pesquisar por nome..." className="w-full rounded border border-amber-800/40 bg-black py-2 pl-9 pr-3 text-sm text-zinc-200 outline-none focus:border-amber-500" />
              </div>
              <div className="relative flex-1 min-w-[200px]">
                <Search className="absolute left-3 top-1/2 -translate-y-1/2 text-zinc-500" size={16} />
                <input value={effectFilter} onChange={e => setEffectFilter(e.target.value)} placeholder="Filtrar por efeito..." className="w-full rounded border border-amber-800/40 bg-black py-2 pl-9 pr-3 text-sm text-zinc-200 outline-none focus:border-amber-500" />
              </div>
              <div className="flex gap-1">
                {[0,1,2,3,4,5,6].map(m => (
                  <button key={m} onClick={() => setManaFilter(manaFilter === m ? null : m)} className={`flex h-9 w-9 items-center justify-center rounded border font-mono text-sm font-bold ${manaFilter === m ? 'border-amber-400 bg-amber-900/50 text-amber-200' : 'border-zinc-700 bg-black text-zinc-400 hover:border-amber-700'}`}>{m === 6 ? '6+' : m}</button>
                ))}
              </div>
            </div>
          </header>

          {inventory.length === 0 ? (
            <div className="flex flex-col items-center justify-center py-20 text-zinc-500">
              <Layers size={48} className="mb-4 opacity-20" />
              <p>Seu acervo está vazio. Vá até o Mercado de Ofier para adquirir pacotes.</p>
            </div>
          ) : (
            <div className="grid grid-cols-4 gap-2 sm:grid-cols-6 md:grid-cols-8 xl:grid-cols-10">
              {filtered.map(card => {
                const countInDeck = deckCards.find(dc => dc.card_id === card.id)?.quantity || 0
                return (
                  <div key={card.id} className="group relative cursor-pointer" onClick={() => setInspectedCard(card)}>
                    <img src={secureImageUrl(card.image_url)} alt={card.nome} className="aspect-[2/3] w-full rounded-md object-cover shadow-md border border-stone-800 transition-all group-hover:scale-105 group-hover:border-amber-500 group-hover:shadow-amber-500/20" />
                    <div className="absolute -right-2 -top-2 z-10 flex h-6 w-6 items-center justify-center rounded-full border-2 border-amber-500 bg-zinc-950 text-xs font-black text-amber-400 shadow-lg">{card.quantity}</div>
                    
                    {/* Add button direct overlay */}
                    <button 
                      onClick={(e) => { e.stopPropagation(); addCard(card); }} 
                      className="absolute bottom-2 right-2 z-20 flex h-7 w-7 items-center justify-center rounded-full border border-emerald-500 bg-emerald-950/90 text-emerald-200 hover:bg-emerald-800 hover:text-white transition-all shadow-md"
                      title="Adicionar ao Deck"
                    >
                      <Plus size={12} />
                    </button>
                    {countInDeck > 0 && (
                      <div className="absolute left-2 bottom-2 z-20 flex h-5 px-1.5 items-center justify-center rounded border border-amber-500 bg-amber-950/90 text-[10px] font-bold text-amber-300">
                        {countInDeck} no deck
                      </div>
                    )}
                  </div>
                )
              })}
            </div>
          )}
        </section>

        {/* Painel Direito - Mesa de Edição */}
        <aside className="lg:col-span-4">
          <div className="sticky top-24 rounded-xl border border-amber-500/20 bg-zinc-950/90 p-5 shadow-2xl">
            <input value={deckName} onChange={e => setDeckName(e.target.value)} className="w-full bg-transparent font-serif text-2xl font-black text-amber-400 outline-none" />
            <p className="mt-1 text-sm text-zinc-400">Cartas no deck: <span className={`font-bold ${totalCards < 20 ? 'text-red-400' : 'text-amber-400'}`}>{totalCards}/40</span></p>

            <div className="mt-6 flex h-16 items-end gap-1 rounded bg-black/40 p-2">
              {manaCurve.map((count, i) => (
                <div key={i} className="group relative flex flex-1 flex-col items-center justify-end">
                  <div className="w-full rounded-t bg-amber-600/80 transition-all hover:bg-amber-400" style={{ height: `${(count / maxMana) * 100}%`, minHeight: count > 0 ? '4px' : '0' }} />
                  <span className="mt-1 text-[10px] font-bold text-zinc-500">{i === 5 ? '5+' : i}</span>
                </div>
              ))}
            </div>

            <div className="mt-4 flex max-h-[400px] flex-col gap-1 overflow-y-auto pr-2">
              {deckCards.map(dc => (
                <div 
                  key={dc.card_id} 
                  className="flex items-center justify-between rounded border border-zinc-800 bg-black/60 p-2 hover:border-amber-900/50 cursor-pointer transition-colors"
                  onClick={() => setInspectedCard(dc.card)}
                >
                  <div className="flex items-center gap-3">
                    <span className="flex h-6 w-6 items-center justify-center rounded border border-amber-500/30 bg-amber-950 text-xs font-black text-amber-200">{dc.quantity}</span>
                    <span className="truncate text-sm font-bold text-zinc-200">{dc.card.nome}</span>
                  </div>
                  <div className="flex items-center gap-2" onClick={e => e.stopPropagation()}>
                    <span className="font-mono text-xs text-blue-300">{dc.card.mana}M</span>
                    <button onClick={() => removeCard(dc.card_id)} className="rounded bg-red-950 p-1 text-red-400 hover:bg-red-900 hover:text-red-200"><Minus size={14} /></button>
                  </div>
                </div>
              ))}
              {deckCards.length === 0 && <p className="py-10 text-center text-sm text-zinc-600">Adicione cartas do acervo para construir seu deck.</p>}
            </div>

            <div className="mt-6 flex flex-col gap-2">
              <button onClick={saveDeck} className="flex items-center justify-center gap-2 rounded border border-amber-600 bg-amber-900/40 py-3 font-bold text-amber-200 shadow-[0_0_15px_rgba(217,119,6,0.15)] hover:bg-amber-800"><Save size={18} /> Salvar no Grimório</button>
              <button className="flex items-center justify-center gap-2 rounded border border-emerald-600 bg-emerald-900/40 py-3 font-bold text-emerald-200 hover:bg-emerald-800"><Swords size={18} /> Ativar para Combate</button>
              <button onClick={() => { setDeckCards([]); setDeckName("Novo Deck") }} className="flex items-center justify-center gap-2 rounded border border-zinc-700 bg-zinc-900 py-2 text-sm font-bold text-zinc-400 hover:bg-zinc-800 hover:text-zinc-200"><Trash2 size={16} /> Novo Deck / Limpar</button>
            </div>
          </div>
        </aside>
      </div>
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
                
                <h2 className="font-serif text-2xl font-black text-amber-200 mb-4 tracking-wider">{inspectedCard.nome}</h2>
                
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

                <div className="border border-amber-900/30 bg-black/60 rounded-xl p-4.5 mb-6 shadow-inner">
                  <h4 className="text-[10px] font-serif font-bold text-amber-500 uppercase tracking-widest mb-2">Efeito de Combate</h4>
                  <p className="text-xs text-stone-300 leading-relaxed font-sans font-medium">{inspectedCard.efeito || "Sem efeito ativo."}</p>
                </div>
              </div>

              {/* Action buttons inside zoom modal */}
              <div className="flex gap-3 mt-auto">
                <button 
                  onClick={() => addCard(inspectedCard)}
                  className="flex-1 rounded-lg border border-emerald-500 bg-emerald-950/80 hover:bg-emerald-900 py-3 text-xs font-serif font-black uppercase text-emerald-100 shadow-[0_4px_12px_rgba(16,185,129,0.15)] flex items-center justify-center gap-1.5 transition-colors"
                >
                  <Plus size={14} /> Adicionar
                </button>
                <button 
                  onClick={() => removeCard(inspectedCard.id)}
                  className="flex-1 rounded-lg border border-red-500 bg-red-950/80 hover:bg-red-900 py-3 text-xs font-serif font-black uppercase text-red-100 flex items-center justify-center gap-1.5 transition-colors"
                >
                  <Minus size={14} /> Remover
                </button>
              </div>
            </div>
          </div>
        </div>
      )}
    </main>
  )
}
