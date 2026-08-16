import { describe, expect, it, vi } from 'vitest'
import { resolveSessionAccess, type BootstrapDataSource, type DataResult } from './sessionBootstrap'

const absent = <T>(): DataResult<T> => ({ data: null, error: null })
const found = <T>(data: T): DataResult<T> => ({ data, error: null })

function source(overrides: Partial<BootstrapDataSource> = {}): BootstrapDataSource {
  return {
    getActiveMembership: vi.fn().mockResolvedValue(absent()),
    getDirectPatient: vi.fn().mockResolvedValue(absent()),
    getGuardianPatient: vi.fn().mockResolvedValue(absent()),
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
  it('resolves an active clinical membership to the professional shell', async () => {
    const result = await resolveSessionAccess(source({ getActiveMembership: vi.fn().mockResolvedValue(found(workspace)) }), 'user-1')
    expect(result).toEqual({ kind: 'professional', workspace })
  })

  it('keeps an active receptionist in the restricted reception destination', async () => {
    const receptionist = { ...workspace, role: 'receptionist' as const }
    const result = await resolveSessionAccess(source({ getActiveMembership: vi.fn().mockResolvedValue(found(receptionist)) }), 'user-1')
    expect(result).toEqual({ kind: 'receptionist', workspace: receptionist })
  })

  it('resolves direct patient and guardian links from the authenticated user', async () => {
    const direct = await resolveSessionAccess(source({ getDirectPatient: vi.fn().mockResolvedValue(found(patient)) }), 'user-1')
    expect(direct).toEqual({ kind: 'patient', patient })

    const guardianPatient = { ...patient, relationship: 'guardian' as const }
    const guardian = await resolveSessionAccess(source({ getGuardianPatient: vi.fn().mockResolvedValue(found(guardianPatient)) }), 'user-2')
    expect(guardian).toEqual({ kind: 'patient', patient: guardianPatient })
  })

  it('returns onboarding only after an explicit successful claim attempt remains empty', async () => {
    const dataSource = source()
    const result = await resolveSessionAccess(dataSource, 'user-1')
    expect(result).toEqual({ kind: 'onboarding' })
    expect(dataSource.claimPatientAccess).toHaveBeenCalledOnce()
    expect(dataSource.getDirectPatient).toHaveBeenCalledTimes(2)
    expect(dataSource.getGuardianPatient).toHaveBeenCalledTimes(2)
  })

  it('returns a recoverable error when membership lookup fails instead of onboarding', async () => {
    const dataSource = source({
      getActiveMembership: vi.fn().mockResolvedValue({ data: null, error: { message: 'Falha de rede' } }),
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
