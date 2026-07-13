import { useCallback, useEffect, useState } from 'react'
import { LogOut, RefreshCw, Utensils } from 'lucide-react'
import { supabase } from './lib/supabase'

type PatientAccess = { id:string; full_name:string; anonymous_code:string }
type SnapshotNutrient = { code:string; unit:string; amount:number }
type PortalItem = { id:string; description:string; grams:number; nutrient_snapshot:{food_name?:string;preparation_state?:string;nutrients?:SnapshotNutrient[]} | null }
type PortalMeal = { id:string;label:string;position:number;suggested_time:string|null;meal_items:PortalItem[] }
type PortalDay = { id:string;label:string;day_index:number;meals:PortalMeal[] }
type PortalVersion = { id:string;version_no:number;targets:Record<string,number>;plan_days:PortalDay[] }
type PortalPlan = { id:string;title:string;published_at:string|null;plan_versions:PortalVersion|null }

export function PatientPortal({patient}:{patient:PatientAccess}){
  const [plans,setPlans]=useState<PortalPlan[]>([]),[loading,setLoading]=useState(true),[error,setError]=useState('')
  const load=useCallback(async()=>{setLoading(true);setError('');const result=await supabase.from('plans').select('id,title,published_at,plan_versions!plans_current_version_tenant_fkey(id,version_no,targets,plan_days(id,label,day_index,meals(id,label,position,suggested_time,meal_items(id,description,grams,nutrient_snapshot))))').eq('patient_id',patient.id).in('status',['published','scheduled']).order('published_at',{ascending:false});if(result.error)setError(`Não foi possível carregar seu plano: ${result.error.message}`);else setPlans((result.data??[]) as unknown as PortalPlan[]);setLoading(false)},[patient.id])
  useEffect(()=>{void load()},[load])
  return <main className="patient-portal"><header><div className="brand"><span>BS</span><div><strong>BSNutri</strong><small>Meu plano alimentar</small></div></div><button className="secondary" onClick={()=>supabase.auth.signOut()}><LogOut/>Sair</button></header><section className="portal-hero"><small>{patient.anonymous_code}</small><h1>Olá, {patient.full_name.split(' ')[0]}</h1><p>Seu plano publicado está disponível aqui para consulta.</p></section>{error&&<div className="notice error" role="alert">{error}</div>}{loading?<div className="portal-empty">Carregando plano...</div>:plans.length?<div className="portal-plans">{plans.map(plan=><PortalPlanCard key={plan.id} plan={plan}/>)}</div>:<div className="portal-empty"><Utensils/><h2>Nenhum plano publicado</h2><p>Quando o profissional publicar seu plano, ele aparecerá aqui.</p><button className="secondary" onClick={()=>void load()}><RefreshCw/>Atualizar</button></div>}</main>
}

function PortalPlanCard({plan}:{plan:PortalPlan}){const version=plan.plan_versions;return <article className="portal-plan"><header><div><small>Plano vigente</small><h2>{plan.title}</h2></div>{plan.published_at&&<time>Publicado em {new Date(plan.published_at).toLocaleDateString('pt-BR')}</time>}</header>{version?.plan_days?.sort((a,b)=>a.day_index-b.day_index).map(day=><section className="portal-day" key={day.id}><h3>{day.label}</h3>{day.meals.sort((a,b)=>a.position-b.position).map(meal=><article className="portal-meal" key={meal.id}><div><h4>{meal.label}</h4>{meal.suggested_time&&<time>{meal.suggested_time.slice(0,5)}</time>}</div><ul>{meal.meal_items.map(item=><li key={item.id}><span><strong>{item.nutrient_snapshot?.food_name??item.description}</strong>{item.nutrient_snapshot?.preparation_state&&<small>{item.nutrient_snapshot.preparation_state}</small>}</span><b>{Number(item.grams).toLocaleString('pt-BR')} g</b></li>)}</ul></article>)}</section>)}</article>}
