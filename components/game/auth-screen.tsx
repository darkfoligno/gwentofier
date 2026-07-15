"use client"

import { useState } from "react"
import { motion, AnimatePresence } from "framer-motion"
import { Mail, Lock, Eye, EyeOff, Crown, ChevronRight } from "lucide-react"
import { Embers } from "./embers"
import type { Screen } from "@/lib/types"

type Mode = "login" | "register"

function LeatherInput({
  icon: Icon,
  label,
  type = "text",
  toggleable = false,
}: {
  icon: typeof Mail
  label: string
  type?: string
  toggleable?: boolean
}) {
  const [show, setShow] = useState(false)
  const inputType = toggleable ? (show ? "text" : "password") : type
  return (
    <label className="block">
      <span className="mb-1.5 block font-serif text-xs uppercase tracking-widest text-brass">{label}</span>
      <div className="group relative flex items-center rounded-md border border-gold-dark/40 bg-[#1a0f07] shadow-[inset_0_3px_8px_rgba(0,0,0,0.8)] transition-colors focus-within:border-gold focus-within:ring-2 focus-within:ring-gold/40">
        <Icon size={16} className="ml-3 text-brass" />
        <input
          type={inputType}
          placeholder={label}
          className="w-full bg-transparent px-3 py-2.5 text-sm text-foreground placeholder:text-muted-foreground/60 focus:outline-none"
        />
        {toggleable && (
          <button
            type="button"
            onClick={() => setShow((s) => !s)}
            className="mr-3 text-brass transition-colors hover:text-gold"
            aria-label={show ? "Ocultar senha" : "Mostrar senha"}
          >
            {show ? <EyeOff size={16} /> : <Eye size={16} />}
          </button>
        )}
      </div>
    </label>
  )
}

export function AuthScreen({ onEnter }: { onEnter: (s: Screen) => void }) {
  const [mode, setMode] = useState<Mode>("login")

  return (
    <div className="relative flex min-h-screen items-center justify-center overflow-hidden px-4 py-10">
      {/* portal backdrop */}
      <div
        className="absolute inset-0"
        style={{
          background:
            "radial-gradient(ellipse at center, rgba(140,104,32,0.25), transparent 55%), radial-gradient(circle at 50% 120%, rgba(255,120,0,0.15), transparent 50%)",
        }}
      />
      <Embers count={30} />

      <motion.div
        initial={{ opacity: 0, y: 24, scale: 0.96 }}
        animate={{ opacity: 1, y: 0, scale: 1 }}
        transition={{ duration: 0.6, ease: "easeOut" }}
        className="relative z-10 w-full max-w-md"
      >
        {/* spellbook frame */}
        <div
          className="rounded-2xl p-[3px] shadow-[0_20px_60px_rgba(0,0,0,0.85)]"
          style={{ background: "linear-gradient(160deg, #d4af37, #5c4415 40%, #d4af37)" }}
        >
          <div className="wood-grain relative rounded-[14px] px-7 py-8">
            {/* corner rivets */}
            {["left-3 top-3", "right-3 top-3", "left-3 bottom-3", "right-3 bottom-3"].map((pos) => (
              <span
                key={pos}
                className={`absolute ${pos} h-2.5 w-2.5 rounded-full`}
                style={{ background: "radial-gradient(circle at 30% 30%, #f0d98a, #6b5010)" }}
              />
            ))}

            <div className="mb-6 text-center">
              <div className="mx-auto mb-3 flex h-14 w-14 items-center justify-center rounded-full border-2 border-gold/60 bg-black/40 shadow-[0_0_18px_rgba(212,175,55,0.5)]">
                <Crown size={28} className="text-gold" />
              </div>
              <h1 className="font-serif text-2xl font-black tracking-wide text-gold text-shadow-gold">
                GWENT OFIERI
              </h1>
              <p className="mt-0.5 font-serif text-xs uppercase tracking-[0.35em] text-brass">Card Game</p>
            </div>

            {/* brass bookmark tabs */}
            <div className="mb-6 flex gap-2">
              {(["login", "register"] as Mode[]).map((m) => (
                <button
                  key={m}
                  onClick={() => setMode(m)}
                  className={`relative flex-1 rounded-t-md border-b-2 py-2 font-serif text-sm font-bold transition-all ${
                    mode === m
                      ? "border-gold bg-gradient-to-b from-gold/25 to-transparent text-gold"
                      : "border-transparent text-brass/70 hover:text-brass"
                  }`}
                >
                  {m === "login" ? "Entrar" : "Criar Conta"}
                </button>
              ))}
            </div>

            <AnimatePresence mode="wait">
              <motion.div
                key={mode}
                initial={{ opacity: 0, x: mode === "login" ? -20 : 20 }}
                animate={{ opacity: 1, x: 0 }}
                exit={{ opacity: 0, x: mode === "login" ? 20 : -20 }}
                transition={{ duration: 0.25 }}
                className="flex flex-col gap-4"
              >
                <LeatherInput icon={Mail} label="E-mail ou Usuário" />
                <LeatherInput icon={Lock} label="Senha" toggleable />
                {mode === "register" && <LeatherInput icon={Lock} label="Confirmar Senha" toggleable />}

                {/* embossed golden submit */}
                <button
                  onClick={() => onEnter("hub")}
                  className="gold-trim group mt-2 w-full rounded-md py-3 font-serif text-base font-black uppercase tracking-wider text-wood-darkest shadow-[0_6px_16px_rgba(0,0,0,0.7),inset_0_1px_2px_rgba(255,255,255,0.6),inset_0_-3px_6px_rgba(0,0,0,0.3)] transition-all hover:shadow-[0_0_24px_rgba(212,175,55,0.7),inset_0_1px_2px_rgba(255,255,255,0.6)] active:translate-y-0.5"
                >
                  {mode === "login" ? "Adentrar na Taverna" : "Forjar Destino"}
                </button>
              </motion.div>
            </AnimatePresence>

            {/* quick skip toggles */}
            <div className="mt-7 border-t border-gold-dark/30 pt-4">
              <p className="mb-2 text-center text-[10px] uppercase tracking-widest text-muted-foreground">
                Acesso rápido (teste)
              </p>
              <div className="flex gap-2">
                <button
                  onClick={() => onEnter("hub")}
                  className="flex flex-1 items-center justify-center gap-1 rounded border border-gold-dark/40 bg-black/30 py-2 text-xs font-semibold text-brass transition-colors hover:border-gold hover:text-gold"
                >
                  Ir ao Hub <ChevronRight size={13} />
                </button>
                <button
                  onClick={() => onEnter("arena")}
                  className="flex flex-1 items-center justify-center gap-1 rounded border border-gold-dark/40 bg-black/30 py-2 text-xs font-semibold text-brass transition-colors hover:border-gold hover:text-gold"
                >
                  Ir à Arena <ChevronRight size={13} />
                </button>
              </div>
            </div>
          </div>
        </div>
      </motion.div>
    </div>
  )
}
