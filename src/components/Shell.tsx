import { useEffect, useRef, useState, type ReactNode } from 'react'
import { BookOpen, CalendarPlus, Layers, LayoutDashboard, LogOut, Menu, Users, X } from 'lucide-react'
import type { AppRoute, Page } from '../lib/appRoute'
import type { WorkspaceAccess } from '../types'

const NAV: { route: AppRoute; label: string; icon: typeof LayoutDashboard; activePages: Page[] }[] = [
  { route: { page: 'dashboard' }, label: 'Visão geral', icon: LayoutDashboard, activePages: ['dashboard'] },
  { route: { page: 'patients' }, label: 'Pacientes', icon: Users, activePages: ['patients', 'patient-new', 'patient-detail'] },
  { route: { page: 'nutrition' }, label: 'Novo plano', icon: CalendarPlus, activePages: ['nutrition'] },
  { route: { page: 'templates' }, label: 'Modelos', icon: Layers, activePages: ['templates'] },
  { route: { page: 'content' }, label: 'Conteúdos', icon: BookOpen, activePages: ['content'] },
]

const ROLE_LABELS = {
  owner: 'Proprietário',
  admin: 'Administrador',
  nutritionist: 'Nutricionista',
  student: 'Estagiário',
  receptionist: 'Recepção',
} as const

export interface ShellProps {
  children: ReactNode
  route: AppRoute
  workspace: WorkspaceAccess
  onNavigate: (route: AppRoute) => void
  onLogout: () => void
}

export function Shell({ children, route, workspace, onNavigate, onLogout }: ShellProps) {
  const [drawerOpen, setDrawerOpen] = useState(false)
  const triggerRef = useRef<HTMLButtonElement>(null)
  const closeRef = useRef<HTMLButtonElement>(null)

  function closeDrawer(returnFocus = false) {
    setDrawerOpen(false)
    if (returnFocus) triggerRef.current?.focus()
  }

  useEffect(() => {
    if (!drawerOpen) return
    closeRef.current?.focus()
    const closeOnEscape = (event: KeyboardEvent) => {
      if (event.key === 'Escape') closeDrawer(true)
    }
    document.addEventListener('keydown', closeOnEscape)
    return () => document.removeEventListener('keydown', closeOnEscape)
  }, [drawerOpen])

  function navigate(next: AppRoute) {
    onNavigate(next)
    closeDrawer(true)
  }

  return (
    <div className="flex min-h-screen bg-background">
      <button
        ref={triggerRef}
        type="button"
        aria-label="Abrir menu"
        aria-controls="professional-navigation"
        aria-expanded={drawerOpen}
        className="fixed left-4 top-4 z-30 rounded-xl border border-border bg-card p-2.5 text-forest-800 shadow-warm focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-amber-400 lg:hidden"
        onClick={() => setDrawerOpen(true)}
      >
        <Menu size={22} />
      </button>

      {drawerOpen && (
        <button
          type="button"
          aria-label="Fechar navegação"
          data-testid="drawer-overlay"
          className="fixed inset-0 z-40 bg-forest-950/55 backdrop-blur-[1px] lg:hidden"
          onClick={() => closeDrawer(true)}
        />
      )}

      <aside
        id="professional-navigation"
        role="navigation"
        aria-label="Navegação principal"
        data-open={drawerOpen ? 'true' : 'false'}
        className={`fixed inset-y-0 left-0 z-50 flex w-60 flex-col bg-forest-800 text-cream-100 shadow-2xl transition-transform duration-200 lg:z-40 lg:visible lg:translate-x-0 lg:shadow-none ${drawerOpen ? 'visible translate-x-0' : 'invisible -translate-x-full'}`}
      >
        <div className="flex items-center gap-3 px-5 pb-7 pt-6">
          <img src="./app-icon.png" alt="BSNutri" className="h-11 w-11 rounded-full ring-2 ring-amber-400/60" />
          <div className="min-w-0 flex-1">
            <p className="font-display text-lg font-semibold leading-none">BSNutri</p>
            <p className="mt-1 truncate font-mono text-[10px] uppercase tracking-[0.16em] text-cream-100/50">{workspace.organizationName}</p>
          </div>
          <button
            ref={closeRef}
            type="button"
            aria-label="Fechar menu"
            className="rounded-lg p-1.5 text-cream-100/70 hover:bg-white/10 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-amber-300 lg:hidden"
            onClick={() => closeDrawer(true)}
          >
            <X size={20} />
          </button>
        </div>

        <nav className="flex-1 space-y-1 px-3">
          {NAV.map(({ route: next, label, icon: Icon, activePages }) => {
            const active = activePages.includes(route.page)
            return (
              <button
                type="button"
                key={label}
                aria-current={active ? 'page' : undefined}
                onClick={() => navigate(next)}
                className={`group flex w-full items-center gap-3 rounded-xl px-3.5 py-2.5 text-left text-sm font-medium transition-all duration-150 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-amber-300 ${active ? 'bg-forest-600 text-cream-50 shadow-warm' : 'text-cream-100/70 hover:bg-white/5 hover:text-cream-50'}`}
              >
                <Icon size={17} strokeWidth={2} className={active ? 'text-amber-300' : 'text-cream-100/50 group-hover:text-amber-300'} />
                {label}
              </button>
            )
          })}
        </nav>

        <div className="space-y-1 px-3 pb-6">
          <button
            type="button"
            onClick={onLogout}
            className="flex w-full items-center gap-3 rounded-xl px-3.5 py-2.5 text-sm font-medium text-cream-100/70 transition-all hover:bg-white/5 hover:text-cream-50 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-amber-300"
          >
            <LogOut size={17} className="text-cream-100/50" />
            Sair
          </button>
          <div className="mt-3 border-t border-white/10 px-3.5 pt-4">
            <p className="truncate text-[13px] font-semibold">{workspace.memberName}</p>
            <p className="truncate text-xs text-cream-100/50">{ROLE_LABELS[workspace.role]}</p>
          </div>
        </div>
      </aside>

      <main className="min-w-0 flex-1 lg:ml-60">
        <header className="border-b border-border bg-card/60 px-5 py-4 pl-16 backdrop-blur lg:px-8">
          <p className="text-xs text-muted-foreground">{workspace.organizationName}</p>
          <p className="text-sm font-semibold text-foreground">{workspace.memberName}</p>
        </header>
        <div className="mx-auto max-w-[1200px] px-5 py-8 lg:px-8">{children}</div>
      </main>
    </div>
  )
}

export function PageHeader({ eyebrow, title, description, actions }: { eyebrow: string; title: string; description?: string; actions?: ReactNode }) {
  return (
    <div className="mb-8 flex flex-wrap items-end justify-between gap-4">
      <div>
        <p className="eyebrow mb-2">{eyebrow}</p>
        <h1 className="font-display text-[34px] font-semibold leading-tight text-foreground">{title}</h1>
        {description && <p className="mt-1.5 max-w-xl text-[15px] text-muted-foreground">{description}</p>}
      </div>
      {actions && <div className="flex items-center gap-3">{actions}</div>}
    </div>
  )
}
