import { describe, expect, it } from 'vitest'
import { buildPublishedPlanPdf, publishedPlanFileName, type PublishedPlanDocument } from './pdf'
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
    await expect(buildPublishedPlanPdf(document())).resolves.toBeTruthy()
  })

  it('gera a semana inteira, que é o caso real do plano publicado', async () => {
    const days = WEEK.map((label) => day(label, 6, 4))
    await expect(buildPublishedPlanPdf(document({ days }))).resolves.toBeTruthy()
  })

  it('gera o documento com substituições prescritas', async () => {
    await expect(buildPublishedPlanPdf(document({
      substitutions: [{ originalName: 'Aveia', options: ['Granola', 'Tapioca'] }],
    }))).resolves.toBeTruthy()
  })

  it('gera nome de arquivo seguro a partir do nome do paciente', () => {
    expect(publishedPlanFileName('Bruno de Souza Gonçalves')).toBe('plano-alimentar-bruno-de-souza-goncalves.pdf')
    expect(publishedPlanFileName('   ')).toBe('plano-alimentar-paciente.pdf')
  })
})
