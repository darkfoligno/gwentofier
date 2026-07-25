"use client"

import { useEffect, useState } from "react"
import { motion, AnimatePresence } from "framer-motion"
import { Sparkles, Trophy } from "lucide-react"

import { usePathname } from "next/navigation"
import { supabase } from "@/lib/supabase"

export function GlobalMarquee() {
  const pathname = usePathname()
  const [tickerItems, setTickerItems] = useState<string[]>([
    "⚔️ BEM-VINDO À ARENA OFIERI! CONQUISTE GRIMÓRIOS E DESAFIE OPONENTES NA LOJA."
  ])
  const [currentIndex, setCurrentIndex] = useState(0)

  if (pathname === "/arena") return null

  useEffect(() => {
    async function loadTicker() {
      try {
        const { data, error } = await supabase.rpc('get_recent_legendary_pulls')
        if (error) throw error
        if (data && data.length > 0) {
          setTickerItems(data.map((item: any) => `✨ PARABÉNS! ${item.username.toUpperCase()} ACABA DE TIRAR A CARTA LENDÁRIA « ${item.card_name.toUpperCase()} » 🏆`))
        } else {
          setTickerItems(["⚔️ BEM-VINDO À ARENA OFIERI! CONQUISTE GRIMÓRIOS E DESAFIE OPONENTES NA LOJA."])
        }
      } catch (err) {
        setTickerItems(["⚔️ BEM-VINDO À ARENA OFIERI! CONQUISTE GRIMÓRIOS E DESAFIE OPONENTES NA LOJA."])
      }
    }
    loadTicker()
  }, [])

  useEffect(() => {
    if (tickerItems.length <= 1) return
    const interval = window.setInterval(() => {
      setCurrentIndex(prev => (prev + 1) % tickerItems.length)
    }, 6000)
    return () => window.clearInterval(interval)
  }, [tickerItems.length])

  if (tickerItems.length === 0) return null

  const current = tickerItems[currentIndex]

  return (
    <div className="fixed top-0 left-0 right-0 z-[500] flex h-8 items-center justify-center overflow-hidden bg-gradient-to-r from-amber-950 via-stone-900 to-amber-950 border-b border-amber-600/40 shadow-[0_0_15px_rgba(217,119,6,0.3)] pointer-events-none">
      <AnimatePresence mode="wait">
        <motion.div
          key={currentIndex}
          initial={{ y: 20, opacity: 0 }}
          animate={{ y: 0, opacity: 1 }}
          exit={{ y: -20, opacity: 0 }}
          transition={{ duration: 0.5 }}
          className="flex items-center gap-2 text-[9px] font-black uppercase tracking-wider text-amber-200 sm:text-xs"
        >
          <Sparkles className="animate-pulse text-amber-400" size={14} />
          <span>{current}</span>
          <Trophy className="text-amber-400" size={14} />
        </motion.div>
      </AnimatePresence>
    </div>
  )
}
