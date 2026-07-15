import { fireEvent, render, screen } from '@testing-library/react'
import { describe, expect, it } from 'vitest'
import App from './App'

describe('App', () => {
  it('apresenta a autenticação do BSNutri', async () => {
    render(<App />)
    expect(await screen.findByText('Bem-vindo de volta')).toBeInTheDocument()
    expect(screen.getByText('BSNutri')).toBeInTheDocument()
  })

  it('oferece recuperação de senha por e-mail', async () => {
    render(<App />)
    fireEvent.click(await screen.findByRole('button', { name: 'Esqueci minha senha' }))
    expect(screen.getByRole('heading', { name: 'Recupere sua senha' })).toBeInTheDocument()
    expect(screen.getByRole('button', { name: 'Enviar link de recuperação' })).toBeInTheDocument()
  })

  it('deixa claro como criar a primeira conta', async () => {
    render(<App />)
    fireEvent.click(await screen.findByRole('button', { name: 'Criar minha conta' }))
    expect(screen.getByRole('heading', { name: 'Crie sua conta' })).toBeInTheDocument()
    expect(screen.getByText('Depois do cadastro, confirme o e-mail para liberar o acesso.')).toBeInTheDocument()
  })
})
