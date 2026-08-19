# Ticket: V1 Fase 1 — Beta Estável e Experiência Básica

> Spec completa: `docs/specs/V1_FASE1_BETA_ESTAVEL.md`
> Base: `docs/PLANO_DESENVOLVIMENTO_BSNUTRI_V1.md` (Fase 1, sprints 1-2)

## Metadata
- **Prioridade**: P0 (bloqueia Fase 2+)
- **Estimativa**: 2-4 semanas (1 dev + IA)
- **Branch**: `feat/v1-fase1-beta-estavel`
- **Depende de**: MVP fechado (commit `6c8f00c`)
- **Desbloqueia**: Fase 2 (Entrada e Consulta Guiada)

## Checklist de Execução

### Sprint 1: Estabilidade e UX Básica
- [ ] **1.1** Revisar navegação 3 papéis (profissional/recepcao/paciente)
- [ ] **1.2** Dividir telas grandes:
  - [ ] `PlanBuilder` → `FoodPickerModal`, `TemplateModal`, `WeekGrid`, `MacroBar`
  - [ ] `PatientDetail` → `PatientHeader`, `MeasurementsChart`, `PlansList`, `MeasureForm`
  - [ ] `Portal` → `PatientHeader`, `DayTabs`, `MealCard`, `DailyGoals`
- [ ] **1.3** Padronizar estados: loading, erro, vazio, confirmação
- [ ] **1.4** Sessão expirada/reconexão: 401→login, preservar view
- [ ] **1.5** Formulários mobile: PatientWizard, PlanBuilder picker, Portal tabs
- [ ] **1.6** Error boundary + logging sem dados clínicos

### Sprint 2: PWA, Acessibilidade, Smoke
- [ ] **2.1** PWA: manifest, SW (excluir API), icons, testar instalação
- [ ] **2.2** A11y AA: contraste, foco, tab order, aria-labels, touch targets, reduced-motion, live regions
- [ ] **2.3** Offline: banner, localStorage rascunho (só PlanBuilder), sem edição clínica offline
- [ ] **2.4** Auditoria ações: listar mutações, verificar RLS/grants/testes SQL
- [ ] **2.5** Smoke E2E (Playwright): 3 jornadas + CI
- [ ] **2.6** Code-splitting: lazy load 4 rotas, chunk < 500KB gzip

## Critérios de Aceite (Gate)
- [ ] `npm test` + smoke manual 3 papéis: verde
- [ ] Portal 360px: usável sem scroll horizontal
- [ ] Recepção não vê menu clínico
- [ ] Rede offline → reconecta → rascunho preservado
- [ ] Sentry: sem PHI em payloads
- [ ] Lighthouse PWA ≥ 90, a11y ≥ 95
- [ ] Build: chunk principal < 500KB gzip

## Arquivos a Modificar (Previsão)
```
src/
├── App.tsx                    # Suspense + lazy routes
├── components/
│   ├── Shell.tsx             # Menu por papel
│   ├── FoodPickerModal.tsx   # Novo (ex-PlanBuilder)
│   ├── TemplateModal.tsx     # Novo (ex-PlanBuilder)
│   ├── WeekGrid.tsx          # Novo (ex-PlanBuilder)
│   ├── MacroBar.tsx          # Novo (ex-PlanBuilder)
│   ├── PatientHeader.tsx     # Novo (compartilhado)
│   ├── MeasurementsChart.tsx # Novo (ex-PatientDetail)
│   ├── PlansList.tsx         # Novo (ex-PatientDetail)
│   ├── MeasureForm.tsx       # Novo (ex-PatientDetail)
│   ├── DayTabs.tsx           # Novo (ex-Portal)
│   ├── MealCard.tsx          # Novo (ex-Portal)
│   └── DailyGoals.tsx        # Novo (ex-Portal)
├── pages/
│   ├── PlanBuilder.tsx       # Refatorado (importa componentes)
│   ├── PatientDetail.tsx     # Refatorado
│   └── Portal.tsx            # Refatorado
├── lib/
│   ├── useStore.ts           # Manter
│   └── errorTracking.ts      # Novo (Sentry wrapper)
└── main.tsx                  # ErrorBoundary
public/
├── manifest.json             # Novo/atualizado
├── sw.js                     # Atualizado (excluir API)
└── icons/                    # 192, 512, apple-touch
tests/
├── e2e/
│   ├── profissional.spec.ts  # Novo
│   ├── recepcao.spec.ts      # Novo
│   └── paciente.spec.ts      # Novo
└── setup.ts                  # Playwright config
docs/
├── auditoria-acoes-pendentes.md  # Novo/atualizado
└── specs/V1_FASE1_BETA_ESTAVEL.md  # Este spec
work/
└── V1_FASE1_HANDOFF.md       # Novo (handoff)
```

## Comandos de Validação
```bash
# Desenvolvimento
npm run dev

# Qualidade
npm run lint
npm test
npm run build

# E2E (após setup Playwright)
npx playwright test tests/e2e/

# Lighthouse (manual)
# Chrome DevTools → Lighthouse → PWA + A11y
```

## Riscos Conhecidos
1. **Chunk size**: `recharts`, `jspdf`, `framer-motion` são pesados → considerar dynamic import apenas onde usados
2. **Service Worker**: cachear API do Supabase causaria stale data → testar exclusão `/rest/`, `/auth/`, `/realtime/`
3. **Mobile touch targets**: botões atuais 40px → aumentar para 44px
4. **Reduced motion**: `framer-motion` precisa respeitar `prefers-reduced-motion` global

## Handoff Próximo
Ao concluir, criar `work/V1_FASE1_HANDOFF.md` com:
- Estado exato do branch
- Comandos para reproduzir
- Próximo ticket: **Fase 2 — Entrada e Consulta Guiada** (requer migrações DB)