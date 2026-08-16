import { act, cleanup, render, screen, waitFor } from '@testing-library/react'
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'
import App from './App'

const harness = vi.hoisted(() => ({
  authListener: undefined as undefined | ((event: string, session: unknown) => void),
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

const session = (id: string) => ({ user: { id, user_metadata: { full_name: id } } })
const access = (id: string) => ({
  kind: 'professional' as const,
  workspace: {
    organizationId: `organization-${id}`,
    organizationName: `Clínica ${id}`,
    memberName: id,
    role: 'nutritionist' as const,
  },
})

describe('App bootstrap generation', () => {
  beforeEach(() => {
    harness.getSession.mockReset().mockResolvedValue({ data: { session: session('A') }, error: null })
    harness.onAuthStateChange.mockReset().mockImplementation((listener) => {
      harness.authListener = listener
      return { data: { subscription: { unsubscribe: vi.fn() } } }
    })
    harness.resolveAccess.mockReset()
  })

  afterEach(() => cleanup())

  it('ignores an old bootstrap after logout and login as another user', async () => {
    let finishA: ((value: ReturnType<typeof access>) => void) | undefined
    let finishB: ((value: ReturnType<typeof access>) => void) | undefined
    harness.resolveAccess.mockImplementation((_source, userId: string) => new Promise((resolve) => {
      if (userId === 'A') finishA = resolve
      else finishB = resolve
    }))

    render(<App />)
    await waitFor(() => expect(finishA).toBeDefined())

    act(() => {
      harness.authListener?.('SIGNED_OUT', null)
      harness.authListener?.('SIGNED_IN', session('B'))
    })
    await waitFor(() => expect(finishB).toBeDefined())
    await act(async () => finishB?.(access('B')))
    await waitFor(() => expect(screen.getAllByText('Clínica B').length).toBeGreaterThan(0))

    await act(async () => finishA?.(access('A')))
    expect(screen.getAllByText('Clínica B').length).toBeGreaterThan(0)
    expect(screen.queryAllByText('Clínica A')).toHaveLength(0)
  })
})
