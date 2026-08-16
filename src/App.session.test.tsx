import { cleanup, fireEvent, render, screen, waitFor } from '@testing-library/react'
import { afterEach, describe, expect, it, vi } from 'vitest'

vi.mock('./lib/supabase', async () => {
  const { supabaseStub } = await import('./test/supabaseStub')
  return { isSupabaseConfigured: true, supabase: supabaseStub() }
})

const { SessionDestination } = await import('./App')

const workspace = {
  organizationId: 'organization-1',
  organizationName: 'Clínica Aurora',
  memberName: 'Dra. Ana',
  role: 'nutritionist' as const,
}

const patient = {
  id: 'patient-1',
  fullName: 'Pessoa vinculada',
  anonymousCode: 'P001',
  organizationId: 'organization-1',
  professionalId: 'professional-1',
  relationship: 'patient' as const,
}

describe('SessionDestination', () => {
  afterEach(() => {
    cleanup()
    window.history.replaceState(null, '', '/')
  })

  it('routes the professional destination to the clinical pages', async () => {
    const { rerender } = render(<SessionDestination access={{ kind: 'professional', workspace }} route={{ page: 'dashboard' }} userId="professional-1" onNavigate={vi.fn()} onRetry={vi.fn()} onLogout={vi.fn()} />)
    expect(await screen.findByRole('heading', { name: 'Visão geral do consultório' })).toBeInTheDocument()

    rerender(<SessionDestination access={{ kind: 'professional', workspace }} route={{ page: 'patients' }} userId="professional-1" onNavigate={vi.fn()} onRetry={vi.fn()} onLogout={vi.fn()} />)
    expect(await screen.findByRole('heading', { name: 'Pacientes' })).toBeInTheDocument()

    rerender(<SessionDestination access={{ kind: 'professional', workspace }} route={{ page: 'patient-new' }} userId="professional-1" onNavigate={vi.fn()} onRetry={vi.fn()} onLogout={vi.fn()} />)
    expect(await screen.findByRole('heading', { name: 'Novo paciente' })).toBeInTheDocument()
  })

  it('keeps an unknown patient out of the record instead of inventing one', async () => {
    const navigate = vi.fn()
    render(<SessionDestination access={{ kind: 'professional', workspace }} route={{ page: 'patient-detail', patientId: 'missing' }} userId="professional-1" onNavigate={navigate} onRetry={vi.fn()} onLogout={vi.fn()} />)
    expect(await screen.findByRole('heading', { name: 'Paciente não encontrado' })).toBeInTheDocument()
    fireEvent.click(screen.getByRole('button', { name: 'Voltar para pacientes' }))
    expect(navigate).toHaveBeenCalledWith({ page: 'patients' })
  })

  it('offers explicit workspace selection in deterministic order', () => {
    const selectWorkspace = vi.fn()
    const zeta = { ...workspace, organizationId: 'organization-z', organizationName: 'Clínica Zeta', role: 'admin' as const }
    const aurora = { ...workspace, organizationId: 'organization-a', organizationName: 'Clínica Aurora' }
    render(<SessionDestination access={{ kind: 'workspace-selection', workspaces: [aurora, zeta] }} route={{ page: 'dashboard' }} userId="professional-1" onNavigate={vi.fn()} onRetry={vi.fn()} onLogout={vi.fn()} onWorkspaceSelect={selectWorkspace} />)

    expect(screen.getByRole('heading', { name: 'Escolha o consultório' })).toBeInTheDocument()
    const choices = screen.getAllByRole('button', { name: /Clínica/ })
    expect(choices.map((choice) => choice.textContent)).toEqual(['Clínica Aurora', 'Clínica Zeta'])
    fireEvent.click(choices[1])
    expect(selectWorkspace).toHaveBeenCalledWith(zeta)
  })

  it('offers explicit portal selection for multiple valid links', () => {
    const selectPatient = vi.fn()
    const guardianPatient = { id: 'patient-2', organizationId: 'organization-1', relationship: 'guardian' as const, guardianRelationship: 'Mãe' }
    render(<SessionDestination access={{ kind: 'portal-selection', patients: [patient, guardianPatient] }} route={{ page: 'portal' }} userId="professional-1" onNavigate={vi.fn()} onRetry={vi.fn()} onLogout={vi.fn()} onPatientSelect={selectPatient} />)

    expect(screen.getByRole('heading', { name: 'Escolha o acesso ao portal' })).toBeInTheDocument()
    expect(screen.getByRole('button', { name: 'Pessoa vinculada' })).toBeInTheDocument()
    fireEvent.click(screen.getByRole('button', { name: 'Dependente · Mãe' }))
    expect(selectPatient).toHaveBeenCalledWith(guardianPatient)
  })

  it('keeps receptionists in a restricted destination with logout', () => {
    const logout = vi.fn()
    render(<SessionDestination access={{ kind: 'receptionist', workspace: { ...workspace, role: 'receptionist' } }} route={{ page: 'dashboard' }} userId="professional-1" onNavigate={vi.fn()} onRetry={vi.fn()} onLogout={logout} />)
    expect(screen.getByRole('heading', { name: 'Módulo de recepção indisponível nesta entrega' })).toBeInTheDocument()
    fireEvent.click(screen.getByRole('button', { name: 'Sair' }))
    expect(logout).toHaveBeenCalledOnce()
  })

  it('derives the patient portal from session access and removes patient id from the URL', async () => {
    window.history.replaceState(null, '', '/?page=portal&patient=other-patient&tab=plan')
    const navigate = vi.fn()
    render(<SessionDestination access={{ kind: 'patient', patient }} route={{ page: 'portal', patientId: 'other-patient', portalTab: 'plan' }} userId="professional-1" onNavigate={navigate} onRetry={vi.fn()} onLogout={vi.fn()} />)
    expect(screen.getByText('Pessoa vinculada')).toBeInTheDocument()
    await waitFor(() => expect(navigate).toHaveBeenCalledWith({ page: 'portal', portalTab: 'plan' }, { replace: true }))
  })

  it('shows explicit onboarding and recoverable error actions', () => {
    const { rerender } = render(<SessionDestination access={{ kind: 'onboarding' }} route={{ page: 'dashboard' }} userId="professional-1" onNavigate={vi.fn()} onRetry={vi.fn()} onLogout={vi.fn()} />)
    expect(screen.getByRole('heading', { name: 'Prepare seu espaço profissional' })).toBeInTheDocument()
    expect(screen.getByRole('button', { name: 'Criar espaço profissional' })).toBeInTheDocument()

    const retry = vi.fn()
    const logout = vi.fn()
    rerender(<SessionDestination access={{ kind: 'error', message: 'Falha de rede' }} route={{ page: 'dashboard' }} userId="professional-1" onNavigate={vi.fn()} onRetry={retry} onLogout={logout} />)
    expect(screen.getByRole('alert')).toHaveTextContent('Falha de rede')
    fireEvent.click(screen.getByRole('button', { name: 'Tentar novamente' }))
    fireEvent.click(screen.getByRole('button', { name: 'Sair' }))
    expect(retry).toHaveBeenCalledOnce()
    expect(logout).toHaveBeenCalledOnce()
  })
})
