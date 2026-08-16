import { describe, expect, it } from 'vitest'
import { guardianAccessFromRow } from './guardianAccess'

describe('guardianAccessFromRow', () => {
  it('derives authorized portal access only from the guardian link', () => {
    expect(guardianAccessFromRow({
      patient_id: 'patient-1',
      organization_id: 'organization-1',
      relationship: 'Mãe',
      can_view_plan: true,
    })).toEqual({
      data: {
        id: 'patient-1',
        organizationId: 'organization-1',
        relationship: 'guardian',
        guardianRelationship: 'Mãe',
      },
      error: null,
    })
  })

  it('denies a guardian link that cannot view the plan', () => {
    expect(guardianAccessFromRow({
      patient_id: 'patient-1',
      organization_id: 'organization-1',
      relationship: 'Responsável',
      can_view_plan: false,
    })).toEqual({
      data: null,
      error: { message: 'Este vínculo de responsável não permite visualizar o plano.' },
    })
  })
})
