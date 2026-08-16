import type { EditorDay } from './planDrafts'
import { totalDay, type NutrientKey } from './nutrition'

const portions=(days:EditorDay[])=>days.flatMap(day=>day.meals.flatMap(meal=>meal.items.map(item=>({id:item.id,name:`${day.label} · ${meal.name} · ${item.name}`,grams:item.grams}))))
const nutrients:[NutrientKey,string,string][]=[['energyKcal','Energia','kcal'],['proteinG','Proteína','g'],['carbohydrateG','Carboidrato','g'],['fatG','Gordura','g'],['fiberG','Fibra','g']]

export function comparePlanDays(previous:EditorDay[],current:EditorDay[]){
  const before=new Map(portions(previous).map(item=>[item.id,item]))
  const after=new Map(portions(current).map(item=>[item.id,item]))
  const ids=new Set([...before.keys(),...after.keys()])
  return [...ids].flatMap(id=>{const oldItem=before.get(id),newItem=after.get(id),name=newItem?.name??oldItem?.name??'';const oldGrams=oldItem?.grams,newGrams=newItem?.grams;if(oldGrams===newGrams)return [];if(oldGrams===undefined)return [`Adicionado: ${name} (${newGrams} g).`];if(newGrams===undefined)return [`Removido: ${name} (${oldGrams} g).`];return [`Alterado: ${name}, ${oldGrams} g para ${newGrams} g.`]})
}

export function comparePlanNutrition(previous:EditorDay[],current:EditorDay[]){
  const before=previous.reduce((sum,day)=>{const total=totalDay(day.meals);for(const key of Object.keys(sum) as NutrientKey[])sum[key]+=total[key]??0;return sum},totalDay([]))
  const after=current.reduce((sum,day)=>{const total=totalDay(day.meals);for(const key of Object.keys(sum) as NutrientKey[])sum[key]+=total[key]??0;return sum},totalDay([]))
  return nutrients.flatMap(([key,label,unit])=>{const delta=Math.round(((after[key]??0)-(before[key]??0))*10)/10;return delta? [`${label}: ${delta>0?'+':''}${delta} ${unit}.`]:[]})
}
