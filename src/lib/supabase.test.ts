import { afterEach, expect, it, vi } from 'vitest'

afterEach(() => {
  vi.unstubAllEnvs()
  vi.resetModules()
})

it('reports that Supabase is unavailable when public configuration is absent', async () => {
  vi.stubEnv('VITE_SUPABASE_URL', undefined)
  vi.stubEnv('VITE_SUPABASE_ANON_KEY', undefined)
  vi.resetModules()

  const client = await import('./supabase')

  expect(client.isSupabaseConfigured).toBe(false)
})
