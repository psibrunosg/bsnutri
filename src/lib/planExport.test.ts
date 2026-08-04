import { describe, expect, it } from 'vitest'
import { formatPlanForExport } from './planExport'
import type { EditorDay } from './planDrafts'
import { emptyNutrients } from './nutrition'

const days: EditorDay[] = [{
  id: 'day-1',
  label: 'Dia 1',
  kind: 'standard',
  meals: [{
    id: 'meal-1',
    name: 'Café da manhã',
    items: [{
      id: 'item-1',
      name: 'Arroz',
      grams: 150,
      nutrientsPer100g: { ...emptyNutrients(), energyKcal: 130, proteinG: 2.5, carbohydrateG: 28, fatG: 0.3 },
    }],
  }],
}]

describe('formatPlanForExport', () => {
  it('inclui título, dias, refeições, itens e totais do dia', () => {
    const text = formatPlanForExport('Plano teste', days, { energyKcal: 2000, proteinG: 100, carbohydrateG: 220, fatG: 70 })
    expect(text).toContain('Plano teste')
    expect(text).toContain('Dia 1')
    expect(text).toContain('Café da manhã')
    expect(text).toContain('Arroz - 150 g')
    expect(text).toContain('Total do dia: 195 kcal · P 3,75 g · C 42 g · G 0,45 g')
    expect(text).toContain('Metas: 2.000 kcal · P 100 g · C 220 g · G 70 g')
  })

  it('marca refeição sem itens', () => {
    const emptyMealDays: EditorDay[] = [{ id: 'day-1', label: 'Dia 1', kind: 'standard', meals: [{ id: 'meal-1', name: 'Jantar', items: [] }] }]
    const text = formatPlanForExport('Plano vazio', emptyMealDays, {})
    expect(text).toContain('(sem itens)')
  })
})
