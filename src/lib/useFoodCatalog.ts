import { useCallback, useEffect, useState, type FormEvent } from 'react'
import { catalogRenderSrc, deriveCatalogNutrients, foodRenderSrc, type CatalogComponent, type CatalogKind } from './catalog'
import { emptyNutrients, type NutrientKey, type Nutrients } from './nutrition'
import { supabase } from './supabase'

export type FoodSource = { id:string; code:string; name:string; dataset_version:string }
export type FoodPreference = { food_id:string; is_favorite:boolean; last_used_at:string|null }
export type CatalogFood = { id: string; name: string; preparationState: string; catalogKind:CatalogKind; yieldGrams:number|null; servingGrams:number|null; portionCount:number|null; householdMeasureLabel:string|null; householdMeasureGrams:number|null; renderPath:string|null; searchTerms:string[]; culturalTags:string[]; restrictionTags:string[]; preferenceTags:string[]; availabilityTags:string[]; costBand:'low'|'medium'|'high'|null; sourceReference:string|null; sourceAccessedOn:string|null; sourceReliability:number|null; reviewStatus:string; reviewedAt:string|null; source:FoodSource|null; nutrients: Nutrients; availableNutrients:NutrientKey[]; components:CatalogComponent[] }

type NutrientRow = { id: string; code: string; name: string; unit: string }
type FoodRow = { id: string; name: string; preparation_state: string; catalog_kind?: CatalogKind; yield_grams?: number | null; serving_grams?: number | null; portion_count?:number|null; household_measure_label?:string|null; household_measure_grams?:number|null; render_path?: string | null; search_terms?:string[]|null; cultural_tags?:string[]|null; restriction_tags?:string[]|null; preference_tags?:string[]|null; availability_tags?:string[]|null; cost_band?:'low'|'medium'|'high'|null; source_reference?:string|null; source_accessed_on?:string|null; source_reliability?:number|null; review_status?:string|null; reviewed_at?:string|null; food_sources?:FoodSource|null; food_nutrient_values: { amount_per_100g: number; nutrients: NutrientRow | null }[] }
type ComponentRow = { parent_food_id:string; component_food_id:string; grams:number; position:number }

export const macroKeys: NutrientKey[] = ['energyKcal','proteinG','carbohydrateG','fatG']
export const macroLabels: Record<NutrientKey,string> = { energyKcal:'Energia',proteinG:'Proteína',carbohydrateG:'Carboidrato',fatG:'Gordura',fiberG:'Fibra',sodiumMg:'Sódio',calciumMg:'Cálcio',ironMg:'Ferro',potassiumMg:'Potássio',vitaminCMg:'Vitamina C' }

const aliases: Record<NutrientKey, string[]> = { energyKcal: ['energy_kcal','energy','kcal'], proteinG: ['protein_g','protein'], carbohydrateG: ['carbohydrate_g','carbohydrate','carbs'], fatG: ['fat_g','fat','lipids'], fiberG: ['fiber_g','fiber'], sodiumMg: ['sodium_mg','sodium'], calciumMg: ['calcium_mg','calcium'], ironMg: ['iron_mg','iron'], potassiumMg: ['potassium_mg','potassium'], vitaminCMg: ['vitamin_c_mg','vitamin_c'] }

function normalize(row: FoodRow,componentRows:ComponentRow[]=[]): CatalogFood {
  const nutrients=emptyNutrients()
  const availableNutrients:NutrientKey[]=[]
  for(const value of row.food_nutrient_values??[]){const code=value.nutrients?.code.toLowerCase();const key=(Object.keys(aliases) as NutrientKey[]).find(k=>code&&aliases[k].includes(code));if(key){nutrients[key]=Number(value.amount_per_100g);availableNutrients.push(key)}}
  return{id:row.id,name:row.name,preparationState:row.preparation_state,catalogKind:row.catalog_kind??'food',yieldGrams:row.yield_grams??null,servingGrams:row.serving_grams??null,portionCount:row.portion_count===null||row.portion_count===undefined?null:Number(row.portion_count),householdMeasureLabel:row.household_measure_label??null,householdMeasureGrams:row.household_measure_grams===null||row.household_measure_grams===undefined?null:Number(row.household_measure_grams),renderPath:foodRenderSrc(row.render_path,row.name),searchTerms:row.search_terms??[],culturalTags:row.cultural_tags??[],restrictionTags:row.restriction_tags??[],preferenceTags:row.preference_tags??[],availabilityTags:row.availability_tags??[],costBand:row.cost_band??null,sourceReference:row.source_reference??null,sourceAccessedOn:row.source_accessed_on??null,sourceReliability:row.source_reliability??null,reviewStatus:row.review_status??'pending_review',reviewedAt:row.reviewed_at??null,source:row.food_sources??null,nutrients,availableNutrients,components:componentRows.filter(component=>component.parent_food_id===row.id).sort((a,b)=>a.position-b.position).map(component=>({foodId:component.component_food_id,grams:Number(component.grams)}))}
}

/** Fetch, cadastro e preferências do catálogo próprio, isolados do editor de plano. */
export function useFoodCatalog(organizationId: string, userId: string, setMessage: (message: string) => void) {
  const [foods,setFoods]=useState<CatalogFood[]>([])
  const [nutrients,setNutrients]=useState<NutrientRow[]>([])
  const [sources,setSources]=useState<FoodSource[]>([])
  const [foodPreferences,setFoodPreferences]=useState<FoodPreference[]>([])
  const [busy,setBusy]=useState(false)

  const load=useCallback(async()=>{const [f,n,c,s,p]=await Promise.all([supabase.from('foods').select('id,name,preparation_state,catalog_kind,yield_grams,serving_grams,portion_count,household_measure_label,household_measure_grams,render_path,search_terms,cultural_tags,restriction_tags,preference_tags,availability_tags,cost_band,source_reference,source_accessed_on,source_reliability,review_status,reviewed_at,food_sources(id,code,name,dataset_version),food_nutrient_values(amount_per_100g,nutrients(id,code,name,unit))').or(`organization_id.is.null,organization_id.eq.${organizationId}`).eq('is_active',true).order('name'),supabase.from('nutrients').select('id,code,name,unit').order('sort_order'),supabase.from('food_components').select('parent_food_id,component_food_id,grams,position').eq('organization_id',organizationId).order('position'),supabase.from('food_sources').select('id,code,name,dataset_version').order('name'),supabase.from('food_user_preferences').select('food_id,is_favorite,last_used_at').eq('user_id',userId).order('last_used_at',{ascending:false})]);if(f.error||n.error||c.error||s.error||p.error)setMessage(f.error?.message??n.error?.message??c.error?.message??s.error?.message??p.error?.message??'Erro ao carregar catálogo.');else{const componentRows=(c.data??[]) as ComponentRow[];setFoods(((f.data??[]) as unknown as FoodRow[]).map(row=>normalize(row,componentRows)));setNutrients(n.data??[]);setSources((s.data??[]) as FoodSource[]);setFoodPreferences((p.data??[]) as FoodPreference[])}},[organizationId,userId,setMessage])
  useEffect(()=>{void load()},[load])

  async function saveFoodPreference(foodId:string,change:Partial<Pick<FoodPreference,'is_favorite'|'last_used_at'>>){const current=foodPreferences.find(item=>item.food_id===foodId);const next={food_id:foodId,is_favorite:change.is_favorite??current?.is_favorite??false,last_used_at:change.last_used_at??current?.last_used_at??null};setFoodPreferences(all=>[...all.filter(item=>item.food_id!==foodId),next]);const {error}=await supabase.from('food_user_preferences').upsert({user_id:userId,...next},{onConflict:'user_id,food_id'});if(error){setFoodPreferences(all=>current?[...all.filter(item=>item.food_id!==foodId),current]:all.filter(item=>item.food_id!==foodId));setMessage(`Preferência não salva: ${error.message}`)}}

  async function addFood(event:FormEvent<HTMLFormElement>){
    event.preventDefault();setBusy(true);setMessage('')
    const form=event.currentTarget,data=new FormData(form),catalogKind=String(data.get('catalogKind')||'food') as CatalogKind
    const components=foods.map(food=>({food,grams:Number(String(data.get(`component-${food.id}`)||0).replace(',','.'))})).filter(item=>item.grams>0)
    const yieldGrams=Number(String(data.get('yieldGrams')||0).replace(',','.')),portionCount=Number(String(data.get('portionCount')||0).replace(',','.')),householdMeasureGrams=Number(String(data.get('householdMeasureGrams')||0).replace(',','.')),householdMeasureLabel=String(data.get('householdMeasureLabel')||'').trim()
    const manualValues=Object.fromEntries(macroKeys.map(key=>[key,Number(String(data.get(key)||0).replace(',','.'))])) as Record<NutrientKey,number>
    if(catalogKind==='food'&&macroKeys.some(key=>!Number.isFinite(manualValues[key])||manualValues[key]<0)){setBusy(false);return setMessage('Informe valores válidos e não negativos.')}
    if(catalogKind!=='food'&&(!components.length||!Number.isFinite(yieldGrams)||yieldGrams<=0||!Number.isFinite(portionCount)||portionCount<=0)){setBusy(false);return setMessage('Adicione componentes, rendimento e número de porções válidos.')}
    if((householdMeasureLabel&&(!Number.isFinite(householdMeasureGrams)||householdMeasureGrams<=0))||(!householdMeasureLabel&&householdMeasureGrams>0)){setBusy(false);return setMessage('Informe nome e peso positivo da medida caseira, ou deixe ambos vazios.')}
    const derived=catalogKind==='food'?{nutrients:manualValues,available:macroKeys}:deriveCatalogNutrients(components.map(({food,grams})=>({grams,nutrients:food.nutrients,available:food.availableNutrients})),yieldGrams)
    const renderPath=catalogRenderSrc(String(data.get('renderPath')||'')),tags=(name:string)=>String(data.get(name)||'').split(',').map(item=>item.trim()).filter(Boolean)
    const sourceReliability=Number(String(data.get('sourceReliability')||0)),reviewed=data.get('reviewed')==='on'
    const result=await supabase.from('foods').insert({organization_id:organizationId,source_id:String(data.get('sourceId')||'')||null,source_reference:String(data.get('sourceReference')||'').trim()||null,source_accessed_on:String(data.get('sourceAccessedOn')||'')||null,source_reliability:Number.isInteger(sourceReliability)&&sourceReliability>0?sourceReliability:null,review_status:reviewed?'reviewed':'pending_review',reviewed_by:reviewed?userId:null,name:String(data.get('name')).trim(),preparation_state:String(data.get('state')).trim()||'unspecified',search_terms:tags('searchTerms'),cultural_tags:tags('culturalTags'),restriction_tags:tags('restrictionTags'),preference_tags:tags('preferenceTags'),availability_tags:tags('availabilityTags'),cost_band:String(data.get('costBand')||'')||null,catalog_kind:catalogKind,yield_grams:catalogKind==='food'?null:yieldGrams,serving_grams:catalogKind==='food'?null:yieldGrams/portionCount,portion_count:catalogKind==='food'?null:portionCount,household_measure_label:householdMeasureLabel||null,household_measure_grams:householdMeasureLabel?householdMeasureGrams:null,render_path:renderPath,created_by:userId}).select('id').single()
    if(result.error||!result.data){setBusy(false);return setMessage(result.error?.message??'Falha no cadastro.')}
    const mapped=derived.available.map(key=>({key,nutrient:nutrients.find(n=>aliases[key].includes(n.code.toLowerCase()))})).filter(item=>item.nutrient)
    const valuesResult=mapped.length?await supabase.from('food_nutrient_values').insert(mapped.map(item=>({food_id:result.data.id,nutrient_id:item.nutrient!.id,amount_per_100g:derived.nutrients[item.key],data_version:'custom-v1'}))):{error:null}
    const componentsResult=catalogKind!=='food'?await supabase.from('food_components').insert(components.map(({food,grams},position)=>({organization_id:organizationId,parent_food_id:result.data.id,component_food_id:food.id,grams,position}))):{error:null}
    if(valuesResult.error||componentsResult.error){await supabase.from('foods').update({is_active:false}).eq('id',result.data.id);setMessage(`Cadastro revertido: ${valuesResult.error?.message??componentsResult.error?.message}`)}
    else{form.reset();await load();setMessage(catalogKind==='food'?'Alimento cadastrado.':catalogKind==='preparation'?'Preparação cadastrada.':'Combinação cadastrada.')}
    setBusy(false)
  }

  return {foods, sources, foodPreferences, busy, addFood, saveFoodPreference, load}
}
