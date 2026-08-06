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

  it('formata lista de trocas de equivalência calórica vinculada à refeição', () => {
    const daysWithEq: EditorDay[] = [{
      id: 'day-1',
      label: 'Dia 1',
      kind: 'standard',
      meals: [{
        id: 'meal-1',
        name: 'Almoço',
        items: [],
        equivalencyListId: 'eq-carb',
      }],
    }]
    const equivalencyLists = [{
      id: 'eq-carb',
      title: 'Grupo dos Carboidratos (~100 kcal)',
      macroGroup: 'carbohydrate',
      targetCalories: 100,
      calorieTolerancePct: 15,
      isActive: true,
      items: [
        { id: '1', equivalencyListId: 'eq-carb', description: 'Arroz integral', grams: 80, householdMeasure: '3 colheres', caloriesPerPortion: 99, position: 0 },
        { id: '2', equivalencyListId: 'eq-carb', description: 'Batata doce', grams: 115, householdMeasure: null, caloriesPerPortion: 98, position: 1 },
      ],
    }]
    const text = formatPlanForExport('Plano com trocas', daysWithEq, {}, equivalencyLists)
    expect(text).toContain('[Opções de Troca por Equivalência · Grupo dos Carboidratos (~100 kcal) (±15%)]')
    expect(text).toContain('• Arroz integral - 80 g (3 colheres) · ~99 kcal')
    expect(text).toContain('• Batata doce - 115 g · ~98 kcal')
  })
})
