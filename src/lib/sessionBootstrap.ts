import type { PatientAccess, WorkspaceAccess } from '../types'

export interface DataError {
  message: string
}

export interface DataResult<T> {
  data: T | null
  error: DataError | null
}

export interface BootstrapDataSource {
  getActiveMembership(userId: string): Promise<DataResult<WorkspaceAccess>>
  getDirectPatient(userId: string): Promise<DataResult<PatientAccess>>
  getGuardianPatient(userId: string): Promise<DataResult<PatientAccess>>
  claimPatientAccess(): Promise<{ error: DataError | null }>
}

export type SessionAccess =
  | { kind: 'professional'; workspace: WorkspaceAccess }
  | { kind: 'receptionist'; workspace: WorkspaceAccess }
  | { kind: 'patient'; patient: PatientAccess }
  | { kind: 'onboarding' }
  | { kind: 'error'; message: string }

const NO_PATIENT_CLAIM_MESSAGE = 'Nenhum cadastro de paciente disponível para este e-mail'

function failure(error: DataError | null): SessionAccess | null {
  return error ? { kind: 'error', message: error.message } : null
}

async function resolvePatient(source: BootstrapDataSource, userId: string): Promise<SessionAccess | null> {
  const direct = await source.getDirectPatient(userId)
  const directFailure = failure(direct.error)
  if (directFailure) return directFailure
  if (direct.data) return { kind: 'patient', patient: direct.data }

  const guardian = await source.getGuardianPatient(userId)
  const guardianFailure = failure(guardian.error)
  if (guardianFailure) return guardianFailure
  if (guardian.data) return { kind: 'patient', patient: guardian.data }
  return null
}

export async function resolveSessionAccess(source: BootstrapDataSource, userId: string): Promise<SessionAccess> {
  const membership = await source.getActiveMembership(userId)
  const membershipFailure = failure(membership.error)
  if (membershipFailure) return membershipFailure
  if (membership.data) {
    return membership.data.role === 'receptionist'
      ? { kind: 'receptionist', workspace: membership.data }
      : { kind: 'professional', workspace: membership.data }
  }

  const linked = await resolvePatient(source, userId)
  if (linked) return linked

  const claim = await source.claimPatientAccess()
  const claimFailure = claim.error?.message === NO_PATIENT_CLAIM_MESSAGE ? null : failure(claim.error)
  if (claimFailure) return claimFailure

  const linkedAfterClaim = await resolvePatient(source, userId)
  return linkedAfterClaim ?? { kind: 'onboarding' }
}
