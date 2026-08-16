import { act, cleanup, renderHook } from '@testing-library/react'
import { afterEach, describe, expect, it } from 'vitest'
import { useAppRoute } from './useAppRoute'

describe('useAppRoute', () => {
  afterEach(() => {
    cleanup()
    window.history.replaceState(null, '', '/')
  })

  it('pushes and replaces navigation using the query string as source of truth', () => {
    window.history.replaceState(null, '', '/?page=dashboard')
    const { result } = renderHook(() => useAppRoute())

    act(() => result.current[1]({ page: 'patients' }))
    expect(window.location.search).toBe('?page=patients')
    expect(result.current[0]).toEqual({ page: 'patients' })

    act(() => result.current[1]({ page: 'templates' }, { replace: true }))
    expect(window.location.search).toBe('?page=templates')
    expect(result.current[0]).toEqual({ page: 'templates' })
  })

  it('updates the route after browser popstate navigation', () => {
    window.history.replaceState(null, '', '/?page=dashboard')
    const { result } = renderHook(() => useAppRoute())

    act(() => {
      window.history.pushState(null, '', '/?page=content')
      window.dispatchEvent(new PopStateEvent('popstate'))
    })

    expect(result.current[0]).toEqual({ page: 'content' })
  })
})
