import { describe, expect, it } from 'vitest'
import { toPublishedPlanDocument, type PrescribedSubstitution } from './pdf'
import { emptyNutrients } from './nutrition'
import { initialAssistantState } from './planAssistant'
import type { DraftSummary } from './planDrafts'

function draft(overrides: Partial<DraftSummary> = {}): DraftSummary {
  return {
    id: 'plan-1',
    patientId: 'patient-1',
    title: 'Plano alimentar',
    status: 'published',
    updatedAt: '2026-08-16T12:00:00Z',
    versionId: 'version-1',
    version: 2,
    targets: {},
    assistantState: initialAssistantState(),
    locked: true,
    days: [
      {
        id: 'day-1',
        label: 'Segunda-feira',
        kind: 'standard',
        meals: [
          {
            id: 'meal-1',
            name: 'Café da manhã',
            items: [{ id: 'item-1', name: 'Aveia', grams: 30, nutrientsPer100g: emptyNutrients() }],
          },
        ],
      },
    ],
    ...overrides,
  }
}

function substitution(overrides: Partial<PrescribedSubstitution> = {}): PrescribedSubstitution {
  return {
    planVersionId: 'version-1',
    mealItemId: 'item-1',
    replacementName: 'Granola sem açúcar',
    isActive: true,
    ...overrides,
  }
}

describe('toPublishedPlanDocument', () => {
  it('refuses a draft that was never published', () => {
    expect(toPublishedPlanDocument(draft({ status: 'draft', locked: false }), 'Mariana')).toBeNull()
  })

  it('refuses a reviewed version that is not published yet', () => {
    expect(toPublishedPlanDocument(draft({ status: 'reviewed', locked: false }), 'Mariana')).toBeNull()
  })

  it('refuses a plan marked published whose version is not locked', () => {
    expect(toPublishedPlanDocument(draft({ locked: false }), 'Mariana')).toBeNull()
  })

  it('builds the patient document from the published version', () => {
    const document = toPublishedPlanDocument(draft(), 'Mariana Lopes')
    expect(document).not.toBeNull()
    expect(document!.patientName).toBe('Mariana Lopes')
    expect(document!.version).toBe(2)
    expect(document!.days).toHaveLength(1)
  })

  it('carries only prescribed substitutions that are active in the published version', () => {
    const document = toPublishedPlanDocument(draft(), 'Mariana Lopes', [
      substitution(),
      substitution({ replacementName: 'Tapioca', planVersionId: 'version-old' }),
      substitution({ replacementName: 'Pão integral', isActive: false }),
      substitution({ replacementName: 'Item fora do plano', mealItemId: 'item-desconhecido' }),
    ])

    expect(document!.substitutions).toEqual([{ originalName: 'Aveia', options: ['Granola sem açúcar'] }])
  })

  it('groups every reviewed option under the prescribed item', () => {
    const document = toPublishedPlanDocument(draft(), 'Mariana Lopes', [
      substitution(),
      substitution({ replacementName: 'Cuscuz' }),
    ])

    expect(document!.substitutions[0].options).toEqual(['Granola sem açúcar', 'Cuscuz'])
  })
})
