import { useCallback, useEffect, useState } from 'react'
import { parseAppRoute, routeToSearch, type AppRoute, type Page } from './appRoute'

export function useAppRoute(fallbackPage: Page): [AppRoute, (next: AppRoute) => void] {
  const [route, setRoute] = useState<AppRoute>(() => parseAppRoute(window.location.search, fallbackPage))

  useEffect(() => {
    const onPopState = () => setRoute(parseAppRoute(window.location.search, fallbackPage))
    window.addEventListener('popstate', onPopState)
    return () => window.removeEventListener('popstate', onPopState)
  }, [fallbackPage])

  const navigate = useCallback((next: AppRoute) => {
    const search = routeToSearch(next)
    if (search !== window.location.search) window.history.pushState(null, '', search || window.location.pathname)
    setRoute(next)
  }, [])

  return [route, navigate]
}
