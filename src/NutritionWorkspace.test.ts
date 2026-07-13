import { describe, expect, it } from 'vitest'
import { mapDraftRows } from './lib/planDrafts'

describe('mapDraftRows', () => {
  it('reconstrói a versão mais recente em ordem de dias e refeições', () => {
    const drafts = mapDraftRows([{
      id: 'p1', patient_id: 'patient-1', title: 'Plano semanal', updated_at: '2026-07-13T10:00:00Z',
      plan_versions: [
        { id: 'v1', version_no: 1, plan_days: [] },
        { id: 'v2', version_no: 2, plan_days: [
          { id: 'd2', label: 'Descanso', kind: 'rest', day_index: 1, meals: [] },
          { id: 'd1', label: 'Treino', kind: 'training', day_index: 0, meals: [
            { id: 'm2', label: 'Almoço', position: 1, meal_items: [] },
            { id: 'm1', label: 'Café', position: 0, meal_items: [{ id: 'i1', description: 'Banana', grams: 120, nutrient_snapshot: { energyKcal: 89, proteinG: 1.1 } }] },
          ] },
        ] },
      ],
    }])

    expect(drafts[0].version).toBe(2)
    expect(drafts[0].days.map(day => day.label)).toEqual(['Treino', 'Descanso'])
    expect(drafts[0].days[0].meals.map(meal => meal.name)).toEqual(['Café', 'Almoço'])
    expect(drafts[0].days[0].meals[0].items[0]).toMatchObject({ name: 'Banana', grams: 120, nutrientsPer100g: { energyKcal: 89, proteinG: 1.1, fatG: 0 } })
  })
})
