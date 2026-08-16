import type { PlanAssistantState } from './planAssistant'
import type { EditorDay } from './planDrafts'

export const REQUIRED_TARGET_KEYS = ['energyKcal', 'proteinG', 'carbohydrateG', 'fatG', 'fiberG', 'waterMl'] as const
export const REQUIRED_ASSISTANT_STEPS = ['objective', 'targets', 'meals', 'equivalents'] as const

export interface StepReadiness {
  objective: boolean
  targets: boolean
  meals: boolean
  equivalents: boolean
}

/**
 * Etapas cujo cumprimento é observável no próprio plano. `equivalents` fica de
 * fora de propósito: revisar substituições é um julgamento clínico e precisa de
 * confirmação explícita do profissional.
 */
export function derivedStepReadiness(
  state: PlanAssistantState,
  targets: Record<string, number>,
  days: EditorDay[],
): StepReadiness {
  return {
    objective: state.objective.trim().length > 1,
    targets: REQUIRED_TARGET_KEYS.every((key) => Number.isFinite(targets[key]) && targets[key] > 0),
    meals: days.some((day) => day.meals.some((meal) => meal.items.length > 0)),
    equivalents: state.completedSteps.includes('equivalents'),
  }
}
