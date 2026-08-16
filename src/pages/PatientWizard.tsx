import { useMemo, useState } from 'react'
import { ArrowLeft, ArrowRight, Check, Ruler, Target, User } from 'lucide-react'
import { bodyMassIndex, bodyMassIndexCategory, waistHipRatio } from '../lib/clinicalMetrics'
import type { PatientDataSource } from '../lib/patients'

const STEPS = [
  { id: 'dados', label: 'Identificação', icon: User },
  { id: 'medidas', label: 'Antropometria', icon: Ruler },
  { id: 'objetivo', label: 'Objetivo', icon: Target },
] as const

const TONE_COLOR = {
  low: 'text-amber-700',
  healthy: 'text-forest-600',
  warning: 'text-amber-700',
  high: 'text-destructive',
  critical: 'text-destructive',
} as const

/**
 * Campo numérico opcional: vazio significa ausente, nunca zero.
 * Usa entrada de texto para aceitar vírgula decimal — `type="number"` descarta
 * silenciosamente "68,5" e transformaria a medida informada em ausente.
 */
function MeasureField({ id, label, unit, value, onChange, hint }: {
  id: string
  label: string
  unit: string
  value: string
  onChange: (value: string) => void
  hint?: string
}) {
  return (
    <div>
      <label className="label-warm" htmlFor={id}>{label} ({unit})</label>
      <input
        id={id}
        className="input-warm"
        type="text"
        inputMode="decimal"
        value={value}
        placeholder="Não informado"
        onChange={(event) => onChange(event.target.value)}
      />
      {hint && <p className="mt-1 text-[11px] text-muted-foreground">{hint}</p>}
    </div>
  )
}

function toNumber(value: string): number | null {
  const parsed = Number(value.replace(',', '.'))
  if (!value.trim() || !Number.isFinite(parsed) || parsed <= 0) return null
  return parsed
}

export interface PatientWizardProps {
  organizationId: string
  dataSource: PatientDataSource
  onCancel: () => void
  onCreated: (patientId: string) => Promise<void> | void
}

export default function PatientWizard({ organizationId, dataSource, onCancel, onCreated }: PatientWizardProps) {
  const [step, setStep] = useState(0)
  const [busy, setBusy] = useState(false)
  const [error, setError] = useState('')

  const [fullName, setFullName] = useState('')
  const [email, setEmail] = useState('')
  const [phone, setPhone] = useState('')
  const [birthDate, setBirthDate] = useState('')

  const [weight, setWeight] = useState('')
  const [height, setHeight] = useState('')
  const [waist, setWaist] = useState('')
  const [hip, setHip] = useState('')
  const [arm, setArm] = useState('')
  const [bodyFat, setBodyFat] = useState('')

  const [objective, setObjective] = useState('')
  const [restrictions, setRestrictions] = useState('')
  const [allergies, setAllergies] = useState('')
  const [notes, setNotes] = useState('')
  const [tagInput, setTagInput] = useState('')
  const [tags, setTags] = useState<string[]>([])

  const index = useMemo(() => bodyMassIndex(toNumber(weight), toNumber(height)), [weight, height])
  const category = bodyMassIndexCategory(index)
  const ratio = useMemo(() => waistHipRatio(toNumber(waist), toNumber(hip)), [waist, hip])
  const canAdvance = step !== 0 || fullName.trim().length > 1

  function addTag() {
    const tag = tagInput.trim().toLowerCase()
    if (!tag) return
    setTags((current) => (current.includes(tag) ? current : [...current, tag]))
    setTagInput('')
  }

  async function finish() {
    setBusy(true)
    setError('')
    const result = await dataSource.createPatientIntake({
      organizationId,
      fullName: fullName.trim(),
      email: email.trim() || null,
      phone: phone.trim() || null,
      birthDate: birthDate || null,
      tags,
      objective: objective.trim() || null,
      foodRestrictions: restrictions.trim() || null,
      allergies: allergies.trim() || null,
      clinicalNotes: notes.trim() || null,
      weightKg: toNumber(weight),
      heightCm: toNumber(height),
      waistCm: toNumber(waist),
      hipCm: toNumber(hip),
      armCm: toNumber(arm),
      bodyFatPercent: toNumber(bodyFat),
    })
    setBusy(false)
    if (result.error || !result.data) {
      setError(result.error?.message ?? 'Não foi possível concluir o cadastro.')
      return
    }
    await onCreated(result.data)
  }

  return (
    <div className="mx-auto max-w-3xl">
      <button type="button" className="mb-6 flex items-center gap-2 text-sm font-medium text-muted-foreground hover:text-foreground" onClick={onCancel}>
        <ArrowLeft size={15} /> Voltar para pacientes
      </button>

      <p className="eyebrow mb-2">Cadastro clínico</p>
      <h1 className="font-display text-3xl font-semibold">Novo paciente</h1>
      <p className="mt-1.5 max-w-xl text-[15px] text-muted-foreground">
        Paciente, avaliação e antropometria são gravados em uma única transação. Medidas não informadas permanecem ausentes.
      </p>

      <ol className="mb-8 mt-8 flex items-center gap-2">
        {STEPS.map((item, position) => (
          <li key={item.id} className="flex flex-1 items-center gap-2">
            <button
              type="button"
              aria-current={position === step ? 'step' : undefined}
              disabled={position > step}
              onClick={() => position < step && setStep(position)}
              className={`flex items-center gap-2.5 rounded-full px-4 py-2 text-sm font-medium transition-all focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-amber-400 ${
                position === step ? 'bg-forest-500 text-cream-50 shadow-warm' : position < step ? 'bg-forest-100 text-forest-600' : 'bg-cream-200 text-muted-foreground'
              }`}
            >
              {position < step ? <Check size={14} /> : <item.icon size={14} />}
              {item.label}
            </button>
            {position < STEPS.length - 1 && <span aria-hidden="true" className={`h-px flex-1 ${position < step ? 'bg-forest-300' : 'bg-border'}`} />}
          </li>
        ))}
      </ol>

      {error && <p className="mb-6 rounded-xl border border-destructive/30 bg-destructive/10 p-4 text-sm text-destructive" role="alert">{error}</p>}

      {step === 0 && (
        <div className="card-warm space-y-5 p-6">
          <div>
            <label className="label-warm" htmlFor="patient-name">Nome completo *</label>
            <input id="patient-name" autoFocus className="input-warm !py-3 !text-base" value={fullName} onChange={(event) => setFullName(event.target.value)} placeholder="Ex.: Mariana Lopes" required minLength={2} />
          </div>
          <div className="grid grid-cols-1 gap-5 sm:grid-cols-2">
            <div>
              <label className="label-warm" htmlFor="patient-email">E-mail</label>
              <input id="patient-email" className="input-warm" type="email" value={email} onChange={(event) => setEmail(event.target.value)} placeholder="paciente@email.com" />
            </div>
            <div>
              <label className="label-warm" htmlFor="patient-phone">Telefone / WhatsApp</label>
              <input id="patient-phone" className="input-warm" value={phone} onChange={(event) => setPhone(event.target.value)} placeholder="(53) 9 9999-9999" />
            </div>
            <div>
              <label className="label-warm" htmlFor="patient-birth">Data de nascimento</label>
              <input id="patient-birth" className="input-warm" type="date" value={birthDate} onChange={(event) => setBirthDate(event.target.value)} />
              <p className="mt-1 text-[11px] text-muted-foreground">Sem data de nascimento a idade fica ausente e as estimativas energéticas ficam bloqueadas.</p>
            </div>
          </div>
        </div>
      )}

      {step === 1 && (
        <div className="grid grid-cols-1 gap-5 lg:grid-cols-5">
          <div className="card-warm space-y-5 p-6 lg:col-span-3">
            <div className="grid grid-cols-1 gap-4 sm:grid-cols-2">
              <MeasureField id="measure-weight" label="Peso corporal" unit="kg" value={weight} onChange={setWeight} />
              <MeasureField id="measure-height" label="Estatura" unit="cm" value={height} onChange={setHeight} />
              <MeasureField id="measure-waist" label="Circunferência da cintura" unit="cm" value={waist} onChange={setWaist} />
              <MeasureField id="measure-hip" label="Circunferência do quadril" unit="cm" value={hip} onChange={setHip} />
              <MeasureField id="measure-arm" label="Circunferência do braço" unit="cm" value={arm} onChange={setArm} />
              <MeasureField id="measure-fat" label="Gordura corporal" unit="%" value={bodyFat} onChange={setBodyFat} hint="Bioimpedância ou dobras cutâneas" />
            </div>
          </div>

          <aside className="lg:col-span-2">
            <div className="card-warm sticky top-6 space-y-5 p-5">
              <p className="eyebrow">Leitura ao vivo</p>
              <div>
                <div className="flex items-baseline justify-between">
                  <p className="text-sm font-medium">IMC</p>
                  <p className={`font-display text-3xl font-semibold ${category ? TONE_COLOR[category.tone] : 'text-muted-foreground'}`}>
                    {index === null ? '—' : index.toFixed(1)}
                  </p>
                </div>
                <p className={`mt-2 text-sm font-medium ${category ? TONE_COLOR[category.tone] : 'text-muted-foreground'}`}>
                  {category?.label ?? 'Informe peso e estatura'}
                </p>
              </div>
              <div className="border-t border-border pt-4">
                <p className="font-mono text-lg font-semibold text-forest-600">{ratio === null ? '—' : ratio.toFixed(2)}</p>
                <p className="text-[11px] text-muted-foreground">Relação cintura-quadril</p>
              </div>
              <p className="text-[11px] leading-relaxed text-muted-foreground">
                A estimativa energética (TMB e GET) é feita na ficha do paciente, com protocolo, sexo biológico e idade informados explicitamente.
              </p>
            </div>
          </aside>
        </div>
      )}

      {step === 2 && (
        <div className="card-warm space-y-5 p-6">
          <div>
            <label className="label-warm" htmlFor="patient-objective">Objetivo do acompanhamento</label>
            <div className="mb-3 grid grid-cols-2 gap-2 sm:grid-cols-4">
              {['Perda de peso', 'Ganho de massa', 'Manutenção', 'Performance'].map((preset) => (
                <button
                  key={preset}
                  type="button"
                  onClick={() => setObjective(preset)}
                  className={`rounded-xl border px-3 py-2.5 text-sm font-medium transition-all focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-amber-400 ${
                    objective === preset ? 'border-amber-400 bg-amber-50 text-amber-700 shadow-warm' : 'border-border bg-card text-muted-foreground hover:border-amber-200'
                  }`}
                >
                  {preset}
                </button>
              ))}
            </div>
            <input id="patient-objective" className="input-warm" value={objective} onChange={(event) => setObjective(event.target.value)} placeholder="Ou descreva livremente..." />
          </div>

          <div className="grid grid-cols-1 gap-5 sm:grid-cols-2">
            <div>
              <label className="label-warm" htmlFor="patient-restrictions">Restrições alimentares</label>
              <input id="patient-restrictions" className="input-warm" value={restrictions} onChange={(event) => setRestrictions(event.target.value)} placeholder="Ex.: sem lactose" />
            </div>
            <div>
              <label className="label-warm" htmlFor="patient-allergies">Alergias</label>
              <input id="patient-allergies" className="input-warm" value={allergies} onChange={(event) => setAllergies(event.target.value)} placeholder="Ex.: amendoim" />
            </div>
          </div>

          <div>
            <label className="label-warm" htmlFor="patient-tags">Tags do paciente</label>
            <div className="flex gap-2">
              <input
                id="patient-tags"
                className="input-warm"
                value={tagInput}
                onChange={(event) => setTagInput(event.target.value)}
                placeholder="Ex.: low carb, vegetariano, corrida"
                onKeyDown={(event) => {
                  if (event.key !== 'Enter') return
                  event.preventDefault()
                  addTag()
                }}
              />
              <button type="button" className="btn-ghost shrink-0" onClick={addTag}>Adicionar</button>
            </div>
            <div className="mt-2 flex flex-wrap gap-1.5">
              {tags.map((tag) => (
                <button key={tag} type="button" className="chip text-forest-600 hover:border-destructive/40 hover:text-destructive" onClick={() => setTags(tags.filter((item) => item !== tag))}>
                  {tag} ×
                </button>
              ))}
            </div>
          </div>

          <div>
            <label className="label-warm" htmlFor="patient-notes">Observações clínicas</label>
            <textarea id="patient-notes" className="input-warm min-h-[100px] resize-y" value={notes} onChange={(event) => setNotes(event.target.value)} placeholder="Rotina, preferências, histórico..." />
          </div>
        </div>
      )}

      <div className="mt-8 flex justify-between">
        <button type="button" className="btn-ghost" disabled={step === 0 || busy} onClick={() => setStep((current) => current - 1)}>
          <ArrowLeft size={16} /> Anterior
        </button>
        {step < STEPS.length - 1 ? (
          <button type="button" className="btn-primary" disabled={!canAdvance} onClick={() => setStep((current) => current + 1)}>
            Continuar <ArrowRight size={16} />
          </button>
        ) : (
          <button type="button" className="btn-amber !px-6" disabled={busy || fullName.trim().length < 2} onClick={() => void finish()}>
            <Check size={16} /> {busy ? 'Gravando cadastro...' : 'Concluir cadastro'}
          </button>
        )}
      </div>
    </div>
  )
}
