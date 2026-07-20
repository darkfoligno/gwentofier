export type SandboxKind="combat_destroy"|"life_history"|"deck_synergy"|"death_reaction"|"manual"|"attack"|"passive"

export type SandboxEffectMeta={
  effect_order:number
  effect_code:string
  trigger_type:string
  target_mode:string
  parameters:Record<string,unknown>
  is_reaction:boolean
}

export type SandboxCardMeta={
  id:string;code:string;name:string;image_url:string|null;element:string;rarity:string
  power:number;max_life:number;mana_cost:number;effect_text:string;effect:SandboxEffectMeta
}

export type SandboxUnit={id:string;name:string;zone:string;power:number;life:number;max_life:number;rarity:string;face_up?:boolean}
export type SandboxState={
  audited_card:SandboxUnit
  practice_dummy:SandboxUnit|null
  enemy_life:SandboxUnit[]
  player_deck:SandboxUnit[]
  enemy_deck:SandboxUnit[]
  player_graveyard:SandboxUnit[]
  enemy_graveyard:SandboxUnit[]
  player_hand_count:number
  mana_available:number
  current_turn:number
  metadata:Record<string,unknown>
}

export type SandboxScenario={
  test_id:string;kind:SandboxKind;action_type:"activate_effect"|"declare_attack"|"resolve_trigger"|"observe_passive"
  interaction_phase:"WAITING_USER_INPUT";objective:string;card:SandboxCardMeta;before:SandboxState;status:"ready"
}

const deathTriggers=new Set(["on_destroyed","reaction","on_reaction","on_attacked","on_damage_received"])

export function interpretSandboxScenario(card:SandboxCardMeta):SandboxKind{
  const {effect}=card,code=effect.effect_code,params=effect.parameters??{}
  if(code==="common_guillaume_destroy_deck"||Boolean(params.destroyed_alone))return"combat_destroy"
  if(code==="common_gerd_double_life"||params.required_zone==="life"||params.opponent_ever_passed)return"life_history"
  if(code==="common_harpy_absorb_and_attack"||params.deck_name||params.names||params.target_name||effect.target_mode==="deck")return"deck_synergy"
  if(deathTriggers.has(effect.trigger_type)||effect.is_reaction)return"death_reaction"
  if(effect.trigger_type==="manual")return"manual"
  if(effect.trigger_type.startsWith("on_attack"))return"attack"
  return"passive"
}

export function scenarioInstruction(scenario:SandboxScenario){
  const name=scenario.card.name
  if(scenario.kind==="combat_destroy")return`Declare o ataque de ${name} contra o Boneco de Prática.`
  if(scenario.kind==="life_history")return`Abra Encerrar Turno / Conjurações e arraste ${name} para a Zona de Efeito Pago.`
  if(scenario.kind==="deck_synergy")return`Arraste ${name} para a Zona de Efeito Pago e confirme a conjuração.`
  if(scenario.kind==="death_reaction")return`Responda SIM ou NÃO ao gatilho provocado pelo ataque do Autômato.`
  if(scenario.action_type==="declare_attack")return`Declare o ataque de ${name} contra o alvo preparado.`
  return`Ative manualmente a mecânica de ${name} na mesa.`
}
