# Fundação Técnica: Tipos Gerados, Tokens CSS e Dependência Morta — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Eliminar drift de tipos entre Supabase e frontend, remover CSS morto/redundante, sincronizar `MASTER.md` com a paleta real e tirar a dependência Tailwind não usada — sem mudar nenhum comportamento ou aparência visível ao usuário.

**Architecture:** Quatro frentes independentes e sequenciais, cada uma com seu próprio ciclo de teste. Nenhuma toca regra de produto (publicação imutável, RLS, IA como rascunho). Spec fonte: `docs/superpowers/specs/2026-07-28-fundacao-tecnica-tokens-e-tipos-design.md`.

**Tech Stack:** React 19, TypeScript ~6.0, Vite 8, Supabase CLI/JS 2.110, Vitest, oxlint.

## Global Constraints

- `npm run lint`, `npm test` e `npm run build` devem ficar verdes ao final de cada task (regra do `AGENTS.md`/`README.md` do repo).
- Nenhuma mudança visível ao paciente, profissional ou recepção em nenhuma das 4 tasks.
- Nenhum valor hex visível pode mudar na Task 2 (CSS) — só remoção de declarações comprovadamente mortas.
- Nunca commitar `service_role`, senha de banco, token pessoal ou dado real de paciente.
- Projeto Supabase remoto: ref `qjclholskxmtxqqentuz`.

---

### Task 1: Gerar tipos do Supabase e trocar tipos hand-rolled em `PatientPortal.tsx`

**Files:**
- Create: `src/lib/database.types.ts` (gerado, não editar à mão)
- Modify: `src/PatientPortal.tsx:1-86` (bloco de tipos), `src/PatientPortal.tsx:160` (remoção do cast inseguro)
- Test: `src/PatientPortal.test.tsx` (já existe, roda como está — nenhum teste novo necessário, é troca de tipo estático)

**Interfaces:**
- Consumes: nada de tasks anteriores.
- Produces: `Database` type exportado de `src/lib/database.types.ts`, usado por qualquer task futura que precise de tipos de tabela.

- [ ] **Step 1: Confirmar link do projeto Supabase**

Run: `supabase projects list`
Expected: a lista inclui `qjclholskxmtxqqentuz` (bsnutri). Se `supabase login` for necessário, rodar antes.

- [ ] **Step 2: Gerar o arquivo de tipos**

Run: `supabase gen types typescript --project-id qjclholskxmtxqqentuz --schema public > src/lib/database.types.ts`

Expected: arquivo `src/lib/database.types.ts` criado, exportando `export type Database = { public: { Tables: {...}; Views: {...}; Functions: {...}; Enums: {...} } }`.

- [ ] **Step 3: Rodar o build para confirmar que o arquivo gerado compila sozinho**

Run: `npm run build`
Expected: PASS (o arquivo novo ainda não é importado por ninguém, então não pode quebrar nada).

- [ ] **Step 4: Substituir o bloco de tipos hand-rolled em `PatientPortal.tsx`**

Abrir `src/PatientPortal.tsx`. Adicionar o import do tipo gerado logo após os imports existentes (linha 13):

```ts
import type { Database } from "./lib/database.types";

type Row<T extends keyof Database["public"]["Tables"]> = Database["public"]["Tables"][T]["Row"];
```

Substituir as linhas 15-84 (do `type PatientAccess = {` até `type OptionalModule = ...`) pelo seguinte bloco, mantendo `OptionalModule` e `NutritionSummary` como estavam (são tipos de UI, não de tabela, `NutritionSummary` já está definido depois na linha 86 e continua igual):

```ts
type PatientAccess = Pick<Row<"patients">, "id" | "full_name" | "anonymous_code" | "organization_id" | "professional_id">;
type Substitution = Pick<Row<"meal_item_substitutions">, "id" | "description" | "grams" | "unit" | "professional_note">;
type Item = Pick<Row<"meal_items">, "id" | "description" | "grams" | "nutrient_snapshot"> & {
  meal_item_substitutions: Substitution[];
};
type Meal = Pick<Row<"meals">, "id" | "label" | "position" | "suggested_time"> & { meal_items: Item[] };
type Day = Pick<Row<"plan_days">, "id" | "label" | "day_index"> & { meals: Meal[] };
type Version = Pick<Row<"plan_versions">, "id" | "version_no" | "assistant_state"> & { plan_days: Day[] };
type Plan = Pick<Row<"plans">, "id" | "title" | "published_at"> & { plan_versions: Version | null };
type Appointment = Pick<Row<"appointments">, "id" | "starts_at" | "status" | "modality">;
type SwapRequest = Pick<
  Row<"substitution_requests">,
  "id" | "substitution_id" | "meal_item_id" | "plan_version_id" | "status" | "professional_note"
>;
type ShoppingItem = { item_key: string; description: string; total_grams: number; occurrences: number };
type IntakeField = Pick<Row<"form_fields">, "id" | "label" | "field_type" | "required" | "position">;
type IntakeAssignment = Pick<Row<"form_assignments">, "id" | "status"> & {
  form_template_versions: { title: string; form_fields: IntakeField[] } | null;
  form_responses: { values: Record<string, string> }[];
};
type DriveStatus = { status: "missing" | "connected"; can_upload_photos: boolean };
type PatientGoal = Pick<Row<"patient_goals">, "id" | "kind" | "title" | "target_value" | "target_unit">;
type WaterLog = Pick<Row<"patient_water_logs">, "amount_ml" | "occurred_on">;
type ContentDelivery = Pick<Row<"patient_content_deliveries">, "id" | "delivered_at"> & {
  snapshot: { title?: string; body?: string; content_type?: string };
};
type WeeklySummary = { period_days: number; meal_checkins: number; completed_meals: number; water_ml: number; active_goals: number };
type Brand = Pick<Row<"organization_branding">, "public_name" | "primary_color" | "logo_url">;
type OptionalModule = "appointments" | "requests" | "intake" | "goals" | "water" | "branding" | "content" | "drive" | "summary" | "image";
```

Se algum nome de coluna citado acima (`nutrient_snapshot`, `professional_note`, `assistant_state`, etc.) não existir literalmente na tabela gerada, o `tsc` vai apontar o erro exato — corrigir o nome da coluna usando o que `database.types.ts` realmente gerou para aquela tabela, sem inventar campo novo.

- [ ] **Step 5: Remover o cast inseguro**

Em `src/PatientPortal.tsx`, trocar:

```ts
else setPlans((p.data ?? []) as unknown as Plan[]);
```

por:

```ts
else setPlans((p.data ?? []) as Plan[]);
```

O cast simples ainda é necessário porque o Supabase JS não tipa estaticamente o shape de um `.select()` com joins aninhados por string — mas o `unknown` intermediário, que existia só para forçar um tipo hand-rolled sem relação nenhuma com o schema, deixa de ser necessário.

- [ ] **Step 6: Rodar lint, teste e build**

Run: `npm run lint && npm test -- PatientPortal && npm run build`
Expected: os três comandos passam. Qualquer erro de tipo aponta um nome de coluna que precisa ser ajustado ao schema real gerado no Step 2 — não escondê-lo com `any`.

- [ ] **Step 7: Commit**

```bash
git add src/lib/database.types.ts src/PatientPortal.tsx
git commit -m "refactor: derive PatientPortal types from generated Supabase schema"
```

---

### Task 2: Remover propriedades customizadas CSS mortas em `App.css`

**Files:**
- Modify: `src/App.css:2` (bloco `:root` original), `src/App.css:23` (bloco `:root` "Tema BSNutri"), `src/App.css:55-66` (bloco `:root` "Redesign 15/07")
- Test: nenhum teste automatizado cobre CSS. Verificação é manual.

**Interfaces:**
- Consumes: nada.
- Produces: nada consumido por outra task.

**Contexto (não repetir declaração, só para quem executa entender o porquê):** `App.css` tem 4 blocos `:root` sucessivos, escritos em datas diferentes, com nomes de variável se sobrepondo (`--primary`, `--accent`, `--border` aparecem em 3 blocos distintos). Cascata CSS faz a última declaração de mesma especificidade vencer, então boa parte dessas redeclarações nunca chega a ser vista — mas continuam no arquivo. Foi confirmado por grep que `var(--accent)`, `var(--leaf)` e `var(--muted)` (o bloco "Redesign 15/07") **não têm nenhum consumidor vivo** em `App.css` — toda regra que os usava foi sobrescrita por uma regra posterior que não usa a variável. `--primary`, `--border`, `--sage`, `--paper`, `--surface`, `--ink`, `--primary-dark` continuam vivos e resolvem para os valores do bloco "Redesign 15/07" (linha 55-66).

- [ ] **Step 1: Tirar screenshot de referência antes da mudança**

Rodar `npm run dev`, abrir a aplicação localmente, tirar screenshot das telas: login/auth, dashboard profissional (sidebar + patient-grid), editor de plano (NutritionWorkspace), portal do paciente. Guardar em `docs/superpowers/plans/_before-after/2026-07-28-css-antes/` (criar a pasta). Essas imagens são só para comparação manual no Step 4, não vão para o commit final.

- [ ] **Step 2: Remover a declaração de `--primary`/`--accent`/`--border` do primeiro bloco `:root` (linha 2)**

Em `src/App.css` linha 2, o bloco começa com:

```css
:root{font-family:'Atkinson Hyperlegible',sans-serif;color:#164e63;background:#ecfeff;--primary:#0891b2;--accent:#059669;--border:#a5f3fc}
```

Trocar por (remove só as 3 custom properties, mantém `font-family`/`color`/`background` que ainda são a base herdada por `:root` antes do `body` pintar por cima):

```css
:root{font-family:'Atkinson Hyperlegible',sans-serif;color:#164e63;background:#ecfeff}
```

- [ ] **Step 3: Remover a declaração de `--primary`/`--accent`/`--border` do segundo bloco `:root` (linha 23)**

Localizar em `src/App.css` linha 23:

```css
:root{color:#2e2e2e;background:#f7f3ee;--primary:#3e6b5c;--accent:#62824d;--border:#c8d4c2}
```

Trocar por:

```css
:root{color:#2e2e2e;background:#f7f3ee}
```

- [ ] **Step 4: Remover `--accent` e `--leaf` e `--muted` do terceiro bloco `:root` (linha 55-66) — variáveis comprovadamente sem consumidor**

Localizar o bloco:

```css
:root{
  --primary:#3e6b5c;
  --primary-dark:#2f5c50;
  --accent:#d5a83f;
  --leaf:#62824d;
  --sage:#a8b8a1;
  --muted:#edf1e8;
  --paper:#f7f3ee;
  --surface:#fffdf8;
  --ink:#2e2e2e;
  --border:#c8d4c2;
}
```

Trocar por (mantém só as variáveis com consumidor vivo — `--primary`, `--primary-dark`, `--sage`, `--paper`, `--surface`, `--ink`, `--border`):

```css
:root{
  --primary:#3e6b5c;
  --primary-dark:#2f5c50;
  --sage:#a8b8a1;
  --paper:#f7f3ee;
  --surface:#fffdf8;
  --ink:#2e2e2e;
  --border:#c8d4c2;
}
```

- [ ] **Step 5: Rodar build e conferir visualmente**

Run: `npm run build && npm run dev`

Abrir as mesmas 4 telas do Step 1, comparar com os screenshots guardados. Nenhum pixel deve mudar — se algo mudar de cor, é sinal de que alguma variável removida ainda tinha um consumidor não pego pelo grep (reverter o Step correspondente e investigar com `grep -n "var(--nome)" src/App.css` antes de tentar de novo).

- [ ] **Step 6: Apagar a pasta de screenshots de comparação**

```bash
rm -rf docs/superpowers/plans/_before-after
```

(são artefato de verificação local, não fazem parte do repositório)

- [ ] **Step 7: Rodar lint e teste**

Run: `npm run lint && npm test`
Expected: PASS (CSS não é coberto por teste automatizado, mas lint/testes de componente não podem ter sido afetados).

- [ ] **Step 8: Commit**

```bash
git add src/App.css
git commit -m "chore: remove dead CSS custom properties shadowed by later :root blocks"
```

---

### Task 3: Atualizar `MASTER.md` com a paleta real em produção

**Files:**
- Modify: `design-system/bsnutri/MASTER.md:18-33` (tabela de paleta)

**Interfaces:**
- Consumes: nenhuma dependência de código — só precisa que a Task 2 já tenha rodado, para documentar os valores que sobraram como fonte única.
- Produces: nada consumido por outra task.

- [ ] **Step 1: Substituir a tabela de paleta**

Em `design-system/bsnutri/MASTER.md`, trocar a tabela em "Color Palette" (linhas 20-31) por:

```markdown
| Role | Hex | CSS Variable |
|------|-----|--------------|
| Primary | `#3E6B5C` | `--primary` |
| Primary Dark | `#2F5C50` | `--primary-dark` |
| On Primary | `#FFFFFF` | (sem variável, hardcoded em `.primary`) |
| Accent/CTA | `#62824D` | (sem variável dedicada; usado como hex direto em componentes de destaque — ver nota abaixo) |
| Background | `#F7F3EE` | `--paper` |
| Foreground | `#2E2E2E` | `--ink` |
| Muted text | `#527382` | (sem variável; hardcoded em toda a UI — candidato a virar `--muted-text` numa limpeza futura) |
| Surface | `#FFFDF8` | `--surface` |
| Border | `#C8D4C2` | `--border` |
| Sage | `#A8B8A1` | `--sage` |
| Destructive | `#A31515` | `--bs-danger-fg` |
| Focus Ring | `rgb(62 107 92 / .32)` | `--focus-ring` |

**Nota:** esta tabela documenta a paleta verde-oliva/bege realmente em produção (tema "Clínica BS", ver `src/App.css` a partir da linha 54), não a paleta cyan/verde-saúde original gerada por este skill. `--accent` e `--muted` (nomes de variável) foram removidos do CSS em 2026-07-28 por não terem consumidor — os papéis "Accent" e "Muted text" acima existem visualmente mas hoje são hex direto, não variável.
```

- [ ] **Step 2: Atualizar o cabeçalho de metadata**

Trocar a linha `**Generated:** 2026-07-12 23:25:52` por:

```markdown
**Generated:** 2026-07-12 23:25:52
**Palette updated to match production:** 2026-07-28
```

- [ ] **Step 3: Commit**

```bash
git add design-system/bsnutri/MASTER.md
git commit -m "docs: sync MASTER.md palette with production CSS"
```

---

### Task 4: Remover dependência Tailwind não usada

**Files:**
- Modify: `package.json`, `vite.config.ts`, `src/index.css`

**Interfaces:**
- Consumes: nada.
- Produces: nada.

- [ ] **Step 1: Confirmar que não há nenhuma classe Tailwind em uso**

Run: `grep -rlE "className=\"[^\"]*(flex|grid|p-[0-9]|m-[0-9]|text-(sm|lg|xl)|bg-[a-z]+-[0-9])" src --include=*.tsx`
Expected: nenhum resultado. Se aparecer algum arquivo, essa task para aqui — significa que Tailwind está em uso e a remoção não pode acontecer sem antes migrar essas classes para CSS puro (fora do escopo deste plano).

- [ ] **Step 2: Remover o import do `index.css`**

Em `src/index.css`, remover a linha 1:

```css
@import "tailwindcss";
```

O arquivo final começa direto em `:root { font-family: Inter, ...`.

- [ ] **Step 3: Remover o plugin do `vite.config.ts`**

Em `vite.config.ts`, remover a linha `import tailwindcss from '@tailwindcss/vite'` e `tailwindcss()` do array `plugins`:

```ts
import { defineConfig } from 'vitest/config'
import react from '@vitejs/plugin-react'

export default defineConfig({
  base: '/bsnutri/',
  plugins: [react()],
  test: { environment: 'jsdom', setupFiles: './src/test/setup.ts' },
})
```

- [ ] **Step 4: Remover as dependências do `package.json`**

Run: `npm uninstall tailwindcss @tailwindcss/vite`
Expected: `package.json` e `package-lock.json` atualizados, as duas entradas somem de `devDependencies`.

- [ ] **Step 5: Rodar lint, teste e build**

Run: `npm run lint && npm test && npm run build`
Expected: os três passam. `npm run dev` local também deve subir sem erro de import quebrado.

- [ ] **Step 6: Commit**

```bash
git add package.json package-lock.json vite.config.ts src/index.css
git commit -m "chore: remove unused tailwindcss dependency"
```

---

## Follow-ups identificados mas fora de escopo (não implementar aqui)

- Unificar de vez `--bs-*`/`--color-*` (linhas 26-42 de `App.css`) com o namespace `--primary`/`--sage`/etc — exigiria renomear ~12 pontos de uso (`var(--color-border)`, `var(--color-surface)` etc.), maior risco visual do que o aprovado neste plano.
- `#c8d4c2` (variável `--border`) e `#d9e1d3` (hex hardcoded, usado em paralelo como uma borda quase idêntica) são duas cores de borda quase-duplicadas nunca consolidadas.
- `#527382` (texto secundário) aparece hardcoded dezenas de vezes sem variável — candidato natural a um token `--muted-text` numa limpeza futura de CSS.
