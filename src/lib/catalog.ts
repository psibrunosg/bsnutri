import { emptyNutrients, type NutrientKey, type Nutrients } from './nutrition'

export type CatalogKind = 'food' | 'preparation' | 'combination'
export type CatalogComponent = { foodId:string; grams:number }
export type CatalogImportRow = { name:string; preparationState:string; energyKcal:number; proteinG:number; carbohydrateG:number; fatG:number }

const importKey=(name:string,state:string)=>`${name.trim().toLocaleLowerCase('pt-BR')}|${state.trim().toLocaleLowerCase('pt-BR')}`

/** Lê a planilha colada no formato nome;preparo;energia_kcal;proteina_g;carboidrato_g;gordura_g. */
export function parseCatalogImport(text:string,existing:readonly {name:string;preparationState:string}[]=[]){
  const rows:CatalogImportRow[]=[]
  const errors:string[]=[]
  const seen=new Set(existing.map(item=>importKey(item.name,item.preparationState)))
  const lines=text.replace(/^\uFEFF/,'').split(/\r?\n/).map(line=>line.trim()).filter(Boolean)
  const start=lines[0]?.toLocaleLowerCase('pt-BR').startsWith('nome;')?1:0
  lines.slice(start).forEach((line,index)=>{
    const [rawName,rawState='unspecified',...rawValues]=line.split(';').map(value=>value.trim())
    const lineNumber=index+start+1
    const values=rawValues.map(value=>Number(value.replace(',','.')))
    if(!rawName||rawName.length<2||rawValues.length!==4||values.some(value=>!Number.isFinite(value)||value<0)){
      errors.push(`Linha ${lineNumber}: use nome;preparo;energia;proteína;carboidrato;gordura, com valores não negativos.`)
      return
    }
    const preparationState=rawState||'unspecified'
    const key=importKey(rawName,preparationState)
    if(seen.has(key)){errors.push(`Linha ${lineNumber}: ${rawName} (${preparationState}) já existe no catálogo ou na importação.`);return}
    seen.add(key)
    rows.push({name:rawName,preparationState,energyKcal:values[0],proteinG:values[1],carbohydrateG:values[2],fatG:values[3]})
  })
  return {rows,errors}
}

/** Caminhos são deliberadamente locais: renders curados permanecem versionados no GitHub. */
export function catalogRenderSrc(renderPath:string|undefined|null){
  if(!renderPath?.startsWith('/food-renders/')||!renderPath.endsWith('.webp'))return null
  return renderPath
}

export function foodRenderSrc(renderPath:string|undefined|null,name:string){
  return catalogRenderSrc(renderPath)??(name.toLocaleLowerCase('pt-BR').includes('peixe')?'/food-renders/peixe-grelhado-legumes.webp':null)
}

export function describeCatalogServing({servingGrams,householdMeasureLabel,householdMeasureGrams}:{servingGrams:number|null;householdMeasureLabel:string|null;householdMeasureGrams:number|null}){
  if(householdMeasureLabel&&householdMeasureGrams&&householdMeasureGrams>0)return `${householdMeasureLabel} · ${householdMeasureGrams} g`
  return servingGrams&&servingGrams>0?`${servingGrams} g · medida caseira não informada`:'Medida e porção não informadas'
}

export function deriveServingNutrients(nutrients:Nutrients,available:NutrientKey[],servingGrams:number|null){
  const serving=emptyNutrients()
  if(!servingGrams||servingGrams<=0)return serving
  for(const key of available)serving[key]=nutrients[key]*servingGrams/100
  return serving
}

export function normalizeCatalogText(value:string){
  return value.normalize('NFD').replace(/[\u0300-\u036f]/g,'').toLocaleLowerCase('pt-BR').trim()
}

export function matchesCatalogSearch(item:{name:string;preparationState:string;searchTerms:string[];culturalTags:string[];restrictionTags:string[];preferenceTags:string[];availabilityTags:string[]},query:string){
  const needle=normalizeCatalogText(query)
  if(!needle)return true
  return [item.name,item.preparationState,...item.searchTerms,...item.culturalTags,...item.restrictionTags,...item.preferenceTags,...item.availabilityTags].some(value=>normalizeCatalogText(value).includes(needle))
}

type NutrientComponent = {
  grams:number
  nutrients:Nutrients
  available:NutrientKey[]
}

export function deriveCatalogNutrients(components:NutrientComponent[],yieldGrams:number){
  const nutrients=emptyNutrients()
  if(!Number.isFinite(yieldGrams)||yieldGrams<=0)return {nutrients,available:[] as NutrientKey[]}
  const nutrientKeys=Object.keys(nutrients) as NutrientKey[]
  const available=nutrientKeys.filter(key=>components.length>0&&components.every(component=>component.available.includes(key)))
  for(const key of available)nutrients[key]=components.reduce((sum,component)=>sum+component.nutrients[key]*component.grams/100,0)*100/yieldGrams
  return {nutrients,available}
}
