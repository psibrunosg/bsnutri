import { describe, expect, it } from 'vitest'
import { canPublishPlan, canReviewPlan, completeAssistantStep, initialAssistantState } from './lib/planAssistant'
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

  it('retoma a etapa do assistente salva no rascunho', () => {
    const drafts = mapDraftRows([{
      id: 'p1',
      patient_id: 'patient-1',
      title: 'Plano semanal',
      updated_at: '2026-07-13T10:00:00Z',
      plan_versions: [{
        id: 'v1',
        version_no: 1,
        assistant_state: { currentStep: 'meals', completedSteps: ['objective', 'targets'], objective: 'Hipertrofia' },
        plan_days: [],
      }],
    }])

    expect(drafts[0].assistantState).toEqual({
      currentStep: 'meals',
      completedSteps: ['objective', 'targets'],
      objective: 'Hipertrofia',
    })
  })
})

describe('plan assistant', () => {
  it('bloqueia revisao e publicacao ate as etapas obrigatorias', () => {
    let state = initialAssistantState()
    expect(canReviewPlan(state)).toBe(false)

    for (const step of ['objective', 'targets', 'meals', 'equivalents'] as const) {
      state = completeAssistantStep(state, step)
    }

    expect(canReviewPlan(state)).toBe(true)
    expect(canPublishPlan(state, 'reviewed')).toBe(false)

    state = completeAssistantStep(state, 'review')
    expect(canPublishPlan(state, 'reviewed')).toBe(true)
  })
})
