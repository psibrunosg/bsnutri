import type { NutrientKey, Nutrients } from './nutrition'

export type NutrientRange = { min:number; target:number; max:number }
export type NutrientRanges = Partial<Record<NutrientKey,NutrientRange>>

export function normalizeRange(value:Partial<NutrientRange>):NutrientRange|null{
  const min=Number(value.min),target=Number(value.target),max=Number(value.max)
  return Number.isFinite(min)&&Number.isFinite(target)&&Number.isFinite(max)&&min>=0&&min<=target&&target<=max?{min,target,max}:null
}

export function rangeIssue(key:NutrientKey,actual:number,range:NutrientRange|undefined){
  if(!range)return null
  if(actual<range.min)return `${key}: ${actual} abaixo da faixa mínima (${range.min}).`
  if(actual>range.max)return `${key}: ${actual} acima da faixa máxima (${range.max}).`
  return null
}

export function getRangeIssues(actual:Nutrients,ranges:NutrientRanges){
  return (Object.keys(ranges) as NutrientKey[]).map(key=>rangeIssue(key,actual[key],ranges[key])).filter((issue):issue is string=>Boolean(issue))
}
