export const nutrientKeys = [
  'energyKcal',
  'proteinG',
  'carbohydrateG',
  'fatG',
  'fiberG',
  'sodiumMg',
  'calciumMg',
  'ironMg',
  'potassiumMg',
  'vitaminCMg',
] as const

export type NutrientKey = (typeof nutrientKeys)[number]
export type Nutrients = Record<NutrientKey, number>
export type NutrientTargets = Partial<Nutrients>

export interface FoodPortion {
  id: string
  name: string
  grams: number
  nutrientsPer100g: Nutrients
}

export interface Meal {
  id: string
  name: string
  items: FoodPortion[]
}

export interface MealTotal extends Meal {
  nutrients: Nutrients
}

export interface TargetProgress {
  consumed: number
  target: number
  percentage: number
  remaining: number
}

export type NutrientProgress = Partial<Record<NutrientKey, TargetProgress>>

export const emptyNutrients = (): Nutrients => ({
  energyKcal: 0,
  proteinG: 0,
  carbohydrateG: 0,
  fatG: 0,
  fiberG: 0,
  sodiumMg: 0,
  calciumMg: 0,
  ironMg: 0,
  potassiumMg: 0,
  vitaminCMg: 0,
})

/** Decimal rounding independent from the host locale. */
export function roundNutrition(value: number, decimals = 2): number {
  assertFinite(value, 'value')
  if (!Number.isInteger(decimals) || decimals < 0 || decimals > 10) {
    throw new RangeError('decimals must be an integer between 0 and 10')
  }
  const factor = 10 ** decimals
  return Math.round((value + Number.EPSILON) * factor) / factor
}

export function nutrientsForPortion(
  nutrientsPer100g: Nutrients,
  grams: number,
  decimals = 2,
): Nutrients {
  assertNonNegative(grams, 'grams')
  const factor = grams / 100
  return mapNutrients((key) => {
    assertNonNegative(nutrientsPer100g[key], key)
    return roundNutrition(nutrientsPer100g[key] * factor, decimals)
  })
}

export function totalFoodPortion(item: FoodPortion, decimals = 2): Nutrients {
  return nutrientsForPortion(item.nutrientsPer100g, item.grams, decimals)
}

export function sumNutrients(values: readonly Nutrients[], decimals = 2): Nutrients {
  return mapNutrients((key) =>
    roundNutrition(values.reduce((sum, value) => {
      assertFinite(value[key], key)
      return sum + value[key]
    }, 0), decimals),
  )
}

export function totalMeal(meal: Meal, decimals = 2): MealTotal {
  return {
    ...meal,
    nutrients: sumNutrients(meal.items.map((item) => totalFoodPortion(item, decimals)), decimals),
  }
}

export function totalDay(meals: readonly Meal[], decimals = 2): Nutrients {
  return sumNutrients(meals.map((meal) => totalMeal(meal, decimals).nutrients), decimals)
}

export function calculateTargetProgress(
  consumed: Nutrients,
  targets: NutrientTargets,
  decimals = 2,
): NutrientProgress {
  const progress: NutrientProgress = {}
  for (const key of nutrientKeys) {
    const target = targets[key]
    if (target === undefined) continue
    assertNonNegative(target, `target.${key}`)
    assertNonNegative(consumed[key], `consumed.${key}`)
    progress[key] = {
      consumed: roundNutrition(consumed[key], decimals),
      target: roundNutrition(target, decimals),
      percentage: target === 0 ? 0 : roundNutrition((consumed[key] / target) * 100, decimals),
      remaining: roundNutrition(target - consumed[key], decimals),
    }
  }
  return progress
}

function mapNutrients(mapper: (key: NutrientKey) => number): Nutrients {
  return Object.fromEntries(nutrientKeys.map((key) => [key, mapper(key)])) as Nutrients
}

function assertFinite(value: number, label: string): void {
  if (!Number.isFinite(value)) throw new RangeError(`${label} must be finite`)
}

function assertNonNegative(value: number, label: string): void {
  assertFinite(value, label)
  if (value < 0) throw new RangeError(`${label} must not be negative`)
}
