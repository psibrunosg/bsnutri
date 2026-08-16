import { supabase } from './supabase'

export interface PatientMeasurement {
  measuredAt: string
  weightKg: number | null
  heightCm: number | null
  bodyFatPercent: number | null
  waistCm: number | null
  hipCm: number | null
  armCm: number | null
}

export interface PatientSummary {
  id: string
  anonymousCode: string
  fullName: string
  email: string | null
  phone: string | null
  birthDate: string | null
  status: string
  tags: string[]
  objective: string | null
  /** Da medida mais recente para a mais antiga. */
  measurements: PatientMeasurement[]
}

export interface PatientSummaryRow {
  id: string
  anonymous_code: string
  full_name: string
  email: string | null
  phone: string | null
  birth_date: string | null
  status: string
  tags: string[] | null
  anthropometry: {
    measured_at: string
    weight_kg: number | null
    height_cm: number | null
    body_fat_percent: number | null
    waist_cm: number | null
    hip_cm: number | null
    arm_cm: number | null
  }[] | null
  assessments: { assessed_at: string; objective: string | null }[] | null
}

export interface PatientIntakeInput {
  organizationId: string
  fullName: string
  email?: string | null
  phone?: string | null
  birthDate?: string | null
  tags?: string[]
  objective?: string | null
  foodPreferences?: string | null
  foodRestrictions?: string | null
  allergies?: string | null
  clinicalNotes?: string | null
  weightKg?: number | null
  heightCm?: number | null
  waistCm?: number | null
  hipCm?: number | null
  armCm?: number | null
  bodyFatPercent?: number | null
}

export interface PatientDataSource {
  listPatients(organizationId: string): Promise<{ data: PatientSummary[] | null; error: { message: string } | null }>
  createPatientIntake(input: PatientIntakeInput): Promise<{ data: string | null; error: { message: string } | null }>
}

const SUMMARY_SELECT =
  'id,anonymous_code,full_name,email,phone,birth_date,status,tags,' +
  'anthropometry(measured_at,weight_kg,height_cm,body_fat_percent,waist_cm,hip_cm,arm_cm),' +
  'assessments(assessed_at,objective)'

function foldForSearch(value: string): string {
  return value.toLowerCase().normalize('NFD').replace(/[\u0300-\u036f]/g, '')
}

export function normalizeIntakeTags(tags: readonly string[]): string[] {
  const seen = new Set<string>()
  const normalized: string[] = []
  for (const raw of tags) {
    const tag = raw.trim().toLowerCase()
    if (!tag || seen.has(tag)) continue
    seen.add(tag)
    normalized.push(tag)
  }
  return normalized
}

export function mapPatientSummary(row: PatientSummaryRow): PatientSummary {
  const measurements = [...(row.anthropometry ?? [])]
    .sort((left, right) => new Date(right.measured_at).getTime() - new Date(left.measured_at).getTime())
    .map((item) => ({
      measuredAt: item.measured_at,
      weightKg: item.weight_kg,
      heightCm: item.height_cm,
      bodyFatPercent: item.body_fat_percent,
      waistCm: item.waist_cm,
      hipCm: item.hip_cm,
      armCm: item.arm_cm,
    }))
  const latestAssessment = [...(row.assessments ?? [])]
    .sort((left, right) => new Date(right.assessed_at).getTime() - new Date(left.assessed_at).getTime())[0]
  return {
    id: row.id,
    anonymousCode: row.anonymous_code,
    fullName: row.full_name,
    email: row.email,
    phone: row.phone,
    birthDate: row.birth_date,
    status: row.status,
    tags: row.tags ?? [],
    objective: latestAssessment?.objective ?? null,
    measurements,
  }
}

export function filterPatients(patients: readonly PatientSummary[], query: string): PatientSummary[] {
  const needle = foldForSearch(query.trim())
  if (!needle) return [...patients]
  return patients.filter((patient) => {
    const haystack = foldForSearch(
      [patient.fullName, patient.anonymousCode, patient.objective ?? '', patient.tags.join(' ')].join(' '),
    )
    return haystack.includes(needle)
  })
}

export function createSupabasePatientDataSource(): PatientDataSource {
  return {
    async listPatients(organizationId) {
      const result = await supabase
        .from('patients')
        .select(SUMMARY_SELECT)
        .eq('organization_id', organizationId)
        .order('full_name')
      if (result.error) return { data: null, error: { message: result.error.message } }
      const rows = (result.data ?? []) as unknown as PatientSummaryRow[]
      return { data: rows.map(mapPatientSummary), error: null }
    },

    async createPatientIntake(input) {
      const result = await supabase.rpc('create_patient_intake', {
        target_organization_id: input.organizationId,
        full_name_input: input.fullName,
        email_input: input.email ?? null,
        phone_input: input.phone ?? null,
        birth_date_input: input.birthDate ?? null,
        tags_input: normalizeIntakeTags(input.tags ?? []),
        objective_input: input.objective ?? null,
        food_preferences_input: input.foodPreferences ?? null,
        food_restrictions_input: input.foodRestrictions ?? null,
        allergies_input: input.allergies ?? null,
        clinical_notes_input: input.clinicalNotes ?? null,
        weight_kg_input: input.weightKg ?? null,
        height_cm_input: input.heightCm ?? null,
        waist_cm_input: input.waistCm ?? null,
        hip_cm_input: input.hipCm ?? null,
        arm_cm_input: input.armCm ?? null,
        body_fat_percent_input: input.bodyFatPercent ?? null,
      })
      if (result.error) return { data: null, error: { message: result.error.message } }
      return { data: (result.data as string | null) ?? null, error: null }
    },
  }
}
