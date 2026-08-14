// Stub local — o catálogo real é gerado no build por scripts/sync-catalog.mjs
import type { Food, PlanTemplate, WeekPlan, MealType } from "./types";
import { WEEK_DAYS } from "./types";

export interface SlimTemplate { id: string; name: string; description: string; kcalTarget: number | null; tags: string[]; hasMenu: boolean; dayPlan: Record<string, { foodId: string; qty: number }[]> | null }
export const DB_TEMPLATES: SlimTemplate[] = [];
export const DB_FOODS: Food[] = [];
export interface EquivList { id: string; title: string; group: string | null; targetKcal: number | null; description: string; items: { description: string; grams: number | null; measure: string | null; kcal: number | null }[] }
export const DB_EQUIV: EquivList[] = [];

export function expandTemplate(t: SlimTemplate): PlanTemplate {
  const plan: WeekPlan = {};
  for (const d of WEEK_DAYS) {
    plan[d] = {};
    for (const m of Object.keys(t.dayPlan ?? {})) plan[d][m as MealType] = (t.dayPlan?.[m] ?? []).map((i) => ({ ...i }));
  }
  return { id: t.id, name: t.name, description: t.description, kcalTarget: t.kcalTarget ?? 0, tags: t.tags, color: "#4a6741", plan };
}
