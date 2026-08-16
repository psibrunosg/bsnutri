import { useCallback, useEffect, useState } from 'react'
import { supabase } from './supabase'

export interface PortalMealItem {
  id: string
  description: string
  grams: number
  meal_item_substitutions: { id: string; description: string; grams: number; unit: string; professional_note: string | null; is_active: boolean }[]
}

export interface PortalMeal {
  id: string
  label: string
  position: number
  suggested_time: string | null
  meal_items: PortalMealItem[]
}

export interface PortalDay {
  id: string
  label: string
  day_index: number
  meals: PortalMeal[]
}

export interface PortalPlan {
  id: string
  title: string
  published_at: string | null
  plan_versions: { id: string; version_no: number; plan_days: PortalDay[] } | null
}

export interface PortalGoal {
  id: string
  kind: string
  title: string
  target_value: number | null
  target_unit: string | null
}

export interface PortalCheckin {
  id: string
  occurred_on: string
  state: string
  meal_id: string
  note: string | null
}

export interface PortalSubstitutionRequest {
  id: string
  status: string
  professional_note: string | null
  meal_item_id: string
  substitution_id: string
}

export interface PortalContent {
  id: string
  delivered_at: string
  snapshot: { title?: string; body?: string } | null
}

export interface PortalFormAssignment {
  id: string
  status: string
  form_template_versions: { title: string; form_fields: { id: string; label: string; field_type: string; required: boolean; position: number }[] } | null
  form_responses: { values: Record<string, string> }[]
}

export interface PortalWeeklySummary {
  period_days: number
  meal_checkins: number
  completed_meals: number
  water_ml: number
  active_goals: number
}

export interface PortalState {
  plan: PortalPlan | null
  goals: PortalGoal[]
  waterMl: number
  checkins: PortalCheckin[]
  requests: PortalSubstitutionRequest[]
  contents: PortalContent[]
  assignments: PortalFormAssignment[]
  weekly: PortalWeeklySummary | null
  shoppingList: { item_key: string; description: string; total_grams: number; occurrences: number }[]
  photos: { id: string; occurred_on: string; file_name: string; drive_web_url: string | null }[]
  canUploadPhotos: boolean
}

const EMPTY: PortalState = {
  plan: null,
  goals: [],
  waterMl: 0,
  checkins: [],
  requests: [],
  contents: [],
  assignments: [],
  weekly: null,
  shoppingList: [],
  photos: [],
  canUploadPhotos: false,
}

const PLAN_SELECT =
  'id,title,published_at,plan_versions!plans_current_version_tenant_fkey(id,version_no,' +
  'plan_days(id,label,day_index,meals(id,label,position,suggested_time,' +
  'meal_items(id,description,grams,meal_item_substitutions(id,description,grams,unit,professional_note,is_active)))))'

export function today(): string {
  return new Date().toISOString().slice(0, 10)
}

/**
 * Carrega o portal do paciente. Cada módulo falha isoladamente: um erro de água
 * não impede o plano publicado de aparecer.
 */
export function usePatientPortal(patientId: string) {
  const [state, setState] = useState<PortalState>(EMPTY)
  const [loading, setLoading] = useState(true)
  const [errors, setErrors] = useState<string[]>([])

  const reload = useCallback(async () => {
    setLoading(true)
    const day = today()
    const [plan, goals, water, checkins, requests, contents, assignments, weekly, shopping, photos, drive] = await Promise.all([
      supabase.from('plans').select(PLAN_SELECT).eq('patient_id', patientId).eq('status', 'published').order('published_at', { ascending: false }).limit(1),
      supabase.from('patient_goals').select('id,kind,title,target_value,target_unit').eq('patient_id', patientId).eq('active', true).order('created_at', { ascending: false }),
      supabase.from('patient_water_logs').select('amount_ml,occurred_on').eq('patient_id', patientId).eq('occurred_on', day),
      supabase.from('meal_checkins').select('id,occurred_on,state,meal_id,note').eq('patient_id', patientId).order('occurred_on', { ascending: false }).limit(30),
      supabase.from('substitution_requests').select('id,status,professional_note,meal_item_id,substitution_id').eq('patient_id', patientId).order('created_at', { ascending: false }),
      supabase.from('patient_content_deliveries').select('id,delivered_at,snapshot').eq('patient_id', patientId).order('delivered_at', { ascending: false }),
      supabase.from('form_assignments').select('id,status,form_template_versions(title,form_fields(id,label,field_type,required,position)),form_responses(values)').eq('patient_id', patientId).order('assigned_at', { ascending: false }),
      supabase.rpc('get_patient_weekly_summary', { target_patient_id: patientId, target_days: 7 }),
      supabase.rpc('get_current_shopping_list', { target_patient_id: patientId, target_days: 7 }),
      supabase.from('meal_checkin_photos').select('id,occurred_on,file_name,drive_web_url').eq('patient_id', patientId).order('occurred_on', { ascending: false }).limit(20),
      supabase.rpc('get_patient_drive_status', { target_patient_id: patientId }),
    ])

    const collected: string[] = []
    const push = (label: string, message: string | undefined) => { if (message) collected.push(`${label}: ${message}`) }
    push('Plano', plan.error?.message)
    push('Metas', goals.error?.message)
    push('Água', water.error?.message)
    push('Check-ins', checkins.error?.message)
    push('Trocas', requests.error?.message)
    push('Conteúdos', contents.error?.message)
    push('Pré-consulta', assignments.error?.message)
    push('Resumo semanal', weekly.error?.message)
    push('Lista de compras', shopping.error?.message)
    push('Fotos', photos.error?.message)
    push('Drive', drive.error?.message)

    setState({
      plan: ((plan.data ?? []) as unknown as PortalPlan[])[0] ?? null,
      goals: (goals.data ?? []) as PortalGoal[],
      waterMl: ((water.data ?? []) as { amount_ml: number }[])[0]?.amount_ml ?? 0,
      checkins: (checkins.data ?? []) as PortalCheckin[],
      requests: (requests.data ?? []) as PortalSubstitutionRequest[],
      contents: (contents.data ?? []) as unknown as PortalContent[],
      assignments: (assignments.data ?? []) as unknown as PortalFormAssignment[],
      weekly: (weekly.data as PortalWeeklySummary | null) ?? null,
      shoppingList: (shopping.data ?? []) as PortalState['shoppingList'],
      photos: (photos.data ?? []) as PortalState['photos'],
      canUploadPhotos: Boolean((drive.data as { can_upload_photos: boolean }[] | null)?.[0]?.can_upload_photos),
    })
    setErrors(collected)
    setLoading(false)
  }, [patientId])

  useEffect(() => { void reload() }, [reload])

  return { state, loading, errors, reload }
}
