import { cleanup, render, screen } from '@testing-library/react'
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'
import { PatientPortal } from './PatientPortal'

const { fromMock, rpcMock } = vi.hoisted(() => ({ fromMock: vi.fn(), rpcMock: vi.fn() }))

vi.mock('./lib/supabase', () => ({
  supabase: {
    from: fromMock,
    rpc: rpcMock,
  },
}))

function queryResult(data: unknown[] = []) {
  return {
    select: vi.fn().mockReturnThis(),
    eq: vi.fn().mockReturnThis(),
    in: vi.fn().mockReturnThis(),
    order: vi.fn().mockResolvedValue({ data, error: null }),
  }
}

const patient = { id: 'patient-1', full_name: 'Paciente Teste', anonymous_code: 'P01', organization_id: 'org-1', professional_id: 'pro-1' }

function plan(visibility: unknown) {
  return [{
    id: 'plan-1',
    title: 'Plano A',
    published_at: '2026-07-17T10:00:00Z',
    plan_versions: {
      id: 'version-1',
      version_no: 1,
      assistant_state: { visibility },
      plan_days: [{
        id: 'day-1',
        label: 'Dia 1',
        day_index: 0,
        meals: [{
          id: 'meal-1',
          label: 'Almoco',
          position: 0,
          suggested_time: null,
          meal_items: [{
            id: 'item-1',
            description: 'Arroz',
            grams: 100,
            nutrient_snapshot: { food_name: 'Arroz', nutrients: [{ code: 'energy_kcal', amount: 130 }, { code: 'protein_g', amount: 5 }, { code: 'carbohydrate_g', amount: 30 }, { code: 'fat_g', amount: 2 }] },
            meal_item_substitutions: [],
          }],
        }],
      }],
    },
  }]
}

describe('PatientPortal visibility controls', () => {
  afterEach(() => cleanup())

  beforeEach(() => {
    rpcMock.mockResolvedValue({ data: [], error: null })
  })

  it.each([
    [{ showTotalKcal: false, showTotalMacros: false, showMealCalculations: false }, false, false],
    [{ showTotalKcal: true, showTotalMacros: true, showMealCalculations: false }, true, false],
    [{ showTotalKcal: false, showTotalMacros: false, showMealCalculations: true }, false, true],
  ])('respeita visibilidade %j', async (visibility, showsPlanTotal, showsMealTotal) => {
    fromMock.mockImplementation((table: string) => queryResult(table === 'plans' ? plan(visibility) : []))

    render(<PatientPortal patient={patient}/>)
    await screen.findByText('Plano A')

    expect(screen.queryAllByText('130 kcal').length).toBe((showsPlanTotal ? 1 : 0) + (showsMealTotal ? 1 : 0))
  })
})
