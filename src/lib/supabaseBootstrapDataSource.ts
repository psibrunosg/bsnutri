import { type BootstrapDataSource, type DataResult } from './sessionBootstrap'
import { supabase } from './supabase'
import type { OrganizationRole, PatientAccess } from '../types'

interface MembershipRecord {
  organization_id: string
  role: string
  organizations: { name: string } | null
}

interface PatientRecord {
  id: string
  full_name: string
  anonymous_code: string
  organization_id: string
  professional_id: string
}

function isOrganizationRole(role: string): role is OrganizationRole {
  return ['owner', 'admin', 'nutritionist', 'student', 'receptionist'].includes(role)
}

function queryFailure<T>(message: string): DataResult<T> {
  return { data: null, error: { message } }
}

function mapPatient(row: PatientRecord, relationship: PatientAccess['relationship']): PatientAccess {
  return {
    id: row.id,
    fullName: row.full_name,
    anonymousCode: row.anonymous_code,
    organizationId: row.organization_id,
    professionalId: row.professional_id,
    relationship,
  }
}

export function createSupabaseBootstrapDataSource(): BootstrapDataSource {
  return {
    async getActiveMembership(userId) {
      const membership = await supabase
        .from('memberships')
        .select('organization_id,role,organizations(name)')
        .eq('user_id', userId)
        .eq('status', 'active')
        .limit(1)
        .maybeSingle()
      if (membership.error) return queryFailure(membership.error.message)
      if (!membership.data) return { data: null, error: null }

      const profile = await supabase.from('profiles').select('full_name').eq('id', userId).maybeSingle()
      if (profile.error) return queryFailure(profile.error.message)
      if (!profile.data) return queryFailure('O perfil profissional não foi encontrado.')

      const row = membership.data as unknown as MembershipRecord
      if (!isOrganizationRole(row.role)) return queryFailure('O papel deste vínculo não é reconhecido.')
      if (!row.organizations?.name) return queryFailure('A organização deste vínculo não foi encontrada.')
      return {
        data: {
          organizationId: row.organization_id,
          organizationName: row.organizations.name,
          memberName: profile.data.full_name,
          role: row.role,
        },
        error: null,
      }
    },

    async getDirectPatient(userId) {
      const result = await supabase
        .from('patients')
        .select('id,full_name,anonymous_code,organization_id,professional_id')
        .eq('patient_user_id', userId)
        .limit(1)
        .maybeSingle()
      if (result.error) return queryFailure(result.error.message)
      return { data: result.data ? mapPatient(result.data, 'patient') : null, error: null }
    },

    async getGuardianPatient(userId) {
      const guardian = await supabase
        .from('patient_guardians')
        .select('patient_id,organization_id')
        .eq('guardian_user_id', userId)
        .limit(1)
        .maybeSingle()
      if (guardian.error) return queryFailure(guardian.error.message)
      if (!guardian.data) return { data: null, error: null }

      const result = await supabase
        .from('patients')
        .select('id,full_name,anonymous_code,organization_id,professional_id')
        .eq('id', guardian.data.patient_id)
        .eq('organization_id', guardian.data.organization_id)
        .maybeSingle()
      if (result.error) return queryFailure(result.error.message)
      return { data: result.data ? mapPatient(result.data, 'guardian') : null, error: null }
    },

    async claimPatientAccess() {
      const result = await supabase.rpc('claim_patient_access')
      return { error: result.error ? { message: result.error.message } : null }
    },
  }
}
