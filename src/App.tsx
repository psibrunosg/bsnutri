import { useCallback, useEffect, useState, type FormEvent } from 'react'
import type { Session } from '@supabase/supabase-js'
import { CalendarDays, LogOut, Menu, Plus, Search, Users, Utensils, X } from 'lucide-react'
import { isSupabaseConfigured, supabase } from './lib/supabase'
import { NutritionWorkspace } from './NutritionWorkspace'
import { PatientPortal } from './PatientPortal'
import { CareWorkspace } from './CareWorkspace'
import './App.css'
import './AuthIllustration.css'

type Workspace = { organization_id: string; role: string; organizations: { name: string } | null }
type Patient = { id: string; anonymous_code: string; full_name: string; email: string | null; birth_date: string | null; status: string }
type Assessment = { id: string; assessed_at: string; objective: string | null; food_preferences: string | null; food_restrictions: string | null; allergies: string | null; clinical_notes: string | null }
type Anthropometry = { id: string; measured_at: string; weight_kg: number | null; height_cm: number | null; body_fat_percent: number | null; waist_cm: number | null; notes: string | null }
type Consent = { id: string; consent_type: string; document_version: string; granted_at: string; revoked_at: string | null }
type LabResult = { id: string; collected_on: string; test_name: string; result_value: number | null; unit: string | null; reference_range: string | null; notes: string | null }
type PatientAccess = { id: string; full_name: string; anonymous_code: string; organization_id:string; professional_id:string }

type AuthMode = 'login' | 'signup' | 'forgot' | 'recovery'

function passwordRecoveryRedirect() {
  return new URL(import.meta.env.BASE_URL, window.location.origin).toString()
}

export function AuthScreen({ recovery = false, onRecoveryComplete }: { recovery?: boolean; onRecoveryComplete?: () => void }) {
  const [mode, setMode] = useState<AuthMode>(recovery ? 'recovery' : 'login')
  const [busy, setBusy] = useState(false)
  const [message, setMessage] = useState('')
  async function submit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault(); setBusy(true); setMessage('')
    const data = new FormData(event.currentTarget)
    const email = String(data.get('email')); const password = String(data.get('password'))
    if (mode === 'forgot') {
      const result = await supabase.auth.resetPasswordForEmail(email, { redirectTo: passwordRecoveryRedirect() })
      setMessage(result.error?.message ?? 'Enviamos o link de recuperação. Confira sua caixa de entrada e o spam.')
      setBusy(false); return
    }
    if (mode === 'recovery') {
      if (password !== String(data.get('passwordConfirmation'))) { setMessage('As senhas não coincidem.'); setBusy(false); return }
      const result = await supabase.auth.updateUser({ password })
      setMessage(result.error?.message ?? 'Senha atualizada com sucesso.')
      setBusy(false); if (!result.error) onRecoveryComplete?.(); return
    }
    const result = mode === 'login'
      ? await supabase.auth.signInWithPassword({ email, password })
      : await supabase.auth.signUp({ email, password, options: { data: { full_name: String(data.get('name')) } } })
    setMessage(result.error?.message ?? (mode === 'signup' ? 'Cadastro realizado. Confira seu e-mail.' : ''))
    setBusy(false)
  }
  return <main className="auth-page"><section className="auth-card">
    <div className="brand"><span className="brand-wolf" role="img" aria-label="Rosto do lobo da BS Nutrição integrada"/><strong>BS Nutrição integrada</strong></div>
    <h1>{mode === 'login' ? 'Bem-vindo de volta' : mode === 'signup' ? 'Crie sua conta' : mode === 'forgot' ? 'Recupere sua senha' : 'Defina uma nova senha'}</h1><p>{mode === 'login' ? 'Entre com seu e-mail e senha. No primeiro acesso, crie sua conta.' : mode === 'signup' ? 'Depois do cadastro, confirme o e-mail para liberar o acesso.' : mode === 'forgot' ? 'Informe seu e-mail para receber um link seguro.' : 'Crie uma senha com pelo menos 8 caracteres.'}</p>
    {!isSupabaseConfigured && <div className="notice">Configure as variáveis VITE_SUPABASE_URL e VITE_SUPABASE_ANON_KEY.</div>}
    <form onSubmit={submit}>{mode === 'signup' && <label>Nome completo<input name="name" required minLength={2}/></label>}
      {mode !== 'recovery' && <label>E-mail<input name="email" type="email" autoComplete="email" required/></label>}
      {mode !== 'forgot' && <label>Senha<input name="password" type="password" autoComplete={mode === 'login' ? 'current-password' : 'new-password'} minLength={8} required/></label>}
      {mode === 'recovery' && <label>Confirme a nova senha<input name="passwordConfirmation" type="password" autoComplete="new-password" minLength={8} required/></label>}
      {message && <p className="form-message" role="status">{message}</p>}<button className="primary" disabled={busy || !isSupabaseConfigured}>{busy ? 'Aguarde...' : mode === 'login' ? 'Entrar' : mode === 'signup' ? 'Cadastrar' : mode === 'forgot' ? 'Enviar link de recuperação' : 'Atualizar senha'}</button>
    </form>{mode === 'login' && <div className="auth-actions"><button type="button" className="primary" onClick={() => setMode('signup')}>Criar minha conta</button><button type="button" className="link" onClick={() => setMode('forgot')}>Esqueci minha senha</button></div>}{mode === 'signup' && <button type="button" className="link" onClick={() => setMode('login')}>Já tenho uma conta</button>}{mode === 'forgot' && <button type="button" className="link" onClick={() => setMode('login')}>Voltar para entrar</button>}
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
  return <main className="auth-page"><section className="auth-card"><div className="brand"><span className="brand-wolf" role="img" aria-label="Rosto do lobo da BS Nutrição integrada"/><strong>BS Nutrição integrada</strong></div><h1>Prepare seu espaço</h1><p>Esses dados identificam você e sua clínica.</p><form onSubmit={create}><label>Seu nome<input name="name" defaultValue={session.user.user_metadata.full_name ?? ''} required/></label><label>Nome da clínica<input name="organization" defaultValue="Clínica BS" required/></label>{error && <p className="form-message">{error}</p>}<button className="primary">Criar espaço</button></form></section></main>
}

function PatientDetail({ patient, session, workspace, onBack }: { patient: Patient; session: Session; workspace: Workspace; onBack: () => void }) {
  const [assessments, setAssessments] = useState<Assessment[]>([])
  const [measurements, setMeasurements] = useState<Anthropometry[]>([])
  const [consents, setConsents] = useState<Consent[]>([])
  const [labs, setLabs] = useState<LabResult[]>([])
  const [error, setError] = useState('')
  const load = useCallback(async () => {
    const [assessmentResult, measurementResult, consentResult, labResult] = await Promise.all([
      supabase.from('assessments').select('id,assessed_at,objective,food_preferences,food_restrictions,allergies,clinical_notes').eq('patient_id', patient.id).order('assessed_at', { ascending: false }),
      supabase.from('anthropometry').select('id,measured_at,weight_kg,height_cm,body_fat_percent,waist_cm,notes').eq('patient_id', patient.id).order('measured_at', { ascending: false }),
      supabase.from('patient_consents').select('id,consent_type,document_version,granted_at,revoked_at').eq('patient_id', patient.id).order('granted_at', { ascending: false }),
      supabase.from('lab_results').select('id,collected_on,test_name,result_value,unit,reference_range,notes').eq('patient_id', patient.id).order('collected_on', { ascending: false }),
    ])
    if (assessmentResult.error || measurementResult.error || consentResult.error || labResult.error) setError(assessmentResult.error?.message ?? measurementResult.error?.message ?? consentResult.error?.message ?? labResult.error?.message ?? '')
    else { setAssessments(assessmentResult.data ?? []); setMeasurements(measurementResult.data ?? []); setConsents(consentResult.data ?? []); setLabs(labResult.data ?? []) }
  }, [patient.id])
  useEffect(() => { void load() }, [load])
  async function addAssessment(event: FormEvent<HTMLFormElement>) {
    event.preventDefault(); const data = new FormData(event.currentTarget)
    const { error } = await supabase.from('assessments').insert({ organization_id: workspace.organization_id, patient_id: patient.id, professional_id: session.user.id, objective: String(data.get('objective')) || null, food_preferences: String(data.get('preferences')) || null, food_restrictions: String(data.get('restrictions')) || null, allergies: String(data.get('allergies')) || null, clinical_notes: String(data.get('clinicalNotes')) || null })
    if (error) setError(error.message); else { event.currentTarget.reset(); await load() }
  }
  async function addMeasurement(event: FormEvent<HTMLFormElement>) {
    event.preventDefault(); const data = new FormData(event.currentTarget); const number = (key: string) => { const value = String(data.get(key)).replace(',', '.'); return value ? Number(value) : null }
    const weight = number('weight'); const height = number('height'); const fat = number('fat'); const waist = number('waist')
    if (!weight || !height || weight <= 0 || height <= 0 || (fat !== null && (fat < 0 || fat > 100)) || (waist !== null && waist <= 0)) return setError('Revise as medidas. Peso e altura devem ser positivos, e gordura deve estar entre 0 e 100%.')
    const { error } = await supabase.from('anthropometry').insert({ organization_id: workspace.organization_id, patient_id: patient.id, created_by: session.user.id, weight_kg: weight, height_cm: height, body_fat_percent: fat, waist_cm: waist, notes: String(data.get('notes')) || null })
    if (error) setError(error.message); else { event.currentTarget.reset(); await load() }
  }
  async function addConsent(event: FormEvent<HTMLFormElement>) {
    event.preventDefault(); const data = new FormData(event.currentTarget)
    const { error } = await supabase.from('patient_consents').insert({ organization_id: workspace.organization_id, patient_id: patient.id, consent_type: String(data.get('type')), document_version: String(data.get('version')), notes: String(data.get('notes')) || null, recorded_by: session.user.id })
    if (error) setError(error.message); else { event.currentTarget.reset(); await load() }
  }
  async function addLab(event: FormEvent<HTMLFormElement>) {
    event.preventDefault(); const data = new FormData(event.currentTarget); const rawValue = String(data.get('value')).replace(',', '.')
    const resultValue = rawValue ? Number(rawValue) : null
    if (resultValue !== null && !Number.isFinite(resultValue)) return setError('Informe um resultado numérico válido.')
    const { error } = await supabase.from('lab_results').insert({ organization_id: workspace.organization_id, patient_id: patient.id, collected_on: String(data.get('collectedOn')), test_name: String(data.get('testName')), result_value: resultValue, unit: String(data.get('unit')) || null, reference_range: String(data.get('referenceRange')) || null, notes: String(data.get('notes')) || null, created_by: session.user.id })
    if (error) setError(error.message); else { event.currentTarget.reset(); await load() }
  }
  const imc = (item: Anthropometry) => item.weight_kg && item.height_cm ? (item.weight_kg / ((item.height_cm / 100) ** 2)).toFixed(1).replace('.', ',') : '—'
  return <section className="detail"><button className="back" onClick={onBack}>← Voltar para pacientes</button><div className="detail-heading"><div className="avatar">{patient.full_name.slice(0,2).toUpperCase()}</div><div><small>{patient.anonymous_code}</small><h1>{patient.full_name}</h1></div></div>{error && <div className="notice error" role="alert">{error}</div>}
    <div className="detail-grid"><section className="panel"><h2>Nova avaliação</h2><form onSubmit={addAssessment}><label>Objetivo<input name="objective" maxLength={500}/></label><label>Preferências alimentares<input name="preferences" maxLength={1000}/></label><label>Restrições alimentares<input name="restrictions" maxLength={1000}/></label><label>Alergias<input name="allergies" maxLength={1000}/></label><label>Observações clínicas<textarea name="clinicalNotes" maxLength={2000}/></label><button className="primary">Salvar avaliação</button></form></section>
    <section className="panel"><h2>Nova antropometria</h2><form onSubmit={addMeasurement}><div className="field-row"><label>Peso (kg)<input name="weight" inputMode="decimal" required placeholder="Ex.: 72,5"/></label><label>Altura (cm)<input name="height" inputMode="decimal" required placeholder="Ex.: 175"/></label></div><div className="field-row"><label>Gordura (%)<input name="fat" inputMode="decimal" placeholder="Opcional"/></label><label>Cintura (cm)<input name="waist" inputMode="decimal" placeholder="Opcional"/></label></div><label>Observações da medida<textarea name="notes" maxLength={1000}/></label><button className="primary">Salvar medidas</button></form></section></div>
    <div className="detail-grid histories"><section className="panel"><h2>Histórico de avaliações</h2>{assessments.length ? assessments.map(a => <article className="history" key={a.id}><time>{new Date(a.assessed_at).toLocaleDateString('pt-BR')}</time><strong>{a.objective || 'Sem objetivo informado'}</strong>{a.allergies && <p>Alergias: {a.allergies}</p>}{a.clinical_notes && <p>{a.clinical_notes}</p>}</article>) : <p className="muted">Nenhuma avaliação registrada.</p>}</section>
    <section className="panel"><h2>Evolução antropométrica</h2>{measurements.length ? measurements.map(m => <article className="history measurement" key={m.id}><time>{new Date(m.measured_at).toLocaleDateString('pt-BR')}</time><span><strong>{m.weight_kg?.toLocaleString('pt-BR')} kg</strong> · {m.height_cm?.toLocaleString('pt-BR')} cm</span><p>IMC: {imc(m)}{m.body_fat_percent !== null ? ` · Gordura: ${m.body_fat_percent}%` : ''}{m.waist_cm !== null ? ` · Cintura: ${m.waist_cm} cm` : ''}</p>{m.notes && <p>{m.notes}</p>}</article>) : <p className="muted">Nenhuma medida registrada.</p>}</section></div>
    <div className="detail-grid histories"><section className="panel"><h2>Consentimentos</h2><form onSubmit={addConsent}><label>Tipo<select name="type" defaultValue="care"><option value="care">Atendimento nutricional</option><option value="data_processing">Tratamento de dados</option><option value="guardian">Responsável</option></select></label><label>Versão do documento<input name="version" defaultValue="v1.0" required maxLength={60}/></label><label>Observação<textarea name="notes" maxLength={1000}/></label><button className="primary">Registrar consentimento</button></form>{consents.length ? consents.map(c => <article className="history" key={c.id}><time>{new Date(c.granted_at).toLocaleDateString('pt-BR')}</time><strong>{c.consent_type === 'care' ? 'Atendimento nutricional' : c.consent_type === 'data_processing' ? 'Tratamento de dados' : 'Responsável'}</strong><p>Documento {c.document_version}{c.revoked_at ? ' · Revogado' : ' · Vigente'}</p></article>) : <p className="muted">Nenhum consentimento registrado.</p>}</section>
    <section className="panel"><h2>Exames básicos</h2><form onSubmit={addLab}><div className="field-row"><label>Data da coleta<input name="collectedOn" type="date" required/></label><label>Exame<input name="testName" required maxLength={160}/></label></div><div className="field-row"><label>Resultado<input name="value" inputMode="decimal"/></label><label>Unidade<input name="unit" maxLength={40}/></label></div><label>Referência<input name="referenceRange" maxLength={120}/></label><label>Observação<textarea name="notes" maxLength={1000}/></label><button className="primary">Salvar exame</button></form>{labs.length ? labs.map(l => <article className="history" key={l.id}><time>{new Date(`${l.collected_on}T12:00:00`).toLocaleDateString('pt-BR')}</time><strong>{l.test_name}</strong><p>{l.result_value ?? 'Sem resultado numérico'}{l.unit ? ` ${l.unit}` : ''}{l.reference_range ? ` · Referência: ${l.reference_range}` : ''}</p>{l.notes && <p>{l.notes}</p>}</article>) : <p className="muted">Nenhum exame registrado.</p>}</section></div></section>
}

function Dashboard({ session, workspace }: { session: Session; workspace: Workspace }) {
  const [patients, setPatients] = useState<Patient[]>([]); const [page, setPage] = useState<'patients' | 'nutrition' | 'care'>('patients'); const [query, setQuery] = useState(''); const [open, setOpen] = useState(false); const [selected, setSelected] = useState<Patient | null>(null); const [menu, setMenu] = useState(false); const [error, setError] = useState('')
  const load = useCallback(async () => { const { data, error } = await supabase.from('patients').select('id,anonymous_code,full_name,email,birth_date,status').eq('organization_id', workspace.organization_id).order('full_name'); if (error) setError(error.message); else setPatients(data ?? []) }, [workspace.organization_id])
  useEffect(() => { void load() }, [load])
  async function addPatient(event: FormEvent<HTMLFormElement>) { event.preventDefault(); const data = new FormData(event.currentTarget); const { error } = await supabase.from('patients').insert({ organization_id: workspace.organization_id, professional_id: session.user.id, created_by: session.user.id, anonymous_code: `P${String(patients.length + 1).padStart(3, '0')}`, full_name: String(data.get('name')), email: String(data.get('email')) || null, birth_date: String(data.get('birthDate')) || null }); if (error) setError(error.message); else { setOpen(false); await load() } }
  const shown = patients.filter(p => `${p.full_name} ${p.anonymous_code}`.toLowerCase().includes(query.toLowerCase()))
  return <div className="app-shell"><aside className={menu ? 'sidebar open' : 'sidebar'}><div className="brand inverse"><span>BS</span><strong>BSNutri</strong><button aria-label="Fechar menu" onClick={() => setMenu(false)}><X/></button></div><nav><button className={page === 'patients' ? 'active' : ''} onClick={() => { setPage('patients'); setSelected(null); setMenu(false) }}><Users/>Pacientes</button><button className={page === 'nutrition' ? 'active' : ''} onClick={() => { setPage('nutrition'); setSelected(null); setMenu(false) }}><Utensils/>Nutrição e planos</button><button className={page === 'care' ? 'active' : ''} onClick={() => { setPage('care'); setSelected(null); setMenu(false) }}><CalendarDays/>Agenda e adesão</button></nav><button className="logout" onClick={() => supabase.auth.signOut()}><LogOut/>Sair</button></aside>
    <main className="content"><header><button className="menu-button" aria-label="Abrir menu" onClick={() => setMenu(true)}><Menu/></button><div><small>{workspace.organizations?.name}</small><h1>{selected ? 'Prontuário nutricional' : page === 'nutrition' ? 'Nutrição e planos' : page === 'care' ? 'Agenda e adesão' : 'Pacientes'}</h1></div>{page === 'patients' && !selected && <button className="primary compact" onClick={() => setOpen(true)}><Plus/>Novo paciente</button>}</header>
      {page === 'nutrition' ? <NutritionWorkspace session={session} organizationId={workspace.organization_id} patients={patients}/> : page === 'care' ? <CareWorkspace session={session} organizationId={workspace.organization_id} patients={patients}/> : selected ? <PatientDetail patient={selected} session={session} workspace={workspace} onBack={() => setSelected(null)}/> : <>
      <section className="toolbar"><div className="search"><Search/><input aria-label="Buscar pacientes" placeholder="Buscar por nome ou código" value={query} onChange={e => setQuery(e.target.value)}/></div><span>{shown.length} paciente{shown.length === 1 ? '' : 's'}</span></section>{error && <div className="notice error">{error}</div>}
      <section className="patient-grid">{shown.map(p => <button className="patient-card" key={p.id} onClick={() => setSelected(p)}><div className="avatar">{p.full_name.slice(0,2).toUpperCase()}</div><div><small>{p.anonymous_code}</small><h2>{p.full_name}</h2><p>{p.email || 'E-mail não informado'}</p></div><span className="status">Ativo</span></button>)}{shown.length === 0 && <div className="empty"><Users/><h2>Nenhum paciente encontrado</h2><p>Cadastre o primeiro paciente para iniciar o acompanhamento.</p></div>}</section></>}
    </main>{open && <div className="modal-backdrop"><section className="modal" role="dialog" aria-modal="true"><header><h2>Novo paciente</h2><button aria-label="Fechar" onClick={() => setOpen(false)}><X/></button></header><form onSubmit={addPatient}><label>Nome completo<input name="name" required minLength={2}/></label><label>E-mail<input name="email" type="email"/></label><label>Data de nascimento<input name="birthDate" type="date"/></label><div className="actions"><button type="button" className="secondary" onClick={() => setOpen(false)}>Cancelar</button><button className="primary">Cadastrar</button></div></form></section></div>}</div>
}

export function App() {
  const [session, setSession] = useState<Session | null>(null); const [ready, setReady] = useState(false); const [workspace, setWorkspace] = useState<Workspace | null>(null); const [patientAccess,setPatientAccess]=useState<PatientAccess|null>(null); const [loading, setLoading] = useState(true); const [recoveringPassword, setRecoveringPassword] = useState(() => window.location.hash.includes('type=recovery'))
  async function loadWorkspace(current: Session) {
    setLoading(true);const { data } = await supabase.from('memberships').select('organization_id,role,organizations(name)').eq('user_id', current.user.id).eq('status','active').limit(1).maybeSingle()
    if(data){setWorkspace(data as unknown as Workspace);setPatientAccess(null);setReady(true);setLoading(false);return}
    await supabase.from('profiles').upsert({id:current.user.id,full_name:current.user.user_metadata.full_name??current.user.email??'Paciente'},{onConflict:'id'})
    await supabase.rpc('claim_patient_access')
    const linked=await supabase.from('patients').select('id,full_name,anonymous_code,organization_id,professional_id').eq('patient_user_id',current.user.id).limit(1).maybeSingle()
    setWorkspace(null);setPatientAccess(linked.data as PatientAccess|null);setReady(Boolean(linked.data));setLoading(false)
  }
  useEffect(() => { supabase.auth.getSession().then(({ data }) => { setSession(data.session); if (data.session && !recoveringPassword) void loadWorkspace(data.session); else setLoading(false) }); const { data } = supabase.auth.onAuthStateChange((event, next) => { setSession(next); if (event === 'PASSWORD_RECOVERY') { setRecoveringPassword(true); setLoading(false); return } if (next && !recoveringPassword) void loadWorkspace(next); else if (!next) { setWorkspace(null);setPatientAccess(null);setLoading(false) } }); return () => data.subscription.unsubscribe() }, [recoveringPassword])
  if (recoveringPassword) return <AuthScreen recovery onRecoveryComplete={() => { setRecoveringPassword(false); window.history.replaceState({}, document.title, passwordRecoveryRedirect()) }}/>
  if (loading) return <main className="loading">Carregando BSNutri...</main>; if (!session) return <AuthScreen/>;if(patientAccess)return <PatientPortal patient={patientAccess}/>; if (!ready || !workspace) return <Bootstrap session={session} onReady={() => loadWorkspace(session)}/>; return <Dashboard session={session} workspace={workspace}/>
}
export default App
