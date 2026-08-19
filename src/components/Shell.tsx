import { useEffect, useRef, useState, type ReactNode } from 'react'
import { Apple, BookOpen, CalendarPlus, ChevronDown, Layers, LayoutDashboard, Leaf, LogOut, Menu, Users, X } from 'lucide-react'
import type { AppRoute, Page } from '../lib/appRoute'
import { usePrefersReducedMotion } from '../lib/usePrefersReducedMotion'
import type { WorkspaceAccess } from '../types'

const NAV: { route: AppRoute; label: string; icon: typeof LayoutDashboard; activePages: Page[] }[] = [
  { route: { page: 'dashboard' }, label: 'Visão geral', icon: LayoutDashboard, activePages: ['dashboard'] },
  { route: { page: 'patients' }, label: 'Pacientes', icon: Users, activePages: ['patients', 'patient-new', 'patient-detail'] },
  { route: { page: 'nutrition' }, label: 'Novo plano', icon: CalendarPlus, activePages: ['nutrition'] },
  { route: { page: 'catalog' }, label: 'Catálogo', icon: Apple, activePages: ['catalog'] },
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

function memberInitials(name: string): string {
  const parts = name.split(' ').filter((part) => part.length > 2)
  return (parts.length ? parts : name.split(' ')).map((part) => part[0] ?? '').slice(0, 2).join('').toUpperCase()
}

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
  const drawerRef = useRef<HTMLElement>(null)
  const prefersReducedMotion = usePrefersReducedMotion()

  function closeDrawer(returnFocus = false) {
    setDrawerOpen(false)
    if (returnFocus) triggerRef.current?.focus()
  }

  useEffect(() => {
    if (typeof window.matchMedia !== 'function') return
    const desktop = window.matchMedia('(min-width: 1024px)')
    const closeOnDesktop = (event: MediaQueryListEvent) => {
      if (event.matches) setDrawerOpen(false)
    }
    if (desktop.matches) setDrawerOpen(false)
    desktop.addEventListener('change', closeOnDesktop)
    return () => desktop.removeEventListener('change', closeOnDesktop)
  }, [])

  useEffect(() => {
    if (!drawerOpen) return
    closeRef.current?.focus()
    const handleDrawerKey = (event: KeyboardEvent) => {
      if (event.key === 'Escape') {
        closeDrawer(true)
        return
      }
      if (event.key !== 'Tab') return
      const focusable = Array.from(drawerRef.current?.querySelectorAll<HTMLElement>('button:not([disabled]), a[href], input:not([disabled]), select:not([disabled]), textarea:not([disabled])') ?? [])
      if (!focusable.length) return
      const first = focusable[0]
      const last = focusable[focusable.length - 1]
      if (event.shiftKey && (document.activeElement === first || !drawerRef.current?.contains(document.activeElement))) {
        event.preventDefault()
        last.focus()
      } else if (!event.shiftKey && (document.activeElement === last || !drawerRef.current?.contains(document.activeElement))) {
        event.preventDefault()
        first.focus()
      }
    }
    document.addEventListener('keydown', handleDrawerKey)
    return () => document.removeEventListener('keydown', handleDrawerKey)
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
        <div
          aria-hidden="true"
          data-testid="drawer-overlay"
          className="fixed inset-0 z-40 bg-forest-950/55 backdrop-blur-[1px] lg:hidden"
          onClick={() => closeDrawer(true)}
        />
      )}

      <aside
        ref={drawerRef}
        id="professional-navigation"
        role="navigation"
        aria-label="Navegação principal"
        data-open={drawerOpen ? 'true' : 'false'}
        data-motion={prefersReducedMotion ? 'reduced' : 'full'}
        className={`fixed inset-y-0 left-0 z-50 flex w-[264px] flex-col bg-forest-800 text-cream-100 shadow-2xl ${prefersReducedMotion ? 'transition-none' : 'transition-transform duration-200'} lg:z-40 lg:visible lg:translate-x-0 lg:shadow-none ${drawerOpen ? 'visible translate-x-0' : 'invisible -translate-x-full'}`}
      >
        <div className="flex items-center gap-3 px-6 pb-7 pt-6">
          <img src="./app-icon.png" alt="BSNutri" className="h-[52px] w-[52px] shrink-0 rounded-full object-cover ring-2 ring-amber-400/70" />
          <div className="min-w-0 flex-1">
            <p className="font-display text-[22px] font-semibold leading-none">BSNutri</p>
            <p className="mt-1.5 truncate font-mono text-[10px] uppercase tracking-[0.18em] text-cream-100/50">{workspace.organizationName}</p>
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

        <div className="space-y-1 px-3.5">
          {NAV.map(({ route: next, label, icon: Icon, activePages }) => {
            const active = activePages.includes(route.page)
            return (
              <button
                type="button"
                key={label}
                aria-current={active ? 'page' : undefined}
                onClick={() => navigate(next)}
                className={`group flex w-full items-center gap-3.5 rounded-xl px-3.5 py-3 text-left text-[15px] font-medium transition-all duration-200 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-amber-300 ${active ? 'bg-forest-600 text-cream-50 shadow-warm' : 'text-cream-100/70 hover:bg-white/5 hover:text-cream-50'}`}
              >
                <Icon size={19} strokeWidth={1.9} className={active ? 'text-amber-300' : 'text-cream-100/50 group-hover:text-amber-300'} />
                {label}
              </button>
            )
          })}
        </div>

        <div className="flex-1" />

        {/* O bloco de identidade fica depois de Sair e permanece não interativo:
            o foco do drawer termina no botão Sair. */}
        <div className="px-3.5">
          <div className="mb-3 border-t border-white/10" />
          <button
            type="button"
            onClick={onLogout}
            className="flex w-full items-center gap-3.5 rounded-xl px-3.5 py-3 text-left text-[15px] font-medium text-cream-100/70 transition-all duration-200 hover:bg-white/5 hover:text-cream-50 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-amber-300"
          >
            <LogOut size={19} strokeWidth={1.9} className="text-cream-100/50" />
            Sair
          </button>
          <div className="mt-3 flex items-center gap-3 border-t border-white/10 px-2 pt-4">
            <span className="flex h-[42px] w-[42px] shrink-0 items-center justify-center rounded-full bg-forest-600 font-display text-[15px] font-semibold text-cream-50 ring-1 ring-white/15">
              {memberInitials(workspace.memberName)}
            </span>
            <span className="min-w-0 flex-1">
              <span className="block truncate text-[13px] font-semibold">{workspace.memberName}</span>
              <span className="block truncate text-[12px] text-cream-100/50">{ROLE_LABELS[workspace.role]}</span>
            </span>
            <ChevronDown size={17} aria-hidden="true" className="shrink-0 text-cream-100/45" />
          </div>
        </div>

        <div className="relative mt-5 px-6 pb-7">
          <Leaf aria-hidden="true" className="pointer-events-none absolute -left-2 bottom-2 h-[72px] w-[72px] -rotate-[18deg] text-cream-100/[0.07]" strokeWidth={1} />
          <p className="relative text-center text-[12px] leading-relaxed text-cream-100/45">
            Nutrição que transforma
            <br />
            ciência, saúde e bem-estar.
          </p>
        </div>
      </aside>

      <main className="min-w-0 flex-1 overflow-x-clip lg:ml-[264px]" inert={drawerOpen || undefined} aria-hidden={drawerOpen || undefined}>
        <header className="border-b border-border bg-card/60 px-5 py-4 pl-16 backdrop-blur lg:hidden">
          <p className="text-xs text-muted-foreground">{workspace.organizationName}</p>
          <p className="text-sm font-semibold text-foreground">{workspace.memberName}</p>
        </header>
        <div className="mx-auto max-w-[1400px] px-5 py-8 lg:px-10 lg:py-9">{children}</div>
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
