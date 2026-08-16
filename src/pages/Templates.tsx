import { useCallback, useEffect, useState } from 'react'
import { Search, ShieldCheck, ShieldAlert } from 'lucide-react'
import { PageHeader } from '../components/Shell'
import type { PatientSummary } from '../lib/patients'
import {
  TEMPLATE_PAGE_SIZE,
  TEMPLATE_STATUS_LABELS,
  isTemplateUsable,
  provenanceLabel,
  type PlanTemplateDataSource,
  type PlanTemplateDetail,
  type PlanTemplatePage,
  type PlanTemplateStatus,
} from '../lib/planTemplates'
import { useDebouncedValue } from '../lib/useDebouncedValue'

const STATUS_FILTERS: { value: PlanTemplateStatus | 'all'; label: string }[] = [
  { value: 'all', label: 'Todos' },
  { value: 'needs_review', label: 'Pendentes' },
  { value: 'approved', label: 'Aprovados' },
  { value: 'archived', label: 'Arquivados' },
]

const WEEKDAYS = [
  { code: 'mon', label: 'Seg' },
  { code: 'tue', label: 'Ter' },
  { code: 'wed', label: 'Qua' },
  { code: 'thu', label: 'Qui' },
  { code: 'fri', label: 'Sex' },
  { code: 'sat', label: 'Sáb' },
  { code: 'sun', label: 'Dom' },
]

export interface TemplatesPageProps {
  organizationId: string
  dataSource: PlanTemplateDataSource
  patients: PatientSummary[]
  canReview: boolean
  onPlanCreated: (planId: string, patientId: string) => void
}

export default function Templates({ organizationId, dataSource, patients, canReview, onPlanCreated }: TemplatesPageProps) {
  const [query, setQuery] = useState('')
  const [status, setStatus] = useState<PlanTemplateStatus | 'all'>('all')
  const [page, setPage] = useState(1)
  const [result, setResult] = useState<PlanTemplatePage | null>(null)
  const [detail, setDetail] = useState<PlanTemplateDetail | null>(null)
  const [detailLoading, setDetailLoading] = useState(false)
  const [patientId, setPatientId] = useState('')
  const [weekdays, setWeekdays] = useState<string[]>(['mon'])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState('')
  const [message, setMessage] = useState('')
  const debouncedQuery = useDebouncedValue(query, 300)

  useEffect(() => { setPage(1) }, [debouncedQuery, status])

  const load = useCallback(async () => {
    setLoading(true)
    const response = await dataSource.listTemplates({ organizationId, query: debouncedQuery, status, page })
    if (response.error) {
      setError(response.error.message)
      setResult(null)
    } else {
      setError('')
      setResult(response.data)
    }
    setLoading(false)
  }, [dataSource, organizationId, debouncedQuery, status, page])

  useEffect(() => { void load() }, [load])

  async function openDetail(id: string) {
    setDetailLoading(true)
    setMessage('')
    const response = await dataSource.getTemplateDetail(id)
    setDetailLoading(false)
    if (response.error) return setError(response.error.message)
    setError('')
    setDetail(response.data)
  }

  async function review(id: string, next: PlanTemplateStatus) {
    const notes = next === 'approved' ? window.prompt('Registre a revisão feita neste modelo:')?.trim() ?? null : null
    if (next === 'approved' && !notes) return setMessage('A aprovação exige o registro da revisão.')
    const response = await dataSource.reviewTemplate(id, next, notes)
    if (response.error) return setError(response.error.message)
    setMessage(next === 'approved' ? 'Modelo aprovado para uso clínico.' : 'Modelo atualizado.')
    if (detail?.id === id) await openDetail(id)
    await load()
  }

  async function apply() {
    if (!detail || !patientId) return setMessage('Escolha o paciente que receberá a proposta.')
    if (!isTemplateUsable(detail)) return setMessage('Somente modelos aprovados podem virar proposta de plano.')
    const response = await dataSource.applyTemplate({ templateId: detail.id, patientId, weekdays })
    if (response.error || !response.data) return setError(response.error?.message ?? 'Não foi possível aplicar o modelo.')
    onPlanCreated(response.data.id, patientId)
  }

  function toggleWeekday(code: string) {
    setWeekdays((current) => (current.includes(code) ? current.filter((item) => item !== code) : [...current, code]))
  }

  return (
    <>
      <PageHeader
        eyebrow="Modelos de plano"
        title="Biblioteca revisável"
        description={`Listagem paginada em ${TEMPLATE_PAGE_SIZE} modelos por página, sem carregar a estrutura completa. Só modelo aprovado vira proposta.`}
      />

      <div className="mb-6 flex flex-wrap items-center gap-3">
        <div className="relative min-w-[240px] flex-1 md:max-w-md">
          <Search size={16} className="absolute left-3.5 top-1/2 -translate-y-1/2 text-muted-foreground" aria-hidden="true" />
          <input className="input-warm !pl-10" aria-label="Buscar modelos" placeholder="Buscar por nome..." value={query} onChange={(event) => setQuery(event.target.value)} />
        </div>
        <div className="flex flex-wrap gap-2" role="group" aria-label="Filtrar por situação">
          {STATUS_FILTERS.map((filter) => (
            <button
              key={filter.value}
              type="button"
              aria-pressed={status === filter.value}
              onClick={() => setStatus(filter.value)}
              className={`rounded-full px-4 py-2 text-sm font-medium transition-all focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-amber-400 ${
                status === filter.value ? 'bg-forest-500 text-cream-50 shadow-warm' : 'bg-cream-200 text-muted-foreground hover:text-foreground'
              }`}
            >
              {filter.label}
            </button>
          ))}
        </div>
      </div>

      {error && <p className="mb-6 rounded-xl border border-destructive/30 bg-destructive/10 p-4 text-sm text-destructive" role="alert">{error}</p>}
      {message && <p className="mb-6 rounded-xl border border-border bg-cream-100/60 p-3 text-sm" role="status">{message}</p>}
      <p className="mb-4 text-sm text-muted-foreground" role="status">
        {loading ? 'Carregando modelos...' : result ? `${result.total} modelo${result.total === 1 ? '' : 's'} · página ${result.page} de ${result.pageCount}` : 'Nenhum modelo disponível.'}
      </p>

      <div className="grid grid-cols-1 gap-4 md:grid-cols-2 xl:grid-cols-3">
        {(result?.templates ?? []).map((template) => {
          const usable = isTemplateUsable(template)
          return (
            <article key={template.id} className="card-warm flex flex-col p-5">
              <div className="flex items-start justify-between gap-3">
                <h2 className="font-display text-lg font-semibold">{template.name}</h2>
                <span className={`chip shrink-0 ${usable ? '!border-forest-200 !bg-forest-50 text-forest-600' : '!border-amber-200 !bg-amber-50 text-amber-700'}`}>
                  {usable ? <ShieldCheck size={12} aria-hidden="true" /> : <ShieldAlert size={12} aria-hidden="true" />}
                  {TEMPLATE_STATUS_LABELS[template.status]}
                </span>
              </div>
              {template.objective && <p className="mt-2 text-sm text-muted-foreground">{template.objective}</p>}
              <p className="mt-2 text-xs text-muted-foreground">{provenanceLabel(template.provenance)}</p>
              {template.tags.length > 0 && (
                <div className="mt-3 flex flex-wrap gap-1.5">
                  {template.tags.map((tag) => <span key={tag} className="chip !bg-cream-100 text-muted-foreground">{tag}</span>)}
                </div>
              )}
              <div className="mt-4 flex flex-wrap gap-2 border-t border-border pt-4">
                <button type="button" className="btn-ghost" onClick={() => void openDetail(template.id)}>Ver detalhes</button>
                {canReview && template.status !== 'approved' && (
                  <button type="button" className="btn-primary" onClick={() => void review(template.id, 'approved')}>Revisar e aprovar</button>
                )}
                {canReview && template.status === 'approved' && (
                  <button type="button" className="btn-ghost" onClick={() => void review(template.id, 'archived')}>Arquivar</button>
                )}
              </div>
            </article>
          )
        })}
      </div>

      {result && result.pageCount > 1 && (
        <nav aria-label="Paginação de modelos" className="mt-6 flex items-center justify-between gap-4">
          <button type="button" className="btn-ghost" disabled={result.page <= 1 || loading} onClick={() => setPage((current) => Math.max(1, current - 1))}>Página anterior</button>
          <p className="text-sm text-muted-foreground">Página {result.page} de {result.pageCount}</p>
          <button type="button" className="btn-ghost" disabled={result.page >= result.pageCount || loading} onClick={() => setPage((current) => current + 1)}>Próxima página</button>
        </nav>
      )}

      {detailLoading && <p className="mt-8 text-sm text-muted-foreground" role="status">Carregando estrutura do modelo...</p>}

      {detail && (
        <section className="card-warm mt-8 p-6">
          <div className="flex flex-wrap items-start justify-between gap-3">
            <div>
              <h2 className="font-display text-2xl font-semibold">{detail.name}</h2>
              <p className="mt-1 text-sm text-muted-foreground">{provenanceLabel(detail.provenance)}</p>
              {detail.reviewNotes && <p className="mt-1 text-sm text-muted-foreground">Revisão: {detail.reviewNotes}</p>}
            </div>
            <button type="button" className="btn-ghost" onClick={() => setDetail(null)}>Fechar</button>
          </div>

          {!isTemplateUsable(detail) ? (
            <p className="mt-5 rounded-xl border border-amber-200 bg-amber-50 p-4 text-sm text-amber-800" role="status">
              Este modelo ainda não foi revisado e aprovado. A aplicação está bloqueada na interface e também no banco de dados.
            </p>
          ) : (
            <div className="mt-5 space-y-4">
              <div>
                <label className="label-warm" htmlFor="template-patient">Paciente</label>
                <select id="template-patient" className="input-warm" value={patientId} onChange={(event) => setPatientId(event.target.value)}>
                  <option value="">Selecione</option>
                  {patients.map((patient) => <option key={patient.id} value={patient.id}>{patient.fullName}</option>)}
                </select>
              </div>
              <fieldset>
                <legend className="label-warm">Dias da semana</legend>
                <div className="flex flex-wrap gap-2">
                  {WEEKDAYS.map((day) => (
                    <button
                      key={day.code}
                      type="button"
                      aria-pressed={weekdays.includes(day.code)}
                      onClick={() => toggleWeekday(day.code)}
                      className={`rounded-xl border px-3 py-2 text-sm font-medium transition-all focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-amber-400 ${
                        weekdays.includes(day.code) ? 'border-forest-400 bg-forest-50 text-forest-600' : 'border-border bg-card text-muted-foreground'
                      }`}
                    >
                      {day.label}
                    </button>
                  ))}
                </div>
              </fieldset>
              <button type="button" className="btn-primary" disabled={!patientId || weekdays.length === 0} onClick={() => void apply()}>
                Criar proposta de plano
              </button>
            </div>
          )}
        </section>
      )}
    </>
  )
}
