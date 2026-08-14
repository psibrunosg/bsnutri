import { describe, expect, it } from 'vitest'
import { emptyWeekPlan, imc, planTotals } from './lib/types'

describe('BSNutri core', () => {
  it('cria semana vazia com 7 dias', () => {
    const w = emptyWeekPlan()
    expect(Object.keys(w)).toHaveLength(7)
  })
  it('calcula IMC', () => {
    expect(imc(70, 175)).toBeCloseTo(22.86, 1)
  })
  it('soma macros da semana vazia como zero', () => {
    expect(planTotals(emptyWeekPlan(), []).kcal).toBe(0)
  })
})
