"use client"

import { useEffect, useState } from "react"
import { motion, AnimatePresence } from "framer-motion"
import { Sparkles, Trophy } from "lucide-react"

import { usePathname } from "next/navigation"
import { supabase } from "@/lib/supabase"

interface LegendaryDrop {
  id: string
  player_name: string
  card_name: string
}

export function GlobalMarquee() {
  const pathname = usePathname()
  const [drops, setDrops] = useState<LegendaryDrop[]>([
    { id: 'f1', player_name: 'GeraltOfRivia', card_name: 'Ciri criança' },
    { id: 'f2', player_name: 'YenneferOfVengerberg', card_name: 'Yennefer' },
    { id: 'f3', player_name: 'Dandelion', card_name: 'Borch Três Gralhas' }
  ])
  const [currentIndex, setCurrentIndex] = useState(0)

  if (pathname === "/arena") return null

  useEffect(() => {
    const fetchDrops = async () => {
      try {
        const { data, error } = await supabase
          .from('user_cards')
          .select(`
            created_at,
            profiles:user_id(username),
            cards:card_id(name, rarity)
          `)
          .eq('cards.rarity', 'legendary')
          .order('created_at', { ascending: false })
          .limit(5)
        
        if (error) throw error;
        
        if (data && data.length > 0) {
          setDrops(data.map((row: any, i) => ({
            id: String(i),
            player_name: row.profiles?.username || 'GeraltOfRivia',
            card_name: row.cards?.name || 'Ciri: Jovem'
          })))
        }
      } catch (err) {
        // Silencia erro 400 / PostgREST no letreiro rolante de produção na Vercel
      }
    }
    
    void fetchDrops()
  }, [])

  useEffect(() => {
    if (drops.length <= 1) return
    const interval = window.setInterval(() => {
      setCurrentIndex(prev => (prev + 1) % drops.length)
    }, 6000) // Change message every 6 seconds
    return () => window.clearInterval(interval)
  }, [drops.length])

  if (drops.length === 0) return null

  const current = drops[currentIndex]

  return (
    <div className="fixed top-0 left-0 right-0 z-[500] flex h-8 items-center justify-center overflow-hidden bg-gradient-to-r from-amber-950 via-stone-900 to-amber-950 border-b border-amber-600/40 shadow-[0_0_15px_rgba(217,119,6,0.3)] pointer-events-none">
      <AnimatePresence mode="wait">
        <motion.div
          key={current.id}
          initial={{ y: 20, opacity: 0 }}
          animate={{ y: 0, opacity: 1 }}
          exit={{ y: -20, opacity: 0 }}
          transition={{ duration: 0.5 }}
          className="flex items-center gap-2 text-[9px] font-black uppercase tracking-wider text-amber-200 sm:text-xs"
        >
          <Sparkles className="animate-pulse text-amber-400" size={14} />
          <span>Parabéns! <b className="text-white">{current.player_name}</b> acaba de tirar a carta Lendária <b className="text-amber-400">« {current.card_name} »</b></span>
          <Trophy className="text-amber-400" size={14} />
        </motion.div>
      </AnimatePresence>
    </div>
  )
}
