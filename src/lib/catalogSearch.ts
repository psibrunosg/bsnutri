import type { NutrientKey } from './nutrition'
import { supabase } from './supabase'

export const CATALOG_PAGE_SIZE = 30

/** Códigos aceitos por nutriente no catálogo. Mantido junto do mapeamento que os usa. */
const NUTRIENT_CODE_ALIASES: Record<NutrientKey, string[]> = {
  energyKcal: ['energy_kcal', 'energy', 'kcal'],
  proteinG: ['protein_g', 'protein'],
  carbohydrateG: ['carbohydrate_g', 'carbohydrate', 'carbs'],
  fatG: ['fat_g', 'fat', 'lipids'],
  fiberG: ['fiber_g', 'fiber'],
  sodiumMg: ['sodium_mg', 'sodium'],
  calciumMg: ['calcium_mg', 'calcium'],
  ironMg: ['iron_mg', 'iron'],
  potassiumMg: ['potassium_mg', 'potassium'],
  vitaminCMg: ['vitamin_c_mg', 'vitamin_c'],
  saturatedFatG: ['saturated_fat_g', 'saturated_fat', 'sat_fat'],
  monounsaturatedFatG: ['monounsaturated_fat_g', 'monounsaturated_fat', 'mono_fat'],
  polyunsaturatedFatG: ['polyunsaturated_fat_g', 'polyunsaturated_fat', 'poly_fat'],
  transFatG: ['trans_fat_g', 'trans_fat', 'trans'],
  vitaminB1Mg: ['vitamin_b1_mg', 'vitamin_b1', 'thiamin', 'tiamina'],
  vitaminB2Mg: ['vitamin_b2_mg', 'vitamin_b2', 'riboflavin', 'riboflavina'],
  vitaminB3Mg: ['vitamin_b3_mg', 'vitamin_b3', 'niacin', 'niacina'],
  vitaminB6Mg: ['vitamin_b6_mg', 'vitamin_b6', 'pyridoxine', 'piridoxina'],
  vitaminB9Mcg: ['vitamin_b9_mcg', 'vitamin_b9', 'folate', 'folic_acid', 'folato'],
  vitaminB12Mcg: ['vitamin_b12_mcg', 'vitamin_b12', 'cobalamin', 'cobalamina'],
}

export interface CatalogFoodRow {
  id: string
  name: string
  preparation_state: string
  organization_id: string | null
  household_measure_label: string | null
  household_measure_grams: number | null
  food_sources: { name: string } | null
  food_nutrient_values: { amount_per_100g: number | null; nutrients: { code: string } | null }[] | null
}

export interface CatalogFoodSummary {
  id: string
  name: string
  preparationState: string
  isOwn: boolean
  householdMeasureLabel: string | null
  householdMeasureGrams: number | null
  sourceName: string | null
  /** Somente nutrientes efetivamente informados. Ausente permanece ausente. */
  nutrients: Partial<Record<NutrientKey, number>>
}

export interface CatalogPage {
  foods: CatalogFoodSummary[]
  total: number
  page: number
  pageSize: number
  pageCount: number
}

export interface CatalogSearchInput {
  organizationId: string
  query: string
  page: number
  pageSize?: number
}

export interface CatalogDataSource {
  searchFoods(input: CatalogSearchInput): Promise<{ data: CatalogPage | null; error: { message: string } | null }>
}

const SELECT =
  'id,name,preparation_state,organization_id,household_measure_label,household_measure_grams,' +
  'food_sources(name),food_nutrient_values(amount_per_100g,nutrients(code))'

function nutrientKeyFor(code: string | undefined): NutrientKey | null {
  if (!code) return null
  const normalized = code.toLowerCase()
  const entry = (Object.keys(NUTRIENT_CODE_ALIASES) as NutrientKey[]).find((key) =>
    NUTRIENT_CODE_ALIASES[key].includes(normalized),
  )
  return entry ?? null
}

export function mapCatalogFood(row: CatalogFoodRow): CatalogFoodSummary {
  const nutrients: Partial<Record<NutrientKey, number>> = {}
  for (const value of row.food_nutrient_values ?? []) {
    if (value.amount_per_100g === null || value.amount_per_100g === undefined) continue
    const key = nutrientKeyFor(value.nutrients?.code)
    if (key) nutrients[key] = Number(value.amount_per_100g)
  }
  return {
    id: row.id,
    name: row.name,
    preparationState: row.preparation_state,
    isOwn: row.organization_id !== null,
    householdMeasureLabel: row.household_measure_label,
    householdMeasureGrams: row.household_measure_grams === null ? null : Number(row.household_measure_grams),
    sourceName: row.food_sources?.name ?? null,
    nutrients,
  }
}

/** Escapa os curingas do PostgREST para que a busca trate `%` e `,` como texto. */
export function escapeSearchTerm(query: string): string {
  return query.replace(/[%,()]/g, ' ').replace(/\s+/g, ' ').trim()
}

export function pageRange(page: number, pageSize: number): { from: number; to: number } {
  const safePage = Number.isFinite(page) && page > 0 ? Math.floor(page) : 1
  const from = (safePage - 1) * pageSize
  return { from, to: from + pageSize - 1 }
}

export function createSupabaseCatalogDataSource(): CatalogDataSource {
  return {
    async searchFoods({ organizationId, query, page, pageSize = CATALOG_PAGE_SIZE }) {
      const term = escapeSearchTerm(query)
      const { from, to } = pageRange(page, pageSize)
      let request = supabase
        .from('foods')
        .select(SELECT, { count: 'exact' })
        .or(`organization_id.is.null,organization_id.eq.${organizationId}`)
        .eq('is_active', true)
      if (term) request = request.ilike('name', `%${term}%`)
      const result = await request.order('name').range(from, to)
      if (result.error) return { data: null, error: { message: result.error.message } }
      const total = result.count ?? 0
      return {
        data: {
          foods: ((result.data ?? []) as unknown as CatalogFoodRow[]).map(mapCatalogFood),
          total,
          page: Math.floor(from / pageSize) + 1,
          pageSize,
          pageCount: Math.max(1, Math.ceil(total / pageSize)),
        },
        error: null,
      }
    },
  }
}
