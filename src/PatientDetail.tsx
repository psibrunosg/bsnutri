import { useCallback, useEffect, useState, type FormEvent, type ReactNode } from 'react'
import type { Session } from '@supabase/supabase-js'
import { supabase } from './lib/supabase'

type Workspace = { organization_id: string; role: string; organizations: { name: string } | null }
type Patient = { id: string; anonymous_code: string; full_name: string; email: string | null; birth_date: string | null; status: string }
type Assessment = { id: string; assessed_at: string; objective: string | null; food_preferences: string | null; food_restrictions: string | null; allergies: string | null; clinical_notes: string | null }
type Anthropometry = { id: string; measured_at: string; weight_kg: number | null; height_cm: number | null; body_fat_percent: number | null; waist_cm: number | null; notes: string | null }
type Consent = { id: string; consent_type: string; document_version: string; granted_at: string; revoked_at: string | null }
type LabResult = { id: string; collected_on: string; test_name: string; result_value: number | null; unit: string | null; reference_range: string | null; notes: string | null }

function DetailSection({ title, children }: { title: string; children: ReactNode }) {
  return <section className="panel"><h2>{title}</h2>{children}</section>
}

export function PatientDetail({ patient, session, workspace, onBack }: { patient: Patient; session: Session; workspace: Workspace; onBack: () => void }) {
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
    <div className="detail-grid"><DetailSection title="Nova avaliação"><form onSubmit={addAssessment}><label>Objetivo<input name="objective" maxLength={500}/></label><label>Preferências alimentares<input name="preferences" maxLength={1000}/></label><label>Restrições alimentares<input name="restrictions" maxLength={1000}/></label><label>Alergias<input name="allergies" maxLength={1000}/></label><label>Observações clínicas<textarea name="clinicalNotes" maxLength={2000}/></label><button className="primary">Salvar avaliação</button></form></DetailSection>
    <DetailSection title="Nova antropometria"><form onSubmit={addMeasurement}><div className="field-row"><label>Peso (kg)<input name="weight" inputMode="decimal" required placeholder="Ex.: 72,5"/></label><label>Altura (cm)<input name="height" inputMode="decimal" required placeholder="Ex.: 175"/></label></div><div className="field-row"><label>Gordura (%)<input name="fat" inputMode="decimal" placeholder="Opcional"/></label><label>Cintura (cm)<input name="waist" inputMode="decimal" placeholder="Opcional"/></label></div><label>Observações da medida<textarea name="notes" maxLength={1000}/></label><button className="primary">Salvar medidas</button></form></DetailSection></div>
    <div className="detail-grid histories"><DetailSection title="Histórico de avaliações">{assessments.length ? assessments.map(a => <article className="history" key={a.id}><time>{new Date(a.assessed_at).toLocaleDateString('pt-BR')}</time><strong>{a.objective || 'Sem objetivo informado'}</strong>{a.allergies && <p>Alergias: {a.allergies}</p>}{a.clinical_notes && <p>{a.clinical_notes}</p>}</article>) : <p className="muted">Nenhuma avaliação registrada.</p>}</DetailSection>
    <DetailSection title="Evolução antropométrica">{measurements.length ? measurements.map(m => <article className="history measurement" key={m.id}><time>{new Date(m.measured_at).toLocaleDateString('pt-BR')}</time><span><strong>{m.weight_kg?.toLocaleString('pt-BR')} kg</strong> · {m.height_cm?.toLocaleString('pt-BR')} cm</span><p>IMC: {imc(m)}{m.body_fat_percent !== null ? ` · Gordura: ${m.body_fat_percent}%` : ''}{m.waist_cm !== null ? ` · Cintura: ${m.waist_cm} cm` : ''}</p>{m.notes && <p>{m.notes}</p>}</article>) : <p className="muted">Nenhuma medida registrada.</p>}</DetailSection></div>
    <div className="detail-grid histories"><DetailSection title="Consentimentos"><form onSubmit={addConsent}><label>Tipo<select name="type" defaultValue="care"><option value="care">Atendimento nutricional</option><option value="data_processing">Tratamento de dados</option><option value="guardian">Responsável</option></select></label><label>Versão do documento<input name="version" defaultValue="v1.0" required maxLength={60}/></label><label>Observação<textarea name="notes" maxLength={1000}/></label><button className="primary">Registrar consentimento</button></form>{consents.length ? consents.map(c => <article className="history" key={c.id}><time>{new Date(c.granted_at).toLocaleDateString('pt-BR')}</time><strong>{c.consent_type === 'care' ? 'Atendimento nutricional' : c.consent_type === 'data_processing' ? 'Tratamento de dados' : 'Responsável'}</strong><p>Documento {c.document_version}{c.revoked_at ? ' · Revogado' : ' · Vigente'}</p></article>) : <p className="muted">Nenhum consentimento registrado.</p>}</DetailSection>
    <DetailSection title="Exames básicos"><form onSubmit={addLab}><div className="field-row"><label>Data da coleta<input name="collectedOn" type="date" required/></label><label>Exame<input name="testName" required maxLength={160}/></label></div><div className="field-row"><label>Resultado<input name="value" inputMode="decimal"/></label><label>Unidade<input name="unit" maxLength={40}/></label></div><label>Referência<input name="referenceRange" maxLength={120}/></label><label>Observação<textarea name="notes" maxLength={1000}/></label><button className="primary">Salvar exame</button></form>{labs.length ? labs.map(l => <article className="history" key={l.id}><time>{new Date(`${l.collected_on}T12:00:00`).toLocaleDateString('pt-BR')}</time><strong>{l.test_name}</strong><p>{l.result_value ?? 'Sem resultado numérico'}{l.unit ? ` ${l.unit}` : ''}{l.reference_range ? ` · Referência: ${l.reference_range}` : ''}</p>{l.notes && <p>{l.notes}</p>}</article>) : <p className="muted">Nenhum exame registrado.</p>}</DetailSection></div></section>
}
