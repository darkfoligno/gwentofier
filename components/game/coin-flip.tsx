"use client"

import { useEffect, useState } from "react"
import { motion, AnimatePresence } from "framer-motion"
import { supabase } from "@/lib/supabase"

interface CoinFlipProps {
  matchId: string
  firstPlayerId: string
  onComplete: () => void
}

export function CoinFlip({ matchId, firstPlayerId, onComplete }: CoinFlipProps) {
  const [show, setShow] = useState(true)
  const [resultText, setResultText] = useState("")

  useEffect(() => {
    // Acknowledge initiative on the server after the animation
    const ack = async () => {
      try {
        await supabase.rpc("acknowledge_initiative", { p_match_id: matchId })
      } catch (err) {
        console.error("Failed to ack initiative", err)
      }
    }

    // Sequence: 
    // 0-3s: Coin spinning
    // 3-5s: Show result text
    // 5.5s: Fade out and complete
    const t1 = setTimeout(() => {
      // Determine if current user is first player or opponent
      supabase.auth.getUser().then(({ data }) => {
        if (data.user?.id === firstPlayerId) {
          setResultText("VOCÊ COMEÇA!")
        } else {
          setResultText("O OPONENTE COMEÇA!")
        }
      })
    }, 3000)

    const t2 = setTimeout(() => {
      setShow(false)
    }, 5000)

    const t3 = setTimeout(() => {
      ack().then(onComplete)
    }, 5500)

    return () => {
      clearTimeout(t1)
      clearTimeout(t2)
      clearTimeout(t3)
    }
  }, [matchId, firstPlayerId, onComplete])

  return (
    <AnimatePresence>
      {show && (
        <motion.div
          initial={{ opacity: 0 }}
          animate={{ opacity: 1 }}
          exit={{ opacity: 0 }}
          transition={{ duration: 0.5 }}
          className="fixed inset-0 z-[300] flex flex-col items-center justify-center bg-black/80 backdrop-blur-md"
        >
          {/* Coin Container */}
          <div className="relative h-48 w-48 perspective-1000">
            <motion.div
              initial={{ rotateY: 0, rotateX: 0, y: 100, scale: 0.5 }}
              animate={{ 
                rotateY: [0, 360, 720, 1080, 1440], 
                rotateX: [0, 180, 360, 540, 720],
                y: [100, -150, -200, -100, 0],
                scale: [0.5, 1.2, 1.5, 1.2, 1]
              }}
              transition={{ duration: 3, ease: "circOut" }}
              className="h-full w-full transform-style-preserve-3d"
            >
              {/* Front of Coin */}
              <div className="absolute inset-0 flex items-center justify-center rounded-full border-4 border-amber-400 bg-amber-700 bg-gradient-to-br from-amber-300 via-amber-600 to-amber-900 shadow-[0_0_50px_rgba(251,191,36,0.6)] backface-hidden">
                <span className="font-serif text-5xl font-black text-amber-100 drop-shadow-lg">1</span>
              </div>
              {/* Back of Coin */}
              <div className="absolute inset-0 flex items-center justify-center rounded-full border-4 border-stone-400 bg-stone-700 bg-gradient-to-br from-stone-300 via-stone-500 to-stone-800 shadow-[0_0_50px_rgba(168,162,158,0.6)] backface-hidden" style={{ transform: "rotateY(180deg)" }}>
                <span className="font-serif text-5xl font-black text-stone-100 drop-shadow-lg">2</span>
              </div>
            </motion.div>
          </div>

          <motion.div
            initial={{ opacity: 0, y: 20 }}
            animate={{ opacity: resultText ? 1 : 0, y: resultText ? 0 : 20 }}
            className="mt-12 text-center"
          >
            <h2 className="font-serif text-4xl font-black uppercase text-amber-400 drop-shadow-[0_0_15px_rgba(251,191,36,0.5)]">
              {resultText}
            </h2>
          </motion.div>
        </motion.div>
      )}
    </AnimatePresence>
  )
}
