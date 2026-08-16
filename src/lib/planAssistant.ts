export const assistantSteps = ['objective', 'targets', 'meals', 'equivalents', 'review', 'publish'] as const

export type PlanAssistantStep = (typeof assistantSteps)[number]
export const clinicalPresets = ['weight_loss', 'hypertrophy', 'insulin_resistance', 'hypertension', 'vegetarian', 'child_teen'] as const
export type ClinicalPreset = (typeof clinicalPresets)[number]
type PlanTargets = Record<string, number | undefined>

export type PlanAssistantState = {
  currentStep: PlanAssistantStep
  completedSteps: PlanAssistantStep[]
  objective: string
  clinicalPresets: ClinicalPreset[]
  priorityMicronutrients: string[]
  visibility: PlanVisibility
  targetRanges: NutrientRanges
  rangeJustification: string
  mealDistributions: Record<string, number>
}

export type PlanVisibility = {
  showTotalKcal: boolean
  showTotalMacros: boolean
  showMealCalculations: boolean
  showDiary: boolean
}

export const assistantLabels: Record<PlanAssistantStep, string> = {
  objective: 'Objetivo',
  targets: 'Metas',
  meals: 'Refeições',
  equivalents: 'Equivalentes',
  review: 'Revisão',
  publish: 'Publicação',
}

export const clinicalPresetLabels: Record<ClinicalPreset, string> = {
  weight_loss: 'Emagrecimento',
  hypertrophy: 'Hipertrofia',
  insulin_resistance: 'Resistencia a insulina',
  hypertension: 'Hipertensao',
  vegetarian: 'Vegetariano',
  child_teen: 'Crianca/adolescente',
}

const presetMicronutrients: Record<ClinicalPreset, string[]> = {
  weight_loss: ['Fibra', 'Potassio', 'Vitamina C'],
  hypertrophy: ['Ferro', 'Calcio', 'Vitamina C'],
  insulin_resistance: ['Fibra', 'Magnesio', 'Potassio'],
  hypertension: ['Sodio', 'Potassio', 'Calcio'],
  vegetarian: ['Ferro', 'Calcio', 'Vitamina B12'],
  child_teen: ['Calcio', 'Ferro', 'Vitamina D'],
}

const requiredBeforeReview: PlanAssistantStep[] = ['objective', 'targets', 'meals', 'equivalents']
const requiredTargets: [string, string[]][] = [
  ['energia', ['energyKcal', 'energy_kcal']],
  ['proteina', ['proteinG', 'protein_g']],
  ['carboidrato', ['carbohydrateG', 'carbohydrate_g']],
  ['gordura', ['fatG', 'fat_g']],
  ['fibra', ['fiberG', 'fiber_g']],
  ['agua', ['waterMl', 'water_ml', 'water']],
]

export function initialAssistantState(): PlanAssistantState {
  return { currentStep: 'objective', completedSteps: [], objective: '', clinicalPresets: [], priorityMicronutrients: [], visibility: defaultPlanVisibility(), targetRanges: {}, rangeJustification: '', mealDistributions: {} }
}

export function defaultPlanVisibility(): PlanVisibility {
  return { showTotalKcal: false, showTotalMacros: false, showMealCalculations: false, showDiary: true }
}

export function sanitizePlanVisibility(value: unknown): PlanVisibility {
  const source = value && typeof value === 'object' ? value as Partial<PlanVisibility> : {}
  return {
    showTotalKcal: source.showTotalKcal === true,
    showTotalMacros: source.showTotalMacros === true,
    showMealCalculations: source.showMealCalculations === true,
    showDiary: source.showDiary !== false,
  }
}

export function suggestMicronutrients(presets: ClinicalPreset[]): string[] {
  return Array.from(new Set(presets.flatMap(preset => presetMicronutrients[preset])))
}

export function sanitizeAssistantState(value: unknown): PlanAssistantState {
  if (!value || typeof value !== 'object') return initialAssistantState()
  const source = value as Partial<PlanAssistantState>
  const completed = Array.isArray(source.completedSteps)
    ? source.completedSteps.filter((step): step is PlanAssistantStep => assistantSteps.includes(step as PlanAssistantStep))
    : []
  const currentStep = assistantSteps.includes(source.currentStep as PlanAssistantStep)
    ? source.currentStep as PlanAssistantStep
    : 'objective'
  return {
    currentStep,
    completedSteps: Array.from(new Set(completed)),
    objective: typeof source.objective === 'string' ? source.objective : '',
    clinicalPresets: Array.isArray(source.clinicalPresets)
      ? source.clinicalPresets.filter((preset): preset is ClinicalPreset => clinicalPresets.includes(preset as ClinicalPreset))
      : [],
    priorityMicronutrients: Array.isArray(source.priorityMicronutrients)
      ? source.priorityMicronutrients.filter(item => typeof item === 'string' && item.trim()).map(item => item.trim())
      : [],
    visibility: sanitizePlanVisibility(source.visibility),
    targetRanges: source.targetRanges&&typeof source.targetRanges==='object'?Object.fromEntries(Object.entries(source.targetRanges).map(([key,value])=>[key,normalizeRange(value as object)]).filter(([,value])=>value)): {},
    rangeJustification: typeof source.rangeJustification==='string'?source.rangeJustification:'',
    mealDistributions: source.mealDistributions&&typeof source.mealDistributions==='object'?Object.fromEntries(Object.entries(source.mealDistributions).filter(([,value])=>Number.isFinite(value)&&Number(value)>=0).map(([key,value])=>[key,Number(value)])): {},
  }
}

export function toggleClinicalPreset(state: PlanAssistantState, preset: ClinicalPreset): PlanAssistantState {
  const clinicalPresets = state.clinicalPresets.includes(preset)
    ? state.clinicalPresets.filter(item => item !== preset)
    : [...state.clinicalPresets, preset]
  return {
    ...state,
    clinicalPresets,
    priorityMicronutrients: Array.from(new Set([...state.priorityMicronutrients, ...suggestMicronutrients(clinicalPresets)])),
  }
}

export function completeAssistantStep(state: PlanAssistantState, step: PlanAssistantStep): PlanAssistantState {
  return {
    ...state,
    completedSteps: Array.from(new Set([...state.completedSteps, step])),
  }
}

export function canReviewPlan(state: PlanAssistantState): boolean {
  return requiredBeforeReview.every(step => state.completedSteps.includes(step))
}

export function canPublishPlan(state: PlanAssistantState, status: string): boolean {
  return status === 'reviewed' && state.completedSteps.includes('review')
}

export function getPlanQualityIssues(state: PlanAssistantState, targets: PlanTargets): string[] {
  const issues = requiredTargets
    .filter(([, keys]) => keys.every(key => !Number.isFinite(targets[key]) || Number(targets[key]) <= 0))
    .map(([label]) => `Informe meta de ${label}.`)
  if (!canReviewPlan(state)) issues.push('Conclua as etapas obrigatorias do assistente.')
  if (!state.priorityMicronutrients.length) issues.push('Informe micronutrientes prioritarios.')
  const distribution=Object.values(state.mealDistributions).reduce((sum,value)=>sum+value,0)
  if (Object.keys(state.mealDistributions).length && (!Number.isFinite(distribution)||Math.abs(distribution-100)>0.01)) issues.push('A distribuição entre refeições deve somar 100%.')
  return issues
}
import { normalizeRange, type NutrientRanges } from './planRanges'
