import type { PatientAccess, WorkspaceAccess } from '../types'

export interface DataError {
  message: string
  code?: 'guardian_access_denied'
}

export interface DataResult<T> {
  data: T | null
  error: DataError | null
}

export interface BootstrapDataSource {
  getActiveMemberships(userId: string): Promise<DataResult<WorkspaceAccess[]>>
  getDirectPatients(userId: string): Promise<DataResult<PatientAccess[]>>
  getGuardianPatients(userId: string): Promise<DataResult<PatientAccess[]>>
  claimPatientAccess(): Promise<{ error: DataError | null }>
}

export type SessionAccess =
  | { kind: 'professional'; workspace: WorkspaceAccess }
  | { kind: 'receptionist'; workspace: WorkspaceAccess }
  | { kind: 'workspace-selection'; workspaces: WorkspaceAccess[] }
  | { kind: 'patient'; patient: PatientAccess }
  | { kind: 'portal-selection'; patients: PatientAccess[] }
  | { kind: 'onboarding' }
  | { kind: 'error'; message: string }

const NO_PATIENT_CLAIM_MESSAGE = 'Nenhum cadastro de paciente disponível para este e-mail'

function failure(error: DataError | null): SessionAccess | null {
  return error ? { kind: 'error', message: error.message } : null
}

function sortWorkspaces(workspaces: WorkspaceAccess[]): WorkspaceAccess[] {
  return [...workspaces].sort((left, right) => left.organizationName.localeCompare(right.organizationName, 'pt-BR') || left.organizationId.localeCompare(right.organizationId))
}

function sortPatients(patients: PatientAccess[]): PatientAccess[] {
  return [...patients].sort((left, right) => left.organizationId.localeCompare(right.organizationId) || left.id.localeCompare(right.id) || left.relationship.localeCompare(right.relationship))
}

async function resolvePatient(source: BootstrapDataSource, userId: string): Promise<SessionAccess | null> {
  const direct = await source.getDirectPatients(userId)
  const directFailure = failure(direct.error)
  if (directFailure) return directFailure

  const guardian = await source.getGuardianPatients(userId)
  const guardianDenied = guardian.error?.code === 'guardian_access_denied'
  const guardianFailure = guardianDenied ? null : failure(guardian.error)
  if (guardianFailure) return guardianFailure
  const patients = sortPatients([...(direct.data ?? []), ...(guardian.data ?? [])])
  if (patients.length === 1) return { kind: 'patient', patient: patients[0] }
  if (patients.length > 1) return { kind: 'portal-selection', patients }
  return guardianDenied ? failure(guardian.error) : null
}

export async function resolveSessionAccess(source: BootstrapDataSource, userId: string): Promise<SessionAccess> {
  const memberships = await source.getActiveMemberships(userId)
  const membershipFailure = failure(memberships.error)
  if (membershipFailure) return membershipFailure
  const workspaces = sortWorkspaces(memberships.data ?? [])
  if (workspaces.length > 1) return { kind: 'workspace-selection', workspaces }
  if (workspaces.length === 1) {
    return workspaces[0].role === 'receptionist'
      ? { kind: 'receptionist', workspace: workspaces[0] }
      : { kind: 'professional', workspace: workspaces[0] }
  }

  const linked = await resolvePatient(source, userId)
  if (linked) return linked

  const claim = await source.claimPatientAccess()
  const claimFailure = claim.error?.message === NO_PATIENT_CLAIM_MESSAGE ? null : failure(claim.error)
  if (claimFailure) return claimFailure

  const linkedAfterClaim = await resolvePatient(source, userId)
  return linkedAfterClaim ?? { kind: 'onboarding' }
}
