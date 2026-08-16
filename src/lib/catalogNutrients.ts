import type { NutrientKey } from './nutrition'

export const macroKeys: NutrientKey[] = ['energyKcal', 'proteinG', 'carbohydrateG', 'fatG']
export const lipidKeys: NutrientKey[] = ['saturatedFatG', 'monounsaturatedFatG', 'polyunsaturatedFatG', 'transFatG']
export const vitaminKeys: NutrientKey[] = ['vitaminCMg', 'vitaminB1Mg', 'vitaminB2Mg', 'vitaminB3Mg', 'vitaminB6Mg', 'vitaminB9Mcg', 'vitaminB12Mcg']
export const mineralKeys: NutrientKey[] = ['sodiumMg', 'calciumMg', 'ironMg', 'potassiumMg', 'fiberG']

export const macroLabels: Record<NutrientKey, string> = {
  energyKcal: 'Energia',
  proteinG: 'Proteína',
  carbohydrateG: 'Carboidrato',
  fatG: 'Gordura',
  fiberG: 'Fibra',
  sodiumMg: 'Sódio',
  calciumMg: 'Cálcio',
  ironMg: 'Ferro',
  potassiumMg: 'Potássio',
  vitaminCMg: 'Vitamina C',
  saturatedFatG: 'Gordura saturada',
  monounsaturatedFatG: 'Gordura monoinsaturada',
  polyunsaturatedFatG: 'Gordura poli-insaturada',
  transFatG: 'Gordura trans',
  vitaminB1Mg: 'Vitamina B1 (tiamina)',
  vitaminB2Mg: 'Vitamina B2 (riboflavina)',
  vitaminB3Mg: 'Vitamina B3 (niacina)',
  vitaminB6Mg: 'Vitamina B6 (piridoxina)',
  vitaminB9Mcg: 'Vitamina B9 (folato)',
  vitaminB12Mcg: 'Vitamina B12 (cobalamina)',
}
