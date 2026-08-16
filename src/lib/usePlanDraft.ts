import { useCallback, useEffect, useMemo, useRef, useState } from 'react'
import type { CatalogFoodSummary } from './catalogSearch'
import { emptyNutrients, totalDay, type Meal, type NutrientKey } from './nutrition'
import {
  canPublishPlan,
  completeAssistantStep,
  getPlanQualityIssues,
  initialAssistantState,
  type PlanAssistantState,
} from './planAssistant'
import { comparePlanDays, comparePlanNutrition } from './planComparison'
import { mapDraftRows, type DraftSummary, type EditorDay, type PlanRow } from './planDrafts'
import { getRangeIssues } from './planRanges'
import { isTargetSetEmpty, suggestTargetsForPatient, type TargetSuggestion } from './planTargets'
import { buildShoppingList } from './shoppingList'
import { supabase } from './supabase'

export type PlanTargets = Record<string, number>

export const AUTOSAVE_DELAY_MS = 1500

const DRAFT_SELECT =
  'id,patient_id,title,status,updated_at,' +
  'plan_versions!plan_versions_plan_id_organization_id_fkey(id,version_no,targets,assistant_state,locked_at,' +
  'plan_days(id,label,kind,day_index,meals(id,label,position,equivalency_list_id,' +
  'meal_items(id,food_id,description,grams,nutrient_snapshot,meal_item_substitutions(is_active))))))'

export const cloneMeal = (meal: Meal): Meal => ({
  ...meal,
  id: crypto.randomUUID(),
  items: meal.items.map((item) => ({ ...item, id: crypto.randomUUID() })),
})

export const standardMeals = (): Meal[] => [
  { id: crypto.randomUUID(), name: 'Café da manhã', items: [] },
  { id: crypto.randomUUID(), name: 'Lanche da manhã', items: [] },
  { id: crypto.randomUUID(), name: 'Almoço', items: [] },
  { id: crypto.randomUUID(), name: 'Lanche da tarde', items: [] },
  { id: crypto.randomUUID(), name: 'Jantar', items: [] },
  { id: crypto.randomUUID(), name: 'Ceia', items: [] },
]

export const initialWeek = (): EditorDay[] =>
  ['Segunda-feira', 'Terça-feira', 'Quarta-feira', 'Quinta-feira', 'Sexta-feira', 'Sábado', 'Domingo'].map((label) => ({
    id: crypto.randomUUID(),
    label,
    kind: 'standard',
    meals: standardMeals(),
  }))

/** Um dia só pode ser sobrescrito sem aviso quando não há nada gravado nele. */
export function dayHasContent(day: EditorDay | undefined): boolean {
  return Boolean(day?.meals.some((meal) => meal.items.length > 0))
}

export function toPayloadDays(days: EditorDay[]) {
  return days.map((day, dayIndex) => ({
    day_index: dayIndex,
    label: day.label,
    kind: day.kind,
    meals: day.meals.map((meal, position) => ({
      position,
      label: meal.name,
      name: meal.name,
      equivalency_list_id: meal.equivalencyListId ?? null,
      items: meal.items.map((item, itemPosition) => ({
        position: itemPosition,
        food_id: item.foodId ?? null,
        description: item.name,
        quantity: item.grams,
        unit: 'g',
        grams: item.grams,
        nutrient_snapshot: item.nutrientsPer100g,
      })),
    })),
  }))
}

export function portionFromCatalogFood(food: CatalogFoodSummary, grams: number) {
  const reported = Object.keys(food.nutrients) as NutrientKey[]
  return {
    id: crypto.randomUUID(),
    foodId: food.id,
    name: food.name,
    grams,
    nutrientsPer100g: { ...emptyNutrients(), ...food.nutrients },
    reportedNutrients: reported,
  }
}

export interface UsePlanDraftOptions {
  organizationId: string
  userId: string
  onMessage: (message: string) => void
  autosaveDelayMs?: number
}

export function usePlanDraft({ organizationId, userId, onMessage, autosaveDelayMs = AUTOSAVE_DELAY_MS }: UsePlanDraftOptions) {
  const [days, setDays] = useState<EditorDay[]>(initialWeek())
  const [activeDay, setActiveDay] = useState(0)
  const [baselineDays, setBaselineDays] = useState<EditorDay[] | null>(null)
  const [drafts, setDrafts] = useState<DraftSummary[]>([])
  const [loadingDrafts, setLoadingDrafts] = useState(true)
  const [loadedDraft, setLoadedDraft] = useState<string | null>(null)
  const [loadedVersion, setLoadedVersion] = useState('')
  const [planStatus, setPlanStatus] = useState('draft')
  const [locked, setLocked] = useState(false)
  const [targets, setTargets] = useState<PlanTargets>({ energyKcal: 0, proteinG: 0, carbohydrateG: 0, fatG: 0, fiberG: 0, waterMl: 0 })
  const [assistant, setAssistant] = useState<PlanAssistantState>(initialAssistantState())
  const [confirmSubstitutionWarning, setConfirmSubstitutionWarning] = useState(false)
  const [patientId, setPatientId] = useState('')
  const [title, setTitle] = useState('Plano alimentar')
  const [changeSummary, setChangeSummary] = useState('')
  const [suggestedTargets, setSuggestedTargets] = useState<TargetSuggestion | null>(null)
  const [suggestedObjective, setSuggestedObjective] = useState<string | null>(null)
  const [busy, setBusy] = useState(false)
  const [autosaveState, setAutosaveState] = useState<'idle' | 'saving' | 'saved' | 'error'>('idle')
  const [autosavedAt, setAutosavedAt] = useState<string | null>(null)
  const autosaveFingerprint = useRef('')

  const meals = days[activeDay]?.meals ?? []
  const setMeals = useCallback((update: Meal[] | ((current: Meal[]) => Meal[])) => {
    setDays((all) => all.map((day, index) => (index === activeDay ? { ...day, meals: typeof update === 'function' ? update(day.meals) : update } : day)))
  }, [activeDay])

  const totals = useMemo(() => totalDay(days[activeDay]?.meals ?? []), [days, activeDay])
  const rangeIssues = useMemo(() => getRangeIssues(totals, assistant.targetRanges), [totals, assistant.targetRanges])
  const planChanges = useMemo(() => (baselineDays ? comparePlanDays(baselineDays, days) : []), [baselineDays, days])
  const nutritionChanges = useMemo(() => (baselineDays ? comparePlanNutrition(baselineDays, days) : []), [baselineDays, days])
  const shoppingList = useMemo(() => buildShoppingList(days), [days])

  const loadDrafts = useCallback(async () => {
    setLoadingDrafts(true)
    const result = await supabase.from('plans').select(DRAFT_SELECT).eq('organization_id', organizationId).order('updated_at', { ascending: false })
    setLoadingDrafts(false)
    if (result.error) {
      onMessage(result.error.message)
      setDrafts([])
      return []
    }
    const next = mapDraftRows((result.data ?? []) as unknown as PlanRow[])
    setDrafts(next)
    return next
  }, [organizationId, onMessage])

  useEffect(() => { void loadDrafts() }, [loadDrafts])

  // Metas nascem calculadas a partir da estimativa energética do paciente. O
  // profissional revisa e ajusta; só não precisa digitar tudo do zero.
  useEffect(() => {
    if (!patientId) {
      setSuggestedTargets(null)
      return
    }
    let active = true
    void (async () => {
      const [estimates, assessments] = await Promise.all([
        supabase.from('nutritional_estimates').select('total_energy_expenditure,current_weight_kg').eq('patient_id', patientId).order('calculated_on', { ascending: false }).limit(1),
        supabase.from('assessments').select('objective').eq('patient_id', patientId).order('assessed_at', { ascending: false }).limit(1),
      ])
      if (!active) return
      const estimate = (estimates.data ?? [])[0] ?? null
      const objective = ((assessments.data ?? [])[0] as { objective: string | null } | undefined)?.objective ?? null
      const suggestion = suggestTargetsForPatient(estimate, objective)
      setSuggestedTargets(suggestion)
      setSuggestedObjective(objective)
      if (suggestion) {
        setTargets((current) => (isTargetSetEmpty(current) ? { ...current, ...suggestion } : current))
        setAssistant((current) => (current.objective.trim() ? current : { ...current, objective: objective ?? '' }))
      }
    })()
    return () => { active = false }
  }, [patientId])

  const openDraft = useCallback((draft: DraftSummary) => {
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
    setTargets((current) => ({ ...current, ...draft.targets }))
    setConfirmSubstitutionWarning(false)
    setAutosaveState('idle')
    autosaveFingerprint.current = JSON.stringify({ days: draft.days, targets: draft.targets, assistant: draft.assistantState })
    onMessage(draft.locked ? 'Plano publicado aberto em modo somente leitura.' : `Plano aberto, versão ${draft.version}.`)
  }, [onMessage])

  // Autosave no banco: nenhum dado clínico é gravado no navegador.
  useEffect(() => {
    if (!loadedDraft || !loadedVersion || locked || planStatus !== 'draft') return
    const fingerprint = JSON.stringify({ days, targets, assistant })
    if (fingerprint === autosaveFingerprint.current) return
    const timer = setTimeout(async () => {
      setAutosaveState('saving')
      const result = await supabase.rpc('autosave_plan_version', {
        target_plan_id: loadedDraft,
        target_version_id: loadedVersion,
        target_assistant_state: assistant,
        target_targets: targets,
        target_days: toPayloadDays(days),
      })
      if (result.error) {
        setAutosaveState('error')
        onMessage(`Gravação automática falhou: ${result.error.message}`)
        return
      }
      autosaveFingerprint.current = fingerprint
      setAutosaveState('saved')
      setAutosavedAt(new Date().toISOString())
    }, autosaveDelayMs)
    return () => clearTimeout(timer)
  }, [days, targets, assistant, loadedDraft, loadedVersion, locked, planStatus, autosaveDelayMs, onMessage])

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
    setAutosaveState('idle')
    onMessage('Novo plano em branco iniciado.')
  }

  /** Aplica uma transformação às refeições de um dia específico do quadro semanal. */
  function updateDayMeals(dayIndex: number, transform: (meals: Meal[]) => Meal[]) {
    setDays((all) => all.map((day, index) => (index === dayIndex ? { ...day, meals: transform(day.meals) } : day)))
  }

  function addItemToDay(dayIndex: number, mealId: string, food: CatalogFoodSummary, grams: number) {
    if (!Number.isFinite(grams) || grams <= 0) return onMessage('Informe uma quantidade em gramas maior que zero.')
    updateDayMeals(dayIndex, (meals) => meals.map((meal) => (meal.id === mealId ? { ...meal, items: [...meal.items, portionFromCatalogFood(food, grams)] } : meal)))
    onMessage('')
  }

  function removeItemFromDay(dayIndex: number, mealId: string, itemId: string) {
    updateDayMeals(dayIndex, (meals) => meals.map((meal) => (meal.id === mealId ? { ...meal, items: meal.items.filter((item) => item.id !== itemId) } : meal)))
  }

  /** Ajusta a quantidade em gramas sem nunca deixá-la chegar a zero ou negativa. */
  function changeItemGrams(dayIndex: number, mealId: string, itemId: string, delta: number) {
    updateDayMeals(dayIndex, (meals) => meals.map((meal) => (meal.id === mealId
      ? { ...meal, items: meal.items.map((item) => (item.id === itemId ? { ...item, grams: Math.max(5, item.grams + delta) } : item)) }
      : meal)))
  }

  function addItem(mealId: string, food: CatalogFoodSummary, grams: number) {
    addItemToDay(activeDay, mealId, food, grams)
  }

  function removeItem(mealId: string, itemId: string) {
    removeItemFromDay(activeDay, mealId, itemId)
  }

  function addMeal(name: string) {
    setMeals((all) => [...all, { id: crypto.randomUUID(), name, items: [] }])
  }

  function renameDay(index: number, label: string) {
    setDays((all) => all.map((day, position) => (position === index ? { ...day, label } : day)))
  }

  /**
   * Copia o dia ativo para outro dia. Quando o destino já tem conteúdo, exige
   * confirmação explícita para não apagar trabalho sem o profissional perceber.
   */
  function copyDay(sourceIndex: number, targetIndex: number, options: { confirmed?: boolean } = {}) {
    const source = days[sourceIndex]
    const target = days[targetIndex]
    if (!source || !target || targetIndex === sourceIndex) return { needsConfirmation: false, applied: false }
    if (dayHasContent(target) && !options.confirmed) return { needsConfirmation: true, applied: false }
    setDays((all) => all.map((day, index) => (index === targetIndex ? { ...day, meals: source.meals.map(cloneMeal) } : day)))
    onMessage(`Conteúdo de ${source.label} copiado para ${target.label}.`)
    return { needsConfirmation: false, applied: true }
  }

  function copyActiveDayTo(targetIndex: number, options: { confirmed?: boolean } = {}) {
    return copyDay(activeDay, targetIndex, options)
  }

  async function save() {
    if (!patientId) return onMessage('Escolha o paciente antes de salvar.')
    if (!days.length || days.some((day) => !day.meals.length)) return onMessage('Mantenha ao menos uma refeição em cada dia.')
    setBusy(true)
    const result = await supabase.rpc('save_plan_draft', {
      target_organization_id: organizationId,
      target_patient_id: patientId,
      target_title: title.trim() || 'Plano alimentar',
      target_change_summary: changeSummary.trim() || (loadedDraft ? 'Cópia editada de rascunho' : 'Versão inicial'),
      target_assistant_state: assistant,
      target_targets: targets,
      target_days: toPayloadDays(days),
      target_created_by: userId,
    })
    setBusy(false)
    if (result.error) return onMessage(`Falha revertida. ${result.error.message}`)
    const created = result.data as { id?: string } | null
    const next = await loadDrafts()
    const saved = next.find((draft) => draft.id === created?.id)
    if (saved) openDraft(saved)
    onMessage('Plano salvo como novo rascunho, versão 1.')
  }

  async function review() {
    if (!loadedDraft || !loadedVersion) return onMessage('Salve e abra um plano antes de revisar.')
    const issues = getPlanQualityIssues(assistant, targets)
    if (issues.length) return onMessage(issues.join(' '))
    const nextAssistant = completeAssistantStep(assistant, 'review')
    setBusy(true)
    const result = await supabase.rpc('review_plan_version', {
      target_plan_id: loadedDraft,
      target_version_id: loadedVersion,
      target_targets: targets,
      target_assistant_state: nextAssistant,
    })
    setBusy(false)
    if (result.error) return onMessage(`Não foi possível revisar: ${result.error.message}`)
    setAssistant(nextAssistant)
    setPlanStatus('reviewed')
    onMessage('Versão revisada. Confira e publique quando estiver pronta.')
    await loadDrafts()
  }

  async function publish() {
    if (!loadedDraft || !loadedVersion) return onMessage('Abra uma versão revisada antes de publicar.')
    const issues = getPlanQualityIssues(assistant, targets)
    if (issues.length) return onMessage(issues.join(' '))
    if (!canPublishPlan(assistant, planStatus)) return onMessage('Conclua a revisão antes de publicar.')
    const missingSubstitutions = days.some((day) => day.meals.some((meal) => !meal.equivalencyListId && meal.items.some((item) => !item.hasReviewedSubstitution)))
    if (missingSubstitutions && !confirmSubstitutionWarning) {
      setConfirmSubstitutionWarning(true)
      return onMessage('Há refeições sem substituições revisadas. Clique em publicar novamente para confirmar.')
    }
    setBusy(true)
    const result = await supabase.rpc('publish_plan_version', { target_plan_id: loadedDraft, target_version_id: loadedVersion })
    setBusy(false)
    if (result.error) return onMessage(`Não foi possível publicar: ${result.error.message}`)
    setPlanStatus('published')
    setLocked(true)
    setConfirmSubstitutionWarning(false)
    setAssistant(completeAssistantStep(assistant, 'publish'))
    onMessage('Plano publicado e bloqueado para edição.')
    await loadDrafts()
  }

  return {
    days, setDays, activeDay, setActiveDay, baselineDays,
    drafts, loadingDrafts, loadedDraft, loadedVersion, planStatus, locked,
    targets, setTargets, assistant, setAssistant, confirmSubstitutionWarning,
    patientId, setPatientId, title, setTitle, busy,
    autosaveState, autosavedAt,
    meals, setMeals, totals, rangeIssues, planChanges, nutritionChanges, shoppingList,
    changeSummary, setChangeSummary,
    suggestedTargets, suggestedObjective,
    applySuggestedTargets: () => { if (suggestedTargets) setTargets((current) => ({ ...current, ...suggestedTargets })) },
    loadDrafts, openDraft, startBlankPlan,
    addItem, removeItem, addMeal, renameDay, copyActiveDayTo,
    addItemToDay, removeItemFromDay, changeItemGrams, copyDay,
    save, review, publish,
  }
}

export type PlanDraftHook = ReturnType<typeof usePlanDraft>
