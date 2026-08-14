// Sincroniza o catálogo real do Supabase para src/lib/realdata.ts antes do build.
// Roda no CI (GitHub Actions) com secrets: SUPABASE_PROF_EMAIL / SUPABASE_PROF_PASSWORD
// Sem secrets, mantém o arquivo atual (stub local) e segue o build.
import { createClient } from '@supabase/supabase-js'
import { writeFileSync } from 'node:fs'

const url = process.env.VITE_SUPABASE_URL
const anon = process.env.VITE_SUPABASE_ANON_KEY
const email = process.env.SUPABASE_PROF_EMAIL
const password = process.env.SUPABASE_PROF_PASSWORD

if (!url || !anon || !email || !password) {
  console.log('[sync-catalog] secrets ausentes — usando catálogo local (stub).')
  process.exit(0)
}

// Node 20 não tem WebSocket nativo (CI usa Node 22); stub evita init do realtime, que não usamos.
if (typeof globalThis.WebSocket === 'undefined') {
  // @ts-expect-error stub mínimo
  globalThis.WebSocket = class { addEventListener() {} removeEventListener() {} send() {} close() {} }
}
const supabase = createClient(url, anon)
const { error } = await supabase.auth.signInWithPassword({ email, password })
if (error) {
  console.warn('[sync-catalog] login falhou:', error.message, '— mantendo stub.')
  process.exit(0)
}

const all = async (table, select) => {
  const out = []
  let from = 0
  for (;;) {
    const { data, error: e } = await supabase.from(table).select(select).range(from, from + 999)
    if (e) throw new Error(table + ': ' + e.message)
    out.push(...data)
    if (data.length < 1000) break
    from += 1000
  }
  return out
}

const [foods, fnv, nutrients, templates, equiv, equivItems] = await Promise.all([
  all('foods', 'id,name,preparation_state,catalog_kind,household_measure_label,household_measure_grams,serving_grams,diet_tags,is_active'),
  all('food_nutrient_values', 'food_id,nutrient_id,amount_per_100g'),
  all('nutrients', 'id,code'),
  all('plan_templates', 'id,name,objective,tags,scope,dimensions,rules,snapshot'),
  all('equivalency_lists', '*'),
  all('equivalency_list_items', '*'),
])
console.log(`[sync-catalog] foods=${foods.length} fnv=${fnv.length} templates=${templates.length}`)

const nutById = Object.fromEntries(nutrients.map((n) => [n.id, n.code]))
const nutmap = {}
for (const r of fnv) {
  const c = nutById[r.nutrient_id]
  if (!c) continue
  ;(nutmap[r.food_id] ??= {})[c] = r.amount_per_100g
}

const slug = (s) => s.normalize('NFKD').replace(/[̀-ͯ]/g, '').toLowerCase().replace(/[^a-z0-9]+/g, '-').replace(/^-|-$/g, '')

const GROUPS = [
  ['Proteínas', ['frango','carne','peixe','salm','atum','ovo','whey','protein','camar','porco','lombo','patinho','tilapia','sardinha','peru','peito']],
  ['Laticínios', ['leite','queijo','iogurte','requeij','coalhada','manteiga','ricota','cottage']],
  ['Carboidratos', ['arroz','feij','macarr','pao','batata','mandioca','aveia','tapioca','cuscuz','milho','granola','cereal','lentilha','grao-de-bico','ervilha','quinoa','farinha','polenta','inhame','aipim']],
  ['Frutas', ['banana','maca','mamao','morango','laranja','uva','manga','abacaxi','pera','melancia','melao','kiwi','mexerica','acerola','goiaba','pessego','ameixa','fruta']],
  ['Vegetais', ['alface','rucula','brocolis','cenoura','tomate','abobrinha','legume','salada','espinafre','couve','pepino','beterraba','repolho','vagem','abobora','chuchu','berinjela']],
  ['Gorduras boas', ['azeite','abacate','castanha','amendoim','amendoa','nozes','semente','pasta-de','oleo','chia','linhaca']],
  ['Bebidas e outros', ['suco','cafe','cha','agua','refrigerante']],
]
const groupOf = (name) => {
  const n = slug(name)
  for (const [g, kws] of GROUPS) if (kws.some((k) => n.includes(k))) return g
  return 'Outros'
}

const r1 = (v) => Math.round(v * 10) / 10
const outFoods = []
for (const f of foods) {
  if (!f.is_active) continue
  const nm = nutmap[f.id] || {}
  if (nm.energy_kcal == null) continue
  const grams = f.household_measure_grams || f.serving_grams || 100
  const factor = grams / 100
  const prep = f.preparation_state && f.preparation_state !== 'in natura' ? ` (${f.preparation_state})` : ''
  outFoods.push({
    id: 'db-' + f.id, name: f.name + prep, group: groupOf(f.name),
    unit: f.household_measure_label || '100 g', grams: Math.round(grams),
    kcal: Math.round(nm.energy_kcal * factor), protein: r1((nm.protein_g || 0) * factor),
    carbs: r1((nm.carbohydrate_g || 0) * factor), fat: r1((nm.fat_g || 0) * factor),
    tags: f.diet_tags || [],
  })
}
// dedup catálogo
const seen = new Set()
const foodsD = []
for (const f of outFoods) {
  const k = slug(f.name) + '|' + f.unit
  if (seen.has(k)) continue
  seen.add(k); foodsD.push(f)
}

const MEAL_ORDER = ['Café da manhã','Lanche da manhã','Almoço','Lanche da tarde','Jantar','Ceia']
const extraFoods = []
const dedup = new Map()
const findFoodId = (name) => {
  const n = slug(name.replace(/\(.*?\)/g, '').trim())
  let best = null
  for (const f of foodsD) {
    const fn = slug(f.name.replace(/\(.*?\)/g, '').trim())
    if (fn === n) return f.id
    if ((n.includes(fn) || fn.includes(n)) && !best) best = f.id
  }
  return best
}
const mealTarget = (name, i) => {
  const mn = slug(name || '')
  if (mn.includes('cafe') && mn.includes('manha')) return 'Café da manhã'
  if (mn.includes('tarde') && mn.includes('lanche')) return 'Lanche da tarde'
  if (mn.includes('lanche')) return 'Lanche da manhã'
  if (mn.includes('almoco')) return 'Almoço'
  if (mn.includes('jantar')) return 'Jantar'
  if (mn.includes('ceia')) return 'Ceia'
  return MEAL_ORDER[Math.min(i, 5)]
}

const outTemplates = []
for (const t of templates) {
  const meals = (t.snapshot && t.snapshot.meals) || []
  const dayPlan = {}
  for (const m of MEAL_ORDER) dayPlan[m] = []
  let total = 0
  meals.forEach((meal, i) => {
    const target = mealTarget(meal.name, i)
    for (const it of meal.items || []) {
      const fname = (it.food || '').trim()
      if (!fname) continue
      const grams = it.grams || 100
      const macros = it.macros || {}
      const fid = findFoodId(fname)
      if (fid) {
        const bf = foodsD.find((x) => x.id === fid)
        const qty = Math.max(1, Math.round(grams / Math.max(bf.grams, 1)))
        dayPlan[target].push({ foodId: fid, qty })
        total += bf.kcal * qty
      } else {
        const key = slug(fname.replace(/\(.*?\)/g, '').trim()) + '|' + grams
        let eid = dedup.get(key)
        if (!eid) {
          eid = 'tx-' + slug(fname).slice(0, 36) + '-' + extraFoods.length
          const kcal = Math.round(((macros.energyKcal || 0) * grams) / 100)
          extraFoods.push({ id: eid, name: fname, group: groupOf(fname), unit: it.measure || `${Math.round(grams)} g`, grams: Math.round(grams), kcal, protein: r1(((macros.proteinG || 0) * grams) / 100), carbs: r1(((macros.carbohydrateG || 0) * grams) / 100), fat: r1(((macros.fatG || 0) * grams) / 100), tags: [] })
          dedup.set(key, eid)
        }
        dayPlan[target].push({ foodId: eid, qty: 1 })
        total += extraFoods.find((x) => x.id === eid).kcal
      }
    }
  })
  outTemplates.push({ id: 'db-' + t.id, name: t.name, description: t.objective || '', kcalTarget: total || null, tags: t.tags || [], hasMenu: meals.length > 0, dayPlan: meals.length ? dayPlan : null })
}

const itemsByList = {}
for (const it of equivItems) (itemsByList[it.equivalency_list_id] ??= []).push(it)
const outEquiv = equiv.map((l) => ({
  id: 'db-' + l.id, title: l.title, group: l.macro_group || null, targetKcal: l.target_calories || null, description: l.description || '',
  items: (itemsByList[l.id] || []).sort((a, b) => a.position - b.position).map((i) => ({ description: i.description, grams: i.grams ?? null, measure: i.household_measure ?? null, kcal: i.calories_per_portion ?? null })),
}))

const J = (x) => JSON.stringify(x)
const content = `// Dados reais sincronizados do Supabase no build (scripts/sync-catalog.mjs)
import type { Food, PlanTemplate, WeekPlan, MealType } from "./types";
import { WEEK_DAYS } from "./types";

export interface SlimTemplate { id: string; name: string; description: string; kcalTarget: number | null; tags: string[]; hasMenu: boolean; dayPlan: Record<string, { foodId: string; qty: number }[]> | null }
export const DB_TEMPLATES: SlimTemplate[] = ${J(outTemplates)};

export const DB_FOODS: Food[] = ${J([...foodsD, ...extraFoods])};

export interface EquivList { id: string; title: string; group: string | null; targetKcal: number | null; description: string; items: { description: string; grams: number | null; measure: string | null; kcal: number | null }[] }
export const DB_EQUIV: EquivList[] = ${J(outEquiv)};

export function expandTemplate(t: SlimTemplate): PlanTemplate {
  const plan: WeekPlan = {};
  for (const d of WEEK_DAYS) {
    plan[d] = {};
    for (const m of Object.keys(t.dayPlan ?? {})) plan[d][m as MealType] = (t.dayPlan?.[m] ?? []).map((i) => ({ ...i }));
  }
  return { id: t.id, name: t.name, description: t.description, kcalTarget: t.kcalTarget ?? 0, tags: t.tags, color: "#4a6741", plan };
}
`
writeFileSync('src/lib/realdata.ts', content)
console.log('[sync-catalog] realdata.ts atualizado:', Math.round(content.length / 1024) + 'KB')
