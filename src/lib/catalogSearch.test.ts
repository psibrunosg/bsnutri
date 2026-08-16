import { describe, expect, it } from 'vitest'
import { CATALOG_PAGE_SIZE, escapeSearchTerm, mapCatalogFood, pageRange, type CatalogFoodRow } from './catalogSearch'

function row(overrides: Partial<CatalogFoodRow> = {}): CatalogFoodRow {
  return {
    id: 'food-1',
    name: 'Arroz integral cozido',
    preparation_state: 'cooked',
    organization_id: null,
    household_measure_label: null,
    household_measure_grams: null,
    food_sources: null,
    food_nutrient_values: [],
    ...overrides,
  }
}

describe('mapCatalogFood', () => {
  it('keeps a missing nutrient absent instead of turning it into zero', () => {
    const mapped = mapCatalogFood(row({
      food_nutrient_values: [
        { amount_per_100g: 112, nutrients: { code: 'energy_kcal' } },
        { amount_per_100g: null, nutrients: { code: 'sodium_mg' } },
      ],
    }))

    expect(mapped.nutrients.energyKcal).toBe(112)
    expect('sodiumMg' in mapped.nutrients).toBe(false)
    expect(mapped.nutrients.sodiumMg).toBeUndefined()
  })

  it('ignores nutrient codes that are not part of the domain', () => {
    const mapped = mapCatalogFood(row({
      food_nutrient_values: [{ amount_per_100g: 9, nutrients: { code: 'codigo_desconhecido' } }],
    }))
    expect(Object.keys(mapped.nutrients)).toEqual([])
  })

  it('distinguishes the clinic catalogue from the shared one', () => {
    expect(mapCatalogFood(row()).isOwn).toBe(false)
    expect(mapCatalogFood(row({ organization_id: 'org-1' })).isOwn).toBe(true)
  })

  it('reads the source name when the food comes from a technical dataset', () => {
    expect(mapCatalogFood(row({ food_sources: { name: 'TBCA' } })).sourceName).toBe('TBCA')
    expect(mapCatalogFood(row()).sourceName).toBeNull()
  })
})

describe('pageRange', () => {
  it('asks the database for one page at a time', () => {
    expect(pageRange(1, CATALOG_PAGE_SIZE)).toEqual({ from: 0, to: 29 })
    expect(pageRange(2, CATALOG_PAGE_SIZE)).toEqual({ from: 30, to: 59 })
    expect(pageRange(4, 24)).toEqual({ from: 72, to: 95 })
  })

  it('falls back to the first page for invalid input', () => {
    expect(pageRange(0, 30)).toEqual({ from: 0, to: 29 })
    expect(pageRange(-3, 30)).toEqual({ from: 0, to: 29 })
    expect(pageRange(Number.NaN, 30)).toEqual({ from: 0, to: 29 })
  })
})

describe('escapeSearchTerm', () => {
  it('removes PostgREST wildcards and separators from the term', () => {
    expect(escapeSearchTerm('  arroz%  ')).toBe('arroz')
    expect(escapeSearchTerm('feijão, carioca')).toBe('feijão carioca')
    expect(escapeSearchTerm('leite (integral)')).toBe('leite integral')
  })
})
