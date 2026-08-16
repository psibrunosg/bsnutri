import { describe, expect, it, vi } from 'vitest'
import { resolveSessionAccess, type BootstrapDataSource, type DataResult } from './sessionBootstrap'

const found = <T>(data: T): DataResult<T> => ({ data, error: null })

function source(overrides: Partial<BootstrapDataSource> = {}): BootstrapDataSource {
  return {
    getActiveMemberships: vi.fn().mockResolvedValue(found([])),
    getDirectPatients: vi.fn().mockResolvedValue(found([])),
    getGuardianPatients: vi.fn().mockResolvedValue(found([])),
    claimPatientAccess: vi.fn().mockResolvedValue({ error: null }),
    ...overrides,
  }
}

const workspace = {
  organizationId: 'organization-1',
  organizationName: 'Clínica Aurora',
  memberName: 'Dra. Ana',
  role: 'nutritionist' as const,
}

const patient = {
  id: 'patient-1',
  fullName: 'Pessoa vinculada',
  anonymousCode: 'P001',
  organizationId: 'organization-1',
  professionalId: 'professional-1',
  relationship: 'patient' as const,
}

describe('resolveSessionAccess', () => {
  it('requires deterministic workspace selection when multiple memberships are active', async () => {
    const zeta = { ...workspace, organizationId: 'organization-z', organizationName: 'Clínica Zeta', role: 'admin' as const }
    const aurora = { ...workspace, organizationId: 'organization-a', organizationName: 'Clínica Aurora' }
    const dataSource = {
      ...source(),
      getActiveMemberships: vi.fn().mockResolvedValue(found([zeta, aurora])),
    }

    expect(await resolveSessionAccess(dataSource, 'user-1')).toEqual({
      kind: 'workspace-selection',
      workspaces: [aurora, zeta],
    })
  })

  it('requires deterministic portal selection when multiple linked patients are valid', async () => {
    const guardianPatient = {
      id: 'patient-2',
      organizationId: 'organization-1',
      relationship: 'guardian' as const,
      guardianRelationship: 'Mãe',
    }
    const dataSource = {
      ...source(),
      getDirectPatients: vi.fn().mockResolvedValue(found([patient])),
      getGuardianPatients: vi.fn().mockResolvedValue(found([guardianPatient])),
    }

    expect(await resolveSessionAccess(dataSource, 'user-1')).toEqual({
      kind: 'portal-selection',
      patients: [patient, guardianPatient],
    })
  })

  it('resolves an active clinical membership to the professional shell', async () => {
    const result = await resolveSessionAccess(source({ getActiveMemberships: vi.fn().mockResolvedValue(found([workspace])) }), 'user-1')
    expect(result).toEqual({ kind: 'professional', workspace })
  })

  it('keeps an active receptionist in the restricted reception destination', async () => {
    const receptionist = { ...workspace, role: 'receptionist' as const }
    const result = await resolveSessionAccess(source({ getActiveMemberships: vi.fn().mockResolvedValue(found([receptionist])) }), 'user-1')
    expect(result).toEqual({ kind: 'receptionist', workspace: receptionist })
  })

  it('resolves direct patient and guardian links from the authenticated user', async () => {
    const direct = await resolveSessionAccess(source({ getDirectPatients: vi.fn().mockResolvedValue(found([patient])) }), 'user-1')
    expect(direct).toEqual({ kind: 'patient', patient })

    const guardianPatient = {
      id: 'patient-2',
      organizationId: 'organization-1',
      relationship: 'guardian' as const,
      guardianRelationship: 'Mãe',
    }
    const guardian = await resolveSessionAccess(source({ getGuardianPatients: vi.fn().mockResolvedValue(found([guardianPatient])) }), 'user-2')
    expect(guardian).toEqual({ kind: 'patient', patient: guardianPatient })
  })

  it('denies guardian access without attempting claim when plan viewing is disabled', async () => {
    const dataSource = source({
      getGuardianPatients: vi.fn().mockResolvedValue({
        data: null,
        error: { message: 'Este vínculo de responsável não permite visualizar o plano.' },
      }),
    })
    const result = await resolveSessionAccess(dataSource, 'user-2')
    expect(result).toEqual({ kind: 'error', message: 'Este vínculo de responsável não permite visualizar o plano.' })
    expect(dataSource.claimPatientAccess).not.toHaveBeenCalled()
  })

  it('returns onboarding only after an explicit successful claim attempt remains empty', async () => {
    const dataSource = source()
    const result = await resolveSessionAccess(dataSource, 'user-1')
    expect(result).toEqual({ kind: 'onboarding' })
    expect(dataSource.claimPatientAccess).toHaveBeenCalledOnce()
    expect(dataSource.getDirectPatients).toHaveBeenCalledTimes(2)
    expect(dataSource.getGuardianPatients).toHaveBeenCalledTimes(2)
  })

  it('returns a recoverable error when membership lookup fails instead of onboarding', async () => {
    const dataSource = source({
      getActiveMemberships: vi.fn().mockResolvedValue({ data: null, error: { message: 'Falha de rede' } }),
    })
    const result = await resolveSessionAccess(dataSource, 'user-1')
    expect(result).toEqual({ kind: 'error', message: 'Falha de rede' })
    expect(dataSource.claimPatientAccess).not.toHaveBeenCalled()
  })

  it('returns a recoverable error when claim fails instead of onboarding', async () => {
    const result = await resolveSessionAccess(source({
      claimPatientAccess: vi.fn().mockResolvedValue({ error: { message: 'Serviço indisponível' } }),
    }), 'user-1')
    expect(result).toEqual({ kind: 'error', message: 'Serviço indisponível' })
  })

  it('treats the claim no-match response as confirmed absence and opens onboarding', async () => {
    const result = await resolveSessionAccess(source({
      claimPatientAccess: vi.fn().mockResolvedValue({ error: { message: 'Nenhum cadastro de paciente disponível para este e-mail' } }),
    }), 'user-1')
    expect(result).toEqual({ kind: 'onboarding' })
  })
})
