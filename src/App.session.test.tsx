import { cleanup, fireEvent, render, screen, waitFor } from '@testing-library/react'
import { afterEach, describe, expect, it, vi } from 'vitest'
import { SessionDestination } from './App'

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

  it('uses one integration state for every professional route', () => {
    const { rerender } = render(<SessionDestination access={{ kind: 'professional', workspace }} route={{ page: 'dashboard' }} onNavigate={vi.fn()} onRetry={vi.fn()} onLogout={vi.fn()} />)
    expect(screen.getByRole('heading', { name: 'Integração em andamento' })).toBeInTheDocument()
    rerender(<SessionDestination access={{ kind: 'professional', workspace }} route={{ page: 'nutrition' }} onNavigate={vi.fn()} onRetry={vi.fn()} onLogout={vi.fn()} />)
    expect(screen.getAllByRole('heading', { name: 'Integração em andamento' })).toHaveLength(1)
  })

  it('keeps receptionists in a restricted destination with logout', () => {
    const logout = vi.fn()
    render(<SessionDestination access={{ kind: 'receptionist', workspace: { ...workspace, role: 'receptionist' } }} route={{ page: 'dashboard' }} onNavigate={vi.fn()} onRetry={vi.fn()} onLogout={logout} />)
    expect(screen.getByRole('heading', { name: 'Módulo de recepção indisponível nesta entrega' })).toBeInTheDocument()
    fireEvent.click(screen.getByRole('button', { name: 'Sair' }))
    expect(logout).toHaveBeenCalledOnce()
  })

  it('derives the patient portal from session access and removes patient id from the URL', async () => {
    window.history.replaceState(null, '', '/?page=portal&patient=other-patient&tab=plan')
    const navigate = vi.fn()
    render(<SessionDestination access={{ kind: 'patient', patient }} route={{ page: 'portal', patientId: 'other-patient', portalTab: 'plan' }} onNavigate={navigate} onRetry={vi.fn()} onLogout={vi.fn()} />)
    expect(screen.getByText('Pessoa vinculada')).toBeInTheDocument()
    await waitFor(() => expect(navigate).toHaveBeenCalledWith({ page: 'portal', portalTab: 'plan' }, { replace: true }))
  })

  it('shows explicit onboarding and recoverable error actions', () => {
    const { rerender } = render(<SessionDestination access={{ kind: 'onboarding' }} route={{ page: 'dashboard' }} onNavigate={vi.fn()} onRetry={vi.fn()} onLogout={vi.fn()} />)
    expect(screen.getByRole('heading', { name: 'Prepare seu espaço profissional' })).toBeInTheDocument()
    expect(screen.getByRole('button', { name: 'Criar espaço profissional' })).toBeInTheDocument()

    const retry = vi.fn()
    const logout = vi.fn()
    rerender(<SessionDestination access={{ kind: 'error', message: 'Falha de rede' }} route={{ page: 'dashboard' }} onNavigate={vi.fn()} onRetry={retry} onLogout={logout} />)
    expect(screen.getByRole('alert')).toHaveTextContent('Falha de rede')
    fireEvent.click(screen.getByRole('button', { name: 'Tentar novamente' }))
    fireEvent.click(screen.getByRole('button', { name: 'Sair' }))
    expect(retry).toHaveBeenCalledOnce()
    expect(logout).toHaveBeenCalledOnce()
  })
})
