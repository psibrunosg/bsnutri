export type Page = 'patients' | 'nutrition' | 'care' | 'content' | 'settings'
export type AppRoute = { page: Page; patientId: string | null }

const PAGES: Page[] = ['patients', 'nutrition', 'care', 'content', 'settings']

function isPage(value: string | null): value is Page {
  return value !== null && (PAGES as string[]).includes(value)
}

export function parseAppRoute(search: string, fallbackPage: Page): AppRoute {
  const params = new URLSearchParams(search)
  const rawPage = params.get('page')
  const page = isPage(rawPage) ? rawPage : fallbackPage
  const patientId = params.get('patient')
  return { page, patientId: patientId || null }
}

export function routeToSearch(route: AppRoute): string {
  const params = new URLSearchParams()
  params.set('page', route.page)
  if (route.patientId) params.set('patient', route.patientId)
  const value = params.toString()
  return value ? `?${value}` : ''
}
