import { useCallback, useEffect, useState } from 'react'
import { parseAppRoute, routeToSearch, type AppRoute } from './appRoute'

type NavigateOptions = { replace?: boolean }

export function useAppRoute(): [AppRoute, (next: AppRoute, options?: NavigateOptions) => void] {
  const [route, setRoute] = useState<AppRoute>(() => parseAppRoute(window.location.search))

  useEffect(() => {
    const onPopState = () => setRoute(parseAppRoute(window.location.search))
    window.addEventListener('popstate', onPopState)
    return () => window.removeEventListener('popstate', onPopState)
  }, [])

  const navigate = useCallback((next: AppRoute, options?: NavigateOptions) => {
    const search = routeToSearch(next)
    const url = `${window.location.pathname}${search}`
    if (search !== window.location.search) {
      if (options?.replace) window.history.replaceState(null, '', url)
      else window.history.pushState(null, '', url)
    }
    setRoute(parseAppRoute(search))
  }, [])

  return [route, navigate]
}
