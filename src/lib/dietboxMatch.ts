import type { CatalogDataSource, CatalogFoodSummary } from './catalogSearch'

export type DietboxFoodMatch =
  | { status: 'matched'; food: CatalogFoodSummary }
  | { status: 'needs_review'; suggestions: CatalogFoodSummary[]; error?: string }

// Faixa Unicode de acentos combinantes (U+0300–U+036F), mesma técnica de `foldForSearch` em patients.ts.
const COMBINING_DIACRITICS_RE = /[̀-ͯ]/g

function normalizeFoodName(value: string): string {
  return value
    .toLowerCase()
    .normalize('NFD')
    .replace(COMBINING_DIACRITICS_RE, '')
    .replace(/[^a-z0-9]+/g, ' ')
    .trim()
    .replace(/\s+/g, ' ')
}

/** Aceita quando os nomes normalizados são iguais, ou quando um contém todas as palavras do outro. */
function namesAreEquivalent(dietboxName: string, catalogName: string): boolean {
  const a = normalizeFoodName(dietboxName)
  const b = normalizeFoodName(catalogName)
  if (a === b) return true
  const wordsA = a.split(' ')
  const wordsB = new Set(b.split(' '))
  return wordsA.length > 0 && wordsA.every((word) => wordsB.has(word))
}

/**
 * Só autoaceita quando a busca no catálogo devolve exatamente um resultado equivalente.
 * Nomes do Dietbox tendem a divergir da nomenclatura de tabela de composição do catálogo,
 * então a maioria dos alimentos deve mesmo cair em `needs_review` — não é falha do matcher.
 */
export async function matchDietboxFoodName(
  name: string,
  dataSource: CatalogDataSource,
  organizationId: string,
): Promise<DietboxFoodMatch> {
  const response = await dataSource.searchFoods({ organizationId, query: name, page: 1 })
  if (response.error) return { status: 'needs_review', suggestions: [], error: response.error.message }
  const suggestions = response.data?.foods ?? []
  if (suggestions.length === 1 && namesAreEquivalent(name, suggestions[0].name)) {
    return { status: 'matched', food: suggestions[0] }
  }
  return { status: 'needs_review', suggestions }
}

export async function buildDietboxMatchIndex(
  names: string[],
  dataSource: CatalogDataSource,
  organizationId: string,
): Promise<Map<string, DietboxFoodMatch>> {
  const index = new Map<string, DietboxFoodMatch>()
  const byNormalized = new Map<string, string[]>()
  for (const name of names) {
    const key = normalizeFoodName(name)
    byNormalized.set(key, [...(byNormalized.get(key) ?? []), name])
  }
  for (const [, variants] of byNormalized) {
    const match = await matchDietboxFoodName(variants[0], dataSource, organizationId)
    for (const variant of variants) index.set(variant, match)
  }
  return index
}
