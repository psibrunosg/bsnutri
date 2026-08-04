import { describe, expect, it } from 'vitest'
import { buildShoppingList } from './shoppingList'
import type { EditorDay } from './planDrafts'

const emptyNutrientsForTest = { energyKcal: 0, proteinG: 0, carbohydrateG: 0, fatG: 0, fiberG: 0, sodiumMg: 0, calciumMg: 0, ironMg: 0, potassiumMg: 0, vitaminCMg: 0 }

const day = (label: string, items: { name: string; grams: number }[]): EditorDay => ({
  id: `day-${label}`,
  label,
  kind: 'standard',
  meals: [{
    id: `meal-${label}`,
    name: 'Refeição',
    items: items.map((item, index) => ({
      id: `item-${label}-${index}`,
      name: item.name,
      grams: item.grams,
      nutrientsPer100g: emptyNutrientsForTest,
    })),
  }],
})

describe('buildShoppingList', () => {
  it('soma gramas do mesmo alimento entre dias e refeições diferentes', () => {
    const days: EditorDay[] = [
      day('1', [{ name: 'Arroz', grams: 150 }, { name: 'Feijão', grams: 80 }]),
      day('2', [{ name: 'Arroz', grams: 100 }]),
    ]
    expect(buildShoppingList(days)).toEqual([
      { name: 'Arroz', grams: 250 },
      { name: 'Feijão', grams: 80 },
    ])
  })

  it('ordena por nome em pt-BR', () => {
    const days: EditorDay[] = [day('1', [{ name: 'Ovo', grams: 50 }, { name: 'Abacate', grams: 100 }])]
    expect(buildShoppingList(days).map(item => item.name)).toEqual(['Abacate', 'Ovo'])
  })

  it('retorna lista vazia quando não há itens', () => {
    const days: EditorDay[] = [day('1', [])]
    expect(buildShoppingList(days)).toEqual([])
  })
})
