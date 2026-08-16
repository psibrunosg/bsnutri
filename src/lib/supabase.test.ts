import { expect, it } from 'vitest'

import * as client from './supabase'

it('reports that Supabase is unavailable when public configuration is absent', () => {
  expect((client as { isSupabaseConfigured?: boolean }).isSupabaseConfigured).toBe(false)
})
