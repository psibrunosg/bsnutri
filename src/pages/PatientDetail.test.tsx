import { cleanup, fireEvent, render, screen, waitFor } from '@testing-library/react'
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'

const harness = vi.hoisted(() => ({ insert: vi.fn() }))

vi.mock('../lib/supabase', async () => {
  const { queryStub } = await import('../test/supabaseStub')
  return {
    isSupabaseConfigured: true,
    supabase: {
      rpc: vi.fn().mockResolvedValue({ data: null, error: null }),
      from: () => {
        const chain = queryStub() as Record<string, unknown>
        chain.insert = (...args: unknown[]) => { harness.insert(...args); return queryStub() }
        return chain
      },
    },
  }
})

const { default: PatientDetail } = await import('./PatientDetail')

const patient = {
  id: 'patient-1',
  anonymousCode: 'P0001',
  fullName: 'Bruno de Souza',
  email: null,
  phone: null,
  birthDate: '1998-11-27',
  status: 'active',
  tags: [],
  objective: null,
  measurements: [],
}

function setup(section = 'evolucao') {
  const onDirectoryChange = vi.fn().mockResolvedValue(undefined)
  render(
    <PatientDetail
      patient={patient}
      organizationId="org-1"
      userId="user-1"
      section={section}
      onSelectSection={vi.fn()}
      onBack={vi.fn()}
      onDirectoryChange={onDirectoryChange}
      onOpenPlan={vi.fn()}
    />,
  )
  return { onDirectoryChange }
}

describe('PatientDetail — gravação de formulário', () => {
  beforeEach(() => harness.insert.mockReset())
  afterEach(() => cleanup())

  it('confirma a antropometria e recarrega o prontuário depois de gravar', async () => {
    const { onDirectoryChange } = setup('evolucao')
    fireEvent.change(await screen.findByLabelText('Peso (kg)'), { target: { value: '88,8' } })
    fireEvent.change(screen.getByLabelText('Estatura (cm)'), { target: { value: '165' } })
    fireEvent.click(screen.getByRole('button', { name: 'Salvar medidas' }))

    // Sem a captura do formulário antes do await, `reset()` lançava e nem a
    // mensagem nem a recarga aconteciam — a lista só atualizava ao recarregar a página.
    expect(await screen.findByText('Medidas registradas.')).toBeInTheDocument()
    await waitFor(() => expect(onDirectoryChange).toHaveBeenCalled())
    expect((screen.getByLabelText('Peso (kg)') as HTMLInputElement).value).toBe('')
  })

  it('confirma a avaliação e recarrega o prontuário depois de gravar', async () => {
    const { onDirectoryChange } = setup('avaliacoes')
    fireEvent.change(await screen.findByLabelText('Objetivo'), { target: { value: 'Emagrecimento' } })
    fireEvent.click(screen.getByRole('button', { name: 'Salvar avaliação' }))

    expect(await screen.findByText('Avaliação registrada.')).toBeInTheDocument()
    await waitFor(() => expect(onDirectoryChange).toHaveBeenCalled())
    expect((screen.getByLabelText('Objetivo') as HTMLInputElement).value).toBe('')
  })

  it('recusa antropometria sem peso nem estatura', async () => {
    setup('evolucao')
    fireEvent.click(await screen.findByRole('button', { name: 'Salvar medidas' }))
    expect(await screen.findByText('Informe ao menos peso ou estatura.')).toBeInTheDocument()
    expect(harness.insert).not.toHaveBeenCalled()
  })
})
