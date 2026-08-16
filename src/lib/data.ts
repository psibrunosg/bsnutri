import type { Food, PlanTemplate, WeekPlan } from "./types";
import { emptyWeekPlan, WEEK_DAYS } from "./types";

const SEED_FOODS: Food[] = [
  { id: "f01", name: "Ovos mexidos", group: "Proteínas", unit: "2 unidades", grams: 100, kcal: 155, protein: 13, carbs: 1, fat: 11 },
  { id: "f02", name: "Peito de frango grelhado", group: "Proteínas", unit: "1 filé (100g)", grams: 100, kcal: 165, protein: 31, carbs: 0, fat: 3.6 },
  { id: "f03", name: "Carne magra (patinho)", group: "Proteínas", unit: "1 porção (100g)", grams: 100, kcal: 170, protein: 29, carbs: 0, fat: 6 },
  { id: "f04", name: "Salmão grelhado", group: "Proteínas", unit: "1 filé (100g)", grams: 100, kcal: 208, protein: 20, carbs: 0, fat: 13 },
  { id: "f05", name: "Iogurte natural integral", group: "Laticínios", unit: "1 pote (170g)", grams: 170, kcal: 105, protein: 6, carbs: 8, fat: 5.5 },
  { id: "f06", name: "Queijo minas frescal", group: "Laticínios", unit: "2 fatias (50g)", grams: 50, kcal: 132, protein: 9, carbs: 1.5, fat: 10 },
  { id: "f07", name: "Whey protein", group: "Proteínas", unit: "1 scoop (30g)", grams: 30, kcal: 120, protein: 24, carbs: 3, fat: 1.5 },
  { id: "f08", name: "Arroz branco cozido", group: "Carboidratos", unit: "4 col. sopa (100g)", grams: 100, kcal: 130, protein: 2.7, carbs: 28, fat: 0.3 },
  { id: "f09", name: "Arroz integral cozido", group: "Carboidratos", unit: "4 col. sopa (100g)", grams: 100, kcal: 112, protein: 2.6, carbs: 23, fat: 0.9 },
  { id: "f10", name: "Feijão carioca", group: "Carboidratos", unit: "1 concha (100g)", grams: 100, kcal: 76, protein: 4.8, carbs: 13.6, fat: 0.5 },
  { id: "f11", name: "Batata-doce cozida", group: "Carboidratos", unit: "1 unid. média (130g)", grams: 130, kcal: 112, protein: 2, carbs: 26, fat: 0.1 },
  { id: "f12", name: "Aveia em flocos", group: "Carboidratos", unit: "3 col. sopa (30g)", grams: 30, kcal: 117, protein: 4.2, carbs: 20, fat: 2.1 },
  { id: "f13", name: "Pão francês integral", group: "Carboidratos", unit: "1 unidade (50g)", grams: 50, kcal: 120, protein: 5, carbs: 23, fat: 1.5 },
  { id: "f14", name: "Tapioca", group: "Carboidratos", unit: "1 disco (70g goma)", grams: 70, kcal: 150, protein: 0.3, carbs: 37, fat: 0.1 },
  { id: "f15", name: "Macarrão cozido", group: "Carboidratos", unit: "1 pegador (100g)", grams: 100, kcal: 158, protein: 5.8, carbs: 31, fat: 0.9 },
  { id: "f16", name: "Banana prata", group: "Frutas", unit: "1 unidade", grams: 100, kcal: 89, protein: 1.1, carbs: 23, fat: 0.3 },
  { id: "f17", name: "Maçã fuji", group: "Frutas", unit: "1 unidade", grams: 130, kcal: 68, protein: 0.3, carbs: 18, fat: 0.2 },
  { id: "f18", name: "Mamão papaia", group: "Frutas", unit: "1/2 unid. (150g)", grams: 150, kcal: 60, protein: 0.7, carbs: 15, fat: 0.2 },
  { id: "f19", name: "Morangos", group: "Frutas", unit: "10 unid. (150g)", grams: 150, kcal: 48, protein: 1, carbs: 11, fat: 0.4 },
  { id: "f20", name: "Abacate", group: "Gorduras boas", unit: "1/2 unid. (100g)", grams: 100, kcal: 160, protein: 2, carbs: 9, fat: 15 },
  { id: "f21", name: "Azeite extra virgem", group: "Gorduras boas", unit: "1 col. sopa (10ml)", grams: 10, kcal: 90, protein: 0, carbs: 0, fat: 10 },
  { id: "f22", name: "Castanha-do-pará", group: "Gorduras boas", unit: "4 unidades (20g)", grams: 20, kcal: 131, protein: 2.9, carbs: 2.4, fat: 13 },
  { id: "f23", name: "Pasta de amendoim", group: "Gorduras boas", unit: "1 col. sopa (15g)", grams: 15, kcal: 90, protein: 3.8, carbs: 3, fat: 7.5 },
  { id: "f24", name: "Salada de folhas (alface, rúcula)", group: "Vegetais", unit: "1 prato (80g)", grams: 80, kcal: 14, protein: 1.2, carbs: 2.2, fat: 0.2 },
  { id: "f25", name: "Brócolis cozido", group: "Vegetais", unit: "5 ramos (100g)", grams: 100, kcal: 35, protein: 2.4, carbs: 7, fat: 0.4 },
  { id: "f26", name: "Legumes salteados", group: "Vegetais", unit: "1 porção (120g)", grams: 120, kcal: 48, protein: 2, carbs: 9, fat: 0.5 },
  { id: "f27", name: "Suco de laranja natural", group: "Frutas", unit: "1 copo (250ml)", grams: 250, kcal: 112, protein: 1.7, carbs: 26, fat: 0.5 },
  { id: "f28", name: "Café com leite desnatado", group: "Laticínios", unit: "1 xícara (200ml)", grams: 200, kcal: 66, protein: 6, carbs: 9, fat: 0.4 },
  { id: "f29", name: "Granola sem açúcar", group: "Carboidratos", unit: "2 col. sopa (25g)", grams: 25, kcal: 110, protein: 2.5, carbs: 16, fat: 4 },
  { id: "f30", name: "Omelete de queijo e espinafre", group: "Proteínas", unit: "1 porção (120g)", grams: 120, kcal: 190, protein: 15, carbs: 2, fat: 13 },
];

export const FOODS: Food[] = SEED_FOODS;

export const FOOD_GROUPS = [...new Set(FOODS.map((f) => f.group))];

function buildTemplatePlan(map: Record<string, Record<string, string[]>>): WeekPlan {
  const p = emptyWeekPlan();
  for (const d of WEEK_DAYS) {
    for (const meal of Object.keys(p[d])) {
      const items = map[meal]?.[d] ?? map[meal]?.["*"] ?? [];
      p[d][meal] = items.map((id) => ({ foodId: id, qty: 1 }));
    }
  }
  return p;
}

const lowCarbPlan = buildTemplatePlan({
  "Café da manhã": { "*": ["f01", "f20"] },
  "Lanche da manhã": { "*": ["f05", "f19"] },
  "Almoço": { "*": ["f02", "f24", "f25", "f21"] },
  "Lanche da tarde": { "*": ["f22"] },
  "Jantar": { "*": ["f04", "f26", "f24"] },
  "Ceia": { "*": ["f05"] },
});

const equilibradoPlan = buildTemplatePlan({
  "Café da manhã": { "*": ["f13", "f06", "f17", "f28"] },
  "Lanche da manhã": { "*": ["f16"] },
  "Almoço": { "*": ["f09", "f10", "f03", "f24", "f26"] },
  "Lanche da tarde": { "*": ["f05", "f29"] },
  "Jantar": { "*": ["f02", "f11", "f25", "f21"] },
  "Ceia": { "*": ["f28"] },
});

const hipercaloricoPlan = buildTemplatePlan({
  "Café da manhã": { "*": ["f12", "f16", "f23", "f28"] },
  "Lanche da manhã": { "*": ["f13", "f06", "f07"] },
  "Almoço": { "*": ["f08", "f10", "f03", "f24", "f21"] },
  "Lanche da tarde": { "*": ["f14", "f16", "f23"] },
  "Jantar": { "*": ["f15", "f02", "f26", "f21"] },
  "Ceia": { "*": ["f05", "f29"] },
});

const LOCAL_TEMPLATES: PlanTemplate[] = [
  {
    id: "t1",
    name: "Low Carb · Definição",
    description: "Ênfase em proteínas e gorduras boas, carboidratos reduzidos. Indicado para recomposição corporal.",
    kcalTarget: 1600,
    tags: ["low carb", "definição", "adulto"],
    color: "#4a6741",
    plan: lowCarbPlan,
  },
  {
    id: "t2",
    name: "Equilibrado · Manutenção",
    description: "Distribuição clássica 45/30/25 com alimentos do dia a dia brasileiro. Fácil adesão.",
    kcalTarget: 2000,
    tags: ["manutenção", "brasileiro", "família"],
    color: "#d9a44a",
    plan: equilibradoPlan,
  },
  {
    id: "t3",
    name: "Hipercalórico · Ganho de massa",
    description: "Superávit moderado com carboidratos estratégicos e proteína distribuída em 6 refeições.",
    kcalTarget: 2600,
    tags: ["hipertrofia", "ganho de peso"],
    color: "#85591d",
    plan: hipercaloricoPlan,
  },
];

export const TEMPLATES: PlanTemplate[] = LOCAL_TEMPLATES;
