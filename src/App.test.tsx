import { cleanup, render, screen } from '@testing-library/react'
import { afterEach, describe, expect, it, vi } from 'vitest'

vi.mock('./lib/supabase', () => ({ isSupabaseConfigured: false, supabase: {} }))

const { App } = await import('./App')

describe('App', () => {
  afterEach(() => cleanup())

  it('refuses to run without Supabase configuration instead of failing silently', () => {
    render(<App />)
    expect(screen.getByRole('heading', { name: 'Configuração necessária' })).toBeInTheDocument()
    expect(screen.getByRole('alert')).toHaveTextContent('VITE_SUPABASE_URL')
  })
})
