export interface Food {
  id: string;
  name: string;
  group: string;
  unit: string; // medida caseira
  grams: number; // gramas por unidade
  kcal: number; // por unidade
  protein: number;
  carbs: number;
  fat: number;
  tags?: string[];
}

export type MealType = "Café da manhã" | "Lanche da manhã" | "Almoço" | "Lanche da tarde" | "Jantar" | "Ceia";

export const MEAL_TYPES: MealType[] = [
  "Café da manhã",
  "Lanche da manhã",
  "Almoço",
  "Lanche da tarde",
  "Jantar",
  "Ceia",
];

export const WEEK_DAYS = ["Segunda", "Terça", "Quarta", "Quinta", "Sexta", "Sábado", "Domingo"] as const;
export type WeekDay = (typeof WEEK_DAYS)[number];

export interface PlanItem {
  foodId: string;
  qty: number; // quantidade de unidades
}

// plan[day][meal] = items
export type WeekPlan = Record<string, Record<string, PlanItem[]>>;

export interface AnthropometryRecord {
  date: string; // ISO
  weight: number; // kg
  height: number; // cm
  waist?: number; // cm
  hip?: number; // cm
  neck?: number;
  arm?: number;
  thigh?: number;
  bodyFat?: number; // %
  triceps?: number; // dobras mm
  subscapular?: number;
  suprailiac?: number;
  abdominal?: number;
}

export interface Patient {
  id: string;
  name: string;
  email: string;
  phone: string;
  birthDate: string;
  sex: "F" | "M" | "Outro";
  goal: string;
  notes: string;
  tags: string[];
  createdAt: string;
  measurements: AnthropometryRecord[];
}

export interface PlanTemplate {
  id: string;
  name: string;
  description: string;
  kcalTarget: number;
  tags: string[];
  color: string; // tailwind-ish hex
  plan: WeekPlan;
}

export interface PatientPlan {
  id: string;
  patientId: string;
  name: string;
  templateId?: string;
  createdAt: string;
  status: "rascunho" | "publicado";
  plan: WeekPlan;
  notes: string;
}

export function emptyWeekPlan(): WeekPlan {
  const p: WeekPlan = {};
  for (const d of WEEK_DAYS) {
    p[d] = {};
    for (const m of MEAL_TYPES) p[d][m] = [];
  }
  return p;
}

export function imc(weight: number, heightCm: number): number {
  const h = heightCm / 100;
  return h > 0 ? weight / (h * h) : 0;
}

export function imcCategory(v: number): { label: string; color: string } {
  if (v <= 0) return { label: "—", color: "#7a7568" };
  if (v < 18.5) return { label: "Abaixo do peso", color: "#c98f2f" };
  if (v < 25) return { label: "Eutrofia", color: "#4a6741" };
  if (v < 30) return { label: "Sobrepeso", color: "#c98f2f" };
  if (v < 35) return { label: "Obesidade I", color: "#b35c33" };
  return { label: "Obesidade II+", color: "#a03a2a" };
}

export function planTotals(plan: WeekPlan, foods: Food[]): { kcal: number; protein: number; carbs: number; fat: number } {
  let kcal = 0, protein = 0, carbs = 0, fat = 0;
  for (const d of Object.keys(plan)) {
    for (const m of Object.keys(plan[d])) {
      for (const it of plan[d][m]) {
        const f = foods.find((x) => x.id === it.foodId);
        if (!f) continue;
        kcal += f.kcal * it.qty;
        protein += f.protein * it.qty;
        carbs += f.carbs * it.qty;
        fat += f.fat * it.qty;
      }
    }
  }
  const days = WEEK_DAYS.length;
  return { kcal: Math.round(kcal / days), protein: Math.round(protein / days), carbs: Math.round(carbs / days), fat: Math.round(fat / days) };
}

export function dayTotals(plan: WeekPlan, day: string, foods: Food[]) {
  let kcal = 0, protein = 0, carbs = 0, fat = 0;
  for (const m of Object.keys(plan[day] ?? {})) {
    for (const it of plan[day][m]) {
      const f = foods.find((x) => x.id === it.foodId);
      if (!f) continue;
      kcal += f.kcal * it.qty;
      protein += f.protein * it.qty;
      carbs += f.carbs * it.qty;
      fat += f.fat * it.qty;
    }
  }
  return { kcal: Math.round(kcal), protein: Math.round(protein), carbs: Math.round(carbs), fat: Math.round(fat) };
}
