export type Page =
  | 'dashboard'
  | 'patients'
  | 'patient-new'
  | 'patient-detail'
  | 'nutrition'
  | 'catalog'
  | 'templates'
  | 'content'
  | 'portal'

export interface AppRoute {
  page: Page
  patientId?: string
  patientSection?: string
  planId?: string
  versionId?: string
  day?: string
  portalTab?: string
}

const PAGES = new Set<Page>([
  'dashboard',
  'patients',
  'patient-new',
  'patient-detail',
  'nutrition',
  'catalog',
  'templates',
  'content',
  'portal',
])

function isPage(value: string | null): value is Page {
  return value !== null && PAGES.has(value as Page)
}

function value(params: URLSearchParams, key: string): string | undefined {
  return params.get(key)?.trim() || undefined
}

export function normalizeAppRoute(route: AppRoute): AppRoute {
  switch (route.page) {
    case 'patient-detail':
      return {
        page: route.page,
        ...(route.patientId ? { patientId: route.patientId } : {}),
        ...(route.patientSection ? { patientSection: route.patientSection } : {}),
      }
    case 'nutrition':
      return {
        page: route.page,
        ...(route.patientId ? { patientId: route.patientId } : {}),
        ...(route.planId ? { planId: route.planId } : {}),
        ...(route.versionId ? { versionId: route.versionId } : {}),
        ...(route.day ? { day: route.day } : {}),
      }
    case 'portal':
      return { page: route.page, ...(route.portalTab ? { portalTab: route.portalTab } : {}) }
    default:
      return { page: route.page }
  }
}

export function parseAppRoute(search: string, fallbackPage: Page = 'dashboard'): AppRoute {
  const params = new URLSearchParams(search)
  const page = isPage(params.get('page')) ? params.get('page') as Page : fallbackPage
  return normalizeAppRoute({
    page,
    patientId: value(params, 'patient'),
    patientSection: value(params, 'section'),
    planId: value(params, 'plan'),
    versionId: value(params, 'version'),
    day: value(params, 'day'),
    portalTab: value(params, 'tab'),
  })
}

export function routeToSearch(route: AppRoute): string {
  const normalized = normalizeAppRoute(route)
  const params = new URLSearchParams({ page: normalized.page })
  if (normalized.patientId) params.set('patient', normalized.patientId)
  if (normalized.patientSection) params.set('section', normalized.patientSection)
  if (normalized.planId) params.set('plan', normalized.planId)
  if (normalized.versionId) params.set('version', normalized.versionId)
  if (normalized.day) params.set('day', normalized.day)
  if (normalized.portalTab) params.set('tab', normalized.portalTab)
  return `?${params.toString()}`
}
