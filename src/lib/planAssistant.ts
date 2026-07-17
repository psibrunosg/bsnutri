export const assistantSteps = ['objective', 'targets', 'meals', 'equivalents', 'review', 'publish'] as const

export type PlanAssistantStep = (typeof assistantSteps)[number]

export type PlanAssistantState = {
  currentStep: PlanAssistantStep
  completedSteps: PlanAssistantStep[]
  objective: string
}

export const assistantLabels: Record<PlanAssistantStep, string> = {
  objective: 'Objetivo',
  targets: 'Metas',
  meals: 'Refeições',
  equivalents: 'Equivalentes',
  review: 'Revisão',
  publish: 'Publicação',
}

const requiredBeforeReview: PlanAssistantStep[] = ['objective', 'targets', 'meals', 'equivalents']

export function initialAssistantState(): PlanAssistantState {
  return { currentStep: 'objective', completedSteps: [], objective: '' }
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
