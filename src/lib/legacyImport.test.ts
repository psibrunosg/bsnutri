import { describe, expect, it, vi } from 'vitest'
import {
  LEGACY_PATIENTS_KEY,
  LEGACY_PLANS_KEY,
  LEGACY_PROVENANCE,
  clearLegacyStore,
  importLegacyPatients,
  readLegacyStore,
  toIntakeInput,
} from './legacyImport'
import type { PatientDataSource } from './patients'

function storage(values: Record<string, string | null>) {
  return { getItem: (key: string) => values[key] ?? null }
}

describe('readLegacyStore', () => {
  it('returns nothing when the browser has no prototype data', () => {
    expect(readLegacyStore(storage({}))).toBeNull()
  })

  it('survives corrupted json instead of throwing', () => {
    expect(readLegacyStore(storage({ [LEGACY_PATIENTS_KEY]: '{not json' }))).toBeNull()
  })

  it('counts records it cannot use instead of importing them silently', () => {
    const preview = readLegacyStore(storage({
      [LEGACY_PATIENTS_KEY]: JSON.stringify([{ name: 'Mariana Lopes' }, { name: 'x' }, { nome: 'sem name' }, 'texto solto']),
      [LEGACY_PLANS_KEY]: JSON.stringify([{ id: 'plan-1' }, { id: 'plan-2' }]),
    }))

    expect(preview?.patients.map((patient) => patient.name)).toEqual(['Mariana Lopes'])
    expect(preview?.discarded).toBe(3)
    expect(preview?.planCount).toBe(2)
  })

  it('does not touch the storage while reading', () => {
    const removeItem = vi.fn()
    const source = { ...storage({ [LEGACY_PATIENTS_KEY]: JSON.stringify([{ name: 'Mariana Lopes' }]) }), removeItem }
    readLegacyStore(source)
    expect(removeItem).not.toHaveBeenCalled()
  })
})

describe('toIntakeInput', () => {
  it('marks the origin and carries the latest measurement only', () => {
    const input = toIntakeInput({
      name: 'Mariana Lopes',
      goal: 'Perda de peso',
      tags: ['low carb'],
      measurements: [{ weight: 72 }, { weight: 68.5, height: 168, hip: 96 }],
    }, 'org-1')

    expect(input.tags).toEqual(['low carb', LEGACY_PROVENANCE])
    expect(input.weightKg).toBe(68.5)
    expect(input.hipCm).toBe(96)
    expect(input.armCm).toBeNull()
    expect(input.objective).toBe('Perda de peso')
  })
})

describe('importLegacyPatients', () => {
  it('reports each failure without stopping the remaining patients', async () => {
    const createPatientIntake = vi.fn()
      .mockResolvedValueOnce({ data: 'patient-1', error: null })
      .mockResolvedValueOnce({ data: null, error: { message: 'RLS negou' } })
      .mockResolvedValueOnce({ data: 'patient-3', error: null })
    const dataSource = { listPatients: vi.fn(), createPatientIntake } as unknown as PatientDataSource

    const report = await importLegacyPatients(
      { patients: [{ name: 'A' }, { name: 'B' }, { name: 'C' }], planCount: 0, discarded: 0 },
      'org-1',
      dataSource,
    )

    expect(report.imported).toBe(2)
    expect(report.failures).toEqual([{ name: 'B', message: 'RLS negou' }])
  })
})

describe('clearLegacyStore', () => {
  it('removes both prototype keys', () => {
    const removeItem = vi.fn()
    clearLegacyStore({ removeItem })
    expect(removeItem).toHaveBeenCalledWith(LEGACY_PATIENTS_KEY)
    expect(removeItem).toHaveBeenCalledWith(LEGACY_PLANS_KEY)
  })
})
