import { useMemo, useState, type FormEvent, type ReactNode } from 'react'
import { ArrowLeft } from 'lucide-react'
import { NutritionalEstimator } from '../components/NutritionalEstimator'
import { ageInYears, bodyMassIndex, bodyMassIndexCategory, waistHipRatio, weightDelta } from '../lib/clinicalMetrics'
import type { PatientSummary } from '../lib/patients'
import { supabase } from '../lib/supabase'
import { usePatientRecord, type ClinicalDraftRow } from '../lib/usePatientRecord'

type SectionId = 'evolucao' | 'avaliacoes' | 'estimativas' | 'metas' | 'exames' | 'rascunhos'

const SECTIONS: { id: SectionId; label: string }[] = [
  { id: 'evolucao', label: 'Evolução' },
  { id: 'avaliacoes', label: 'Avaliações' },
  { id: 'estimativas', label: 'Estimativas' },
  { id: 'metas', label: 'Objetivos e metas' },
  { id: 'exames', label: 'Exames' },
  { id: 'rascunhos', label: 'Rascunhos clínicos' },
]

function isSection(value: string | undefined): value is SectionId {
  return SECTIONS.some((section) => section.id === value)
}

function Panel({ title, description, children }: { title: string; description?: string; children: ReactNode }) {
  return (
    <section className="card-warm p-6">
      <h2 className="font-display text-xl font-semibold">{title}</h2>
      {description && <p className="mt-1 text-sm text-muted-foreground">{description}</p>}
      <div className="mt-4">{children}</div>
    </section>
  )
}

function Stat({ label, value }: { label: string; value: string }) {
  return (
    <div>
      <p className="eyebrow">{label}</p>
      <p className="mt-1 font-mono text-lg font-semibold">{value}</p>
    </div>
  )
}

function decimal(form: FormData, key: string): number | null {
  const raw = String(form.get(key) ?? '').replace(',', '.').trim()
  if (!raw) return null
  const parsed = Number(raw)
  return Number.isFinite(parsed) ? parsed : null
}

function text(form: FormData, key: string): string | null {
  const raw = String(form.get(key) ?? '').trim()
  return raw || null
}

function draftText(kind: ClinicalDraftRow['kind'], facts: string): string {
  if (kind === 'summary') return `Rascunho para revisão: ${facts}. Sintetizar a evolução relatada, os pontos de adesão e as pendências para o próximo encontro.`
  if (kind === 'guidance') return `Rascunho para revisão: ${facts}. Propor uma orientação curta, prática e compatível com a rotina da pessoa.`
  return `Rascunho para revisão: ${facts}. Sugerir apenas a estrutura inicial do plano, a ser completada e validada antes de salvar.`
}

export interface PatientDetailProps {
  patient: PatientSummary
  organizationId: string
  userId: string
  section: string | undefined
  onSelectSection: (section: string) => void
  onBack: () => void
  onDirectoryChange: () => Promise<void>
  onOpenPlan: (planId?: string) => void
}

export default function PatientDetail({ patient, organizationId, userId, section, onSelectSection, onBack, onDirectoryChange, onOpenPlan }: PatientDetailProps) {
  const { record, loading, errors, reload } = usePatientRecord(patient.id)
  const [message, setMessage] = useState('')
  const [draftKind, setDraftKind] = useState<ClinicalDraftRow['kind']>('summary')
  const active: SectionId = isSection(section) ? section : 'evolucao'
  const today = useMemo(() => new Date(), [])

  const latest = record.measurements[0]
  const age = ageInYears(patient.birthDate, today)
  const index = bodyMassIndex(latest?.weight_kg, latest?.height_cm)
  const category = bodyMassIndexCategory(index)
  const ratio = waistHipRatio(latest?.waist_cm, latest?.hip_cm)
  const delta = weightDelta(record.measurements.map((item) => ({ weight_kg: item.weight_kg })))
  const latestAssessment = record.assessments[0]

  async function refresh() {
    await reload()
    await onDirectoryChange()
  }

  async function addAssessment(event: FormEvent<HTMLFormElement>) {
    event.preventDefault()
    const form = new FormData(event.currentTarget)
    const result = await supabase.from('assessments').insert({
      organization_id: organizationId,
      patient_id: patient.id,
      professional_id: userId,
      objective: text(form, 'objective'),
      food_preferences: text(form, 'preferences'),
      food_restrictions: text(form, 'restrictions'),
      allergies: text(form, 'allergies'),
      clinical_notes: text(form, 'clinicalNotes'),
    })
    if (result.error) return setMessage(result.error.message)
    event.currentTarget.reset()
    setMessage('Avaliação registrada.')
    await refresh()
  }

  async function addMeasurement(event: FormEvent<HTMLFormElement>) {
    event.preventDefault()
    const form = new FormData(event.currentTarget)
    const weight = decimal(form, 'weight')
    const height = decimal(form, 'height')
    const fat = decimal(form, 'fat')
    if (weight === null && height === null) return setMessage('Informe ao menos peso ou estatura.')
    if ((weight !== null && weight <= 0) || (height !== null && height <= 0)) return setMessage('Peso e estatura precisam ser maiores que zero.')
    if (fat !== null && (fat < 0 || fat > 100)) return setMessage('Percentual de gordura deve ficar entre 0 e 100.')
    const result = await supabase.from('anthropometry').insert({
      organization_id: organizationId,
      patient_id: patient.id,
      created_by: userId,
      weight_kg: weight,
      height_cm: height,
      body_fat_percent: fat,
      waist_cm: decimal(form, 'waist'),
      hip_cm: decimal(form, 'hip'),
      arm_cm: decimal(form, 'arm'),
      notes: text(form, 'notes'),
    })
    if (result.error) return setMessage(result.error.message)
    event.currentTarget.reset()
    setMessage('Medidas registradas.')
    await refresh()
  }

  async function addGoal(event: FormEvent<HTMLFormElement>) {
    event.preventDefault()
    const form = new FormData(event.currentTarget)
    const result = await supabase.from('patient_goals').insert({
      organization_id: organizationId,
      patient_id: patient.id,
      kind: String(form.get('kind')) as 'water' | 'meals' | 'weight' | 'behavior',
      title: String(form.get('title')),
      target_value: decimal(form, 'targetValue'),
      target_unit: text(form, 'targetUnit'),
      starts_on: text(form, 'startsOn') ?? new Date().toISOString().slice(0, 10),
      created_by: userId,
    })
    if (result.error) return setMessage(result.error.message)
    event.currentTarget.reset()
    setMessage('Meta registrada.')
    await reload()
  }

  async function addLab(event: FormEvent<HTMLFormElement>) {
    event.preventDefault()
    const form = new FormData(event.currentTarget)
    const attachmentName = text(form, 'attachmentName')
    const attachmentUrl = text(form, 'attachmentUrl')
    if (Boolean(attachmentName) !== Boolean(attachmentUrl)) return setMessage('Informe nome e link do anexo juntos.')
    const result = await supabase.from('lab_results').insert({
      organization_id: organizationId,
      patient_id: patient.id,
      collected_on: String(form.get('collectedOn')),
      test_name: String(form.get('testName')),
      result_value: decimal(form, 'value'),
      unit: text(form, 'unit'),
      reference_range: text(form, 'referenceRange'),
      notes: text(form, 'notes'),
      attachment_name: attachmentName,
      attachment_url: attachmentUrl,
      created_by: userId,
    })
    if (result.error) return setMessage(result.error.message)
    event.currentTarget.reset()
    setMessage('Exame registrado.')
    await reload()
  }

  async function addSummary(event: FormEvent<HTMLFormElement>) {
    event.preventDefault()
    const form = new FormData(event.currentTarget)
    const result = await supabase.from('consultation_summaries').insert({
      organization_id: organizationId,
      patient_id: patient.id,
      summary: String(form.get('summary')),
      created_by: userId,
    })
    if (result.error) return setMessage(result.error.message)
    event.currentTarget.reset()
    setMessage('Resumo registrado.')
    await reload()
  }

  async function createDraft() {
    const facts = `${record.goals.filter((goal) => goal.active).length} metas ativas; ${record.measurements.length} medidas registradas`
    const result = await supabase.from('clinical_drafts').insert({
      organization_id: organizationId,
      patient_id: patient.id,
      kind: draftKind,
      body: draftText(draftKind, facts),
      source_snapshot: { facts },
      created_by: userId,
    })
    if (result.error) return setMessage(result.error.message)
    setMessage('Rascunho criado. Revise antes de usar.')
    await reload()
  }

  async function reviewDraft(id: string, status: 'approved' | 'discarded') {
    const result = await supabase.rpc('review_clinical_draft', { target_draft_id: id, target_status: status })
    if (result.error) return setMessage(result.error.message)
    setMessage(status === 'approved' ? 'Rascunho aprovado.' : 'Rascunho descartado.')
    await reload()
  }

  const timeline = [
    ...record.measurements.map((item) => ({ id: `m-${item.id}`, date: item.measured_at, label: `Medida · ${item.weight_kg ?? '—'} kg`, detail: item.waist_cm === null ? null : `Cintura ${item.waist_cm} cm` })),
    ...record.labs.map((item) => ({ id: `l-${item.id}`, date: item.collected_on, label: `Exame · ${item.test_name}`, detail: item.result_value === null ? null : `${item.result_value} ${item.unit ?? ''}` })),
    ...record.summaries.map((item) => ({ id: `s-${item.id}`, date: item.created_at, label: 'Resumo de consulta', detail: null })),
    ...record.estimates.map((item) => ({ id: `e-${item.id}`, date: item.calculated_on, label: `Estimativa · GET ${item.total_energy_expenditure} kcal`, detail: `TMB ${item.basal_metabolic_rate} kcal` })),
  ].sort((left, right) => new Date(right.date).getTime() - new Date(left.date).getTime())

  return (
    <div className="space-y-6">
      <button type="button" className="flex items-center gap-2 text-sm font-medium text-muted-foreground hover:text-foreground" onClick={onBack}>
        <ArrowLeft size={15} /> Voltar para pacientes
      </button>

      <header className="card-warm p-6">
        <div className="flex flex-wrap items-start justify-between gap-4">
          <div className="flex items-center gap-4">
            <div className="flex h-14 w-14 items-center justify-center rounded-full bg-forest-100 font-display text-xl font-semibold text-forest-600">
              {patient.fullName.split(' ').map((part) => part[0]).slice(0, 2).join('')}
            </div>
            <div>
              <p className="font-mono text-[11px] uppercase tracking-wider text-muted-foreground">{patient.anonymousCode}</p>
              <h1 className="font-display text-3xl font-semibold leading-tight">{patient.fullName}</h1>
              <p className="mt-1 text-sm text-muted-foreground">
                {age === null ? 'Idade não informada' : `${age} anos`}
                {patient.email ? ` · ${patient.email}` : ''}
              </p>
            </div>
          </div>
          <button type="button" className="btn-primary" onClick={() => onOpenPlan(record.plans[0]?.id)}>
            {record.plans.length ? 'Abrir plano alimentar' : 'Criar plano alimentar'}
          </button>
        </div>

        <div className="mt-6 grid grid-cols-2 gap-4 border-t border-border pt-5 sm:grid-cols-4">
          <Stat label="Peso atual" value={latest?.weight_kg === null || latest?.weight_kg === undefined ? '—' : `${latest.weight_kg} kg`} />
          <Stat label="IMC" value={index === null ? '—' : `${index.toFixed(1)}${category ? ` · ${category.label}` : ''}`} />
          <Stat label="Cintura-quadril" value={ratio === null ? '—' : ratio.toFixed(2)} />
          <Stat label="Variação de peso" value={delta === null ? '—' : `${delta > 0 ? '+' : ''}${delta.toFixed(1)} kg`} />
        </div>

        {(patient.tags.length > 0 || latestAssessment?.food_restrictions || latestAssessment?.allergies) && (
          <div className="mt-5 flex flex-wrap gap-1.5 border-t border-border pt-5">
            {patient.tags.map((tag) => <span key={tag} className="chip !bg-cream-100 text-muted-foreground">{tag}</span>)}
            {latestAssessment?.food_restrictions && <span className="chip border-amber-200 bg-amber-50 text-amber-700">Restrição: {latestAssessment.food_restrictions}</span>}
            {latestAssessment?.allergies && <span className="chip border-destructive/30 bg-destructive/10 text-destructive">Alergia: {latestAssessment.allergies}</span>}
          </div>
        )}
      </header>

      {errors.map((item) => <p key={item} className="rounded-xl border border-destructive/30 bg-destructive/10 p-3 text-sm text-destructive" role="alert">{item}</p>)}
      {message && <p className="rounded-xl border border-border bg-cream-100/60 p-3 text-sm" role="status">{message}</p>}
      {loading && <p className="text-sm text-muted-foreground" role="status">Carregando prontuário...</p>}

      <nav aria-label="Seções do prontuário" className="flex flex-wrap gap-2">
        {SECTIONS.map((item) => (
          <button
            key={item.id}
            type="button"
            aria-current={active === item.id ? 'page' : undefined}
            onClick={() => onSelectSection(item.id)}
            className={`rounded-full px-4 py-2 text-sm font-medium transition-all focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-amber-400 ${
              active === item.id ? 'bg-forest-500 text-cream-50 shadow-warm' : 'bg-cream-200 text-muted-foreground hover:text-foreground'
            }`}
          >
            {item.label}
          </button>
        ))}
      </nav>

      {active === 'evolucao' && (
        <div className="grid grid-cols-1 gap-5 lg:grid-cols-2">
          <Panel title="Nova antropometria" description="Deixe em branco o que não foi medido; o campo permanece ausente.">
            <form className="space-y-4" onSubmit={addMeasurement}>
              <div className="grid grid-cols-2 gap-4">
                <div><label className="label-warm" htmlFor="anthro-weight">Peso (kg)</label><input id="anthro-weight" name="weight" className="input-warm" inputMode="decimal" /></div>
                <div><label className="label-warm" htmlFor="anthro-height">Estatura (cm)</label><input id="anthro-height" name="height" className="input-warm" inputMode="decimal" /></div>
                <div><label className="label-warm" htmlFor="anthro-fat">Gordura (%)</label><input id="anthro-fat" name="fat" className="input-warm" inputMode="decimal" /></div>
                <div><label className="label-warm" htmlFor="anthro-waist">Cintura (cm)</label><input id="anthro-waist" name="waist" className="input-warm" inputMode="decimal" /></div>
                <div><label className="label-warm" htmlFor="anthro-hip">Quadril (cm)</label><input id="anthro-hip" name="hip" className="input-warm" inputMode="decimal" /></div>
                <div><label className="label-warm" htmlFor="anthro-arm">Braço (cm)</label><input id="anthro-arm" name="arm" className="input-warm" inputMode="decimal" /></div>
              </div>
              <div><label className="label-warm" htmlFor="anthro-notes">Observações</label><textarea id="anthro-notes" name="notes" className="input-warm min-h-[80px] resize-y" maxLength={1000} /></div>
              <button className="btn-primary w-full">Salvar medidas</button>
            </form>
          </Panel>

          <Panel title="Linha do tempo clínica">
            {timeline.length === 0 && <p className="text-sm text-muted-foreground">Registre medidas, exames ou resumos para iniciar a linha do tempo.</p>}
            <ol className="space-y-3">
              {timeline.map((item) => (
                <li key={item.id} className="rounded-xl border border-border p-4">
                  <time className="font-mono text-[11px] uppercase tracking-wider text-muted-foreground" dateTime={item.date}>{new Date(item.date).toLocaleDateString('pt-BR')}</time>
                  <p className="mt-1 font-semibold">{item.label}</p>
                  {item.detail && <p className="text-sm text-muted-foreground">{item.detail}</p>}
                </li>
              ))}
            </ol>
          </Panel>

          <div className="lg:col-span-2">
            <Panel title="Evolução antropométrica">
              {record.measurements.length === 0 && <p className="text-sm text-muted-foreground">Nenhuma medida registrada.</p>}
              <ol className="space-y-3">
                {record.measurements.map((item) => (
                  <li key={item.id} className="rounded-xl border border-border p-4">
                    <time className="font-mono text-[11px] uppercase tracking-wider text-muted-foreground" dateTime={item.measured_at}>{new Date(item.measured_at).toLocaleDateString('pt-BR')}</time>
                    <p className="mt-1 font-semibold">{item.weight_kg ?? '—'} kg · {item.height_cm ?? '—'} cm</p>
                    <p className="text-sm text-muted-foreground">
                      IMC {bodyMassIndex(item.weight_kg, item.height_cm)?.toFixed(1) ?? '—'}
                      {item.body_fat_percent === null ? '' : ` · Gordura ${item.body_fat_percent}%`}
                      {item.waist_cm === null ? '' : ` · Cintura ${item.waist_cm} cm`}
                      {item.hip_cm === null ? '' : ` · Quadril ${item.hip_cm} cm`}
                      {item.arm_cm === null ? '' : ` · Braço ${item.arm_cm} cm`}
                    </p>
                    {item.notes && <p className="mt-1 text-sm text-muted-foreground">{item.notes}</p>}
                  </li>
                ))}
              </ol>
            </Panel>
          </div>
        </div>
      )}

      {active === 'avaliacoes' && (
        <div className="grid grid-cols-1 gap-5 lg:grid-cols-2">
          <Panel title="Nova avaliação">
            <form className="space-y-4" onSubmit={addAssessment}>
              <div><label className="label-warm" htmlFor="assess-objective">Objetivo</label><input id="assess-objective" name="objective" className="input-warm" maxLength={500} /></div>
              <div><label className="label-warm" htmlFor="assess-preferences">Preferências alimentares</label><input id="assess-preferences" name="preferences" className="input-warm" maxLength={1000} /></div>
              <div><label className="label-warm" htmlFor="assess-restrictions">Restrições alimentares</label><input id="assess-restrictions" name="restrictions" className="input-warm" maxLength={1000} /></div>
              <div><label className="label-warm" htmlFor="assess-allergies">Alergias</label><input id="assess-allergies" name="allergies" className="input-warm" maxLength={1000} /></div>
              <div><label className="label-warm" htmlFor="assess-notes">Observações clínicas</label><textarea id="assess-notes" name="clinicalNotes" className="input-warm min-h-[100px] resize-y" maxLength={2000} /></div>
              <button className="btn-primary w-full">Salvar avaliação</button>
            </form>
          </Panel>

          <div className="space-y-5">
            <Panel title="Histórico de avaliações">
              {record.assessments.length === 0 && <p className="text-sm text-muted-foreground">Nenhuma avaliação registrada.</p>}
              <ol className="space-y-3">
                {record.assessments.map((item) => (
                  <li key={item.id} className="rounded-xl border border-border p-4">
                    <time className="font-mono text-[11px] uppercase tracking-wider text-muted-foreground" dateTime={item.assessed_at}>{new Date(item.assessed_at).toLocaleDateString('pt-BR')}</time>
                    <p className="mt-1 font-semibold">{item.objective ?? 'Sem objetivo informado'}</p>
                    {item.food_preferences && <p className="text-sm text-muted-foreground">Preferências: {item.food_preferences}</p>}
                    {item.food_restrictions && <p className="text-sm text-muted-foreground">Restrições: {item.food_restrictions}</p>}
                    {item.allergies && <p className="text-sm text-muted-foreground">Alergias: {item.allergies}</p>}
                    {item.clinical_notes && <p className="mt-1 text-sm text-muted-foreground">{item.clinical_notes}</p>}
                  </li>
                ))}
              </ol>
            </Panel>

            <Panel title="Resumo da consulta">
              <form className="space-y-4" onSubmit={addSummary}>
                <div><label className="label-warm" htmlFor="summary-body">Resumo clínico</label><textarea id="summary-body" name="summary" className="input-warm min-h-[100px] resize-y" required maxLength={4000} /></div>
                <button className="btn-primary w-full">Salvar resumo</button>
              </form>
              <ol className="mt-4 space-y-3">
                {record.summaries.map((item) => (
                  <li key={item.id} className="rounded-xl border border-border p-4">
                    <time className="font-mono text-[11px] uppercase tracking-wider text-muted-foreground" dateTime={item.created_at}>{new Date(item.created_at).toLocaleDateString('pt-BR')}</time>
                    <p className="mt-1 text-sm">{item.summary}</p>
                  </li>
                ))}
              </ol>
            </Panel>
          </div>
        </div>
      )}

      {active === 'estimativas' && (
        <NutritionalEstimator
          organizationId={organizationId}
          patient={{ id: patient.id, birthDate: patient.birthDate }}
          userId={userId}
          latestWeightKg={latest?.weight_kg ?? null}
          latestHeightCm={latest?.height_cm ?? null}
          estimates={record.estimates}
          onReload={reload}
        />
      )}

      {active === 'metas' && (
        <div className="grid grid-cols-1 gap-5 lg:grid-cols-2">
          <Panel title="Nova meta">
            <form className="space-y-4" onSubmit={addGoal}>
              <div>
                <label className="label-warm" htmlFor="goal-kind">Tipo</label>
                <select id="goal-kind" name="kind" className="input-warm" defaultValue="water">
                  <option value="water">Água</option>
                  <option value="meals">Refeições</option>
                  <option value="weight">Peso</option>
                  <option value="behavior">Comportamento</option>
                </select>
              </div>
              <div><label className="label-warm" htmlFor="goal-title">Meta</label><input id="goal-title" name="title" className="input-warm" required maxLength={160} placeholder="Ex.: Levar garrafa para o trabalho" /></div>
              <div className="grid grid-cols-2 gap-4">
                <div><label className="label-warm" htmlFor="goal-value">Valor</label><input id="goal-value" name="targetValue" className="input-warm" inputMode="decimal" /></div>
                <div><label className="label-warm" htmlFor="goal-unit">Unidade</label><input id="goal-unit" name="targetUnit" className="input-warm" placeholder="ml, refeições, kg" /></div>
              </div>
              <div><label className="label-warm" htmlFor="goal-start">Início</label><input id="goal-start" name="startsOn" className="input-warm" type="date" defaultValue={new Date().toISOString().slice(0, 10)} /></div>
              <button className="btn-primary w-full">Salvar meta</button>
            </form>
          </Panel>

          <Panel title="Metas do paciente">
            {record.goals.length === 0 && <p className="text-sm text-muted-foreground">Nenhuma meta registrada.</p>}
            <ol className="space-y-3">
              {record.goals.map((goal) => (
                <li key={goal.id} className="rounded-xl border border-border p-4">
                  <p className="font-semibold">{goal.title}</p>
                  <p className="text-sm text-muted-foreground">
                    {goal.kind}{goal.target_value === null ? '' : ` · ${goal.target_value} ${goal.target_unit ?? ''}`} · {goal.active ? 'ativa' : 'encerrada'}
                  </p>
                </li>
              ))}
            </ol>
          </Panel>
        </div>
      )}

      {active === 'exames' && (
        <div className="grid grid-cols-1 gap-5 lg:grid-cols-2">
          <Panel title="Novo exame">
            <form className="space-y-4" onSubmit={addLab}>
              <div className="grid grid-cols-2 gap-4">
                <div><label className="label-warm" htmlFor="lab-date">Data da coleta</label><input id="lab-date" name="collectedOn" className="input-warm" type="date" required /></div>
                <div><label className="label-warm" htmlFor="lab-name">Exame</label><input id="lab-name" name="testName" className="input-warm" required maxLength={160} /></div>
                <div><label className="label-warm" htmlFor="lab-value">Resultado</label><input id="lab-value" name="value" className="input-warm" inputMode="decimal" /></div>
                <div><label className="label-warm" htmlFor="lab-unit">Unidade</label><input id="lab-unit" name="unit" className="input-warm" maxLength={40} /></div>
              </div>
              <div><label className="label-warm" htmlFor="lab-reference">Referência</label><input id="lab-reference" name="referenceRange" className="input-warm" maxLength={120} /></div>
              <div className="grid grid-cols-2 gap-4">
                <div><label className="label-warm" htmlFor="lab-attachment-name">Nome do anexo</label><input id="lab-attachment-name" name="attachmentName" className="input-warm" maxLength={180} /></div>
                <div><label className="label-warm" htmlFor="lab-attachment-url">Link seguro</label><input id="lab-attachment-url" name="attachmentUrl" className="input-warm" type="url" placeholder="https://..." /></div>
              </div>
              <div><label className="label-warm" htmlFor="lab-notes">Observação</label><textarea id="lab-notes" name="notes" className="input-warm min-h-[80px] resize-y" maxLength={1000} /></div>
              <button className="btn-primary w-full">Salvar exame</button>
            </form>
          </Panel>

          <Panel title="Exames registrados">
            {record.labs.length === 0 && <p className="text-sm text-muted-foreground">Nenhum exame registrado.</p>}
            <ol className="space-y-3">
              {record.labs.map((item) => (
                <li key={item.id} className="rounded-xl border border-border p-4">
                  <time className="font-mono text-[11px] uppercase tracking-wider text-muted-foreground" dateTime={item.collected_on}>{new Date(`${item.collected_on}T12:00:00`).toLocaleDateString('pt-BR')}</time>
                  <p className="mt-1 font-semibold">{item.test_name}</p>
                  <p className="text-sm text-muted-foreground">
                    {item.result_value === null ? 'Sem resultado numérico' : `${item.result_value}${item.unit ? ` ${item.unit}` : ''}`}
                    {item.reference_range ? ` · Referência ${item.reference_range}` : ''}
                  </p>
                  {item.attachment_url && <a className="text-sm font-medium text-forest-600 underline" href={item.attachment_url} target="_blank" rel="noreferrer">{item.attachment_name}</a>}
                  {item.notes && <p className="mt-1 text-sm text-muted-foreground">{item.notes}</p>}
                </li>
              ))}
            </ol>
          </Panel>
        </div>
      )}

      {active === 'rascunhos' && (
        <Panel title="Propostas revisáveis" description="Os dados ficam no BSNutri. Nada é publicado ou enviado ao paciente automaticamente.">
          <div className="flex flex-wrap items-end gap-3">
            <div className="min-w-[220px] flex-1">
              <label className="label-warm" htmlFor="draft-kind">Tipo de rascunho</label>
              <select id="draft-kind" className="input-warm" value={draftKind} onChange={(event) => setDraftKind(event.target.value as ClinicalDraftRow['kind'])}>
                <option value="summary">Resumo</option>
                <option value="guidance">Orientação</option>
                <option value="plan_structure">Estrutura de plano</option>
              </select>
            </div>
            <button type="button" className="btn-ghost" onClick={() => void createDraft()}>Gerar rascunho</button>
          </div>

          <ol className="mt-4 space-y-3">
            {record.drafts.length === 0 && <p className="text-sm text-muted-foreground">Nenhum rascunho gerado.</p>}
            {record.drafts.map((draft) => (
              <li key={draft.id} className="rounded-xl border border-border p-4">
                <time className="font-mono text-[11px] uppercase tracking-wider text-muted-foreground" dateTime={draft.created_at}>
                  {new Date(draft.created_at).toLocaleDateString('pt-BR')} · {draft.kind}
                </time>
                <p className="mt-1 text-sm">{draft.body}</p>
                {draft.status === 'draft' ? (
                  <div className="mt-3 flex gap-2">
                    <button type="button" className="btn-ghost" onClick={() => void reviewDraft(draft.id, 'discarded')}>Descartar</button>
                    <button type="button" className="btn-primary" onClick={() => void reviewDraft(draft.id, 'approved')}>Aprovar após revisão</button>
                  </div>
                ) : (
                  <p className="mt-2 text-sm font-semibold">{draft.status === 'approved' ? 'Aprovado' : 'Descartado'}</p>
                )}
              </li>
            ))}
          </ol>
        </Panel>
      )}
    </div>
  )
}
