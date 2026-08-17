import { act, renderHook, waitFor } from '@testing-library/react'
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'

const harness = vi.hoisted(() => ({ rpc: vi.fn(), from: vi.fn() }))

vi.mock('./supabase', async () => {
  const { queryStub } = await import('../test/supabaseStub')
  harness.from.mockImplementation(() => queryStub())
  return { supabase: { rpc: harness.rpc, from: harness.from }, isSupabaseConfigured: true }
})

const { dayHasContent, initialWeek, portionFromCatalogFood, toPayloadDays, usePlanDraft } = await import('./usePlanDraft')

const food = {
  id: 'food-1',
  name: 'Aveia',
  preparationState: 'raw',
  isOwn: false,
  householdMeasureLabel: null,
  householdMeasureGrams: null,
  sourceName: 'TBCA',
  nutrients: { energyKcal: 389, proteinG: 16.9 },
}

describe('portionFromCatalogFood', () => {
  it('records which nutrients the source actually reported', () => {
    const portion = portionFromCatalogFood(food, 40)
    expect(portion.grams).toBe(40)
    expect(portion.reportedNutrients).toEqual(['energyKcal', 'proteinG'])
    expect(portion.nutrientsPer100g.energyKcal).toBe(389)
    expect(portion.nutrientsPer100g.sodiumMg).toBe(0)
  })
})

describe('dayHasContent', () => {
  it('treats a day without items as empty', () => {
    const [day] = initialWeek()
    expect(dayHasContent(day)).toBe(false)
    expect(dayHasContent(undefined)).toBe(false)
  })

  it('treats a day with at least one item as filled', () => {
    const [day] = initialWeek()
    day.meals[0].items.push(portionFromCatalogFood(food, 40))
    expect(dayHasContent(day)).toBe(true)
  })
})

describe('toPayloadDays', () => {
  it('numbers days, meals and items so the server keeps the order', () => {
    const days = initialWeek().slice(0, 2)
    days[0].meals[0].items.push(portionFromCatalogFood(food, 40))
    const payload = toPayloadDays(days)

    expect(payload[0].day_index).toBe(0)
    expect(payload[1].day_index).toBe(1)
    expect(payload[0].meals[0].position).toBe(0)
    expect(payload[0].meals[0].items[0]).toMatchObject({ position: 0, food_id: 'food-1', grams: 40, unit: 'g' })
  })

  it('sends the meal note so it is not silently dropped on save', () => {
    const days = initialWeek().slice(0, 1)
    days[0].meals[0].notes = 'Nota importada do Dietbox'
    const payload = toPayloadDays(days)
    expect(payload[0].meals[0].notes).toBe('Nota importada do Dietbox')
    expect(payload[0].meals[1].notes).toBeNull()
  })
})

describe('usePlanDraft copy day', () => {
  beforeEach(() => {
    harness.rpc.mockReset().mockResolvedValue({ data: null, error: null })
  })
  afterEach(() => vi.clearAllMocks())

  function setup() {
    return renderHook(() => usePlanDraft({ organizationId: 'org-1', userId: 'user-1', onMessage: vi.fn() }))
  }

  it('copies straight into an empty day', async () => {
    const { result } = setup()
    await waitFor(() => expect(result.current.loadingDrafts).toBe(false))

    act(() => { result.current.addItem(result.current.days[0].meals[0].id, food, 40) })
    let outcome: { needsConfirmation: boolean; applied: boolean } | undefined
    act(() => { outcome = result.current.copyActiveDayTo(1) })

    expect(outcome).toEqual({ needsConfirmation: false, applied: true })
    expect(result.current.days[1].meals[0].items).toHaveLength(1)
  })

  it('asks for confirmation before overwriting a day that already has content', async () => {
    const { result } = setup()
    await waitFor(() => expect(result.current.loadingDrafts).toBe(false))

    act(() => {
      result.current.addItem(result.current.days[0].meals[0].id, food, 40)
      result.current.setActiveDay(1)
    })
    act(() => { result.current.addItem(result.current.days[1].meals[0].id, food, 90) })
    act(() => { result.current.setActiveDay(0) })

    let outcome: { needsConfirmation: boolean; applied: boolean } | undefined
    act(() => { outcome = result.current.copyActiveDayTo(1) })
    expect(outcome).toEqual({ needsConfirmation: true, applied: false })
    expect(result.current.days[1].meals[0].items[0].grams).toBe(90)

    act(() => { result.current.copyActiveDayTo(1, { confirmed: true }) })
    expect(result.current.days[1].meals[0].items[0].grams).toBe(40)
  })

  it('never autosaves while no draft version is open', async () => {
    const { result } = setup()
    await waitFor(() => expect(result.current.loadingDrafts).toBe(false))

    act(() => { result.current.addItem(result.current.days[0].meals[0].id, food, 40) })
    await new Promise((resolve) => setTimeout(resolve, 50))
    expect(harness.rpc).not.toHaveBeenCalledWith('autosave_plan_version', expect.anything())
  })
})

describe('changeItemGrams', () => {
  it('nunca deixa a quantidade chegar a zero ou negativa', async () => {
    const { result } = renderHook(() => usePlanDraft({ organizationId: 'org-1', userId: 'user-1', onMessage: vi.fn() }))
    await waitFor(() => expect(result.current.loadingDrafts).toBe(false))

    const mealId = result.current.days[0].meals[0].id
    act(() => { result.current.addItemToDay(0, mealId, food, 20) })
    const itemId = result.current.days[0].meals[0].items[0].id

    act(() => { result.current.changeItemGrams(0, mealId, itemId, -100) })
    expect(result.current.days[0].meals[0].items[0].grams).toBe(5)

    act(() => { result.current.changeItemGrams(0, mealId, itemId, 10) })
    expect(result.current.days[0].meals[0].items[0].grams).toBe(15)
  })
})
