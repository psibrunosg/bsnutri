import { describe, expect, it } from 'vitest'
import { mapDraftRows } from './planDrafts'

describe('mapDraftRows', () => {
  it('preserva a referência do catálogo usada pelo plano', () => {
    const [draft] = mapDraftRows([{
      id: 'plan-1', patient_id: 'patient-1', title: 'Plano', updated_at: '2026-07-24T10:00:00Z',
      plan_versions: [{ id: 'version-1', version_no: 1, plan_days: [{
        id: 'day-1', label: 'Dia 1', kind: 'standard', day_index: 0, meals: [{
          id: 'meal-1', label: 'Almoço', position: 0, meal_items: [{
            id: 'item-1', food_id: 'global-food-1', description: 'Arroz', grams: 100, nutrient_snapshot: { energyKcal: 130 },
          }],
        }],
      }], }],
    }])

    expect(draft.days[0].meals[0].items[0].foodId).toBe('global-food-1')
  })
})
