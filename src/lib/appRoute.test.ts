import { describe, expect, it } from 'vitest'
import { parseAppRoute, routeToSearch } from './appRoute'

describe('parseAppRoute', () => {
  it('usa a página padrão quando não há query string', () => {
    expect(parseAppRoute('', 'patients')).toEqual({ page: 'patients', patientId: null })
  })

  it('lê a página informada na query string', () => {
    expect(parseAppRoute('?page=nutrition', 'patients')).toEqual({ page: 'nutrition', patientId: null })
  })

  it('ignora página desconhecida e usa a padrão', () => {
    expect(parseAppRoute('?page=inexistente', 'patients')).toEqual({ page: 'patients', patientId: null })
  })

  it('lê o paciente selecionado', () => {
    expect(parseAppRoute('?page=patients&patient=abc-123', 'patients')).toEqual({ page: 'patients', patientId: 'abc-123' })
  })
})

describe('routeToSearch', () => {
  it('serializa apenas a página quando não há paciente', () => {
    expect(routeToSearch({ page: 'care', patientId: null })).toBe('?page=care')
  })

  it('serializa página e paciente', () => {
    expect(routeToSearch({ page: 'patients', patientId: 'abc-123' })).toBe('?page=patients&patient=abc-123')
  })
})
