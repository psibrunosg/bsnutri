# Graph Report - bsnutri  (2026-07-13)

## Corpus Check
- 40 files · ~18,178 words
- Verdict: corpus is large enough that graph structure adds value.

## Summary
- 325 nodes · 405 edges · 30 communities (26 shown, 4 thin omitted)
- Extraction: 100% EXTRACTED · 0% INFERRED · 0% AMBIGUOUS · INFERRED: 1 edges (avg confidence: 0.5)
- Token cost: 0 input · 0 output

## Graph Freshness
- Built from commit: `408f24de`
- Run `git rev-parse HEAD` and compare to check if the graph is stale.
- Run `graphify update .` after code changes (no API cost).

## Community Hubs (Navigation)
- devDependencies
- compilerOptions
- compilerOptions
- Design System Master File
- App.tsx
- 20260713022714_secure_membership_helpers_and_bootstrap.sql
- BSNutri
- package.json
- 20260713022042_initial_tenant_and_patient_schema.sql
- dependencies
- plugins
- 20260713023230_bootstrap_without_exposed_definer.sql
- tsconfig.json
- 20260713023752_nutrition_catalog_and_plan_drafts.sql
- Política de dados de composição nutricional
- 20260713025127_immutable_publication_and_patient_portal.sql
- 20260713030043_enforce_plan_workflow_rpc.sql
- Regras de agenda e adesão
- 20260713031025_appointments_and_adherence.sql
- 20260713032104_require_online_meeting_link.sql

## God Nodes (most connected - your core abstractions)
1. `compilerOptions` - 18 edges
2. `compilerOptions` - 15 edges
3. `public.profiles` - 8 edges
4. `public.organizations` - 8 edges
5. `Política de dados de composição nutricional` - 8 edges
6. `scripts` - 7 edges
7. `sumNutrients()` - 7 edges
8. `totalDay()` - 7 edges
9. `BSNutri` - 7 edges
10. `Design System Master File` - 7 edges

## Surprising Connections (you probably didn't know these)
- `MealCard()` --calls--> `totalDay()`  [EXTRACTED]
  src/NutritionWorkspace.tsx → src/lib/nutrition.ts
- `normalize()` --calls--> `emptyNutrients()`  [EXTRACTED]
  src/NutritionWorkspace.tsx → src/lib/nutrition.ts
- `NutritionWorkspace()` --calls--> `totalDay()`  [EXTRACTED]
  src/NutritionWorkspace.tsx → src/lib/nutrition.ts
- `NutritionWorkspace()` --calls--> `mapDraftRows()`  [EXTRACTED]
  src/NutritionWorkspace.tsx → src/lib/planDrafts.ts
- `mapDraftRows()` --calls--> `emptyNutrients()`  [EXTRACTED]
  src/lib/planDrafts.ts → src/lib/nutrition.ts

## Import Cycles
- None detected.

## Communities (30 total, 4 thin omitted)

### Community 0 - "devDependencies"
Cohesion: 0.07
Nodes (27): jsdom, oxlint, devDependencies, jsdom, oxlint, tailwindcss, @tailwindcss/vite, @testing-library/jest-dom (+19 more)

### Community 1 - "compilerOptions"
Cohesion: 0.08
Nodes (23): DOM, src, vite/client, compilerOptions, allowArbitraryExtensions, allowImportingTsExtensions, erasableSyntaxOnly, jsx (+15 more)

### Community 2 - "compilerOptions"
Cohesion: 0.10
Nodes (19): node, vite.config.ts, compilerOptions, allowImportingTsExtensions, erasableSyntaxOnly, lib, module, moduleDetection (+11 more)

### Community 3 - "Design System Master File"
Cohesion: 0.11
Nodes (17): Additional Forbidden Patterns, Anti-Patterns (Do NOT Use), Buttons, Cards, Color Palette, Component Specs, Design System Master File, Global Rules (+9 more)

### Community 4 - "App.tsx"
Cohesion: 0.07
Nodes (27): react, Anthropometry, App(), Assessment, AuthMode, passwordRecoveryRedirect(), Patient, PatientAccess (+19 more)

### Community 5 - "20260713022714_secure_membership_helpers_and_bootstrap.sql"
Cohesion: 0.17
Nodes (9): assessments_set_updated_at, memberships_set_updated_at, organizations_set_updated_at, patients_set_updated_at, profiles_set_updated_at, public.anthropometry, public.assessments, public.patient_guardians (+1 more)

### Community 6 - "BSNutri"
Cohesion: 0.12
Nodes (14): Gates de entrega, Isolamento clínico, Matriz de testes RLS e publicação, Metas nutricionais, Paciente e responsável, Publicação imutável e versionada, Roteiro manual remoto A/B, BSNutri (+6 more)

### Community 7 - "package.json"
Cohesion: 0.10
Nodes (20): lucide-react, dependencies, lucide-react, react, react-dom, @supabase/supabase-js, name, private (+12 more)

### Community 8 - "20260713022042_initial_tenant_and_patient_schema.sql"
Cohesion: 0.53
Nodes (10): public.anthropometry, public.assessments, public.audit_events, public.has_organization_role(), public.is_active_member(), public.memberships, public.organizations, public.patient_guardians (+2 more)

### Community 9 - "dependencies"
Cohesion: 0.09
Nodes (40): assertFinite(), assertNonNegative(), calculateTargetProgress(), emptyNutrients(), FoodPortion, mapNutrients(), Meal, MealTotal (+32 more)

### Community 10 - "plugins"
Cohesion: 0.22
Nodes (8): plugins, rules, react/only-export-components, react/rules-of-hooks, $schema, oxc, typescript, warn

### Community 17 - "20260713023752_nutrition_catalog_and_plan_drafts.sql"
Cohesion: 0.29
Nodes (11): foods_set_updated_at, plans_set_updated_at, public.food_nutrient_values, public.food_sources, public.foods, public.meal_items, public.meals, public.nutrients (+3 more)

### Community 18 - "Política de dados de composição nutricional"
Cohesion: 0.18
Nodes (10): Cadastro próprio e comunitário, Campos essenciais, Fontes previstas, Gate para implementação, Objetivo, Política de dados de composição nutricional, Prioridade e conflitos, Registro do alimento (+2 more)

### Community 22 - "20260713025127_immutable_publication_and_patient_portal.sql"
Cohesion: 0.38
Nodes (9): patients_guard_self_claim, private.can_access_patient(), private.guard_patient_self_claim(), private.guard_version_mutation(), public.claim_patient_access(), public.patients, public.plan_versions, public.plans (+1 more)

### Community 25 - "Regras de agenda e adesão"
Cohesion: 0.17
Nodes (11): Adesão, Agenda, Alertas, Conflitos e consistência, Estados e registro, Estados e transições, Linguagem neutra, Matriz mínima de testes SQL (+3 more)

### Community 26 - "20260713031025_appointments_and_adherence.sql"
Cohesion: 0.31
Nodes (8): checkins_create_alert, checkins_validate, private.create_checkin_alert(), private.validate_checkin_chain(), public.adherence_alerts, public.appointments, public.meal_checkins, public.rooms

## Knowledge Gaps
- **154 isolated node(s):** `$schema`, `typescript`, `oxc`, `react/rules-of-hooks`, `warn` (+149 more)
  These have ≤1 connection - possible missing edges or undocumented components.
- **4 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `react` connect `App.tsx` to `dependencies`, `plugins`?**
  _High betweenness centrality (0.019) - this node is a cross-community bridge._
- **Why does `devDependencies` connect `devDependencies` to `package.json`?**
  _High betweenness centrality (0.016) - this node is a cross-community bridge._
- **Why does `plugins` connect `plugins` to `App.tsx`?**
  _High betweenness centrality (0.013) - this node is a cross-community bridge._
- **What connects `$schema`, `typescript`, `oxc` to the rest of the system?**
  _154 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `devDependencies` be split into smaller, more focused modules?**
  _Cohesion score 0.07407407407407407 - nodes in this community are weakly interconnected._
- **Should `compilerOptions` be split into smaller, more focused modules?**
  _Cohesion score 0.08333333333333333 - nodes in this community are weakly interconnected._
- **Should `compilerOptions` be split into smaller, more focused modules?**
  _Cohesion score 0.1 - nodes in this community are weakly interconnected._