import type { DataResult } from './sessionBootstrap'
import type { PatientAccess } from '../types'

export interface GuardianAccessRow {
  patient_id: string
  organization_id: string
  relationship: string
  can_view_plan: boolean
}

export function guardianAccessFromRow(row: GuardianAccessRow): DataResult<PatientAccess> {
  if (!row.can_view_plan) {
    return { data: null, error: { message: 'Este vínculo de responsável não permite visualizar o plano.' } }
  }
  return {
    data: {
      id: row.patient_id,
      organizationId: row.organization_id,
      relationship: 'guardian',
      guardianRelationship: row.relationship,
    },
    error: null,
  }
}
