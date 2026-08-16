import { describe, expect, it } from 'vitest'
import { filterPatients, mapPatientSummary, normalizeIntakeTags, type PatientSummary } from './patients'

function summary(overrides: Partial<PatientSummary> = {}): PatientSummary {
  return {
    id: 'p1',
    anonymousCode: 'P0001',
    fullName: 'Mariana Lopes',
    email: null,
    phone: null,
    birthDate: null,
    status: 'active',
    tags: [],
    objective: null,
    measurements: [],
    ...overrides,
  }
}

describe('mapPatientSummary', () => {
  it('keeps absent measures absent instead of turning them into zero', () => {
    const mapped = mapPatientSummary({
      id: 'p1',
      anonymous_code: 'P0001',
      full_name: 'Mariana Lopes',
      email: null,
      phone: null,
      birth_date: null,
      status: 'active',
      tags: null,
      anthropometry: [
        { measured_at: '2026-08-01T12:00:00Z', weight_kg: null, height_cm: 168, body_fat_percent: null, waist_cm: null, hip_cm: null, arm_cm: null },
      ],
      assessments: [],
    })

    expect(mapped.measurements[0].weightKg).toBeNull()
    expect(mapped.measurements[0].heightCm).toBe(168)
    expect(mapped.tags).toEqual([])
    expect(mapped.objective).toBeNull()
  })

  it('orders measurements from newest to oldest and reads the latest objective', () => {
    const mapped = mapPatientSummary({
      id: 'p1',
      anonymous_code: 'P0001',
      full_name: 'Mariana Lopes',
      email: 'mariana@teste.invalid',
      phone: null,
      birth_date: '1990-01-01',
      status: 'active',
      tags: ['low carb'],
      anthropometry: [
        { measured_at: '2026-07-01T12:00:00Z', weight_kg: 70, height_cm: 168, body_fat_percent: null, waist_cm: null, hip_cm: null, arm_cm: null },
        { measured_at: '2026-08-01T12:00:00Z', weight_kg: 68.5, height_cm: 168, body_fat_percent: 24, waist_cm: 80, hip_cm: 96, arm_cm: 28 },
      ],
      assessments: [
        { assessed_at: '2026-08-01T12:00:00Z', objective: 'Perda de peso' },
        { assessed_at: '2026-07-01T12:00:00Z', objective: 'Avaliação inicial' },
      ],
    })

    expect(mapped.measurements.map((item) => item.weightKg)).toEqual([68.5, 70])
    expect(mapped.objective).toBe('Perda de peso')
  })
})

describe('filterPatients', () => {
  const list = [
    summary({ id: 'p1', fullName: 'Mariana Lopes', anonymousCode: 'P0001', tags: ['low carb'], objective: 'Perda de peso' }),
    summary({ id: 'p2', fullName: 'João Pereira', anonymousCode: 'P0002', tags: ['corrida'], objective: 'Performance' }),
  ]

  it('returns every patient for an empty query', () => {
    expect(filterPatients(list, '  ')).toHaveLength(2)
  })

  it('matches name, code, objective and tags ignoring case and accents', () => {
    expect(filterPatients(list, 'mariana').map((p) => p.id)).toEqual(['p1'])
    expect(filterPatients(list, 'P0002').map((p) => p.id)).toEqual(['p2'])
    expect(filterPatients(list, 'joao').map((p) => p.id)).toEqual(['p2'])
    expect(filterPatients(list, 'corrida').map((p) => p.id)).toEqual(['p2'])
    expect(filterPatients(list, 'perda').map((p) => p.id)).toEqual(['p1'])
  })

  it('returns nothing when no patient matches', () => {
    expect(filterPatients(list, 'inexistente')).toEqual([])
  })
})

describe('normalizeIntakeTags', () => {
  it('trims, lowercases and removes duplicates and empties', () => {
    expect(normalizeIntakeTags([' Low Carb ', 'low carb', '', '  ', 'Corrida'])).toEqual(['low carb', 'corrida'])
  })
})
