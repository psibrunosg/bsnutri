import { act, cleanup, fireEvent, render, screen } from '@testing-library/react'
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
  afterEach(() => {
    cleanup()
    vi.unstubAllGlobals()
  })

  it('opens and closes the responsive drawer with its accessible controls', () => {
    render(<Shell route={{ page: 'dashboard' }} workspace={workspace} onNavigate={vi.fn()} onLogout={vi.fn()}>Conteúdo</Shell>)
    const trigger = screen.getByRole('button', { name: 'Abrir menu' })

    fireEvent.click(trigger)
    expect(screen.getByRole('navigation', { name: 'Navegação principal' })).toHaveAttribute('data-open', 'true')
    expect(screen.getAllByRole('navigation')).toHaveLength(1)
    expect(screen.getByRole('button', { name: 'Fechar menu' })).toBeInTheDocument()
    expect(screen.getByTestId('drawer-overlay')).not.toHaveAttribute('tabindex')
    expect(screen.getByRole('main', { hidden: true })).toHaveAttribute('inert')
    expect(screen.getByRole('main', { hidden: true })).toHaveAttribute('aria-hidden', 'true')

    const close = screen.getByRole('button', { name: 'Fechar menu' })
    const logout = screen.getByRole('button', { name: 'Sair' })
    logout.focus()
    fireEvent.keyDown(document, { key: 'Tab' })
    expect(close).toHaveFocus()
    fireEvent.keyDown(document, { key: 'Tab', shiftKey: true })
    expect(logout).toHaveFocus()

    fireEvent.keyDown(document, { key: 'Escape' })
    expect(screen.getByRole('navigation', { name: 'Navegação principal' })).toHaveAttribute('data-open', 'false')
    expect(trigger).toHaveFocus()
    expect(screen.getByRole('main')).not.toHaveAttribute('inert')
    expect(screen.getByRole('main')).not.toHaveAttribute('aria-hidden')
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

  it('removes the drawer transition when reduced motion is preferred', () => {
    vi.stubGlobal('matchMedia', vi.fn().mockReturnValue({
      matches: true,
      media: '(prefers-reduced-motion: reduce)',
      addEventListener: vi.fn(),
      removeEventListener: vi.fn(),
    }))

    render(<Shell route={{ page: 'dashboard' }} workspace={workspace} onNavigate={vi.fn()} onLogout={vi.fn()}>Conteúdo</Shell>)

    expect(screen.getByRole('navigation', { name: 'Navegação principal' })).toHaveAttribute('data-motion', 'reduced')
    expect(screen.getByRole('navigation', { name: 'Navegação principal' })).toHaveClass('transition-none')
  })

  it('closes the mobile drawer when the viewport enters the desktop breakpoint', () => {
    const desktopListeners: Array<(event: MediaQueryListEvent) => void> = []
    vi.stubGlobal('matchMedia', vi.fn((query: string) => ({
      matches: false,
      media: query,
      addEventListener: vi.fn((_event: string, listener: (event: MediaQueryListEvent) => void) => {
        if (query === '(min-width: 1024px)') desktopListeners.push(listener)
      }),
      removeEventListener: vi.fn(),
    })))
    render(<Shell route={{ page: 'dashboard' }} workspace={workspace} onNavigate={vi.fn()} onLogout={vi.fn()}>Conteúdo</Shell>)

    fireEvent.click(screen.getByRole('button', { name: 'Abrir menu' }))
    expect(screen.getByRole('main', { hidden: true })).toHaveAttribute('inert')

    act(() => desktopListeners.forEach((listener) => listener({ matches: true } as MediaQueryListEvent)))

    expect(screen.getByRole('navigation', { name: 'Navegação principal' })).toHaveAttribute('data-open', 'false')
    expect(screen.queryByTestId('drawer-overlay')).not.toBeInTheDocument()
    expect(screen.getByRole('main')).not.toHaveAttribute('inert')
    expect(screen.getByRole('main')).not.toHaveAttribute('aria-hidden')

    const logout = screen.getByRole('button', { name: 'Sair' })
    logout.focus()
    fireEvent.keyDown(document, { key: 'Tab' })
    expect(screen.getByRole('button', { name: 'Fechar menu' })).not.toHaveFocus()
  })
})
