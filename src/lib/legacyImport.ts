import type { PatientDataSource, PatientIntakeInput } from './patients'

export const LEGACY_PATIENTS_KEY = 'bsnutri-patients'
export const LEGACY_PLANS_KEY = 'bsnutri-plans'
export const LEGACY_PROVENANCE = 'prototype-v2'

export interface LegacyPatient {
  name: string
  email?: string
  phone?: string
  birthDate?: string
  goal?: string
  notes?: string
  tags?: string[]
  measurements?: { weight?: number; height?: number; waist?: number; hip?: number; arm?: number; bodyFat?: number }[]
}

export interface LegacyPreview {
  patients: LegacyPatient[]
  planCount: number
  /** Registros descartados por não terem sequer um nome utilizável. */
  discarded: number
}

function parseArray(raw: string | null): unknown[] {
  if (!raw) return []
  try {
    const parsed = JSON.parse(raw)
    return Array.isArray(parsed) ? parsed : []
  } catch {
    return []
  }
}

function readPatient(value: unknown): LegacyPatient | null {
  if (typeof value !== 'object' || value === null) return null
  const record = value as Record<string, unknown>
  const name = typeof record.name === 'string' ? record.name.trim() : ''
  if (name.length < 2) return null
  const measurements = Array.isArray(record.measurements)
    ? record.measurements.filter((item): item is Record<string, unknown> => typeof item === 'object' && item !== null).map((item) => ({
        weight: typeof item.weight === 'number' ? item.weight : undefined,
        height: typeof item.height === 'number' ? item.height : undefined,
        waist: typeof item.waist === 'number' ? item.waist : undefined,
        hip: typeof item.hip === 'number' ? item.hip : undefined,
        arm: typeof item.arm === 'number' ? item.arm : undefined,
        bodyFat: typeof item.bodyFat === 'number' ? item.bodyFat : undefined,
      }))
    : []
  return {
    name,
    email: typeof record.email === 'string' ? record.email : undefined,
    phone: typeof record.phone === 'string' ? record.phone : undefined,
    birthDate: typeof record.birthDate === 'string' ? record.birthDate : undefined,
    goal: typeof record.goal === 'string' ? record.goal : undefined,
    notes: typeof record.notes === 'string' ? record.notes : undefined,
    tags: Array.isArray(record.tags) ? record.tags.filter((tag): tag is string => typeof tag === 'string') : undefined,
    measurements,
  }
}

/** Lê o armazenamento antigo sem alterá-lo. Nenhum envio acontece aqui. */
export function readLegacyStore(storage: Pick<Storage, 'getItem'>): LegacyPreview | null {
  const rawPatients = parseArray(storage.getItem(LEGACY_PATIENTS_KEY))
  const rawPlans = parseArray(storage.getItem(LEGACY_PLANS_KEY))
  if (!rawPatients.length && !rawPlans.length) return null
  const patients: LegacyPatient[] = []
  let discarded = 0
  for (const candidate of rawPatients) {
    const patient = readPatient(candidate)
    if (patient) patients.push(patient)
    else discarded += 1
  }
  return { patients, planCount: rawPlans.length, discarded }
}

export function toIntakeInput(patient: LegacyPatient, organizationId: string): PatientIntakeInput {
  const latest = patient.measurements?.[patient.measurements.length - 1]
  return {
    organizationId,
    fullName: patient.name,
    email: patient.email?.trim() || null,
    phone: patient.phone?.trim() || null,
    birthDate: patient.birthDate || null,
    tags: [...(patient.tags ?? []), LEGACY_PROVENANCE],
    objective: patient.goal?.trim() || null,
    clinicalNotes: patient.notes?.trim() || null,
    weightKg: latest?.weight ?? null,
    heightCm: latest?.height ?? null,
    waistCm: latest?.waist ?? null,
    hipCm: latest?.hip ?? null,
    armCm: latest?.arm ?? null,
    bodyFatPercent: latest?.bodyFat ?? null,
  }
}

export interface LegacyImportReport {
  imported: number
  failures: { name: string; message: string }[]
}

/** Importa paciente a paciente: uma falha isolada não impede as demais. */
export async function importLegacyPatients(
  preview: LegacyPreview,
  organizationId: string,
  dataSource: PatientDataSource,
): Promise<LegacyImportReport> {
  const failures: LegacyImportReport['failures'] = []
  let imported = 0
  for (const patient of preview.patients) {
    const result = await dataSource.createPatientIntake(toIntakeInput(patient, organizationId))
    if (result.error || !result.data) failures.push({ name: patient.name, message: result.error?.message ?? 'Falha desconhecida.' })
    else imported += 1
  }
  return { imported, failures }
}

/** Só é chamado depois de confirmação explícita do profissional. */
export function clearLegacyStore(storage: Pick<Storage, 'removeItem'>): void {
  storage.removeItem(LEGACY_PATIENTS_KEY)
  storage.removeItem(LEGACY_PLANS_KEY)
}
