import { cleanup, fireEvent, render, screen } from '@testing-library/react'
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'
import { NutritionWorkspace } from './NutritionWorkspace'

const { fromMock, rpcMock } = vi.hoisted(() => ({ fromMock: vi.fn(), rpcMock: vi.fn() }))

vi.mock('./lib/supabase', () => ({ supabase: { from: fromMock, rpc: rpcMock } }))

function queryResult(data: unknown[] = []) {
  return {
    select: vi.fn().mockReturnThis(),
    eq: vi.fn().mockReturnThis(),
    order: vi.fn().mockResolvedValue({ data, error: null }),
  }
}

const session = { user: { id: 'user-1' } }
const patients = [{ id: 'patient-1', anonymous_code: 'P01', full_name: 'Paciente Teste' }]

describe('NutritionWorkspace editor modes', () => {
  afterEach(() => cleanup())

  beforeEach(() => {
    fromMock.mockImplementation(() => queryResult([]))
    rpcMock.mockResolvedValue({ error: null })
  })

  it('alterna densidade sem perder dados do rascunho', async () => {
    render(<NutritionWorkspace session={session as never} organizationId="org-1" patients={patients}/>)

    fireEvent.click(screen.getByRole('button', { name: /Editor de plano/i }))

    const quickMode = await screen.findByRole('tab', { name: /Consulta rapida/i })
    expect(quickMode).toHaveAttribute('aria-selected', 'true')
    expect(screen.getByText('Metas nutricionais').closest('section')).toHaveAttribute('aria-hidden', 'true')

    const objective = screen.getByLabelText(/Objetivo/i)
    fireEvent.change(objective, { target: { value: 'Hipertrofia com rotina simples' } })

    fireEvent.click(screen.getByRole('tab', { name: /Tecnico/i }))
    expect(screen.getByText('Metas nutricionais').closest('section')).toHaveAttribute('aria-hidden', 'false')
    expect(screen.getByText('Pendencias tecnicas').closest('section')).toHaveAttribute('aria-hidden', 'false')
    expect(screen.getByDisplayValue('Hipertrofia com rotina simples')).toBeInTheDocument()

    fireEvent.click(screen.getByRole('tab', { name: /Consulta rapida/i }))
    expect(screen.getByDisplayValue('Hipertrofia com rotina simples')).toBeInTheDocument()
  })

  it('exige confirmacao extra ao publicar sem substituicoes revisadas', async () => {
    fromMock.mockImplementation((table: string) => queryResult(table === 'plans' ? [{
      id: 'plan-1',
      patient_id: 'patient-1',
      title: 'Plano A',
      status: 'reviewed',
      updated_at: '2026-07-17T10:00:00Z',
      plan_versions: [{
        id: 'version-1',
        version_no: 1,
        targets: { energyKcal: 2000, proteinG: 100, carbohydrateG: 220, fatG: 70, fiberG: 30, waterMl: 2500 },
        assistant_state: { currentStep: 'review', completedSteps: ['objective', 'targets', 'meals', 'equivalents', 'review'], objective: 'Plano clinico', clinicalPresets: ['hypertrophy'], priorityMicronutrients: ['Ferro'] },
        locked_at: null,
        plan_days: [{ id: 'day-1', label: 'Dia 1', kind: 'standard', day_index: 0, meals: [{ id: 'meal-1', label: 'Almoco', position: 0, meal_items: [{ id: 'item-1', description: 'Arroz', grams: 100, nutrient_snapshot: { energyKcal: 130 }, meal_item_substitutions: [] }] }] }],
      }],
    }] : []))

    render(<NutritionWorkspace session={session as never} organizationId="org-1" patients={patients}/>)
    fireEvent.click(screen.getByRole('button', { name: /Editor de plano/i }))
    fireEvent.click(await screen.findByText('Plano A'))

    fireEvent.click(screen.getByRole('button', { name: /^Publicar$/i }))
    expect(await screen.findByText(/sem substituicoes revisadas/i)).toBeInTheDocument()
    expect(rpcMock).not.toHaveBeenCalled()

    fireEvent.click(screen.getByRole('button', { name: /Confirmar publica/i }))
    expect(rpcMock).toHaveBeenCalledWith('publish_plan_version', { target_plan_id: 'plan-1', target_version_id: 'version-1' })
  })
})
