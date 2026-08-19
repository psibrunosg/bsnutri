import { useCallback, useEffect, useMemo, useState } from 'react'
import { CalendarDays, ChevronRight, ClipboardList, FileText, Info, Leaf, MoreVertical, Sprout, Target, UserPlus, Users } from 'lucide-react'
import { bodyMassIndex, bodyMassIndexCategory } from '../lib/clinicalMetrics'
import type { PatientSummary } from '../lib/patients'
import { supabase } from '../lib/supabase'
import { PageHeader } from '../components/Shell'

const LABEL = 'font-mono text-[10.5px] font-medium uppercase tracking-[0.11em] text-muted-foreground'
const WEEKDAYS = ['Dom', 'Seg', 'Ter', 'Qua', 'Qui', 'Sex', 'Sáb']
/** Ordem de exibição do gráfico de adesão: a semana clínica começa na segunda. */
const WEEK_ORDER = [1, 2, 3, 4, 5, 6, 0]
const ADHERENCE_WINDOW_DAYS = 28

const MACRO_SLICES = [
  { key: 'carbohydrate', label: 'Carboidratos', color: '#4f7c43' },
  { key: 'protein', label: 'Proteínas', color: '#d9a44a' },
  { key: 'fat', label: 'Gorduras', color: '#e08a5e' },
] as const

const BMI_TONE_COLORS = {
  low: '#c98f2f',
  healthy: '#4a6741',
  warning: '#c98f2f',
  high: '#b35c33',
  critical: '#a03a2a',
} as const

interface PlanOverviewRow {
  id: string
  title: string
  status: string
  updated_at: string
  patient_id: string
}

interface PlanTargetsRow {
  plan_id: string
  created_at: string
  targets: Record<string, unknown> | null
}

interface MealCheckinRow {
  occurred_on: string
  state: string
}

function statusLabel(status: string): string {
  if (status === 'published') return 'Publicado'
  if (status === 'in_review') return 'Em revisão'
  return 'Rascunho'
}

function dayKey(timestamp: string): string {
  return timestamp.slice(0, 10)
}

function formatDayMonth(isoDate: string): string {
  const date = new Date(`${isoDate}T12:00:00`)
  const month = date.toLocaleDateString('pt-BR', { month: 'short' }).replace('.', '')
  return `${String(date.getDate()).padStart(2, '0')} ${month[0].toUpperCase()}${month.slice(1)}`
}

function formatShortDate(isoDate: string): string {
  return new Date(`${isoDate}T12:00:00`).toLocaleDateString('pt-BR', { day: '2-digit', month: '2-digit' })
}

function initials(name: string): string {
  const parts = name.split(' ').filter((part) => part.length > 2)
  return (parts.length ? parts : name.split(' ')).map((part) => part[0] ?? '').slice(0, 2).join('').toUpperCase()
}

function average(values: number[]): number | null {
  if (!values.length) return null
  return values.reduce((total, value) => total + value, 0) / values.length
}

/** `targets` é um jsonb plano de números; as chaves existem em camelCase e snake_case. */
function targetValue(targets: Record<string, unknown> | null, keys: string[]): number | null {
  if (!targets) return null
  for (const key of keys) {
    const raw = targets[key]
    if (typeof raw !== 'number' || !Number.isFinite(raw) || raw <= 0) continue
    return raw
  }
  return null
}

/** Peso mais recente menos o mais antigo do período, por paciente. */
function periodWeightChange(measurements: PatientSummary['measurements']): number | null {
  const weights = measurements.filter((item) => item.weightKg !== null)
  if (weights.length < 2) return null
  const latest = weights[0].weightKg
  const oldest = weights[weights.length - 1].weightKg
  if (latest === null || oldest === null) return null
  return latest - oldest
}

function useOverviewData(organizationId: string) {
  const [plans, setPlans] = useState<PlanOverviewRow[]>([])
  const [targets, setTargets] = useState<PlanTargetsRow[]>([])
  const [checkins, setCheckins] = useState<MealCheckinRow[]>([])
  const [error, setError] = useState('')

  const load = useCallback(async () => {
    const since = new Date(Date.now() - ADHERENCE_WINDOW_DAYS * 86400000).toISOString().slice(0, 10)
    const [planResult, targetResult, checkinResult] = await Promise.all([
      supabase
        .from('plans')
        .select('id,title,status,updated_at,patient_id')
        .eq('organization_id', organizationId)
        .order('updated_at', { ascending: false }),
      supabase
        .from('plan_versions')
        .select('plan_id,created_at,targets')
        .eq('organization_id', organizationId)
        .order('created_at', { ascending: false })
        .limit(200),
      supabase
        .from('meal_checkins')
        .select('occurred_on,state')
        .eq('organization_id', organizationId)
        .gte('occurred_on', since),
    ])

    // Só o painel de planos derruba a página: metas e check-ins degradam para "sem dados".
    if (planResult.error) {
      setError(planResult.error.message)
      setPlans([])
    } else {
      setError('')
      setPlans((planResult.data ?? []) as PlanOverviewRow[])
    }
    setTargets(targetResult.error ? [] : ((targetResult.data ?? []) as PlanTargetsRow[]))
    setCheckins(checkinResult.error ? [] : ((checkinResult.data ?? []) as MealCheckinRow[]))
  }, [organizationId])

  useEffect(() => { void load() }, [load])
  return { plans, targets, checkins, error }
}

/** Passo de eixo em valor redondo (1, 2, 2.5, 5 ou 10 vezes a ordem de grandeza). */
function niceStep(rough: number): number {
  const magnitude = 10 ** Math.floor(Math.log10(Math.max(rough, 0.001)))
  for (const factor of [1, 2, 2.5, 5]) if (magnitude * factor >= rough) return magnitude * factor
  return magnitude * 10
}

function WeightChart({ points }: { points: { label: string; value: number }[] }) {
  if (points.length < 2) {
    return <p className="flex h-[104px] items-center justify-center text-[12px] text-muted-foreground">Sem medições suficientes no período.</p>
  }

  const left = 34
  const right = 314
  const top = 10
  const bottom = 82
  const values = points.map((point) => point.value)
  const step = niceStep((Math.max(...values) + 1.5 - (Math.min(...values) - 1.5)) / 3)
  const min = Math.floor((Math.min(...values) - 1.5) / step) * step
  const max = Math.ceil((Math.max(...values) + 1.5) / step) * step
  const span = max - min || 1
  const x = (index: number) => left + (index / (points.length - 1)) * (right - left)
  const y = (value: number) => bottom - ((value - min) / span) * (bottom - top)
  const ticks = Array.from({ length: Math.round(span / step) + 1 }, (_, index) => min + index * step)
  const line = points.map((point, index) => `${index === 0 ? 'M' : 'L'}${x(index).toFixed(1)},${y(point.value).toFixed(1)}`).join(' ')
  const area = `${line} L${x(points.length - 1).toFixed(1)},${bottom} L${left},${bottom} Z`
  const lastIndex = points.length - 1
  const badgeX = Math.min(x(lastIndex), right - 26)

  return (
    <svg viewBox="0 0 320 116" className="h-[104px] w-full" role="img" aria-label={`Peso médio de ${points[0].label} a ${points[lastIndex].label}`}>
      <defs>
        <linearGradient id="dashboard-weight-fill" x1="0" y1="0" x2="0" y2="1">
          <stop offset="0%" stopColor="#4a6741" stopOpacity="0.22" />
          <stop offset="100%" stopColor="#4a6741" stopOpacity="0" />
        </linearGradient>
      </defs>
      {ticks.map((tick) => (
        <text key={tick} x={left - 8} y={y(tick) + 3} textAnchor="end" fontSize="9" fill="#8a8577">{Number(tick.toFixed(1))}</text>
      ))}
      <path d={area} fill="url(#dashboard-weight-fill)" />
      <path d={line} fill="none" stroke="#4a6741" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" />
      {points.map((point, index) => (
        <circle key={point.label} cx={x(index)} cy={y(point.value)} r="3" fill="#fffdf8" stroke="#4a6741" strokeWidth="2" />
      ))}
      <g transform={`translate(${badgeX - 24}, ${Math.max(y(points[lastIndex].value) - 26, 0)})`}>
        <rect width="48" height="19" rx="9" fill="#28371f" />
        <text x="24" y="13" textAnchor="middle" fontSize="10" fontWeight="600" fill="#faf8f2">
          {points[lastIndex].value.toFixed(1)} kg
        </text>
      </g>
      {points.map((point, index) => {
        const isEdge = index === 0 || index === lastIndex
        const isMiddle = points.length >= 3 && index === Math.floor(lastIndex / 2)
        if (!isEdge && !isMiddle) return null
        return (
          <text
            key={`label-${point.label}`}
            x={x(index)}
            y="106"
            textAnchor={index === 0 ? 'start' : index === lastIndex ? 'end' : 'middle'}
            fontSize="9"
            fill="#8a8577"
          >
            {point.label}
          </text>
        )
      })}
    </svg>
  )
}

function MacroDonut({ slices }: { slices: { key: string; color: string; percent: number }[] }) {
  const radius = 45
  const circumference = 2 * Math.PI * radius
  let offset = 0

  return (
    <svg viewBox="0 0 116 116" className="h-[116px] w-[116px]" aria-hidden="true">
      <circle cx="58" cy="58" r={radius} fill="none" stroke="#e9e1cd" strokeWidth="22" />
      {slices.map((slice) => {
        const length = (slice.percent / 100) * circumference
        const dash = `${length} ${circumference - length}`
        const element = (
          <circle
            key={slice.key}
            cx="58"
            cy="58"
            r={radius}
            fill="none"
            stroke={slice.color}
            strokeWidth="22"
            strokeDasharray={dash}
            strokeDashoffset={-offset}
            transform="rotate(-90 58 58)"
          />
        )
        offset += length
        return element
      })}
    </svg>
  )
}

function AdherenceBars({ days }: { days: { label: string; percent: number }[] }) {
  const top = 6
  const baseline = 74
  const barWidth = 11

  return (
    <svg viewBox="0 0 224 92" className="h-[88px] w-full" aria-hidden="true">
      {days.map((day, index) => {
        const center = 16 + index * 32
        const height = Math.max((day.percent / 100) * (baseline - top), 3)
        return (
          <g key={day.label}>
            <rect x={center - barWidth / 2} y={baseline - height} width={barWidth} height={height} rx={barWidth / 2} fill="#a8c489" />
            <text x={center} y="88" textAnchor="middle" fontSize="9" fill="#8a8577">{day.label}</text>
          </g>
        )
      })}
    </svg>
  )
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
  const { plans, targets, checkins, error } = useOverviewData(organizationId)
  const published = plans.filter((plan) => plan.status === 'published').length
  const drafts = plans.length - published
  const patientNames = useMemo(() => new Map(patients.map((patient) => [patient.id, patient.fullName])), [patients])

  const cards = [
    { label: 'Pacientes cadastrados', value: patients.length, hint: 'Ativos no consultório', icon: Users, tone: 'forest' as const, art: Leaf },
    { label: 'Planos publicados', value: published, hint: 'Planos ativos', icon: FileText, tone: 'amber' as const, art: ClipboardList },
    { label: 'Rascunhos em aberto', value: drafts, hint: 'Planos em andamento', icon: CalendarDays, tone: 'forest' as const, art: Leaf },
  ]

  // Peso médio do consultório: em cada data medida, a média da última pesagem
  // conhecida de cada paciente até aquele dia.
  const weight = useMemo(() => {
    const dates = [...new Set(patients.flatMap((patient) => patient.measurements.map((item) => dayKey(item.measuredAt))))].sort()
    const points = dates.map((date) => {
      const weights = patients
        .map((patient) => patient.measurements.find((item) => dayKey(item.measuredAt) <= date && item.weightKg !== null)?.weightKg)
        .filter((value): value is number => value !== undefined && value !== null)
      return { label: formatDayMonth(date), value: Number((average(weights) ?? 0).toFixed(1)) }
    })
    const changes = patients.map((patient) => periodWeightChange(patient.measurements)).filter((value): value is number => value !== null)
    return { points: points.filter((point) => point.value > 0), change: average(changes) }
  }, [patients])

  // Macros médios das metas da versão mais recente de cada plano.
  const macros = useMemo(() => {
    const latestByPlan = new Map<string, PlanTargetsRow>()
    for (const row of targets) if (!latestByPlan.has(row.plan_id)) latestByPlan.set(row.plan_id, row)
    const rows = [...latestByPlan.values()]
    const energy = average(rows.map((row) => targetValue(row.targets, ['energyKcal', 'energy_kcal'])).filter((value): value is number => value !== null))
    const grams = {
      carbohydrate: average(rows.map((row) => targetValue(row.targets, ['carbohydrateG', 'carbohydrate_g'])).filter((value): value is number => value !== null)),
      protein: average(rows.map((row) => targetValue(row.targets, ['proteinG', 'protein_g'])).filter((value): value is number => value !== null)),
      fat: average(rows.map((row) => targetValue(row.targets, ['fatG', 'fat_g'])).filter((value): value is number => value !== null)),
    }
    if (energy === null || grams.carbohydrate === null || grams.protein === null || grams.fat === null) return null
    const kcalByMacro = { carbohydrate: grams.carbohydrate * 4, protein: grams.protein * 4, fat: grams.fat * 9 }
    const total = kcalByMacro.carbohydrate + kcalByMacro.protein + kcalByMacro.fat
    if (total <= 0) return null
    return {
      energyKcal: Math.round(energy),
      slices: MACRO_SLICES.map((slice) => ({
        ...slice,
        percent: Math.round((kcalByMacro[slice.key] / total) * 100),
      })),
    }
  }, [targets])

  // Adesão real: check-ins de refeição das últimas 4 semanas, por dia da semana.
  // `completed` e `adapted` contam como refeição cumprida; `skipped`, não.
  const adherence = useMemo(() => {
    const byWeekday = new Map<number, { done: number; total: number }>()
    for (const checkin of checkins) {
      const weekday = new Date(`${checkin.occurred_on}T12:00:00`).getDay()
      const bucket = byWeekday.get(weekday) ?? { done: 0, total: 0 }
      bucket.total += 1
      if (checkin.state === 'completed' || checkin.state === 'adapted') bucket.done += 1
      byWeekday.set(weekday, bucket)
    }
    const days = WEEK_ORDER.map((weekday) => {
      const bucket = byWeekday.get(weekday)
      return { label: WEEKDAYS[weekday], percent: bucket && bucket.total ? Math.round((bucket.done / bucket.total) * 100) : 0 }
    })
    if (!checkins.length) return { days, overall: null, grade: 'Sem check-ins no período', color: '#7a7568' }
    const done = checkins.filter((checkin) => checkin.state === 'completed' || checkin.state === 'adapted').length
    const overall = Math.round((done / checkins.length) * 100)
    return {
      days,
      overall,
      grade: overall >= 80 ? 'Boa adesão' : overall >= 50 ? 'Adesão parcial' : 'Baixa adesão',
      color: overall >= 80 ? '#4a6741' : overall >= 50 ? '#c98f2f' : '#a97324',
    }
  }, [checkins])

  return (
    <>
      <PageHeader
        eyebrow={
          <>
            Olá, {memberName}
            <Sprout size={17} strokeWidth={1.8} className="text-forest-400" aria-hidden="true" />
          </>
        }
        title="Visão geral do consultório"
        description="Acompanhe seus pacientes, publique planos e mantenha a semana de todo mundo organizada."
        actions={
          <>
            <button type="button" className="btn-ghost" onClick={onCreatePatient}>
              <UserPlus size={17} strokeWidth={1.9} aria-hidden="true" /> Novo paciente
            </button>
            <button type="button" className="btn-primary" onClick={() => onOpenPlan()}>
              <CalendarDays size={17} strokeWidth={1.9} aria-hidden="true" /> Novo plano
            </button>
          </>
        }
      />

      {error && <p className="mb-6 rounded-xl border border-destructive/30 bg-destructive/10 p-4 text-sm text-destructive" role="alert">{error}</p>}

      <div className="mb-4 grid grid-cols-1 gap-4 sm:grid-cols-3">
        {cards.map((card) => (
          <article key={card.label} className="card-warm relative flex items-center gap-4 overflow-hidden p-4">
            <span className={`flex h-11 w-11 shrink-0 items-center justify-center rounded-full ${card.tone === 'amber' ? 'bg-amber-50 text-amber-600' : 'bg-forest-100 text-forest-500'}`}>
              <card.icon size={21} strokeWidth={1.8} aria-hidden="true" />
            </span>
            <div className="min-w-0">
              <p className={LABEL}>{card.label}</p>
              <p className="mt-0.5 font-display text-[36px] font-semibold leading-none">{card.value}</p>
              <p className="mt-1.5 text-[13px] text-muted-foreground">{card.hint}</p>
            </div>
            <card.art aria-hidden="true" className="pointer-events-none absolute -right-2 top-1/2 h-16 w-16 -translate-y-1/2 rotate-[14deg] text-forest-500/[0.09]" strokeWidth={0.9} />
          </article>
        ))}
      </div>

      <div className="mb-7 grid grid-cols-1 gap-4 lg:grid-cols-[1.16fr_1.02fr_1fr]">
        <section className="card-warm p-4">
          <div className="mb-2 flex items-center justify-between gap-3">
            <h2 className={LABEL}>Evolução de peso (pacientes ativos)</h2>
            <p className="shrink-0 text-[12px] font-medium text-forest-500">
              {weight.change === null ? '—' : `${weight.change <= 0 ? '↓' : '↑'} ${weight.change.toFixed(1).replace('.', ',')} kg média`}
            </p>
          </div>
          <WeightChart points={weight.points} />
        </section>

        <section className="card-warm p-4">
          <h2 className={LABEL}>Distribuição de macros (média)</h2>
          <div className="mt-2 flex items-center gap-4">
            <div className="relative shrink-0">
              <MacroDonut slices={macros ? macros.slices : []} />
              <div className="pointer-events-none absolute inset-0 flex flex-col items-center justify-center">
                <span className="font-display text-[19px] font-semibold leading-none">{macros ? macros.energyKcal.toLocaleString('pt-BR') : '—'}</span>
                <span className="mt-0.5 text-[11px] text-muted-foreground">kcal</span>
              </div>
            </div>
            <ul className="min-w-0 flex-1 space-y-2.5">
              {MACRO_SLICES.map((slice) => (
                <li key={slice.key} className="flex items-center gap-2 text-[13px]">
                  <span aria-hidden="true" className="h-2 w-2 shrink-0 rounded-full" style={{ background: slice.color }} />
                  <span className="min-w-0 flex-1 truncate text-foreground/80">{slice.label}</span>
                  <span className="shrink-0 font-semibold">
                    {macros ? `${macros.slices.find((item) => item.key === slice.key)?.percent ?? 0}%` : '—'}
                  </span>
                </li>
              ))}
            </ul>
          </div>
        </section>

        <section className="card-warm p-4">
          <div className="flex items-start justify-between gap-3">
            <h2 className={`${LABEL} flex items-center gap-1.5`}>
              Adesão aos planos
              <Info size={12} aria-hidden="true" className="text-muted-foreground/60" />
            </h2>
            <Target size={20} strokeWidth={1.6} aria-hidden="true" className="shrink-0 text-forest-300" />
          </div>
          <p className="mt-2 font-display text-[30px] font-semibold leading-none">{adherence.overall === null ? '—' : `${adherence.overall}%`}</p>
          <p className="mt-1 text-[13px] font-medium" style={{ color: adherence.color }}>{adherence.grade}</p>
          <div className="mt-2">
            <AdherenceBars days={adherence.days} />
          </div>
        </section>
      </div>

      <div className="grid grid-cols-1 gap-4 lg:grid-cols-[1.24fr_1fr]">
        <section>
          <div className="mb-3 flex items-center justify-between gap-3">
            <h2 className="flex items-center gap-2 font-display text-[19px] font-semibold">
              <Leaf size={17} strokeWidth={1.9} aria-hidden="true" className="text-forest-400" />
              Seus pacientes
            </h2>
            <button type="button" className="flex items-center gap-1.5 text-[13px] font-medium text-forest-500 transition-colors duration-200 hover:text-forest-600" onClick={onOpenPatients}>
              Ver todos <ChevronRight size={14} aria-hidden="true" />
            </button>
          </div>

          <div className="card-warm divide-y divide-border/70 overflow-hidden">
            {patients.length === 0 && (
              <p className="px-4 py-10 text-center text-sm text-muted-foreground">Nenhum paciente cadastrado. Comece pelo cadastro clínico.</p>
            )}
            {patients.slice(0, 4).map((patient) => {
              const latest = patient.measurements[0]
              const oldest = patient.measurements.filter((item) => item.weightKg !== null).at(-1)
              const change = periodWeightChange(patient.measurements)
              const index = bodyMassIndex(latest?.weightKg, latest?.heightCm)
              const category = bodyMassIndexCategory(index)
              return (
                <button
                  type="button"
                  key={patient.id}
                  onClick={() => onOpenPatient(patient.id)}
                  className="group flex w-full items-center gap-4 px-4 py-3.5 text-left transition-colors duration-200 hover:bg-forest-50/60 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-amber-400"
                >
                  <span className="flex h-11 w-11 shrink-0 items-center justify-center rounded-full bg-forest-100 font-display text-[15px] font-semibold text-forest-600">
                    {initials(patient.fullName)}
                  </span>
                  <span className="min-w-0 flex-1">
                    <span className="block truncate text-[15px] font-semibold">{patient.fullName}</span>
                    <span className="mt-1 inline-flex max-w-full items-center gap-1.5 rounded-full bg-forest-50 px-2.5 py-1 text-[12px] font-medium text-forest-600">
                      <Leaf size={12} strokeWidth={2} aria-hidden="true" className="shrink-0" />
                      <span className="truncate">{patient.objective ?? 'Objetivo ainda não registrado'}</span>
                    </span>
                  </span>

                  <span className="hidden w-[92px] shrink-0 border-l border-border/60 pl-4 sm:block">
                    <span className="block text-[14px] font-semibold">
                      {latest?.weightKg === null || latest?.weightKg === undefined ? '—' : `${latest.weightKg.toFixed(1)} kg`}
                    </span>
                    <span className="mt-0.5 block text-[11px] text-muted-foreground">Peso atual</span>
                  </span>

                  <span className="hidden w-[96px] shrink-0 border-l border-border/60 pl-4 md:block">
                    <span className="block text-[14px] font-semibold">IMC {index === null ? '—' : index.toFixed(1)}</span>
                    <span className="mt-0.5 block text-[11px] font-medium" style={{ color: category ? BMI_TONE_COLORS[category.tone] : undefined }}>
                      {category?.label ?? 'Sem medida'}
                    </span>
                  </span>

                  <span className="hidden w-[124px] shrink-0 border-l border-border/60 pl-4 lg:block">
                    <span className={`block text-[13px] font-semibold ${change === null ? 'text-muted-foreground' : change < 0 ? 'text-forest-500' : change > 0 ? 'text-amber-600' : 'text-muted-foreground'}`}>
                      {change === null ? 'sem histórico' : change === 0 ? 'estável' : `${change > 0 ? '+' : ''}${change.toFixed(1)} kg`}
                    </span>
                    <span className="mt-0.5 block text-[11px] text-muted-foreground">
                      {oldest ? `desde ${formatShortDate(dayKey(oldest.measuredAt))}` : 'sem medidas'}
                    </span>
                  </span>

                  <span className="flex h-8 w-8 shrink-0 items-center justify-center rounded-full border border-border text-muted-foreground transition-all duration-200 group-hover:border-forest-300 group-hover:text-forest-500">
                    <ChevronRight size={15} aria-hidden="true" />
                  </span>
                </button>
              )
            })}
            <p className="flex items-center justify-center gap-2 bg-cream-100/70 py-2.5 text-[12px] text-muted-foreground">
              <Users size={13} strokeWidth={1.9} aria-hidden="true" />
              {patients.length} {patients.length === 1 ? 'paciente ativo' : 'pacientes ativos'}
            </p>
          </div>
        </section>

        <section>
          <div className="mb-3 flex items-center justify-between gap-3">
            <h2 className="flex items-center gap-2 font-display text-[19px] font-semibold">
              <Leaf size={17} strokeWidth={1.9} aria-hidden="true" className="text-forest-400" />
              Planos recentes
            </h2>
            <button type="button" className="flex items-center gap-1.5 text-[13px] font-medium text-forest-500 transition-colors duration-200 hover:text-forest-600" onClick={onOpenTemplates}>
              Ver todos <ChevronRight size={14} aria-hidden="true" />
            </button>
          </div>

          <div className="space-y-3">
            {plans.length === 0 && (
              <p className="rounded-2xl border border-dashed border-border p-6 text-center text-sm text-muted-foreground">Nenhum plano criado ainda.</p>
            )}
            {plans.slice(0, 4).map((plan, index) => (
              <article key={plan.id} className="card-warm flex items-center gap-3 p-2.5 transition-all duration-200 hover:-translate-y-0.5 hover:shadow-warm-md">
                <button
                  type="button"
                  onClick={() => onOpenPlan(plan.id)}
                  className="flex min-w-0 flex-1 items-center gap-3 text-left focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-amber-400"
                >
                  <img src={`./dashboard/plan-${(index % 4) + 1}.webp`} alt="" className="h-[62px] w-[86px] shrink-0 rounded-xl object-cover" />
                  <span className="min-w-0 flex-1">
                    <span className="block truncate text-[15px] font-semibold">{plan.title}</span>
                    <span className="mt-0.5 block truncate text-[13px] text-muted-foreground">{patientNames.get(plan.patient_id) ?? 'Paciente'}</span>
                    <span className="mt-1.5 block truncate font-mono text-[10px] uppercase tracking-[0.1em] text-muted-foreground/70">
                      Atualizado em {new Date(plan.updated_at).toLocaleDateString('pt-BR')}
                    </span>
                  </span>
                </button>
                <span className={`chip shrink-0 ${plan.status === 'published' ? '!border-forest-200 !bg-forest-50 text-forest-600' : '!border-amber-200 !bg-amber-50 text-amber-700'}`}>
                  {statusLabel(plan.status)}
                </span>
                <button
                  type="button"
                  aria-label={`Abrir o plano ${plan.title}`}
                  onClick={() => onOpenPlan(plan.id)}
                  className="flex h-8 w-8 shrink-0 items-center justify-center rounded-lg text-muted-foreground transition-colors duration-200 hover:bg-cream-200 hover:text-foreground focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-amber-400"
                >
                  <MoreVertical size={16} aria-hidden="true" />
                </button>
              </article>
            ))}
            <button type="button" onClick={onOpenTemplates} className="w-full rounded-2xl border border-dashed border-forest-300 bg-forest-50/50 p-4 text-sm font-medium text-forest-600 transition-all hover:bg-forest-50 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-amber-400">
              Explorar modelos de plano →
            </button>
          </div>
        </section>
      </div>
    </>
  )
}
