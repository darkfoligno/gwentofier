"use client"

import { createContext, useContext, useEffect, useState } from "react"
import { supabase } from "@/lib/supabase"

interface WalletState {
  coins: number
  lastClaimDate: string | null
  refresh: () => Promise<void>
}

const WalletContext = createContext<WalletState | undefined>(undefined)

export function WalletProvider({ children }: { children: React.ReactNode }) {
  const [coins, setCoins] = useState<number>(0)
  const [lastClaimDate, setLastClaimDate] = useState<string | null>(null)
  const [userId, setUserId] = useState<string | null>(null)

  const refresh = async () => {
    const { data: { user } } = await supabase.auth.getUser()
    if (!user) return
    setUserId(user.id)
    
    const { data } = await supabase
      .from("player_wallets")
      .select("coins, last_claim_date")
      .eq("user_id", user.id)
      .maybeSingle()
      
    if (data) {
      setCoins(data.coins ?? 0)
      setLastClaimDate(data.last_claim_date)
    }
  }

  useEffect(() => {
    void refresh()
  }, [])

  useEffect(() => {
    if (!userId) return

    const channel = supabase.channel("wallet_sync")
      .on("postgres_changes", { event: "*", schema: "public", table: "player_wallets", filter: `user_id=eq.${userId}` }, (payload) => {
        const newRow = payload.new as any
        if (newRow && newRow.coins !== undefined) {
          setCoins(newRow.coins)
          setLastClaimDate(newRow.last_claim_date)
        } else {
          void refresh()
        }
      })
      .subscribe()

    return () => { void supabase.removeChannel(channel) }
  }, [userId])

  return (
    <WalletContext.Provider value={{ coins, lastClaimDate, refresh }}>
      {children}
    </WalletContext.Provider>
  )
}

export function useWallet() {
  const context = useContext(WalletContext)
  if (context === undefined) {
    throw new Error("useWallet must be used within a WalletProvider")
  }
  return context
}
