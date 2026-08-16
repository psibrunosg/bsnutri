import { cleanup, fireEvent, render, screen } from '@testing-library/react'
import { afterEach, describe, expect, it, vi } from 'vitest'
import { PlanAssistantPanel } from './PlanAssistantPanel'
import { derivedStepReadiness } from '../lib/assistantReadiness'
import { emptyNutrients } from '../lib/nutrition'
import { initialAssistantState, type PlanAssistantState } from '../lib/planAssistant'
import type { EditorDay } from '../lib/planDrafts'

const FULL_TARGETS = { energyKcal: 2000, proteinG: 110, carbohydrateG: 230, fatG: 65, fiberG: 28, waterMl: 2200 }

function dayWithItem(): EditorDay {
  return {
    id: 'day-1',
    label: 'Segunda-feira',
    kind: 'standard',
    meals: [{ id: 'meal-1', name: 'Café da manhã', items: [{ id: 'item-1', name: 'Aveia', grams: 30, nutrientsPer100g: emptyNutrients() }] }],
  }
}

function emptyDay(): EditorDay {
  return { id: 'day-1', label: 'Segunda-feira', kind: 'standard', meals: [{ id: 'meal-1', name: 'Café da manhã', items: [] }] }
}

function state(overrides: Partial<PlanAssistantState> = {}): PlanAssistantState {
  return { ...initialAssistantState(), ...overrides }
}

describe('derivedStepReadiness', () => {
  it('reads objective, targets and meals from the plan itself', () => {
    const ready = derivedStepReadiness(state({ objective: 'Perda de peso' }), FULL_TARGETS, [dayWithItem()])
    expect(ready.objective).toBe(true)
    expect(ready.targets).toBe(true)
    expect(ready.meals).toBe(true)
  })

  it('does not consider a target met when it is zero or missing', () => {
    expect(derivedStepReadiness(state(), { ...FULL_TARGETS, waterMl: 0 }, [dayWithItem()]).targets).toBe(false)
    expect(derivedStepReadiness(state(), { ...FULL_TARGETS, fiberG: Number.NaN }, [dayWithItem()]).targets).toBe(false)
  })

  it('does not consider meals ready when no day has an item', () => {
    expect(derivedStepReadiness(state(), FULL_TARGETS, [emptyDay()]).meals).toBe(false)
  })

  it('never derives the equivalents step: it needs an explicit confirmation', () => {
    expect(derivedStepReadiness(state(), FULL_TARGETS, [dayWithItem()]).equivalents).toBe(false)
    expect(derivedStepReadiness(state({ completedSteps: ['equivalents'] }), FULL_TARGETS, [dayWithItem()]).equivalents).toBe(true)
  })
})

describe('PlanAssistantPanel', () => {
  afterEach(() => cleanup())

  function setup(initial: PlanAssistantState, days = [dayWithItem()]) {
    let current = initial
    const setAssistant = vi.fn((update: (value: PlanAssistantState) => PlanAssistantState) => { current = update(current) })
    const view = render(<PlanAssistantPanel assistant={current} setAssistant={setAssistant} targets={FULL_TARGETS} setTargets={vi.fn()} days={days} disabled={false} />)
    return { view, read: () => current }
  }

  it('only confirms the steps that the plan actually supports', () => {
    const { read } = setup(state({ objective: 'Perda de peso' }))
    fireEvent.click(screen.getByRole('button', { name: /Confirmar objetivo, metas e refeições/ }))
    expect(read().completedSteps.sort()).toEqual(['meals', 'objective', 'targets'])
    expect(read().completedSteps).not.toContain('equivalents')
  })

  it('leaves the equivalents step to an explicit confirmation', () => {
    const { read } = setup(state({ objective: 'Perda de peso' }))
    fireEvent.click(screen.getByRole('button', { name: /Confirmo que revisei os equivalentes/ }))
    expect(read().completedSteps).toEqual(['equivalents'])
  })

  it('suggests priority micronutrients from the clinical approach', () => {
    const { read } = setup(state())
    fireEvent.click(screen.getByRole('button', { name: 'Emagrecimento' }))
    expect(read().clinicalPresets).toEqual(['weight_loss'])
    expect(read().priorityMicronutrients).toEqual(['Fibra', 'Potassio', 'Vitamina C'])
  })

  it('shows every required step as pending while nothing is confirmed', () => {
    setup(state(), [emptyDay()])
    expect(screen.getByText(/Objetivo · pendente/)).toBeInTheDocument()
    expect(screen.getByText(/Equivalentes · pendente/)).toBeInTheDocument()
  })
})
