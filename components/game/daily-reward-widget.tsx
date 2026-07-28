"use client"

import { useEffect, useState, useCallback } from "react"
import { Gift, Sparkles, Scroll, Hourglass } from "lucide-react"
import { supabase } from "@/lib/supabase"
import { useWallet } from "@/components/wallet-provider"
import { motion } from "framer-motion"

export function DailyRewardWidget({ onClaimSuccess }: { onClaimSuccess?: (data: any) => void }) {
  const { lastClaimDate, refresh: refreshWallet } = useWallet()
  const [busy, setBusy] = useState<boolean>(false)
  const [error, setError] = useState<string | null>(null)
  const [lastClaimInfo, setLastClaimInfo] = useState<{ claimed_at: string; missed_days_before: number } | null>(null)

  const refreshInfo = useCallback(async () => {
    const { data: { user } } = await supabase.auth.getUser()
    if (!user) return
    
    await refreshWallet()

    const { data: claimData } = await supabase
      .from("daily_claims")
      .select("claimed_at, missed_days_before")
      .eq("user_id", user.id)
      .order("claimed_at", { ascending: false })
      .limit(1)
      .maybeSingle()

    if (claimData) {
      setLastClaimInfo({
        claimed_at: claimData.claimed_at,
        missed_days_before: claimData.missed_days_before
      })
    }
  }, [refreshWallet])

  useEffect(() => {
    void refreshInfo()
  }, [refreshInfo])

  const canClaimDaily = () => {
    if (!lastClaimDate) return true
    const last = new Date(lastClaimDate)
    const now = new Date()
    return last.getFullYear() !== now.getFullYear() || last.getMonth() !== now.getMonth() || last.getDate() !== now.getDate()
  }

  const isDailyAvailable = canClaimDaily()

  const daily = async () => {
    setBusy(true)
    setError(null)
    try {
      const user = (await supabase.auth.getUser()).data.user
      if (!user) return
      
      const { data, error: rpcError } = await supabase.rpc("claim_daily_login_reward", { p_user_id: user.id })
      if (rpcError) {
        setError(rpcError.message)
        return
      }
      
      if (data && !data.success) {
        setError(data.error || "Já resgatado hoje")
        return
      }

      await refreshInfo()
      if (onClaimSuccess) {
        onClaimSuccess(data)
      }
    } catch (err: any) {
      setError(err.message || "Erro ao resgatar recompensa")
    } finally {
      setBusy(false)
    }
  }

  const formatClaimDate = (dateStr: string) => {
    try {
      const d = new Date(dateStr)
      const pad = (n: number) => String(n).padStart(2, "0")
      const day = pad(d.getDate())
      const month = pad(d.getMonth() + 1)
      const year = d.getFullYear()
      const hours = pad(d.getHours())
      const minutes = pad(d.getMinutes())
      return `${day}/${month}/${year} às ${hours}:${minutes}`
    } catch {
      return dateStr
    }
  }

  return (
    <div className="w-full">
      {error && (
        <motion.div 
          initial={{ y: -10, opacity: 0 }} 
          animate={{ y: 0, opacity: 1 }} 
          className="mb-4 rounded-lg border border-red-500 bg-red-950/80 p-3 text-center text-sm font-bold text-red-200"
        >
          {error}
        </motion.div>
      )}
      <button 
        onClick={() => void daily()} 
        disabled={busy || !isDailyAvailable} 
        className="flex w-full items-center justify-between rounded-xl border border-amber-400 bg-gradient-to-r from-amber-950 via-stone-950 to-amber-950 p-5 text-left shadow-[0_0_30px_rgba(245,158,11,.22)] disabled:opacity-50 disabled:grayscale transition-all duration-300 hover:border-amber-300"
      >
        <span className="flex items-center gap-4">
          <Gift className="text-amber-300" size={35} />
          <span className="flex flex-col gap-1">
            <b className="block font-serif text-xl text-amber-100">Resgate Diário</b>
            <span className="text-sm text-stone-400">
              {isDailyAvailable 
                ? (lastClaimDate && (Math.floor((new Date().setHours(0,0,0,0) - new Date(lastClaimDate).setHours(0,0,0,0)) / 86400000) - 1) > 0 
                    ? `Reivindique sua recompensa gratuita! Você está há ${Math.floor((new Date().setHours(0,0,0,0) - new Date(lastClaimDate).setHours(0,0,0,0)) / 86400000) - 1} dia(s) sem resgatar seus resgates diários.` 
                    : "Reivindique sua recompensa gratuita nas Areias.") 
                : (lastClaimInfo 
                    ? `Você já resgatou sua recompensa hoje às ${new Date(lastClaimInfo.claimed_at).getHours().toString().padStart(2, "0")}:${new Date(lastClaimInfo.claimed_at).getMinutes().toString().padStart(2, "0")} e poderá resgatar novamente às 00:01 do dia seguinte.` 
                    : "Você já resgatou sua recompensa de hoje. Volte amanhã!")}
            </span>
            {!isDailyAvailable && lastClaimInfo && (
              <span className="text-xs text-amber-300/80 mt-1 block font-bold">
                🕒 Último resgate efetuado em {formatClaimDate(lastClaimInfo.claimed_at)}
                {lastClaimInfo.missed_days_before > 0 ? ` — (Bônus resgatado: ${lastClaimInfo.missed_days_before} dia(s) de atraso)` : ""}
              </span>
            )}
          </span>
        </span>
        <span className="rounded bg-amber-700 px-5 py-2 text-xs font-black shrink-0 text-amber-100 hover:bg-amber-600 transition-colors">
          {busy ? "INVOCANDO..." : isDailyAvailable ? "RESGATAR" : "INDISPONÍVEL"}
        </span>
      </button>
    </div>
  )
}
