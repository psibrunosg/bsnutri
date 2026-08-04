# Fase 0 — Vitórias Rápidas do Nutrition Workspace Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Dar ao plano alimentar do BSNutri as três saídas que faltam hoje — impressão/PDF do plano, lista de compras agregada, e proteína/carboidrato/gordura em g/kg de peso corporal — sem tocar em schema de banco, todas derivadas de dados já existentes.

**Architecture:** Três funções puras novas em `src/lib` (uma por capacidade: export de texto, lista de compras, cálculo g/kg), mais uma função pura adicionada a um arquivo existente (`gramsPerKg` em `nutrition.ts`), e uma task final de integração que conecta as quatro no `NutritionWorkspace.tsx` via novo estado local e um efeito que busca o peso mais recente do paciente em `anthropometry`.

**Tech Stack:** React + TypeScript, Vitest + Testing Library (padrão já usado no projeto), Supabase client já configurado em `src/lib/supabase.ts`.

## Global Constraints

- Todo texto de UI em português do Brasil (pt-BR), mesmo padrão do resto do arquivo.
- Todo número exibido em UI usa `.toLocaleString('pt-BR')` — sem exceção, é o padrão já usado em `NutritionWorkspace.tsx`.
- Nenhuma dependência nova — `package.json` não muda.
- Nenhuma migration de banco nesta fase — tudo deriva de `days[].meals[].items[]` (já em memória) ou da tabela `anthropometry` (já existe, já usada em `PatientDetail.tsx`).
- Segue o padrão de mock de teste já existente em `src/NutritionWorkspace.ui.test.tsx` (`fromMock` + helper `queryResult` com `.select/.eq/.or/.order/.upsert`) — não introduzir um helper de mock novo nem adicionar `.limit`/`.maybeSingle` ao mock; a query nova usa `.order()` e lê `data[0]`, igual ao padrão já usado em `PatientDetail.tsx` para "medida mais recente".
- Não altera comportamento de nenhuma funcionalidade existente do `NutritionWorkspace.tsx` — só adiciona.
- `npx tsc -b`, `npx vitest run`, `npx oxlint src` devem passar limpos ao final de cada task.

---

## File Structure

- **Create** `src/lib/shoppingList.ts` — agrega gramas por alimento em todos os dias/refeições de um plano.
- **Create** `src/lib/shoppingList.test.ts`
- **Create** `src/lib/planExport.ts` — formata um plano (dias, refeições, itens, totais, metas) como texto plano pronto pra `printClinicalDocument`.
- **Create** `src/lib/planExport.test.ts`
- **Modify** `src/lib/nutrition.ts` — adiciona `gramsPerKg(grams, weightKg)`.
- **Modify** `src/lib/nutrition.test.ts` — testa `gramsPerKg`.
- **Modify** `src/NutritionWorkspace.tsx` — liga as três funções acima: botão "Imprimir plano", painel "Lista de compras", coluna g/kg nos totais.
- **Modify** `src/NutritionWorkspace.ui.test.tsx` — cobre as três funcionalidades novas.

---

### Task 1: Lista de compras agregada (`shoppingList.ts`)

**Files:**
- Create: `src/lib/shoppingList.ts`
- Create: `src/lib/shoppingList.test.ts`

**Interfaces:**
- Consumes: `EditorDay` de `./planDrafts` (já existe: `{ id, label, kind, meals: Meal[] }`, onde `Meal = { id, name, items: FoodPortion[] }` e `FoodPortion` tem `{ id, name, grams, nutrientsPer100g, foodId?, hasReviewedSubstitution? }`, ambos de `./nutrition`).
- Produces: `export type ShoppingListItem = { name: string; grams: number }` e `export function buildShoppingList(days: EditorDay[]): ShoppingListItem[]` — usado pela Task 4.

- [ ] **Step 1: Escrever o teste que falha**

Criar `src/lib/shoppingList.test.ts`:

```ts
import { describe, expect, it } from 'vitest'
import { buildShoppingList } from './shoppingList'
import type { EditorDay } from './planDrafts'

const emptyNutrientsForTest = { energyKcal: 0, proteinG: 0, carbohydrateG: 0, fatG: 0, fiberG: 0, sodiumMg: 0, calciumMg: 0, ironMg: 0, potassiumMg: 0, vitaminCMg: 0 }

const day = (label: string, items: { name: string; grams: number }[]): EditorDay => ({
  id: `day-${label}`,
  label,
  kind: 'standard',
  meals: [{
    id: `meal-${label}`,
    name: 'Refeição',
    items: items.map((item, index) => ({
      id: `item-${label}-${index}`,
      name: item.name,
      grams: item.grams,
      nutrientsPer100g: emptyNutrientsForTest,
    })),
  }],
})

describe('buildShoppingList', () => {
  it('soma gramas do mesmo alimento entre dias e refeições diferentes', () => {
    const days: EditorDay[] = [
      day('1', [{ name: 'Arroz', grams: 150 }, { name: 'Feijão', grams: 80 }]),
      day('2', [{ name: 'Arroz', grams: 100 }]),
    ]
    expect(buildShoppingList(days)).toEqual([
      { name: 'Arroz', grams: 250 },
      { name: 'Feijão', grams: 80 },
    ])
  })

  it('ordena por nome em pt-BR', () => {
    const days: EditorDay[] = [day('1', [{ name: 'Ovo', grams: 50 }, { name: 'Abacate', grams: 100 }])]
    expect(buildShoppingList(days).map(item => item.name)).toEqual(['Abacate', 'Ovo'])
  })

  it('retorna lista vazia quando não há itens', () => {
    const days: EditorDay[] = [day('1', [])]
    expect(buildShoppingList(days)).toEqual([])
  })
})
```

- [ ] **Step 2: Rodar o teste e confirmar que falha**

Run: `npx vitest run src/lib/shoppingList.test.ts`
Expected: FAIL — `Cannot find module './shoppingList'` (o arquivo ainda não existe).

- [ ] **Step 3: Implementar**

Criar `src/lib/shoppingList.ts`:

```ts
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
```

- [ ] **Step 4: Rodar o teste e confirmar que passa**

Run: `npx vitest run src/lib/shoppingList.test.ts`
Expected: PASS (3/3)

- [ ] **Step 5: Checar tipos e lint**

Run: `npx tsc -b && npx oxlint src/lib/shoppingList.ts src/lib/shoppingList.test.ts`
Expected: sem erros

- [ ] **Step 6: Commit**

```bash
git add src/lib/shoppingList.ts src/lib/shoppingList.test.ts
git commit -m "feat: add shopping list aggregation from plan days"
```

---

### Task 2: Formatação do plano pra impressão/PDF (`planExport.ts`)

**Files:**
- Create: `src/lib/planExport.ts`
- Create: `src/lib/planExport.test.ts`

**Interfaces:**
- Consumes: `totalDay` e `emptyNutrients` de `./nutrition` (já existem); `EditorDay` de `./planDrafts` (já existe, ver Task 1).
- Produces: `export function formatPlanForExport(title: string, days: EditorDay[], targets: Record<string, number>): string` — usado pela Task 4 junto com `printClinicalDocument` (já existe em `./clinicalExport`, assinatura `printClinicalDocument(title: string, subtitle: string, body: string): boolean`).

- [ ] **Step 1: Escrever o teste que falha**

Criar `src/lib/planExport.test.ts`:

```ts
import { describe, expect, it } from 'vitest'
import { formatPlanForExport } from './planExport'
import type { EditorDay } from './planDrafts'
import { emptyNutrients } from './nutrition'

const days: EditorDay[] = [{
  id: 'day-1',
  label: 'Dia 1',
  kind: 'standard',
  meals: [{
    id: 'meal-1',
    name: 'Café da manhã',
    items: [{
      id: 'item-1',
      name: 'Arroz',
      grams: 150,
      nutrientsPer100g: { ...emptyNutrients(), energyKcal: 130, proteinG: 2.5, carbohydrateG: 28, fatG: 0.3 },
    }],
  }],
}]

describe('formatPlanForExport', () => {
  it('inclui título, dias, refeições, itens e totais do dia', () => {
    const text = formatPlanForExport('Plano teste', days, { energyKcal: 2000, proteinG: 100, carbohydrateG: 220, fatG: 70 })
    expect(text).toContain('Plano teste')
    expect(text).toContain('Dia 1')
    expect(text).toContain('Café da manhã')
    expect(text).toContain('Arroz - 150 g')
    expect(text).toContain('Total do dia: 195 kcal · P 3,75 g · C 42 g · G 0,45 g')
    expect(text).toContain('Metas: 2.000 kcal · P 100 g · C 220 g · G 70 g')
  })

  it('marca refeição sem itens', () => {
    const emptyMealDays: EditorDay[] = [{ id: 'day-1', label: 'Dia 1', kind: 'standard', meals: [{ id: 'meal-1', name: 'Jantar', items: [] }] }]
    const text = formatPlanForExport('Plano vazio', emptyMealDays, {})
    expect(text).toContain('(sem itens)')
  })
})
```

- [ ] **Step 2: Rodar o teste e confirmar que falha**

Run: `npx vitest run src/lib/planExport.test.ts`
Expected: FAIL — `Cannot find module './planExport'`

- [ ] **Step 3: Implementar**

Criar `src/lib/planExport.ts`:

```ts
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
```

- [ ] **Step 4: Rodar o teste e confirmar que passa**

Run: `npx vitest run src/lib/planExport.test.ts`
Expected: PASS (2/2)

- [ ] **Step 5: Checar tipos e lint**

Run: `npx tsc -b && npx oxlint src/lib/planExport.ts src/lib/planExport.test.ts`
Expected: sem erros

- [ ] **Step 6: Commit**

```bash
git add src/lib/planExport.ts src/lib/planExport.test.ts
git commit -m "feat: add plain-text plan formatter for print/PDF export"
```

---

### Task 3: `gramsPerKg` em `nutrition.ts`

**Files:**
- Modify: `src/lib/nutrition.ts` (adicionar função nova após `roundNutrition`, linhas 60-68 do arquivo atual)
- Modify: `src/lib/nutrition.test.ts` (adicionar import e novo bloco `describe`)

**Interfaces:**
- Consumes: `roundNutrition` (já existe no mesmo arquivo).
- Produces: `export function gramsPerKg(grams: number, weightKg: number | null): number | null` — usado pela Task 4.

- [ ] **Step 1: Escrever o teste que falha**

Em `src/lib/nutrition.test.ts`, o import no topo do arquivo hoje é:

```ts
import {
  calculateTargetProgress,
  emptyNutrients,
  nutrientsForPortion,
  roundNutrition,
  sumNutrients,
  totalDay,
  totalMeal,
  type FoodPortion,
  type Meal,
  type Nutrients,
} from './nutrition'
```

Trocar por (adiciona `gramsPerKg` em ordem alfabética):

```ts
import {
  calculateTargetProgress,
  emptyNutrients,
  gramsPerKg,
  nutrientsForPortion,
  roundNutrition,
  sumNutrients,
  totalDay,
  totalMeal,
  type FoodPortion,
  type Meal,
  type Nutrients,
} from './nutrition'
```

No fim do arquivo (depois do último `describe`/`})` existente), adicionar:

```ts
describe('gramsPerKg', () => {
  it('divide gramas pelo peso em kg com 2 casas decimais', () => {
    expect(gramsPerKg(145.42, 93)).toBe(1.56)
  })

  it('retorna null quando não há peso cadastrado', () => {
    expect(gramsPerKg(100, null)).toBeNull()
  })

  it('retorna null quando o peso é zero ou negativo', () => {
    expect(gramsPerKg(100, 0)).toBeNull()
    expect(gramsPerKg(100, -5)).toBeNull()
  })
})
```

- [ ] **Step 2: Rodar o teste e confirmar que falha**

Run: `npx vitest run src/lib/nutrition.test.ts`
Expected: FAIL — `gramsPerKg` não existe em `./nutrition`

- [ ] **Step 3: Implementar**

Em `src/lib/nutrition.ts`, logo depois da função `roundNutrition` (que termina em `}` na linha 68 do arquivo atual, antes de `export function nutrientsForPortion`), adicionar:

```ts
/** g de um macronutriente por kg de peso corporal; null se não há peso cadastrado. */
export function gramsPerKg(grams: number, weightKg: number | null): number | null {
  assertNonNegative(grams, 'grams')
  if (weightKg === null || weightKg <= 0) return null
  return roundNutrition(grams / weightKg, 2)
}
```

- [ ] **Step 4: Rodar o teste e confirmar que passa**

Run: `npx vitest run src/lib/nutrition.test.ts`
Expected: PASS (todos os testes do arquivo, incluindo os 3 novos)

- [ ] **Step 5: Checar tipos e lint**

Run: `npx tsc -b && npx oxlint src/lib/nutrition.ts src/lib/nutrition.test.ts`
Expected: sem erros

- [ ] **Step 6: Commit**

```bash
git add src/lib/nutrition.ts src/lib/nutrition.test.ts
git commit -m "feat: add gramsPerKg for body-weight-normalized macro targets"
```

---

### Task 4: Ligar tudo no `NutritionWorkspace.tsx`

**Files:**
- Modify: `src/NutritionWorkspace.tsx`
- Modify: `src/NutritionWorkspace.ui.test.tsx`

**Interfaces:**
- Consumes: `buildShoppingList` (Task 1), `formatPlanForExport` (Task 2), `gramsPerKg` (Task 3), `printClinicalDocument` de `./lib/clinicalExport` (já existe).
- Produces: nada consumido por outra task — é a task final desta fase.

O arquivo `src/NutritionWorkspace.tsx` tem hoje 193 linhas. As mudanças abaixo são todas dentro da função `NutritionWorkspace` (state, um efeito, um memo) e do JSX do editor de plano. Nenhuma outra função do arquivo muda.

- [ ] **Step 1: Imports**

Trocar a linha 4:
```ts
import { totalDay, type Meal, type NutrientKey } from './lib/nutrition'
```
por:
```ts
import { gramsPerKg, totalDay, type Meal, type NutrientKey } from './lib/nutrition'
```

Depois da linha 12 (`import { comparePlanDays, comparePlanNutrition } from './lib/planComparison'`), adicionar três linhas:
```ts
import { printClinicalDocument } from './lib/clinicalExport'
import { buildShoppingList } from './lib/shoppingList'
import { formatPlanForExport } from './lib/planExport'
```

- [ ] **Step 2: Novo estado**

A linha 40 hoje é:
```ts
  const [patientId,setPatientId]=useState(''),[title,setTitle]=useState('Plano alimentar'),[busy,setBusy]=useState(false),[message,setMessage]=useState('')
```
Logo depois dela (antes da linha `const catalog=useFoodCatalog(...)`), adicionar:
```ts
  const [patientWeightKg,setPatientWeightKg]=useState<number|null>(null)
  const [showShoppingList,setShowShoppingList]=useState(false)
```

- [ ] **Step 3: Memo da lista de compras**

A linha (hoje) `const nutritionChanges=useMemo(()=>baselineDays?comparePlanNutrition(baselineDays,days):[],[baselineDays,days])` é seguida por uma linha em branco e `const loadDrafts=useCallback(...)`. Logo depois da linha do `nutritionChanges`, adicionar:
```ts
  const shoppingList=useMemo(()=>buildShoppingList(days),[days])
```

- [ ] **Step 4: Efeito que busca o peso mais recente do paciente**

A linha hoje `useEffect(()=>{void loadDrafts()},[loadDrafts])` — logo depois dela, adicionar:
```ts
  useEffect(()=>{
    if(!patientId){setPatientWeightKg(null);return}
    let active=true
    supabase.from('anthropometry').select('weight_kg').eq('patient_id',patientId).order('measured_at',{ascending:false}).then(({data})=>{if(active)setPatientWeightKg(((data??[]) as {weight_kg:number|null}[])[0]?.weight_kg??null)})
    return ()=>{active=false}
  },[patientId])
```

- [ ] **Step 5: Botões de export + painel de lista de compras**

A linha do `day-tabs` termina o `<div>` e é seguida pela linha dos `meals.map`:
```tsx
        <div className="day-tabs" role="tablist" aria-label="Dias do plano">{days.map((day,index)=><button role="tab" aria-selected={activeDay===index} className={activeDay===index?'active':''} key={day.id} onClick={()=>setActiveDay(index)}>{day.label}</button>)}{!locked&&<><button onClick={()=>{setDays(all=>[...all,{...initialDay(),label:`Dia ${all.length+1}`}]);setActiveDay(days.length)}}><Plus/> Dia</button><button className="secondary" onClick={duplicateActiveDay}><Copy/> Duplicar dia</button></>}</div>
        {meals.map((meal,index)=><EditableMealCard key={meal.id} meal={meal} index={index} foods={catalog.foods} setMeals={setMeals} addItem={addItem} duplicateMeal={duplicateMeal} readOnly={locked}/>)}<MealDistributionInputs meals={meals} assistant={assistant} setAssistant={setAssistant} locked={locked}/>
```

Inserir duas linhas novas entre essas duas (funcionam independente de `locked`, pra dar pra imprimir/exportar até plano publicado):

```tsx
        <div className="plan-export-actions"><button className="secondary" onClick={()=>printClinicalDocument(title||'Plano alimentar',patients.find(p=>p.id===patientId)?.full_name??'',formatPlanForExport(title||'Plano alimentar',days,targets))}>Imprimir plano</button><button className="secondary" onClick={()=>setShowShoppingList(value=>!value)}>{showShoppingList?'Ocultar lista de compras':'Lista de compras'}</button></div>
        {showShoppingList&&<section className="panel shopping-list"><h3>Lista de compras</h3>{shoppingList.length?<ul>{shoppingList.map(item=><li key={item.name}>{item.name} - {item.grams.toLocaleString('pt-BR')} g</li>)}</ul>:<p className="muted">Nenhum item nas refeições ainda.</p>}{shoppingList.length>0&&<button className="secondary" onClick={()=>printClinicalDocument('Lista de compras',title||'Plano alimentar',shoppingList.map(item=>`${item.name} - ${item.grams.toLocaleString('pt-BR')} g`).join('\n'))}>Imprimir lista</button>}</section>}
```

- [ ] **Step 6: g/kg de peso corporal nos totais**

A linha do `live-totals` hoje é:
```tsx
        <section className="live-totals" aria-hidden={editorMode==='quick'}>{macroKeys.map(k=><div key={k}><small>{macroLabels[k]}</small><strong>{totals[k].toLocaleString('pt-BR')} {k==='energyKcal'?'kcal':'g'}</strong></div>)}</section>
```
Trocar por:
```tsx
        <section className="live-totals" aria-hidden={editorMode==='quick'}>{macroKeys.map(k=>{const perKg=k==='energyKcal'?null:gramsPerKg(totals[k],patientWeightKg);return <div key={k}><small>{macroLabels[k]}</small><strong>{totals[k].toLocaleString('pt-BR')} {k==='energyKcal'?'kcal':'g'}</strong>{perKg!==null&&<small>{perKg.toLocaleString('pt-BR')} g/kg</small>}</div>})}</section>
```

- [ ] **Step 7: Rodar os testes existentes e confirmar que nada quebrou**

Run: `npx vitest run src/NutritionWorkspace.ui.test.tsx`
Expected: todos os testes já existentes continuam passando (nenhuma mudança de comportamento anterior).

- [ ] **Step 8: Adicionar os três testes novos**

No fim do `describe('NutritionWorkspace editor modes', ...)` em `src/NutritionWorkspace.ui.test.tsx` (antes do `})` final que fecha o describe, depois do último `it(...)` existente), adicionar:

```ts
  it('imprime o plano ativo formatado', async () => {
    const write = vi.fn(), print = vi.fn(), focus = vi.fn(), close = vi.fn()
    vi.spyOn(window, 'open').mockReturnValue({ document: { write, close }, print, focus } as unknown as Window)
    render(<NutritionWorkspace session={session as never} organizationId="org-1" patients={patients}/>)

    fireEvent.click(screen.getByRole('button', { name: /Editor de plano/i }))
    fireEvent.change(await screen.findByLabelText('Título'), { target: { value: 'Plano para imprimir' } })
    fireEvent.click(screen.getByRole('button', { name: /Imprimir plano/i }))

    expect(write).toHaveBeenCalledWith(expect.stringContaining('Plano para imprimir'))
    expect(print).toHaveBeenCalled()
  })

  it('mostra e oculta a lista de compras agregada por alimento', async () => {
    fromMock.mockImplementation((table: string) => queryResult(table === 'foods' ? [{
      id: 'food-1', name: 'Arroz', preparation_state: 'cozido',
      food_nutrient_values: [{ amount_per_100g: 130, nutrients: { id: 'n-1', code: 'energy_kcal', name: 'Energia', unit: 'kcal' } }],
    }] : []))
    render(<NutritionWorkspace session={session as never} organizationId="org-1" patients={patients}/>)

    fireEvent.click(screen.getByRole('button', { name: /Editor de plano/i }))
    fireEvent.change(await screen.findByLabelText('Buscar alimento'), { target: { value: 'arr' } })
    fireEvent.change(await screen.findByLabelText('Alimento'), { target: { value: 'food-1' } })
    fireEvent.change(screen.getByLabelText('Gramas'), { target: { value: '150' } })
    fireEvent.click(screen.getByRole('button', { name: /Item/i }))

    fireEvent.click(screen.getByRole('button', { name: /Lista de compras/i }))
    expect(screen.getByText('Arroz - 150 g')).toBeInTheDocument()

    fireEvent.click(screen.getByRole('button', { name: /Ocultar lista de compras/i }))
    expect(screen.queryByText('Arroz - 150 g')).not.toBeInTheDocument()
  })

  it('mostra gramas por quilo de peso corporal quando o paciente tem antropometria', async () => {
    fromMock.mockImplementation((table: string) => table === 'anthropometry'
      ? queryResult([{ weight_kg: 93 }])
      : table === 'plans'
        ? queryResult([{
            id: 'plan-1', patient_id: 'patient-1', title: 'Plano A', status: 'reviewed', updated_at: '2026-07-17T10:00:00Z',
            plan_versions: [{
              id: 'version-1', version_no: 1, targets: { proteinG: 145.42 },
              assistant_state: { currentStep: 'objective', completedSteps: [], objective: '', clinicalPresets: [], priorityMicronutrients: [] },
              locked_at: null,
              plan_days: [{ id: 'day-1', label: 'Dia 1', kind: 'standard', day_index: 0, meals: [{ id: 'meal-1', label: 'Almoco', position: 0, meal_items: [{ id: 'item-1', description: 'Frango', grams: 100, nutrient_snapshot: { proteinG: 145.42 }, meal_item_substitutions: [] }] }] }],
            }],
          }]
        : queryResult([]))
    render(<NutritionWorkspace session={session as never} organizationId="org-1" patients={patients}/>)

    fireEvent.click(screen.getByRole('button', { name: /Editor de plano/i }))
    fireEvent.click(await screen.findByText('Plano A'))
    fireEvent.click(screen.getByRole('tab', { name: /Tecnico/i }))

    expect(await screen.findByText('1,56 g/kg')).toBeInTheDocument()
  })
```

- [ ] **Step 9: Rodar todos os testes e confirmar que passam**

Run: `npx vitest run`
Expected: PASS — todos os testes do projeto, incluindo os 3 novos e os das Tasks 1-3.

- [ ] **Step 10: Checar tipos, lint e build**

Run: `npx tsc -b && npx oxlint src && npx vite build`
Expected: sem erros em nenhum dos três.

- [ ] **Step 11: Commit**

```bash
git add src/NutritionWorkspace.tsx src/NutritionWorkspace.ui.test.tsx
git commit -m "feat: add plan print/PDF export, shopping list panel and g/kg macro targets"
```
