import { cleanup, fireEvent, render, screen } from '@testing-library/react'
import { afterEach, describe, expect, it, vi } from 'vitest'
import { Shell } from './Shell'

vi.mock('../lib/store', () => ({
  useStore: () => ({
    view: { name: 'dashboard' },
    go: vi.fn(),
    setLoggedIn: vi.fn(),
    patients: [],
  }),
}))

const workspace = {
  organizationId: 'organization-1',
  organizationName: 'Clínica Aurora',
  memberName: 'Dra. Ana',
  role: 'nutritionist' as const,
}

describe('Shell', () => {
  afterEach(() => cleanup())

  it('opens and closes the responsive drawer with its accessible controls', () => {
    render(<Shell route={{ page: 'dashboard' }} workspace={workspace} onNavigate={vi.fn()} onLogout={vi.fn()}>Conteúdo</Shell>)
    const trigger = screen.getByRole('button', { name: 'Abrir menu' })

    fireEvent.click(trigger)
    expect(screen.getByRole('navigation', { name: 'Navegação principal' })).toHaveAttribute('data-open', 'true')
    expect(screen.getByRole('button', { name: 'Fechar menu' })).toBeInTheDocument()
    expect(screen.getByTestId('drawer-overlay')).toBeInTheDocument()

    fireEvent.keyDown(document, { key: 'Escape' })
    expect(screen.getByRole('navigation', { name: 'Navegação principal' })).toHaveAttribute('data-open', 'false')
    expect(trigger).toHaveFocus()
  })

  it('navigates and closes the drawer after choosing a destination', () => {
    const navigate = vi.fn()
    render(<Shell route={{ page: 'dashboard' }} workspace={workspace} onNavigate={navigate} onLogout={vi.fn()}>Conteúdo</Shell>)
    const trigger = screen.getByRole('button', { name: 'Abrir menu' })
    fireEvent.click(trigger)
    fireEvent.click(screen.getByRole('button', { name: 'Pacientes' }))

    expect(navigate).toHaveBeenCalledWith({ page: 'patients' })
    expect(screen.getByRole('navigation', { name: 'Navegação principal' })).toHaveAttribute('data-open', 'false')
    expect(trigger).toHaveFocus()
  })

  it('renders professional identity from the workspace record', () => {
    render(<Shell route={{ page: 'dashboard' }} workspace={workspace} onNavigate={vi.fn()} onLogout={vi.fn()}>Conteúdo</Shell>)
    expect(screen.getAllByText('Dra. Ana').length).toBeGreaterThan(0)
    expect(screen.getAllByText('Clínica Aurora').length).toBeGreaterThan(0)
    expect(screen.getByText('Nutricionista')).toBeInTheDocument()
  })
})
