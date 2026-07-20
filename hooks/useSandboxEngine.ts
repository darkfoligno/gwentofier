"use client"

import {useCallback,useReducer,useState} from "react"
import {supabase} from "@/lib/supabase"
import {interpretSandboxScenario,type SandboxScenario,type SandboxState} from "@/lib/sandbox-scenario"

export type SandboxResult={success:boolean;approved:boolean;status:string;effect_code:string;message:string;before:SandboxState;after:SandboxState;proof:Record<string,unknown>;reason?:string;http_status?:number;state_mutated?:boolean}
type Phase="catalog"|"waiting"|"resolving"|"impact"|"finished"
type State={scenario:SandboxScenario|null;result:SandboxResult|null;board:SandboxState|null;phase:Phase;dump:string[];events:string[]}
type Event={type:"reset"}|{type:"scenario";scenario:SandboxScenario;dump:string}|{type:"resolving";dump:string}|{type:"impact";result:SandboxResult;dump:string}|{type:"finished"}|{type:"error";dump:string;message:string}
const initial:State={scenario:null,result:null,board:null,phase:"catalog",dump:[],events:[]}
const log=(label:string,value:unknown)=>`[${new Date().toISOString()}] ${label}\n${JSON.stringify(value,null,2)}`
function reducer(state:State,event:Event):State{switch(event.type){case"reset":return initial;case"scenario":return{scenario:event.scenario,result:null,board:event.scenario.before,phase:"waiting",dump:[event.dump],events:["scenario","waiting_user_input"]};case"resolving":return{...state,phase:"resolving",dump:[...state.dump,event.dump],events:[...state.events,"command"]};case"impact":return{...state,result:event.result,board:event.result.after??state.board,phase:"impact",dump:[...state.dump,event.dump],events:[...state.events,"impact"]};case"finished":return{...state,phase:"finished",events:[...state.events,"finished"]};case"error":return{...state,phase:"finished",dump:[...state.dump,event.dump],events:[...state.events,event.message]}}}
const cinematic=(ms:number)=>new Promise<void>(resolve=>window.setTimeout(resolve,ms))

export function useSandboxEngine(){
  const[state,dispatch]=useReducer(reducer,initial);const[busy,setBusy]=useState(false)
  const failure=useCallback((operation:string,error:unknown,payload:unknown)=>{const issue=error as{message?:string;details?:string;hint?:string;code?:string};const stack=error instanceof Error?error.stack:new Error(issue?.message??String(error)).stack;dispatch({type:"error",message:issue?.message??"Falha SQL",dump:log(`${operation} · PAYLOAD`,payload)+"\n"+log(`${operation} · ERRO HTTP/SQL`,{...issue,stack})})},[])
  const conjure=useCallback(async(cardCode:string)=>{if(busy)return false;setBusy(true);dispatch({type:"reset"});const payload={p_card_id:cardCode};try{const{data,error}=await supabase.rpc("create_lab_sie_scenario",payload);if(error)throw error;const scenario=data as SandboxScenario;if(!scenario?.test_id)throw new Error(JSON.stringify(data));const interpreted=interpretSandboxScenario(scenario.card);if(interpreted!==scenario.kind)throw new Error(`SIE_CLASSIFICATION_DIVERGENCE: client=${interpreted}, sql=${scenario.kind}`);dispatch({type:"scenario",scenario,dump:log("RPC create_lab_sie_scenario · PAYLOAD",payload)+"\n"+log("SIE · CENÁRIO INTERPRETADO",scenario)});return true}catch(error){failure("create_lab_sie_scenario",error,payload);return false}finally{setBusy(false)}},[busy,failure])
  const execute=useCallback(async(accept=true)=>{if(!state.scenario||state.phase!=="waiting"||busy)return;setBusy(true);const payload={p_test_id:state.scenario.test_id,p_action:{type:state.scenario.action_type,accept,source_card_id:state.scenario.card.id,target:state.scenario.kind==="deck_synergy"?"enemy-life-far":"practice-dummy",manual_user_input:true}};dispatch({type:"resolving",dump:log("RPC execute_lab_sie_action · PAYLOAD",payload)});try{const{data,error}=await supabase.rpc("execute_lab_sie_action",payload);if(error)throw error;const result=data as SandboxResult;if(!result.success)throw new Error(result.reason??"SIE_ACTION_FAILED");dispatch({type:"impact",result,dump:log(`RPC execute_lab_sie_action · RETORNO HTTP ${result.http_status??200}`,result)});await cinematic(state.scenario.card.effect.effect_code==="common_harpy_absorb_and_attack"?2000:2500);dispatch({type:"finished"})}catch(error){failure("execute_lab_sie_action",error,payload)}finally{setBusy(false)}},[busy,failure,state.phase,state.scenario])
  return{...state,busy,dump:state.dump.join("\n\n"),conjure,execute,reset:()=>dispatch({type:"reset"})}
}
