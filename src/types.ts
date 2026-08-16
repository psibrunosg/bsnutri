export type BiologicalSex = 'female' | 'male'
export type EnergyProtocol = 'harris_benedict' | 'mifflin_st_jeor' | 'eer_iom' | 'tinsley'

export interface NutritionalEstimateRow {
  id: string
  organization_id: string
  patient_id: string
  protocol: EnergyProtocol
  current_weight_kg: number
  height_cm: number
  age_years: number
  biological_sex: BiologicalSex
  activity_factor: number
  basal_metabolic_rate: number
  total_energy_expenditure: number
  calculated_on: string
  notes?: string
  created_by: string
  created_at: string
}

export interface NutritionalEstimateInput {
  protocol: EnergyProtocol
  currentWeightKg: number
  heightCm: number
  ageYears: number
  biologicalSex: BiologicalSex
  activityFactor: number
  notes?: string
}

export interface NutritionalEstimateResult {
  basalMetabolicRate: number
  totalEnergyExpenditure: number
  protocol: EnergyProtocol
}

export type ProfessionalRole = 'owner' | 'admin' | 'nutritionist' | 'student'
export type OrganizationRole = ProfessionalRole | 'receptionist'

export interface WorkspaceAccess {
  organizationId: string
  organizationName: string
  memberName: string
  role: OrganizationRole
}

export interface DirectPatientAccess {
  id: string
  fullName: string
  anonymousCode: string
  organizationId: string
  professionalId: string
  relationship: 'patient'
}

export interface GuardianPatientAccess {
  id: string
  organizationId: string
  relationship: 'guardian'
  guardianRelationship: string
}

export type PatientAccess = DirectPatientAccess | GuardianPatientAccess
