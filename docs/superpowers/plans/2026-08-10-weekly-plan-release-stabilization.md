# Weekly Plan Release Stabilization Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Restore the BSNutri validation and Pages release while preserving the automatic seven-day plan and making repeated meal controls accessible.

**Architecture:** Keep `usePlanDraft` as the source of the approved weekly defaults. Adapt the integration test to navigate the tabbed editor, then add only native ARIA relationships and contextual labels in `PlanEditor`; do not introduce a routing, state, or component abstraction.

**Tech Stack:** React 19, TypeScript, Testing Library, Vitest, Oxlint, Vite, GitHub Actions.

## Global Constraints

- New plans contain seven days and six standard meals per day.
- Persisted templates apply directly to all seven weekdays.
- Existing drafts preserve their stored day and meal structure.
- The professional remains the primary user and publication stays immutable.
- Do not add dependencies, database migrations, clinical rules, or broad refactors.
- Subagents use `gpt-5.6-terra` with low reasoning and return only `OK` or `Fail`; detailed evidence goes in the SDD report files.

---

### Task 1: Encode the approved tabbed weekly journey

**Files:**
- Modify: `src/NutritionWorkspace.ui.test.tsx`
- Test: `src/NutritionWorkspace.ui.test.tsx`

**Interfaces:**
- Consumes: visible tabs `Configuração`, `Modelos`, `Planos`, `Assistente`; seven weekday day tabs; six standard meals.
- Produces: integration expectations for contextual meal controls and the approved direct seven-day model application.

- [ ] **Step 1: Update interactions that target conditional sidebar content**

Add a small test-local helper and use it only where the requested panel is conditional:

```tsx
const openSidebarTab = (name: RegExp) =>
  fireEvent.click(screen.getByRole('tab', { name }))
```

Open `Assistente` before objective fields, `Planos` before drafts and blank-plan actions, and `Modelos` before the model gallery.

- [ ] **Step 2: Express the approved weekly and accessible behavior**

Use hand-derived expectations:

```tsx
expect(screen.getByRole('tab', { name: 'Segunda-feira' })).toHaveAttribute('aria-selected', 'true')
expect(screen.getByRole('tab', { name: 'Domingo' })).toBeInTheDocument()
expect(screen.getByRole('tab', { name: 'Segunda-feira' })).toHaveAttribute('aria-controls', 'plan-day-panel')
expect(screen.getByRole('tabpanel', { name: 'Segunda-feira' })).toHaveAttribute('id', 'plan-day-panel')
expect(screen.getByRole('region', { name: 'Café da manhã' })).toBeInTheDocument()
expect(screen.getByLabelText('Buscar alimento no Café da manhã')).toBeInTheDocument()
```

Update the duplicate expectation to `Segunda-feira copia`. Replace the removed template dialog interaction with a direct click on `Aplicar`, then assert the seven-day success message and opened copied draft.

- [ ] **Step 3: Scope meal editing by the named meal region**

```tsx
const breakfast = screen.getByRole('region', { name: 'Café da manhã' })
fireEvent.change(within(breakfast).getByLabelText('Buscar alimento no Café da manhã'), {
  target: { value: 'arr' },
})
```

Use the same region-scoped pattern in shopping-list and atomic-save tests. Do not use `getAllByLabelText()[0]`.

- [ ] **Step 4: Run the targeted test and verify RED**

Run:

```bash
npx vitest run src/NutritionWorkspace.ui.test.tsx
```

Expected: failures specifically because named meal regions, contextual labels, day-panel association, or complete sidebar tab semantics do not exist yet. Fix selector mistakes until the remaining failures name missing production behavior.

- [ ] **Step 5: Commit the test contract**

```bash
git add src/NutritionWorkspace.ui.test.tsx
git commit -m "test: define weekly editor journey"
```

### Task 2: Add native accessible names and tab relationships

**Files:**
- Modify: `src/components/PlanEditor.tsx`
- Test: `src/NutritionWorkspace.ui.test.tsx`

**Interfaces:**
- Consumes: existing `sidebarTab` state and `meal.name` values.
- Produces: named sidebar tablist, sidebar and day tabs associated to active `tabpanel` elements, and meal regions with contextual control names.

- [ ] **Step 1: Name and associate the sidebar tabs**

Keep the existing state. Give the tablist `aria-label="Seções do contexto do plano"`. Each tab receives a stable `id` and matching `aria-controls`. Render the active content inside one native wrapper:

```tsx
<div
  role="tabpanel"
  id={`plan-context-panel-${sidebarTab}`}
  aria-labelledby={`plan-context-tab-${sidebarTab}`}
>
  {activeContent}
</div>
```

Do not add a generic tabs component.

- [ ] **Step 2: Associate the active day with its tab**

Give every day tab a stable ID derived from `day.id` and `aria-controls="plan-day-panel"`. Wrap the active day's editable content in:

```tsx
<div
  role="tabpanel"
  id="plan-day-panel"
  aria-labelledby={`plan-day-tab-${days[activeDay].id}`}
>
  {dayContent}
</div>
```

Keep only the active day's meals in the DOM.

- [ ] **Step 3: Name each meal region and its repeated controls**

Use the existing `meal.name` directly:

```tsx
<section className="panel meal-editor" aria-label={meal.name}>
  <input aria-label={`Buscar alimento no ${meal.name}`} />
  <select aria-label={`Alimento no ${meal.name}`} />
  <input aria-label={`Gramas no ${meal.name}`} />
</section>
```

Preserve visible copy and behavior.

- [ ] **Step 4: Run the targeted test and verify GREEN**

Run:

```bash
npx vitest run src/NutritionWorkspace.ui.test.tsx
```

Expected: all tests in the file pass with zero failures.

- [ ] **Step 5: Run the focused regression set**

Run:

```bash
npx vitest run src/NutritionWorkspace.ui.test.tsx src/lib/planDrafts.test.ts src/lib/planModels.test.ts src/PatientPortal.test.tsx
```

Expected: zero failures.

- [ ] **Step 6: Commit the implementation**

```bash
git add src/components/PlanEditor.tsx
git commit -m "fix: stabilize weekly plan editor"
```

### Task 3: Verify the release candidate

**Files:**
- Verify: `src/NutritionWorkspace.ui.test.tsx`
- Verify: `src/components/PlanEditor.tsx`
- Verify: `.github/workflows/deploy.yml`

**Interfaces:**
- Consumes: Tasks 1 and 2 commits.
- Produces: evidence that the branch satisfies the design and can enter the existing deploy workflow.

- [ ] **Step 1: Run the complete frontend gates**

```bash
npm test
npm run lint
npm run build
git diff --check origin/main...HEAD
```

Expected: every command exits `0`; test output has zero failures. The existing non-blocking Vite chunk-size warning may remain because bundle optimization is out of scope.

- [ ] **Step 2: Audit the design requirements against the diff**

Confirm directly that:

- `initialWeek()` remains the default for new or empty plans;
- no migration, dependency, clinical rule, or workflow change entered the diff;
- stored non-empty drafts still use their own `days`;
- meal controls are distinguishable without positional selectors;
- all twelve formerly failing journeys are represented by passing tests.

- [ ] **Step 3: Record operational follow-ups without changing scope**

Report, but do not fix in this branch, the existing npm audit findings, Node 20 Actions warning, and Vite bundle-size warning.
