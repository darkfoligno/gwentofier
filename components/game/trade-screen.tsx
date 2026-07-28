"use client"

import { useEffect, useState, useCallback } from "react"
import { motion, AnimatePresence } from "framer-motion"
import { ArrowRightLeft, Lock, Loader2, Coins, ArrowLeft, RefreshCw, X, ShieldAlert, CheckCircle2 } from "lucide-react"
import { supabase } from "@/lib/supabase"
import { GameCard } from "./game-card"
import type { GameCard as GameCardType, Rarity, OfficialCardType } from "@/lib/game-data"
import type { Screen } from "@/lib/types"

interface Profile {
  username: string
  avatar_url: string | null
}

interface TradeListing {
  id: string
  seller_user_id: string
  card_id: string
  created_at: string
  seller_ip: string
  profiles: Profile
  cards: any // raw DB card
}

interface UserCardWithDetails {
  card_id: string
  quantity: number
  cards: any
}

export function TradeScreen({ onEnter }: { onEnter: (screen: Screen) => void }) {
  const [profile, setProfile] = useState<any>(null)
  const [isEligible, setIsEligible] = useState<boolean | null>(null)
  const [eligibilityReason, setEligibilityReason] = useState<string>("")
  const [totalCardsCount, setTotalCardsCount] = useState<number>(0)
  const [loading, setLoading] = useState(true)
  const [busy, setBusy] = useState<string | null>(null)
  const [error, setError] = useState<string | null>(null)
  const [successMessage, setSuccessMessage] = useState<string | null>(null)

  // Data lists
  const [userCards, setUserCards] = useState<UserCardWithDetails[]>([])
  const [duplicates, setDuplicates] = useState<UserCardWithDetails[]>([])
  const [listings, setListings] = useState<TradeListing[]>([])
  const [myListings, setMyListings] = useState<TradeListing[]>([])

  // Selection state
  const [selectedDuplicateId, setSelectedDuplicateId] = useState<string | null>(null)
  const [activeTradeListing, setActiveTradeListing] = useState<TradeListing | null>(null)
  const [offeredCardId, setOfferedCardId] = useState<string | null>(null)

  const checkEligibilityAndLoad = useCallback(async () => {
    setLoading(true)
    setError(null)
    try {
      const { data: { user } } = await supabase.auth.getUser()
      if (!user) {
        onEnter("hub")
        return
      }

      // Check profile
      const { data: profData } = await supabase
        .from("profiles")
        .select("*")
        .eq("id", user.id)
        .single()
      setProfile(profData)

      // Run SQL Check
      const { data: eligibility, error: eligibilityError } = await supabase.rpc("check_trade_eligibility", {
        p_user_id: user.id
      })
      
      if (eligibilityError) throw eligibilityError

      const eligResult = eligibility && eligibility.length > 0 ? eligibility[0] : { is_eligible: false, reason: "Sem dados" }
      setIsEligible(eligResult.is_eligible)
      setEligibilityReason(eligResult.reason)

      // Get count
      const { data: countData } = await supabase
        .from("user_cards")
        .select("quantity")
        .eq("user_id", user.id)
      
      const total = (countData || []).reduce((sum, item) => sum + (item.quantity || 0), 0)
      setTotalCardsCount(total)

      if (eligResult.is_eligible) {
        // Load User Cards
        const { data: uCards } = await supabase
          .from("user_cards")
          .select("card_id, quantity, cards(*)")
          .eq("user_id", user.id)

        const items = uCards as unknown as UserCardWithDetails[] || []
        setUserCards(items)
        setDuplicates(items.filter(uc => uc.quantity > 1))

        // Load Active Listings from others
        const { data: otherListings } = await supabase
          .from("trade_listings")
          .select("id, seller_user_id, card_id, created_at, seller_ip, profiles:seller_user_id(username, avatar_url), cards:card_id(*)")
          .eq("status", "active")
          .neq("seller_user_id", user.id)
        
        setListings((otherListings as unknown as TradeListing[]) || [])

        // Load my active listings
        const { data: ownListings } = await supabase
          .from("trade_listings")
          .select("id, seller_user_id, card_id, created_at, seller_ip, profiles:seller_user_id(username, avatar_url), cards:card_id(*)")
          .eq("status", "active")
          .eq("seller_user_id", user.id)

        setMyListings((ownListings as unknown as TradeListing[]) || [])
      }
    } catch (err: any) {
      console.error(err)
      setError("Erro ao carregar dados do mercado: " + (err.message || err))
    } finally {
      setLoading(false)
    }
  }, [onEnter])

  useEffect(() => {
    void checkEligibilityAndLoad()
  }, [checkEligibilityAndLoad])

  const handleCreateListing = async () => {
    if (!selectedDuplicateId) return
    setBusy("create")
    setError(null)
    setSuccessMessage(null)
    try {
      const { data, error: rpcError } = await supabase.rpc("create_trade_listing", {
        p_card_id: selectedDuplicateId
      })
      if (rpcError) throw rpcError

      setSuccessMessage("Carta anunciada no Trade Marketing com sucesso!")
      setSelectedDuplicateId(null)
      await checkEligibilityAndLoad()
    } catch (err: any) {
      setError(err.message || "Erro ao anunciar carta")
    } finally {
      setBusy(null)
    }
  }

  const handleCancelListing = async (listingId: string) => {
    setBusy("cancel")
    setError(null)
    setSuccessMessage(null)
    try {
      const { error: rpcError } = await supabase.rpc("cancel_trade_listing", {
        p_trade_listing_id: listingId
      })
      if (rpcError) throw rpcError

      setSuccessMessage("Anúncio cancelado e carta devolvida ao inventário!")
      await checkEligibilityAndLoad()
    } catch (err: any) {
      setError(err.message || "Erro ao cancelar anúncio")
    } finally {
      setBusy(null)
    }
  }

  const handleExecuteTrade = async () => {
    if (!activeTradeListing || !offeredCardId) return
    setBusy("trade")
    setError(null)
    setSuccessMessage(null)
    try {
      const { error: rpcError } = await supabase.rpc("execute_card_trade", {
        p_trade_listing_id: activeTradeListing.id,
        p_buyer_offered_card_id: offeredCardId
      })
      if (rpcError) throw rpcError

      setSuccessMessage("Troca atômica efetuada com sucesso! Grimório atualizado.")
      setActiveTradeListing(null)
      setOfferedCardId(null)
      await checkEligibilityAndLoad()
    } catch (err: any) {
      setError(err.message || "Erro ao realizar troca")
    } finally {
      setBusy(null)
    }
  }

  const mapToGameCard = (rawCard: any): GameCardType => {
    return {
      id: rawCard.id,
      nome: rawCard.name,
      image_url: rawCard.image_url,
      elemento: (["Bestiário", "M&F", "Witcher", "Elfica", "Cívil", "Vampiro"].includes(rawCard.element) ? rawCard.element : "Bestiário") as GameCardType["elemento"],
      raridade: rawCard.rarity as Rarity,
      tipo: rawCard.element,
      mana: rawCard.effect_mana_cost,
      ataque: rawCard.base_power,
      vida: rawCard.base_max_life,
      efeito: rawCard.effect_text ?? "",
      effect_definition: [],
      is_original_rpg: rawCard.is_original_rpg,
      quantity: 1
    }
  }

  const hasCardInCollection = (cardId: string) => {
    return userCards.some(uc => uc.card_id === cardId && uc.quantity > 0)
  }

  if (loading) {
    return (
      <div className="flex min-h-screen flex-col items-center justify-center bg-stone-950 text-stone-100">
        <Loader2 className="animate-spin text-amber-500 mb-4" size={48} />
        <p className="font-serif text-lg text-amber-200">Carregando Mercado de Ofier...</p>
      </div>
    )
  }

  // Page blocked if not eligible
  if (isEligible === false) {
    return (
      <main className="relative min-h-screen w-full bg-[url('/yang-69TcSUVhbmY-unsplash.jpg')] bg-cover bg-fixed bg-center p-6 text-stone-100 flex items-center justify-center">
        <div className="absolute inset-0 bg-black/90 backdrop-blur-[4px]" />
        <div className="relative mx-auto max-w-xl text-center border border-amber-600/40 bg-zinc-950/80 p-8 rounded-2xl shadow-2xl">
          <div className="mx-auto flex h-16 w-16 items-center justify-center rounded-full border-2 border-red-500 bg-red-950/50 text-red-400 mb-6 animate-pulse">
            <Lock size={32} />
          </div>
          <h1 className="font-serif text-2xl font-black text-amber-200 uppercase tracking-widest mb-4">Mercado Trancado</h1>
          <p className="text-stone-300 leading-relaxed mb-6 text-sm">
            ⚖️ O Mercado de Ofier é exclusivo para duelistas experientes! Personalize seu avatar e acumule pelo menos 20 cartas em sua coleção para destrancar o comércio.
          </p>
          <div className="text-xs text-stone-400 border-t border-stone-800 pt-4 flex flex-col gap-2">
            <div>Seu Avatar: <span className={profile?.avatar_url ? "text-emerald-400 font-bold" : "text-red-400 font-bold"}>{profile?.avatar_url ? "Personalizado" : "Padrão (Falta alterar)"}</span></div>
            <div>Sua coleção: <span className={totalCardsCount >= 20 ? "text-emerald-400 font-bold" : "text-red-400 font-bold"}>{totalCardsCount} / 20 cartas</span></div>
          </div>
          <button 
            onClick={() => onEnter("hub")} 
            className="mt-6 flex items-center gap-2 mx-auto rounded-lg border border-amber-500 bg-amber-950/60 px-5 py-2.5 text-xs font-black text-amber-200 uppercase tracking-wider hover:bg-amber-900 transition-all"
          >
            <ArrowLeft size={16} /> Voltar ao Hub
          </button>
        </div>
      </main>
    )
  }

  return (
    <main className="relative min-h-screen w-full overflow-x-hidden overflow-y-auto pb-24 bg-[url('/yang-69TcSUVhbmY-unsplash.jpg')] bg-cover bg-fixed bg-center p-6 text-stone-100">
      <div className="absolute inset-0 bg-black/80 backdrop-blur-[2px]" />
      <div className="relative mx-auto max-w-7xl">
        <header className="mb-6 flex items-center justify-between rounded-xl border border-amber-600/40 bg-zinc-950/75 p-5">
          <div className="flex items-center gap-4">
            <button 
              onClick={() => onEnter("hub")} 
              className="rounded-lg border border-stone-800 bg-black/50 p-2 text-stone-400 hover:text-amber-200 transition-colors"
            >
              <ArrowLeft size={20} />
            </button>
            <div>
              <h1 className="font-serif text-3xl font-black text-amber-200 flex items-center gap-2">
                <ArrowRightLeft className="text-amber-400" size={28} />
                Trade Marketing
              </h1>
              <p className="text-xs text-zinc-400 mt-1">Troque suas cartas repetidas diretamente com outros duelistas.</p>
            </div>
          </div>
          <button 
            onClick={() => void checkEligibilityAndLoad()} 
            className="flex items-center gap-2 rounded-lg border border-stone-800 bg-black/50 px-4 py-2 text-xs font-bold text-stone-300 hover:text-white transition-colors"
          >
            <RefreshCw size={14} className={busy ? "animate-spin" : ""} />
            Atualizar
          </button>
        </header>

        {error && (
          <div className="mb-5 rounded-lg border border-red-500 bg-red-950/80 p-4 text-sm font-bold text-red-200 flex items-center gap-3">
            <ShieldAlert size={20} className="shrink-0" />
            <div>{error}</div>
          </div>
        )}

        {successMessage && (
          <div className="mb-5 rounded-lg border border-emerald-500 bg-emerald-950/80 p-4 text-sm font-bold text-emerald-200 flex items-center gap-3">
            <CheckCircle2 size={20} className="shrink-0" />
            <div>{successMessage}</div>
          </div>
        )}

        {/* SECTION 1: MY DUPLICATES CAROUSEL */}
        <section className="mb-8 rounded-xl border border-amber-800/35 bg-black/60 p-5">
          <h2 className="font-serif text-lg font-black text-amber-200 uppercase tracking-widest mb-3">Minhas Repetidas</h2>
          <p className="text-xs text-stone-400 mb-4">Selecione uma carta que você possui em excesso para colocá-la à venda no mercado global.</p>
          
          {duplicates.length > 0 ? (
            <div>
              <div className="flex gap-4 overflow-x-auto pb-4 pt-1 px-1 snap-x">
                {duplicates.map(uc => {
                  const card = mapToGameCard(uc.cards)
                  const isSelected = selectedDuplicateId === card.id
                  return (
                    <div 
                      key={uc.card_id}
                      onClick={() => setSelectedDuplicateId(isSelected ? null : card.id)}
                      className={`relative w-36 shrink-0 snap-start cursor-pointer rounded-xl border p-2 pt-8 transition-all hover:-translate-y-1 ${
                        isSelected 
                          ? "border-amber-400 bg-amber-950/20 ring-2 ring-amber-400" 
                          : "border-stone-800 bg-stone-950/50 hover:border-stone-700"
                      }`}
                    >
                      <span className="absolute left-2 top-2 z-10 flex items-center justify-center">
                        <input 
                          type="checkbox" 
                          checked={isSelected}
                          onChange={() => {}} // handled by click container
                          className="h-4.5 w-4.5 rounded border-stone-600 bg-stone-900 text-amber-500 focus:ring-amber-500" 
                        />
                      </span>
                      <span className="absolute right-2 top-2 z-10 rounded bg-amber-950/80 border border-amber-500/50 px-1.5 py-0.5 text-[9px] font-black text-amber-300">
                        {uc.quantity} unidades
                      </span>
                      <div className="aspect-[2/3]">
                        <GameCard card={card} enableZoom={true} />
                      </div>
                      <div className="mt-2 text-center text-[10px] font-bold text-stone-300 truncate">{card.nome}</div>
                    </div>
                  )
                })}
              </div>

              <div className="mt-4 flex justify-end">
                <button
                  disabled={!selectedDuplicateId || busy !== null}
                  onClick={() => void handleCreateListing()}
                  className="rounded border-2 border-amber-400 bg-gradient-to-b from-amber-700 to-amber-950 px-6 py-2.5 font-serif text-xs font-black uppercase text-amber-100 shadow-[0_0_15px_rgba(245,158,11,0.25)] transition-all hover:scale-105 disabled:opacity-40 disabled:scale-100"
                >
                  {busy === "create" ? "Anunciando..." : "Colocar no Trade Marketing"}
                </button>
              </div>
            </div>
          ) : (
            <div className="flex h-32 items-center justify-center border border-dashed border-stone-800 rounded-lg text-sm text-stone-500 font-serif">
              Você não possui nenhuma carta repetida no momento.
            </div>
          )}
        </section>

        <div className="w-full">
          {/* COMBINED SECTION: MERCADO GERAL */}
          <section className="rounded-xl border border-amber-800/35 bg-black/60 p-5">
            <h2 className="font-serif text-lg font-black text-amber-200 uppercase tracking-widest mb-4">Mercado Geral</h2>
            
            {(() => {
              const allListings = [
                ...myListings.map(l => ({ ...l, isMine: true })),
                ...listings.map(l => ({ ...l, isMine: false }))
              ].sort((a, b) => new Date(b.created_at).getTime() - new Date(a.created_at).getTime());

              return allListings.length > 0 ? (
                <div className="grid grid-cols-2 gap-4 sm:grid-cols-3 md:grid-cols-4 lg:grid-cols-5 xl:grid-cols-6">
                  {allListings.map(item => {
                    const card = mapToGameCard(item.cards)
                    const ownIt = item.isMine || hasCardInCollection(card.id)
                    return (
                      <article 
                        key={item.id}
                        className="rounded-xl border border-stone-800 bg-stone-950/60 p-3 flex flex-col justify-between"
                      >
                        <div>
                          <div className="mb-2 flex items-center justify-between">
                            {item.isMine ? (
                              <span className="rounded bg-amber-950/80 border border-amber-500/40 px-2 py-0.5 text-[9px] font-bold text-amber-300">
                                Você anunciou
                              </span>
                            ) : ownIt ? (
                              <span className="rounded bg-emerald-950/80 border border-emerald-500/40 px-2 py-0.5 text-[9px] font-bold text-emerald-400">
                                🟢 Você já possui
                              </span>
                            ) : (
                              <span className="rounded bg-blue-950/80 border border-blue-500/40 px-2 py-0.5 text-[9px] font-bold text-blue-400">
                                🟡 Nova!
                              </span>
                            )}
                          </div>
                          <div className="aspect-[2/3] w-full mb-3">
                            <GameCard card={card} interactive enableZoom={true} />
                          </div>
                          <div className="text-xs font-bold text-stone-200 truncate">{card.nome}</div>
                          <div className="text-[10px] text-stone-400 mt-1 flex flex-col gap-1 border-t border-stone-800/60 pt-2">
                            <div>
                              <span className="text-amber-500/80 font-bold">Anunciado por:</span>{' '}
                              <span className="truncate max-w-[120px] text-stone-300 font-medium">
                                {item.isMine ? (profile?.username ? `${profile.username} (Você)` : "Você") : (item.profiles?.username || "Duelista")}
                              </span>
                            </div>
                          </div>
                        </div>

                        {item.isMine ? (
                          <button
                            disabled={busy !== null}
                            onClick={() => void handleCancelListing(item.id)}
                            className="mt-3 w-full rounded border border-red-500 bg-red-950/40 py-2 text-[10px] font-black uppercase text-red-200 tracking-wider hover:bg-red-900/60 transition-colors disabled:opacity-40"
                          >
                            {busy === "cancel" ? "Cancelando..." : "Cancelar Anúncio"}
                          </button>
                        ) : (
                          <button
                            onClick={() => setActiveTradeListing(item)}
                            className="mt-3 w-full rounded border border-amber-500 bg-amber-950/40 py-2 text-[10px] font-black uppercase text-amber-200 tracking-wider hover:bg-amber-900/60 transition-colors"
                          >
                            Fazer Troca
                          </button>
                        )}
                      </article>
                    )
                  })}
                </div>
              ) : (
                <div className="flex h-64 items-center justify-center border border-dashed border-stone-800 rounded-lg text-sm text-stone-500 font-serif">
                  Nenhum anúncio ativo no mercado de trocas no momento.
                </div>
              );
            })()}
          </section>
        </div>
      </div>

      {/* SWAP MODAL */}
      <AnimatePresence>
        {activeTradeListing && (
          <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/80 backdrop-blur-sm p-4">
            <div className="relative w-full max-w-xl rounded-2xl border-2 border-amber-600/40 bg-zinc-950 p-6 shadow-2xl flex flex-col max-h-[85vh]">
              <button 
                onClick={() => { setActiveTradeListing(null); setOfferedCardId(null) }} 
                className="absolute right-4 top-4 rounded bg-stone-800 p-1 text-stone-400 hover:text-white"
              >
                <X size={20} />
              </button>

              <h3 className="font-serif text-xl font-black text-amber-200 mb-1 flex items-center gap-2">
                <ArrowRightLeft size={20} className="text-amber-400" />
                Oferecer Carta em Troca
              </h3>
              <p className="text-xs text-stone-400 mb-4 border-b border-stone-800/80 pb-3">
                Escolha uma carta da sua coleção que tenha a **EXATA MESMA RARIDADE** ({mapToGameCard(activeTradeListing.cards).raridade}) e possua quantidade &gt; 1.
              </p>

              {/* LISTING CARD PREVIEW */}
              <div className="mb-4 flex items-center gap-4 bg-stone-900/60 p-3 rounded-lg border border-stone-800">
                <div className="aspect-[2/3] w-14 shrink-0">
                  <GameCard card={mapToGameCard(activeTradeListing.cards)} enableZoom={false} />
                </div>
                <div>
                  <div className="text-[10px] text-amber-500/80 font-bold uppercase tracking-wider">Você receberá:</div>
                  <div className="text-sm font-black text-amber-100">{mapToGameCard(activeTradeListing.cards).nome}</div>
                  <div className="text-xs text-stone-400 capitalize mt-0.5">Raridade: {mapToGameCard(activeTradeListing.cards).raridade}</div>
                </div>
              </div>

              {/* BUYER REPETIDAS OF SAME RARITY */}
              <div className="flex-1 overflow-y-auto mb-4 min-h-0">
                <div className="text-xs font-bold text-stone-300 mb-2">Suas repetidas disponíveis da raridade {mapToGameCard(activeTradeListing.cards).raridade}:</div>
                
                {duplicates.filter(uc => uc.cards.rarity === activeTradeListing.cards.rarity).length > 0 ? (
                  <div className="grid grid-cols-3 gap-3">
                    {duplicates
                      .filter(uc => uc.cards.rarity === activeTradeListing.cards.rarity)
                      .map(uc => {
                        const card = mapToGameCard(uc.cards)
                        const isSelected = offeredCardId === card.id
                        return (
                          <div
                            key={uc.card_id}
                            onClick={() => setOfferedCardId(isSelected ? null : card.id)}
                            className={`relative cursor-pointer rounded-lg border p-2 text-center transition-all ${
                              isSelected 
                                ? "border-amber-400 bg-amber-950/20 ring-2 ring-amber-400" 
                                : "border-stone-800 bg-stone-900/40 hover:border-stone-700"
                            }`}
                          >
                            <span className="absolute right-2 top-2 z-10 rounded bg-amber-950/80 px-1 py-0.5 text-[8px] font-black text-amber-300">
                              +{uc.quantity - 1}
                            </span>
                            <div className="aspect-[2/3] w-full mb-1">
                              <GameCard card={card} enableZoom={false} />
                            </div>
                            <div className="text-[9px] font-bold text-stone-300 truncate">{card.nome}</div>
                          </div>
                        )
                      })}
                  </div>
                ) : (
                  <div className="py-12 text-center text-stone-500 text-xs border border-dashed border-stone-800 rounded-lg font-serif">
                    Você não possui cartas repetidas de raridade {mapToGameCard(activeTradeListing.cards).raridade} para oferecer.
                  </div>
                )}
              </div>

              {/* ACTION */}
              <button
                disabled={!offeredCardId || busy !== null}
                onClick={() => void handleExecuteTrade()}
                className="w-full rounded-lg border-2 border-amber-400 bg-gradient-to-b from-amber-700 to-amber-950 py-3 font-serif text-sm font-black uppercase text-amber-100 shadow-[0_0_20px_rgba(245,158,11,0.3)] transition-all hover:scale-[1.02] disabled:opacity-40 disabled:scale-100"
              >
                {busy === "trade" ? "Processando Troca Atômica..." : "Confirmar Troca Atômica"}
              </button>
            </div>
          </div>
        )}
      </AnimatePresence>
    </main>
  )
}
