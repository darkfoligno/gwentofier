export type Rarity = "common" | "rare" | "epic" | "legendary" | "collab"
export type OfficialCardType = "Bestiário" | "M&F" | "Witcher" | "Elfica" | "Cívil" | "Vampiro"

export type GameCard = {
  id: string
  nome: string
  tipo: string
  elemento: OfficialCardType
  mana: number
  ataque: number
  vida: number
  raridade: Rarity
  efeito: string
  image_url?: string | null
  effect_definition?: Array<{ effect_code?: string; [key: string]: unknown }>
  is_original_rpg?: boolean
  is_collab?: boolean
}

export const raridadeLabel: Record<Rarity, string> = { common: "Comum", rare: "Rara", epic: "Épica", legendary: "Lendária", collab: "Collab" }
export const raridadeCor: Record<Rarity, string> = { common: "#94a3b8", rare: "#3b82f6", epic: "#9333ea", legendary: "#f59e0b", collab: "#ec4899" }
export const filtrosRaridade: { key: Rarity; label: string }[] = Object.entries(raridadeLabel).map(([key, label]) => ({ key: key as Rarity, label }))
export const filtrosElemento: { key: OfficialCardType; label: string }[] = ["Bestiário", "M&F", "Witcher", "Elfica", "Cívil", "Vampiro"].map(label => ({ key: label as OfficialCardType, label }))
