import { describe, expect, it } from 'vitest'
import { emptyNutrients } from './nutrition'
import { getRangeIssues, normalizeRange } from './planRanges'

describe('plan ranges',()=>{
  it('aceita faixa ordenada e explica desvio',()=>{
    expect(normalizeRange({min:1800,target:2000,max:2200})).toEqual({min:1800,target:2000,max:2200})
    expect(normalizeRange({min:2200,target:2000,max:1800})).toBeNull()
    expect(getRangeIssues({...emptyNutrients(),energyKcal:1750},{energyKcal:{min:1800,target:2000,max:2200}})).toEqual(['energyKcal: 1750 abaixo da faixa mínima (1800).'])
  })
})
