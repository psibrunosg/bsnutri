import React, { useState } from 'react'
import {
  ChevronLeft,
  ChevronRight,
  Copy,
  LayoutPanelLeft,
  PanelRightClose,
  Plus,
  RefreshCw,
  Sparkles,
  Trash2,
  UtensilsCrossed,
} from 'lucide-react'
import { gramsPerKg, totalDay, type Meal, type NutrientKey } from '../lib/nutrition'
import { macroKeys, macroLabels, lipidKeys, vitaminKeys, type CatalogFood } from '../lib/useFoodCatalog'
import { builtInPlanModels, matchesModel, type ModelDimensions } from '../lib/planModels'
import { PROTOCOL_LABELS } from '../lib/energyEstimations'
import {
  assistantLabels,
  assistantSteps,
  canPublishPlan,
  canReviewPlan,
  completeAssistantStep,
  clinicalPresetLabels,
  clinicalPresets,
  toggleClinicalPreset,
  type PlanAssistantState,
  type PlanAssistantStep,
} from '../lib/planAssistant'
import { initialDay, type EditorMode, type Patient, type PlanDraftHook, type PlanTemplate, type CatalogRef } from '../lib/usePlanDraft'
import { printClinicalDocument } from '../lib/clinicalExport'
import { formatPlanForExport } from '../lib/planExport'
import { useEquivalencyLists, type EquivalencyList } from '../lib/equivalency'

const MODEL_TAG_LABELS: Record<string, string> = {
  mediterranean: 'Mediterrânea',
  dash: 'DASH',
  ketogenic: 'Cetogênica',
  low_carb: 'Low Carb',
  vegan: 'Vegana',
  vegetarian: 'Vegetariana',
  paleo: 'Paleolítica',
  anti_inflammatory: 'Anti-inflamatória',
  intermittent_fasting: 'Jejum intermitente',
  enteral: 'Enteral',
  glycemic_load: 'Carga glicêmica',
  hypocaloric: 'Hipocalórica',
  high_protein: 'Hiperproteica',
  glycemic_control: 'Controle glicêmico',
  hypertension: 'Hipertensão',
  renal: 'Renal',
  gestational: 'Gestação',
  hypertrophy: 'Hipertrofia',
  dyslipidemia: 'Dislipidemia',
  menopause: 'Menopausa',
  pediatric: 'Pediatria',
  elderly: 'Idosos',
  gastrointestinal: 'Gastrointestinal',
  gout: 'Ácido úrico',
  food_allergy: 'Alergia alimentar',
  swallowing: 'Deglutição',
  perioperative: 'Perioperatório',
  aesthetic: 'Estética',
  weight_loss: 'Emagrecimento',
}
const modelTagLabel = (tag: string) => MODEL_TAG_LABELS[tag] ?? tag



interface PlanEditorProps {
  catalog: CatalogRef
  planDraft: PlanDraftHook
  patients: Patient[]
  organizationId?: string
  setMessage: (msg: string) => void
}

export function PlanEditor({ catalog, planDraft, patients, organizationId, setMessage }: PlanEditorProps) {
  const [sidebarTab, setSidebarTab] = useState<'config' | 'models' | 'drafts' | 'assistant'>('config')
  const { lists: equivalencyLists } = useEquivalencyLists(organizationId)
  const {
    days,
    setDays,
    activeDay,
    setActiveDay,
    drafts,
    templates,
    loadedDraft,
    loadingDrafts,
    planStatus,
    locked,
    targets,
    setTargets,
    assistant,
    setAssistant,
    editorMode,
    setEditorMode,
    confirmSubstitutionWarning,
    contextCollapsed,
    setContextCollapsed,
    analysisCollapsed,
    setAnalysisCollapsed,
    modelFilters,
    setModelFilters,
    patientId,
    setPatientId,
    title,
    setTitle,
    busy,
    patientWeightKg,
    latestEstimate,
    showShoppingList,
    setShowShoppingList,
    meals,
    setMeals,
    totals,
    rangeIssues,
    planChanges,
    nutritionChanges,
    shoppingList,
    loadDrafts,
    openDraft,
    startBlankPlan,
    copyOpenDraft,
    review,
    publish,
    saveTemplate,
    requestApplyTemplate,
    applyBuiltInModel,
    duplicateActiveDay,
    duplicateMeal,
    applyActiveStructureToAllDays,
    addItem,
    save,
  } = planDraft

  return (
    <div className={`plans-layout ${contextCollapsed ? 'context-collapsed' : ''} ${analysisCollapsed ? 'analysis-collapsed' : ''}`}>
      <header className="plan-workspace-header">
        <div>
          <span className="eyebrow">
            <Sparkles /> Construtor de plano
          </span>
          <h2>{title || 'Novo plano alimentar'}</h2>
          <p>Contexto, prescrição e análise reunidos para você decidir sem perder o fio da consulta.</p>
        </div>
        <EditorModeSwitch mode={editorMode} setMode={setEditorMode} />
      </header>
      <aside className="plan-context" aria-label="Contexto do plano">
        <button
          className="rail-toggle"
          aria-label={contextCollapsed ? 'Expandir contexto' : 'Recolher contexto'}
          onClick={() => setContextCollapsed(value => !value)}
        >
          {contextCollapsed ? <LayoutPanelLeft /> : <ChevronLeft />}
        </button>
        {!contextCollapsed && (
          <>
            <div className="editor-mode panel" role="tablist" aria-label="Seções do contexto do plano" style={{ marginBottom: '1rem' }}>
              <button role="tab" id="plan-context-tab-config" aria-controls="plan-context-panel-config" aria-selected={sidebarTab === 'config'} className={sidebarTab === 'config' ? 'active' : ''} onClick={() => setSidebarTab('config')}>Configuração</button>
              <button role="tab" id="plan-context-tab-models" aria-controls="plan-context-panel-models" aria-selected={sidebarTab === 'models'} className={sidebarTab === 'models' ? 'active' : ''} onClick={() => setSidebarTab('models')}>Modelos</button>
              <button role="tab" id="plan-context-tab-drafts" aria-controls="plan-context-panel-drafts" aria-selected={sidebarTab === 'drafts'} className={sidebarTab === 'drafts' ? 'active' : ''} onClick={() => setSidebarTab('drafts')}>Planos</button>
              <button role="tab" id="plan-context-tab-assistant" aria-controls="plan-context-panel-assistant" aria-selected={sidebarTab === 'assistant'} className={sidebarTab === 'assistant' ? 'active' : ''} onClick={() => setSidebarTab('assistant')}>Assistente</button>
            </div>
            <div role="tabpanel" id={`plan-context-panel-${sidebarTab}`} aria-labelledby={`plan-context-tab-${sidebarTab}`}>
            {sidebarTab === 'config' && (
              <section className="panel plan-basics">
                <div className="panel-kicker">
                  <UtensilsCrossed /> Contexto clínico
                </div>
                <label>
                  Paciente
                  <select value={patientId} disabled={locked} onChange={e => setPatientId(e.target.value)}>
                    <option value="">Selecione</option>
                    {patients.map(p => (
                      <option key={p.id} value={p.id}>
                        {p.anonymous_code} · {p.full_name}
                      </option>
                    ))}
                  </select>
                </label>
                <label>
                  Título
                  <input value={title} readOnly={locked} onChange={e => setTitle(e.target.value)} />
                </label>
              </section>
            )}

            {sidebarTab === 'drafts' && (
              <aside className="draft-panel panel">
                <header>
                  <div>
                    <h2>Planos</h2>
                    <small>{drafts.length} plano(s)</small>
                  </div>
                  <button aria-label="Atualizar planos" onClick={() => void loadDrafts()}>
                    <RefreshCw />
                  </button>
                </header>
                <div className="template-box">
                  <h3>Começar plano</h3>
                  <button className="secondary" onClick={startBlankPlan}>
                    <Plus /> Em branco
                  </button>
                  <button className="secondary" disabled={!loadedDraft} onClick={copyOpenDraft}>
                    <Copy /> Usar plano aberto como base
                  </button>
                </div>
                {loadingDrafts ? (
                  <p className="muted">Carregando planos...</p>
                ) : (
                  <div className="draft-list">
                    {drafts.map(draft => (
                      <button className={loadedDraft === draft.id ? 'active' : ''} key={draft.id} onClick={() => openDraft(draft)}>
                        <span>
                          <strong>{draft.title}</strong>
                          <small>
                            {patients.find(p => p.id === draft.patientId)?.full_name ?? 'Paciente'} · {draft.days.length} dia(s) · v
                            {draft.version}
                          </small>
                          <time>
                            <b className={`plan-status ${draft.status}`}>
                              {draft.status === 'published' ? 'Publicado' : draft.status === 'reviewed' ? 'Revisado' : 'Rascunho'}
                            </b>{' '}
                            · {new Date(draft.updatedAt).toLocaleDateString('pt-BR')}
                          </time>
                        </span>
                        <ChevronRight />
                      </button>
                    ))}
                    {!drafts.length && <p className="muted">Nenhum plano salvo.</p>}
                    <div className="template-box">
                      <h3>Salvar modelo</h3>
                      <button className="secondary" disabled={!loadedDraft} onClick={() => void saveTemplate('personal')}>
                        Salvar pessoal
                      </button>
                      <button className="secondary" disabled={!loadedDraft} onClick={() => void saveTemplate('organization')}>
                        Compartilhar com clínica
                      </button>
                    </div>
                  </div>
                )}
              </aside>
            )}

            {sidebarTab === 'models' && (
              <ModelGallery
                templates={templates}
                filters={modelFilters}
                setFilters={setModelFilters}
                applyBuiltInModel={applyBuiltInModel}
                requestApplyTemplate={requestApplyTemplate}
              />
            )}

            {sidebarTab === 'assistant' && (
              <PlanAssistant state={assistant} setState={setAssistant} locked={locked} />
            )}
            </div>
          </>
        )}
      </aside>
      <main className={`plan-editor ${editorMode}`}>
        <div className="day-tabs" role="tablist" aria-label="Dias do plano">
          {days.map((day, index) => (
            <button role="tab" id={`plan-day-tab-${day.id}`} aria-controls="plan-day-panel" aria-selected={activeDay === index} className={activeDay === index ? 'active' : ''} key={day.id} onClick={() => setActiveDay(index)}>
              {day.label}
            </button>
          ))}
          {!locked && (
            <>
              <button
                onClick={() => {
                  setDays(all => [...all, { ...initialDay(), label: `Dia ${all.length + 1}` }])
                  setActiveDay(days.length)
                }}
              >
                <Plus /> Dia
              </button>
              <button className="secondary" onClick={duplicateActiveDay}>
                <Copy /> Duplicar dia
              </button>
            </>
          )}
        </div>
        <div role="tabpanel" id="plan-day-panel" aria-labelledby={`plan-day-tab-${days[activeDay].id}`}>
        <div className="plan-export-actions">
          <button
            className="secondary"
            onClick={() => {
              if (!printClinicalDocument(title || 'Plano alimentar', patients.find(p => p.id === patientId)?.full_name ?? '', formatPlanForExport(title || 'Plano alimentar', days, targets, equivalencyLists)))
                setMessage('Permita janelas pop-up para exportar.')
            }}
          >
            Imprimir plano
          </button>
          <button className="secondary" onClick={() => setShowShoppingList(value => !value)}>
            {showShoppingList ? 'Ocultar lista de compras' : 'Lista de compras'}
          </button>
        </div>
        {showShoppingList && (
          <section className="panel plan-shopping-list">
            <h3>Lista de compras</h3>
            {shoppingList.length ? (
              <ul>
                {shoppingList.map(item => (
                  <li key={item.name}>
                    {item.name} - {item.grams.toLocaleString('pt-BR')} g
                  </li>
                ))}
              </ul>
            ) : (
              <p className="muted">Nenhum item nas refeições ainda.</p>
            )}
            {shoppingList.length > 0 && (
              <button
                className="secondary"
                onClick={() => {
                  if (!printClinicalDocument('Lista de compras', title || 'Plano alimentar', shoppingList.map(item => `${item.name} - ${item.grams.toLocaleString('pt-BR')} g`).join('\n')))
                    setMessage('Permita janelas pop-up para exportar.')
                }}
              >
                Imprimir lista
              </button>
            )}
          </section>
        )}
        {meals.map((meal, index) => (
          <EditableMealCard key={meal.id} meal={meal} index={index} foods={catalog.foods} equivalencyLists={equivalencyLists} setMeals={setMeals} addItem={addItem} duplicateMeal={duplicateMeal} readOnly={locked} />
        ))}
        <MealDistributionInputs meals={meals} assistant={assistant} setAssistant={setAssistant} locked={locked} />
        {planChanges.length > 0 && (
          <section className="panel plan-comparison">
            <h3>Alterações desde versão aberta</h3>
            <ul>
              {planChanges.map(change => (
                <li key={change}>{change}</li>
              ))}
            </ul>
            {nutritionChanges.length > 0 && (
              <>
                <h4>Impacto nutricional do plano</h4>
                <ul>
                  {nutritionChanges.map(change => (
                    <li key={change}>{change}</li>
                  ))}
                </ul>
              </>
            )}
          </section>
        )}
        {!locked && (
          <div className="editor-actions">
            <button className="secondary" onClick={() => setMeals(m => [...m, { id: crypto.randomUUID(), name: `Refeição ${m.length + 1}`, items: [] }])}>
              <Plus />
              Adicionar refeição
            </button>
            <button className="secondary" disabled={days.length < 2} onClick={applyActiveStructureToAllDays}>
              <Copy />
              Aplicar refeições a todos os dias
            </button>
            <span className="publication-actions">
              <button className="secondary" disabled={busy || !loadedDraft || !canReviewPlan(assistant)} onClick={() => void review()}>
                Marcar como revisado
              </button>
              <button className="primary" disabled={busy || !canPublishPlan(assistant, planStatus)} onClick={() => void publish()}>
                {confirmSubstitutionWarning ? 'Confirmar publicação' : 'Publicar'}
              </button>
              <button className="primary" disabled={busy} onClick={() => void save()}>
                {busy ? 'Salvando...' : loadedDraft ? 'Salvar como novo rascunho' : 'Salvar rascunho'}
              </button>
            </span>
          </div>
        )}
        </div>
      </main>
      <aside className="plan-analysis" aria-label="Análise nutricional">
        <button
          className="rail-toggle"
          aria-label={analysisCollapsed ? 'Expandir análise' : 'Recolher análise'}
          onClick={() => setAnalysisCollapsed(value => !value)}
        >
          {analysisCollapsed ? <PanelRightClose /> : <ChevronRight />}
        </button>
        {!analysisCollapsed && (
          <>
            <section className="panel target-panel" aria-hidden={editorMode === 'quick'}>
              <header>
                <div>
                  <h2>Metas nutricionais</h2>
                  <small>Status: {planStatus === 'published' ? 'Publicado' : planStatus === 'reviewed' ? 'Revisado' : 'Rascunho'}</small>
                </div>
              </header>
              {latestEstimate && !locked && (
                <div className="estimate-import-box" style={{ margin: '0.5rem 0', padding: '0.5rem', background: 'var(--surface-sunken, #f1f5f9)', borderRadius: '4px' }}>
                  <small style={{ display: 'block', marginBottom: '0.25rem' }}>
                    GET Estimado: <strong>{latestEstimate.total_energy_expenditure} kcal/dia</strong> ({PROTOCOL_LABELS[latestEstimate.protocol] ?? latestEstimate.protocol})
                  </small>
                  <button
                    type="button"
                    className="secondary small"
                    onClick={() => {
                      setTargets(all => ({ ...all, energyKcal: latestEstimate.total_energy_expenditure }))
                      setMessage(`Meta de energia importada: ${latestEstimate.total_energy_expenditure} kcal/dia.`)
                    }}
                  >
                    Importar GET como meta energética
                  </button>
                </div>
              )}
              <div>
                {(
                  [
                    ['energyKcal', 'Energia (kcal)'],
                    ['proteinG', 'Proteína (g)'],
                    ['carbohydrateG', 'Carboidrato (g)'],
                    ['fatG', 'Gordura (g)'],
                    ['fiberG', 'Fibra (g)'],
                    ['waterMl', 'Água (ml)'],
                  ] as const
                ).map(([key, label]) => (
                  <label key={key}>
                    {label}
                    <input type="number" min="0" step="0.1" value={targets[key] ?? 0} disabled={locked} onChange={e => setTargets(all => ({ ...all, [key]: Number(e.target.value) }))} />
                  </label>
                ))}
              </div>
              <TargetRangeInputs state={assistant} setState={setAssistant} setTargets={setTargets} locked={locked} />
            </section>
            <section className="live-totals" aria-hidden={editorMode === 'quick'}>
              {macroKeys.map(k => {
                const perKg = k === 'energyKcal' ? null : gramsPerKg(totals[k], patientWeightKg)
                return (
                  <div key={k}>
                    <small>{macroLabels[k]}</small>
                    <strong>
                      {totals[k].toLocaleString('pt-BR')} {k === 'energyKcal' ? 'kcal' : 'g'}
                    </strong>
                    {perKg !== null && <small>{perKg.toLocaleString('pt-BR')} g/kg</small>}
                  </div>
                )
              })}
            </section>
            {editorMode === 'technical' && (
              <>
                <section className="panel lipid-totals" style={{ marginTop: '0.5rem' }}>
                  <h4>Frações Lipídicas (Total do dia)</h4>
                  <div className="live-totals" style={{ display: 'flex', gap: '1rem', flexWrap: 'wrap', marginTop: '0.5rem' }}>
                    {lipidKeys.map(k => (
                      <div key={k}>
                        <small>{macroLabels[k]}</small>
                        <strong>{totals[k]?.toLocaleString('pt-BR') || 0} g</strong>
                      </div>
                    ))}
                  </div>
                </section>
                <section className="panel micronutrient-totals" style={{ marginTop: '0.5rem' }}>
                  <h4>Micronutrientes & Complexo B (Total do dia)</h4>
                  <div className="live-totals" style={{ display: 'flex', gap: '1rem', flexWrap: 'wrap', marginTop: '0.5rem' }}>
                    {vitaminKeys.map(k => (
                      <div key={k}>
                        <small>{macroLabels[k]}</small>
                        <strong>{totals[k]?.toLocaleString('pt-BR') || 0} {k.endsWith('Mg') ? 'mg' : k.endsWith('Mcg') ? 'mcg' : 'g'}</strong>
                      </div>
                    ))}
                  </div>
                </section>
              </>
            )}
            {rangeIssues.length > 0 && (
              <section className="panel range-issues" role="status">
                <h3>Faixas a revisar</h3>
                <ul>
                  {rangeIssues.map(issue => (
                    <li key={issue}>{issue}</li>
                  ))}
                </ul>
                <label>
                  Justificativa clínica
                  <textarea value={assistant.rangeJustification ?? ''} disabled={locked} onChange={event => setAssistant(current => ({ ...current, rangeJustification: event.target.value }))} />
                </label>
              </section>
            )}
            <TechnicalChecklist assistant={assistant} canReview={canReviewPlan(assistant)} hidden={editorMode === 'quick'} />
          </>
        )}
      </aside>

    </div>
  )
}

function EditorModeSwitch({ mode, setMode }: { mode: EditorMode; setMode: (mode: EditorMode) => void }) {
  return (
    <div className="editor-mode panel" role="tablist" aria-label="Modo do editor">
      <button role="tab" aria-selected={mode === 'quick'} className={mode === 'quick' ? 'active' : ''} onClick={() => setMode('quick')}>
        Consulta rapida
      </button>
      <button role="tab" aria-selected={mode === 'technical'} className={mode === 'technical' ? 'active' : ''} onClick={() => setMode('technical')}>
        Tecnico
      </button>
    </div>
  )
}

function TechnicalChecklist({ assistant, canReview, hidden }: { assistant: PlanAssistantState; canReview: boolean; hidden: boolean }) {
  const pending = assistantSteps.filter(step => step !== 'publish' && !assistant.completedSteps.includes(step))
  return (
    <section className="panel technical-checklist" aria-hidden={hidden}>
      <h2>Pendencias tecnicas</h2>
      {canReview ? (
        <p className="muted">Assistente pronto para revisao.</p>
      ) : (
        <ul>
          {pending.map(step => (
            <li key={step}>{assistantLabels[step]}</li>
          ))}
        </ul>
      )}
    </section>
  )
}

function TargetRangeInputs({
  state,
  setState,
  setTargets,
  locked,
}: {
  state: PlanAssistantState
  setState: React.Dispatch<React.SetStateAction<PlanAssistantState>>
  setTargets: React.Dispatch<React.SetStateAction<Record<string, number>>>
  locked: boolean
}) {
  const fields: [NutrientKey, string][] = [
    ['energyKcal', 'Energia (kcal)'],
    ['proteinG', 'Proteína (g)'],
    ['carbohydrateG', 'Carboidrato (g)'],
    ['fatG', 'Gordura (g)'],
    ['fiberG', 'Fibra (g)'],
    ['saturatedFatG', 'Gordura Saturada (g)'],
    ['monounsaturatedFatG', 'Gordura Monoinsaturada (g)'],
    ['polyunsaturatedFatG', 'Gordura Poli-insaturada (g)'],
    ['transFatG', 'Gordura Trans (g)'],
    ['vitaminB12Mcg', 'Vitamina B12 (mcg)'],
    ['vitaminCMg', 'Vitamina C (mg)'],
  ]
  const change = (key: NutrientKey, field: 'min' | 'target' | 'max', value: number) => {
    setState(current => ({
      ...current,
      targetRanges: {
        ...current.targetRanges,
        [key]: { min: current.targetRanges[key]?.min ?? 0, target: current.targetRanges[key]?.target ?? 0, max: current.targetRanges[key]?.max ?? 0, [field]: value },
      },
    }))
    if (field === 'target') setTargets(current => ({ ...current, [key]: value }))
  }
  return (
    <fieldset className="target-ranges">
      <legend>Faixas aceitáveis</legend>
      {fields.map(([key, label]) => {
        const range = state.targetRanges[key] ?? { min: 0, target: 0, max: 0 }
        return (
          <div key={key}>
            <strong>{label}</strong>
            {(['min', 'target', 'max'] as const).map(field => (
              <label key={field}>
                {field === 'min' ? 'Mín.' : field === 'target' ? 'Alvo' : 'Máx.'}
                <input aria-label={`${label} ${field}`} type="number" min="0" step="0.1" disabled={locked} value={range[field]} onChange={event => change(key, field, Number(event.target.value))} />
              </label>
            ))}
          </div>
        )
      })}
    </fieldset>
  )
}

function MealDistributionInputs({
  meals,
  assistant,
  setAssistant,
  locked,
}: {
  meals: Meal[]
  assistant: PlanAssistantState
  setAssistant: React.Dispatch<React.SetStateAction<PlanAssistantState>>
  locked: boolean
}) {
  if (!meals.length) return null
  const total = meals.reduce((sum, meal) => sum + (assistant.mealDistributions[meal.id] ?? 0), 0)
  return (
    <section className="panel meal-distribution">
      <h3>Distribuição entre refeições</h3>
      <p className="muted">Defina a participação da energia diária. Total: {total}%.</p>
      {meals.map(meal => (
        <label key={meal.id}>
          {meal.name}
          <input
            aria-label={`Distribuição de ${meal.name}`}
            type="number"
            min="0"
            max="100"
            step="1"
            disabled={locked}
            value={assistant.mealDistributions[meal.id] ?? 0}
            onChange={event => setAssistant(current => ({ ...current, mealDistributions: { ...current.mealDistributions, [meal.id]: Number(event.target.value) || 0 } }))}
          />
          %
        </label>
      ))}
    </section>
  )
}

function PlanAssistant({
  state,
  setState,
  locked,
}: {
  state: PlanAssistantState
  setState: React.Dispatch<React.SetStateAction<PlanAssistantState>>
  locked: boolean
}) {
  const index = assistantSteps.indexOf(state.currentStep)
  const move = (step: PlanAssistantStep) => setState(current => ({ ...current, currentStep: step }))
  const complete = () => setState(current => completeAssistantStep(current, current.currentStep))
  return (
    <section className="panel plan-assistant">
      <header>
        <div>
          <h2>Assistente do plano</h2>
          <small>Etapa atual: {assistantLabels[state.currentStep]}</small>
        </div>
      </header>
      <div className="assistant-steps">
        {assistantSteps.map(step => (
          <button
            key={step}
            className={state.currentStep === step ? 'active' : state.completedSteps.includes(step) ? 'done' : ''}
            disabled={locked}
            onClick={() => move(step)}
          >
            {assistantLabels[step]}
          </button>
        ))}
      </div>
      <label>
        Objetivo clínico
        <input
          value={state.objective}
          readOnly={locked}
          onChange={e => setState(current => ({ ...current, objective: e.target.value }))}
          placeholder="Ex.: recomposição corporal com melhora de rotina"
        />
      </label>
      <div className="preset-grid">
        {clinicalPresets.map(preset => (
          <label key={preset} className="check-option">
            <input type="checkbox" checked={state.clinicalPresets.includes(preset)} disabled={locked} onChange={() => setState(current => toggleClinicalPreset(current, preset))} />
            {clinicalPresetLabels[preset]}
          </label>
        ))}
      </div>
      <label>
        Micronutrientes prioritarios
        <textarea
          value={state.priorityMicronutrients.join(', ')}
          readOnly={locked}
          onChange={e => setState(current => ({ ...current, priorityMicronutrients: e.target.value.split(',').map(item => item.trim()).filter(Boolean) }))}
          placeholder="Ex.: Ferro, Calcio, Vitamina D"
        />
      </label>
      <div className="visibility-grid">
        <strong>Visibilidade no portal</strong>
        <label className="check-option">
          <input type="checkbox" checked={state.visibility.showTotalKcal} disabled={locked} onChange={e => setState(current => ({ ...current, visibility: { ...current.visibility, showTotalKcal: e.target.checked } }))} />
          Kcal totais
        </label>
        <label className="check-option">
          <input type="checkbox" checked={state.visibility.showTotalMacros} disabled={locked} onChange={e => setState(current => ({ ...current, visibility: { ...current.visibility, showTotalMacros: e.target.checked } }))} />
          Macros totais
        </label>
        <label className="check-option">
          <input type="checkbox" checked={state.visibility.showMealCalculations} disabled={locked} onChange={e => setState(current => ({ ...current, visibility: { ...current.visibility, showMealCalculations: e.target.checked } }))} />
          Calculos por refeicao
        </label>
        <label className="check-option">
          <input type="checkbox" checked={state.visibility.showDiary} disabled={locked} onChange={e => setState(current => ({ ...current, visibility: { ...current.visibility, showDiary: e.target.checked } }))} />
          Diário alimentar
        </label>
      </div>
      {!locked && (
        <div className="assistant-actions">
          <button className="secondary" disabled={index <= 0} onClick={() => move(assistantSteps[index - 1])}>
            Voltar
          </button>
          <button className="secondary" onClick={complete}>
            Concluir etapa
          </button>
          <button className="secondary" disabled={index >= assistantSteps.length - 1} onClick={() => move(assistantSteps[index + 1])}>
            Avançar
          </button>
        </div>
      )}
    </section>
  )
}


function ModelGallery({
  templates,
  filters,
  setFilters,
  applyBuiltInModel,
  requestApplyTemplate,
}: {
  templates: PlanTemplate[]
  filters: Partial<ModelDimensions>
  setFilters: React.Dispatch<React.SetStateAction<Partial<ModelDimensions>>>
  applyBuiltInModel: (model: (typeof builtInPlanModels)[number]) => void
  requestApplyTemplate: (id: string, name: string) => void
}) {
  const models = [
    ...builtInPlanModels,
    ...templates.map(template => ({
      id: template.id,
      name: template.name,
      summary: template.rules?.guidance?.[0] ?? 'Modelo salvo pela equipe.',
      dimensions: template.dimensions ?? {
        approaches: template.tags ?? [],
        objectives: template.objective ? [template.objective] : [],
        restrictions: [],
        preferences: [],
        contexts: [],
      },
      rules: template.rules ?? { targets: {}, guidance: [] },
      templateId: template.id,
      scope: template.scope,
    })),
  ].filter(model => matchesModel(model, filters))
  const toggle = (key: keyof ModelDimensions, value: string) =>
    setFilters(current => ({
      ...current,
      [key]: current[key]?.includes(value) ? current[key]?.filter(item => item !== value) : [...(current[key] ?? []), value],
    }))
  const choices: { key: keyof ModelDimensions; label: string; values: string[] }[] = [
    { key: 'approaches', label: 'Abordagem', values: ['Brasileira equilibrada', 'Mediterrânea', 'DASH', 'Vegetariana', 'Vegana', 'Flexível', 'Esportiva'] },
    { key: 'objectives', label: 'Objetivo', values: ['Emagrecimento', 'Hipertrofia', 'Desempenho', 'Controle glicêmico', 'Baixo custo', 'Adesão'] },
    { key: 'contexts', label: 'Contexto', values: ['baixo custo', 'rotina corrida', 'cultura brasileira'] },
  ]
  return (
    <section className="model-gallery" aria-label="Galeria de modelos">
      <header>
        <div>
          <span className="eyebrow">Modelos combináveis</span>
          <h3>Aplicar modelo</h3>
        </div>
        <small>{models.length} opção(ões)</small>
      </header>
      {choices.map(group => (
        <fieldset key={group.key}>
          <legend>{group.label}</legend>
          {group.values.map(value => (
            <label key={value}>
              <input type="checkbox" checked={filters[group.key]?.includes(value) ?? false} onChange={() => toggle(group.key, value)} />
              {value}
            </label>
          ))}
        </fieldset>
      ))}
      <div className="model-cards">
        {models.map(model => {
          const templateId = 'templateId' in model && typeof model.templateId === 'string' ? model.templateId : null
          return (
            <article key={model.id}>
              <span className="catalog-badge">{'scope' in model && model.scope === 'personal' ? 'Pessoal' : 'Modelo'}</span>
              <strong>{model.name}</strong>
              <small>{model.summary}</small>
              <em>
                {modelTagLabel(model.dimensions.approaches[0] ?? 'Flexível')} · {modelTagLabel(model.dimensions.objectives[0] ?? 'Personalizável')}
              </em>
              {'requiredContext' in model && model.requiredContext?.length && <small>Antes de usar: {model.requiredContext.join(' · ')}</small>}
              {'limits' in model && model.limits?.map(limit => <small key={limit}>Limite: {limit}</small>)}
              {'sources' in model && model.sources?.length && <small>Fonte: {model.sources.join(' · ')}</small>}
              <button className="secondary" onClick={() => (templateId ? requestApplyTemplate(templateId, model.name) : applyBuiltInModel(model))}>
                Aplicar
              </button>
            </article>
          )
        })}
        {!models.length && <p className="muted">Nenhum modelo corresponde aos filtros.</p>}
      </div>
    </section>
  )
}

function EditableMealCard({
  meal,
  index,
  foods,
  equivalencyLists = [],
  setMeals,
  addItem,
  duplicateMeal,
  readOnly,
}: {
  meal: Meal
  index: number
  foods: CatalogFood[]
  equivalencyLists?: EquivalencyList[]
  setMeals: React.Dispatch<React.SetStateAction<Meal[]>>
  addItem: (m: string, f: string, g: number) => void
  duplicateMeal: (meal: Meal) => void
  readOnly: boolean
}) {
  const [food, setFood] = useState('')
  const [foodQuery, setFoodQuery] = useState('')
  const [grams, setGrams] = useState(100)
  const total = totalDay([meal])
  const filteredFoods = foods.filter(f => f.name.toLowerCase().includes(foodQuery.trim().toLowerCase()))
  return (
    <section className="panel meal-editor" aria-label={meal.name}>
      <div className="meal-heading">
        <input aria-label={`Nome da refeição ${index + 1}`} value={meal.name} readOnly={readOnly} onChange={e => setMeals(all => all.map(m => (m.id === meal.id ? { ...m, name: e.target.value } : m)))} />
        {!readOnly && (
          <>
            <button aria-label={`Duplicar ${meal.name}`} onClick={() => duplicateMeal(meal)}>
              <Copy />
            </button>
            <button aria-label="Remover refeição" onClick={() => setMeals(all => all.filter(m => m.id !== meal.id))}>
              <Trash2 />
            </button>
          </>
        )}
      </div>
      {!readOnly && (
        <div className="add-food-row">
          <input aria-label={`Buscar alimento no ${meal.name}`} value={foodQuery} onChange={e => setFoodQuery(e.target.value)} placeholder="Buscar alimento" />
          <select aria-label={`Alimento no ${meal.name}`} value={food} onChange={e => setFood(e.target.value)}>
            <option value="">Escolha um alimento</option>
            {filteredFoods.map(f => (
              <option key={f.id} value={f.id}>
                {f.name}
              </option>
            ))}
          </select>
          <input aria-label={`Gramas no ${meal.name}`} type="number" min=".01" step=".01" value={grams} onChange={e => setGrams(Number(e.target.value))} />
          <button
            className="secondary"
            onClick={() => {
              addItem(meal.id, food, grams)
              setFood('')
            }}
          >
            <Plus />
            Item
          </button>
        </div>
      )}
      {meal.items.map(item => (
        <div className="meal-item" key={item.id}>
          <span>
            {readOnly ? (
              <strong>{item.name}</strong>
            ) : (
              <select
                aria-label={`Alimento de ${item.name}`}
                value={item.foodId ?? foods.find(f => f.name === item.name)?.id ?? ''}
                onChange={e => {
                  const selected = foods.find(f => f.id === e.target.value)
                  if (selected)
                    setMeals(all =>
                      all.map(m =>
                        m.id === meal.id
                          ? { ...m, items: m.items.map(i => (i.id === item.id ? { ...i, foodId: selected.id, name: selected.name, nutrientsPer100g: selected.nutrients } : i)) }
                          : m
                      )
                    )
                }}
              >
                {foods.map(f => (
                  <option key={f.id} value={f.id}>
                    {f.name}
                  </option>
                ))}
              </select>
            )}
            {readOnly ? (
              <small>{item.grams} g</small>
            ) : (
              <input
                aria-label={`Gramas de ${item.name}`}
                type="number"
                min=".01"
                step=".01"
                value={item.grams}
                onChange={e =>
                  setMeals(all =>
                    all.map(m => (m.id === meal.id ? { ...m, items: m.items.map(i => (i.id === item.id ? { ...i, grams: Number(e.target.value) } : i)) } : m))
                  )
                }
              />
            )}
          </span>
          {!readOnly && (
            <button aria-label={`Remover ${item.name}`} onClick={() => setMeals(all => all.map(m => (m.id === meal.id ? { ...m, items: m.items.filter(i => i.id !== item.id) } : m)))}>
              <Trash2 />
            </button>
          )}
        </div>
      ))}
      <div className="meal-equivalency-row" style={{ marginTop: '0.75rem', paddingTop: '0.5rem', borderTop: '1px dashed var(--border, #e2e8f0)' }}>
        <label style={{ display: 'block', fontSize: '0.8rem', fontWeight: 600, color: 'var(--muted, #64748b)', marginBottom: '0.25rem' }}>
          Trocas Autônomas (Equivalência Calórica):
        </label>
        {readOnly ? (
          <span style={{ fontSize: '0.85rem', fontWeight: 500 }}>
            {equivalencyLists.find(l => l.id === meal.equivalencyListId)?.title || 'Nenhuma lista vinculada (avaliação unitária)'}
          </span>
        ) : (
          <select
            aria-label={`Lista de equivalência para ${meal.name}`}
            value={meal.equivalencyListId || ''}
            onChange={e => {
              const val = e.target.value || undefined
              setMeals(all => all.map(m => (m.id === meal.id ? { ...m, equivalencyListId: val } : m)))
            }}
            style={{ width: '100%', padding: '0.4rem', fontSize: '0.85rem', borderRadius: '4px' }}
          >
            <option value="">Sem lista vinculada (avaliação de troca item a item)</option>
            {equivalencyLists.map(l => (
              <option key={l.id} value={l.id}>
                {l.title} (±{l.calorieTolerancePct}% cal · {l.macroGroup})
              </option>
            ))}
          </select>
        )}
      </div>
      <div className="meal-subtotal">
        {total.energyKcal} kcal · P {total.proteinG} g · C {total.carbohydrateG} g · G {total.fatG} g
      </div>
    </section>
  )
}
