import { describe, expect, it, vi } from 'vitest'
import type { CatalogDataSource, CatalogFoodSummary } from './catalogSearch'
import { buildDietboxMatchIndex, matchDietboxFoodName } from './dietboxMatch'

function food(overrides: Partial<CatalogFoodSummary> = {}): CatalogFoodSummary {
  return {
    id: 'food-1',
    name: 'Arroz integral cozido',
    preparationState: 'cooked',
    isOwn: false,
    householdMeasureLabel: null,
    householdMeasureGrams: null,
    sourceName: 'TACO',
    nutrients: {},
    ...overrides,
  }
}

function fakeDataSource(foodsByQuery: Record<string, CatalogFoodSummary[]>): CatalogDataSource {
  return {
    searchFoods: vi.fn(async ({ query }) => ({
      data: { foods: foodsByQuery[query] ?? [], total: (foodsByQuery[query] ?? []).length, page: 1, pageSize: 30, pageCount: 1 },
      error: null,
    })),
  }
}

describe('matchDietboxFoodName', () => {
  it('auto-accepts a single candidate whose name is equivalent once normalized', async () => {
    const dataSource = fakeDataSource({ 'Ovo de galinha cozido': [food({ id: 'egg-1', name: 'Ovo de galinha, cozido' })] })
    const result = await matchDietboxFoodName('Ovo de galinha cozido', dataSource, 'org-1')
    expect(result).toEqual({ status: 'matched', food: food({ id: 'egg-1', name: 'Ovo de galinha, cozido' }) })
  })

  it('auto-accepts when the catalog name is a superset of the dietbox words', async () => {
    const dataSource = fakeDataSource({ 'Banana prata': [food({ id: 'banana-1', name: 'Banana, prata, crua' })] })
    const result = await matchDietboxFoodName('Banana prata', dataSource, 'org-1')
    expect(result.status).toBe('matched')
  })

  it('requires manual review when nothing is found', async () => {
    const dataSource = fakeDataSource({})
    const result = await matchDietboxFoodName('Alimento inexistente', dataSource, 'org-1')
    expect(result).toEqual({ status: 'needs_review', suggestions: [] })
  })

  it('requires manual review when several candidates come back and none matches exactly', async () => {
    const candidates = [food({ id: 'a', name: 'Frango grelhado' }), food({ id: 'b', name: 'Frango assado' })]
    const dataSource = fakeDataSource({ Frango: candidates })
    const result = await matchDietboxFoodName('Frango', dataSource, 'org-1')
    expect(result).toEqual({ status: 'needs_review', suggestions: candidates })
  })

  it('never auto-selects among ambiguous candidates even if one matches exactly', async () => {
    const exact = food({ id: 'exact', name: 'Arroz branco' })
    const other = food({ id: 'other', name: 'Arroz branco tipo 1' })
    const dataSource = fakeDataSource({ 'Arroz branco': [exact, other] })
    const result = await matchDietboxFoodName('Arroz branco', dataSource, 'org-1')
    expect(result.status).toBe('needs_review')
  })

  it('surfaces a search error as needs_review instead of throwing', async () => {
    const dataSource: CatalogDataSource = { searchFoods: vi.fn(async () => ({ data: null, error: { message: 'falha de rede' } })) }
    const result = await matchDietboxFoodName('Qualquer coisa', dataSource, 'org-1')
    expect(result).toEqual({ status: 'needs_review', suggestions: [], error: 'falha de rede' })
  })
})

describe('buildDietboxMatchIndex', () => {
  it('queries each distinct name only once even when it repeats', async () => {
    const egg = food({ id: 'egg-1', name: 'Ovo de galinha, cozido' })
    const dataSource = fakeDataSource({ 'Ovo de galinha cozido': [egg] })
    const index = await buildDietboxMatchIndex(
      ['Ovo de galinha cozido', 'Ovo de galinha cozido', 'ovo de galinha cozido'],
      dataSource,
      'org-1',
    )
    expect(dataSource.searchFoods).toHaveBeenCalledTimes(1)
    expect(index.get('Ovo de galinha cozido')).toEqual({ status: 'matched', food: egg })
    expect(index.get('ovo de galinha cozido')).toEqual({ status: 'matched', food: egg })
  })
})
