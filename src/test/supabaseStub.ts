/**
 * Stub encadeável do cliente Supabase para testes de UI.
 * Nenhuma chamada de rede é feita: toda cadeia resolve no resultado informado.
 */
export interface StubResult {
  data: unknown
  error: { message: string } | null
}

const CHAIN_METHODS = [
  'select', 'eq', 'neq', 'gt', 'gte', 'lt', 'lte', 'in', 'is', 'like', 'ilike', 'or',
  'order', 'limit', 'range', 'insert', 'update', 'upsert', 'delete', 'single', 'maybeSingle',
] as const

export function queryStub(result: StubResult = { data: [], error: null }) {
  const chain: Record<string, unknown> = {}
  for (const method of CHAIN_METHODS) chain[method] = () => chain
  chain.then = (resolve: (value: StubResult) => unknown, reject?: (reason: unknown) => unknown) =>
    Promise.resolve(result).then(resolve, reject)
  return chain
}

export function supabaseStub(results: Record<string, StubResult> = {}) {
  return {
    from: (table: string) => queryStub(results[table] ?? { data: [], error: null }),
    rpc: async (name: string) => results[name] ?? { data: null, error: null },
    auth: {
      getSession: async () => ({ data: { session: null }, error: null }),
      onAuthStateChange: () => ({ data: { subscription: { unsubscribe: () => {} } } }),
      signOut: async () => ({ error: null }),
    },
  }
}
