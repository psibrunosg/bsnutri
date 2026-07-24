import { cleanup, fireEvent, render, screen } from '@testing-library/react'
import { afterEach, describe, expect, it } from 'vitest'
import App from './App'

describe('App', () => {
  afterEach(() => cleanup())

  it('apresenta a autenticação do BSNutri', async () => {
    render(<App />)
    expect(await screen.findByText('Bem-vindo de volta')).toBeTruthy()
    expect(screen.getByText('BS Nutrição integrada')).toBeTruthy()
  })

  it('oferece recuperação de senha por e-mail', async () => {
    render(<App />)
    fireEvent.click(await screen.findByRole('button', { name: 'Esqueci minha senha' }))
    expect(screen.getByRole('heading', { name: 'Recupere sua senha' })).toBeTruthy()
    expect(screen.getByRole('button', { name: 'Enviar link de recuperação' })).toBeTruthy()
  })

  it('deixa claro como criar a primeira conta', async () => {
    render(<App />)
    fireEvent.click(await screen.findByRole('button', { name: 'Criar minha conta' }))
    expect(screen.getByRole('heading', { name: 'Crie sua conta' })).toBeTruthy()
    expect(screen.getByText('Depois do cadastro, confirme o e-mail para liberar o acesso.')).toBeTruthy()
  })
})
