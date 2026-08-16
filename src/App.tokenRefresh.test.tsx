import { act, cleanup, render, screen, waitFor } from '@testing-library/react'
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'

const harness = vi.hoisted(() => ({
  listener: undefined as undefined | ((event: string, session: unknown) => void),
  getSession: vi.fn(),
  onAuthStateChange: vi.fn(),
  resolveAccess: vi.fn(),
}))

vi.mock('./lib/supabase', async () => {
  const { queryStub } = await import('./test/supabaseStub')
  return {
    isSupabaseConfigured: true,
    supabase: {
      from: () => queryStub(),
      rpc: vi.fn().mockResolvedValue({ data: null, error: null }),
      auth: {
        getSession: harness.getSession,
        onAuthStateChange: harness.onAuthStateChange,
        signOut: vi.fn().mockResolvedValue({ error: null }),
      },
    },
  }
})
vi.mock('./lib/supabaseBootstrapDataSource', () => ({ createSupabaseBootstrapDataSource: () => ({}) }))
vi.mock('./lib/sessionBootstrap', () => ({ resolveSessionAccess: harness.resolveAccess }))

const { default: App } = await import('./App')

const session = (id: string) => ({ user: { id, user_metadata: { full_name: id } } })
const access = (id: string) => ({
  kind: 'professional' as const,
  workspace: { organizationId: `org-${id}`, organizationName: `Clínica ${id}`, memberName: id, role: 'nutritionist' as const },
})

describe('renovação de token', () => {
  beforeEach(() => {
    harness.getSession.mockReset().mockResolvedValue({ data: { session: session('A') }, error: null })
    harness.onAuthStateChange.mockReset().mockImplementation((listener) => {
      harness.listener = listener
      return { data: { subscription: { unsubscribe: vi.fn() } } }
    })
    harness.resolveAccess.mockReset().mockResolvedValue(access('A'))
  })

  afterEach(() => cleanup())

  it('não refaz o bootstrap quando o token é renovado para a mesma pessoa', async () => {
    render(<App />)
    await waitFor(() => expect(screen.getAllByText('Clínica A').length).toBeGreaterThan(0))
    expect(harness.resolveAccess).toHaveBeenCalledTimes(1)

    act(() => { harness.listener?.('TOKEN_REFRESHED', session('A')) })
    act(() => { harness.listener?.('SIGNED_IN', session('A')) })
    act(() => { harness.listener?.('USER_UPDATED', session('A')) })

    // Sem novo bootstrap não há tela de carregamento, então nada é desmontado
    // e o que o profissional estiver digitando permanece.
    expect(harness.resolveAccess).toHaveBeenCalledTimes(1)
    expect(screen.queryByText('Verificando sessão e vínculos de acesso.')).not.toBeInTheDocument()
    expect(screen.getAllByText('Clínica A').length).toBeGreaterThan(0)
  })

  it('ainda refaz o bootstrap quando a pessoa autenticada muda', async () => {
    render(<App />)
    await waitFor(() => expect(harness.resolveAccess).toHaveBeenCalledTimes(1))

    harness.resolveAccess.mockResolvedValue(access('B'))
    await act(async () => { harness.listener?.('SIGNED_IN', session('B')) })

    await waitFor(() => expect(harness.resolveAccess).toHaveBeenCalledTimes(2))
    await waitFor(() => expect(screen.getAllByText('Clínica B').length).toBeGreaterThan(0))
  })

  it('limpa o acesso ao sair', async () => {
    render(<App />)
    await waitFor(() => expect(harness.resolveAccess).toHaveBeenCalledTimes(1))

    await act(async () => { harness.listener?.('SIGNED_OUT', null) })
    await waitFor(() => expect(screen.getByRole('heading', { name: /de volta/ })).toBeInTheDocument())
  })
})
