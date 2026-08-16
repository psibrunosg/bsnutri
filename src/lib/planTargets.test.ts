import { describe, expect, it } from 'vitest'
import { isTargetSetEmpty, objectiveFromText, suggestTargets, suggestTargetsForPatient } from './planTargets'

describe('suggestTargets', () => {
  it('recusa dados clínicos ausentes em vez de inventar meta', () => {
    expect(suggestTargets({ totalEnergyExpenditure: 0, weightKg: 80, objective: 'maintenance' })).toBeNull()
    expect(suggestTargets({ totalEnergyExpenditure: 2400, weightKg: 0, objective: 'maintenance' })).toBeNull()
    expect(suggestTargets({ totalEnergyExpenditure: Number.NaN, weightKg: 80, objective: 'maintenance' })).toBeNull()
  })

  it('aplica déficit no emagrecimento e superávit no ganho', () => {
    const base = { totalEnergyExpenditure: 2400, weightKg: 80 } as const
    expect(suggestTargets({ ...base, objective: 'weight_loss' })!.energyKcal).toBe(2040)
    expect(suggestTargets({ ...base, objective: 'maintenance' })!.energyKcal).toBe(2400)
    expect(suggestTargets({ ...base, objective: 'weight_gain' })!.energyKcal).toBe(2760)
  })

  it('eleva a proteína no emagrecimento para preservar massa magra', () => {
    const base = { totalEnergyExpenditure: 2400, weightKg: 80 } as const
    expect(suggestTargets({ ...base, objective: 'weight_loss' })!.proteinG).toBe(144)
    expect(suggestTargets({ ...base, objective: 'maintenance' })!.proteinG).toBe(112)
  })

  it('fecha o valor energético entre os três macronutrientes', () => {
    const target = suggestTargets({ totalEnergyExpenditure: 2400, weightKg: 80, objective: 'maintenance' })!
    const soma = target.proteinG * 4 + target.carbohydrateG * 4 + target.fatG * 9
    expect(Math.abs(soma - target.energyKcal)).toBeLessThanOrEqual(12)
  })

  it('deriva fibra da energia e água do peso', () => {
    const target = suggestTargets({ totalEnergyExpenditure: 2400, weightKg: 80, objective: 'maintenance' })!
    expect(target.fiberG).toBe(34)
    expect(target.waterMl).toBe(2800)
  })

  it('nunca devolve carboidrato negativo quando a proteína consome quase tudo', () => {
    const target = suggestTargets({ totalEnergyExpenditure: 900, weightKg: 120, objective: 'weight_loss' })!
    expect(target.carbohydrateG).toBeGreaterThanOrEqual(0)
  })
})

describe('objectiveFromText', () => {
  it('reconhece o objetivo já registrado na avaliação', () => {
    expect(objectiveFromText('Emagrecimento')).toBe('weight_loss')
    expect(objectiveFromText('Perda de peso com preservação de massa')).toBe('weight_loss')
    expect(objectiveFromText('Ganho de massa')).toBe('weight_gain')
    expect(objectiveFromText('Hipertrofia')).toBe('weight_gain')
  })

  it('mantém manutenção quando o texto não é claro', () => {
    expect(objectiveFromText('Acompanhamento geral')).toBe('maintenance')
    expect(objectiveFromText(null)).toBe('maintenance')
    expect(objectiveFromText('')).toBe('maintenance')
  })
})

describe('suggestTargetsForPatient', () => {
  it('não sugere nada sem estimativa energética registrada', () => {
    expect(suggestTargetsForPatient(null, 'Emagrecimento')).toBeNull()
  })

  it('usa a estimativa e o objetivo do prontuário', () => {
    const target = suggestTargetsForPatient({ total_energy_expenditure: 2400, current_weight_kg: 80 }, 'Emagrecimento')
    expect(target!.energyKcal).toBe(2040)
    expect(target!.proteinG).toBe(144)
  })
})

describe('isTargetSetEmpty', () => {
  it('só considera vazio quando nenhuma meta foi informada', () => {
    expect(isTargetSetEmpty({ energyKcal: 0, proteinG: 0, carbohydrateG: 0, fatG: 0, fiberG: 0, waterMl: 0 })).toBe(true)
    expect(isTargetSetEmpty({ energyKcal: 2000, proteinG: 0, carbohydrateG: 0, fatG: 0, fiberG: 0, waterMl: 0 })).toBe(false)
  })
})
