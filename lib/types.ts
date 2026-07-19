export type Screen = "auth" | "hub" | "store" | "spectator" | "arena" | "friends" | "patch-notes" | "collection" | "decks"

export type MatchStatus = "waiting" | "ban_phase" | "setup" | "initiative" | "in_progress" | "finished" | "cancelled" | "expired"
export type MatchCardZone = "deck" | "hand" | "life" | "reinforcement" | "attacker" | "leader" | "graveyard" | "banished" | "temporary"
export type PendingAttackStatus = "awaiting_reaction" | "reaction_used" | "reaction_declined" | "resolving" | "resolved" | "cancelled" | "expired"
export type MatchEngineState = "lifecycle" | "ban_phase" | "setup" | "turn_action" | "reaction_window" | "resolving" | "finished"

/** Exact public.matches columns consumed by the client. */
export interface MatchRow {
  id: string
  status: MatchStatus
  active_player_id: string | null
  winner_id: string | null
  current_turn: number
  state_version: number
  finish_reason: string | null
  turn_deadline: string | null
  initiative_result: { mode?: string; player1?: number; player2?: number; winner_user_id?: string } | null
  engine_state: MatchEngineState
}

/** Exact public.match_public_states row. */
export interface MatchPublicStateRow {
  match_id: string
  player1_user_id: string | null
  player2_user_id: string | null
  player1_username: string | null
  player2_username: string | null
  player1_avatar_url: string | null
  player2_avatar_url: string | null
  player1_hand_count: number
  player2_hand_count: number
  player1_deck_count: number
  player2_deck_count: number
  player1_graveyard_count: number
  player2_graveyard_count: number
  player1_life_remaining: number
  player2_life_remaining: number
  player1_mana_available: number
  player2_mana_available: number
  public_board: { cards: unknown[] }
  updated_at: string
}

/** Exact public.visible_match_cards view row. Null fields are RLS-redacted. */
export interface VisibleMatchCardRow {
  id: string
  match_id: string
  owner_user_id: string
  controller_user_id: string
  source_card_id: string
  card_name: string | null
  image_url: string | null
  rarity: string | null
  element?: string | null
  effect_mana_cost?: number | null
  effect_text?: string | null
  current_power: number | null
  maximum_power: number | null
  current_life: number | null
  maximum_life: number | null
  zone: MatchCardZone
  zone_position: number | null
  is_face_up: boolean
  is_destroyed: boolean
  has_attacked_this_turn: boolean
}

/** Presentation adapter derived only from VisibleMatchCardRow. */
export interface VisibleMatchCard extends VisibleMatchCardRow {
  card_id: string
  owner_id: string
  slot_index: number
  card_data: {
    id: string
    nome: string
    image_url?: string | null
    mana: number
    ataque: number
    vida: number
    elemento: "Bestiário" | "M&F" | "Witcher" | "Elfica" | "Cívil" | "Vampiro"
    tipo: string
    raridade: "common" | "rare" | "epic" | "legendary" | "collab"
    efeito: string
    effect_definition?: Array<{ effect_order?: number; trigger_type?: string; effect_code?: string; target_mode?: string; parameters?: Record<string, unknown>; is_reaction?: boolean }>
  } | null
  active_modifiers?: Array<{ id: string; modifier_type: string; power_delta: number; max_life_delta: number; current_life_delta: number; multiplier: number | null; is_permanent: boolean; metadata: Record<string, unknown> }>
}

export interface MatchState extends MatchRow, MatchPublicStateRow {
  current_player_id: string | null
  player1_id: string
  player2_id: string
  player1_mana: number
  player2_mana: number
  player1_max_mana: number
  player2_max_mana: number
  match_version: number
  turn_action_count?: number
}

/** Exact public.visible_match_actions row. */
export interface MatchAction {
  id: number
  match_id: string
  sequence_number: number
  actor_user_id: string | null
  action_type: string
  payload_public: Record<string, unknown>
  state_version_before: number
  state_version_after: number
  created_at: string
}

/** Exact public.pending_attacks row. */
export interface PendingAttack {
  id: string
  match_id: string
  attacker_user_id: string
  defender_user_id: string
  status: PendingAttackStatus
  is_direct: boolean
  declared_power: number
  resolved_power: number | null
  damage_remaining_after_resolution: number | null
  reaction_deadline: string
  reaction_completed_at: string | null
  resolved_at: string | null
  declared_state_version: number
  resolved_state_version: number | null
  result: Record<string, unknown>
  created_at: string
}

export interface BanCandidate {
  card_id: string
  name: string
  image_url: string
  rarity: string
  is_golden: boolean
  copy_count: number
}
