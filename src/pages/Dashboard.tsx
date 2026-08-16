import { useCallback, useEffect, useMemo, useState } from 'react'
import { ArrowRight, CalendarPlus, FileDown, TrendingDown, TrendingUp, UserPlus, Users } from 'lucide-react'
import { PageHeader } from '../components/Shell'
import { bodyMassIndex, weightDelta } from '../lib/clinicalMetrics'
import type { PatientSummary } from '../lib/patients'
import { supabase } from '../lib/supabase'

interface PlanOverviewRow {
  id: string
  title: string
  status: string
  updated_at: string
  patient_id: string
}

function usePlanOverview(organizationId: string) {
  const [plans, setPlans] = useState<PlanOverviewRow[]>([])
  const [error, setError] = useState('')

  const load = useCallback(async () => {
    const result = await supabase
      .from('plans')
      .select('id,title,status,updated_at,patient_id')
      .eq('organization_id', organizationId)
      .order('updated_at', { ascending: false })
    if (result.error) {
      setError(result.error.message)
      setPlans([])
      return
    }
    setError('')
    setPlans((result.data ?? []) as PlanOverviewRow[])
  }, [organizationId])

  useEffect(() => { void load() }, [load])
  return { plans, error }
}

export interface DashboardProps {
  organizationId: string
  memberName: string
  patients: PatientSummary[]
  onOpenPatient: (patientId: string) => void
  onOpenPatients: () => void
  onCreatePatient: () => void
  onOpenPlan: (planId?: string) => void
  onOpenTemplates: () => void
}

export default function Dashboard({ organizationId, memberName, patients, onOpenPatient, onOpenPatients, onCreatePatient, onOpenPlan, onOpenTemplates }: DashboardProps) {
  const { plans, error } = usePlanOverview(organizationId)
  const published = plans.filter((plan) => plan.status === 'published').length
  const drafts = plans.length - published
  const patientNames = useMemo(() => new Map(patients.map((patient) => [patient.id, patient.fullName])), [patients])

  const cards = [
    { label: 'Pacientes cadastrados', value: String(patients.length), icon: Users },
    { label: 'Planos publicados', value: String(published), icon: FileDown },
    { label: 'Rascunhos em aberto', value: String(drafts), icon: CalendarPlus },
  ]

  return (
    <>
      <PageHeader
        eyebrow={`Olá, ${memberName}`}
        title="Visão geral do consultório"
        description="Acompanhe seus pacientes, publique planos e mantenha a semana de todo mundo organizada."
        actions={
          <>
            <button type="button" className="btn-ghost" onClick={onCreatePatient}><UserPlus size={16} /> Novo paciente</button>
            <button type="button" className="btn-primary" onClick={() => onOpenPlan()}><CalendarPlus size={16} /> Novo plano</button>
          </>
        }
      />

      {error && <p className="mb-6 rounded-xl border border-destructive/30 bg-destructive/10 p-4 text-sm text-destructive" role="alert">{error}</p>}

      <div className="mb-10 grid grid-cols-1 gap-4 sm:grid-cols-3">
        {cards.map((card) => (
          <article key={card.label} className="card-warm p-5">
            <div className="flex items-center justify-between">
              <p className="eyebrow">{card.label}</p>
              <card.icon size={18} className="text-forest-400" aria-hidden="true" />
            </div>
            <p className="mt-3 font-display text-4xl font-semibold">{card.value}</p>
          </article>
        ))}
      </div>

      <div className="grid grid-cols-1 gap-8 lg:grid-cols-5">
        <div className="lg:col-span-3">
          <div className="mb-4 flex items-center justify-between">
            <h2 className="font-display text-xl font-semibold">Seus pacientes</h2>
            <button type="button" className="text-sm font-medium text-forest-500 hover:text-forest-600" onClick={onOpenPatients}>Ver todos →</button>
          </div>
          <div className="space-y-3">
            {patients.length === 0 && (
              <p className="rounded-2xl border border-dashed border-border p-8 text-center text-sm text-muted-foreground">
                Nenhum paciente cadastrado. Comece pelo cadastro clínico.
              </p>
            )}
            {patients.slice(0, 6).map((patient) => {
              const latest = patient.measurements[0]
              const delta = weightDelta(patient.measurements.map((item) => ({ weight_kg: item.weightKg })))
              const index = bodyMassIndex(latest?.weightKg, latest?.heightCm)
              return (
                <button
                  type="button"
                  key={patient.id}
                  onClick={() => onOpenPatient(patient.id)}
                  className="card-warm group flex w-full items-center gap-4 p-4 text-left transition-all duration-150 hover:-translate-y-0.5 hover:shadow-warm-md focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-amber-400"
                >
                  <div className="flex h-12 w-12 shrink-0 items-center justify-center rounded-full bg-forest-100 font-display text-lg font-semibold text-forest-600">
                    {patient.fullName.split(' ').map((part) => part[0]).slice(0, 2).join('')}
                  </div>
                  <div className="min-w-0 flex-1">
                    <p className="truncate font-semibold">{patient.fullName}</p>
                    <p className="truncate text-sm text-muted-foreground">{patient.objective ?? 'Objetivo ainda não registrado'}</p>
                  </div>
                  <div className="hidden text-right sm:block">
                    <p className="font-mono text-sm font-medium">{latest?.weightKg === null || latest?.weightKg === undefined ? '—' : `${latest.weightKg.toFixed(1)} kg`}</p>
                    <p className={`flex items-center justify-end gap-1 text-xs ${delta === null ? 'text-muted-foreground' : delta < 0 ? 'text-forest-500' : delta > 0 ? 'text-amber-600' : 'text-muted-foreground'}`}>
                      {delta !== null && delta < 0 && <TrendingDown size={12} aria-hidden="true" />}
                      {delta !== null && delta > 0 && <TrendingUp size={12} aria-hidden="true" />}
                      {delta === null ? 'sem histórico' : delta === 0 ? 'estável' : `${delta > 0 ? '+' : ''}${delta.toFixed(1)} kg`}
                    </p>
                  </div>
                  <div className="hidden text-right md:block">
                    <p className="font-mono text-sm font-medium">IMC {index === null ? '—' : index.toFixed(1)}</p>
                  </div>
                  <ArrowRight size={16} className="text-muted-foreground/50 transition-transform group-hover:translate-x-1 group-hover:text-forest-500" aria-hidden="true" />
                </button>
              )
            })}
          </div>
        </div>

        <div className="lg:col-span-2">
          <h2 className="mb-4 font-display text-xl font-semibold">Planos recentes</h2>
          <div className="space-y-3">
            {plans.length === 0 && (
              <p className="rounded-2xl border border-dashed border-border p-6 text-center text-sm text-muted-foreground">Nenhum plano criado ainda.</p>
            )}
            {plans.slice(0, 5).map((plan) => (
              <button
                type="button"
                key={plan.id}
                onClick={() => onOpenPlan(plan.id)}
                className="card-warm w-full p-4 text-left transition-all duration-150 hover:-translate-y-0.5 hover:shadow-warm-md focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-amber-400"
              >
                <div className="flex items-center justify-between gap-2">
                  <p className="truncate font-semibold">{plan.title}</p>
                  <span className={`chip shrink-0 ${plan.status === 'published' ? '!border-forest-200 !bg-forest-50 text-forest-600' : '!border-amber-200 !bg-amber-50 text-amber-700'}`}>
                    {plan.status === 'published' ? 'publicado' : plan.status === 'in_review' ? 'em revisão' : 'rascunho'}
                  </span>
                </div>
                <p className="mt-1 text-sm text-muted-foreground">{patientNames.get(plan.patient_id) ?? 'Paciente'}</p>
                <p className="mt-2 font-mono text-[11px] uppercase tracking-wider text-muted-foreground/70">
                  Atualizado em {new Date(plan.updated_at).toLocaleDateString('pt-BR')}
                </p>
              </button>
            ))}
            <button type="button" onClick={onOpenTemplates} className="w-full rounded-2xl border border-dashed border-forest-300 bg-forest-50/50 p-4 text-sm font-medium text-forest-600 transition-all hover:bg-forest-50">
              Explorar modelos de plano →
            </button>
          </div>
        </div>
      </div>
    </>
  )
}
