import { useMemo, useState, type FormEvent } from 'react'
import { ACTIVITY_LEVEL_PRESETS, PROTOCOL_DESCRIPTIONS, PROTOCOL_LABELS, calculateEnergyEstimate } from '../lib/energyEstimations'
import { ageInYears, isEstimateInputComplete } from '../lib/clinicalMetrics'
import { supabase } from '../lib/supabase'
import type { BiologicalSex, EnergyProtocol, NutritionalEstimateRow } from '../types'

export interface NutritionalEstimatorProps {
  organizationId: string
  patient: { id: string; birthDate: string | null }
  userId: string
  latestWeightKg: number | null
  latestHeightCm: number | null
  estimates: NutritionalEstimateRow[]
  onReload: () => Promise<void>
}

function decimal(value: string): number | null {
  const parsed = Number(value.replace(',', '.'))
  if (!value.trim() || !Number.isFinite(parsed) || parsed <= 0) return null
  return parsed
}

export function NutritionalEstimator({ organizationId, patient, userId, latestWeightKg, latestHeightCm, estimates, onReload }: NutritionalEstimatorProps) {
  const today = useMemo(() => new Date(), [])
  const age = ageInYears(patient.birthDate, today)

  const [protocol, setProtocol] = useState<EnergyProtocol>('mifflin_st_jeor')
  const [sex, setSex] = useState<BiologicalSex | ''>('')
  const [weight, setWeight] = useState(latestWeightKg === null ? '' : String(latestWeightKg))
  const [height, setHeight] = useState(latestHeightCm === null ? '' : String(latestHeightCm))
  const [activityFactor, setActivityFactor] = useState(1.55)
  const [notes, setNotes] = useState('')
  const [error, setError] = useState('')
  const [busy, setBusy] = useState(false)

  const weightKg = decimal(weight)
  const heightCm = decimal(height)
  const complete = isEstimateInputComplete({ weightKg, heightCm, ageYears: age, biologicalSex: sex === '' ? null : sex })

  const preview = complete
    ? calculateEnergyEstimate({
        protocol,
        currentWeightKg: weightKg as number,
        heightCm: heightCm as number,
        ageYears: age as number,
        biologicalSex: sex as BiologicalSex,
        activityFactor,
      })
    : null

  const missing = [
    age === null ? 'data de nascimento do paciente' : null,
    sex === '' ? 'sexo biológico' : null,
    weightKg === null ? 'peso atual' : null,
    heightCm === null ? 'estatura' : null,
  ].filter((item): item is string => item !== null)

  async function submit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault()
    if (!preview || weightKg === null || heightCm === null || age === null || sex === '') {
      setError(`Informe ${missing.join(', ')} para calcular a estimativa.`)
      return
    }
    setError('')
    setBusy(true)
    const result = await supabase.from('nutritional_estimates').insert({
      organization_id: organizationId,
      patient_id: patient.id,
      protocol,
      current_weight_kg: weightKg,
      height_cm: heightCm,
      age_years: age,
      biological_sex: sex,
      activity_factor: activityFactor,
      basal_metabolic_rate: preview.basalMetabolicRate,
      total_energy_expenditure: preview.totalEnergyExpenditure,
      notes: notes.trim() || null,
      created_by: userId,
    })
    setBusy(false)
    if (result.error) {
      setError(result.error.message)
      return
    }
    setNotes('')
    await onReload()
  }

  return (
    <div className="grid grid-cols-1 gap-5 lg:grid-cols-2">
      <section className="card-warm p-6">
        <h2 className="font-display text-xl font-semibold">Nova estimativa energética</h2>
        <p className="mt-1 text-sm text-muted-foreground">TMB e GET só são calculados com dados clínicos completos. Nenhum valor é presumido.</p>

        {age === null && (
          <p className="mt-4 rounded-xl border border-amber-200 bg-amber-50 p-3 text-sm text-amber-700" role="status">
            Sem data de nascimento cadastrada não é possível estimar o gasto energético. Registre a data na identificação do paciente.
          </p>
        )}
        {error && <p className="mt-4 rounded-xl border border-destructive/30 bg-destructive/10 p-3 text-sm text-destructive" role="alert">{error}</p>}

        <form className="mt-5 space-y-4" onSubmit={submit}>
          <div>
            <label className="label-warm" htmlFor="estimate-protocol">Protocolo de cálculo</label>
            <select id="estimate-protocol" className="input-warm" value={protocol} onChange={(event) => setProtocol(event.target.value as EnergyProtocol)}>
              {Object.entries(PROTOCOL_LABELS).map(([key, label]) => <option key={key} value={key}>{label}</option>)}
            </select>
            <p className="mt-1 text-[11px] text-muted-foreground">{PROTOCOL_DESCRIPTIONS[protocol]}</p>
          </div>

          <div className="grid grid-cols-1 gap-4 sm:grid-cols-2">
            <div>
              <label className="label-warm" htmlFor="estimate-sex">Sexo biológico</label>
              <select id="estimate-sex" className="input-warm" value={sex} onChange={(event) => setSex(event.target.value as BiologicalSex | '')} required>
                <option value="">Selecione</option>
                <option value="female">Feminino</option>
                <option value="male">Masculino</option>
              </select>
            </div>
            <div>
              <label className="label-warm" htmlFor="estimate-age">Idade (anos)</label>
              <input id="estimate-age" className="input-warm" value={age === null ? '' : age} readOnly placeholder="Sem data de nascimento" />
              <p className="mt-1 text-[11px] text-muted-foreground">Derivada da data de nascimento.</p>
            </div>
            <div>
              <label className="label-warm" htmlFor="estimate-weight">Peso (kg)</label>
              <input id="estimate-weight" className="input-warm" type="text" inputMode="decimal" value={weight} onChange={(event) => setWeight(event.target.value)} placeholder="Não informado" />
            </div>
            <div>
              <label className="label-warm" htmlFor="estimate-height">Estatura (cm)</label>
              <input id="estimate-height" className="input-warm" type="text" inputMode="decimal" value={height} onChange={(event) => setHeight(event.target.value)} placeholder="Não informado" />
            </div>
          </div>

          <div>
            <label className="label-warm" htmlFor="estimate-activity">Nível de atividade física</label>
            <select id="estimate-activity" className="input-warm" value={activityFactor} onChange={(event) => setActivityFactor(Number(event.target.value))}>
              {ACTIVITY_LEVEL_PRESETS.map((preset) => <option key={preset.factor} value={preset.factor}>{preset.label} ({preset.factor})</option>)}
            </select>
          </div>

          <div>
            <label className="label-warm" htmlFor="estimate-notes">Observação clínica ou meta</label>
            <input id="estimate-notes" className="input-warm" value={notes} onChange={(event) => setNotes(event.target.value)} maxLength={500} placeholder="Ex.: paciente iniciará treino resistido" />
          </div>

          <div className="grid grid-cols-2 gap-4 rounded-xl border border-border bg-cream-100/60 p-4">
            <div>
              <p className="eyebrow">TMB</p>
              <p className="font-mono text-lg font-semibold">{preview ? `${preview.basalMetabolicRate.toLocaleString('pt-BR')} kcal` : '—'}</p>
            </div>
            <div>
              <p className="eyebrow">GET</p>
              <p className="font-mono text-lg font-semibold text-forest-600">{preview ? `${preview.totalEnergyExpenditure.toLocaleString('pt-BR')} kcal` : '—'}</p>
            </div>
            {!preview && <p className="col-span-2 text-[11px] text-muted-foreground">Faltam: {missing.join(', ')}.</p>}
          </div>

          <button className="btn-primary w-full" disabled={busy || !preview}>
            {busy ? 'Salvando...' : 'Salvar estimativa no prontuário'}
          </button>
        </form>
      </section>

      <section className="card-warm p-6">
        <h2 className="font-display text-xl font-semibold">Histórico de estimativas</h2>
        <div className="mt-4 space-y-3">
          {estimates.length === 0 && <p className="text-sm text-muted-foreground">Nenhuma estimativa registrada no prontuário.</p>}
          {estimates.map((estimate) => (
            <article key={estimate.id} className="rounded-xl border border-border p-4">
              <time className="font-mono text-[11px] uppercase tracking-wider text-muted-foreground" dateTime={estimate.calculated_on}>
                {new Date(estimate.calculated_on).toLocaleDateString('pt-BR')}
              </time>
              <p className="mt-1 font-semibold">GET {estimate.total_energy_expenditure.toLocaleString('pt-BR')} kcal · TMB {estimate.basal_metabolic_rate.toLocaleString('pt-BR')} kcal</p>
              <p className="mt-1 text-sm text-muted-foreground">
                {PROTOCOL_LABELS[estimate.protocol] ?? estimate.protocol} · {estimate.current_weight_kg} kg · fator {estimate.activity_factor}
              </p>
              {estimate.notes && <p className="mt-1 text-sm text-muted-foreground">{estimate.notes}</p>}
            </article>
          ))}
        </div>
      </section>
    </div>
  )
}
