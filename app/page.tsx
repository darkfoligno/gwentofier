"use client"

import { useState } from "react"
import { AnimatePresence, motion } from "framer-motion"
import { AuthScreen } from "@/components/game/auth-screen"
import { HubScreen } from "@/components/game/hub-screen"
import { ArenaScreen } from "@/components/game/arena-screen"
import type { Screen } from "@/lib/types"

const debugItems: { key: Screen; label: string }[] = [
  { key: "auth", label: "Login" },
  { key: "hub", label: "Hub" },
  { key: "arena", label: "Arena" },
]

export default function Page() {
  const [activeScreen, setActiveScreen] = useState<Screen>("arena")

  return (
    <main className="relative min-h-screen">
      {/* floating debug toggle */}
      <div className="fixed right-3 top-3 z-[200] flex items-center gap-1 rounded-lg border border-gold/40 bg-wood-darkest/90 p-1 shadow-[0_6px_18px_rgba(0,0,0,0.8)] backdrop-blur-md">
        {debugItems.map((item) => (
          <button
            key={item.key}
            onClick={() => setActiveScreen(item.key)}
            className={`rounded px-2.5 py-1 font-serif text-[11px] font-bold uppercase tracking-wide transition-all ${
              activeScreen === item.key
                ? "bg-gold text-wood-darkest"
                : "text-brass hover:bg-gold/15 hover:text-gold"
            }`}
          >
            {item.label}
          </button>
        ))}
      </div>

      <AnimatePresence mode="wait">
        <motion.div
          key={activeScreen}
          initial={{ opacity: 0 }}
          animate={{ opacity: 1 }}
          exit={{ opacity: 0 }}
          transition={{ duration: 0.35 }}
        >
          {activeScreen === "auth" && <AuthScreen onEnter={setActiveScreen} />}
          {activeScreen === "hub" && <HubScreen onEnter={setActiveScreen} />}
          {activeScreen === "arena" && <ArenaScreen />}
        </motion.div>
      </AnimatePresence>
    </main>
  )
}
