import type { EditorDay } from './planDrafts'

export type ShoppingListItem = { name: string; grams: number }

export function buildShoppingList(days: EditorDay[]): ShoppingListItem[] {
  const totals = new Map<string, number>()
  for (const day of days) {
    for (const meal of day.meals) {
      for (const item of meal.items) {
        totals.set(item.name, (totals.get(item.name) ?? 0) + item.grams)
      }
    }
  }
  return [...totals.entries()]
    .map(([name, grams]) => ({ name, grams: Math.round(grams * 100) / 100 }))
    .sort((a, b) => a.name.localeCompare(b.name, 'pt-BR'))
}
