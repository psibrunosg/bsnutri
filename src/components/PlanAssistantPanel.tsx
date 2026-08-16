import { useState } from 'react'
import { Check } from 'lucide-react'
import {
  assistantLabels,
  clinicalPresetLabels,
  clinicalPresets,
  completeAssistantStep,
  type ClinicalPreset,
  type PlanAssistantState,
} from '../lib/planAssistant'
import { REQUIRED_ASSISTANT_STEPS as REQUIRED_STEPS, derivedStepReadiness } from '../lib/assistantReadiness'
import type { EditorDay } from '../lib/planDrafts'
import type { TargetSuggestion } from '../lib/planTargets'



const PRESET_MICRONUTRIENTS: Record<ClinicalPreset, string[]> = {
  weight_loss: ['Fibra', 'Potassio', 'Vitamina C'],
  hypertrophy: ['Ferro', 'Calcio', 'Vitamina C'],
  insulin_resistance: ['Fibra', 'Magnesio', 'Potassio'],
  hypertension: ['Sodio', 'Potassio', 'Calcio'],
  vegetarian: ['Ferro', 'Calcio', 'Vitamina B12'],
  child_teen: ['Calcio', 'Ferro', 'Vitamina D'],
}



const TARGET_FIELDS = [
  { key: 'energyKcal', label: 'Energia', unit: 'kcal' },
  { key: 'proteinG', label: 'Proteína', unit: 'g' },
  { key: 'carbohydrateG', label: 'Carboidrato', unit: 'g' },
  { key: 'fatG', label: 'Gordura', unit: 'g' },
  { key: 'fiberG', label: 'Fibra', unit: 'g' },
  { key: 'waterMl', label: 'Água', unit: 'ml' },
] as const

export interface PlanAssistantPanelProps {
  assistant: PlanAssistantState
  setAssistant: (update: (current: PlanAssistantState) => PlanAssistantState) => void
  targets: Record<string, number>
  setTargets: (update: (current: Record<string, number>) => Record<string, number>) => void
  days: EditorDay[]
  disabled: boolean
  suggestion?: TargetSuggestion | null
  onApplySuggestion?: () => void
}

export function PlanAssistantPanel({ assistant, setAssistant, targets, setTargets, days, disabled, suggestion, onApplySuggestion }: PlanAssistantPanelProps) {
  const [micronutrient, setMicronutrient] = useState('')
  const readiness = derivedStepReadiness(assistant, targets, days)

  function togglePreset(preset: ClinicalPreset) {
    setAssistant((current) => {
      const active = current.clinicalPresets.includes(preset)
      const presets = active ? current.clinicalPresets.filter((item) => item !== preset) : [...current.clinicalPresets, preset]
      const suggested = active ? current.priorityMicronutrients : [...current.priorityMicronutrients, ...PRESET_MICRONUTRIENTS[preset]]
      return { ...current, clinicalPresets: presets, priorityMicronutrients: [...new Set(suggested)] }
    })
  }

  function addMicronutrient() {
    const value = micronutrient.trim()
    if (!value) return
    setAssistant((current) => ({ ...current, priorityMicronutrients: [...new Set([...current.priorityMicronutrients, value])] }))
    setMicronutrient('')
  }

  function confirmEquivalents() {
    setAssistant((current) => completeAssistantStep(current, 'equivalents'))
  }

  // As três primeiras etapas seguem o conteúdo real do plano; nada é marcado por conta própria.
  function syncSteps() {
    setAssistant((current) => {
      let next = current
      for (const step of REQUIRED_STEPS) {
        if (step !== 'equivalents' && readiness[step]) next = completeAssistantStep(next, step)
      }
      return next
    })
  }

  return (
    <section className="card-warm p-5">
      <h2 className="font-display text-lg font-semibold">Assistente clínico</h2>
      <p className="mt-1 text-sm text-muted-foreground">Revisão e publicação exigem estas etapas concluídas.</p>

      <ol className="mt-4 space-y-1.5">
        {REQUIRED_STEPS.map((step) => {
          const done = assistant.completedSteps.includes(step)
          const ready = readiness[step]
          return (
            <li key={step} className="flex items-center gap-2 text-sm">
              <span
                aria-hidden="true"
                className={`flex h-4 w-4 shrink-0 items-center justify-center rounded-full ${done ? 'bg-forest-500 text-cream-50' : ready ? 'bg-amber-200' : 'bg-cream-200'}`}
              >
                {done && <Check size={11} />}
              </span>
              <span className={done ? 'text-foreground' : 'text-muted-foreground'}>
                {assistantLabels[step]}{done ? '' : ready ? ' · pronto para confirmar' : ' · pendente'}
              </span>
            </li>
          )
        })}
      </ol>

      <div className="mt-4 space-y-4">
        <div>
          <label className="label-warm" htmlFor="assistant-objective">Objetivo do plano</label>
          <input
            id="assistant-objective"
            className="input-warm"
            disabled={disabled}
            value={assistant.objective}
            onChange={(event) => setAssistant((current) => ({ ...current, objective: event.target.value }))}
            placeholder="Ex.: perda de peso com preservação de massa magra"
          />
        </div>

        <fieldset>
          <legend className="label-warm">Metas do plano</legend>
          {suggestion && (
            <p className="mb-2 rounded-lg border border-forest-200 bg-forest-50 p-2 text-[11px] text-forest-700">
              Calculadas a partir da estimativa energética do paciente ({suggestion.energyKcal} kcal). Revise e ajuste.
              {onApplySuggestion && (
                <button type="button" className="ml-1 underline underline-offset-2" disabled={disabled} onClick={onApplySuggestion}>
                  recalcular
                </button>
              )}
            </p>
          )}
          <div className="grid grid-cols-2 gap-2">
            {TARGET_FIELDS.map((field) => (
              <div key={field.key}>
                <label className="text-[11px] text-muted-foreground" htmlFor={`target-${field.key}`}>{field.label} ({field.unit})</label>
                <input
                  id={`target-${field.key}`}
                  className="input-warm !py-1.5 !text-sm"
                  inputMode="decimal"
                  disabled={disabled}
                  value={targets[field.key] ?? 0}
                  onChange={(event) => setTargets((current) => ({ ...current, [field.key]: Number(event.target.value.replace(',', '.')) || 0 }))}
                />
              </div>
            ))}
          </div>
        </fieldset>

        <fieldset>
          <legend className="label-warm">Abordagem clínica</legend>
          <div className="flex flex-wrap gap-1.5">
            {clinicalPresets.map((preset) => (
              <button
                key={preset}
                type="button"
                disabled={disabled}
                aria-pressed={assistant.clinicalPresets.includes(preset)}
                onClick={() => togglePreset(preset)}
                className={`chip ${assistant.clinicalPresets.includes(preset) ? '!border-forest-300 !bg-forest-50 text-forest-700' : 'text-muted-foreground'}`}
              >
                {clinicalPresetLabels[preset]}
              </button>
            ))}
          </div>
        </fieldset>

        <div>
          <label className="label-warm" htmlFor="assistant-micronutrient">Micronutrientes prioritários</label>
          <div className="flex gap-2">
            <input
              id="assistant-micronutrient"
              className="input-warm !py-2"
              disabled={disabled}
              value={micronutrient}
              onChange={(event) => setMicronutrient(event.target.value)}
              onKeyDown={(event) => { if (event.key === 'Enter') { event.preventDefault(); addMicronutrient() } }}
              placeholder="Ex.: Ferro"
            />
            <button type="button" className="btn-ghost shrink-0" disabled={disabled} onClick={addMicronutrient}>Adicionar</button>
          </div>
          <div className="mt-2 flex flex-wrap gap-1.5">
            {assistant.priorityMicronutrients.length === 0 && <p className="text-xs text-muted-foreground">Nenhum micronutriente prioritário informado.</p>}
            {assistant.priorityMicronutrients.map((item) => (
              <button
                key={item}
                type="button"
                disabled={disabled}
                className="chip text-forest-600 hover:border-destructive/40 hover:text-destructive"
                onClick={() => setAssistant((current) => ({ ...current, priorityMicronutrients: current.priorityMicronutrients.filter((entry) => entry !== item) }))}
              >
                {item} ×
              </button>
            ))}
          </div>
        </div>

        <div className="space-y-2 border-t border-border pt-4">
          <button type="button" className="btn-ghost w-full" disabled={disabled} onClick={syncSteps}>
            Confirmar objetivo, metas e refeições
          </button>
          <button
            type="button"
            className="btn-ghost w-full"
            disabled={disabled || assistant.completedSteps.includes('equivalents')}
            onClick={confirmEquivalents}
          >
            {assistant.completedSteps.includes('equivalents') ? 'Equivalentes revisados' : 'Confirmo que revisei os equivalentes'}
          </button>
        </div>
      </div>
    </section>
  )
}
