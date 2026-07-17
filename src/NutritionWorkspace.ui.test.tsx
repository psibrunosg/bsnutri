import { fireEvent, render, screen } from '@testing-library/react'
import { beforeEach, describe, expect, it, vi } from 'vitest'
import { NutritionWorkspace } from './NutritionWorkspace'

const { fromMock } = vi.hoisted(() => ({ fromMock: vi.fn() }))

vi.mock('./lib/supabase', () => ({ supabase: { from: fromMock } }))

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
  beforeEach(() => {
    fromMock.mockImplementation(() => queryResult([]))
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
})
