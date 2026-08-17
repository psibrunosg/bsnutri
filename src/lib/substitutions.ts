import type { CatalogFoodSummary } from './catalogSearch'
import { supabase } from './supabase'

export interface PrescribedSubstitutionRow {
  id: string
  meal_item_id: string
  plan_version_id: string
  description: string
  grams: number
  unit: string
  professional_note: string | null
  is_active: boolean
}

export interface SubstitutionInput {
  organizationId: string
  planVersionId: string
  mealItemId: string
  food: CatalogFoodSummary
  grams: number
  note: string | null
  userId: string
}

/**
 * Substituições prescritas pelo profissional para um item do plano.
 * O paciente só enxerga as ativas da versão publicada — quem garante isso é o
 * RLS de `meal_item_substitutions`, não a interface.
 */
export interface SubstitutionDataSource {
  listForVersion(planVersionId: string): Promise<{ data: PrescribedSubstitutionRow[]; error: { message: string } | null }>
  prescribe(input: SubstitutionInput): Promise<{ error: { message: string } | null }>
  setActive(id: string, isActive: boolean): Promise<{ error: { message: string } | null }>
}

/** Agrupa por item do plano para a interface montar a lista de cada alimento. */
export function groupByMealItem(rows: readonly PrescribedSubstitutionRow[]): Map<string, PrescribedSubstitutionRow[]> {
  const grouped = new Map<string, PrescribedSubstitutionRow[]>()
  for (const row of rows) {
    const current = grouped.get(row.meal_item_id) ?? []
    current.push(row)
    grouped.set(row.meal_item_id, current)
  }
  return grouped
}

/**
 * O item precisa já existir no banco para receber substituição: a chave
 * estrangeira aponta para `meal_items`. Item de rascunho ainda não salvo tem
 * identificador só do navegador.
 */
export function isPersistedMealItem(id: string): boolean {
  return /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(id)
}

export function createSupabaseSubstitutionDataSource(): SubstitutionDataSource {
  return {
    async listForVersion(planVersionId) {
      const result = await supabase
        .from('meal_item_substitutions')
        .select('id,meal_item_id,plan_version_id,description,grams,unit,professional_note,is_active')
        .eq('plan_version_id', planVersionId)
        .order('description')
      if (result.error) return { data: [], error: { message: result.error.message } }
      return { data: (result.data ?? []) as PrescribedSubstitutionRow[], error: null }
    },

    async prescribe({ organizationId, planVersionId, mealItemId, food, grams, note, userId }) {
      const result = await supabase.from('meal_item_substitutions').insert({
        organization_id: organizationId,
        plan_version_id: planVersionId,
        meal_item_id: mealItemId,
        substitute_food_id: food.id,
        description: food.name,
        grams,
        unit: 'g',
        professional_note: note,
        nutrient_snapshot: food.nutrients,
        created_by: userId,
      })
      return { error: result.error ? { message: result.error.message } : null }
    },

    async setActive(id, isActive) {
      const result = await supabase.from('meal_item_substitutions').update({ is_active: isActive }).eq('id', id)
      return { error: result.error ? { message: result.error.message } : null }
    },
  }
}
