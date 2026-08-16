import { useCallback, useEffect, useState } from 'react'
import { ArrowLeft, Check, ClipboardList, FileDown, Layers, Lock, Plus, Save, Search, Trash2, X } from 'lucide-react'
import { PlanAssistantPanel } from '../components/PlanAssistantPanel'
import { CATALOG_PAGE_SIZE, type CatalogDataSource, type CatalogFoodSummary } from '../lib/catalogSearch'
import { totalDay } from '../lib/nutrition'
import type { PatientSummary } from '../lib/patients'
import { exportPublishedPlanPdf, toPublishedPlanDocument } from '../lib/pdf'
import type { DraftSummary } from '../lib/planDrafts'
import {
  isTemplateUsable,
  provenanceLabel,
  type PlanTemplateDataSource,
  type PlanTemplateSummary,
} from '../lib/planTemplates'
import { supabase } from '../lib/supabase'
import { useDebouncedValue } from '../lib/useDebouncedValue'
import { usePlanDraft } from '../lib/usePlanDraft'

const MACRO_DOTS = [
  { key: 'energyKcal', label: 'Calorias', unit: 'kcal', color: '#4a6741' },
  { key: 'proteinG', label: 'Proteína', unit: 'g', color: '#85591d' },
  { key: 'carbohydrateG', label: 'Carboidrato', unit: 'g', color: '#c98f2f' },
  { key: 'fatG', label: 'Gordura', unit: 'g', color: '#749966' },
] as const

const STATUS_LABELS: Record<string, string> = {
  draft: 'rascunho',
  reviewed: 'revisado',
  published: 'publicado',
  superseded: 'substituído',
  archived: 'arquivado',
}

const GRAMS_STEP = 10

function Modal({ title, subtitle, onClose, children, wide = false }: {
  title: string
  subtitle?: string
  onClose: () => void
  children: React.ReactNode
  wide?: boolean
}) {
  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-forest-900/40 p-4 backdrop-blur-sm" onClick={onClose}>
      <div
        role="dialog"
        aria-modal="true"
        aria-label={title}
        className={`w-full ${wide ? 'max-w-2xl' : 'max-w-lg'} rounded-2xl bg-card p-5 shadow-warm-lg`}
        onClick={(event) => event.stopPropagation()}
      >
        <div className="mb-4 flex items-center justify-between">
          <div>
            <p className="font-display text-lg font-semibold">{title}</p>
            {subtitle && <p className="text-xs text-muted-foreground">{subtitle}</p>}
          </div>
          <button type="button" aria-label="Fechar" className="rounded-lg p-1.5 hover:bg-cream-200" onClick={onClose}><X size={16} /></button>
        </div>
        {children}
      </div>
    </div>
  )
}

function FoodPickerModal({ organizationId, dataSource, dayLabel, mealName, onPick, onClose }: {
  organizationId: string
  dataSource: CatalogDataSource
  dayLabel: string
  mealName: string
  onPick: (food: CatalogFoodSummary, grams: number) => void
  onClose: () => void
}) {
  const [query, setQuery] = useState('')
  const [grams, setGrams] = useState('100')
  const [results, setResults] = useState<CatalogFoodSummary[]>([])
  const [loading, setLoading] = useState(false)
  const debounced = useDebouncedValue(query, 300)

  const search = useCallback(async () => {
    setLoading(true)
    const response = await dataSource.searchFoods({ organizationId, query: debounced, page: 1 })
    setLoading(false)
    setResults(response.data?.foods ?? [])
  }, [dataSource, organizationId, debounced])

  useEffect(() => { void search() }, [search])

  function parseGrams(): number {
    const parsed = Number(grams.replace(',', '.'))
    return Number.isFinite(parsed) ? parsed : 0
  }

  function macro(food: CatalogFoodSummary, key: 'proteinG' | 'carbohydrateG' | 'fatG'): string {
    const value = food.nutrients[key]
    return value === undefined ? '—' : String(Math.round(value))
  }

  return (
    <Modal title="Adicionar alimento" subtitle={`${dayLabel} · ${mealName}`} onClose={onClose}>
      <div className="mb-3 flex gap-2">
        <div className="relative flex-1">
          <Search size={15} className="absolute left-3 top-1/2 -translate-y-1/2 text-muted-foreground" aria-hidden="true" />
          <input autoFocus className="input-warm !pl-9" aria-label="Buscar alimento" placeholder="Buscar alimento..." value={query} onChange={(event) => setQuery(event.target.value)} />
        </div>
        <input className="input-warm !w-24" aria-label="Quantidade em gramas" inputMode="decimal" value={grams} onChange={(event) => setGrams(event.target.value)} />
      </div>

      <p className="mb-2 text-xs text-muted-foreground" role="status">
        {loading ? 'Buscando no catálogo...' : `${results.length} de até ${CATALOG_PAGE_SIZE} resultados por página`}
      </p>

      <div className="max-h-72 space-y-1 overflow-y-auto pr-1">
        {results.map((food) => (
          <button
            key={food.id}
            type="button"
            className="flex w-full items-center justify-between gap-3 rounded-xl px-3 py-2.5 text-left transition-colors hover:bg-forest-50 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-amber-400"
            onClick={() => onPick(food, parseGrams())}
          >
            <div className="min-w-0">
              <p className="truncate text-sm font-medium">{food.name}</p>
              <p className="truncate text-xs text-muted-foreground">
                {food.householdMeasureLabel ?? (food.isOwn ? 'Catálogo próprio' : food.sourceName ?? 'Catálogo compartilhado')}
              </p>
            </div>
            <div className="shrink-0 text-right font-mono text-xs text-muted-foreground">
              <p className="font-semibold text-foreground">{food.nutrients.energyKcal === undefined ? '—' : `${food.nutrients.energyKcal} kcal`}</p>
              <p>P{macro(food, 'proteinG')} C{macro(food, 'carbohydrateG')} G{macro(food, 'fatG')}</p>
            </div>
          </button>
        ))}
        {!loading && results.length === 0 && <p className="py-6 text-center text-sm text-muted-foreground">Nada encontrado no catálogo.</p>}
      </div>
      <p className="mt-3 text-xs text-muted-foreground">Valores por 100 g. Nutriente sem dado na fonte aparece como “—”, nunca como zero.</p>
    </Modal>
  )
}

function TemplatesModal({ organizationId, dataSource, patientName, onApply, onClose }: {
  organizationId: string
  dataSource: PlanTemplateDataSource
  patientName: string
  onApply: (templateId: string) => void
  onClose: () => void
}) {
  const [query, setQuery] = useState('')
  const [templates, setTemplates] = useState<PlanTemplateSummary[]>([])
  const [total, setTotal] = useState(0)
  const [loading, setLoading] = useState(true)
  const debounced = useDebouncedValue(query, 300)

  const load = useCallback(async () => {
    setLoading(true)
    const response = await dataSource.listTemplates({ organizationId, query: debounced, status: 'all', page: 1 })
    setLoading(false)
    setTemplates(response.data?.templates ?? [])
    setTotal(response.data?.total ?? 0)
  }, [dataSource, organizationId, debounced])

  useEffect(() => { void load() }, [load])

  return (
    <Modal title={`Aplicar modelo a ${patientName}`} subtitle="Biblioteca de modelos" onClose={onClose} wide>
      <div className="relative mb-4">
        <Search size={15} className="absolute left-3 top-1/2 -translate-y-1/2 text-muted-foreground" aria-hidden="true" />
        <input autoFocus className="input-warm !pl-9" aria-label="Buscar modelos" placeholder={`Buscar entre ${total} modelos...`} value={query} onChange={(event) => setQuery(event.target.value)} />
      </div>

      <div className="max-h-[55vh] space-y-3 overflow-y-auto pr-1">
        {loading && <p className="py-6 text-center text-sm text-muted-foreground" role="status">Carregando modelos...</p>}
        {templates.map((template) => {
          const usable = isTemplateUsable(template)
          return (
            <button
              key={template.id}
              type="button"
              disabled={!usable}
              onClick={() => onApply(template.id)}
              className={`group flex w-full items-center gap-4 rounded-2xl border border-border p-4 text-left transition-all focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-amber-400 ${
                usable ? 'hover:-translate-y-0.5 hover:border-forest-300 hover:shadow-warm-md' : 'opacity-60'
              }`}
            >
              <span aria-hidden="true" className={`h-11 w-2 shrink-0 rounded-full ${usable ? 'bg-forest-500' : 'bg-amber-400'}`} />
              <div className="min-w-0 flex-1">
                <p className="font-semibold">{template.name}</p>
                <p className="line-clamp-1 text-sm text-muted-foreground">{template.objective ?? provenanceLabel(template.provenance)}</p>
                <div className="mt-1.5 flex flex-wrap gap-1.5">
                  {template.tags.map((tag) => <span key={tag} className="chip !py-0.5 !text-[10.5px] text-muted-foreground">{tag}</span>)}
                </div>
              </div>
              <div className="shrink-0 text-right">
                {usable
                  ? <p className="text-xs font-medium text-forest-600">Aplicar →</p>
                  : <p className="text-xs font-medium text-amber-700">Pendente de revisão</p>}
              </div>
            </button>
          )
        })}
        {!loading && templates.length === 0 && <p className="py-6 text-center text-sm text-muted-foreground">Nenhum modelo encontrado.</p>}
      </div>
      <p className="mt-4 text-xs text-muted-foreground">
        Aplicar um modelo cria um rascunho independente. Modelo sem revisão aprovada fica bloqueado aqui e também no banco.
      </p>
    </Modal>
  )
}

export interface PlanBuilderProps {
  organizationId: string
  userId: string
  patients: PatientSummary[]
  catalogSource: CatalogDataSource
  templateSource: PlanTemplateDataSource
  planId?: string
  patientId?: string
  onBack: () => void
}

export default function PlanBuilder({ organizationId, userId, patients, catalogSource, templateSource, planId, patientId, onBack }: PlanBuilderProps) {
  const [message, setMessage] = useState('')
  const [picker, setPicker] = useState<{ dayIndex: number; mealId: string; dayLabel: string; mealName: string } | null>(null)
  const [showTemplates, setShowTemplates] = useState(false)
  const [showAssistant, setShowAssistant] = useState(false)
  const [pendingCopy, setPendingCopy] = useState<{ from: number; to: number } | null>(null)
  const [exporting, setExporting] = useState(false)
  const plan = usePlanDraft({ organizationId, userId, onMessage: setMessage })
  const { openDraft, drafts, setPatientId } = plan

  useEffect(() => {
    if (!planId) return
    const target = drafts.find((draft) => draft.id === planId)
    if (target && target.id !== plan.loadedDraft) openDraft(target)
  }, [planId, drafts, openDraft, plan.loadedDraft])

  useEffect(() => {
    if (patientId && !plan.patientId) setPatientId(patientId)
  }, [patientId, plan.patientId, setPatientId])

  const readOnly = plan.locked
  const patient = patients.find((item) => item.id === plan.patientId) ?? null
  const openDraftSummary = plan.drafts.find((item) => item.id === plan.loadedDraft) ?? null
  const weekTotals = plan.days.map((day) => totalDay(day.meals))
  const average = MACRO_DOTS.map((macro) => {
    const sum = weekTotals.reduce((total, day) => total + (day[macro.key] ?? 0), 0)
    return { ...macro, value: Math.round(sum / Math.max(1, plan.days.length)) }
  })

  function requestCopy(from: number, to: number) {
    const outcome = plan.copyDay(from, to)
    if (outcome.needsConfirmation) setPendingCopy({ from, to })
  }

  async function applyTemplate(templateId: string) {
    if (!plan.patientId) return setMessage('Escolha o paciente antes de aplicar um modelo.')
    const response = await templateSource.applyTemplate({ templateId, patientId: plan.patientId, weekdays: ['mon', 'tue', 'wed', 'thu', 'fri', 'sat', 'sun'] })
    if (response.error || !response.data) return setMessage(response.error?.message ?? 'Não foi possível aplicar o modelo.')
    setShowTemplates(false)
    const next = await plan.loadDrafts()
    const created = next.find((draft) => draft.id === response.data?.id)
    if (created) plan.openDraft(created)
  }

  async function exportPdf(draft: DraftSummary) {
    const rows = await supabase
      .from('meal_item_substitutions')
      .select('plan_version_id,meal_item_id,description,is_active')
      .eq('organization_id', organizationId)
      .eq('plan_version_id', draft.versionId)
    const document = toPublishedPlanDocument(draft, patient?.fullName ?? 'Paciente', (rows.data ?? []).map((row) => ({
      planVersionId: row.plan_version_id,
      mealItemId: row.meal_item_id,
      replacementName: row.description,
      isActive: row.is_active,
    })))
    if (!document) return setMessage('Só a versão publicada gera o PDF do paciente.')
    setExporting(true)
    await exportPublishedPlanPdf(document)
    setExporting(false)
  }

  return (
    <>
      <button type="button" className="mb-6 flex items-center gap-2 text-sm font-medium text-muted-foreground hover:text-foreground" onClick={onBack}>
        <ArrowLeft size={15} /> Voltar
      </button>

      <div className="mb-6 flex flex-wrap items-end justify-between gap-4">
        <div className="min-w-[280px] flex-1">
          <p className="eyebrow mb-2">Construtor de plano</p>
          <input
            aria-label="Título do plano"
            className="w-full max-w-lg border-b border-transparent bg-transparent font-display text-3xl font-semibold outline-none transition-colors focus:border-forest-300"
            value={plan.title}
            disabled={readOnly}
            onChange={(event) => plan.setTitle(event.target.value)}
          />
          <div className="mt-2 flex flex-wrap items-center gap-3">
            <select aria-label="Paciente do plano" className="input-warm !w-auto !py-1.5 text-sm" value={plan.patientId} disabled={readOnly} onChange={(event) => plan.setPatientId(event.target.value)}>
              <option value="">Selecione o paciente</option>
              {patients.map((item) => <option key={item.id} value={item.id}>{item.fullName}</option>)}
            </select>
            <span className={`chip ${plan.planStatus === 'published' ? 'text-forest-600' : 'text-amber-700'}`}>● {STATUS_LABELS[plan.planStatus] ?? plan.planStatus}</span>
            <span className="text-xs text-muted-foreground" role="status" aria-live="polite">
              {plan.autosaveState === 'saving' ? 'gravando...' : plan.autosaveState === 'saved' ? 'gravado no servidor' : plan.autosaveState === 'error' ? 'falha na gravação' : ''}
            </span>
          </div>
        </div>

        <div className="flex flex-wrap gap-2.5">
          <button type="button" className="btn-ghost" disabled={readOnly} onClick={() => setShowTemplates(true)}><Layers size={16} /> Aplicar modelo</button>
          <button type="button" className="btn-ghost" onClick={() => setShowAssistant(true)}><ClipboardList size={16} /> Assistente</button>
          <button type="button" className="btn-ghost" disabled={plan.busy || readOnly} onClick={() => void plan.save()}><Save size={16} /> Salvar rascunho</button>
          <button type="button" className="btn-ghost" disabled={exporting || !openDraftSummary?.locked} onClick={() => openDraftSummary && void exportPdf(openDraftSummary)}>
            <FileDown size={16} /> {exporting ? 'Gerando...' : 'PDF'}
          </button>
          <button type="button" className="btn-ghost" disabled={plan.busy || readOnly || !plan.loadedDraft} onClick={() => void plan.review()}><Check size={16} /> Revisar</button>
          <button type="button" className="btn-amber" disabled={plan.busy || readOnly || plan.planStatus !== 'reviewed'} onClick={() => void plan.publish()}>
            <Lock size={16} /> {plan.confirmSubstitutionWarning ? 'Confirmar' : 'Publicar'}
          </button>
        </div>
      </div>

      {message && <p className="mb-4 rounded-xl border border-border bg-cream-100/60 p-3 text-sm" role="status">{message}</p>}
      {readOnly && (
        <p className="mb-4 rounded-xl border border-forest-200 bg-forest-50 p-3 text-sm text-forest-700" role="status">
          Versão publicada: o conteúdo é imutável e permanece como histórico.
        </p>
      )}

      <div className="card-warm mb-6 flex flex-wrap items-center gap-x-8 gap-y-3 px-5 py-4">
        <p className="eyebrow">Média diária</p>
        {average.map((macro) => (
          <div key={macro.key} className="flex items-baseline gap-2">
            <span aria-hidden="true" className="h-2.5 w-2.5 rounded-full" style={{ background: macro.color }} />
            <span className="text-[13px] text-muted-foreground">{macro.label}</span>
            <span className="font-mono text-sm font-semibold">{macro.value} {macro.unit}</span>
          </div>
        ))}
        <textarea
          aria-label="Observações desta versão"
          className="ml-auto min-w-[260px] flex-1 rounded-lg border border-border bg-cream-100/70 px-3 py-1.5 text-xs text-muted-foreground outline-none focus:border-forest-300"
          rows={1}
          disabled={readOnly}
          placeholder="Observações desta versão (o que mudou e por quê)"
          value={plan.changeSummary}
          onChange={(event) => plan.setChangeSummary(event.target.value)}
        />
      </div>

      {pendingCopy && (
        <div className="card-warm mb-6 border-amber-200 bg-amber-50/60 p-4" role="alertdialog" aria-label="Confirmar cópia de dia">
          <p className="text-sm text-amber-800">
            {plan.days[pendingCopy.to]?.label} já tem conteúdo. Copiar vai substituir tudo que está gravado nesse dia.
          </p>
          <div className="mt-3 flex gap-2">
            <button type="button" className="btn-ghost" onClick={() => setPendingCopy(null)}>Cancelar</button>
            <button type="button" className="btn-primary" onClick={() => { plan.copyDay(pendingCopy.from, pendingCopy.to, { confirmed: true }); setPendingCopy(null) }}>
              Substituir o dia
            </button>
          </div>
        </div>
      )}

      <div className="grid grid-cols-1 gap-4 md:grid-cols-2 xl:grid-cols-7 xl:gap-3">
        {plan.days.map((day, dayIndex) => (
          <section key={day.id} className="rounded-2xl border border-border bg-card shadow-warm">
            <div className="flex items-center justify-between gap-2 border-b border-border px-3.5 py-2.5">
              <p className="truncate font-display text-[15px] font-semibold">{day.label}</p>
              <div className="flex shrink-0 items-center gap-2">
                <span className="font-mono text-[10.5px] text-muted-foreground">{Math.round(weekTotals[dayIndex].energyKcal)} kcal</span>
                {!readOnly && (
                  <select
                    aria-label={`Copiar ${day.label} para outro dia`}
                    className="cursor-pointer bg-transparent text-muted-foreground/60 hover:text-forest-500"
                    value=""
                    onChange={(event) => { if (event.target.value) requestCopy(dayIndex, Number(event.target.value)) }}
                  >
                    <option value="">Copiar →</option>
                    {plan.days.map((other, otherIndex) => otherIndex !== dayIndex && <option key={other.id} value={otherIndex}>→ {other.label}</option>)}
                  </select>
                )}
              </div>
            </div>

            <div className="space-y-3 p-3">
              {day.meals.map((meal) => (
                <div key={meal.id}>
                  <p className="mb-1 font-mono text-[10px] font-medium uppercase tracking-wider text-amber-700">{meal.name}</p>
                  <div className="space-y-1.5">
                    {meal.items.map((item) => (
                      <div key={item.id} className="group rounded-lg bg-cream-100 px-2.5 py-2">
                        <p className="text-[12.5px] font-medium leading-snug">{item.name}</p>
                        <div className="mt-1 flex items-center justify-between gap-1">
                          <p className="min-w-0 truncate font-mono text-[10.5px] text-muted-foreground">
                            {Math.round((item.nutrientsPer100g.energyKcal * item.grams) / 100)} kcal
                          </p>
                          {!readOnly && (
                            <div className="flex shrink-0 items-center gap-0.5 text-muted-foreground">
                              <button type="button" aria-label={`Diminuir ${item.name}`} className="rounded px-1 hover:bg-cream-200" onClick={() => plan.changeItemGrams(dayIndex, meal.id, item.id, -GRAMS_STEP)}>−</button>
                              <span className="font-mono text-[11px]">{item.grams} g</span>
                              <button type="button" aria-label={`Aumentar ${item.name}`} className="rounded px-1 hover:bg-cream-200" onClick={() => plan.changeItemGrams(dayIndex, meal.id, item.id, GRAMS_STEP)}>+</button>
                              <button type="button" aria-label={`Remover ${item.name}`} className="rounded p-0.5 transition-colors hover:!text-destructive group-hover:text-destructive" onClick={() => plan.removeItemFromDay(dayIndex, meal.id, item.id)}>
                                <Trash2 size={12} />
                              </button>
                            </div>
                          )}
                          {readOnly && <span className="font-mono text-[11px] text-muted-foreground">{item.grams} g</span>}
                        </div>
                      </div>
                    ))}
                    {!readOnly && (
                      <button
                        type="button"
                        onClick={() => setPicker({ dayIndex, mealId: meal.id, dayLabel: day.label, mealName: meal.name })}
                        className="flex w-full items-center justify-center gap-1 rounded-lg border border-dashed border-border py-1.5 text-[11px] font-medium text-muted-foreground transition-all hover:border-forest-300 hover:bg-forest-50 hover:text-forest-600 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-amber-400"
                      >
                        <Plus size={11} /> adicionar
                      </button>
                    )}
                  </div>
                </div>
              ))}
            </div>
          </section>
        ))}
      </div>

      {picker && (
        <FoodPickerModal
          organizationId={organizationId}
          dataSource={catalogSource}
          dayLabel={picker.dayLabel}
          mealName={picker.mealName}
          onClose={() => setPicker(null)}
          onPick={(food, grams) => { plan.addItemToDay(picker.dayIndex, picker.mealId, food, grams); setPicker(null) }}
        />
      )}

      {showTemplates && (
        <TemplatesModal
          organizationId={organizationId}
          dataSource={templateSource}
          patientName={patient?.fullName ?? 'paciente'}
          onApply={(templateId) => void applyTemplate(templateId)}
          onClose={() => setShowTemplates(false)}
        />
      )}

      {showAssistant && (
        <Modal title="Assistente clínico" subtitle="Revisão e publicação exigem estas etapas" onClose={() => setShowAssistant(false)}>
          <PlanAssistantPanel
            assistant={plan.assistant}
            setAssistant={plan.setAssistant}
            targets={plan.targets}
            setTargets={plan.setTargets}
            days={plan.days}
            disabled={readOnly}
          />
        </Modal>
      )}
    </>
  )
}
