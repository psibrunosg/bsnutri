import { cleanup, fireEvent, render, screen } from '@testing-library/react'
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'
import App from './App'

const auth = vi.hoisted(() => ({
  listener: undefined as undefined | ((event: string, session: null) => void),
  getSession: vi.fn(),
  onAuthStateChange: vi.fn(),
  signOut: vi.fn(),
  signInWithPassword: vi.fn(),
  signUp: vi.fn(),
  resetPasswordForEmail: vi.fn(),
  updateUser: vi.fn(),
}))

vi.mock('./lib/supabase', () => ({ isSupabaseConfigured: true, supabase: { auth, rpc: vi.fn() } }))

describe('App auth transitions', () => {
  beforeEach(() => {
    auth.getSession.mockReset().mockResolvedValue({ data: { session: null }, error: { message: 'Falha de sessão' } })
    auth.onAuthStateChange.mockReset().mockImplementation((listener) => {
      auth.listener = listener
      return { data: { subscription: { unsubscribe: vi.fn() } } }
    })
    auth.signOut.mockReset().mockImplementation(async () => {
      auth.listener?.('SIGNED_OUT', null)
      return { error: null }
    })
  })

  afterEach(() => cleanup())

  it('clears a getSession error after a successful signed-out transition', async () => {
    render(<App />)
    expect(await screen.findByRole('alert')).toHaveTextContent('Falha de sessão')

    fireEvent.click(screen.getByRole('button', { name: 'Sair' }))

    expect(await screen.findByRole('heading', { name: 'Bem-vinda de volta' })).toBeInTheDocument()
    expect(screen.queryByText('Falha de sessão')).not.toBeInTheDocument()
  })
})
