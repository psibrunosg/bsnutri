import { cleanup, fireEvent, render, screen, waitFor } from '@testing-library/react'
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'
import { CareWorkspace } from './CareWorkspace'

const { fromMock, rpcMock } = vi.hoisted(() => ({ fromMock: vi.fn(), rpcMock: vi.fn() }))

vi.mock('./lib/supabase', () => ({ supabase: { from: fromMock, rpc: rpcMock } }))

function queryResult(data: unknown[] = []) {
  const chain = {
    select: vi.fn(() => chain),
    eq: vi.fn(() => chain),
    order: vi.fn(() => chain),
    limit: vi.fn().mockResolvedValue({ data, error: null }),
  }
  return chain
}

const session = { user: { id: 'nutri-1' } }
const patients = [{ id: 'patient-1', full_name: 'Paciente Teste' }]
const alerts = [
  {
    id: 'alert-help',
    kind: 'severe_symptom',
    severity: 'urgent',
    message: 'Paciente pediu ajuda no diario alimentar.',
    status: 'open',
    detected_at: '2030-03-01T10:00:00Z',
    patient_name: 'Paciente Ajuda',
    priority_score: 100,
  },
  {
    id: 'alert-hunger',
    kind: 'intense_hunger',
    severity: 'attention',
    message: 'Paciente registrou fome extrema antes da refeicao.',
    status: 'open',
    detected_at: '2030-03-05T10:00:00Z',
    patient_name: 'Paciente Fome',
    priority_score: 60,
  },
]

describe('CareWorkspace follow-up queue', () => {
  afterEach(() => cleanup())

  beforeEach(() => {
    vi.clearAllMocks()
    fromMock.mockImplementation((table: string) =>
      queryResult(table === 'follow_up_queue' ? alerts : []),
    )
    rpcMock.mockResolvedValue({ error: null })
  })

  it('mostra fila priorizada e acoes rapidas', async () => {
    render(<CareWorkspace session={session as never} organizationId="org-1" patients={patients}/>)
    fireEvent.click(screen.getByRole('button', { name: /Adesão e alertas/i }))

    const help = await screen.findByText(/Paciente Ajuda/)
    const hunger = screen.getByText(/Paciente Fome/)
    expect(help.compareDocumentPosition(hunger) & Node.DOCUMENT_POSITION_FOLLOWING).toBeTruthy()
    expect(screen.getByText(/Prioridade 100/)).toBeInTheDocument()
    expect(screen.getAllByRole('button', { name: 'Orientar' })).toHaveLength(2)
    expect(screen.getAllByRole('button', { name: 'Revisar plano' })).toHaveLength(2)
    expect(screen.getAllByRole('button', { name: 'Pedir troca' })).toHaveLength(2)
  })

  it('registra orientacao e alerta acompanhado pela RPC', async () => {
    const prompt = vi.spyOn(window, 'prompt').mockReturnValue('Orientacao curta')
    render(<CareWorkspace session={session as never} organizationId="org-1" patients={patients}/>)
    fireEvent.click(screen.getByRole('button', { name: /Adesão e alertas/i }))

    fireEvent.click((await screen.findAllByRole('button', { name: 'Orientar' }))[0])
    await waitFor(() =>
      expect(rpcMock).toHaveBeenCalledWith('create_follow_up_action', {
        target_alert_id: 'alert-help',
        target_action: 'guidance',
        target_note: 'Orientacao curta',
      }),
    )

    fireEvent.click((await screen.findAllByRole('button', { name: 'Acompanhado' }))[0])
    await waitFor(() =>
      expect(rpcMock).toHaveBeenCalledWith('create_follow_up_action', {
        target_alert_id: 'alert-help',
        target_action: 'followed_up',
        target_note: null,
      }),
    )
    prompt.mockRestore()
  })
})
