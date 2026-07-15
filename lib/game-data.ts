export type Rarity = "common" | "rare" | "epic" | "legendary" | "collab"

export type GameCard = {
  id: string
  nome: string
  tipo: string
  elemento: "fogo" | "gelo" | "arcano" | "natureza" | "sombra"
  mana: number
  ataque: number
  vida: number
  raridade: Rarity
  efeito: string
}

export const raridadeLabel: Record<Rarity, string> = {
  common: "Comum",
  rare: "Rara",
  epic: "Épica",
  legendary: "Lendária",
  collab: "Collab",
}

export const raridadeCor: Record<Rarity, string> = {
  common: "var(--rarity-common)",
  rare: "var(--rarity-rare)",
  epic: "var(--rarity-epic)",
  legendary: "var(--rarity-legendary)",
  collab: "#ff6b9d",
}

export const elementoIcon: Record<GameCard["elemento"], string> = {
  fogo: "Flame",
  gelo: "Snowflake",
  arcano: "Sparkles",
  natureza: "Leaf",
  sombra: "Moon",
}

export const collection: GameCard[] = [
  {
    id: "c1",
    nome: "Cavaleiro de Ofieri",
    tipo: "Unidade / Humano",
    elemento: "fogo",
    mana: 4,
    ataque: 4500,
    vida: 8000,
    raridade: "legendary",
    efeito: "Ao ser posicionado, causa 1200 de dano à unidade inimiga à sua frente. Ganha +500 de ataque para cada Reforço aliado revelado.",
  },
  {
    id: "c2",
    nome: "Feiticeira de Yggdrasil",
    tipo: "Unidade / Mística",
    elemento: "natureza",
    mana: 5,
    ataque: 3200,
    vida: 6500,
    raridade: "epic",
    efeito: "No início do seu turno, cura 800 de vida da Carta de Defesa mais ferida. Imune a efeitos de Sombra.",
  },
  {
    id: "c3",
    nome: "Golem de Ferro Forjado",
    tipo: "Unidade / Constructo",
    elemento: "arcano",
    mana: 6,
    ataque: 2000,
    vida: 12000,
    raridade: "rare",
    efeito: "Provocar: inimigos devem atacar esta unidade primeiro. Reduz o dano recebido em 30%.",
  },
  {
    id: "c4",
    nome: "Arqueira das Sombras",
    tipo: "Unidade / Ágil",
    elemento: "sombra",
    mana: 3,
    ataque: 3800,
    vida: 3000,
    raridade: "rare",
    efeito: "Furtividade por 1 turno. Ao atacar, ignora a linha de Reforços inimiga.",
  },
  {
    id: "c5",
    nome: "Dragão de Gelo Ancião",
    tipo: "Unidade / Dragão",
    elemento: "gelo",
    mana: 8,
    ataque: 6000,
    vida: 9000,
    raridade: "legendary",
    efeito: "Grito de Batalha: congela toda a linha de Ataque inimiga por 1 turno. Sopro Glacial ao morrer.",
  },
  {
    id: "c6",
    nome: "Servo da Taverna",
    tipo: "Unidade / Humano",
    elemento: "natureza",
    mana: 1,
    ataque: 1000,
    vida: 1500,
    raridade: "common",
    efeito: "Ao morrer, restaura 1 de Mana ao seu portador.",
  },
  {
    id: "c7",
    nome: "Batedor Élfico",
    tipo: "Unidade / Ágil",
    elemento: "natureza",
    mana: 2,
    ataque: 2200,
    vida: 1800,
    raridade: "common",
    efeito: "Ao ser posicionado, compre 1 carta do topo do Deck.",
  },
  {
    id: "c8",
    nome: "Avatar d500 Universal",
    tipo: "Unidade / Collab",
    elemento: "arcano",
    mana: 7,
    ataque: 5000,
    vida: 5000,
    raridade: "collab",
    efeito: "Copia o efeito da última carta enviada ao Cemitério. Não pode ser alvo de efeitos Lendários.",
  },
  {
    id: "c9",
    nome: "Guardião Rúnico",
    tipo: "Unidade / Constructo",
    elemento: "arcano",
    mana: 4,
    ataque: 3000,
    vida: 5500,
    raridade: "epic",
    efeito: "Enquanto em campo, seus Reforços não podem ser revelados por efeitos inimigos.",
  },
  {
    id: "c10",
    nome: "Chama Errante",
    tipo: "Feitiço / Fogo",
    elemento: "fogo",
    mana: 2,
    ataque: 0,
    vida: 0,
    raridade: "rare",
    efeito: "Causa 2500 de dano dividido entre até 3 unidades inimigas na linha de Ataque.",
  },
]

export const filtrosRaridade: { key: Rarity; label: string }[] = [
  { key: "common", label: "Comum" },
  { key: "rare", label: "Rara" },
  { key: "epic", label: "Épica" },
  { key: "legendary", label: "Lendária" },
  { key: "collab", label: "Collab" },
]

export const filtrosElemento: { key: GameCard["elemento"]; label: string }[] = [
  { key: "fogo", label: "Fogo" },
  { key: "gelo", label: "Gelo" },
  { key: "arcano", label: "Arcano" },
  { key: "natureza", label: "Natureza" },
  { key: "sombra", label: "Sombra" },
]

export const questsDiarias = [
  { titulo: "Vencer 1 Duelo Amistoso", recompensa: "50 Moedas + Pacote", feito: false },
  { titulo: "Jogar 5 cartas Lendárias", recompensa: "30 Moedas", feito: true },
  { titulo: "Destruir 10 unidades inimigas", recompensa: "80 Moedas", feito: false },
  { titulo: "Abrir o Pacote Diário", recompensa: "Fragmentos Rúnicos", feito: false },
]

export const feedNoticias = [
  {
    tag: "Expansão",
    titulo: "Nova Expansão: Mitos de Yggdrasil & Collab D500",
    texto: "48 novas cartas chegam à taverna, incluindo a linha colaborativa Universal d500 com raridade exclusiva.",
  },
  {
    tag: "Balanceamento",
    titulo: "Notas de Atualização 3.4 — O Forjar do Ferro",
    texto: "Golem de Ferro Forjado teve sua vida ajustada. Feitiços de Fogo agora custam 1 Mana a menos na Arena PVP.",
  },
  {
    tag: "Lore",
    titulo: "Crônicas de Ofieri: A Queda da Ordem Rúnica",
    texto: "Descubra os segredos por trás dos Cavaleiros de Ofieri e o pacto proibido com as Sombras de Yggdrasil.",
  },
]
