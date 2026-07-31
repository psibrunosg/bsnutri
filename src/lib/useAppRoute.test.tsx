import { act, renderHook } from '@testing-library/react'
import { afterEach, beforeEach, describe, expect, it } from 'vitest'
import { useAppRoute } from './useAppRoute'

describe('useAppRoute', () => {
  beforeEach(() => {
    window.history.replaceState(null, '', '/')
  })

  afterEach(() => {
    window.history.replaceState(null, '', '/')
  })

  it('parte da página padrão quando a URL não tem parâmetros', () => {
    const { result } = renderHook(() => useAppRoute('patients'))
    expect(result.current[0]).toEqual({ page: 'patients', patientId: null })
  })

  it('lê a rota inicial a partir da URL atual', () => {
    window.history.replaceState(null, '', '/?page=nutrition&patient=abc')
    const { result } = renderHook(() => useAppRoute('patients'))
    expect(result.current[0]).toEqual({ page: 'nutrition', patientId: 'abc' })
  })

  it('navigate atualiza o estado e empilha uma entrada no histórico', () => {
    const { result } = renderHook(() => useAppRoute('patients'))
    act(() => result.current[1]({ page: 'care', patientId: null }))
    expect(result.current[0]).toEqual({ page: 'care', patientId: null })
    expect(window.location.search).toBe('?page=care')
  })

  it('popstate (botão voltar) atualiza o estado a partir da URL', () => {
    const { result } = renderHook(() => useAppRoute('patients'))
    act(() => result.current[1]({ page: 'nutrition', patientId: null }))
    act(() => {
      window.history.replaceState(null, '', '?page=patients')
      window.dispatchEvent(new PopStateEvent('popstate'))
    })
    expect(result.current[0]).toEqual({ page: 'patients', patientId: null })
  })
})
