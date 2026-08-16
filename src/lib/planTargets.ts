import type { NutritionalEstimateRow } from '../types'

export type PlanObjective = 'weight_loss' | 'maintenance' | 'weight_gain'

export interface TargetSuggestionInput {
  /** Gasto energético total estimado, em kcal/dia. */
  totalEnergyExpenditure: number
  weightKg: number
  objective: PlanObjective
}

export interface TargetSuggestion {
  energyKcal: number
  proteinG: number
  carbohydrateG: number
  fatG: number
  fiberG: number
  waterMl: number
}

/**
 * Referências das heurísticas, todas de uso corrente na prática clínica:
 * - déficit/superávit de 15% sobre o GET;
 * - proteína por peso corporal, mais alta em emagrecimento para preservar massa magra;
 * - gordura em 27% do valor energético;
 * - carboidrato pelo restante das calorias;
 * - fibra a 14 g por 1000 kcal (Institute of Medicine);
 * - água a 35 ml por kg de peso.
 *
 * São ponto de partida para o profissional revisar, nunca prescrição automática.
 */
const ENERGY_FACTOR: Record<PlanObjective, number> = {
  weight_loss: 0.85,
  maintenance: 1,
  weight_gain: 1.15,
}

const PROTEIN_PER_KG: Record<PlanObjective, number> = {
  weight_loss: 1.8,
  maintenance: 1.4,
  weight_gain: 1.7,
}

const FAT_ENERGY_SHARE = 0.27
const FIBER_PER_1000_KCAL = 14
const WATER_ML_PER_KG = 35

function round(value: number, step = 1): number {
  return Math.round(value / step) * step
}

export function suggestTargets(input: TargetSuggestionInput): TargetSuggestion | null {
  const { totalEnergyExpenditure, weightKg, objective } = input
  if (!Number.isFinite(totalEnergyExpenditure) || totalEnergyExpenditure <= 0) return null
  if (!Number.isFinite(weightKg) || weightKg <= 0) return null

  const energyKcal = round(totalEnergyExpenditure * ENERGY_FACTOR[objective], 10)
  const proteinG = round(weightKg * PROTEIN_PER_KG[objective])
  const fatG = round((energyKcal * FAT_ENERGY_SHARE) / 9)
  const remainingKcal = energyKcal - proteinG * 4 - fatG * 9
  const carbohydrateG = Math.max(0, round(remainingKcal / 4))
  const fiberG = round((energyKcal / 1000) * FIBER_PER_1000_KCAL)
  const waterMl = round(weightKg * WATER_ML_PER_KG, 50)

  return { energyKcal, proteinG, carbohydrateG, fatG, fiberG, waterMl }
}

const OBJECTIVE_PATTERNS: [PlanObjective, RegExp][] = [
  ['weight_loss', /emagrec|perda de peso|redu[çc][ãa]o de peso|d[ée]ficit/i],
  ['weight_gain', /ganho de (peso|massa)|hipertrofia|super[áa]vit/i],
]

/** Lê o objetivo já registrado na avaliação; sem correspondência clara, mantém manutenção. */
export function objectiveFromText(text: string | null | undefined): PlanObjective {
  if (!text) return 'maintenance'
  for (const [objective, pattern] of OBJECTIVE_PATTERNS) {
    if (pattern.test(text)) return objective
  }
  return 'maintenance'
}

export function suggestTargetsForPatient(
  estimate: Pick<NutritionalEstimateRow, 'total_energy_expenditure' | 'current_weight_kg'> | null,
  objectiveText: string | null | undefined,
): TargetSuggestion | null {
  if (!estimate) return null
  return suggestTargets({
    totalEnergyExpenditure: Number(estimate.total_energy_expenditure),
    weightKg: Number(estimate.current_weight_kg),
    objective: objectiveFromText(objectiveText),
  })
}

export function isTargetSetEmpty(targets: Record<string, number>): boolean {
  return ['energyKcal', 'proteinG', 'carbohydrateG', 'fatG', 'fiberG', 'waterMl']
    .every((key) => !Number.isFinite(targets[key]) || targets[key] <= 0)
}
