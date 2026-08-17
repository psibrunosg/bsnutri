import { describe, expect, it } from 'vitest'
import { standardMeals } from './usePlanDraft'
import {
  bucketListsByDietboxGroup,
  buildMergedDaysPayload,
  classifyDietboxMacroGroup,
  groupNoFromTitle,
} from './dietboxImportWrite'

describe('buildMergedDaysPayload', () => {
  it('replaces only the target day, keeping the rest of the week untouched', () => {
    const days = [
      { id: 'd0', label: 'Segunda-feira', kind: 'standard', meals: standardMeals() },
      { id: 'd1', label: 'Terça-feira', kind: 'standard', meals: standardMeals() },
    ]
    const imported = { id: 'd0', label: 'Segunda-feira', kind: 'standard', meals: [] as never[] }
    const merged = buildMergedDaysPayload(days, 0, imported)
    expect(merged[0]).toBe(imported)
    expect(merged[1]).toBe(days[1])
    expect(merged).toHaveLength(2)
  })
})

describe('groupNoFromTitle', () => {
  it('reads the dietbox group number from a title built by the importer', () => {
    expect(groupNoFromTitle('Grupo 4: Carnes e Proteínas')).toBe(4)
  })

  it('returns null for a title with no group number', () => {
    expect(groupNoFromTitle('Grupo dos Carboidratos Complexos (~100 kcal)')).toBeNull()
  })
})

describe('bucketListsByDietboxGroup', () => {
  it('groups lists by their dietbox group number, ignoring unrelated ones', () => {
    const rows = [
      { id: 'a', title: 'Grupo 4: Carnes e Proteínas' },
      { id: 'b', title: 'Grupo 4: Proteínas (outra versão)' },
      { id: 'c', title: 'Grupo 9: Frutas' },
      { id: 'd', title: 'Sem número nenhum' },
    ]
    const map = bucketListsByDietboxGroup(rows, [4, 9])
    expect(map.get(4)?.map((r) => r.id)).toEqual(['a', 'b'])
    expect(map.get(9)?.map((r) => r.id)).toEqual(['c'])
  })
})

describe('classifyDietboxMacroGroup', () => {
  it('recognizes protein-leaning titles', () => {
    expect(classifyDietboxMacroGroup('Carnes e Proteínas')).toBe('protein')
  })

  it('recognizes fruit-leaning titles', () => {
    expect(classifyDietboxMacroGroup('Frutas')).toBe('fruit')
  })

  it('falls back to other when nothing matches', () => {
    expect(classifyDietboxMacroGroup('Bebidas')).toBe('other')
  })
})
