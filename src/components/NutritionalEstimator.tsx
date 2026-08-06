import { useState, type FormEvent } from 'react'
import { supabase } from '../lib/supabase'
import { calculateEnergyEstimate, PROTOCOL_LABELS, PROTOCOL_DESCRIPTIONS, ACTIVITY_LEVEL_PRESETS } from '../lib/energyEstimations'
import type { BiologicalSex, EnergyProtocol, NutritionalEstimateRow } from '../types'

interface NutritionalEstimatorProps {
  organizationId: string
  patient: { id: string; birth_date: string | null; full_name: string }
  userId: string
  latestAnthro?: { weight_kg: number | null; height_cm: number | null }
  estimates: NutritionalEstimateRow[]
  onReload: () => Promise<void>
}

export function NutritionalEstimator({
  organizationId,
  patient,
  userId,
  latestAnthro,
  estimates,
  onReload,
}: NutritionalEstimatorProps) {
  const defaultAge = patient.birth_date
    ? Math.max(0, Math.floor((Date.now() - new Date(patient.birth_date).getTime()) / (1000 * 3600 * 24 * 365.25)))
    : 30

  const [protocol, setProtocol] = useState<EnergyProtocol>('mifflin_st_jeor')
  const [sex, setSex] = useState<BiologicalSex>('female')
  const [weight, setWeight] = useState<number>(latestAnthro?.weight_kg ?? 70)
  const [height, setHeight] = useState<number>(latestAnthro?.height_cm ?? 170)
  const [age, setAge] = useState<number>(defaultAge)
  const [activityFactor, setActivityFactor] = useState<number>(1.55)
  const [notes, setNotes] = useState('')
  const [error, setError] = useState('')
  const [busy, setBusy] = useState(false)

  const preview = calculateEnergyEstimate({
    protocol,
    currentWeightKg: Number(weight) || 0,
    heightCm: Number(height) || 0,
    ageYears: Number(age) || 0,
    biologicalSex: sex,
    activityFactor: Number(activityFactor) || 1.2,
  })

  async function handleSubmit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault()
    if (!weight || !height || weight <= 0 || height <= 0) {
      setError('Peso e altura devem ser maiores que zero.')
      return
    }
    setError('')
    setBusy(true)
    const { error: dbError } = await supabase.from('nutritional_estimates').insert({
      organization_id: organizationId,
      patient_id: patient.id,
      protocol,
      current_weight_kg: Number(weight),
      height_cm: Number(height),
      age_years: Number(age),
      biological_sex: sex,
      activity_factor: Number(activityFactor),
      basal_metabolic_rate: preview.basalMetabolicRate,
      total_energy_expenditure: preview.totalEnergyExpenditure,
      notes: notes.trim() || null,
      created_by: userId,
    })
    setBusy(false)
    if (dbError) {
      setError(dbError.message)
    } else {
      setNotes('')
      await onReload()
    }
  }

  return (
    <div className="detail-grid histories">
      <section className="panel">
        <h2>Nova estimativa nutricional (TMB / GET)</h2>
        {error && <div className="notice error" role="alert">{error}</div>}
        <form onSubmit={handleSubmit}>
          <label>
            Protocolo de cálculo
            <select
              aria-label="Protocolo de cálculo"
              value={protocol}
              onChange={e => setProtocol(e.target.value as EnergyProtocol)}
            >
              {Object.entries(PROTOCOL_LABELS).map(([key, label]) => (
                <option key={key} value={key}>
                  {label}
                </option>
              ))}
            </select>
            <small>{PROTOCOL_DESCRIPTIONS[protocol]}</small>
          </label>

          <div className="field-row">
            <label>
              Sexo biológico
              <select aria-label="Sexo biológico" value={sex} onChange={e => setSex(e.target.value as BiologicalSex)}>
                <option value="female">Feminino</option>
                <option value="male">Masculino</option>
              </select>
            </label>
            <label>
              Idade (anos)
              <input aria-label="Idade" type="number" min="0" max="120" value={age} onChange={e => setAge(Number(e.target.value))} required />
            </label>
          </div>

          <div className="field-row">
            <label>
              Peso (kg)
              <input aria-label="Peso para estimativa" type="number" step="0.1" min="1" value={weight} onChange={e => setWeight(Number(e.target.value))} required />
            </label>
            <label>
              Altura (cm)
              <input aria-label="Altura para estimativa" type="number" step="0.5" min="30" value={height} onChange={e => setHeight(Number(e.target.value))} required />
            </label>
          </div>

          <label>
            Nível de atividade física
            <select aria-label="Nível de atividade física" value={activityFactor} onChange={e => setActivityFactor(Number(e.target.value))}>
              {ACTIVITY_LEVEL_PRESETS.map(preset => (
                <option key={preset.factor} value={preset.factor}>
                  {preset.label} ({preset.factor})
                </option>
              ))}
            </select>
          </label>

          <label>
            Observação clínica ou meta
            <input value={notes} onChange={e => setNotes(e.target.value)} placeholder="Ex.: paciente iniciará treino resistido" maxLength={500} />
          </label>

          <div className="live-totals estimate-preview" style={{ padding: '0.75rem', background: 'var(--surface-sunken, #f8f9fa)', borderRadius: '6px', margin: '0.5rem 0' }}>
            <div>
              <small>Taxa Metabólica Basal (TMB)</small>
              <strong>{preview.basalMetabolicRate.toLocaleString('pt-BR')} kcal/dia</strong>
            </div>
            <div>
              <small>Gasto Energético Total (GET)</small>
              <strong style={{ color: 'var(--primary, #0056b3)' }}>{preview.totalEnergyExpenditure.toLocaleString('pt-BR')} kcal/dia</strong>
            </div>
          </div>

          <button type="submit" className="primary" disabled={busy}>
            {busy ? 'Salvando...' : 'Salvar estimativa no prontuário'}
          </button>
        </form>
      </section>

      <section className="panel">
        <h2>Histórico de estimativas energéticas</h2>
        {estimates.length ? (
          estimates.map(est => (
            <article className="history measurement" key={est.id}>
              <time>{new Date(est.calculated_on).toLocaleDateString('pt-BR')} às {new Date(est.calculated_on).toLocaleTimeString('pt-BR', { hour: '2-digit', minute: '2-digit' })}</time>
              <span>
                <strong>GET: {est.total_energy_expenditure.toLocaleString('pt-BR')} kcal</strong> · TMB: {est.basal_metabolic_rate.toLocaleString('pt-BR')} kcal
              </span>
              <p>
                Protocolo: {PROTOCOL_LABELS[est.protocol] ?? est.protocol} · Peso: {est.current_weight_kg} kg · Fator atividade: {est.activity_factor}
              </p>
              {est.notes && <p>Observações: {est.notes}</p>}
            </article>
          ))
        ) : (
          <p className="muted">Nenhuma estimativa nutricional registrada no prontuário.</p>
        )}
      </section>
    </div>
  )
}
