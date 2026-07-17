"use client"

import { useEffect, useState } from "react"
import { motion } from "framer-motion"
import {
  Search,
  Coins,
  Package,
  Crown,
  Home,
  Layers,
  BookOpen,
  Swords,
  Gem,
  Check,
  Sparkles,
  Flame,
  Snowflake,
  Leaf,
  Moon,
  ChevronRight,
} from "lucide-react"
import {
  filtrosRaridade,
  filtrosElemento,
  questsDiarias,
  feedNoticias,
  raridadeCor,
  type Rarity,
  type GameCard as GameCardType,
} from "@/lib/game-data"
import type { Screen } from "@/lib/types"
import { supabase } from "@/lib/supabase"
import { GameCard } from "./game-card"

const elementIcons = { fogo: Flame, gelo: Snowflake, arcano: Sparkles, natureza: Leaf, sombra: Moon }

const navItems = [
  { label: "Início", icon: Home },
  { label: "Meus Decks", icon: Layers },
  { label: "Modo História", icon: BookOpen },
  { label: "Campanha PVE", icon: Swords },
  { label: "Inventário", icon: Package },
]

function Panel({
  title,
  children,
  className,
}: {
  title: string
  children: React.ReactNode
  className?: string
}) {
  return (
    <section
      className={`flex min-h-0 flex-col rounded-xl p-[2px] shadow-[0_10px_30px_rgba(0,0,0,0.7)] ${className ?? ""}`}
      style={{ background: "linear-gradient(160deg, #6b5010, #2c1e14 45%, #6b5010)" }}
    >
      <div className="wood-grain flex min-h-0 flex-1 flex-col rounded-[10px]">
        <h2 className="border-b border-gold-dark/40 px-4 py-3 font-serif text-sm font-bold uppercase tracking-wider text-gold text-shadow-gold">
          {title}
        </h2>
        <div className="min-h-0 flex-1">{children}</div>
      </div>
    </section>
  )
}

function TopBar() {
  return (
    <header
      className="flex flex-col gap-4 rounded-xl p-[2px] shadow-[0_10px_30px_rgba(0,0,0,0.7)] xl:flex-row xl:items-center xl:justify-between"
      style={{ background: "linear-gradient(160deg, #6b5010, #242424 45%, #6b5010)" }}
    >
      <div className="iron-plate flex flex-col gap-4 rounded-[10px] px-4 py-3 xl:flex-row xl:items-center xl:justify-between">
        {/* profile */}
        <div className="flex items-center gap-3">
          <div className="relative">
            <div className="flex h-14 w-14 items-center justify-center rounded-full border-2 border-gold bg-gradient-to-b from-leather to-wood-darkest shadow-[0_0_14px_rgba(212,175,55,0.5)]">
              <Crown size={24} className="text-gold" />
            </div>
            <span className="absolute -bottom-1 left-1/2 -translate-x-1/2 rounded-full border border-gold bg-wood-darkest px-1.5 text-[10px] font-bold text-gold">
              42
            </span>
          </div>
          <div className="min-w-[150px]">
            <p className="font-serif text-base font-bold text-gold">Mestre Foli</p>
            <p className="text-[11px] uppercase tracking-wide text-brass">Grão-Mestre de Ofieri</p>
            <div className="mt-1 h-2 w-40 overflow-hidden rounded-full border border-gold-dark/50 bg-black/50">
              <div
                className="h-full rounded-full"
                style={{
                  width: "68%",
                  background: "linear-gradient(90deg, #8c6820, #d4af37)",
                  boxShadow: "0 0 8px rgba(212,175,55,0.7)",
                }}
              />
            </div>
          </div>
        </div>

        {/* center nav */}
        <nav className="flex flex-wrap items-center justify-center gap-1.5">
          {navItems.map((item, i) => {
            const Icon = item.icon
            const active = i === 0
            return (
              <button
                key={item.label}
                className={`flex items-center gap-1.5 rounded border px-3 py-2 font-serif text-xs font-semibold transition-all ${
                  active
                    ? "border-gold bg-gradient-to-b from-gold/25 to-transparent text-gold"
                    : "border-gold-dark/30 bg-black/30 text-brass hover:border-gold/60 hover:text-gold"
                }`}
              >
                <Icon size={14} />
                {item.label}
              </button>
            )
          })}
        </nav>

        {/* economy */}
        <div className="flex items-center gap-3">
          <div className="flex items-center gap-2 rounded-md border border-gold-dark/50 bg-black/40 px-3 py-2">
            <motion.span
              animate={{ rotateY: 360 }}
              transition={{ duration: 3, repeat: Number.POSITIVE_INFINITY, ease: "linear" }}
              style={{ transformStyle: "preserve-3d" }}
            >
              <Coins size={20} className="text-gold" />
            </motion.span>
            <span className="font-bold text-foreground">2.450</span>
            <span className="text-[10px] uppercase text-brass">Moedas</span>
          </div>
          <motion.div
            animate={{ boxShadow: ["0 0 6px rgba(255,170,0,0.4)", "0 0 18px rgba(255,170,0,0.9)", "0 0 6px rgba(255,170,0,0.4)"] }}
            transition={{ duration: 1.8, repeat: Number.POSITIVE_INFINITY }}
            className="flex items-center gap-2 rounded-md border border-rune-amber/60 bg-rune-amber/10 px-3 py-2"
          >
            <Package size={18} className="text-rune-amber" />
            <span className="text-xs font-semibold text-rune-amber">1 Pacote Diário</span>
          </motion.div>
        </div>
      </div>
    </header>
  )
}

function Compendium() {
  const [rar, setRar] = useState<Rarity | null>(null)
  const [cards, setCards] = useState<GameCardType[]>([])
  useEffect(() => {
    void supabase.from("cards").select("id,name,image_url,element,rarity,card_type,is_original_rpg,base_power,base_max_life,effect_mana_cost,effect_text,card_effects(effect_code)").eq("is_active", true).order("name").then(({ data, error }) => {
      if (error) { console.error("Falha ao carregar catálogo", error); return }
      setCards((data ?? []).map((card: any) => ({
        id: card.id, nome: card.name, tipo: card.card_type, image_url: card.image_url,
        elemento: (["fogo", "gelo", "arcano", "natureza", "sombra"].includes(card.element) ? card.element : "arcano") as GameCardType["elemento"],
        raridade: card.rarity as Rarity, mana: card.effect_mana_cost, ataque: card.base_power, vida: card.base_max_life,
        efeito: card.effect_text ?? "", effect_definition: card.card_effects ?? [], is_original_rpg: card.is_original_rpg,
      })))
    })
  }, [])
  const list = rar ? cards.filter((card) => card.raridade === rar) : cards
  return (
    <Panel title="Coleção & Enciclopédia" className="min-h-0">
      <div className="flex h-full flex-col p-3">
        <div className="relative mb-3">
          <Search size={15} className="absolute left-3 top-1/2 -translate-y-1/2 text-brass" />
          <input
            placeholder="Pesquisar carta por nome, efeito ou tipagem..."
            className="w-full rounded-md border border-gold-dark/40 bg-[#1a0f07] py-2 pl-9 pr-3 text-xs text-foreground shadow-[inset_0_2px_6px_rgba(0,0,0,0.7)] placeholder:text-muted-foreground/60 focus:border-gold focus:outline-none focus:ring-1 focus:ring-gold/40"
          />
        </div>
        <div className="mb-3 flex flex-wrap gap-1.5">
          {filtrosRaridade.map((f) => (
            <button
              key={f.key}
              onClick={() => setRar(rar === f.key ? null : f.key)}
              className="rounded-full border px-2.5 py-1 text-[10px] font-semibold transition-all"
              style={{
                borderColor: rar === f.key ? raridadeCor[f.key] : "rgba(140,104,32,0.4)",
                color: rar === f.key ? raridadeCor[f.key] : "#a89575",
                background: rar === f.key ? `${raridadeCor[f.key]}22` : "rgba(0,0,0,0.3)",
              }}
            >
              {f.label}
            </button>
          ))}
        </div>
        <div className="mb-2 flex flex-wrap gap-1.5">
          {filtrosElemento.map((f) => {
            const Icon = elementIcons[f.key]
            return (
              <span
                key={f.key}
                className="flex items-center gap-1 rounded border border-gold-dark/30 bg-black/30 px-2 py-0.5 text-[10px] text-brass"
              >
                <Icon size={11} /> {f.label}
              </span>
            )
          })}
        </div>
        <div className="scrollbar-thin -mr-1 grid flex-1 grid-cols-2 gap-3 overflow-y-auto pr-1 xl:grid-cols-3">
          {list.map(card => <GameCard key={card.id} card={card} interactive />)}
          {!list.length && <div className="col-span-full flex h-40 items-center justify-center rounded-lg border border-dashed border-amber-600/30 text-xs text-brass">Nenhuma carta disponível no catálogo.</div>}
        </div>
      </div>
    </Panel>
  )
}

function NewsFeed() {
  return (
    <Panel title="Crônicas & Atualizações">
      <div className="scrollbar-thin flex h-full flex-col gap-4 overflow-y-auto p-3">
        {/* featured banner */}
        <div
          className="relative overflow-hidden rounded-lg border border-gold/40 p-5 shadow-[0_8px_20px_rgba(0,0,0,0.6)]"
          style={{
            background:
              "radial-gradient(circle at 80% 20%, rgba(192,132,252,0.35), transparent 50%), linear-gradient(150deg, #3a2817, #140d07)",
          }}
        >
          <span className="inline-block rounded bg-rune-amber/20 px-2 py-0.5 text-[10px] font-bold uppercase tracking-wider text-rune-amber">
            Destaque
          </span>
          <h3 className="mt-2 font-serif text-lg font-black leading-tight text-gold text-shadow-gold text-balance">
            Nova Expansão: Mitos de Yggdrasil & Collab D500
          </h3>
          <p className="mt-1 max-w-md text-xs leading-relaxed text-muted-foreground">
            48 novas cartas chegam à taverna, incluindo a linha colaborativa Universal d500 com raridade exclusiva.
          </p>
          <button className="mt-3 flex items-center gap-1 rounded border border-gold/50 bg-black/30 px-3 py-1.5 text-xs font-semibold text-gold transition-colors hover:bg-gold/15">
            Explorar Expansão <ChevronRight size={13} />
          </button>
        </div>

        {/* claim daily pack widget */}
        <motion.button
          whileHover={{ scale: 1.015 }}
          whileTap={{ scale: 0.985 }}
          className="relative flex items-center justify-between overflow-hidden rounded-lg border border-rune-amber/60 px-4 py-3"
          style={{ background: "linear-gradient(90deg, rgba(255,170,0,0.2), rgba(140,104,32,0.15))" }}
        >
          <div className="flex items-center gap-3">
            <motion.span
              animate={{ y: [0, -3, 0] }}
              transition={{ duration: 1.4, repeat: Number.POSITIVE_INFINITY }}
            >
              <Package size={26} className="text-rune-amber" />
            </motion.span>
            <div className="text-left">
              <p className="font-serif text-sm font-bold text-gold">Resgatar Pacote Diário</p>
              <p className="text-[11px] text-brass">4 Cartas Aleatórias</p>
            </div>
          </div>
          <span className="rounded-full bg-rune-amber px-3 py-1 text-xs font-black uppercase text-wood-darkest">
            Resgatar
          </span>
        </motion.button>

        {/* daily quests */}
        <div className="rounded-lg border border-gold-dark/40 bg-black/30 p-3">
          <p className="mb-2 font-serif text-xs font-bold uppercase tracking-wide text-brass">Missões Diárias</p>
          <div className="space-y-2">
            {questsDiarias.map((q) => (
              <div key={q.titulo} className="flex items-center gap-2">
                <span
                  className={`flex h-5 w-5 shrink-0 items-center justify-center rounded border ${
                    q.feito ? "border-rune-amber bg-rune-amber/20" : "border-gold-dark/50 bg-black/40"
                  }`}
                >
                  {q.feito && <Check size={12} className="text-rune-amber" />}
                </span>
                <div className="min-w-0 flex-1">
                  <p className={`truncate text-xs ${q.feito ? "text-muted-foreground line-through" : "text-foreground"}`}>
                    {q.titulo}
                  </p>
                  <p className="text-[10px] text-brass">Recompensa: {q.recompensa}</p>
                </div>
              </div>
            ))}
          </div>
        </div>

        {/* patch notes / lore */}
        {feedNoticias.slice(1).map((n) => (
          <div key={n.titulo} className="rounded-lg border border-gold-dark/30 bg-black/20 p-3">
            <span className="text-[10px] font-bold uppercase tracking-wider text-brass">{n.tag}</span>
            <h4 className="font-serif text-sm font-bold text-gold">{n.titulo}</h4>
            <p className="mt-0.5 text-[11px] leading-relaxed text-muted-foreground">{n.texto}</p>
          </div>
        ))}
      </div>
    </Panel>
  )
}

function GameModes({ onEnter }: { onEnter: (s: Screen) => void }) {
  const modes = [
    {
      label: "Arena PVP",
      sub: "Tempo Real",
      icon: Swords,
      color: "#ff3333",
      action: () => onEnter("arena"),
    },
    { label: "Sala de Testes", sub: "Amistoso", icon: Snowflake, color: "#38bdf8", action: () => onEnter("arena") },
    { label: "Loja de Cartas & Gacha", sub: "Pacote Universal d500", icon: Gem, color: "#c084fc", action: () => {} },
    { label: "Modo Campanha", sub: "20 Decks", icon: Leaf, color: "#66dd88", action: () => {} },
  ]
  return (
    <Panel title="Salões de Duelo">
      <div className="scrollbar-thin flex h-full flex-col gap-3 overflow-y-auto p-3">
        {modes.map((m) => {
          const Icon = m.icon
          return (
            <motion.button
              key={m.label}
              onClick={m.action}
              whileHover={{ scale: 1.03 }}
              whileTap={{ scale: 0.98 }}
              className="group relative flex items-center gap-4 overflow-hidden rounded-xl border p-4 text-left shadow-[0_6px_18px_rgba(0,0,0,0.6)]"
              style={{
                borderColor: `${m.color}66`,
                background: `radial-gradient(circle at 15% 50%, ${m.color}33, transparent 60%), linear-gradient(120deg, #241811, #140d07)`,
              }}
            >
              <div
                className="flex h-12 w-12 shrink-0 items-center justify-center rounded-lg border"
                style={{ borderColor: `${m.color}88`, background: `${m.color}22` }}
              >
                <Icon size={26} style={{ color: m.color }} />
              </div>
              <div className="flex-1">
                <p className="font-serif text-base font-black text-gold text-shadow-gold">{m.label}</p>
                <p className="text-[11px] uppercase tracking-wide text-brass">{m.sub}</p>
              </div>
              <ChevronRight size={18} className="text-brass transition-transform group-hover:translate-x-1" />
            </motion.button>
          )
        })}
      </div>
    </Panel>
  )
}

export function HubScreen({ onEnter }: { onEnter: (s: Screen) => void }) {
  return (
    <div className="relative min-h-screen p-3 md:p-5">
      <div className="mx-auto flex max-w-[1600px] flex-col gap-4">
        <TopBar />
        <div className="grid grid-cols-1 gap-4 lg:grid-cols-12">
          <div className="lg:col-span-3 lg:h-[calc(100vh-180px)]">
            <Compendium />
          </div>
          <div className="lg:col-span-5 lg:h-[calc(100vh-180px)]">
            <NewsFeed />
          </div>
          <div className="lg:col-span-4 lg:h-[calc(100vh-180px)]">
            <GameModes onEnter={onEnter} />
          </div>
        </div>
      </div>
    </div>
  )
}
