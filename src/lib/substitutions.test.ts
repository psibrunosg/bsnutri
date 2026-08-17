import { describe, expect, it } from 'vitest'
import { groupByMealItem, isPersistedMealItem, type PrescribedSubstitutionRow } from './substitutions'

function row(overrides: Partial<PrescribedSubstitutionRow> = {}): PrescribedSubstitutionRow {
  return {
    id: 'sub-1',
    meal_item_id: 'item-1',
    plan_version_id: 'version-1',
    description: 'Granola sem açúcar',
    grams: 30,
    unit: 'g',
    professional_note: null,
    is_active: true,
    ...overrides,
  }
}

describe('groupByMealItem', () => {
  it('agrupa as substituições pelo item do plano', () => {
    const grouped = groupByMealItem([
      row({ id: 'a', meal_item_id: 'item-1' }),
      row({ id: 'b', meal_item_id: 'item-1', description: 'Tapioca' }),
      row({ id: 'c', meal_item_id: 'item-2', description: 'Cuscuz' }),
    ])

    expect(grouped.get('item-1')?.map((item) => item.id)).toEqual(['a', 'b'])
    expect(grouped.get('item-2')?.map((item) => item.id)).toEqual(['c'])
    expect(grouped.get('item-3')).toBeUndefined()
  })

  it('devolve mapa vazio quando não há substituição', () => {
    expect(groupByMealItem([]).size).toBe(0)
  })
})

describe('isPersistedMealItem', () => {
  it('aceita o identificador de um item já gravado', () => {
    expect(isPersistedMealItem('3a88d92e-2611-4df7-a3fd-65017997ded3')).toBe(true)
  })

  it('recusa item que só existe no rascunho do navegador', () => {
    expect(isPersistedMealItem('item-1')).toBe(false)
    expect(isPersistedMealItem('')).toBe(false)
  })
})
