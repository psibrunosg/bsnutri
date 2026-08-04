import { totalDay } from './nutrition'
import type { EditorDay } from './planDrafts'

const macroLine = (energyKcal: number, proteinG: number, carbohydrateG: number, fatG: number) =>
  `${energyKcal.toLocaleString('pt-BR')} kcal · P ${proteinG.toLocaleString('pt-BR')} g · C ${carbohydrateG.toLocaleString('pt-BR')} g · G ${fatG.toLocaleString('pt-BR')} g`

export function formatPlanForExport(title: string, days: EditorDay[], targets: Record<string, number>): string {
  const dayBlocks = days.map(day => {
    const mealLines = day.meals.map(meal => {
      const itemLines = meal.items.map(item => `    ${item.name} - ${item.grams.toLocaleString('pt-BR')} g`).join('\n')
      return `  ${meal.name}\n${itemLines || '    (sem itens)'}`
    }).join('\n')
    const totals = totalDay(day.meals)
    return `${day.label}\n${mealLines}\n  Total do dia: ${macroLine(totals.energyKcal, totals.proteinG, totals.carbohydrateG, totals.fatG)}`
  }).join('\n\n')

  const targetsLine = `Metas: ${macroLine(targets.energyKcal ?? 0, targets.proteinG ?? 0, targets.carbohydrateG ?? 0, targets.fatG ?? 0)}`

  return `${title}\n\n${dayBlocks}\n\n${targetsLine}`
}
