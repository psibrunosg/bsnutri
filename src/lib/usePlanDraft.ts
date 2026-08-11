import { useCallback, useEffect, useMemo, useRef, useState } from 'react'
import { totalDay, type Meal } from './nutrition'
import { builtInPlanModels, type ModelDimensions, type ModelRules } from './planModels'
import {
  canPublishPlan,
  completeAssistantStep,
  getPlanQualityIssues,
  initialAssistantState,
  sanitizeAssistantState,
  type PlanAssistantState,
} from './planAssistant'
import { supabase } from './supabase'
import { mapDraftRows, type DraftSummary, type EditorDay, type PlanRow } from './planDrafts'
import { getRangeIssues } from './planRanges'
import { comparePlanDays, comparePlanNutrition } from './planComparison'
import type { NutritionalEstimateRow } from '../types'
import { buildShoppingList } from './shoppingList'
import type { CatalogFood, FoodPreference } from './useFoodCatalog'

export type Patient = { id: string; anonymous_code: string; full_name: string }
export type EditorMode = 'quick' | 'technical'
export type PlanTemplate = { id: string; name: string; objective: string | null; tags: string[]; created_at: string; scope: 'personal' | 'organization'; dimensions: ModelDimensions; rules: ModelRules }
export type LocalPlanDraft = { patientId: string; title: string; days: EditorDay[]; activeDay: number; targets: Record<string, number>; assistant: PlanAssistantState; editorMode: EditorMode; savedAt: string }

export function localDraftFingerprint(draft: LocalPlanDraft) {
  const { savedAt: _savedAt, ...content } = draft
  return JSON.stringify(content)
}

export const cloneMeal = (meal: Meal): Meal => ({
  ...meal,
  id: crypto.randomUUID(),
  items: meal.items.map(item => ({ ...item, id: crypto.randomUUID() })),
})
export const cloneDay = (day: EditorDay): EditorDay => ({
  ...day,
  id: crypto.randomUUID(),
  label: `${day.label} copia`,
  meals: day.meals.map(cloneMeal),
})

export const initialDay = (): EditorDay => ({
  id: crypto.randomUUID(),
  label: 'Dia 1',
  kind: 'standard',
  meals: [{ id: crypto.randomUUID(), name: 'Café da manhã', items: [] }],
})

export const standardMeals = (): Meal[] => [
  { id: crypto.randomUUID(), name: 'Café da manhã', items: [] },
  { id: crypto.randomUUID(), name: 'Lanche da manhã', items: [] },
  { id: crypto.randomUUID(), name: 'Almoço', items: [] },
  { id: crypto.randomUUID(), name: 'Lanche da tarde', items: [] },
  { id: crypto.randomUUID(), name: 'Jantar', items: [] },
  { id: crypto.randomUUID(), name: 'Ceia', items: [] },
]

export const initialWeek = (): EditorDay[] => {
  const labels = ['Segunda-feira', 'Terça-feira', 'Quarta-feira', 'Quinta-feira', 'Sexta-feira', 'Sábado', 'Domingo']
  return labels.map(label => ({
    id: crypto.randomUUID(),
    label,
    kind: 'standard',
    meals: standardMeals(),
  }))
}

export interface CatalogRef {
  foods: CatalogFood[]
  saveFoodPreference: (foodId: string, change: Partial<Pick<FoodPreference, 'is_favorite' | 'last_used_at'>>) => Promise<void>
}

export function usePlanDraft(
  organizationId: string,
  userId: string,
  catalog: CatalogRef,
  setMessage: (msg: string) => void,
  setTab: (tab: 'catalog' | 'plan') => void
) {
  const autosaveKey = `bsnutri:plan-draft:${organizationId}`
  const [days, setDays] = useState<EditorDay[]>(initialWeek())
  const [activeDay, setActiveDay] = useState(0)
  const [baselineDays, setBaselineDays] = useState<EditorDay[] | null>(null)
  const [drafts, setDrafts] = useState<DraftSummary[]>([])
  const [templates, setTemplates] = useState<PlanTemplate[]>([])
  const [loadedDraft, setLoadedDraft] = useState<string | null>(null)
  const [loadingDrafts, setLoadingDrafts] = useState(true)
  const [loadedVersion, setLoadedVersion] = useState('')
  const [planStatus, setPlanStatus] = useState('draft')
  const [locked, setLocked] = useState(false)
  const [targets, setTargets] = useState<Record<string, number>>({ energyKcal: 0, proteinG: 0, carbohydrateG: 0, fatG: 0, fiberG: 0, waterMl: 0 })
  const [assistant, setAssistant] = useState<PlanAssistantState>(initialAssistantState())
  const [editorMode, setEditorMode] = useState<EditorMode>('quick')
  const [confirmSubstitutionWarning, setConfirmSubstitutionWarning] = useState(false)
  const [contextCollapsed, setContextCollapsed] = useState(false)
  const [analysisCollapsed, setAnalysisCollapsed] = useState(false)
  const [modelFilters, setModelFilters] = useState<Partial<ModelDimensions>>({})
  const [recoverableDraft, setRecoverableDraft] = useState<LocalPlanDraft | null>(null)
  const [autosaveReady, setAutosaveReady] = useState(false)
  const autosaveBaselineRef = useRef('')
  const initialAutosaveRef = useRef<LocalPlanDraft | null>(null)
  const [patientId, setPatientId] = useState('')
  const [title, setTitle] = useState('Plano alimentar')
  const [busy, setBusy] = useState(false)
  const [patientWeightKg, setPatientWeightKg] = useState<number | null>(null)
  const [latestEstimate, setLatestEstimate] = useState<NutritionalEstimateRow | null>(null)
  const [showShoppingList, setShowShoppingList] = useState(false)

  const meals = days[activeDay]?.meals ?? []
  const setMeals: React.Dispatch<React.SetStateAction<Meal[]>> = update =>
    setDays(all =>
      all.map((day, index) =>
        index === activeDay ? { ...day, meals: typeof update === 'function' ? update(day.meals) : update } : day
      )
    )

  const totals = useMemo(() => totalDay(days[activeDay]?.meals ?? []), [days, activeDay])
  const rangeIssues = useMemo(() => getRangeIssues(totals, assistant.targetRanges), [totals, assistant.targetRanges])
  const planChanges = useMemo(() => (baselineDays ? comparePlanDays(baselineDays, days) : []), [baselineDays, days])
  const nutritionChanges = useMemo(() => (baselineDays ? comparePlanNutrition(baselineDays, days) : []), [baselineDays, days])
  const shoppingList = useMemo(() => buildShoppingList(days), [days])

  const loadDrafts = useCallback(async () => {
    setLoadingDrafts(true)
    const [result, templateResult] = await Promise.all([
      supabase
        .from('plans')
        .select(
          'id,patient_id,title,status,updated_at,plan_versions!plan_versions_plan_id_organization_id_fkey(id,version_no,targets,assistant_state,locked_at,plan_days(id,label,kind,day_index,meals(id,label,position,equivalency_list_id,meal_items(id,food_id,description,grams,nutrient_snapshot,meal_item_substitutions(is_active))))))'
        )
        .eq('organization_id', organizationId)
        .order('updated_at', { ascending: false }),
      supabase
        .from('plan_templates')
        .select('id,name,objective,tags,created_at,scope,dimensions,rules')
        .eq('organization_id', organizationId)
        .order('created_at', { ascending: false }),
    ])
    if (result.error || templateResult.error) {
      setMessage(result.error?.message ?? templateResult.error?.message ?? 'Erro ao carregar planos.')
      setDrafts([])
      setLoadingDrafts(false)
      return []
    }
    const nextDrafts = mapDraftRows((result.data ?? []) as unknown as PlanRow[])
    setDrafts(nextDrafts)
    setTemplates((templateResult.data ?? []) as PlanTemplate[])
    setLoadingDrafts(false)
    return nextDrafts
  }, [organizationId, setMessage])

  useEffect(() => {
    void loadDrafts()
  }, [loadDrafts])

  useEffect(() => {
    if (!patientId) {
      setPatientWeightKg(null)
      setLatestEstimate(null)
      return
    }
    let active = true
    Promise.all([
      supabase
        .from('anthropometry')
        .select('weight_kg')
        .eq('patient_id', patientId)
        .order('measured_at', { ascending: false }),
      supabase
        .from('nutritional_estimates')
        .select('*')
        .eq('patient_id', patientId)
        .order('calculated_on', { ascending: false }),
    ]).then(([anthro, estimates]) => {
      if (active) {
        setPatientWeightKg(((anthro.data ?? []) as { weight_kg: number | null }[])[0]?.weight_kg ?? null)
        setLatestEstimate(((estimates.data ?? []) as unknown as NutritionalEstimateRow[])[0] ?? null)
      }
    })
    return () => {
      active = false
    }
  }, [patientId])

  if (!initialAutosaveRef.current) {
    initialAutosaveRef.current = { patientId, title, days, activeDay, targets, assistant, editorMode, savedAt: '' }
  }

  useEffect(() => {
    const current = initialAutosaveRef.current
    if (!current) return
    autosaveBaselineRef.current = localDraftFingerprint(current)
    try {
      const raw = localStorage.getItem(autosaveKey)
      if (raw) setRecoverableDraft(JSON.parse(raw) as LocalPlanDraft)
    } catch {}
    setAutosaveReady(true)
  }, [autosaveKey])

  useEffect(() => {
    if (!autosaveReady) return
    const draft = { patientId, title, days, activeDay, targets, assistant, editorMode, savedAt: new Date().toISOString() } satisfies LocalPlanDraft
    if (localDraftFingerprint(draft) === autosaveBaselineRef.current) return
    localStorage.setItem(autosaveKey, JSON.stringify(draft))
  }, [autosaveReady, autosaveKey, patientId, title, days, activeDay, targets, assistant, editorMode])

  function openDraft(draft: DraftSummary) {
    setPatientId(draft.patientId)
    setTitle(draft.title)
    setDays(draft.days.length ? draft.days : initialWeek())
    setBaselineDays(structuredClone(draft.days))
    setActiveDay(0)
    setLoadedDraft(draft.id)
    setLoadedVersion(draft.versionId)
    setPlanStatus(draft.status)
    setLocked(draft.locked)
    setAssistant(draft.assistantState)
    setTargets(current => ({ ...current, ...draft.targets }))
    setConfirmSubstitutionWarning(false)
    setTab('plan')
    setMessage(draft.locked ? 'Plano publicado aberto em modo somente leitura.' : `Plano aberto, versão ${draft.version}.`)
  }

  function restoreLocalDraft() {
    if (!recoverableDraft) return
    const restoredDays = recoverableDraft.days.length ? recoverableDraft.days : initialWeek()
    const restored = {
      ...recoverableDraft,
      days: restoredDays,
      activeDay: Number.isInteger(recoverableDraft.activeDay)
        ? Math.min(Math.max(recoverableDraft.activeDay, 0), restoredDays.length - 1)
        : 0,
      assistant: sanitizeAssistantState(recoverableDraft.assistant),
    }
    autosaveBaselineRef.current = localDraftFingerprint(restored)
    setPatientId(restored.patientId)
    setTitle(restored.title)
    setDays(restored.days)
    setActiveDay(restored.activeDay)
    setTargets(restored.targets)
    setAssistant(restored.assistant)
    setEditorMode(restored.editorMode)
    setLoadedDraft(null)
    setLoadedVersion('')
    setPlanStatus('draft')
    setLocked(false)
    setRecoverableDraft(null)
    setAutosaveReady(true)
    setTab('plan')
    setMessage('Rascunho local restaurado.')
  }

  function discardLocalDraft() {
    localStorage.removeItem(autosaveKey)
    autosaveBaselineRef.current = localDraftFingerprint({ patientId, title, days, activeDay, targets, assistant, editorMode, savedAt: '' })
    setRecoverableDraft(null)
    setAutosaveReady(true)
    setMessage('Rascunho local descartado.')
  }

  function startBlankPlan() {
    setTitle('Plano alimentar')
    setDays(initialWeek())
    setBaselineDays(null)
    setActiveDay(0)
    setLoadedDraft(null)
    setLoadedVersion('')
    setPlanStatus('draft')
    setLocked(false)
    setAssistant(initialAssistantState())
    setTargets({ energyKcal: 0, proteinG: 0, carbohydrateG: 0, fatG: 0, fiberG: 0, waterMl: 0 })
    setConfirmSubstitutionWarning(false)
    setTab('plan')
    setMessage('Novo plano em branco iniciado.')
  }

  function copyOpenDraft() {
    if (!loadedDraft) return setMessage('Abra um plano anterior para usar como base.')
    setTitle(`${title} copia`)
    setLoadedDraft(null)
    setLoadedVersion('')
    setPlanStatus('draft')
    setLocked(false)
    setConfirmSubstitutionWarning(false)
    setTab('plan')
    setMessage('Plano aberto copiado como base. Salve para criar um novo rascunho.')
  }

  async function review() {
    if (!loadedDraft || !loadedVersion) return setMessage('Salve e abra um plano antes de revisar.')
    const issues = getPlanQualityIssues(assistant, targets)
    if (issues.length) {
      setEditorMode('technical')
      return setMessage(issues.join(' '))
    }
    const nextAssistant = completeAssistantStep(assistant, 'review')
    setBusy(true)
    const { error } = await supabase.rpc('review_plan_version', {
      target_plan_id: loadedDraft,
      target_version_id: loadedVersion,
      target_targets: targets,
      target_assistant_state: nextAssistant,
    })
    setBusy(false)
    if (error) return setMessage(`Não foi possível revisar: ${error.message}`)
    setAssistant(nextAssistant)
    setPlanStatus('reviewed')
    setMessage('Versão revisada. Confira e publique quando estiver pronta.')
    await loadDrafts()
  }

  async function publish() {
    if (!loadedDraft || !loadedVersion) return setMessage('Abra uma versão revisada antes de publicar.')
    const issues = getPlanQualityIssues(assistant, targets)
    if (issues.length) {
      setEditorMode('technical')
      return setMessage(issues.join(' '))
    }
    if (!canPublishPlan(assistant, planStatus)) return setMessage('Conclua a revisão do assistente antes de publicar.')
    const missingSubstitutions = days.some(day => day.meals.some(meal => !meal.equivalencyListId && meal.items.some(item => !item.hasReviewedSubstitution)))
    if (missingSubstitutions && !confirmSubstitutionWarning) {
      setConfirmSubstitutionWarning(true)
      return setMessage('Aviso: ha refeicoes sem substituicoes revisadas. Clique em Publicar novamente para confirmar.')
    }
    setBusy(true)
    const { error } = await supabase.rpc('publish_plan_version', { target_plan_id: loadedDraft, target_version_id: loadedVersion })
    setBusy(false)
    if (error) return setMessage(`Não foi possível publicar: ${error.message}`)
    setPlanStatus('published')
    setLocked(true)
    setConfirmSubstitutionWarning(false)
    setAssistant(completeAssistantStep(assistant, 'publish'))
    setMessage('Plano publicado e bloqueado para edição.')
    await loadDrafts()
  }

  const currentDimensions = (): ModelDimensions => ({
    approaches: assistant.clinicalPresets,
    objectives: assistant.objective ? [assistant.objective] : [],
    restrictions: [],
    preferences: [],
    contexts: [],
  })

  async function saveTemplate(scope: 'personal' | 'organization') {
    if (!loadedDraft) return setMessage('Abra um plano antes de salvar como modelo.')
    const name = window.prompt('Nome do modelo:', title)?.trim()
    if (!name) return
    const { error } = await supabase.rpc('create_plan_template_from_plan_v2', {
      target_plan_id: loadedDraft,
      target_name: name,
      target_scope: scope,
      target_dimensions: currentDimensions(),
      target_rules: { targets, guidance: [] },
    })
    if (error) setMessage(error.message)
    else {
      setMessage(scope === 'personal' ? 'Modelo pessoal salvo.' : 'Modelo compartilhado com a clínica.')
      await loadDrafts()
    }
  }

  async function copyTemplate(templateId: string, weekdays?: string[]) {
    if (!patientId) return setMessage('Selecione um paciente antes de aplicar o modelo.')
    const { data, error } = await supabase.rpc('apply_plan_template_to_patient', {
      target_template_id: templateId,
      target_patient_id: patientId,
      ...(weekdays?.length ? { target_weekdays: weekdays } : {}),
    })
    if (error) setMessage(error.message)
    else {
      const nextDrafts = await loadDrafts()
      const copiedId = typeof data === 'string' ? data : (data as { id?: string } | null)?.id
      const copiedDraft = nextDrafts.find(draft => draft.id === copiedId)
      if (copiedDraft) openDraft(copiedDraft)
      setMessage(
        copiedDraft
          ? `Modelo aplicado em rascunho independente (${weekdays?.length ?? 1} dia(s)). Revise antes de publicar.`
          : 'Modelo aplicado para novo rascunho.'
      )
    }
  }

  function requestApplyTemplate(templateId: string, _name: string) {
    if (!patientId) return setMessage('Selecione um paciente antes de aplicar o modelo.')
    void copyTemplate(templateId, ['mon', 'tue', 'wed', 'thu', 'fri', 'sat', 'sun'])
  }

  function applyBuiltInModel(model: (typeof builtInPlanModels)[number]) {
    if (!patientId) return setMessage('Selecione um paciente antes de aplicar o modelo.')
    setTitle(model.name)
    setTargets(model.rules.targets)
    setAssistant(current => ({
      ...current,
      objective: model.dimensions.objectives[0] ?? current.objective,
      clinicalPresets: [],
      priorityMicronutrients: [],
      currentStep: 'objective',
      completedSteps: [],
    }))
    setDays(initialWeek())
    setBaselineDays(null)
    setActiveDay(0)
    setLoadedDraft(null)
    setLoadedVersion('')
    setPlanStatus('draft')
    setLocked(false)
    setTab('plan')
    setMessage('Modelo aplicado em rascunho local. Ajuste metas e refeições antes de salvar.')
  }

  function duplicateActiveDay() {
    const source = days[activeDay]
    if (!source) return
    setDays(all => {
      const next = [...all.slice(0, activeDay + 1), cloneDay(source), ...all.slice(activeDay + 1)]
      setActiveDay(activeDay + 1)
      return next
    })
    setMessage('Dia duplicado.')
  }

  function duplicateMeal(meal: Meal) {
    setMeals(all => {
      const index = all.findIndex(item => item.id === meal.id)
      if (index < 0) return all
      return [...all.slice(0, index + 1), cloneMeal({ ...meal, name: `${meal.name} copia` }), ...all.slice(index + 1)]
    })
    setMessage('Refeicao duplicada.')
  }

  function applyActiveStructureToAllDays() {
    const source = days[activeDay]
    if (!source) return
    setDays(all => all.map((day, index) => (index === activeDay ? day : { ...day, meals: source.meals.map(cloneMeal) })))
    setMessage('Estrutura de refeições aplicada aos demais dias.')
  }

  function addItem(mealId: string, foodId: string, grams: number) {
    const food = catalog.foods.find(f => f.id === foodId)
    if (!food || grams <= 0 || !Number.isFinite(grams)) return setMessage('Selecione alimento e gramas válidos.')
    setMeals(all =>
      all.map(m =>
        m.id === mealId
          ? { ...m, items: [...m.items, { id: crypto.randomUUID(), foodId: food.id, name: food.name, grams, nutrientsPer100g: food.nutrients }] }
          : m
      )
    )
    void catalog.saveFoodPreference(foodId, { last_used_at: new Date().toISOString() })
    setMessage('')
  }

  async function save() {
    if (!patientId || !days.length || days.some(day => !day.meals.length))
      return setMessage('Escolha o paciente e mantenha ao menos uma refeição em cada dia.')
    setBusy(true)
    setMessage('')
    try {
      const payloadDays = days.map((day, dayIndex) => ({
        day_index: dayIndex,
        label: day.label,
        kind: day.kind,
        meals: day.meals.map((meal, position) => ({
          position,
          label: meal.name,
          name: meal.name,
          equivalency_list_id: meal.equivalencyListId ?? null,
          equivalencyListId: meal.equivalencyListId ?? null,
          items: meal.items.map((item, itemPos) => ({
            position: itemPos,
            food_id: item.foodId ?? catalog.foods.find(f => f.name === item.name)?.id ?? null,
            description: item.name,
            name: item.name,
            quantity: item.grams,
            unit: 'g',
            grams: item.grams,
            nutrient_snapshot: item.nutrientsPer100g,
          })),
        })),
      }))

      const { error } = await supabase.rpc('save_plan_draft', {
        target_organization_id: organizationId,
        target_patient_id: patientId,
        target_title: title.trim() || 'Plano alimentar',
        target_change_summary: loadedDraft ? 'Cópia editada de rascunho' : 'Versão inicial',
        target_assistant_state: assistant,
        target_targets: targets,
        target_days: payloadDays,
        target_created_by: userId,
      })

      if (error) throw error

      setMessage('Plano salvo como novo rascunho, versão 1.')
      setDays(initialWeek())
      setActiveDay(0)
      setLoadedDraft(null)
      setLoadedVersion('')
      setPlanStatus('draft')
      setLocked(false)
      setAssistant(initialAssistantState())
      await loadDrafts()
    } catch (error) {
      setMessage(`Falha revertida. ${error instanceof Error ? error.message : typeof error === 'object' && error && 'message' in error ? String((error as { message: unknown }).message) : String(error)}`)
    } finally {
      setBusy(false)
    }
  }

  return {
    days,
    setDays,
    activeDay,
    setActiveDay,
    baselineDays,
    drafts,
    templates,
    loadedDraft,
    loadingDrafts,
    loadedVersion,
    planStatus,
    locked,
    targets,
    setTargets,
    assistant,
    setAssistant,
    editorMode,
    setEditorMode,
    confirmSubstitutionWarning,
    contextCollapsed,
    setContextCollapsed,
    analysisCollapsed,
    setAnalysisCollapsed,
    modelFilters,
    setModelFilters,
    recoverableDraft,
    patientId,
    setPatientId,
    title,
    setTitle,
    busy,
    patientWeightKg,
    latestEstimate,
    showShoppingList,
    setShowShoppingList,
    meals,
    setMeals,
    totals,
    rangeIssues,
    planChanges,
    nutritionChanges,
    shoppingList,
    loadDrafts,
    openDraft,
    restoreLocalDraft,
    discardLocalDraft,
    startBlankPlan,
    copyOpenDraft,
    review,
    publish,
    saveTemplate,
    copyTemplate,
    requestApplyTemplate,
    applyBuiltInModel,
    duplicateActiveDay,
    duplicateMeal,
    applyActiveStructureToAllDays,
    addItem,
    save,
  }
}
export type PlanDraftHook = ReturnType<typeof usePlanDraft>
