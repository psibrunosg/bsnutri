import { describe, expect, it, vi } from 'vitest'
import { exportPublishedPlanPdf, type PublishedPlanDocument } from './pdf'
import { emptyNutrients } from './nutrition'
import type { EditorDay } from './planDrafts'

const WEEK = ['Segunda-feira', 'Terça-feira', 'Quarta-feira', 'Quinta-feira', 'Sexta-feira', 'Sábado', 'Domingo']

function day(label: string, meals: number, itemsPerMeal: number): EditorDay {
  return {
    id: `day-${label}`,
    label,
    kind: 'standard',
    meals: Array.from({ length: meals }, (_, mealIndex) => ({
      id: `meal-${label}-${mealIndex}`,
      name: `Refeição ${mealIndex + 1}`,
      items: Array.from({ length: itemsPerMeal }, (_, itemIndex) => ({
        id: `item-${label}-${mealIndex}-${itemIndex}`,
        name: `Alimento ${itemIndex + 1}`,
        grams: 100,
        nutrientsPer100g: { ...emptyNutrients(), energyKcal: 120, proteinG: 8 },
      })),
    })),
  }
}

function document(overrides: Partial<PublishedPlanDocument> = {}): PublishedPlanDocument {
  return {
    patientName: 'Bruno de Souza',
    planTitle: 'Plano alimentar',
    version: 1,
    days: [day('Segunda-feira', 2, 2)],
    substitutions: [],
    ...overrides,
  }
}

describe('exportPublishedPlanPdf', () => {
  it('gera o documento de um dia sem lançar erro', async () => {
    const save = vi.fn()
    vi.spyOn(await import('jspdf'), 'jsPDF')
    await expect(exportPublishedPlanPdf(document())).resolves.toBeUndefined()
    expect(save).not.toHaveBeenCalled()
  })

  it('gera a semana inteira, que é o caso real do plano publicado', async () => {
    const days = WEEK.map((label) => day(label, 6, 4))
    await expect(exportPublishedPlanPdf(document({ days }))).resolves.toBeUndefined()
  })

  it('gera o documento com substituições prescritas', async () => {
    await expect(exportPublishedPlanPdf(document({
      substitutions: [{ originalName: 'Aveia', options: ['Granola', 'Tapioca'] }],
    }))).resolves.toBeUndefined()
  })
})
