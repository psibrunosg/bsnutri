import { type BootstrapDataSource, type DataResult } from './sessionBootstrap'
import { guardianAccessFromRow } from './guardianAccess'
import { supabase } from './supabase'
import type { OrganizationRole, PatientAccess, WorkspaceAccess } from '../types'

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

function mapPatient(row: PatientRecord): PatientAccess {
  return {
    id: row.id,
    fullName: row.full_name,
    anonymousCode: row.anonymous_code,
    organizationId: row.organization_id,
    professionalId: row.professional_id,
    relationship: 'patient',
  }
}

export function createSupabaseBootstrapDataSource(): BootstrapDataSource {
  return {
    async getActiveMemberships(userId) {
      const memberships = await supabase
        .from('memberships')
        .select('organization_id,role,organizations(name)')
        .eq('user_id', userId)
        .eq('status', 'active')
        .order('organization_id')
      if (memberships.error) return queryFailure(memberships.error.message)
      if (!memberships.data?.length) return { data: [], error: null }

      const profile = await supabase.from('profiles').select('full_name').eq('id', userId).maybeSingle()
      if (profile.error) return queryFailure(profile.error.message)
      if (!profile.data) return queryFailure('O perfil profissional não foi encontrado.')

      const rows = memberships.data as unknown as MembershipRecord[]
      const workspaces: WorkspaceAccess[] = []
      for (const row of rows) {
        if (!isOrganizationRole(row.role)) return queryFailure('O papel deste vínculo não é reconhecido.')
        if (!row.organizations?.name) return queryFailure('A organização deste vínculo não foi encontrada.')
        workspaces.push({
          organizationId: row.organization_id,
          organizationName: row.organizations.name,
          memberName: profile.data.full_name,
          role: row.role,
        })
      }
      return { data: workspaces, error: null }
    },

    async getDirectPatients(userId) {
      const result = await supabase
        .from('patients')
        .select('id,full_name,anonymous_code,organization_id,professional_id')
        .eq('patient_user_id', userId)
        .order('id')
      if (result.error) return queryFailure(result.error.message)
      return { data: (result.data ?? []).map(mapPatient), error: null }
    },

    async getGuardianPatients(userId) {
      const guardian = await supabase
        .from('patient_guardians')
        .select('patient_id,organization_id,relationship,can_view_plan')
        .eq('guardian_user_id', userId)
        .order('patient_id')
      if (guardian.error) return queryFailure(guardian.error.message)
      if (!guardian.data?.length) return { data: [], error: null }
      const patients: PatientAccess[] = []
      for (const row of guardian.data) {
        const access = guardianAccessFromRow(row)
        if (access.data) patients.push(access.data)
      }
      if (patients.length) return { data: patients, error: null }
      return { data: null, error: { code: 'guardian_access_denied', message: 'Este vínculo de responsável não permite visualizar o plano.' } }
    },

    async claimPatientAccess() {
      const result = await supabase.rpc('claim_patient_access')
      return { error: result.error ? { message: result.error.message } : null }
    },
  }
}
