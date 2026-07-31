import { useCallback, useEffect, useState } from 'react'
import { parseAppRoute, routeToSearch, type AppRoute, type Page } from './appRoute'

export function useAppRoute(
  fallbackPage: Page,
): [AppRoute, (next: AppRoute, options?: { replace?: boolean }) => void] {
  const [route, setRoute] = useState<AppRoute>(() => parseAppRoute(window.location.search, fallbackPage))

  useEffect(() => {
    const onPopState = () => setRoute(parseAppRoute(window.location.search, fallbackPage))
    window.addEventListener('popstate', onPopState)
    return () => window.removeEventListener('popstate', onPopState)
  }, [fallbackPage])

  const navigate = useCallback((next: AppRoute, options?: { replace?: boolean }) => {
    const search = routeToSearch(next)
    if (search !== window.location.search) {
      const url = search || window.location.pathname
      if (options?.replace) window.history.replaceState(null, '', url)
      else window.history.pushState(null, '', url)
    }
    setRoute(next)
  }, [])

  return [route, navigate]
}
