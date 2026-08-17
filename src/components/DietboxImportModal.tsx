import { useCallback, useEffect, useMemo, useState } from 'react'
import { Search, X } from 'lucide-react'
import type { CatalogDataSource, CatalogFoodSummary } from '../lib/catalogSearch'
import {
  detectDietboxTextKind,
  parseDietboxPlanText,
  parseDietboxSubstitutionListText,
  type ParsedDietboxGroup,
  type ParsedDietboxMeal,
} from '../lib/dietboxImport'
import { buildDietboxMatchIndex, type DietboxFoodMatch } from '../lib/dietboxMatch'
import { buildImportedDay } from '../lib/dietboxImportPlan'
import { buildMergedDaysPayload, type DietboxImportDataSource, type DietboxEquivalencyListRef } from '../lib/dietboxImportWrite'
import type { PlanAssistantState } from '../lib/planAssistant'
import type { DraftSummary, EditorDay } from '../lib/planDrafts'
import type { SubstitutionDataSource } from '../lib/substitutions'
import { useDebouncedValue } from '../lib/useDebouncedValue'

function collectFoodNames(kind: 'plan' | 'substitution_list', meals: ParsedDietboxMeal[], groups: ParsedDietboxGroup[]): string[] {
  const names = new Set<string>()
  if (kind === 'plan') {
    for (const meal of meals) for (const slot of meal.slots) {
      names.add(slot.primary.rawName)
      for (const alt of slot.alternatives) names.add(alt.rawName)
    }
  } else {
    for (const group of groups) for (const food of group.foods) names.add(food.rawName)
  }
  return [...names]
}

function InlineFoodSearch({ organizationId, dataSource, onPick }: {
  organizationId: string
  dataSource: CatalogDataSource
  onPick: (food: CatalogFoodSummary) => void
}) {
  const [query, setQuery] = useState('')
  const [results, setResults] = useState<CatalogFoodSummary[]>([])
  const debounced = useDebouncedValue(query, 300)

  useEffect(() => {
    let active = true
    void (async () => {
      if (!debounced.trim()) return setResults([])
      const response = await dataSource.searchFoods({ organizationId, query: debounced, page: 1 })
      if (active) setResults(response.data?.foods ?? [])
    })()
    return () => { active = false }
  }, [dataSource, organizationId, debounced])

  return (
    <div className="mt-1 rounded-lg border border-amber-200 bg-amber-50/60 p-2">
      <div className="relative">
        <Search size={12} className="absolute left-2 top-1/2 -translate-y-1/2 text-muted-foreground" aria-hidden="true" />
        <input
          className="input-warm !py-1 !pl-6 !text-xs"
          placeholder="Buscar no catálogo..."
          value={query}
          onChange={(event) => setQuery(event.target.value)}
        />
      </div>
      <div className="mt-1 max-h-32 space-y-0.5 overflow-y-auto">
        {results.map((food) => (
          <button
            key={food.id}
            type="button"
            className="block w-full truncate rounded px-1.5 py-1 text-left text-[11px] hover:bg-white"
            onClick={() => onPick(food)}
          >
            {food.name}
          </button>
        ))}
      </div>
    </div>
  )
}

function MatchStatus({ rawName, match, manualPick, organizationId, catalogSource, onManualPick }: {
  rawName: string
  match: DietboxFoodMatch | undefined
  manualPick: CatalogFoodSummary | undefined
  organizationId: string
  catalogSource: CatalogDataSource
  onManualPick: (rawName: string, food: CatalogFoodSummary) => void
}) {
  const [searching, setSearching] = useState(false)
  if (manualPick) {
    return <p className="text-[11px] text-forest-600">{rawName} → {manualPick.name} (escolhido)</p>
  }
  if (match?.status === 'matched') {
    return <p className="text-[11px] text-forest-600">{rawName} → {match.food.name}</p>
  }
  return (
    <div>
      <div className="flex items-center justify-between gap-2">
        <p className="text-[11px] text-amber-700">{rawName} — não casado automaticamente{match?.error ? ` (${match.error})` : ''}</p>
        <button type="button" className="text-[10px] font-medium text-forest-600 hover:underline" onClick={() => setSearching((v) => !v)}>
          {searching ? 'fechar busca' : 'buscar'}
        </button>
      </div>
      {match?.status === 'needs_review' && match.suggestions.length > 0 && !searching && (
        <div className="mt-1 space-y-0.5">
          {match.suggestions.slice(0, 5).map((food) => (
            <button key={food.id} type="button" className="block w-full truncate rounded bg-white/70 px-1.5 py-1 text-left text-[11px] hover:bg-white" onClick={() => onManualPick(rawName, food)}>
              {food.name}
            </button>
          ))}
        </div>
      )}
      {searching && <InlineFoodSearch organizationId={organizationId} dataSource={catalogSource} onPick={(food) => { onManualPick(rawName, food); setSearching(false) }} />}
    </div>
  )
}

export interface DietboxImportModalProps {
  organizationId: string
  userId: string
  catalogSource: CatalogDataSource
  writeSource: DietboxImportDataSource
  substitutionSource: SubstitutionDataSource
  patientId: string
  title: string
  targets: Record<string, number>
  assistantState: PlanAssistantState
  days: EditorDay[]
  activeDayIndex: number
  loadDrafts: () => Promise<DraftSummary[]>
  onImported: (draftId: string) => void
  onClose: () => void
}

export function DietboxImportModal({
  organizationId, userId, catalogSource, writeSource, substitutionSource,
  patientId, title, targets, assistantState, days, activeDayIndex, loadDrafts, onImported, onClose,
}: DietboxImportModalProps) {
  const [text, setText] = useState('')
  const [kind, setKind] = useState<'plan' | 'substitution_list' | 'unknown' | null>(null)
  const [meals, setMeals] = useState<ParsedDietboxMeal[]>([])
  const [groups, setGroups] = useState<ParsedDietboxGroup[]>([])
  const [warnings, setWarnings] = useState<string[]>([])
  const [matchIndex, setMatchIndex] = useState<Map<string, DietboxFoodMatch>>(new Map())
  const [manualPicks, setManualPicks] = useState<Map<string, CatalogFoodSummary>>(new Map())
  const [groupLists, setGroupLists] = useState<Map<number, DietboxEquivalencyListRef[]>>(new Map())
  const [targetDayIndex, setTargetDayIndex] = useState(activeDayIndex)
  const [busy, setBusy] = useState(false)
  const [result, setResult] = useState<string | null>(null)
  const [analyzing, setAnalyzing] = useState(false)

  const resolveFood = useCallback((rawName: string): CatalogFoodSummary | null => {
    const manual = manualPicks.get(rawName)
    if (manual) return manual
    const match = matchIndex.get(rawName)
    return match?.status === 'matched' ? match.food : null
  }, [manualPicks, matchIndex])

  const resolveEquivalencyList = useCallback((groupNo: number): DietboxEquivalencyListRef | null => {
    const candidates = groupLists.get(groupNo) ?? []
    return candidates.length === 1 ? candidates[0] : null
  }, [groupLists])

  const preview = useMemo(() => {
    if (kind !== 'plan') return null
    return buildImportedDay(days[targetDayIndex] ?? days[0], meals, resolveFood, resolveEquivalencyList)
  }, [kind, days, targetDayIndex, meals, resolveFood, resolveEquivalencyList])

  async function analyze() {
    setResult(null)
    const detected = detectDietboxTextKind(text)
    setKind(detected)
    if (detected === 'unknown') {
      setMeals([])
      setGroups([])
      return
    }
    setAnalyzing(true)
    if (detected === 'plan') {
      const parsed = parseDietboxPlanText(text)
      setMeals(parsed.meals)
      setGroups([])
      setWarnings(parsed.warnings)
      const names = collectFoodNames('plan', parsed.meals, [])
      const [index, lists] = await Promise.all([
        buildDietboxMatchIndex(names, catalogSource, organizationId),
        writeSource.findEquivalencyListsByDietboxGroup(
          [...new Set(parsed.meals.flatMap((meal) => meal.slots.map((slot) => slot.dietboxGroupNo).filter((n): n is number => n !== null)))],
          organizationId,
        ),
      ])
      setMatchIndex(index)
      setGroupLists(lists)
    } else {
      const parsed = parseDietboxSubstitutionListText(text)
      setGroups(parsed.groups)
      setMeals([])
      setWarnings(parsed.warnings)
      const names = collectFoodNames('substitution_list', [], parsed.groups)
      setMatchIndex(await buildDietboxMatchIndex(names, catalogSource, organizationId))
    }
    setManualPicks(new Map())
    setAnalyzing(false)
  }

  function onManualPick(rawName: string, food: CatalogFoodSummary) {
    setManualPicks((current) => new Map(current).set(rawName, food))
  }

  const allPrimariesResolved = kind === 'plan'
    ? meals.every((meal) => meal.slots.every((slot) => resolveFood(slot.primary.rawName) !== null))
    : false

  async function confirmPlanImport() {
    if (!preview || !patientId) return
    setBusy(true)
    const mergedDays = buildMergedDaysPayload(days, targetDayIndex, preview.day)
    const saveResult = await writeSource.saveDraft({
      organizationId,
      patientId,
      title,
      changeSummary: 'Importado de um cardápio Dietbox',
      assistantState,
      targets,
      days: mergedDays,
      userId,
    })
    if (saveResult.error || !saveResult.data) {
      setBusy(false)
      setResult(`Falha ao salvar o plano: ${saveResult.error?.message ?? 'erro desconhecido'}`)
      return
    }
    const draftId = saveResult.data.id
    const next = await loadDrafts()
    const saved = next.find((draft) => draft.id === draftId)
    let attached = 0
    const failures: string[] = []
    if (saved) {
      for (const pending of preview.pendingSubstitutions) {
        const realItemId = saved.days[targetDayIndex]?.meals[pending.mealIndex]?.items[pending.itemIndex]?.id
        if (!realItemId) { failures.push(`${pending.food.name}: item não encontrado após salvar`); continue }
        const response = await substitutionSource.prescribe({
          organizationId,
          planVersionId: saved.versionId,
          mealItemId: realItemId,
          food: pending.food,
          grams: pending.grams,
          note: 'Alternativa importada do Dietbox.',
          userId,
        })
        if (response.error) failures.push(`${pending.food.name}: ${response.error.message}`)
        else attached += 1
      }
    }
    setBusy(false)
    const parts = [`${preview.report.importedItems} itens importados`, `${attached} substituições anexadas`]
    if (preview.report.skippedSlots.length) parts.push(`${preview.report.skippedSlots.length} itens não encontrados`)
    if (failures.length) parts.push(`${failures.length} substituições falharam`)
    setResult(parts.join(', ') + '.')
    onImported(draftId)
  }

  async function confirmListImport() {
    setBusy(true)
    let created = 0
    const failures: string[] = []
    for (const group of groups) {
      const resolvedFoods = group.foods
        .map((line) => {
          const food = resolveFood(line.rawName)
          return food ? { description: food.name, grams: line.grams, householdMeasure: line.measure || null, foodId: food.id, caloriesPerPortion: (food.nutrients.energyKcal ?? 0) * (line.grams / 100) } : null
        })
        .filter((item): item is NonNullable<typeof item> => item !== null)
      const response = await writeSource.insertEquivalencyGroup({ organizationId, userId, groupNo: group.groupNo, title: group.title, foods: resolvedFoods })
      if (response.error) failures.push(`Grupo ${group.groupNo}: ${response.error.message}`)
      else created += 1
    }
    setBusy(false)
    const parts = [`${created} listas criadas`]
    if (failures.length) parts.push(`${failures.length} falharam`)
    setResult(parts.join(', ') + '.')
  }

  const allGroupFoodsResolvable = kind === 'substitution_list' && groups.some((group) => group.foods.some((food) => resolveFood(food.rawName)))

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-forest-900/40 p-4 backdrop-blur-sm" onClick={onClose}>
      <div role="dialog" aria-modal="true" aria-label="Importar do Dietbox" className="max-h-[85vh] w-full max-w-3xl overflow-y-auto rounded-2xl bg-card p-5 shadow-warm-lg" onClick={(event) => event.stopPropagation()}>
        <div className="mb-4 flex items-center justify-between">
          <p className="font-display text-lg font-semibold">Importar do Dietbox</p>
          <button type="button" aria-label="Fechar" className="rounded-lg p-1.5 hover:bg-cream-200" onClick={onClose}><X size={16} /></button>
        </div>

        <textarea
          aria-label="Texto colado do Dietbox"
          className="input-warm h-40 w-full font-mono text-xs"
          placeholder="Cole aqui o texto do cardápio ou da lista de substituição do Dietbox..."
          value={text}
          onChange={(event) => setText(event.target.value)}
        />
        <button type="button" className="btn-ghost mt-2" disabled={!text.trim() || analyzing} onClick={() => void analyze()}>
          {analyzing ? 'Analisando...' : 'Analisar'}
        </button>

        {kind === 'unknown' && <p className="mt-3 text-sm text-amber-700">Não reconheci esse texto como um cardápio ou lista de substituição do Dietbox.</p>}

        {warnings.length > 0 && (
          <div className="mt-3 rounded-lg border border-amber-200 bg-amber-50/60 p-2 text-[11px] text-amber-700">
            {warnings.map((warning) => <p key={warning}>{warning}</p>)}
          </div>
        )}

        {kind === 'plan' && (
          <div className="mt-4 space-y-4">
            <div>
              <label className="text-xs font-medium text-muted-foreground" htmlFor="dietbox-target-day">Importar para o dia</label>
              <select id="dietbox-target-day" className="input-warm !w-auto !py-1.5 text-sm" value={targetDayIndex} onChange={(event) => setTargetDayIndex(Number(event.target.value))}>
                {days.map((day, index) => <option key={day.id} value={index}>{day.label}</option>)}
              </select>
            </div>

            {meals.map((meal) => (
              <div key={meal.name + meal.time} className="rounded-xl border border-border p-3">
                <p className="font-mono text-[10px] font-medium uppercase tracking-wider text-amber-700">{meal.time} · {meal.name}</p>
                {meal.notes && <p className="mt-1 text-[11px] italic text-muted-foreground">{meal.notes}</p>}
                <div className="mt-2 space-y-2">
                  {meal.slots.map((slot, slotIndex) => (
                    <div key={slotIndex} className="rounded-lg bg-cream-100 p-2">
                      <MatchStatus rawName={slot.primary.rawName} match={matchIndex.get(slot.primary.rawName)} manualPick={manualPicks.get(slot.primary.rawName)} organizationId={organizationId} catalogSource={catalogSource} onManualPick={onManualPick} />
                      {slot.alternatives.map((alt) => (
                        <p key={alt.rawName} className="ml-3 text-[10.5px] text-muted-foreground">
                          alternativa: {alt.rawName}{resolveFood(alt.rawName) ? ` → ${resolveFood(alt.rawName)?.name}` : ' (não casado — será ignorada)'}
                        </p>
                      ))}
                      {slot.dietboxGroupNo !== null && (
                        <p className="ml-3 text-[10.5px] text-muted-foreground">
                          grupo {slot.dietboxGroupNo}{resolveEquivalencyList(slot.dietboxGroupNo) ? `: lista "${resolveEquivalencyList(slot.dietboxGroupNo)?.title}"` : ' — nenhuma lista correspondente encontrada'}
                        </p>
                      )}
                    </div>
                  ))}
                </div>
              </div>
            ))}

            <button type="button" className="btn-primary" disabled={busy || !allPrimariesResolved || !patientId} onClick={() => void confirmPlanImport()}>
              {busy ? 'Importando...' : 'Confirmar importação'}
            </button>
            {!patientId && <p className="text-xs text-amber-700">Escolha o paciente antes de importar.</p>}
            {!allPrimariesResolved && <p className="text-xs text-amber-700">Resolva todos os itens principais antes de confirmar.</p>}
          </div>
        )}

        {kind === 'substitution_list' && (
          <div className="mt-4 space-y-4">
            {groups.map((group) => (
              <div key={group.groupNo} className="rounded-xl border border-border p-3">
                <p className="font-medium text-sm">Grupo {group.groupNo}: {group.title}</p>
                <div className="mt-2 space-y-2">
                  {group.foods.map((foodLine) => (
                    <MatchStatus key={foodLine.rawName} rawName={foodLine.rawName} match={matchIndex.get(foodLine.rawName)} manualPick={manualPicks.get(foodLine.rawName)} organizationId={organizationId} catalogSource={catalogSource} onManualPick={onManualPick} />
                  ))}
                </div>
              </div>
            ))}
            <button type="button" className="btn-primary" disabled={busy || !allGroupFoodsResolvable} onClick={() => void confirmListImport()}>
              {busy ? 'Importando...' : 'Importar listas'}
            </button>
          </div>
        )}

        {result && <p className="mt-4 rounded-xl border border-border bg-cream-100/60 p-3 text-sm" role="status">{result}</p>}
      </div>
    </div>
  )
}
