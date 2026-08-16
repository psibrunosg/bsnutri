import { describe, expect, it } from 'vitest'
import { calculateEnergyEstimate, PROTOCOL_LABELS, ACTIVITY_LEVEL_PRESETS } from './energyEstimations'

describe('calculateEnergyEstimate', () => {
  it('calcula corretamente o TMB e GET pelo protocolo Mifflin-St Jeor para homem', () => {
    const result = calculateEnergyEstimate({
      protocol: 'mifflin_st_jeor',
      currentWeightKg: 70,
      heightCm: 175,
      ageYears: 30,
      biologicalSex: 'male',
      activityFactor: 1.55,
    })
    expect(result.basalMetabolicRate).toBe(1648.8)
    expect(result.totalEnergyExpenditure).toBe(2555.6)
    expect(result.protocol).toBe('mifflin_st_jeor')
  })

  it('calcula corretamente o TMB e GET pelo protocolo Mifflin-St Jeor para mulher', () => {
    const result = calculateEnergyEstimate({
      protocol: 'mifflin_st_jeor',
      currentWeightKg: 60,
      heightCm: 165,
      ageYears: 25,
      biologicalSex: 'female',
      activityFactor: 1.375,
    })
    expect(result.basalMetabolicRate).toBe(1345.3)
    expect(result.totalEnergyExpenditure).toBe(1849.7)
  })

  it('calcula corretamente o protocolo Harris-Benedict (Roza & Shizgal 1984) para homem', () => {
    const result = calculateEnergyEstimate({
      protocol: 'harris_benedict',
      currentWeightKg: 80,
      heightCm: 180,
      ageYears: 28,
      biologicalSex: 'male',
      activityFactor: 1.2,
    })
    expect(result.basalMetabolicRate).toBe(1865)
    expect(result.totalEnergyExpenditure).toBe(2238)
  })

  it('calcula corretamente o protocolo EER / IOM para mulher', () => {
    const result = calculateEnergyEstimate({
      protocol: 'eer_iom',
      currentWeightKg: 65,
      heightCm: 168,
      ageYears: 35,
      biologicalSex: 'female',
      activityFactor: 1.55,
    })
    expect(result.basalMetabolicRate).toBeGreaterThan(0)
    expect(result.totalEnergyExpenditure).toBeGreaterThan(result.basalMetabolicRate)
  })

  it('calcula corretamente o protocolo Tinsley com base no peso corporal', () => {
    const result = calculateEnergyEstimate({
      protocol: 'tinsley',
      currentWeightKg: 85,
      heightCm: 180,
      ageYears: 25,
      biologicalSex: 'male',
      activityFactor: 1.725,
    })
    // BMR = 24.8 * 85 + 10 = 2108 + 10 = 2118
    expect(result.basalMetabolicRate).toBe(2118)
    expect(result.totalEnergyExpenditure).toBe(3653.6)
  })

  it('disponibiliza labels e presets de atividade física adequados para a interface', () => {
    expect(Object.keys(PROTOCOL_LABELS)).toHaveLength(4)
    expect(ACTIVITY_LEVEL_PRESETS.length).toBeGreaterThanOrEqual(5)
  })
})
