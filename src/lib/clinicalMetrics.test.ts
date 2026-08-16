import { describe, expect, it } from 'vitest'
import {
  ageInYears,
  bodyMassIndex,
  bodyMassIndexCategory,
  isEstimateInputComplete,
  waistHipRatio,
  weightDelta,
} from './clinicalMetrics'

describe('ageInYears', () => {
  it('returns null when the birth date is missing', () => {
    expect(ageInYears(null, new Date('2026-08-16T12:00:00'))).toBeNull()
    expect(ageInYears('', new Date('2026-08-16T12:00:00'))).toBeNull()
  })

  it('returns null when the birth date cannot be parsed', () => {
    expect(ageInYears('não é data', new Date('2026-08-16T12:00:00'))).toBeNull()
  })

  it('returns null when the birth date is in the future', () => {
    expect(ageInYears('2027-01-01', new Date('2026-08-16T12:00:00'))).toBeNull()
  })

  it('counts completed years only', () => {
    expect(ageInYears('1990-08-16', new Date('2026-08-16T12:00:00'))).toBe(36)
    expect(ageInYears('1990-08-17', new Date('2026-08-16T12:00:00'))).toBe(35)
  })
})

describe('bodyMassIndex', () => {
  it('returns null when any measure is missing or invalid', () => {
    expect(bodyMassIndex(null, 170)).toBeNull()
    expect(bodyMassIndex(70, null)).toBeNull()
    expect(bodyMassIndex(70, 0)).toBeNull()
    expect(bodyMassIndex(0, 170)).toBeNull()
  })

  it('computes the index from kilograms and centimetres', () => {
    expect(bodyMassIndex(70, 170)).toBeCloseTo(24.22, 2)
  })
})

describe('bodyMassIndexCategory', () => {
  it('returns null without an index', () => {
    expect(bodyMassIndexCategory(null)).toBeNull()
  })

  it('classifies each band', () => {
    expect(bodyMassIndexCategory(17)?.label).toBe('Abaixo do peso')
    expect(bodyMassIndexCategory(22)?.label).toBe('Eutrofia')
    expect(bodyMassIndexCategory(27)?.label).toBe('Sobrepeso')
    expect(bodyMassIndexCategory(32)?.label).toBe('Obesidade I')
    expect(bodyMassIndexCategory(38)?.label).toBe('Obesidade II+')
  })
})

describe('waistHipRatio', () => {
  it('returns null when a circumference is missing', () => {
    expect(waistHipRatio(null, 100)).toBeNull()
    expect(waistHipRatio(80, null)).toBeNull()
    expect(waistHipRatio(80, 0)).toBeNull()
  })

  it('divides waist by hip', () => {
    expect(waistHipRatio(80, 100)).toBeCloseTo(0.8, 5)
  })
})

describe('weightDelta', () => {
  it('returns null without two measurements', () => {
    expect(weightDelta([])).toBeNull()
    expect(weightDelta([{ weight_kg: 70 }])).toBeNull()
  })

  it('returns null when either measurement lacks weight', () => {
    expect(weightDelta([{ weight_kg: null }, { weight_kg: 70 }])).toBeNull()
  })

  it('subtracts the previous weight from the newest one', () => {
    expect(weightDelta([{ weight_kg: 68.5 }, { weight_kg: 70 }])).toBeCloseTo(-1.5, 5)
  })
})

describe('isEstimateInputComplete', () => {
  it('rejects incomplete clinical data instead of defaulting', () => {
    expect(isEstimateInputComplete({ weightKg: null, heightCm: 170, ageYears: 30, biologicalSex: 'female' })).toBe(false)
    expect(isEstimateInputComplete({ weightKg: 70, heightCm: null, ageYears: 30, biologicalSex: 'female' })).toBe(false)
    expect(isEstimateInputComplete({ weightKg: 70, heightCm: 170, ageYears: null, biologicalSex: 'female' })).toBe(false)
    expect(isEstimateInputComplete({ weightKg: 70, heightCm: 170, ageYears: 30, biologicalSex: null })).toBe(false)
    expect(isEstimateInputComplete({ weightKg: 0, heightCm: 170, ageYears: 30, biologicalSex: 'male' })).toBe(false)
  })

  it('accepts a fully informed clinical input', () => {
    expect(isEstimateInputComplete({ weightKg: 70, heightCm: 170, ageYears: 30, biologicalSex: 'male' })).toBe(true)
  })
})
