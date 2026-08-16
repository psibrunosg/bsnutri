import { useMemo, useState } from 'react'
import { Plus, Search } from 'lucide-react'
import { PageHeader } from '../components/Shell'
import { ageInYears, bodyMassIndex, bodyMassIndexCategory } from '../lib/clinicalMetrics'
import { filterPatients, type PatientSummary } from '../lib/patients'

const TONE_CLASS = {
  low: 'border-amber-200 bg-amber-50 text-amber-700',
  healthy: 'border-forest-200 bg-forest-50 text-forest-600',
  warning: 'border-amber-200 bg-amber-50 text-amber-700',
  high: 'border-destructive/30 bg-destructive/10 text-destructive',
  critical: 'border-destructive/40 bg-destructive/15 text-destructive',
} as const

function formatNumber(value: number | null, digits = 1): string {
  return value === null ? '—' : value.toLocaleString('pt-BR', { minimumFractionDigits: digits, maximumFractionDigits: digits })
}

export interface PatientsPageProps {
  patients: PatientSummary[]
  loading: boolean
  error: string
  onOpenPatient: (patientId: string) => void
  onCreatePatient: () => void
}

export default function Patients({ patients, loading, error, onOpenPatient, onCreatePatient }: PatientsPageProps) {
  const [query, setQuery] = useState('')
  const today = useMemo(() => new Date(), [])
  const list = useMemo(() => filterPatients(patients, query), [patients, query])

  return (
    <>
      <PageHeader
        eyebrow="Gestão clínica"
        title="Pacientes"
        description="Cadastre, acompanhe medidas antropométricas e acesse os planos de cada pessoa."
        actions={
          <button type="button" className="btn-primary" onClick={onCreatePatient}>
            <Plus size={16} /> Cadastrar paciente
          </button>
        }
      />

      <div className="relative mb-6 max-w-md">
        <Search size={16} className="absolute left-3.5 top-1/2 -translate-y-1/2 text-muted-foreground" aria-hidden="true" />
        <input
          className="input-warm !pl-10"
          aria-label="Buscar pacientes"
          placeholder="Buscar por nome, código, objetivo ou tag..."
          value={query}
          onChange={(event) => setQuery(event.target.value)}
        />
      </div>

      {error && <p className="mb-6 rounded-xl border border-destructive/30 bg-destructive/10 p-4 text-sm text-destructive" role="alert">{error}</p>}
      {loading && <p className="mb-6 text-sm text-muted-foreground" role="status">Carregando pacientes...</p>}

      <div className="grid grid-cols-1 gap-4 md:grid-cols-2 xl:grid-cols-3">
        {list.map((patient) => {
          const latest = patient.measurements[0]
          const index = bodyMassIndex(latest?.weightKg, latest?.heightCm)
          const category = bodyMassIndexCategory(index)
          const age = ageInYears(patient.birthDate, today)
          return (
            <button
              type="button"
              key={patient.id}
              onClick={() => onOpenPatient(patient.id)}
              className="card-warm p-5 text-left transition-all duration-150 hover:-translate-y-1 hover:shadow-warm-md focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-amber-400"
            >
              <div className="flex items-start justify-between gap-3">
                <div className="flex min-w-0 items-center gap-3">
                  <div className="flex h-12 w-12 shrink-0 items-center justify-center rounded-full bg-forest-100 font-display text-lg font-semibold text-forest-600">
                    {patient.fullName.split(' ').map((part) => part[0]).slice(0, 2).join('')}
                  </div>
                  <div className="min-w-0">
                    <p className="truncate font-semibold">{patient.fullName}</p>
                    <p className="font-mono text-[11px] uppercase tracking-wider text-muted-foreground">
                      {patient.anonymousCode}{age === null ? ' · idade não informada' : ` · ${age} anos`}
                    </p>
                  </div>
                </div>
                {category && <span className={`chip shrink-0 ${TONE_CLASS[category.tone]}`}>{category.label}</span>}
              </div>

              <p className="mt-3 line-clamp-2 text-sm text-muted-foreground">{patient.objective ?? 'Objetivo ainda não registrado.'}</p>

              <div className="mt-4 grid grid-cols-3 gap-2 border-t border-border pt-3">
                <div>
                  <p className="font-mono text-sm font-semibold">{formatNumber(latest?.weightKg ?? null)}</p>
                  <p className="text-[11px] text-muted-foreground">kg</p>
                </div>
                <div>
                  <p className="font-mono text-sm font-semibold">{formatNumber(index)}</p>
                  <p className="text-[11px] text-muted-foreground">IMC</p>
                </div>
                <div>
                  <p className="font-mono text-sm font-semibold">{latest?.bodyFatPercent === null || latest?.bodyFatPercent === undefined ? '—' : `${formatNumber(latest.bodyFatPercent)}%`}</p>
                  <p className="text-[11px] text-muted-foreground">Gordura</p>
                </div>
              </div>

              {patient.tags.length > 0 && (
                <div className="mt-3 flex flex-wrap gap-1.5">
                  {patient.tags.map((tag) => (
                    <span key={tag} className="chip !bg-cream-100 text-muted-foreground">{tag}</span>
                  ))}
                </div>
              )}
            </button>
          )
        })}

        {!loading && list.length === 0 && (
          <p className="col-span-full rounded-2xl border border-dashed border-border p-10 text-center text-sm text-muted-foreground">
            {patients.length === 0
              ? 'Nenhum paciente cadastrado ainda. Comece pelo cadastro clínico.'
              : `Nenhum paciente encontrado para “${query}”.`}
          </p>
        )}
      </div>
    </>
  )
}
