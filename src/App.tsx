import { useCallback, useEffect, useState, type FormEvent } from 'react'
import type { Session } from '@supabase/supabase-js'
import { CalendarDays, LogOut, Menu, Plus, Search, Users, Utensils, X } from 'lucide-react'
import { isSupabaseConfigured, supabase } from './lib/supabase'
import { NutritionWorkspace } from './NutritionWorkspace'
import './App.css'

type Workspace = { organization_id: string; role: string; organizations: { name: string } | null }
type Patient = { id: string; anonymous_code: string; full_name: string; email: string | null; birth_date: string | null; status: string }
type Assessment = { id: string; assessed_at: string; objective: string | null; food_preferences: string | null; food_restrictions: string | null; allergies: string | null }
type Anthropometry = { id: string; measured_at: string; weight_kg: number | null; height_cm: number | null; body_fat_percent: number | null; waist_cm: number | null }

function AuthScreen() {
  const [mode, setMode] = useState<'login' | 'signup'>('login')
  const [busy, setBusy] = useState(false)
  const [message, setMessage] = useState('')
  async function submit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault(); setBusy(true); setMessage('')
    const data = new FormData(event.currentTarget)
    const email = String(data.get('email')); const password = String(data.get('password'))
    const result = mode === 'login'
      ? await supabase.auth.signInWithPassword({ email, password })
      : await supabase.auth.signUp({ email, password, options: { data: { full_name: String(data.get('name')) } } })
    setMessage(result.error?.message ?? (mode === 'signup' ? 'Cadastro realizado. Confira seu e-mail.' : ''))
    setBusy(false)
  }
  return <main className="auth-page"><section className="auth-card">
    <div className="brand"><span>BS</span><div><strong>BSNutri</strong><small>Nutrição integrada</small></div></div>
    <h1>{mode === 'login' ? 'Bem-vindo de volta' : 'Crie sua conta'}</h1><p>Acesse seu espaço clínico com segurança.</p>
    {!isSupabaseConfigured && <div className="notice">Configure as variáveis VITE_SUPABASE_URL e VITE_SUPABASE_ANON_KEY.</div>}
    <form onSubmit={submit}>{mode === 'signup' && <label>Nome completo<input name="name" required minLength={2}/></label>}
      <label>E-mail<input name="email" type="email" autoComplete="email" required/></label>
      <label>Senha<input name="password" type="password" autoComplete={mode === 'login' ? 'current-password' : 'new-password'} minLength={8} required/></label>
      {message && <p className="form-message" role="status">{message}</p>}<button className="primary" disabled={busy || !isSupabaseConfigured}>{busy ? 'Aguarde...' : mode === 'login' ? 'Entrar' : 'Cadastrar'}</button>
    </form><button className="link" onClick={() => setMode(mode === 'login' ? 'signup' : 'login')}>{mode === 'login' ? 'Ainda não tenho conta' : 'Já tenho uma conta'}</button>
  </section></main>
}

function Bootstrap({ session, onReady }: { session: Session; onReady: () => void }) {
  const [error, setError] = useState('')
  async function create(event: FormEvent<HTMLFormElement>) {
    event.preventDefault(); setError(''); const data = new FormData(event.currentTarget)
    const fullName = String(data.get('name')); const organizationName = String(data.get('organization'))
    const slug = `${organizationName.toLowerCase().normalize('NFD').replace(/[\u0300-\u036f]/g, '').replace(/[^a-z0-9]+/g, '-').replace(/(^-|-$)/g, '')}-${crypto.randomUUID().slice(0, 6)}`
    const { error } = await supabase.rpc('bootstrap_organization', { full_name_input: fullName, organization_name_input: organizationName, organization_slug_input: slug })
    if (error) return setError(error.message); onReady()
  }
  return <main className="auth-page"><section className="auth-card"><div className="brand"><span>BS</span><strong>BSNutri</strong></div><h1>Prepare seu espaço</h1><p>Esses dados identificam você e sua clínica.</p><form onSubmit={create}><label>Seu nome<input name="name" defaultValue={session.user.user_metadata.full_name ?? ''} required/></label><label>Nome da clínica<input name="organization" defaultValue="Clínica BS" required/></label>{error && <p className="form-message">{error}</p>}<button className="primary">Criar espaço</button></form></section></main>
}

function PatientDetail({ patient, session, workspace, onBack }: { patient: Patient; session: Session; workspace: Workspace; onBack: () => void }) {
  const [assessments, setAssessments] = useState<Assessment[]>([])
  const [measurements, setMeasurements] = useState<Anthropometry[]>([])
  const [error, setError] = useState('')
  const load = useCallback(async () => {
    const [assessmentResult, measurementResult] = await Promise.all([
      supabase.from('assessments').select('id,assessed_at,objective,food_preferences,food_restrictions,allergies').eq('patient_id', patient.id).order('assessed_at', { ascending: false }),
      supabase.from('anthropometry').select('id,measured_at,weight_kg,height_cm,body_fat_percent,waist_cm').eq('patient_id', patient.id).order('measured_at', { ascending: false }),
    ])
    if (assessmentResult.error || measurementResult.error) setError(assessmentResult.error?.message ?? measurementResult.error?.message ?? '')
    else { setAssessments(assessmentResult.data ?? []); setMeasurements(measurementResult.data ?? []) }
  }, [patient.id])
  useEffect(() => { void load() }, [load])
  async function addAssessment(event: FormEvent<HTMLFormElement>) {
    event.preventDefault(); const data = new FormData(event.currentTarget)
    const { error } = await supabase.from('assessments').insert({ organization_id: workspace.organization_id, patient_id: patient.id, professional_id: session.user.id, objective: String(data.get('objective')) || null, food_preferences: String(data.get('preferences')) || null, food_restrictions: String(data.get('restrictions')) || null, allergies: String(data.get('allergies')) || null })
    if (error) setError(error.message); else { event.currentTarget.reset(); await load() }
  }
  async function addMeasurement(event: FormEvent<HTMLFormElement>) {
    event.preventDefault(); const data = new FormData(event.currentTarget); const number = (key: string) => { const value = String(data.get(key)).replace(',', '.'); return value ? Number(value) : null }
    const weight = number('weight'); const height = number('height'); const fat = number('fat'); const waist = number('waist')
    if (!weight || !height || weight <= 0 || height <= 0 || (fat !== null && (fat < 0 || fat > 100)) || (waist !== null && waist <= 0)) return setError('Revise as medidas. Peso e altura devem ser positivos, e gordura deve estar entre 0 e 100%.')
    const { error } = await supabase.from('anthropometry').insert({ organization_id: workspace.organization_id, patient_id: patient.id, created_by: session.user.id, weight_kg: weight, height_cm: height, body_fat_percent: fat, waist_cm: waist })
    if (error) setError(error.message); else { event.currentTarget.reset(); await load() }
  }
  const imc = (item: Anthropometry) => item.weight_kg && item.height_cm ? (item.weight_kg / ((item.height_cm / 100) ** 2)).toFixed(1).replace('.', ',') : '—'
  return <section className="detail"><button className="back" onClick={onBack}>← Voltar para pacientes</button><div className="detail-heading"><div className="avatar">{patient.full_name.slice(0,2).toUpperCase()}</div><div><small>{patient.anonymous_code}</small><h1>{patient.full_name}</h1></div></div>{error && <div className="notice error" role="alert">{error}</div>}
    <div className="detail-grid"><section className="panel"><h2>Nova avaliação</h2><form onSubmit={addAssessment}><label>Objetivo<input name="objective" maxLength={500}/></label><label>Preferências alimentares<input name="preferences" maxLength={1000}/></label><label>Restrições alimentares<input name="restrictions" maxLength={1000}/></label><label>Alergias<input name="allergies" maxLength={1000}/></label><button className="primary">Salvar avaliação</button></form></section>
    <section className="panel"><h2>Nova antropometria</h2><form onSubmit={addMeasurement}><div className="field-row"><label>Peso (kg)<input name="weight" inputMode="decimal" required placeholder="Ex.: 72,5"/></label><label>Altura (cm)<input name="height" inputMode="decimal" required placeholder="Ex.: 175"/></label></div><div className="field-row"><label>Gordura (%)<input name="fat" inputMode="decimal" placeholder="Opcional"/></label><label>Cintura (cm)<input name="waist" inputMode="decimal" placeholder="Opcional"/></label></div><button className="primary">Salvar medidas</button></form></section></div>
    <div className="detail-grid histories"><section className="panel"><h2>Histórico de avaliações</h2>{assessments.length ? assessments.map(a => <article className="history" key={a.id}><time>{new Date(a.assessed_at).toLocaleDateString('pt-BR')}</time><strong>{a.objective || 'Sem objetivo informado'}</strong>{a.allergies && <p>Alergias: {a.allergies}</p>}</article>) : <p className="muted">Nenhuma avaliação registrada.</p>}</section>
    <section className="panel"><h2>Evolução antropométrica</h2>{measurements.length ? measurements.map(m => <article className="history measurement" key={m.id}><time>{new Date(m.measured_at).toLocaleDateString('pt-BR')}</time><span><strong>{m.weight_kg?.toLocaleString('pt-BR')} kg</strong> · {m.height_cm?.toLocaleString('pt-BR')} cm</span><p>IMC: {imc(m)}{m.body_fat_percent !== null ? ` · Gordura: ${m.body_fat_percent}%` : ''}{m.waist_cm !== null ? ` · Cintura: ${m.waist_cm} cm` : ''}</p></article>) : <p className="muted">Nenhuma medida registrada.</p>}</section></div></section>
}

function Dashboard({ session, workspace }: { session: Session; workspace: Workspace }) {
  const [patients, setPatients] = useState<Patient[]>([]); const [page, setPage] = useState<'patients' | 'nutrition'>('patients'); const [query, setQuery] = useState(''); const [open, setOpen] = useState(false); const [selected, setSelected] = useState<Patient | null>(null); const [menu, setMenu] = useState(false); const [error, setError] = useState('')
  const load = useCallback(async () => { const { data, error } = await supabase.from('patients').select('id,anonymous_code,full_name,email,birth_date,status').eq('organization_id', workspace.organization_id).order('full_name'); if (error) setError(error.message); else setPatients(data ?? []) }, [workspace.organization_id])
  useEffect(() => { void load() }, [load])
  async function addPatient(event: FormEvent<HTMLFormElement>) { event.preventDefault(); const data = new FormData(event.currentTarget); const { error } = await supabase.from('patients').insert({ organization_id: workspace.organization_id, professional_id: session.user.id, created_by: session.user.id, anonymous_code: `P${String(patients.length + 1).padStart(3, '0')}`, full_name: String(data.get('name')), email: String(data.get('email')) || null, birth_date: String(data.get('birthDate')) || null }); if (error) setError(error.message); else { setOpen(false); await load() } }
  const shown = patients.filter(p => `${p.full_name} ${p.anonymous_code}`.toLowerCase().includes(query.toLowerCase()))
  return <div className="app-shell"><aside className={menu ? 'sidebar open' : 'sidebar'}><div className="brand inverse"><span>BS</span><strong>BSNutri</strong><button aria-label="Fechar menu" onClick={() => setMenu(false)}><X/></button></div><nav><button className={page === 'patients' ? 'active' : ''} onClick={() => { setPage('patients'); setSelected(null); setMenu(false) }}><Users/>Pacientes</button><button className={page === 'nutrition' ? 'active' : ''} onClick={() => { setPage('nutrition'); setSelected(null); setMenu(false) }}><Utensils/>Nutrição e planos</button><a><CalendarDays/>Agenda</a></nav><button className="logout" onClick={() => supabase.auth.signOut()}><LogOut/>Sair</button></aside>
    <main className="content"><header><button className="menu-button" aria-label="Abrir menu" onClick={() => setMenu(true)}><Menu/></button><div><small>{workspace.organizations?.name}</small><h1>{selected ? 'Prontuário nutricional' : page === 'nutrition' ? 'Nutrição e planos' : 'Pacientes'}</h1></div>{page === 'patients' && !selected && <button className="primary compact" onClick={() => setOpen(true)}><Plus/>Novo paciente</button>}</header>
      {page === 'nutrition' ? <NutritionWorkspace session={session} organizationId={workspace.organization_id} patients={patients}/> : selected ? <PatientDetail patient={selected} session={session} workspace={workspace} onBack={() => setSelected(null)}/> : <>
      <section className="toolbar"><div className="search"><Search/><input aria-label="Buscar pacientes" placeholder="Buscar por nome ou código" value={query} onChange={e => setQuery(e.target.value)}/></div><span>{shown.length} paciente{shown.length === 1 ? '' : 's'}</span></section>{error && <div className="notice error">{error}</div>}
      <section className="patient-grid">{shown.map(p => <button className="patient-card" key={p.id} onClick={() => setSelected(p)}><div className="avatar">{p.full_name.slice(0,2).toUpperCase()}</div><div><small>{p.anonymous_code}</small><h2>{p.full_name}</h2><p>{p.email || 'E-mail não informado'}</p></div><span className="status">Ativo</span></button>)}{shown.length === 0 && <div className="empty"><Users/><h2>Nenhum paciente encontrado</h2><p>Cadastre o primeiro paciente para iniciar o acompanhamento.</p></div>}</section></>}
    </main>{open && <div className="modal-backdrop"><section className="modal" role="dialog" aria-modal="true"><header><h2>Novo paciente</h2><button aria-label="Fechar" onClick={() => setOpen(false)}><X/></button></header><form onSubmit={addPatient}><label>Nome completo<input name="name" required minLength={2}/></label><label>E-mail<input name="email" type="email"/></label><label>Data de nascimento<input name="birthDate" type="date"/></label><div className="actions"><button type="button" className="secondary" onClick={() => setOpen(false)}>Cancelar</button><button className="primary">Cadastrar</button></div></form></section></div>}</div>
}

export function App() {
  const [session, setSession] = useState<Session | null>(null); const [ready, setReady] = useState(false); const [workspace, setWorkspace] = useState<Workspace | null>(null); const [loading, setLoading] = useState(true)
  async function loadWorkspace(userId: string) { const { data } = await supabase.from('memberships').select('organization_id,role,organizations(name)').eq('user_id', userId).eq('status','active').limit(1).maybeSingle(); setWorkspace(data as unknown as Workspace | null); setReady(Boolean(data)); setLoading(false) }
  useEffect(() => { supabase.auth.getSession().then(({ data }) => { setSession(data.session); if (data.session) void loadWorkspace(data.session.user.id); else setLoading(false) }); const { data } = supabase.auth.onAuthStateChange((_event, next) => { setSession(next); if (next) void loadWorkspace(next.user.id); else { setWorkspace(null); setLoading(false) } }); return () => data.subscription.unsubscribe() }, [])
  if (loading) return <main className="loading">Carregando BSNutri...</main>; if (!session) return <AuthScreen/>; if (!ready || !workspace) return <Bootstrap session={session} onReady={() => loadWorkspace(session.user.id)}/>; return <Dashboard session={session} workspace={workspace}/>
}
export default App
