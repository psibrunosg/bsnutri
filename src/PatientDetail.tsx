import { useCallback, useEffect, useState, type FormEvent, type ReactNode } from 'react'
import type { Session } from '@supabase/supabase-js'
import { supabase } from './lib/supabase'
import { ClinicalDrafts } from './ClinicalDrafts'
import { printClinicalDocument } from './lib/clinicalExport'

type Workspace = { organization_id: string; role: string; organizations: { name: string } | null }
type Patient = { id: string; anonymous_code: string; full_name: string; email: string | null; birth_date: string | null; status: string }
type Assessment = { id: string; assessed_at: string; objective: string | null; allergies: string | null; clinical_notes: string | null }
type Anthropometry = { id: string; measured_at: string; weight_kg: number | null; height_cm: number | null; body_fat_percent: number | null; waist_cm: number | null; notes: string | null }
type Consent = { id: string; consent_type: string; document_version: string; granted_at: string; revoked_at: string | null }
type LabResult = { id: string; collected_on: string; test_name: string; result_value: number | null; unit: string | null; reference_range: string | null; notes: string | null }
type FormField = { id: string; label: string; field_type: string; required: boolean; position: number }
type FormVersion = { id: string; title: string; version_no: number; form_fields: FormField[] }
type FormTemplate = { id: string; name: string; form_template_versions: FormVersion[] }
type FormAssignment = { id: string; status: string; assigned_at: string; form_template_versions: FormVersion | null; form_responses: { values: Record<string, string>; status: string; submitted_at: string | null }[] }
type ConsultationSummary = { id: string; summary: string; created_at: string }
type PatientGoal = { id:string; kind:string; title:string; target_value:number|null; target_unit:string|null; active:boolean; starts_on:string; ends_on:string|null }
type WeeklySummary = { period_days:number; meal_checkins:number; completed_meals:number; water_ml:number; active_goals:number }

function DetailSection({ title, children }: { title: string; children: ReactNode }) {
  return <section className="panel"><h2>{title}</h2>{children}</section>
}

export function PatientDetail({ patient, session, workspace, onBack }: { patient: Patient; session: Session; workspace: Workspace; onBack: () => void }) {
  const [assessments, setAssessments] = useState<Assessment[]>([])
  const [measurements, setMeasurements] = useState<Anthropometry[]>([])
  const [consents, setConsents] = useState<Consent[]>([])
  const [labs, setLabs] = useState<LabResult[]>([])
  const [templates, setTemplates] = useState<FormTemplate[]>([])
  const [assignments, setAssignments] = useState<FormAssignment[]>([])
  const [summaries, setSummaries] = useState<ConsultationSummary[]>([])
  const [goals, setGoals] = useState<PatientGoal[]>([])
  const [weeklySummary, setWeeklySummary] = useState<WeeklySummary | null>(null)
  const [error, setError] = useState('')

  const load = useCallback(async () => {
    const [assessmentResult, measurementResult, consentResult, labResult, templateResult, assignmentResult, summaryResult, goalResult, weeklyResult] = await Promise.all([
      supabase.from('assessments').select('id,assessed_at,objective,allergies,clinical_notes').eq('patient_id', patient.id).order('assessed_at', { ascending: false }),
      supabase.from('anthropometry').select('id,measured_at,weight_kg,height_cm,body_fat_percent,waist_cm,notes').eq('patient_id', patient.id).order('measured_at', { ascending: false }),
      supabase.from('patient_consents').select('id,consent_type,document_version,granted_at,revoked_at').eq('patient_id', patient.id).order('granted_at', { ascending: false }),
      supabase.from('lab_results').select('id,collected_on,test_name,result_value,unit,reference_range,notes').eq('patient_id', patient.id).order('collected_on', { ascending: false }),
      supabase.from('form_templates').select('id,name,form_template_versions(id,title,version_no,form_fields(id,label,field_type,required,position))').eq('organization_id', workspace.organization_id).eq('status', 'published').order('created_at', { ascending: false }),
      supabase.from('form_assignments').select('id,status,assigned_at,form_template_versions(id,title,version_no,form_fields(id,label,field_type,required,position)),form_responses(values,status,submitted_at)').eq('patient_id', patient.id).order('assigned_at', { ascending: false }),
      supabase.from('consultation_summaries').select('id,summary,created_at').eq('patient_id', patient.id).order('created_at', { ascending: false }),
      supabase.from('patient_goals').select('id,kind,title,target_value,target_unit,active,starts_on,ends_on').eq('patient_id', patient.id).order('created_at', { ascending: false }),
      supabase.rpc('get_patient_weekly_summary', { target_patient_id: patient.id, target_days: 7 }),
    ])
    const first = assessmentResult.error ?? measurementResult.error ?? consentResult.error ?? labResult.error ?? templateResult.error ?? assignmentResult.error ?? summaryResult.error ?? goalResult.error ?? weeklyResult.error
    if (first) setError(first.message)
    else {
      setAssessments(assessmentResult.data ?? [])
      setMeasurements(measurementResult.data ?? [])
      setConsents(consentResult.data ?? [])
      setLabs(labResult.data ?? [])
      setTemplates((templateResult.data ?? []) as unknown as FormTemplate[])
      setAssignments((assignmentResult.data ?? []) as unknown as FormAssignment[])
      setSummaries(summaryResult.data ?? [])
      setGoals((goalResult.data ?? []) as PatientGoal[])
      setWeeklySummary((weeklyResult.data as WeeklySummary | null) ?? null)
    }
  }, [patient.id, workspace.organization_id])

  useEffect(() => { void load() }, [load])

  async function addAssessment(event: FormEvent<HTMLFormElement>) {
    event.preventDefault()
    const data = new FormData(event.currentTarget)
    const { error } = await supabase.from('assessments').insert({ organization_id: workspace.organization_id, patient_id: patient.id, professional_id: session.user.id, objective: String(data.get('objective')) || null, food_preferences: String(data.get('preferences')) || null, food_restrictions: String(data.get('restrictions')) || null, allergies: String(data.get('allergies')) || null, clinical_notes: String(data.get('clinicalNotes')) || null })
    if (error) setError(error.message); else { event.currentTarget.reset(); await load() }
  }

  async function addMeasurement(event: FormEvent<HTMLFormElement>) {
    event.preventDefault()
    const data = new FormData(event.currentTarget), number = (key: string) => { const value = String(data.get(key)).replace(',', '.'); return value ? Number(value) : null }
    const weight = number('weight'), height = number('height'), fat = number('fat'), waist = number('waist')
    if (!weight || !height || weight <= 0 || height <= 0 || (fat !== null && (fat < 0 || fat > 100)) || (waist !== null && waist <= 0)) return setError('Revise as medidas.')
    const { error } = await supabase.from('anthropometry').insert({ organization_id: workspace.organization_id, patient_id: patient.id, created_by: session.user.id, weight_kg: weight, height_cm: height, body_fat_percent: fat, waist_cm: waist, notes: String(data.get('notes')) || null })
    if (error) setError(error.message); else { event.currentTarget.reset(); await load() }
  }

  async function addConsent(event: FormEvent<HTMLFormElement>) {
    event.preventDefault()
    const data = new FormData(event.currentTarget)
    const { error } = await supabase.from('patient_consents').insert({ organization_id: workspace.organization_id, patient_id: patient.id, consent_type: String(data.get('type')), document_version: String(data.get('version')), notes: String(data.get('notes')) || null, recorded_by: session.user.id })
    if (error) setError(error.message); else { event.currentTarget.reset(); await load() }
  }

  async function addLab(event: FormEvent<HTMLFormElement>) {
    event.preventDefault()
    const data = new FormData(event.currentTarget), rawValue = String(data.get('value')).replace(',', '.'), resultValue = rawValue ? Number(rawValue) : null
    if (resultValue !== null && !Number.isFinite(resultValue)) return setError('Informe um resultado numerico valido.')
    const { error } = await supabase.from('lab_results').insert({ organization_id: workspace.organization_id, patient_id: patient.id, collected_on: String(data.get('collectedOn')), test_name: String(data.get('testName')), result_value: resultValue, unit: String(data.get('unit')) || null, reference_range: String(data.get('referenceRange')) || null, notes: String(data.get('notes')) || null, created_by: session.user.id })
    if (error) setError(error.message); else { event.currentTarget.reset(); await load() }
  }

  async function createIntakeTemplate(event: FormEvent<HTMLFormElement>) {
    event.preventDefault()
    const name = String(new FormData(event.currentTarget).get('name') || 'Anamnese pre-consulta')
    const template = await supabase.from('form_templates').insert({ organization_id: workspace.organization_id, name, purpose: 'pre_consultation', status: 'published', created_by: session.user.id }).select('id').single()
    if (template.error || !template.data) return setError(template.error?.message ?? 'Falha ao criar formulario.')
    const version = await supabase.from('form_template_versions').insert({ organization_id: workspace.organization_id, template_id: template.data.id, version_no: 1, title: name, published_by: session.user.id }).select('id').single()
    if (version.error || !version.data) return setError(version.error?.message ?? 'Falha ao publicar formulario.')
    const fields = [['Objetivo principal', 'short_text', true], ['Rotina alimentar', 'long_text', true], ['Sintomas ou desconfortos', 'long_text', false], ['Peso atual informado', 'number', false], ['Fome habitual de 0 a 10', 'scale', false], ['Data do ultimo exame', 'date', false]]
    const { error } = await supabase.from('form_fields').insert(fields.map(([label, field_type, required], position) => ({ organization_id: workspace.organization_id, version_id: version.data.id, label, field_type, required, position })))
    if (error) setError(error.message); else { event.currentTarget.reset(); await load() }
  }

  async function assignTemplate(event: FormEvent<HTMLFormElement>) {
    event.preventDefault()
    const versionId = String(new FormData(event.currentTarget).get('version'))
    const { error } = await supabase.from('form_assignments').insert({ organization_id: workspace.organization_id, patient_id: patient.id, version_id: versionId, assigned_by: session.user.id })
    if (error) setError(error.message); else { event.currentTarget.reset(); await load() }
  }

  async function addSummary(event: FormEvent<HTMLFormElement>) {
    event.preventDefault()
    const { error } = await supabase.from('consultation_summaries').insert({ organization_id: workspace.organization_id, patient_id: patient.id, summary: String(new FormData(event.currentTarget).get('summary')), created_by: session.user.id })
    if (error) setError(error.message); else { event.currentTarget.reset(); await load() }
  }

  async function addGoal(event: FormEvent<HTMLFormElement>) {
    event.preventDefault()
    const data = new FormData(event.currentTarget), raw=String(data.get('targetValue')).replace(',', '.'), target=raw?Number(raw):null
    if (target!==null&&!Number.isFinite(target)) return setError('Informe uma meta numérica válida.')
    const { error } = await supabase.from('patient_goals').insert({ organization_id: workspace.organization_id, patient_id: patient.id, kind: String(data.get('kind')), title: String(data.get('title')), target_value: target, target_unit: String(data.get('targetUnit')) || null, starts_on: String(data.get('startsOn')) || new Date().toISOString().slice(0,10), created_by: session.user.id })
    if (error) setError(error.message); else { event.currentTarget.reset(); await load() }
  }
  async function exportSummary(){const {error}=await supabase.rpc('audit_clinical_export',{target_patient_id:patient.id,target_kind:'summary'});if(error)return setError(error.message);if(!printClinicalDocument('Resumo nutricional',patient.full_name,summaries.map(summary=>`${new Date(summary.created_at).toLocaleDateString('pt-BR')}\n${summary.summary}`).join('\n\n')||'Sem resumo registrado.'))setError('Permita janelas pop-up para exportar.')}

  const imc = (item: Anthropometry) => item.weight_kg && item.height_cm ? (item.weight_kg / ((item.height_cm / 100) ** 2)).toFixed(1).replace('.', ',') : '-'
  const versions = templates.flatMap(t => t.form_template_versions)
  const timeline = [
    ...measurements.map(item=>({id:`measurement-${item.id}`,date:item.measured_at,label:`Medida · ${item.weight_kg ?? '-'} kg`,detail:item.waist_cm!==null?`Cintura ${item.waist_cm} cm`:null})),
    ...labs.map(item=>({id:`lab-${item.id}`,date:item.collected_on,label:`Exame · ${item.test_name}`,detail:item.result_value!==null?`${item.result_value} ${item.unit ?? ''}`:null})),
    ...summaries.map(item=>({id:`summary-${item.id}`,date:item.created_at,label:'Resumo de consulta',detail:null})),
  ].sort((a,b)=>new Date(b.date).getTime()-new Date(a.date).getTime())

  return <section className="detail"><button className="back" onClick={onBack}>Voltar para pacientes</button><div className="detail-heading"><div className="avatar">{patient.full_name.slice(0, 2).toUpperCase()}</div><div><small>{patient.anonymous_code}</small><h1>{patient.full_name}</h1></div><button className="secondary" onClick={()=>void exportSummary()}>Exportar resumo</button></div>{error && <div className="notice error" role="alert">{error}</div>}
    <div className="detail-grid"><DetailSection title="Nova avaliacao"><form onSubmit={addAssessment}><label>Objetivo<input name="objective" maxLength={500}/></label><label>Preferencias alimentares<input name="preferences" maxLength={1000}/></label><label>Restricoes alimentares<input name="restrictions" maxLength={1000}/></label><label>Alergias<input name="allergies" maxLength={1000}/></label><label>Observacoes clinicas<textarea name="clinicalNotes" maxLength={2000}/></label><button className="primary">Salvar avaliacao</button></form></DetailSection>
    <DetailSection title="Nova antropometria"><form onSubmit={addMeasurement}><div className="field-row"><label>Peso (kg)<input name="weight" inputMode="decimal" required/></label><label>Altura (cm)<input name="height" inputMode="decimal" required/></label></div><div className="field-row"><label>Gordura (%)<input name="fat" inputMode="decimal"/></label><label>Cintura (cm)<input name="waist" inputMode="decimal"/></label></div><label>Observacoes da medida<textarea name="notes" maxLength={1000}/></label><button className="primary">Salvar medidas</button></form></DetailSection></div>
    <div className="detail-grid histories"><DetailSection title="Historico de avaliacoes">{assessments.length ? assessments.map(a => <article className="history" key={a.id}><time>{new Date(a.assessed_at).toLocaleDateString('pt-BR')}</time><strong>{a.objective || 'Sem objetivo informado'}</strong>{a.allergies && <p>Alergias: {a.allergies}</p>}{a.clinical_notes && <p>{a.clinical_notes}</p>}</article>) : <p className="muted">Nenhuma avaliacao registrada.</p>}</DetailSection>
    <DetailSection title="Evolucao antropometrica">{measurements.length ? measurements.map(m => <article className="history measurement" key={m.id}><time>{new Date(m.measured_at).toLocaleDateString('pt-BR')}</time><span><strong>{m.weight_kg?.toLocaleString('pt-BR')} kg</strong> · {m.height_cm?.toLocaleString('pt-BR')} cm</span><p>IMC: {imc(m)}{m.body_fat_percent !== null ? ` · Gordura: ${m.body_fat_percent}%` : ''}{m.waist_cm !== null ? ` · Cintura: ${m.waist_cm} cm` : ''}</p>{m.notes && <p>{m.notes}</p>}</article>) : <p className="muted">Nenhuma medida registrada.</p>}</DetailSection></div>
    <div className="detail-grid histories"><DetailSection title="Pre-consulta e anamnese"><form onSubmit={createIntakeTemplate}><label>Novo modelo<input name="name" defaultValue="Anamnese pre-consulta adulto" required maxLength={120}/></label><button className="secondary">Criar modelo padrao</button></form><form onSubmit={assignTemplate}><label>Atribuir ao paciente<select name="version" required><option value="">Selecione</option>{versions.map(v => <option key={v.id} value={v.id}>{v.title} v{v.version_no}</option>)}</select></label><button className="primary">Atribuir pre-consulta</button></form>{assignments.length ? assignments.map(a => <article className="history" key={a.id}><time>{new Date(a.assigned_at).toLocaleDateString('pt-BR')}</time><strong>{a.form_template_versions?.title ?? 'Formulario'} · {a.status}</strong>{a.form_responses?.[0]?.values && <ul>{(a.form_template_versions?.form_fields ?? []).sort((x, y) => x.position - y.position).map(f => <li key={f.id}><b>{f.label}:</b> {a.form_responses[0].values[f.id] || 'Sem resposta'}</li>)}</ul>}</article>) : <p className="muted">Nenhuma pre-consulta atribuida.</p>}</DetailSection>
    <DetailSection title="Resumo da consulta"><form onSubmit={addSummary}><label>Resumo clinico curto<textarea name="summary" required maxLength={4000}/></label><button className="primary">Salvar resumo</button></form>{summaries.length ? summaries.map(s => <article className="history" key={s.id}><time>{new Date(s.created_at).toLocaleDateString('pt-BR')}</time><p>{s.summary}</p></article>) : <p className="muted">Nenhum resumo registrado.</p>}</DetailSection></div>
    <div className="detail-grid histories"><DetailSection title="Consentimentos"><form onSubmit={addConsent}><label>Tipo<select name="type" defaultValue="care"><option value="care">Atendimento nutricional</option><option value="data_processing">Tratamento de dados</option><option value="guardian">Responsavel</option></select></label><label>Versao do documento<input name="version" defaultValue="v1.0" required maxLength={60}/></label><label>Observacao<textarea name="notes" maxLength={1000}/></label><button className="primary">Registrar consentimento</button></form>{consents.length ? consents.map(c => <article className="history" key={c.id}><time>{new Date(c.granted_at).toLocaleDateString('pt-BR')}</time><strong>{c.consent_type}</strong><p>Documento {c.document_version}{c.revoked_at ? ' · Revogado' : ' · Vigente'}</p></article>) : <p className="muted">Nenhum consentimento registrado.</p>}</DetailSection>
    <DetailSection title="Exames basicos"><form onSubmit={addLab}><div className="field-row"><label>Data da coleta<input name="collectedOn" type="date" required/></label><label>Exame<input name="testName" required maxLength={160}/></label></div><div className="field-row"><label>Resultado<input name="value" inputMode="decimal"/></label><label>Unidade<input name="unit" maxLength={40}/></label></div><label>Referencia<input name="referenceRange" maxLength={120}/></label><label>Observacao<textarea name="notes" maxLength={1000}/></label><button className="primary">Salvar exame</button></form>{labs.length ? labs.map(l => <article className="history" key={l.id}><time>{new Date(`${l.collected_on}T12:00:00`).toLocaleDateString('pt-BR')}</time><strong>{l.test_name}</strong><p>{l.result_value ?? 'Sem resultado numerico'}{l.unit ? ` ${l.unit}` : ''}{l.reference_range ? ` · Referencia: ${l.reference_range}` : ''}</p>{l.notes && <p>{l.notes}</p>}</article>) : <p className="muted">Nenhum exame registrado.</p>}</DetailSection></div>
    <div className="detail-grid histories"><DetailSection title="Metas e resumo semanal"><form onSubmit={addGoal}><label>Tipo<select name="kind"><option value="water">Água</option><option value="meals">Refeições</option><option value="weight">Peso</option><option value="behavior">Comportamento</option></select></label><label>Meta<input name="title" required maxLength={160} placeholder="Ex.: Levar garrafa para o trabalho"/></label><div className="field-row"><label>Valor<input name="targetValue" inputMode="decimal"/></label><label>Unidade<input name="targetUnit" placeholder="ml, refeições, kg"/></label></div><label>Início<input name="startsOn" type="date" defaultValue={new Date().toISOString().slice(0,10)}/></label><button className="primary">Salvar meta</button></form><div className="weekly-facts"><strong>{weeklySummary?.completed_meals ?? 0}</strong><span>refeições registradas · {weeklySummary?.water_ml ?? 0} ml de água · {weeklySummary?.active_goals ?? 0} metas ativas</span></div>{goals.length?goals.map(goal=><article className="history" key={goal.id}><strong>{goal.title}</strong><p>{goal.kind}{goal.target_value!==null?` · ${goal.target_value} ${goal.target_unit ?? ''}`:''}</p></article>):<p className="muted">Nenhuma meta ativa.</p>}</DetailSection>
    <ClinicalDrafts session={session} organizationId={workspace.organization_id} patientId={patient.id} facts={`${goals.length} metas ativas; ${weeklySummary?.completed_meals ?? 0} refeições e ${weeklySummary?.water_ml ?? 0} ml de água registrados na semana`}/>
    <DetailSection title="Linha do tempo clínica"><div className="clinical-timeline">{timeline.length?timeline.map(item=><article key={item.id}><time>{new Date(item.date).toLocaleDateString('pt-BR')}</time><strong>{item.label}</strong>{item.detail&&<span>{item.detail}</span>}</article>):<p className="muted">Registre medidas, exames ou resumo de consulta para iniciar a linha do tempo.</p>}</div></DetailSection></div></section>
}
