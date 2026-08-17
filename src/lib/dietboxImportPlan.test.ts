import { describe, expect, it } from 'vitest'
import type { CatalogFoodSummary } from './catalogSearch'
import { buildImportedDay } from './dietboxImportPlan'
import type { ParsedDietboxMeal } from './dietboxImport'
import type { EditorDay } from './planDrafts'

function food(id: string, name: string): CatalogFoodSummary {
  return {
    id,
    name,
    preparationState: 'raw',
    isOwn: false,
    householdMeasureLabel: null,
    householdMeasureGrams: null,
    sourceName: 'TACO',
    nutrients: { energyKcal: 100 },
  }
}

function baseDay(): EditorDay {
  return { id: 'day-0', label: 'Segunda-feira', kind: 'standard', meals: [] }
}

const CATALOG: Record<string, CatalogFoodSummary> = {
  Café: food('f-cafe', 'Café'),
  'Ovo de galinha frito/mexido': food('f-ovo', 'Ovo de galinha, frito'),
  'Mamão formosa': food('f-mamao', 'Mamão formosa'),
  'Banana prata': food('f-banana', 'Banana prata'),
}

function resolveFood(rawName: string): CatalogFoodSummary | null {
  return CATALOG[rawName] ?? null
}

const BREAKFAST: ParsedDietboxMeal = {
  name: 'Café da manhã',
  time: '10:00',
  notes: 'Nota do café',
  slots: [
    { primary: { rawName: 'Café', quantity: 1, measure: 'Xícara(s)', grams: 80 }, alternatives: [], dietboxGroupNo: 1 },
    {
      primary: { rawName: 'Ovo de galinha frito/mexido', quantity: 2, measure: 'Unidade(s)', grams: 100 },
      alternatives: [
        { rawName: 'Ovo de galinha cozido', quantity: 2, measure: 'Unidade(s)', grams: 110 },
        { rawName: 'Peito de frango desfiado', quantity: 2, measure: 'Colher(es)', grams: 50 },
      ],
      dietboxGroupNo: 4,
    },
    {
      primary: { rawName: 'Mamão formosa', quantity: 1, measure: 'Fatia(s)', grams: 170 },
      alternatives: [{ rawName: 'Banana prata', quantity: 1, measure: 'Unidade(s)', grams: 55 }],
      dietboxGroupNo: 9,
    },
  ],
}

describe('buildImportedDay', () => {
  it('builds one meal item per slot, using the primary food, and keeps the note', () => {
    const { day } = buildImportedDay(baseDay(), [BREAKFAST], resolveFood, () => null)
    expect(day.meals).toHaveLength(1)
    expect(day.meals[0].items.map((item) => item.name)).toEqual(['Café', 'Ovo de galinha, frito', 'Mamão formosa'])
    expect(day.meals[0].items[1].grams).toBe(100)
    expect(day.meals[0].notes).toBe('Nota do café')
  })

  it('does not sum the alternatives as extra meal items', () => {
    const { day, report } = buildImportedDay(baseDay(), [BREAKFAST], resolveFood, () => null)
    expect(day.meals[0].items).toHaveLength(3)
    expect(report.importedItems).toBe(3)
  })

  it('queues only the alternatives that have a catalog match, keyed by the primary item position', () => {
    const { pendingSubstitutions } = buildImportedDay(baseDay(), [BREAKFAST], resolveFood, () => null)
    // "Ovo de galinha cozido" and "Peito de frango desfiado" have no catalog match in this fixture, so only
    // "Banana prata" (alternative of the 3rd slot, item index 2) should come through.
    expect(pendingSubstitutions).toEqual([{ mealIndex: 0, itemIndex: 2, food: CATALOG['Banana prata'], grams: 55 }])
  })

  it('resolves an alternative that does have a catalog match, in isolation', () => {
    const withBanana: ParsedDietboxMeal = {
      ...BREAKFAST,
      slots: [BREAKFAST.slots[2]],
    }
    const { pendingSubstitutions } = buildImportedDay(baseDay(), [withBanana], resolveFood, () => null)
    expect(pendingSubstitutions).toEqual([{ mealIndex: 0, itemIndex: 0, food: CATALOG['Banana prata'], grams: 55 }])
  })

  it('skips a slot whose primary item has no catalog match instead of importing a wrong item', () => {
    const withGap: ParsedDietboxMeal = {
      ...BREAKFAST,
      slots: [{ primary: { rawName: 'Alimento inexistente', quantity: 1, measure: 'g', grams: 10 }, alternatives: [], dietboxGroupNo: null }],
    }
    const { day, report } = buildImportedDay(baseDay(), [withGap], resolveFood, () => null)
    expect(day.meals[0].items).toEqual([])
    expect(report.skippedSlots).toEqual([{ mealName: 'Café da manhã', rawName: 'Alimento inexistente' }])
  })

  it('reports a dropped alternative that has no catalog match without blocking the primary item', () => {
    const { report } = buildImportedDay(baseDay(), [BREAKFAST], resolveFood, () => null)
    expect(report.droppedAlternatives).toEqual([
      { mealName: 'Café da manhã', rawName: 'Ovo de galinha cozido' },
      { mealName: 'Café da manhã', rawName: 'Peito de frango desfiado' },
    ])
  })

  it('sets equivalencyListId only when the meal has a single slot whose group resolves to one list', () => {
    const singleSlotMeal: ParsedDietboxMeal = {
      name: 'Lanche',
      time: '15:00',
      notes: null,
      slots: [{ primary: { rawName: 'Café', quantity: 1, measure: 'Xícara(s)', grams: 80 }, alternatives: [], dietboxGroupNo: 1 }],
    }
    const { day } = buildImportedDay(baseDay(), [singleSlotMeal], resolveFood, (groupNo) => (groupNo === 1 ? { id: 'list-1', title: 'Grupo 1: Bebidas' } : null))
    expect(day.meals[0].equivalencyListId).toBe('list-1')
  })

  it('never sets equivalencyListId for a meal with multiple slots, even if groups resolve, to avoid misattributing it', () => {
    const { day } = buildImportedDay(baseDay(), [BREAKFAST], resolveFood, () => ({ id: 'list-x', title: 'Grupo X' }))
    expect(day.meals[0].equivalencyListId).toBeUndefined()
  })

  it('still surfaces multi-slot group hints for the professional to look up manually', () => {
    const { groupHints } = buildImportedDay(baseDay(), [BREAKFAST], resolveFood, (groupNo) =>
      groupNo === 4 ? { id: 'list-4', title: 'Grupo 4: Carnes e Proteínas' } : null,
    )
    expect(groupHints).toEqual([
      { mealName: 'Café da manhã', groupNo: 1, matchedListTitle: null },
      { mealName: 'Café da manhã', groupNo: 4, matchedListTitle: 'Grupo 4: Carnes e Proteínas' },
      { mealName: 'Café da manhã', groupNo: 9, matchedListTitle: null },
    ])
  })
})
