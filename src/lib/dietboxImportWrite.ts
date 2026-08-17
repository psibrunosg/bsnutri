import type { PlanAssistantState } from './planAssistant'
import type { EditorDay } from './planDrafts'
import { supabase } from './supabase'
import { toPayloadDays } from './usePlanDraft'

export interface DietboxSaveDraftInput {
  organizationId: string
  patientId: string
  title: string
  changeSummary: string
  assistantState: PlanAssistantState
  targets: Record<string, number>
  days: EditorDay[]
  userId: string
}

export interface DietboxEquivalencyFoodInput {
  description: string
  grams: number
  householdMeasure: string | null
  foodId: string
  caloriesPerPortion: number
}

export interface DietboxEquivalencyGroupInput {
  organizationId: string
  userId: string
  groupNo: number
  title: string
  foods: DietboxEquivalencyFoodInput[]
}

export interface DietboxEquivalencyListRef {
  id: string
  title: string
}

/** Substitui só o dia de destino, preservando os outros dias da semana do editor. */
export function buildMergedDaysPayload(currentDays: EditorDay[], targetDayIndex: number, importedDay: EditorDay): EditorDay[] {
  return currentDays.map((day, index) => (index === targetDayIndex ? importedDay : day))
}

/** Lê o número do grupo Dietbox a partir de um título gravado como "Grupo {N}: {Título}". */
export function groupNoFromTitle(title: string): number | null {
  const match = /^Grupo\s+(\d+)\s*:/i.exec(title)
  return match ? Number(match[1]) : null
}

export function bucketListsByDietboxGroup(
  rows: DietboxEquivalencyListRef[],
  groupNos: number[],
): Map<number, DietboxEquivalencyListRef[]> {
  const wanted = new Set(groupNos)
  const map = new Map<number, DietboxEquivalencyListRef[]>()
  for (const row of rows) {
    const groupNo = groupNoFromTitle(row.title)
    if (groupNo === null || !wanted.has(groupNo)) continue
    map.set(groupNo, [...(map.get(groupNo) ?? []), row])
  }
  return map
}

const MACRO_GROUP_RULES: [RegExp, string][] = [
  [/carne|prote[íi]na|frango|peixe|ovo|carnes/i, 'protein'],
  [/fruta/i, 'fruit'],
  [/carboidrato|p[ãa]o|arroz|massa|cereal/i, 'carbohydrate'],
  [/gordura|[óo]leo|azeite/i, 'fat'],
  [/leite|laticín|queijo|iogurte/i, 'dairy'],
  [/legume|verdura|hortali[çc]a/i, 'vegetable'],
]

/** Heurística por palavra-chave no título do grupo; o profissional pode ajustar depois. */
export function classifyDietboxMacroGroup(title: string): string {
  const rule = MACRO_GROUP_RULES.find(([re]) => re.test(title))
  return rule ? rule[1] : 'other'
}

export interface DietboxImportDataSource {
  saveDraft(input: DietboxSaveDraftInput): Promise<{ data: { id: string } | null; error: { message: string } | null }>
  insertEquivalencyGroup(
    input: DietboxEquivalencyGroupInput,
  ): Promise<{ data: { id: string } | null; error: { message: string } | null }>
  findEquivalencyListsByDietboxGroup(
    groupNos: number[],
    organizationId: string,
  ): Promise<Map<number, DietboxEquivalencyListRef[]>>
}

export function createSupabaseDietboxImportDataSource(): DietboxImportDataSource {
  return {
    async saveDraft({ organizationId, patientId, title, changeSummary, assistantState, targets, days, userId }) {
      const result = await supabase.rpc('save_plan_draft', {
        target_organization_id: organizationId,
        target_patient_id: patientId,
        target_title: title,
        target_change_summary: changeSummary,
        target_assistant_state: assistantState,
        target_targets: targets,
        target_days: toPayloadDays(days),
        target_created_by: userId,
      })
      if (result.error) return { data: null, error: { message: result.error.message } }
      const created = result.data as { id?: string } | null
      return created?.id ? { data: { id: created.id }, error: null } : { data: null, error: { message: 'Plano criado sem identificador.' } }
    },

    async insertEquivalencyGroup({ organizationId, userId, groupNo, title, foods }) {
      const targetCalories = foods.length
        ? Math.round((foods.reduce((sum, food) => sum + food.caloriesPerPortion, 0) / foods.length) * 100) / 100
        : 0
      const listResult = await supabase
        .from('equivalency_lists')
        .insert({
          organization_id: organizationId,
          title: `Grupo ${groupNo}: ${title}`,
          macro_group: classifyDietboxMacroGroup(title),
          target_calories: targetCalories,
          calorie_tolerance_pct: 10,
          description: 'Importado de uma lista de substituição do Dietbox. Revise a caloria-alvo e a tolerância.',
          created_by: userId,
        })
        .select('id')
        .single()
      if (listResult.error) return { data: null, error: { message: listResult.error.message } }
      const listId = listResult.data.id as string
      if (!foods.length) return { data: { id: listId }, error: null }

      const itemsResult = await supabase.from('equivalency_list_items').insert(
        foods.map((food, position) => ({
          equivalency_list_id: listId,
          food_id: food.foodId,
          description: food.description,
          grams: food.grams,
          household_measure: food.householdMeasure,
          calories_per_portion: food.caloriesPerPortion,
          position,
        })),
      )
      if (itemsResult.error) return { data: { id: listId }, error: { message: itemsResult.error.message } }
      return { data: { id: listId }, error: null }
    },

    async findEquivalencyListsByDietboxGroup(groupNos, organizationId) {
      if (!groupNos.length) return new Map()
      const result = await supabase
        .from('equivalency_lists')
        .select('id,title')
        .or(`organization_id.is.null,organization_id.eq.${organizationId}`)
        .eq('is_active', true)
        .ilike('title', 'Grupo %')
      if (result.error || !result.data) return new Map()
      return bucketListsByDietboxGroup(result.data as DietboxEquivalencyListRef[], groupNos)
    },
  }
}
