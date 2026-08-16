import { useEffect, useState } from 'react'

const REDUCED_MOTION_QUERY = '(prefers-reduced-motion: reduce)'

export function usePrefersReducedMotion() {
  const [prefersReducedMotion, setPrefersReducedMotion] = useState(() => (
    typeof window.matchMedia === 'function' && window.matchMedia(REDUCED_MOTION_QUERY).matches
  ))

  useEffect(() => {
    if (typeof window.matchMedia !== 'function') return
    const media = window.matchMedia(REDUCED_MOTION_QUERY)
    const updatePreference = (event: MediaQueryListEvent) => setPrefersReducedMotion(event.matches)
    media.addEventListener('change', updatePreference)
    return () => media.removeEventListener('change', updatePreference)
  }, [])

  return prefersReducedMotion
}
