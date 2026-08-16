import { cleanup, fireEvent, render, screen } from '@testing-library/react'
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'
import Login from './Login'

const auth = vi.hoisted(() => ({
  signInWithPassword: vi.fn(),
  signUp: vi.fn(),
  resetPasswordForEmail: vi.fn(),
  updateUser: vi.fn(),
}))

vi.mock('../lib/supabase', () => ({ supabase: { auth }, isSupabaseConfigured: true }))
vi.mock('../lib/store', () => ({ useStore: () => ({ setLoggedIn: vi.fn() }) }))

describe('Login', () => {
  beforeEach(() => {
    auth.signInWithPassword.mockReset().mockResolvedValue({ data: { session: null, user: null }, error: { message: 'Credenciais inválidas' } })
    auth.signUp.mockReset().mockResolvedValue({ data: { session: null, user: null }, error: null })
    auth.resetPasswordForEmail.mockReset().mockResolvedValue({ data: {}, error: null })
    auth.updateUser.mockReset().mockResolvedValue({ data: { user: null }, error: null })
  })

  afterEach(() => cleanup())

  it('submits email and password to Supabase and displays an authentication error', async () => {
    render(<Login />)
    fireEvent.change(screen.getByLabelText('E-mail'), { target: { value: 'ana@example.com' } })
    fireEvent.change(screen.getByLabelText('Senha'), { target: { value: 'senha-segura' } })
    fireEvent.click(screen.getByRole('button', { name: 'Entrar no consultório' }))

    expect(auth.signInWithPassword).toHaveBeenCalledWith({ email: 'ana@example.com', password: 'senha-segura' })
    expect(await screen.findByRole('alert')).toHaveTextContent('Credenciais inválidas')
  })

  it('creates an account through Supabase without a prefilled identity', async () => {
    render(<Login />)
    expect(screen.getByLabelText('E-mail')).toHaveValue('')
    fireEvent.click(screen.getByRole('button', { name: 'Criar minha conta' }))
    fireEvent.change(screen.getByLabelText('Nome completo'), { target: { value: 'Ana Souza' } })
    fireEvent.change(screen.getByLabelText('E-mail'), { target: { value: 'ana@example.com' } })
    fireEvent.change(screen.getByLabelText('Senha'), { target: { value: 'senha-segura' } })
    fireEvent.click(screen.getByRole('button', { name: 'Cadastrar' }))

    expect(auth.signUp).toHaveBeenCalledWith({
      email: 'ana@example.com',
      password: 'senha-segura',
      options: { data: { full_name: 'Ana Souza' } },
    })
    expect(await screen.findByRole('status')).toHaveTextContent('Cadastro realizado. Confira seu e-mail.')
  })

  it('requests password recovery through Supabase', async () => {
    render(<Login />)
    fireEvent.click(screen.getByRole('button', { name: 'Esqueci minha senha' }))
    fireEvent.change(screen.getByLabelText('E-mail'), { target: { value: 'ana@example.com' } })
    fireEvent.click(screen.getByRole('button', { name: 'Enviar link de recuperação' }))

    expect(auth.resetPasswordForEmail).toHaveBeenCalledWith('ana@example.com', expect.objectContaining({ redirectTo: expect.any(String) }))
    expect(await screen.findByRole('status')).toHaveTextContent('Enviamos o link de recuperação.')
  })
})
