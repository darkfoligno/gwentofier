"use client"
import { useEffect, useState, useMemo } from "react"
import { Layers, Search, Settings, Save, Swords, Trash2, Plus, Minus, X, Info, Copy, Check } from "lucide-react"
import { supabase } from "@/lib/supabase"
import type { GameCard as GameCardType, Rarity, OfficialCardType } from "@/lib/game-data"
import { secureImageUrl } from "@/lib/secure-url"
import { GameCard } from "./game-card"

type DeckCard = { card_id: string; quantity: number; card: GameCardType }
type Deck = { id: string; name: string; is_valid: boolean; updated_at: string; is_active: boolean; deck_cards: DeckCard[] }

export function DecksScreen() {
  const [inventory, setInventory] = useState<(GameCardType & { quantity: number; last_obtained_at?: string })[]>([])
  const [error, setError] = useState("")
  const [search, setSearch] = useState("")
  const [effectFilter, setEffectFilter] = useState("")
  const [rarityFilter, setRarityFilter] = useState<Rarity | null>(null)
  const [elementFilter, setElementFilter] = useState<OfficialCardType | null>(null)
  const [manaFilter, setManaFilter] = useState<number | null>(null)
  const [inspectedCard, setInspectedCard] = useState<GameCardType | null>(null)
  const [sortBy, setSortBy] = useState<"name" | "recent">("name")
  
  // Decks States
  const [activeDeck, setActiveDeck] = useState<Deck | null>(null)
  const [deckName, setDeckName] = useState("Novo Deck")
  const [deckCards, setDeckCards] = useState<DeckCard[]>([])
  const [myDecks, setMyDecks] = useState<Deck[]>([])
  const [showSaveModal, setShowSaveModal] = useState(false)
  const [newDeckName, setNewDeckName] = useState("")

  // Lixeira / Recycle States
  const [trash, setTrash] = useState<{ [cardId: string]: number }>({})
  const [showRecycleModal, setShowRecycleModal] = useState(false)

  // Compare Owners States
  const [comparingCard, setComparingCard] = useState<GameCardType | null>(null)
  const [cardOwners, setCardOwners] = useState<{ username: string; quantity: number }[]>([])
  const [loadingOwners, setLoadingOwners] = useState(false)
  const [copied, setCopied] = useState(false)
  
  const handleCopyId = async (id: string) => {
    try {
      await navigator.clipboard.writeText(id)
      setCopied(true)
      setTimeout(() => setCopied(false), 2000)
    } catch (err) {
      console.error("Erro ao copiar ID", err)
    }
  }

  const loadDecks = async () => {
    const { data: { user } } = await supabase.auth.getUser()
    if (!user) return
    const { data, error } = await supabase
      .from('decks')
      .select('*, deck_cards(*, cards(*))')
      .eq('user_id', user.id)
      .order('updated_at', { ascending: false })
    
    if (error) {
      console.error(error)
      return
    }
    
    const mapped: Deck[] = (data ?? []).map((d: any) => ({
      id: d.id,
      name: d.name,
      is_valid: d.is_valid,
      updated_at: d.updated_at,
      is_active: d.is_favorite || false,
      deck_cards: (d.deck_cards ?? []).map((dc: any) => ({
        card_id: dc.card_id,
        quantity: dc.quantity,
        card: {
          id: dc.cards.id,
          nome: dc.cards.name,
          image_url: dc.cards.image_url,
          elemento: dc.cards.element,
          raridade: dc.cards.rarity,
          tipo: dc.cards.card_type,
          mana: dc.cards.effect_mana_cost,
          ataque: dc.cards.base_power,
          vida: dc.cards.base_max_life,
          efeito: dc.cards.effect_text,
          quantity: 1
        }
      }))
    }))
    setMyDecks(mapped)
  }

  const loadInventory = async () => {
    const { data: { user } } = await supabase.auth.getUser()
    if (!user) return

    const { data: userCards, error: invError } = await supabase
      .from("user_cards")
      .select("quantity, last_obtained_at, cards(id,name,image_url,element,rarity,card_type,base_power,base_max_life,effect_mana_cost,effect_text)")
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
      quantity: row.quantity,
      last_obtained_at: row.last_obtained_at
    }))
    setInventory(mapped)
  }

  useEffect(() => {
    void loadInventory()
    void loadDecks()
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

  const sorted = useMemo(() => {
    const list = [...filtered]
    if (sortBy === "name") {
      list.sort((a, b) => a.nome.localeCompare(b.nome))
    } else if (sortBy === "recent") {
      list.sort((a, b) => {
        const timeA = a.last_obtained_at ? new Date(a.last_obtained_at).getTime() : 0
        const timeB = b.last_obtained_at ? new Date(b.last_obtained_at).getTime() : 0
        return timeB - timeA
      })
    }
    return list
  }, [filtered, sortBy])

  const totalCards = deckCards.reduce((sum, c) => sum + c.quantity, 0)
  const legendaryCardsCount = deckCards.reduce((sum, c) => c.card.raridade === "legendary" ? sum + c.quantity : sum, 0)
  
  const addCard = (card: GameCardType) => {
    const invItem = inventory.find(i => i.id === card.id)
    if (!invItem) return
    const existing = deckCards.find(c => c.card_id === card.id)
    const currentQty = existing?.quantity || 0
    
    const inTrash = trash[card.id] || 0
    const available = invItem.quantity - inTrash
    
    if (currentQty >= available) return // cannot add more than owned & not trashed
    if (currentQty >= 3 && card.raridade !== 'legendary') return // rule: max 3 copies of non-legendary
    if (currentQty >= 1 && card.raridade === 'legendary') return // rule: max 1 copy of legendary
    
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

  // Lixeira Actions
  const addToTrash = (card: GameCardType) => {
    const invItem = inventory.find(i => i.id === card.id)
    if (!invItem) return
    
    const inDeck = deckCards.find(c => c.card_id === card.id)?.quantity || 0
    const inTrash = trash[card.id] || 0
    
    if (inTrash + inDeck >= invItem.quantity) {
      alert("Você não possui cópias livres desta carta no inventário (remova do deck se necessário).")
      return
    }
    
    setTrash({
      ...trash,
      [card.id]: inTrash + 1
    })
  }

  const removeFromTrash = (cardId: string) => {
    const inTrash = trash[cardId] || 0
    if (inTrash <= 1) {
      const copy = { ...trash }
      delete copy[cardId]
      setTrash(copy)
    } else {
      setTrash({
        ...trash,
        [cardId]: inTrash - 1
      })
    }
  }

  const calculateRecycleValue = () => {
    let total = 0
    Object.entries(trash).forEach(([cardId, qty]) => {
      const card = inventory.find(c => c.id === cardId)
      if (!card) return
      let value = 0
      if (card.raridade === 'common') value = 10
      else if (card.raridade === 'rare') value = 25
      else if (card.raridade === 'epic') value = 100
      else if (card.raridade === 'legendary') value = 250
      total += value * qty
    })
    return total
  }

  const totalTrashCount = Object.values(trash).reduce((sum, qty) => sum + qty, 0)

  const handleRecycleConfirm = async () => {
    const totalCoins = calculateRecycleValue()
    if (totalCoins <= 0) return
    
    const cardIdsArray: string[] = []
    Object.entries(trash).forEach(([cardId, qty]) => {
      for (let i = 0; i < qty; i++) {
        cardIdsArray.push(cardId)
      }
    })
    
    try {
      const { error } = await supabase.rpc('recycle_user_cards', { p_card_ids: cardIdsArray })
      if (error) throw error
      
      alert(`Sucesso! Você reciclou ${totalTrashCount} carta(s) e ganhou +${totalCoins} moedas!`)
      setTrash({})
      setShowRecycleModal(false)
      
      // Reload inventory data
      void loadInventory()
      
      // Refresh global layout coins by reloading window safely
      window.location.reload()
    } catch (err: any) {
      alert("Erro ao reciclar: " + err.message)
    }
  }

  // Compare Owners Action
  const handleCompare = async (card: GameCardType) => {
    setComparingCard(card)
    setLoadingOwners(true)
    setCardOwners([])
    try {
      const { data, error } = await supabase.rpc('get_card_owners', { p_card_id: card.id })
      if (error) throw error
      setCardOwners(data || [])
    } catch (err) {
      console.error(err)
    } finally {
      setLoadingOwners(false)
    }
  }

  // Save Deck Actions
  const handleSaveDeckConfirm = async () => {
    if (!newDeckName.trim()) {
      alert("Por favor, digite um nome para o deck.")
      return
    }
    const { data: { user } } = await supabase.auth.getUser()
    if (!user) return
    
    const total = deckCards.reduce((sum, c) => sum + c.quantity, 0)
    const legendary = deckCards.reduce((sum, c) => c.card.raridade === "legendary" ? sum + c.quantity : sum, 0)
    if (total < 40 || total > 80) {
      alert("O deck deve conter entre 40 e 80 cartas.")
      return
    }
    if (legendary > 5) {
      alert("O deck só pode conter no máximo 5 cartas lendárias.")
      return
    }
    
    try {
      let deckId = activeDeck?.id;
      if (!deckId) {
        const { data, error } = await supabase.from('decks').insert({ user_id: user.id, name: newDeckName, total_cards: total, is_valid: true }).select().single()
        if (error) throw error
        deckId = data.id
      } else {
        const { error } = await supabase.from('decks').update({ name: newDeckName, total_cards: total, is_valid: true }).eq('id', deckId)
        if (error) throw error
      }

      await supabase.from('deck_cards').delete().eq('deck_id', deckId)
      
      if (deckCards.length > 0) {
        const inserts = deckCards.map(dc => ({ deck_id: deckId, card_id: dc.card_id, quantity: dc.quantity }))
        const { error: cErr } = await supabase.from('deck_cards').insert(inserts)
        if (cErr) throw cErr
      }
      
      alert("Deck montado e salvo com sucesso!")
      setShowSaveModal(false)
      setActiveDeck({ id: deckId as string, name: newDeckName, is_valid: true, updated_at: new Date().toISOString(), is_active: false, deck_cards: deckCards })
      void loadDecks()
    } catch (err: any) {
      console.error(err)
      alert("Erro ao salvar deck: " + err.message)
    }
  }

  const editDeck = (deck: Deck) => {
    setActiveDeck(deck)
    setDeckName(deck.name)
    setDeckCards(deck.deck_cards)
  }

  const deleteDeck = async (deckId: string) => {
    if (!confirm("Tem certeza que deseja deletar este deck?")) return
    try {
      const { error: dcError } = await supabase.from('deck_cards').delete().eq('deck_id', deckId)
      if (dcError) throw dcError
      const { error: dError } = await supabase.from('decks').delete().eq('id', deckId)
      if (dError) throw dError
      
      alert("Deck deletado com sucesso!")
      if (activeDeck?.id === deckId) {
        setActiveDeck(null)
        setDeckCards([])
        setDeckName("Novo Deck")
      }
      void loadDecks()
    } catch (err: any) {
      alert("Erro ao deletar deck: " + err.message)
    }
  }

  const manaCurve = [0,1,2,3,4,5].map(cost => {
    if (cost === 5) return deckCards.filter(c => c.card.mana >= 5).reduce((s, c) => s + c.quantity, 0)
    return deckCards.filter(c => c.card.mana === cost).reduce((s, c) => s + c.quantity, 0)
  })
  const maxMana = Math.max(...manaCurve, 1)

  return (
    <main className="min-h-screen bg-[url('/yang-69TcSUVhbmY-unsplash.jpg')] bg-cover bg-fixed bg-center p-6 pt-20 text-stone-100">
      <div className="absolute inset-0 bg-black/85 backdrop-blur-[4px]" />
      <div className="relative mx-auto grid max-w-[1800px] grid-cols-1 gap-6 lg:grid-cols-12">
        
        {/* Painel Esquerdo (Lixeira / Reciclagem Mística) - lg:col-span-3 */}
        <section className="lg:col-span-3">
          <div className="rounded-xl border border-amber-600/30 bg-zinc-950/85 p-5 shadow-2xl">
            <div className="flex items-center gap-2 border-b border-amber-500/20 pb-3 mb-4">
              <Trash2 className="text-red-400" size={20} />
              <h2 className="font-serif text-lg font-black text-amber-200 uppercase tracking-widest">Reciclagem Mística</h2>
            </div>
            
            <p className="text-xs text-stone-400 mb-4 leading-relaxed">
              Arraste cartas ou clique em <Trash2 className="inline text-red-500 mx-0.5" size={12} /> para converter suas cartas extras em moedas de Ofier.
            </p>
            
            {/* Tabela de Valores */}
            <div className="bg-black/40 border border-amber-900/20 rounded-lg p-3 text-xs mb-5 space-y-1 font-serif text-stone-300">
              <div className="flex justify-between">
                <span>🟢 Comum</span>
                <span className="text-emerald-400 font-mono font-bold">+10 moedas</span>
              </div>
              <div className="flex justify-between">
                <span>🔵 Rara</span>
                <span className="text-blue-400 font-mono font-bold">+25 moedas</span>
              </div>
              <div className="flex justify-between">
                <span>🟣 Épica</span>
                <span className="text-purple-400 font-mono font-bold">+100 moedas</span>
              </div>
              <div className="flex justify-between">
                <span>🟡 Lendária</span>
                <span className="text-amber-400 font-mono font-bold">+250 moedas</span>
              </div>
            </div>

            {/* Lista da Lixeira */}
            <h4 className="text-[10px] font-serif font-bold text-amber-500 uppercase tracking-widest mb-2">Cartas na Lixeira ({totalTrashCount})</h4>
            <div className="max-h-[220px] overflow-y-auto space-y-1.5 mb-5 pr-1.5 border border-zinc-900 rounded p-2 bg-black/20">
              {Object.keys(trash).length === 0 ? (
                <p className="text-xs text-zinc-600 text-center py-6">Lixeira vazia.</p>
              ) : (
                Object.entries(trash).map(([cardId, qty]) => {
                  const card = inventory.find(c => c.id === cardId)
                  if (!card) return null
                  return (
                    <div key={cardId} className="flex justify-between items-center bg-stone-900/60 border border-zinc-800 p-2 rounded text-xs transition-colors hover:border-red-950">
                      <div className="flex flex-col">
                        <span className="font-bold text-stone-200 truncate max-w-[130px]">{card.nome}</span>
                        <span className="text-[9px] text-zinc-500 uppercase font-serif">{card.raridade}</span>
                      </div>
                      <div className="flex items-center gap-2">
                        <span className="font-bold font-mono text-amber-200">x{qty}</span>
                        <button onClick={() => removeFromTrash(cardId)} className="p-1 rounded bg-red-950/40 text-red-400 hover:bg-red-900 hover:text-red-200 transition-colors">
                          <Minus size={12} />
                        </button>
                      </div>
                    </div>
                  )
                })
              )}
            </div>

            {/* Ganhos e Confirmar */}
            <div className="border-t border-amber-900/20 pt-4">
              <div className="flex justify-between items-center mb-3">
                <span className="text-xs font-serif text-stone-400">Ganhos Estimados:</span>
                <span className="text-sm font-mono font-bold text-emerald-400">+{calculateRecycleValue()} moedas</span>
              </div>
              <button
                disabled={totalTrashCount === 0}
                onClick={() => setShowRecycleModal(true)}
                className={`w-full py-2.5 rounded font-serif font-black text-xs uppercase tracking-widest transition-all duration-300 border ${
                  totalTrashCount === 0 
                    ? 'border-stone-850 bg-stone-900/30 text-stone-600 cursor-not-allowed opacity-50' 
                    : 'border-red-500 bg-red-950/80 hover:bg-red-900 text-red-200 hover:text-white shadow-[0_0_10px_rgba(220,38,38,0.2)]'
                }`}
              >
                Reciclar Cartas
              </button>
            </div>
          </div>
        </section>

        {/* Painel Central - Acervo Pessoal (lg:col-span-6) */}
        <section className="lg:col-span-6">
          <header className="mb-6 rounded-xl border border-amber-600/30 bg-zinc-950/85 p-5 shadow-xl">
            <h1 className="font-serif text-3xl font-black text-amber-400">Minhas Cartas</h1>
            <p className="mb-4 text-sm text-zinc-400">Monte decks com as cartas que você tem disponível</p>
            <div className="flex flex-wrap items-center gap-3">
              <div className="relative flex-1 min-w-[180px]">
                <Search className="absolute left-3 top-1/2 -translate-y-1/2 text-zinc-500" size={16} />
                <input value={search} onChange={e => setSearch(e.target.value)} placeholder="Pesquisar por nome..." className="w-full rounded border border-amber-800/40 bg-black py-2 pl-9 pr-3 text-sm text-zinc-200 outline-none focus:border-amber-500" />
              </div>
              <div className="relative flex-1 min-w-[180px]">
                <Search className="absolute left-3 top-1/2 -translate-y-1/2 text-zinc-500" size={16} />
                <input value={effectFilter} onChange={e => setEffectFilter(e.target.value)} placeholder="Filtrar por efeito..." className="w-full rounded border border-amber-800/40 bg-black py-2 pl-9 pr-3 text-sm text-zinc-200 outline-none focus:border-amber-500" />
              </div>
              <div className="relative min-w-[150px]">
                <select 
                  value={sortBy} 
                  onChange={e => setSortBy(e.target.value as any)} 
                  className="w-full rounded border border-amber-800/40 bg-black py-2 px-3 text-sm text-zinc-200 outline-none focus:border-amber-500 cursor-pointer"
                >
                  <option value="name">Ordenar: Nome (A-Z)</option>
                  <option value="recent">Ordenar: Mais Recentes</option>
                </select>
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
            <div className="grid grid-cols-3 gap-2 sm:grid-cols-4 md:grid-cols-5 xl:grid-cols-7">
              {sorted.map(card => {
                const countInDeck = deckCards.find(dc => dc.card_id === card.id)?.quantity || 0
                const inTrash = trash[card.id] || 0
                const available = card.quantity - inTrash
                return (
                  <div key={card.id} className="group relative cursor-pointer" onClick={() => setInspectedCard(card)}>
                    <img src={secureImageUrl(card.image_url)} alt={card.nome} className={`aspect-[2/3] w-full rounded-md object-cover shadow-md border transition-all group-hover:scale-105 group-hover:border-amber-500 group-hover:shadow-amber-500/20 ${available === 0 ? 'border-red-950 opacity-40' : 'border-stone-800'}`} />
                    
                    {/* Badge Quantity Top-Right */}
                    <div className="absolute -right-1.5 -top-1.5 z-10 flex h-5.5 px-1.5 items-center justify-center rounded-full border-2 border-amber-500 bg-zinc-950 text-[10px] font-black text-amber-400 shadow-lg">
                      x{card.quantity}
                    </div>

                    {/* Compare Button Top-Left */}
                    <button 
                      onClick={(e) => { e.stopPropagation(); void handleCompare(card); }} 
                      className="absolute top-2 left-2 z-20 flex h-6 w-6 items-center justify-center rounded-full border border-blue-500 bg-blue-950/90 text-blue-200 hover:bg-blue-800 hover:text-white transition-all shadow-md opacity-0 group-hover:opacity-100"
                      title="Comparar Duelistas"
                    >
                      <Search size={10} />
                    </button>

                    {/* Add button direct overlay (Bottom-Right) */}
                    <button 
                      onClick={(e) => { e.stopPropagation(); addCard(card); }} 
                      className="absolute bottom-2 right-2 z-20 flex h-7 w-7 items-center justify-center rounded-full border border-emerald-500 bg-emerald-950/90 text-emerald-200 hover:bg-emerald-800 hover:text-white transition-all shadow-md"
                      title="Adicionar ao Deck"
                    >
                      <Plus size={12} />
                    </button>

                    {/* Trash button direct overlay (Bottom-Left) */}
                    <button 
                      onClick={(e) => { e.stopPropagation(); addToTrash(card); }} 
                      className="absolute bottom-2 left-2 z-20 flex h-7 w-7 items-center justify-center rounded-full border border-red-500 bg-red-950/90 text-red-200 hover:bg-red-800 hover:text-white transition-all shadow-md opacity-0 group-hover:opacity-100"
                      title="Mandar para Lixeira"
                    >
                      <Trash2 size={12} />
                    </button>

                    {countInDeck > 0 && (
                      <div className="absolute left-2 top-10 z-10 flex h-5 px-1.5 items-center justify-center rounded border border-amber-500 bg-amber-950/90 text-[10px] font-bold text-amber-300 shadow-md">
                        {countInDeck} deck
                      </div>
                    )}

                    {inTrash > 0 && (
                      <div className="absolute left-2 top-16 z-10 flex h-5 px-1.5 items-center justify-center rounded border border-red-500 bg-red-950/90 text-[10px] font-bold text-red-300 shadow-md">
                        {inTrash} lixo
                      </div>
                    )}
                  </div>
                )
              })}
            </div>
          )}
        </section>

        {/* Painel Direito - Mesa de Edição e Decks Montados (lg:col-span-3) */}
        <aside className="lg:col-span-3 space-y-6">
          <div className="sticky top-24 rounded-xl border border-amber-500/20 bg-zinc-950/90 p-5 shadow-2xl">
            <div className="flex items-center justify-between gap-2 border-b border-amber-500/10 pb-2 mb-3">
              <input value={deckName} onChange={e => setDeckName(e.target.value)} className="w-full bg-transparent font-serif text-xl font-black text-amber-400 outline-none" />
              <button 
                onClick={() => { setDeckCards([]); setDeckName("Novo Deck"); setActiveDeck(null); }} 
                className="text-stone-500 hover:text-red-400 text-xs font-serif transition-colors"
                title="Limpar Deck"
              >
                Limpar
              </button>
            </div>
            
            <div className="flex flex-col gap-1">
              <p className="text-sm text-zinc-400">Cartas no deck: <span className={`font-bold ${(totalCards < 40 || totalCards > 80) ? 'text-red-400' : 'text-amber-400'}`}>{totalCards} (min 40, max 80)</span></p>
              <p className="text-xs text-zinc-500">Cartas lendárias: <span className={`font-bold ${legendaryCardsCount > 5 ? 'text-red-400' : 'text-zinc-450'}`}>{legendaryCardsCount}/5</span></p>
            </div>

            <div className="mt-4 flex h-16 items-end gap-1 rounded bg-black/40 p-2">
              {manaCurve.map((count, i) => (
                <div key={i} className="group relative flex flex-1 flex-col items-center justify-end">
                  <div className="w-full rounded-t bg-amber-600/80 transition-all hover:bg-amber-400" style={{ height: `${(count / maxMana) * 100}%`, minHeight: count > 0 ? '4px' : '0' }} />
                  <span className="mt-1 text-[10px] font-bold text-zinc-500">{i === 5 ? '5+' : i}</span>
                </div>
              ))}
            </div>

            <div className="mt-4 flex max-h-[250px] flex-col gap-1 overflow-y-auto pr-2">
              {deckCards.map(dc => (
                <div 
                  key={dc.card_id} 
                  className="flex items-center justify-between rounded border border-zinc-800 bg-black/60 p-2 hover:border-amber-900/50 cursor-pointer transition-colors"
                  onClick={() => setInspectedCard(dc.card)}
                >
                  <div className="flex items-center gap-3">
                    <span className="flex h-6 w-6 items-center justify-center rounded border border-amber-500/30 bg-amber-950 text-xs font-black text-amber-200">{dc.quantity}</span>
                    <span className="truncate text-sm font-bold text-zinc-200 max-w-[130px]">{dc.card.nome}</span>
                  </div>
                  <div className="flex items-center gap-2" onClick={e => e.stopPropagation()}>
                    <span className="font-mono text-xs text-blue-300">{dc.card.mana}M</span>
                    <button onClick={() => removeCard(dc.card_id)} className="rounded bg-red-950 p-1 text-red-400 hover:bg-red-900 hover:text-red-200"><Minus size={14} /></button>
                  </div>
                </div>
              ))}
              {deckCards.length === 0 && <p className="py-10 text-center text-sm text-zinc-650">Adicione cartas do acervo para construir seu deck.</p>}
            </div>

            {/* Montar Deck Button */}
            <div className="mt-5 pt-3 border-t border-amber-500/10">
              <button 
                disabled={totalCards < 40 || totalCards > 80 || legendaryCardsCount > 5} 
                onClick={() => { setNewDeckName(deckName); setShowSaveModal(true); }}
                className={`w-full flex items-center justify-center gap-2 rounded-lg border py-3 font-serif font-black text-xs tracking-widest uppercase transition-all duration-300 ${
                  (totalCards < 40 || totalCards > 80 || legendaryCardsCount > 5) 
                    ? 'border-stone-850 bg-stone-900/30 text-stone-600 cursor-not-allowed opacity-50' 
                    : 'border-amber-500 bg-gradient-to-b from-amber-700 to-amber-900 text-amber-100 hover:shadow-[0_0_15px_rgba(245,158,11,0.3)] shadow-[0_4px_12px_rgba(0,0,0,0.5)]'
                }`}
              >
                {totalCards < 40 
                  ? `Faltam ${40 - totalCards} cartas` 
                  : totalCards > 80 
                  ? `Excesso de ${totalCards - 80} cartas` 
                  : legendaryCardsCount > 5 
                  ? `Limite lendárias excedido (${legendaryCardsCount}/5)` 
                  : "Montar Deck"}
              </button>
            </div>
          </div>

          {/* Seção Decks Montados */}
          <div className="rounded-xl border border-amber-600/20 bg-zinc-950/85 p-5 shadow-2xl">
            <div className="flex items-center gap-2 border-b border-amber-500/10 pb-2.5 mb-3">
              <Layers className="text-amber-400" size={18} />
              <h3 className="font-serif text-sm font-black text-amber-200 uppercase tracking-widest">Decks Salvos</h3>
            </div>
            
            <div className="space-y-2 max-h-[260px] overflow-y-auto pr-1">
              {myDecks.length === 0 ? (
                <p className="text-xs text-zinc-600 text-center py-6">Nenhum deck salvo ainda.</p>
              ) : (
                myDecks.map(deck => (
                  <div key={deck.id} className="border border-zinc-800 bg-black/40 rounded-lg p-2.5 flex justify-between items-center transition-colors hover:border-amber-950">
                    <div>
                      <h4 className="font-bold text-xs text-stone-200 truncate max-w-[120px]">{deck.name}</h4>
                      <p className="text-[10px] text-zinc-500">{deck.deck_cards.reduce((sum, c) => sum + c.quantity, 0)} cartas</p>
                    </div>
                    <div className="flex gap-1.5">
                      <button onClick={() => editDeck(deck)} className="px-2 py-1 bg-amber-950/40 hover:bg-amber-900/80 text-amber-300 border border-amber-700/30 text-[9px] font-black uppercase rounded transition-colors">
                        Editar
                      </button>
                      <button onClick={() => deleteDeck(deck.id)} className="px-2 py-1 bg-red-950/40 hover:bg-red-900/80 text-red-300 border border-red-700/30 text-[9px] font-black uppercase rounded transition-colors">
                        Deletar
                      </button>
                    </div>
                  </div>
                ))
              )}
            </div>
          </div>
        </aside>
      </div>

      {/* Modal Zoom/Inspeção Split-panel */}
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

      {/* Modal Salvar Deck */}
      {showSaveModal && (
        <div className="fixed inset-0 z-[400] flex items-center justify-center bg-black/80 backdrop-blur-sm" onClick={() => setShowSaveModal(false)}>
          <div className="w-[450px] max-w-[90vw] rounded-xl border border-amber-500/50 bg-stone-900 p-6 shadow-2xl text-stone-100" onClick={e => e.stopPropagation()}>
            <h2 className="mb-4 text-center font-serif text-xl font-black tracking-widest text-amber-500">SALVAR E MONTAR DECK</h2>
            <p className="mb-4 text-center text-xs text-stone-400 leading-relaxed">
              O seu deck contem {totalCards} cartas (sendo {legendaryCardsCount} lendárias) e atende aos requisitos de combate (40-80 cartas, max 5 lendárias). Digite um nome para salvar no seu Grimório.
            </p>
            <div className="mb-6">
              <label className="block text-[10px] font-serif text-amber-500 uppercase tracking-widest mb-1.5">Nome do Deck</label>
              <input 
                type="text"
                value={newDeckName}
                onChange={e => setNewDeckName(e.target.value)}
                placeholder="Ex: Ofensa zerrikana, Muralha Élfica..."
                className="w-full rounded border border-amber-800/40 bg-black py-2.5 px-3 text-sm text-zinc-200 outline-none focus:border-amber-500"
              />
            </div>
            <div className="flex gap-4">
              <button onClick={() => setShowSaveModal(false)} className="flex-1 rounded border border-stone-600 bg-stone-800 py-3 text-xs font-black uppercase text-stone-300">
                Cancelar
              </button>
              <button onClick={handleSaveDeckConfirm} className="flex-1 rounded border border-amber-500 bg-amber-700 py-3 text-xs font-black uppercase text-amber-100 shadow-[0_0_15px_rgba(217,119,6,0.3)]">
                Confirmar e Salvar
              </button>
            </div>
          </div>
        </div>
      )}

      {/* Modal de Confirmação de Reciclagem */}
      {showRecycleModal && (
        <div className="fixed inset-0 z-[400] flex items-center justify-center bg-black/80 backdrop-blur-sm" onClick={() => setShowRecycleModal(false)}>
          <div className="w-[450px] max-w-[90vw] rounded-xl border border-red-500/50 bg-stone-900 p-6 shadow-2xl text-stone-100" onClick={e => e.stopPropagation()}>
            <h2 className="mb-4 text-center font-serif text-xl font-black tracking-widest text-red-500 uppercase">Confirmar Reciclagem</h2>
            <p className="mb-6 text-center text-sm leading-relaxed text-stone-300">
              Tem certeza que deseja reciclar <strong className="text-red-400 font-mono">{totalTrashCount}</strong> carta(s)? Você receberá <strong className="text-emerald-400 font-mono">+{calculateRecycleValue()}</strong> moedas e essa ação não pode ser desfeita!
            </p>
            <div className="flex gap-4">
              <button onClick={() => setShowRecycleModal(false)} className="flex-1 rounded border border-stone-600 bg-stone-800 py-3 text-xs font-black uppercase text-stone-300">
                Voltar
              </button>
              <button onClick={handleRecycleConfirm} className="flex-1 rounded border border-emerald-500 bg-emerald-800 hover:bg-emerald-700 py-3 text-xs font-black uppercase text-emerald-100 shadow-[0_0_15px_rgba(16,185,129,0.3)]">
                Reciclar Agora
              </button>
            </div>
          </div>
        </div>
      )}

      {/* Modal Comparar Duelistas */}
      {comparingCard && (
        <div className="fixed inset-0 z-[400] flex items-center justify-center bg-black/90 p-4 backdrop-blur-md" onClick={() => setComparingCard(null)}>
          <div className="relative w-[450px] max-w-[95vw] rounded-xl border border-amber-500/40 bg-stone-900 p-6 shadow-2xl text-stone-100" onClick={e => e.stopPropagation()}>
            <button onClick={() => setComparingCard(null)} className="absolute -right-3 -top-3 rounded-full border border-red-500 bg-red-950 p-2 text-red-200 shadow-lg hover:bg-red-900 transition-colors">
              <X size={14} />
            </button>
            <h3 className="font-serif text-xl font-black text-amber-200 mb-2">Quem possui "{comparingCard.nome}"?</h3>
            <p className="text-xs text-zinc-400 mb-4">Outros duelistas que possuem esta carta no inventário:</p>
            {loadingOwners ? (
              <p className="text-sm text-zinc-400 py-4 text-center">Buscando na biblioteca...</p>
            ) : cardOwners.length === 0 ? (
              <p className="text-sm text-zinc-400 py-4 text-center">Nenhum outro duelista possui esta carta ainda.</p>
            ) : (
              <div className="max-h-60 overflow-y-auto space-y-2 pr-2">
                {cardOwners.map((owner, idx) => (
                  <div key={idx} className="flex justify-between items-center bg-black/40 border border-zinc-800 rounded p-2 text-sm">
                    <span className="font-bold text-amber-100">{owner.username}</span>
                    <span className="text-xs text-zinc-400 font-mono">Quantidade: x{owner.quantity}</span>
                  </div>
                ))}
              </div>
            )}
          </div>
        </div>
      )}

    </main>
  )
}
