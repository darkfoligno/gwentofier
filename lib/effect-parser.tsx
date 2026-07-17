import type { LucideIcon } from "lucide-react"
import { Crosshair, Flame, Grab, Layers, Lock, RefreshCw, ShieldAlert, Sparkles } from "lucide-react"

export interface EffectBadge {
  code: string
  label: string
  description: string
  Icon: LucideIcon
  className: string
}

const groups: Array<{ codes: string[]; label: string; description: string; Icon: LucideIcon; className: string }> = [
  { codes: ["draw", "search_deck"], label: "Compra", description: "Compra ou procura cartas no deck.", Icon: Layers, className: "border-blue-400/60 bg-blue-950/90 text-blue-200" },
  { codes: ["silence", "block_effect", "lock_mana", "card_restriction"], label: "Restrição", description: "Limita recursos, efeitos ou ações.", Icon: Lock, className: "border-purple-500/60 bg-purple-950/90 text-purple-200" },
  { codes: ["damage", "burn", "bleed", "destroy"], label: "Dano", description: "Causa dano ou destrói uma carta.", Icon: Flame, className: "border-orange-500/60 bg-red-950/90 text-orange-200" },
  { codes: ["direct_attack", "block_direct"], label: "Ataque direto", description: "Interage com ataques diretos.", Icon: Crosshair, className: "border-red-400/70 bg-red-950 text-red-200" },
  { codes: ["steal_hand", "steal_deck", "discard_hand"], label: "Roubo", description: "Rouba ou descarta recursos do rival.", Icon: Grab, className: "border-fuchsia-600/60 bg-purple-950/90 text-fuchsia-200" },
  { codes: ["bounce", "revive", "swap_defense"], label: "Movimento", description: "Move, revive ou troca cartas de zona.", Icon: RefreshCw, className: "border-emerald-400/60 bg-emerald-950/90 text-emerald-200" },
  { codes: ["heal", "shield", "mirror_trap"], label: "Proteção", description: "Cura, protege ou reflete ameaças.", Icon: ShieldAlert, className: "border-lime-400/60 bg-green-950/90 text-lime-200" },
  { codes: ["combo", "turn_scale", "deck_passive", "win_condition"], label: "Passiva", description: "Combo ou condição persistente.", Icon: Sparkles, className: "border-amber-300/70 bg-amber-950/90 text-amber-100" },
]

export function parseEffectBadges(definition?: Array<{ effect_code?: string }>): EffectBadge[] {
  const codes = [...new Set((definition ?? []).map(effect => effect.effect_code).filter((code): code is string => Boolean(code)))]
  return codes.flatMap(code => {
    const group = groups.find(item => item.codes.includes(code))
    return group ? [{ code, label: group.label, description: group.description, Icon: group.Icon, className: group.className }] : []
  })
}

export function highlightEffectText(text: string) {
  const keywords = /(Ataque Direto|Compra|Dano|Cura|Escudo|Destruir|Reviver)/gi
  return text.split(keywords).map((part, index) => keywords.test(part)
    ? <strong key={`${part}-${index}`} className={/ataque|dano|destruir/i.test(part) ? "text-red-700" : /compra/i.test(part) ? "text-blue-700" : "text-emerald-700"}>{part}</strong>
    : part)
}
