import { useCallback, useEffect, useState } from 'react'
import type { Session } from '@supabase/supabase-js'
import { supabase } from './lib/supabase'

type Draft={id:string;kind:'summary'|'guidance'|'plan_structure';body:string;status:'draft'|'approved'|'discarded';created_at:string}

function draftText(kind:Draft['kind'], facts:string){
  if(kind==='summary')return `Rascunho para revisão: ${facts}. Sintetizar a evolução relatada, os pontos de adesão e as pendências para o próximo encontro.`
  if(kind==='guidance')return `Rascunho para revisão: ${facts}. Propor uma orientação curta, prática e compatível com a rotina da pessoa.`
  return `Rascunho para revisão: ${facts}. Sugerir apenas a estrutura inicial do plano, a ser completada e validada antes de salvar.`
}

export function ClinicalDrafts({session,organizationId,patientId,facts}:{session:Session;organizationId:string;patientId:string;facts:string}){
  const [drafts,setDrafts]=useState<Draft[]>([]),[kind,setKind]=useState<Draft['kind']>('summary'),[message,setMessage]=useState('')
  const load=useCallback(async()=>{const {data,error}=await supabase.from('clinical_drafts').select('id,kind,body,status,created_at').eq('patient_id',patientId).order('created_at',{ascending:false});if(error)setMessage(error.message);else setDrafts((data??[]) as Draft[])},[patientId])
  useEffect(()=>{void load()},[load])
  async function create(){const {error}=await supabase.from('clinical_drafts').insert({organization_id:organizationId,patient_id:patientId,kind,body:draftText(kind,facts),source_snapshot:{facts},created_by:session.user.id});if(error)setMessage(error.message);else{setMessage('Rascunho criado. Revise antes de usar.');await load()}}
  async function review(id:string,status:'approved'|'discarded'){const {error}=await supabase.rpc('review_clinical_draft',{target_draft_id:id,target_status:status});if(error)setMessage(error.message);else{setMessage(status==='approved'?'Rascunho aprovado.':'Rascunho descartado.');await load()}}
  return <section className="panel clinical-drafts"><header><div><span className="eyebrow">Assistente de rascunhos</span><h2>Propostas revisáveis</h2></div><select aria-label="Tipo de rascunho" value={kind} onChange={event=>setKind(event.target.value as Draft['kind'])}><option value="summary">Resumo</option><option value="guidance">Orientação</option><option value="plan_structure">Estrutura de plano</option></select></header><p className="muted">Dados ficam no BSNutri. Nada é publicado ou enviado ao paciente automaticamente.</p><button className="secondary" onClick={()=>void create()}>Gerar rascunho</button>{message&&<p className="notice" role="status">{message}</p>}<div>{drafts.map(draft=><article key={draft.id}><small>{new Date(draft.created_at).toLocaleDateString('pt-BR')} · {draft.kind}</small><p>{draft.body}</p>{draft.status==='draft'?<div className="care-actions"><button className="secondary" onClick={()=>void review(draft.id,'discarded')}>Descartar</button><button className="primary" onClick={()=>void review(draft.id,'approved')}>Aprovar após revisão</button></div>:<strong>{draft.status==='approved'?'Aprovado':'Descartado'}</strong>}</article>)}</div></section>
}
