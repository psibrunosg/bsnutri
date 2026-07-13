import { describe, expect, it } from 'vitest'
import {
  calculateTargetProgress,
  emptyNutrients,
  nutrientsForPortion,
  roundNutrition,
  sumNutrients,
  totalDay,
  totalMeal,
  type FoodPortion,
  type Meal,
  type Nutrients,
} from './nutrition'

const rice100g: Nutrients = {
  ...emptyNutrients(),
  energyKcal: 128,
  proteinG: 2.5,
  carbohydrateG: 28.1,
  fatG: 0.2,
  fiberG: 1.6,
  sodiumMg: 1,
}

const rice = (grams: number): FoodPortion => ({
  id: `rice-${grams}`,
  name: 'Arroz cozido',
  grams,
  nutrientsPer100g: rice100g,
})

describe('nutrition engine', () => {
  it('calculates nutrients for a portion in grams', () => {
    expect(nutrientsForPortion(rice100g, 150)).toMatchObject({
      energyKcal: 192,
      proteinG: 3.75,
      carbohydrateG: 42.15,
      fiberG: 2.4,
    })
  })

  it('totals an item, a meal and a day', () => {
    const lunch: Meal = { id: 'lunch', name: 'Almoço', items: [rice(150), rice(50)] }
    const dinner: Meal = { id: 'dinner', name: 'Jantar', items: [rice(100)] }

    expect(totalMeal(lunch).nutrients.energyKcal).toBe(256)
    expect(totalDay([lunch, dinner])).toMatchObject({ energyKcal: 384, carbohydrateG: 84.3 })
  })

  it('sums nutrient sets and rounds deterministically', () => {
    const a = { ...emptyNutrients(), proteinG: 0.105 }
    const b = { ...emptyNutrients(), proteinG: 0.105 }
    expect(roundNutrition(1.005)).toBe(1.01)
    expect(sumNutrients([a, b]).proteinG).toBe(0.21)
  })

  it('calculates target percentages and preserves surplus as negative remaining', () => {
    const consumed = { ...emptyNutrients(), energyKcal: 2200, proteinG: 80 }
    const progress = calculateTargetProgress(consumed, { energyKcal: 2000, proteinG: 100 })
    expect(progress.energyKcal).toEqual({ consumed: 2200, target: 2000, percentage: 110, remaining: -200 })
    expect(progress.proteinG?.percentage).toBe(80)
    expect(progress.fiberG).toBeUndefined()
  })

  it('rejects invalid quantities and treats a zero target explicitly', () => {
    expect(() => nutrientsForPortion(rice100g, -1)).toThrow('grams must not be negative')
    expect(calculateTargetProgress(emptyNutrients(), { sodiumMg: 0 }).sodiumMg?.percentage).toBe(0)
  })
})
