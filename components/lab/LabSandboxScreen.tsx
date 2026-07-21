"use client"

import {useEffect,useMemo,useState} from "react"
import {motion} from "framer-motion"
import {Beaker,CheckCircle2,ChevronLeft,Loader2,Search,ShieldCheck,Sparkles} from "lucide-react"
import {GameCard} from "@/components/game/game-card"
import {supabase} from "@/lib/supabase"
import type {GameCard as GameCardType,OfficialCardType,Rarity} from "@/lib/game-data"
import {getLabCardScenario,LAB_SCENARIO_COUNT} from "@/lib/lab-card-scenarios"
import type {Screen} from "@/lib/types"

type CatalogCard={id:string;code:string;name:string;image_url:string|null;element:OfficialCardType;rarity:Rarity;card_type:string;base_power:number;base_max_life:number;effect_mana_cost:number;effect_text:string|null}

const cardView=(card:CatalogCard):GameCardType=>({id:card.id,nome:card.name,image_url:card.image_url,elemento:card.element,raridade:card.rarity,tipo:card.element,mana:card.effect_mana_cost,ataque:card.base_power,vida:card.base_max_life,efeito:card.effect_text??""})

export function LabSandboxScreen({onEnter}:{onEnter:(screen:Screen)=>void}){
  const[cards,setCards]=useState<CatalogCard[]>([])
  const[query,setQuery]=useState("")
  const[selected,setSelected]=useState<CatalogCard|null>(null)
  const[busy,setBusy]=useState(false)
  const[message,setMessage]=useState("")

  useEffect(()=>{void supabase.from("cards").select("id,code,name,image_url,element,rarity,card_type,base_power,base_max_life,effect_mana_cost,effect_text").eq("is_active",true).like("code","COMMON_%").order("code").then(({data,error})=>{if(error)setMessage(error.message);else setCards((data??[])as CatalogCard[])})},[])
  const filtered=useMemo(()=>{const term=query.trim().toLocaleLowerCase("pt-BR");return cards.filter(card=>!term||card.name.toLocaleLowerCase("pt-BR").includes(term)||card.code.toLowerCase().includes(term))},[cards,query])
  const contract=selected?getLabCardScenario(selected.code):null

  const start=async()=>{
    if(!selected||!contract||busy)return
    setBusy(true);setMessage("")
    try{
      const{data,error}=await supabase.rpc("setup_sandbox_match",{p_card_id:selected.code})
      if(error)throw error
      const result=data as{success?:boolean;match_id?:string;reason?:string;error_code?:string;action_type?:string}
      if(!result.success||!result.match_id)throw new Error([result.reason,result.error_code].filter(Boolean).join(" · ")||"O cenário individual não pôde ser criado.")
      const url=new URL(window.location.href)
      url.searchParams.set("screen","arena");url.searchParams.set("matchId",result.match_id);url.searchParams.set("sandbox","1")
      url.searchParams.set("sandboxCard",selected.code);url.searchParams.set("sandboxAction",result.action_type??contract.action);url.searchParams.set("objective",contract.instruction)
      url.searchParams.set("sandboxSetup",JSON.stringify(contract.setup));url.searchParams.set("sandboxExpected",JSON.stringify(contract.expected));url.searchParams.set("sandboxVisual",JSON.stringify(contract.visual))
      window.location.assign(url.toString())
    }catch(error){setMessage(error instanceof Error?error.message:String(error));setBusy(false)}
  }

  return <main className="relative min-h-screen overflow-hidden bg-[url('/yang-69TcSUVhbmY-unsplash.jpg')] bg-cover bg-center px-4 pb-10 pt-20 text-stone-100">
    <div className="absolute inset-0 bg-[radial-gradient(circle_at_top,rgba(88,28,135,.7),rgba(0,0,0,.93)_64%)]"/>
    <div className="relative z-10 mx-auto max-w-[1500px]">
      <header className="flex flex-wrap items-center justify-between gap-3 rounded-2xl border border-purple-300/50 bg-black/75 p-4 shadow-[0_0_45px_rgba(168,85,247,.18)]">
        <button onClick={()=>onEnter("hub")} className="rounded-lg border border-stone-600 bg-stone-950 px-3 py-2 text-xs font-black"><ChevronLeft className="mr-1 inline" size={15}/>VOLTAR</button>
        <div className="text-center"><p className="text-[10px] font-black uppercase tracking-[.25em] text-purple-200">Laboratório autoritativo</p><h1 className="font-serif text-2xl font-black text-amber-100">Grimório de Simulação Tática</h1><p className="text-xs text-stone-300">{LAB_SCENARIO_COUNT}/72 contratos individuais · uma partida real de turno único por carta</p></div>
        <div className="rounded-lg border border-emerald-400/50 bg-emerald-950/70 px-3 py-2 text-[10px] font-black text-emerald-100"><ShieldCheck className="mr-1 inline" size={15}/>MESMO MOTOR DA ARENA</div>
      </header>
      <div className="mt-4 grid gap-4 lg:grid-cols-[1fr_390px]">
        <section className="rounded-2xl border border-purple-500/35 bg-black/70 p-4">
          <div className="relative"><Search className="absolute left-3 top-1/2 -translate-y-1/2 text-purple-300" size={18}/><input value={query} onChange={event=>setQuery(event.target.value)} placeholder="Buscar por número, código ou nome…" className="w-full rounded-xl border border-purple-300/50 bg-stone-950 py-3 pl-10 pr-3 text-sm outline-none focus:border-amber-300"/></div>
          <div className="mt-4 grid max-h-[calc(100vh-220px)] grid-cols-2 gap-3 overflow-y-auto pr-1 sm:grid-cols-3 md:grid-cols-4 xl:grid-cols-6">
            {filtered.map(card=><button key={card.id} onClick={()=>{setSelected(card);setMessage("")}} className={`rounded-xl border-2 p-2 text-left transition ${selected?.id===card.id?"border-emerald-300 bg-emerald-950/50 ring-2 ring-emerald-300/50":"border-purple-900/70 bg-black/45 hover:border-purple-300"}`}><div className="aspect-[2/3]"><GameCard card={cardView(card)}/></div><b className="mt-2 block text-[9px] text-amber-100">{card.code} · {card.name}</b></button>)}
          </div>
        </section>
        <aside className="self-start rounded-2xl border-2 border-amber-500/45 bg-stone-950/95 p-5 lg:sticky lg:top-20">
          {!selected||!contract?<div className="py-16 text-center text-stone-400"><Beaker className="mx-auto mb-3" size={36}/><p>Escolha uma carta. O cenário, a ação e a prova exigida aparecerão aqui.</p></div>:<motion.div key={selected.id} initial={{opacity:0,x:12}} animate={{opacity:1,x:0}}>
            <p className="text-[10px] font-black uppercase tracking-widest text-purple-300">{selected.code} · {contract.effectCode}</p><h2 className="mt-1 font-serif text-2xl font-black text-amber-100">{selected.name}</h2>
            <p className="mt-3 rounded-lg border border-amber-600/40 bg-amber-950/35 p-3 text-xs leading-relaxed text-amber-50"><b>Objetivo:</b> {contract.instruction}</p>
            <div className="mt-4 space-y-4 text-xs"><div><b className="text-cyan-200">CENÁRIO EXCLUSIVO</b>{contract.setup.map(item=><p key={item} className="mt-1 text-stone-300">• {item}</p>)}</div><div><b className="text-fuchsia-200">TUTORIAL VISUAL</b>{contract.visual.map((item,index)=><p key={item} className="mt-1 text-stone-300">{index+1}. {item}</p>)}</div><div><b className="text-emerald-200">PROVAS OBRIGATÓRIAS</b>{contract.expected.map(item=><p key={item} className="mt-1 text-stone-300"><CheckCircle2 className="mr-1 inline text-emerald-400" size={12}/>{item}</p>)}</div></div>
            <button disabled={busy} onClick={()=>void start()} className="mt-5 w-full rounded-xl border-2 border-emerald-200 bg-gradient-to-r from-emerald-950 via-emerald-600 to-emerald-950 px-5 py-4 font-serif text-sm font-black uppercase text-white shadow-[0_0_25px_rgba(52,211,153,.25)] disabled:opacity-40">{busy?<Loader2 className="mr-2 inline animate-spin"/>:<Sparkles className="mr-2 inline"/>}CRIAR PARTIDA DE TESTE</button>
          </motion.div>}
          {message&&<p className="mt-4 rounded-lg border border-red-400 bg-red-950/80 p-3 text-xs text-red-100">{message}</p>}
        </aside>
      </div>
    </div>
  </main>
}
