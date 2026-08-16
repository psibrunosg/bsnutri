import { describe, expect, it } from 'vitest'
import { parseAppRoute, routeToSearch } from './appRoute'

describe('appRoute', () => {
  it('parses every supported route field from the query string', () => {
    expect(parseAppRoute('?page=nutrition&patient=patient-1&plan=plan-2&version=version-3&day=4')).toEqual({
      page: 'nutrition',
      patientId: 'patient-1',
      planId: 'plan-2',
      versionId: 'version-3',
      day: '4',
    })
    expect(parseAppRoute('?page=patient-detail&patient=patient-1&section=assessment')).toEqual({
      page: 'patient-detail',
      patientId: 'patient-1',
      patientSection: 'assessment',
    })
    expect(parseAppRoute('?page=portal&tab=progress')).toEqual({ page: 'portal', portalTab: 'progress' })
  })

  it('uses a safe dashboard fallback for invalid pages and strips unknown data', () => {
    expect(parseAppRoute('?page=admin&name=Maria&notes=private')).toEqual({ page: 'dashboard' })
  })

  it('removes parameters that are incompatible with the selected page', () => {
    expect(parseAppRoute('?page=patients&patient=p1&plan=p2&version=v3&day=2&section=history&tab=plan')).toEqual({ page: 'patients' })
    expect(routeToSearch({ page: 'patient-detail', patientId: 'p1', patientSection: 'history', planId: 'secret-plan' })).toBe('?page=patient-detail&patient=p1&section=history')
  })

  it('never serializes a freely supplied patient id for the portal', () => {
    expect(routeToSearch({ page: 'portal', patientId: 'another-patient', portalTab: 'plan' })).toBe('?page=portal&tab=plan')
  })
})
