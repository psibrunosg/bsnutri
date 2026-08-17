import type { CatalogFoodSummary } from './catalogSearch'
import type { ParsedDietboxMeal } from './dietboxImport'
import type { Meal } from './nutrition'
import type { EditorDay } from './planDrafts'
import { portionFromCatalogFood } from './usePlanDraft'

export interface PendingSubstitution {
  mealIndex: number
  itemIndex: number
  food: CatalogFoodSummary
  grams: number
}

export interface DietboxGroupHint {
  mealName: string
  groupNo: number
  matchedListTitle: string | null
}

export interface DietboxImportReport {
  importedItems: number
  skippedSlots: { mealName: string; rawName: string }[]
  droppedAlternatives: { mealName: string; rawName: string }[]
}

export interface BuildImportedDayResult {
  day: EditorDay
  pendingSubstitutions: PendingSubstitution[]
  report: DietboxImportReport
  groupHints: DietboxGroupHint[]
}

/**
 * Monta o dia importado a partir das refeições parseadas do Dietbox. O item principal de
 * cada slot vira um item da refeição; as alternativas resolvidas viram substituições
 * pendentes (gravadas depois de salvar, quando o item ganha um id real do banco).
 *
 * `equivalencyListId` só é preenchido quando a refeição tem um único slot cujo grupo
 * resolve a exatamente uma lista — com mais de um slot por refeição não há como saber a
 * qual item o grupo se refere, então o vínculo fica de fora e vira só uma dica textual
 * (`groupHints`) para o profissional resolver manualmente.
 */
export function buildImportedDay(
  baseDay: EditorDay,
  parsedMeals: ParsedDietboxMeal[],
  resolveFood: (rawName: string) => CatalogFoodSummary | null,
  resolveEquivalencyList: (groupNo: number) => { id: string; title: string } | null,
): BuildImportedDayResult {
  const pendingSubstitutions: PendingSubstitution[] = []
  const skippedSlots: DietboxImportReport['skippedSlots'] = []
  const droppedAlternatives: DietboxImportReport['droppedAlternatives'] = []
  const groupHints: DietboxGroupHint[] = []
  let importedItems = 0

  const meals: Meal[] = parsedMeals.map((parsedMeal, mealIndex) => {
    const items: Meal['items'] = []
    for (const slot of parsedMeal.slots) {
      if (slot.dietboxGroupNo !== null) {
        const match = resolveEquivalencyList(slot.dietboxGroupNo)
        groupHints.push({ mealName: parsedMeal.name, groupNo: slot.dietboxGroupNo, matchedListTitle: match?.title ?? null })
      }

      const primaryFood = resolveFood(slot.primary.rawName)
      if (!primaryFood) {
        skippedSlots.push({ mealName: parsedMeal.name, rawName: slot.primary.rawName })
        continue
      }
      const itemIndex = items.length
      items.push(portionFromCatalogFood(primaryFood, slot.primary.grams))
      importedItems += 1

      for (const alternative of slot.alternatives) {
        const alternativeFood = resolveFood(alternative.rawName)
        if (!alternativeFood) {
          droppedAlternatives.push({ mealName: parsedMeal.name, rawName: alternative.rawName })
          continue
        }
        pendingSubstitutions.push({ mealIndex, itemIndex, food: alternativeFood, grams: alternative.grams })
      }
    }

    const singleGroupNo = parsedMeal.slots.length === 1 ? parsedMeal.slots[0].dietboxGroupNo : null
    const equivalencyListId = singleGroupNo !== null ? (resolveEquivalencyList(singleGroupNo)?.id ?? undefined) : undefined

    return {
      id: crypto.randomUUID(),
      name: parsedMeal.name,
      items,
      notes: parsedMeal.notes ?? undefined,
      equivalencyListId,
    }
  })

  return {
    day: { ...baseDay, meals },
    pendingSubstitutions,
    report: { importedItems, skippedSlots, droppedAlternatives },
    groupHints,
  }
}
