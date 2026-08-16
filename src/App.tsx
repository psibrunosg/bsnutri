import { useCallback, useEffect, useRef, useState, type FormEvent, type ReactNode } from 'react'
import type { Session } from '@supabase/supabase-js'
import { AlertTriangle, LoaderCircle, LogOut } from 'lucide-react'
import { ProfessionalWorkspace } from './components/ProfessionalWorkspace'
import { type AppRoute } from './lib/appRoute'
import { passwordRecoveryRedirect } from './lib/authRedirect'
import { resolveSessionAccess, type SessionAccess } from './lib/sessionBootstrap'
import { isSupabaseConfigured, supabase } from './lib/supabase'
import { createSupabaseBootstrapDataSource } from './lib/supabaseBootstrapDataSource'
import { useAppRoute } from './lib/useAppRoute'
import Login from './pages/Login'
import type { PatientAccess, WorkspaceAccess } from './types'

type Navigate = (route: AppRoute, options?: { replace?: boolean }) => void

function StatusCard({ title, children }: { title: string; children?: ReactNode }) {
  return (
    <main className="flex min-h-screen items-center justify-center bg-background p-6">
      <section className="card-warm w-full max-w-lg p-8 text-center">
        <img src="./app-icon.png" alt="BSNutri" className="mx-auto mb-5 h-16 w-16 rounded-full" />
        <h1 className="font-display text-3xl font-semibold">{title}</h1>
        {children}
      </section>
    </main>
  )
}

function LoadingScreen() {
  return (
    <StatusCard title="Carregando seu espaço">
      <LoaderCircle className="mx-auto mt-5 animate-spin text-forest-600" aria-hidden="true" />
      <p className="mt-3 text-sm text-muted-foreground" role="status">Verificando sessão e vínculos de acesso.</p>
    </StatusCard>
  )
}

function ErrorScreen({ message, onRetry, onLogout }: { message: string; onRetry: () => void; onLogout: () => void }) {
  return (
    <StatusCard title="Não foi possível carregar seu acesso">
      <AlertTriangle className="mx-auto mt-5 text-destructive" aria-hidden="true" />
      <p className="mt-3 text-sm text-destructive" role="alert">{message}</p>
      <div className="mt-6 flex flex-wrap justify-center gap-3">
        <button type="button" className="btn-primary" onClick={onRetry}>Tentar novamente</button>
        <button type="button" className="btn-ghost" onClick={onLogout}><LogOut size={16} />Sair</button>
      </div>
    </StatusCard>
  )
}

function ProfessionalOnboarding({ defaultName = '', onComplete }: { defaultName?: string; onComplete?: () => void }) {
  const [busy, setBusy] = useState(false)
  const [error, setError] = useState('')

  async function submit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault()
    setBusy(true)
    setError('')
    const data = new FormData(event.currentTarget)
    const fullName = String(data.get('name') ?? '').trim()
    const organizationName = String(data.get('organization') ?? '').trim()
    const baseSlug = organizationName.toLowerCase().normalize('NFD').replace(/[\u0300-\u036f]/g, '').replace(/[^a-z0-9]+/g, '-').replace(/(^-|-$)/g, '')
    const slug = `${baseSlug}-${crypto.randomUUID().slice(0, 6)}`
    const result = await supabase.rpc('bootstrap_organization', {
      full_name_input: fullName,
      organization_name_input: organizationName,
      organization_slug_input: slug,
    })
    setBusy(false)
    if (result.error) {
      setError(result.error.message)
      return
    }
    onComplete?.()
  }

  return (
    <StatusCard title="Prepare seu espaço profissional">
      <p className="mt-3 text-sm text-muted-foreground">Crie a organização somente quando estiver pronto. Nenhum espaço é criado automaticamente.</p>
      <form className="mt-6 space-y-4 text-left" onSubmit={submit}>
        <div>
          <label className="label-warm" htmlFor="onboarding-name">Seu nome</label>
          <input id="onboarding-name" className="input-warm" name="name" defaultValue={defaultName} required minLength={2} />
        </div>
        <div>
          <label className="label-warm" htmlFor="onboarding-organization">Nome do consultório</label>
          <input id="onboarding-organization" className="input-warm" name="organization" required minLength={2} />
        </div>
        {error && <p className="text-sm text-destructive" role="alert">{error}</p>}
        <button className="btn-primary w-full" disabled={busy}>{busy ? 'Criando espaço...' : 'Criar espaço profissional'}</button>
      </form>
    </StatusCard>
  )
}

export interface SessionDestinationProps {
  access: SessionAccess
  route: AppRoute
  userId: string
  onNavigate: Navigate
  onRetry: () => void
  onLogout: () => void
  onWorkspaceSelect?: (workspace: WorkspaceAccess) => void
  onPatientSelect?: (patient: PatientAccess) => void
  defaultName?: string
}

export function SessionDestination({ access, route, userId, onNavigate, onRetry, onLogout, onWorkspaceSelect, onPatientSelect, defaultName }: SessionDestinationProps) {
  const patientPortalTab = access.kind === 'patient' ? route.portalTab : undefined
  useEffect(() => {
    if (access.kind === 'patient') onNavigate({ page: 'portal', ...(patientPortalTab ? { portalTab: patientPortalTab } : {}) }, { replace: true })
  }, [access.kind, onNavigate, patientPortalTab])

  if (access.kind === 'error') return <ErrorScreen message={access.message} onRetry={onRetry} onLogout={onLogout} />
  if (access.kind === 'onboarding') return <ProfessionalOnboarding defaultName={defaultName} onComplete={onRetry} />
  if (access.kind === 'workspace-selection') {
    return (
      <StatusCard title="Escolha o consultório">
        <p className="mt-3 text-sm text-muted-foreground">Sua conta possui mais de um vínculo ativo. Escolha qual espaço abrir nesta sessão.</p>
        <div className="mt-6 grid gap-3">
          {access.workspaces.map((workspace) => (
            <button type="button" className="btn-ghost" key={workspace.organizationId} onClick={() => onWorkspaceSelect?.(workspace)}>{workspace.organizationName}</button>
          ))}
        </div>
      </StatusCard>
    )
  }
  if (access.kind === 'portal-selection') {
    return (
      <StatusCard title="Escolha o acesso ao portal">
        <p className="mt-3 text-sm text-muted-foreground">Há mais de um vínculo válido nesta conta. Escolha qual portal abrir nesta sessão.</p>
        <div className="mt-6 grid gap-3">
          {access.patients.map((patient) => (
            <button type="button" className="btn-ghost" key={`${patient.organizationId}:${patient.id}:${patient.relationship}`} onClick={() => onPatientSelect?.(patient)}>
              {patient.relationship === 'patient' ? patient.fullName : `Dependente · ${patient.guardianRelationship}`}
            </button>
          ))}
        </div>
      </StatusCard>
    )
  }
  if (access.kind === 'receptionist') {
    return (
      <StatusCard title="Módulo de recepção indisponível nesta entrega">
        <p className="mt-3 text-sm text-muted-foreground">Seu vínculo de recepção está ativo, mas este módulo ainda não foi liberado.</p>
        <button type="button" className="btn-ghost mt-6" onClick={onLogout}><LogOut size={16} />Sair</button>
      </StatusCard>
    )
  }
  if (access.kind === 'patient') {
    return (
      <StatusCard title="Portal do paciente">
        <p className="mt-3 font-semibold text-forest-800">{access.patient.relationship === 'patient' ? access.patient.fullName : 'Acesso de responsável'}</p>
        <p className="mt-1 text-sm text-muted-foreground">O conteúdo do seu plano será conectado na etapa do portal.</p>
        <button type="button" className="btn-ghost mt-6" onClick={onLogout}><LogOut size={16} />Sair</button>
      </StatusCard>
    )
  }
  return <ProfessionalWorkspace workspace={access.workspace} userId={userId} route={route} onNavigate={onNavigate} onLogout={onLogout} />
}

function ConfiguredApp() {
  const [route, navigate] = useAppRoute()
  const [session, setSession] = useState<Session | null>(null)
  const [access, setAccess] = useState<SessionAccess | null>(null)
  const [loading, setLoading] = useState(true)
  const [sessionError, setSessionError] = useState('')
  const [recoveringPassword, setRecoveringPassword] = useState(() => window.location.hash.includes('type=recovery'))
  const bootstrapGeneration = useRef(0)
  const activeUserId = useRef<string | null>(null)

  const loadAccess = useCallback(async (current: Session) => {
    const generation = ++bootstrapGeneration.current
    activeUserId.current = current.user.id
    setLoading(true)
    setSessionError('')
    try {
      const nextAccess = await resolveSessionAccess(createSupabaseBootstrapDataSource(), current.user.id)
      if (generation !== bootstrapGeneration.current || activeUserId.current !== current.user.id) return
      setAccess(nextAccess)
    } catch (error) {
      if (generation !== bootstrapGeneration.current || activeUserId.current !== current.user.id) return
      setAccess({ kind: 'error', message: error instanceof Error ? error.message : 'Falha inesperada ao carregar o acesso.' })
    } finally {
      if (generation === bootstrapGeneration.current && activeUserId.current === current.user.id) setLoading(false)
    }
  }, [])

  const initializeSession = useCallback(async () => {
    const generation = ++bootstrapGeneration.current
    activeUserId.current = null
    setLoading(true)
    setSessionError('')
    const result = await supabase.auth.getSession()
    if (generation !== bootstrapGeneration.current) return
    if (result.error) {
      setSessionError(result.error.message)
      setLoading(false)
      return
    }
    setSession(result.data.session)
    if (result.data.session && !recoveringPassword) await loadAccess(result.data.session)
    else {
      activeUserId.current = result.data.session?.user.id ?? null
      setLoading(false)
    }
  }, [loadAccess, recoveringPassword])

  useEffect(() => {
    void initializeSession()
    const { data } = supabase.auth.onAuthStateChange((event, next) => {
      bootstrapGeneration.current += 1
      activeUserId.current = next?.user.id ?? null
      setSessionError('')
      setSession(next)
      if (event === 'PASSWORD_RECOVERY') {
        setRecoveringPassword(true)
        setLoading(false)
      } else if (next) {
        void loadAccess(next)
      } else {
        setAccess(null)
        setLoading(false)
      }
    })
    return () => data.subscription.unsubscribe()
  }, [initializeSession, loadAccess])

  async function logout() {
    const result = await supabase.auth.signOut()
    if (result.error) setAccess({ kind: 'error', message: result.error.message })
  }

  if (recoveringPassword) {
    return <Login recovery onRecoveryComplete={() => {
      setRecoveringPassword(false)
      window.history.replaceState({}, document.title, passwordRecoveryRedirect())
      if (session) void loadAccess(session)
    }} />
  }
  if (loading) return <LoadingScreen />
  if (sessionError) return <ErrorScreen message={sessionError} onRetry={() => void initializeSession()} onLogout={() => void logout()} />
  if (!session) return <Login />
  if (!access) return <ErrorScreen message="Não foi possível determinar seu acesso." onRetry={() => void loadAccess(session)} onLogout={() => void logout()} />
  return <SessionDestination
    access={access}
    route={route}
    userId={session.user.id}
    onNavigate={navigate}
    onRetry={() => void loadAccess(session)}
    onLogout={() => void logout()}
    onWorkspaceSelect={(workspace) => setAccess(workspace.role === 'receptionist' ? { kind: 'receptionist', workspace } : { kind: 'professional', workspace })}
    onPatientSelect={(patient) => setAccess({ kind: 'patient', patient })}
    defaultName={session.user.user_metadata.full_name ?? ''}
  />
}

export function App() {
  if (!isSupabaseConfigured) {
    return (
      <StatusCard title="Configuração necessária">
        <p className="mt-3 text-sm text-muted-foreground" role="alert">Configure VITE_SUPABASE_URL e VITE_SUPABASE_ANON_KEY para iniciar o BSNutri.</p>
      </StatusCard>
    )
  }
  return <ConfiguredApp />
}

export default App
