export type SubstitutionCandidate = {
  id: string
  name: string
  nutrients: Partial<Record<'energyKcal'|'proteinG'|'carbohydrateG'|'fatG'|'fiberG',number>>
  tags?: string[]
  costBand?: 'low'|'medium'|'high'|null
  preparationMinutes?: number | null
}

export type SubstitutionCriteria = {
  reference: SubstitutionCandidate
  excludedTags?: string[]
  preferredTags?: string[]
  maxCost?: 'low'|'medium'|'high'
  maxPreparationMinutes?: number
  weights?: Partial<Record<'energyKcal'|'proteinG'|'carbohydrateG'|'fatG'|'fiberG',number>>
  toleranceFraction?: number
}

export type RankedSubstitution = SubstitutionCandidate & { score:number; reasons:string[] }

const costRank={low:0,medium:1,high:2} as const
const macros:['energyKcal'|'proteinG'|'carbohydrateG'|'fatG'|'fiberG',string][]=[['energyKcal','energia próxima'],['proteinG','proteína próxima'],['carbohydrateG','carboidrato próximo'],['fatG','gordura próxima'],['fiberG','fibra próxima']]

export function rankSubstitutions(candidates:SubstitutionCandidate[],criteria:SubstitutionCriteria):RankedSubstitution[]{
  const excluded=new Set(criteria.excludedTags??[]),preferred=new Set(criteria.preferredTags??[])
  return candidates.flatMap(candidate=>{
    if(candidate.id===criteria.reference.id)return []
    const tags=new Set(candidate.tags??[])
    if([...excluded].some(tag=>tags.has(tag)))return []
    if(criteria.maxCost&&candidate.costBand&&costRank[candidate.costBand]>costRank[criteria.maxCost])return []
    if(criteria.maxPreparationMinutes!==undefined&&candidate.preparationMinutes!==null&&candidate.preparationMinutes!==undefined&&candidate.preparationMinutes>criteria.maxPreparationMinutes)return []
    const matching=[...preferred].filter(tag=>tags.has(tag)),reasons:string[]=matching.length?[`preferência: ${matching.join(', ')}`]:[]
    let score=matching.length?-matching.length*25:0
    for(const [key,label] of macros){const reference=criteria.reference.nutrients[key]??0,value=candidate.nutrients[key]??0;const difference=Math.abs(value-reference),tolerance=Math.max(1,reference*(criteria.toleranceFraction??.1));score+=difference*(criteria.weights?.[key]??1);if(difference<=tolerance)reasons.push(label)}
    if(candidate.costBand==='low'){score-=3;reasons.push('baixo custo')}
    if(candidate.preparationMinutes!==null&&candidate.preparationMinutes!==undefined&&candidate.preparationMinutes<=15){score-=2;reasons.push('preparo rápido')}
    return [{...candidate,score:Math.round(score*100)/100,reasons:reasons.slice(0,3)}]
  }).sort((a,b)=>a.score-b.score||a.name.localeCompare(b.name,'pt-BR'))
}
