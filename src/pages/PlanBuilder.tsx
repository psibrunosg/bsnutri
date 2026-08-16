import { useCallback, useEffect, useState } from 'react'
import { CheckCircle2, FileDown, Lock, Plus, Save, Search, Trash2 } from 'lucide-react'
import { PageHeader } from '../components/Shell'
import { macroKeys, macroLabels } from '../lib/catalogNutrients'
import type { CatalogDataSource, CatalogFoodSummary } from '../lib/catalogSearch'
import type { PatientSummary } from '../lib/patients'
import { exportPublishedPlanPdf, toPublishedPlanDocument } from '../lib/pdf'
import type { DraftSummary } from '../lib/planDrafts'
import { supabase } from '../lib/supabase'
import { useDebouncedValue } from '../lib/useDebouncedValue'
import { usePlanDraft } from '../lib/usePlanDraft'

const TARGET_FIELDS: { key: string; label: string; unit: string }[] = [
  { key: 'energyKcal', label: 'Energia', unit: 'kcal' },
  { key: 'proteinG', label: 'Proteína', unit: 'g' },
  { key: 'carbohydrateG', label: 'Carboidrato', unit: 'g' },
  { key: 'fatG', label: 'Gordura', unit: 'g' },
  { key: 'fiberG', label: 'Fibra', unit: 'g' },
  { key: 'waterMl', label: 'Água', unit: 'ml' },
]

const AUTOSAVE_LABELS = {
  idle: 'Sem alterações pendentes',
  saving: 'Gravando automaticamente...',
  saved: 'Rascunho gravado no servidor',
  error: 'Falha na gravação automática',
} as const

function FoodPicker({ organizationId, dataSource, onPick }: {
  organizationId: string
  dataSource: CatalogDataSource
  onPick: (food: CatalogFoodSummary, grams: number) => void
}) {
  const [query, setQuery] = useState('')
  const [grams, setGrams] = useState('100')
  const [results, setResults] = useState<CatalogFoodSummary[]>([])
  const [searching, setSearching] = useState(false)
  const debounced = useDebouncedValue(query, 300)

  const search = useCallback(async () => {
    if (!debounced.trim()) {
      setResults([])
      return
    }
    setSearching(true)
    const response = await dataSource.searchFoods({ organizationId, query: debounced, page: 1 })
    setSearching(false)
    setResults(response.data?.foods.slice(0, 8) ?? [])
  }, [dataSource, organizationId, debounced])

  useEffect(() => { void search() }, [search])

  function parseGrams(): number {
    const parsed = Number(grams.replace(',', '.'))
    return Number.isFinite(parsed) ? parsed : 0
  }

  return (
    <div className="rounded-xl border border-dashed border-border p-3">
      <div className="flex flex-wrap gap-2">
        <div className="relative min-w-[180px] flex-1">
          <Search size={14} className="absolute left-3 top-1/2 -translate-y-1/2 text-muted-foreground" aria-hidden="true" />
          <input className="input-warm !py-2 !pl-9 !text-sm" aria-label="Buscar alimento" placeholder="Buscar alimento..." value={query} onChange={(event) => setQuery(event.target.value)} />
        </div>
        <input className="input-warm !w-24 !py-2 !text-sm" aria-label="Quantidade em gramas" inputMode="decimal" value={grams} onChange={(event) => setGrams(event.target.value)} />
      </div>
      {searching && <p className="mt-2 text-xs text-muted-foreground" role="status">Buscando...</p>}
      {results.length > 0 && (
        <ul className="mt-2 space-y-1">
          {results.map((food) => (
            <li key={food.id}>
              <button type="button" className="flex w-full items-center justify-between gap-3 rounded-lg px-2 py-1.5 text-left text-sm hover:bg-cream-100 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-amber-400" onClick={() => onPick(food, parseGrams())}>
                <span className="truncate">{food.name}</span>
                <span className="shrink-0 font-mono text-xs text-muted-foreground">
                  {food.nutrients.energyKcal === undefined ? '— kcal/100 g' : `${food.nutrients.energyKcal} kcal/100 g`}
                </span>
              </button>
            </li>
          ))}
        </ul>
      )}
    </div>
  )
}

export interface PlanBuilderProps {
  organizationId: string
  userId: string
  patients: PatientSummary[]
  catalogSource: CatalogDataSource
  planId?: string
  patientId?: string
}

export default function PlanBuilder({ organizationId, userId, patients, catalogSource, planId, patientId }: PlanBuilderProps) {
  const [message, setMessage] = useState('')
  const [pendingCopy, setPendingCopy] = useState<number | null>(null)
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

  const day = plan.days[plan.activeDay]
  const readOnly = plan.locked

  function requestCopy(targetIndex: number) {
    const outcome = plan.copyActiveDayTo(targetIndex)
    if (outcome.needsConfirmation) setPendingCopy(targetIndex)
  }

  function confirmCopy() {
    if (pendingCopy === null) return
    plan.copyActiveDayTo(pendingCopy, { confirmed: true })
    setPendingCopy(null)
  }

  async function exportPdf(draft: DraftSummary) {
    const patient = patients.find((item) => item.id === draft.patientId)
    const substitutionRows = await supabase
      .from('meal_item_substitutions')
      .select('plan_version_id,meal_item_id,description,is_active')
      .eq('organization_id', organizationId)
      .eq('plan_version_id', draft.versionId)
    const substitutions = (substitutionRows.data ?? []).map((row) => ({
      planVersionId: row.plan_version_id,
      mealItemId: row.meal_item_id,
      replacementName: row.description,
      isActive: row.is_active,
    }))
    const document = toPublishedPlanDocument(draft, patient?.fullName ?? 'Paciente', substitutions)
    if (!document) return setMessage('Só a versão publicada gera o PDF do paciente.')
    setExporting(true)
    await exportPublishedPlanPdf(document)
    setExporting(false)
  }

  const openDraftSummary = plan.drafts.find((item) => item.id === plan.loadedDraft) ?? null

  return (
    <>
      <PageHeader
        eyebrow="Editor de plano"
        title={plan.title}
        description="Contexto, edição de um dia por vez e análise. A gravação automática acontece no servidor, nunca no navegador."
        actions={
          <>
            <button type="button" className="btn-ghost" onClick={plan.startBlankPlan}>Novo plano</button>
            <button type="button" className="btn-primary" disabled={plan.busy || readOnly} onClick={() => void plan.save()}>
              <Save size={16} /> Salvar como novo rascunho
            </button>
          </>
        }
      />

      {message && <p className="mb-6 rounded-xl border border-border bg-cream-100/60 p-3 text-sm" role="status">{message}</p>}

      <div className="grid grid-cols-1 gap-6 xl:grid-cols-12">
        {/* Região 1: contexto */}
        <aside className="space-y-5 xl:col-span-3">
          <section className="card-warm p-5">
            <h2 className="font-display text-lg font-semibold">Contexto clínico</h2>
            <div className="mt-4 space-y-4">
              <div>
                <label className="label-warm" htmlFor="plan-patient">Paciente</label>
                <select id="plan-patient" className="input-warm" value={plan.patientId} disabled={readOnly} onChange={(event) => plan.setPatientId(event.target.value)}>
                  <option value="">Selecione</option>
                  {patients.map((item) => <option key={item.id} value={item.id}>{item.fullName}</option>)}
                </select>
              </div>
              <div>
                <label className="label-warm" htmlFor="plan-title">Título do plano</label>
                <input id="plan-title" className="input-warm" value={plan.title} disabled={readOnly} onChange={(event) => plan.setTitle(event.target.value)} />
              </div>
              <p className="text-xs text-muted-foreground" role="status" aria-live="polite">
                {AUTOSAVE_LABELS[plan.autosaveState]}
                {plan.autosavedAt && plan.autosaveState === 'saved' ? ` às ${new Date(plan.autosavedAt).toLocaleTimeString('pt-BR', { hour: '2-digit', minute: '2-digit' })}` : ''}
              </p>
            </div>
          </section>

          <section className="card-warm p-5">
            <h2 className="font-display text-lg font-semibold">Metas do plano</h2>
            <div className="mt-4 space-y-3">
              {TARGET_FIELDS.map((field) => (
                <div key={field.key}>
                  <label className="label-warm" htmlFor={`target-${field.key}`}>{field.label} ({field.unit})</label>
                  <input
                    id={`target-${field.key}`}
                    className="input-warm !py-2"
                    inputMode="decimal"
                    disabled={readOnly}
                    value={plan.targets[field.key] ?? 0}
                    onChange={(event) => plan.setTargets((current) => ({ ...current, [field.key]: Number(event.target.value.replace(',', '.')) || 0 }))}
                  />
                </div>
              ))}
            </div>
          </section>

          <section className="card-warm p-5">
            <h2 className="font-display text-lg font-semibold">Planos da clínica</h2>
            {plan.loadingDrafts && <p className="mt-3 text-sm text-muted-foreground" role="status">Carregando...</p>}
            <ul className="mt-3 space-y-2">
              {plan.drafts.slice(0, 8).map((draft) => (
                <li key={draft.id}>
                  <button type="button" className="w-full rounded-xl border border-border p-3 text-left text-sm hover:bg-cream-100 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-amber-400" onClick={() => plan.openDraft(draft)}>
                    <span className="flex items-center justify-between gap-2">
                      <span className="truncate font-medium">{draft.title}</span>
                      {draft.locked && <Lock size={13} className="shrink-0 text-forest-600" aria-label="Publicado" />}
                    </span>
                    <span className="text-xs text-muted-foreground">v{draft.version} · {draft.status}</span>
                  </button>
                </li>
              ))}
            </ul>
          </section>
        </aside>

        {/* Região 2: edição de um dia por vez */}
        <section className="space-y-4 xl:col-span-6">
          <nav aria-label="Dias do plano" className="flex flex-wrap gap-2">
            {plan.days.map((item, index) => (
              <button
                key={item.id}
                type="button"
                aria-current={index === plan.activeDay ? 'true' : undefined}
                onClick={() => plan.setActiveDay(index)}
                className={`rounded-full px-3.5 py-2 text-sm font-medium transition-all focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-amber-400 ${
                  index === plan.activeDay ? 'bg-forest-500 text-cream-50 shadow-warm' : 'bg-cream-200 text-muted-foreground hover:text-foreground'
                }`}
              >
                {item.label}
              </button>
            ))}
          </nav>

          {readOnly && (
            <p className="rounded-xl border border-forest-200 bg-forest-50 p-3 text-sm text-forest-700" role="status">
              Versão publicada: o conteúdo é imutável e permanece disponível como histórico.
            </p>
          )}

          {day && (
            <article className="card-warm p-5">
              <div className="flex flex-wrap items-center justify-between gap-3">
                <div className="min-w-[200px] flex-1">
                  <label className="label-warm" htmlFor="day-label">Nome do dia</label>
                  <input id="day-label" className="input-warm" value={day.label} disabled={readOnly} onChange={(event) => plan.renameDay(plan.activeDay, event.target.value)} />
                </div>
                <div>
                  <label className="label-warm" htmlFor="copy-target">Copiar este dia para</label>
                  <select id="copy-target" className="input-warm" value="" disabled={readOnly} onChange={(event) => { if (event.target.value) requestCopy(Number(event.target.value)) }}>
                    <option value="">Selecione o destino</option>
                    {plan.days.map((item, index) => index !== plan.activeDay && <option key={item.id} value={index}>{item.label}</option>)}
                  </select>
                </div>
              </div>

              {pendingCopy !== null && (
                <div className="mt-4 rounded-xl border border-amber-200 bg-amber-50 p-4" role="alertdialog" aria-label="Confirmar cópia de dia">
                  <p className="text-sm text-amber-800">
                    {plan.days[pendingCopy]?.label} já tem conteúdo. Copiar vai substituir tudo que está gravado nesse dia.
                  </p>
                  <div className="mt-3 flex gap-2">
                    <button type="button" className="btn-ghost" onClick={() => setPendingCopy(null)}>Cancelar</button>
                    <button type="button" className="btn-primary" onClick={confirmCopy}>Substituir o dia</button>
                  </div>
                </div>
              )}

              <div className="mt-5 space-y-4">
                {day.meals.map((meal) => (
                  <div key={meal.id} className="rounded-xl border border-border p-4">
                    <h3 className="font-semibold">{meal.name}</h3>
                    <ul className="mt-2 space-y-1.5">
                      {meal.items.length === 0 && <li className="text-sm text-muted-foreground">Nenhum item neste horário.</li>}
                      {meal.items.map((item) => (
                        <li key={item.id} className="flex items-center justify-between gap-3 text-sm">
                          <span className="truncate">{item.name} · {item.grams} g</span>
                          {!readOnly && (
                            <button type="button" aria-label={`Remover ${item.name}`} className="shrink-0 text-muted-foreground hover:text-destructive" onClick={() => plan.removeItem(meal.id, item.id)}>
                              <Trash2 size={14} />
                            </button>
                          )}
                        </li>
                      ))}
                    </ul>
                    {!readOnly && (
                      <div className="mt-3">
                        <FoodPicker organizationId={organizationId} dataSource={catalogSource} onPick={(food, grams) => plan.addItem(meal.id, food, grams)} />
                      </div>
                    )}
                  </div>
                ))}
              </div>

              {!readOnly && (
                <button type="button" className="btn-ghost mt-4" onClick={() => plan.addMeal('Nova refeição')}>
                  <Plus size={16} /> Acrescentar refeição
                </button>
              )}
            </article>
          )}
        </section>

        {/* Região 3: análise e fluxo de publicação */}
        <aside className="space-y-5 xl:col-span-3">
          <section className="card-warm p-5">
            <h2 className="font-display text-lg font-semibold">Análise do dia</h2>
            <dl className="mt-4 space-y-2">
              {macroKeys.map((key) => (
                <div key={key} className="flex items-baseline justify-between gap-2">
                  <dt className="text-sm text-muted-foreground">{macroLabels[key]}</dt>
                  <dd className="font-mono text-sm font-semibold">{Math.round(plan.totals[key])}</dd>
                </div>
              ))}
            </dl>
            {plan.rangeIssues.length > 0 && (
              <ul className="mt-4 space-y-1.5">
                {plan.rangeIssues.map((issue) => (
                  <li key={issue} className="rounded-lg border border-amber-200 bg-amber-50 p-2 text-xs text-amber-800">{issue}</li>
                ))}
              </ul>
            )}
          </section>

          {plan.planChanges.length > 0 && (
            <section className="card-warm p-5">
              <h2 className="font-display text-lg font-semibold">Comparação com a versão aberta</h2>
              <ul className="mt-3 space-y-1.5 text-sm text-muted-foreground">
                {plan.planChanges.slice(0, 8).map((change) => <li key={change}>{change}</li>)}
              </ul>
            </section>
          )}

          <section className="card-warm p-5">
            <h2 className="font-display text-lg font-semibold">Revisão e publicação</h2>
            <p className="mt-2 text-sm text-muted-foreground">Publicar exige revisão concluída. A versão publicada não pode mais ser editada.</p>
            <div className="mt-4 space-y-2">
              <button type="button" className="btn-ghost w-full" disabled={plan.busy || readOnly || !plan.loadedDraft} onClick={() => void plan.review()}>
                <CheckCircle2 size={16} /> Marcar versão como revisada
              </button>
              <button type="button" className="btn-primary w-full" disabled={plan.busy || readOnly || plan.planStatus !== 'reviewed'} onClick={() => void plan.publish()}>
                <Lock size={16} /> {plan.confirmSubstitutionWarning ? 'Confirmar publicação' : 'Publicar plano'}
              </button>
              <button
                type="button"
                className="btn-ghost w-full"
                disabled={exporting || !openDraftSummary?.locked}
                onClick={() => openDraftSummary && void exportPdf(openDraftSummary)}
              >
                <FileDown size={16} /> {exporting ? 'Gerando PDF...' : 'PDF da versão publicada'}
              </button>
            </div>
          </section>
        </aside>
      </div>
    </>
  )
}
