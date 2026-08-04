import { readFileSync, writeFileSync, mkdirSync } from 'node:fs'
import { fileURLToPath } from 'node:url'
import { dirname, join } from 'node:path'

const root = join(dirname(fileURLToPath(import.meta.url)), '..')
const srcPath = join(root, 'docs', 'seed', 'modelos-plano-dietbox.json')
const migrationPath = join(root, 'supabase', 'migrations', '20260804000000_plan_template_dietbox_seed.sql')

const MACRO_KEYS = {
  energyKcal: 'calorias',
  proteinG: 'proteinas',
  carbohydrateG: 'carboidratos',
  fatG: 'gorduras',
  fiberG: 'fibras',
  sodiumMg: 'sodio',
  calciumMg: 'calcio',
  ironMg: 'ferro',
  potassiumMg: 'potassio',
}

const r2 = (n) => Math.round((n + Number.EPSILON) * 100) / 100
const r1 = (n) => Math.round((n + Number.EPSILON) * 10) / 10
const num = (v) => (typeof v === 'number' && Number.isFinite(v) ? v : 0)

function normalizeName(raw) {
  let s = raw
  s = s.replace(/\([^)]*dietbox[^)]*\)/gi, '')
  s = s.replace(/\(seu modelo de card[áa]pio\)/gi, '')
  s = s.replace(/\(importado\)/gi, '')
  s = s.replace(/\(duplicado\)/gi, '')
  s = s.replace(/\s+/g, ' ').trim()
  s = s.replace(/\b(anti|pr[ée]|p[óo]s|centro)\s+-\s+(?=[A-Za-zÀ-ÿ])/gi, '$1-')
  s = s.replace(/(\S)-\s+/g, '$1 - ')
  s = s.replace(/\s+-\s+/g, ' - ')
  s = s.replace(/\s*-\s+-\s*/g, ' - ')
  s = s.replace(/(\d)%PTN/gi, '$1% PTN')
  s = s.replace(/(\d)kcal/gi, '$1 kcal')
  s = s.replace(/\bbrasil\b/gi, 'Brasil')
  s = s.replace(/\bnordeste\b/gi, 'Nordeste')
  s = s.replace(/\bsudeste\b/gi, 'Sudeste')
  s = s.replace(/\bcentro-oeste\b/gi, 'Centro-Oeste')
  s = s.replace(/\bsul\b/gi, 'Sul')
  s = s.replace(/^\s*[-–]\s*/, '').replace(/\s*[-–]\s*$/, '')
  s = s.replace(/\s+/g, ' ').trim()
  return s
}

function parseKcal(name) {
  const m = name.match(/(\d[\d.,]*)\s*kcal/i)
  if (!m) return null
  return Math.round(Number(m[1].replace(/\./g, '').replace(',', '.')))
}

function parsePtnPct(name) {
  const m = name.match(/(\d+)\s*%\s*ptn/i)
  return m ? `${m[1]}% ptn` : null
}

const APPROACH_RULES = [
  [/\bmediterr[áâa]ne[oa]\b/i, 'mediterranean'],
  [/\bdash\b/i, 'dash'],
  [/cetog[êe]nic/i, 'ketogenic'],
  [/\blow carb\b/i, 'low_carb'],
  [/\bvegana\b/i, 'vegan'],
  [/ovolactovegetarian/i, 'vegetarian'],
  [/paleo/i, 'paleo'],
  [/anti-inflamat[óo]ria/i, 'anti_inflammatory'],
  [/jejum intermitente/i, 'intermittent_fasting'],
  [/enteral/i, 'enteral'],
  [/carga glic[êe]mica/i, 'glycemic_load'],
]

const OBJECTIVE_RULES = [
  [/diab[iíé]t|tipo 2/i, 'glycemic_control'],
  [/hipoglic[êe]mica|jejum intermitente/i, 'glycemic_control'],
  [/hipertens/i, 'hypertension'],
  [/insufici[êe]ncia renal|renal/i, 'renal'],
  [/gestante/i, 'gestational'],
  [/hipertrofia/i, 'hypertrophy'],
  [/hipercolesterolemia|hipertrigliceridemia/i, 'dyslipidemia'],
  [/menopausa/i, 'menopause'],
  [/crian[çc]as|beb[êe]s/i, 'pediatric'],
  [/introdu[çc][ãa]o alimentar/i, 'pediatric'],
  [/idosos/i, 'elderly'],
  [/constipa[çc][ãa]o|refluxo|pancreatite|diverticulite|crohn/i, 'gastrointestinal'],
  [/ácid[oú] ?[úu]rico/i, 'gout'],
  [/alergia a prote[íi]na/i, 'food_allergy'],
  [/degluti[çc][ãa]o/i, 'swallowing'],
  [/cirurgia pl[áa]stica|pr[ée]-operat[óo]rio|p[óo]s-operat[óo]rio/i, 'perioperative'],
  [/celulite|lipedema/i, 'aesthetic'],
  [/hipocal[óo]rica/i, 'weight_loss'],
  [/hiperproteica/i, 'high_protein'],
]

const RESTRICTION_RULES = [
  [/\bsem gl[úu]ten\b/i, 'gluten_free'],
  [/\bsem lactose\b/i, 'lactose_free'],
  [/sem frutose|fodmap/i, 'low_fodmap'],
  [/restri[çc][ãa]o de fibras|restri[çc][ãa]o de res[íi]duos/i, 'low_fiber_low_residue'],
  [/\bvegana\b/i, 'vegan'],
  [/ovolactovegetarian/i, 'no_meat'],
  [/renal/i, 'renal'],
  [/enteral/i, 'enteral'],
  [/cetog[êe]nica/i, 'very_low_carb'],
  [/paleo/i, 'no_grains'],
]

const OBJECTIVE_LABELS = {
  glycemic_control: 'controle glicêmico',
  hypertension: 'controle pressórico',
  renal: 'terapia nutricional renal',
  gestational: 'gestação',
  hypertrophy: 'hipertrofia',
  dyslipidemia: 'controle lipídico',
  menopause: 'menopausa',
  pediatric: 'nutrição pediátrica',
  elderly: 'nutrição do idoso',
  gastrointestinal: 'conforto gastrointestinal',
  gout: 'controle de ácido úrico',
  food_allergy: 'alergia alimentar',
  swallowing: 'dificuldade de deglutição',
  perioperative: 'período perioperatório',
  aesthetic: 'objetivo estético',
  weight_loss: 'perda de peso',
  high_protein: 'plano hiperproteico',
}

function derive(name) {
  const approaches = []
  const objectives = []
  const restrictions = []
  for (const [re, tag] of APPROACH_RULES) if (re.test(name) && !approaches.includes(tag)) approaches.push(tag)
  for (const [re, tag] of OBJECTIVE_RULES) if (re.test(name) && !objectives.includes(tag)) objectives.push(tag)
  for (const [re, tag] of RESTRICTION_RULES) if (re.test(name) && !restrictions.includes(tag)) restrictions.push(tag)
  const objective = objectives.length
    ? `Cardápio clínico para ${objectives.map((o) => OBJECTIVE_LABELS[o] ?? o).join(' e ')} — adaptar à avaliação nutricional do paciente.`
    : 'Cardápio pronto para adaptação clínica profissional no BSNutri.'
  return { dimensions: { approaches, objectives, restrictions, preferences: [], contexts: ['outpatient'] }, objective }
}

function macrosFor(alimento) {
  const base = num(alimento?.quantidadeBaseGrama) > 0 ? num(alimento?.quantidadeBaseGrama) : 100
  const out = {}
  for (const [key, src] of Object.entries(MACRO_KEYS)) out[key] = r2((num(alimento?.[src]) * 100) / base)
  return out
}

function splitMeasure(descricao) {
  const m = descricao.match(/^(.+?)\s+\((.+)\)\s*$/)
  return m ? [m[1].trim(), m[2].trim()] : [descricao.trim(), null]
}

function itemToSnapshot(item) {
  const [food, measure] = splitMeasure(item.descricao)
  const grams = num(item.quantidade) > 0 ? item.quantidade : num(item.medidaCaseiraQtd)
  const out = { food, grams: r2(grams), macros: macrosFor(item.alimento) }
  if (measure) out.measure = measure
  const subs = (Array.isArray(item.substituicoes) ? item.substituicoes : []).map((s) => {
    const [sFood, sMeasure] = splitMeasure(s.Description ?? s.Name ?? s.IbgeDescription ?? '')
    const subGrams = num(s.HomemadeMeasureQuantityInGrams) > 0 ? s.HomemadeMeasureQuantityInGrams : num(s.Quantity)
    const sub = { food: sFood, grams: r2(subGrams) }
    if (sMeasure) sub.measure = sMeasure
    sub.macros = {
      energyKcal: r2(num(s.Calories)),
      proteinG: r2(num(s.ProteinInGrams)),
      carbohydrateG: r2(num(s.CarbohydrateInGrams)),
      fatG: r2(num(s.FatInGrams)),
      fiberG: r2(num(s.Fiber)),
      sodiumMg: r2(num(s.Sodium)),
      calciumMg: r2(num(s.Calcium)),
      ironMg: r2(num(s.Iron)),
      potassiumMg: r2(num(s.Potassium)),
    }
    return sub
  })
  if (subs.length) out.subs = subs
  return out
}

function modelToSnapshot(model) {
  const meals = model.refeicoes.map((refeicao) => {
    const meal = { name: refeicao.descricao, items: refeicao.itens.map(itemToSnapshot) }
    if (refeicao.horario) meal.time = refeicao.horario
    if (refeicao.observacao) meal.notes = refeicao.observacao
    return meal
  })
  const summary = {}
  for (const key of Object.keys(MACRO_KEYS)) summary[key] = 0
  for (const meal of meals)
    for (const item of meal.items)
      for (const key of Object.keys(summary)) summary[key] += num(item.macros[key]) * item.grams / 100
  for (const key of Object.keys(summary)) summary[key] = r1(summary[key])
  return {
    dietboxId: model.id,
    originalName: model.descricao,
    kcalTotal: Math.round(summary.energyKcal),
    summary,
    meals,
  }
}

function tagsFor(name, approaches) {
  const tags = []
  const kcal = parseKcal(name)
  const ptn = parsePtnPct(name)
  if (kcal) tags.push(`${kcal} kcal`)
  if (ptn) tags.push(ptn)
  for (const a of approaches) if (!tags.includes(a)) tags.push(a)
  return tags
}

function buildModel(model) {
  const name = normalizeName(model.descricao)
  const { dimensions, objective } = derive(name)
  const snapshot = modelToSnapshot(model)
  const nameKcal = parseKcal(name)
  const rules = {
    targets: { energyKcal: nameKcal ?? snapshot.kcalTotal },
    guidance: ['Cardápio de referência — revisar e adaptar à avaliação nutricional do paciente antes de publicar.'],
  }
  return { name, objective, tags: tagsFor(name, dimensions.approaches), snapshot, dimensions, rules }
}

const source = JSON.parse(readFileSync(srcPath, 'utf8'))
const rawAll = [...source.meusModelos, ...source.modelosDietbox]

const normalized = rawAll.map((m) => ({ ...m, descricao: normalizeName(m.descricao) }))

const seen = new Map()
const dropped = []
const unique = []
for (const m of normalized) {
  if (seen.has(m.descricao)) { dropped.push({ descricao: m.descricao, id: m.id }); continue }
  seen.set(m.descricao, true)
  unique.push(m)
}

const models = unique.map(buildModel)

// Normalized seed file (preserves original field set, deduped, BSNutri names)
const meusIds = new Set(source.meusModelos.map((m) => m.id))
const dedupedMeus = unique.filter((m) => meusIds.has(m.id))
const dedupedDietbox = unique.filter((m) => !meusIds.has(m.id))
const estatisticas = {
  meusModelosCount: dedupedMeus.length,
  modelosDietboxCount: dedupedDietbox.length,
  totalCount: unique.length,
  fonteOriginal: 'Dietbox (nomes normalizados para o vocabulário BSNutri)',
}
writeFileSync(srcPath, JSON.stringify({ estatisticas, meusModelos: dedupedMeus, modelosDietbox: dedupedDietbox }, null, 2) + '\n', 'utf8')

// Migration SQL
const CHUNK = 25
const chunks = []
for (let i = 0; i < models.length; i += CHUNK) chunks.push(models.slice(i, i + CHUNK))

const dataChunk = (chunk) => {
  const json = JSON.stringify(chunk).replaceAll('$data$', '$dat_a$')
  return `  for model in select jsonb_array_elements($data$${json}$data$::jsonb) loop\n` +
    `    insert into public.plan_templates (organization_id, name, objective, tags, snapshot, created_by, scope, dimensions, rules)\n` +
    `    values (target_organization_id, model->>'name', model->>'objective', (select array(select jsonb_array_elements_text(model->'tags'))), model->'snapshot', actor, 'organization', model->'dimensions', model->'rules')\n` +
    `    on conflict (organization_id, (snapshot->>'dietboxId')) where snapshot ? 'dietboxId' do update set\n` +
    `      name = excluded.name, objective = excluded.objective, tags = excluded.tags, snapshot = excluded.snapshot,\n` +
    `      dimensions = excluded.dimensions, rules = excluded.rules, updated_at = now();\n  end loop;`
}

const sql = `-- Importa ${models.length} modelos de cardápio convertidos de Dietbox (docs/seed/modelos-plano-dietbox.json),
-- com nomes normalizados para o vocabulário BSNutri (sem marca de terceiros) e estrutura completa das
-- refeições preservada em snapshot. Idempotente via unique index (organization_id, (snapshot->>'dietboxId')).
-- Revisão clínica obrigatória antes de qualquer uso (ver docs/nutrition-data-policy.md).

create unique index if not exists plan_templates_org_dietbox_id_key
  on public.plan_templates (organization_id, (snapshot->>'dietboxId'))
  where snapshot ? 'dietboxId';

create or replace function public.seed_plan_templates_dietbox(
  target_organization_id uuid,
  target_created_by uuid default null
)
returns void
language plpgsql
security definer
set search_path = ''
as $fn$
declare
  actor uuid := coalesce(auth.uid(), target_created_by);
  model jsonb;
begin
  if auth.uid() is not null and not private.has_organization_role(target_organization_id, array['owner','admin','nutritionist','student']::public.organization_role[]) then
    raise exception 'Acesso negado';
  end if;
  if actor is null then
    raise exception 'created_by obrigatório';
  end if;

${chunks.map(dataChunk).join('\n\n')}
end;
$fn$;

revoke all on function public.seed_plan_templates_dietbox(uuid, uuid) from public, anon;
grant execute on function public.seed_plan_templates_dietbox(uuid, uuid) to authenticated;

-- Backfill: clínicas já existentes recebem os modelos imediatamente.
do $backfill$
declare r record;
begin
  for r in select id, created_by from public.organizations loop
    perform public.seed_plan_templates_dietbox(r.id, r.created_by);
  end loop;
end;
$backfill$;
`

mkdirSync(join(root, 'supabase', 'migrations'), { recursive: true })
writeFileSync(migrationPath, sql, 'utf8')

console.log('source models:', rawAll.length)
console.log('dropped duplicates:', dropped.length)
for (const d of dropped) console.log('  -', d.descricao, `(id ${d.id})`)
console.log('unique models:', models.length)
console.log('normalized seed:', srcPath)
console.log('migration:', migrationPath, `(${(sql.length / 1024).toFixed(0)} KB)`)
