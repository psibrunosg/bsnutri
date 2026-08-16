import { useCallback, useEffect, useState } from 'react'
import { supabase } from './supabase'

export interface EquivalencyListItem {
  id: string
  equivalencyListId: string
  foodId?: string | null
  description: string
  grams: number
  householdMeasure?: string | null
  caloriesPerPortion: number
  position: number
}

export interface EquivalencyList {
  id: string
  organizationId?: string | null
  title: string
  macroGroup: string
  targetCalories: number
  calorieTolerancePct: number
  description?: string | null
  isActive: boolean
  items: EquivalencyListItem[]
}

type ListRow = {
  id: string
  organization_id?: string | null
  title: string
  macro_group: string
  target_calories: number
  calorie_tolerance_pct: number
  description?: string | null
  is_active: boolean
  equivalency_list_items?: {
    id: string
    equivalency_list_id: string
    food_id?: string | null
    description: string
    grams: number
    household_measure?: string | null
    calories_per_portion: number
    position: number
  }[]
}

export function formatEquivalencyListForDisplay(list: EquivalencyList): string {
  const itemsText = list.items
    .slice()
    .sort((a, b) => a.position - b.position)
    .map(item => {
      const measure = item.householdMeasure ? ` (${item.householdMeasure})` : ''
      return `      • ${item.description} - ${Number(item.grams).toLocaleString('pt-BR')} g${measure} · ~${Number(item.caloriesPerPortion).toLocaleString('pt-BR')} kcal`
    })
    .join('\n')
  return `    [Opções de Troca por Equivalência · ${list.title} (±${list.calorieTolerancePct}%)]\n${itemsText || '      (sem opções cadastradas)'}`
}

export function useEquivalencyLists(organizationId?: string) {
  const [lists, setLists] = useState<EquivalencyList[]>([])
  const [loading, setLoading] = useState(false)
  const [error, setError] = useState<string | null>(null)

  const load = useCallback(async () => {
    setLoading(true)
    setError(null)
    const filterStr = organizationId
      ? `organization_id.is.null,organization_id.eq.${organizationId}`
      : 'organization_id.is.null'

    const { data, error: fetchError } = await supabase
      .from('equivalency_lists')
      .select('id,organization_id,title,macro_group,target_calories,calorie_tolerance_pct,description,is_active,equivalency_list_items(id,equivalency_list_id,food_id,description,grams,household_measure,calories_per_portion,position)')
      .or(filterStr)
      .eq('is_active', true)
      .order('title')
    if (fetchError) {
      setError(fetchError.message)
      setLoading(false)
      return
    }

    const loaded = ((data ?? []) as unknown as ListRow[]).map(row => ({
      id: row.id,
      organizationId: row.organization_id ?? null,
      title: row.title,
      macroGroup: row.macro_group,
      targetCalories: Number(row.target_calories),
      calorieTolerancePct: Number(row.calorie_tolerance_pct),
      description: row.description ?? null,
      isActive: row.is_active,
      items: (row.equivalency_list_items ?? []).sort((a, b) => a.position - b.position).map(item => ({
        id: item.id,
        equivalencyListId: item.equivalency_list_id,
        foodId: item.food_id ?? null,
        description: item.description,
        grams: Number(item.grams),
        householdMeasure: item.household_measure ?? null,
        caloriesPerPortion: Number(item.calories_per_portion),
        position: item.position,
      })),
    }))
    setLists(loaded)
    setLoading(false)
  }, [organizationId])

  useEffect(() => {
    void load()
  }, [load])

  return { lists, loading, error, reload: load }
}
