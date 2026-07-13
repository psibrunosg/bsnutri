import { render, screen } from '@testing-library/react'
import { describe, expect, it } from 'vitest'
import App from './App'

describe('App', () => {
  it('apresenta a autenticação do BSNutri', async () => {
    render(<App />)
    expect(await screen.findByText('Bem-vindo de volta')).toBeInTheDocument()
    expect(screen.getByText('BSNutri')).toBeInTheDocument()
  })
})
