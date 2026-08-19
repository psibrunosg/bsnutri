# Spec: V1 Fase 1 — Beta Estável e Experiência Básica

> Baseado em `docs/PLANO_DESENVOLVIMENTO_BSNUTRI_V1.md` (Fase 1, sprints 1-2) e `docs/PLANO_REDESIGN_DESENVOLVIMENTO_AUTONOMO_BSNUTRI_V2.md` (Fase 1).

## Contexto
MVP fechado em 17/07/2026. Próximo ciclo visa transformar a base em produto utilizável na rotina real de clínica.

## Objetivo da Fase 1
Deixar o produto atual confortável para uso frequente antes de ampliar o domínio.

---

## Sprint 1: Estabilidade e UX Básica (1-2 semanas)

### 1.1 Revisar navegação dos três papéis
- [ ] Profissional: menu completo (Dashboard, Pacientes, Planejamento, Biblioteca, Agenda, Configurações)
- [ ] Recepção: menu reduzido (Agenda, Pacientes básicos, sem navegação clínica)
- [ ] Paciente: portal standalone (sem shell lateral)

**Critério**: Cada papel vê apenas o que tem permissão (RLS já garante no backend; frontend não deve mostrar itens inacessíveis).

### 1.2 Dividir telas grandes sem criar framework interno
- [ ] `PlanBuilder.tsx` (311 linhas) → lazy load + extrair `FoodPickerModal`, `TemplateModal`, `WeekGrid`, `MacroBar`
- [ ] `PatientDetail.tsx` (172 linhas) → extrair `PatientHeader`, `MeasurementsChart`, `PlansList`, `MeasureForm`
- [ ] `Portal.tsx` (133 linhas) → extrair `PatientHeader`, `DayTabs`, `MealCard`, `DailyGoals`

**Critério**: Cada extração é um componente funcional com props tipadas; sem criar "design system" próprio.

### 1.3 Padronizar estados de UI
- [ ] Loading: skeleton ou spinner consistente
- [ ] Erro: toast + inline message com ação de retry
- [ ] Vazio: ilustração + call-to-action contextual
- [ ] Confirmação: modal para ações irreversíveis (publicar, excluir)

### 1.4 Tratar sessão expirada e reconexão
- [ ] Interceptar erros 401/403 do Supabase → redirect para `/login` com mensagem
- [ ] Auto-refresh de token já configurado no cliente; testar expiração real
- [ ] Preservar `view` atual no store para restaurar após relogin

### 1.5 Revisar formulários no celular
- [ ] `PatientWizard`: campos empilhados, inputs com `type` correto (email, tel, date)
- [ ] `PlanBuilder`: food picker usável em 360px (scroll horizontal → accordion)
- [ ] `Portal`: day tabs com scroll horizontal, meal cards empilhados

### 1.6 Instrumentar erros técnicos sem conteúdo clínico
- [ ] Error boundary no `App.tsx` capturando erros de render
- [ ] Log para serviço externo (Sentry/LogRocket) apenas: `error.message`, `componentStack`, `userRole`, `view.name`
- [ ] **Nunca** enviar: patient names, IDs, measurements, plan contents

---

## Sprint 2: PWA, Acessibilidade e Smoke (1-2 semanas)

### 2.1 Transformar portal em PWA instalável
- [ ] `public/manifest.json`: name, short_name, icons (192, 512), start_url `/portal`, display `standalone`
- [ ] `public/sw.js`: cache app shell (`index.html`, CSS, JS chunks), **excluir** `/auth/`, `/rest/`, `/realtime/`
- [ ] `index.html`: `<link rel="manifest">`, `<meta name="theme-color">`, apple touch icons
- [ ] Testar: "Adicionar à tela inicial" no Chrome Android/iOS Safari

### 2.2 Acessibilidade (WCAG AA)
- [ ] Contraste mínimo 4.5:1 (texto), 3:1 (UI components) — revisar cores `forest-500`, `amber-600`, `cream-100`
- [ ] Foco visível: `focus-visible:ring-2 focus-visible:ring-forest-500` em todos os interativos
- [ ] Ordem de tabulação coerente (header → main → aside → footer)
- [ ] Botões de ícone: `aria-label` descritivo (ex: `aria-label="Fechar modal de alimentos"`)
- [ ] Alvos de toque ≥ 44×44px (mobile)
- [ ] Não depender apenas de cor (status chips têm ícone + texto)
- [ ] Suportar zoom 200% e largura 375px sem overflow horizontal
- [ ] Respeitar `prefers-reduced-motion`: desabilitar `framer-motion` animations
- [ ] Live regions para: salvamento, publicação, erros de rede

### 2.3 Estados offline claros
- [ ] Detectar `navigator.onLine` + interceptar falhas de fetch
- [ ] Banner não-intrusivo: "Você está offline. Alterações serão salvas quando reconectar."
- [ ] **Não** permitir edição clínica offline (plano, medidas, avaliações)
- [ ] Persistir rascunho local (`localStorage`) apenas para `PlanBuilder` com timestamp

### 2.4 Auditoria de ações não cobertas
- [ ] Listar todas as mutações Supabase (RPC, insert, update, delete) no frontend
- [ ] Verificar se cada uma tem: RLS policy, grant explícito, teste SQL positivo/negativo
- [ ] Documentar gaps em `docs/auditoria-acoes-pendentes.md`

### 2.5 Smoke automatizado dos 3 papéis
- [ ] Playwright/Vitest Browser Mode: 3 testes E2E
  - `profissional`: login → dashboard → patient-detail → plan-builder → publicar
  - `recepcao`: login → agenda → criar agendamento → confirmar
  - `paciente`: login → portal → ver plano → marcar refeição → baixar PDF
- [ ] Rodar em CI (GitHub Actions) antes de deploy
- [ ] Dados: fixtures sintéticas via `supabase db seed`

### 2.6 Code-splitting para reduzir chunk principal (1.4MB → <500KB)
- [ ] Lazy load rotas pesadas:
  ```tsx
  const PlanBuilder = lazy(() => import('./pages/PlanBuilder'));
  const PatientDetail = lazy(() => import('./pages/PatientDetail'));
  const Portal = lazy(() => import('./pages/Portal'));
  const Templates = lazy(() => import('./pages/Templates'));
  ```
- [ ] `Suspense` fallback com skeleton no `App.tsx`
- [ ] Verificar: `npm run build` → chunks < 500KB gzip

---

## Critérios de Aceite (Gate Fase 1)

| Critério | Verificação |
|----------|-------------|
| Todas as jornadas atuais continuam verdes | `npm test` + smoke manual 3 papéis |
| Portal funciona em 360px | Chrome DevTools device toolbar |
| Nenhuma tela clínica vaza para recepção | Login recepcao → inspecionar menu |
| Erro de rede não apaga rascunho local | Desconectar WiFi → editar plano → reconectar |
| Erros de produção investigáveis sem expor dado clínico | Verificar payload Sentry |
| PWA instalável no mobile | Lighthouse PWA score ≥ 90 |
| Acessibilidade AA | axe-core / Lighthouse a11y ≥ 95 |
| Chunk principal < 500KB gzip | `npm run build` output |

---

## Fora do Escopo (Não Fazer Nesta Fase)
- ❌ Novo editor de plano (Fase 3)
- ❌ Motor de estimativas nutricionais (Fase 2)
- ❌ Formulários pré-consulta versionados (Fase 2)
- ❌ Chat/mensagens (Fase 5)
- ❌ Agenda pública (Fase 6)
- ❌ Financeiro (Fase 6)
- ❌ Redesign visual completo (paralelo, não bloqueante)

---

## Dependências Técnicas
- Nenhuma migração DB necessária (usa schema atual)
- Supabase Auth já configurado (refresh token rotation, site_url)
- Testes SQL existentes cobrem RLS atual

---

## Entregáveis
1. Branch `feat/v1-fase1-beta-estavel` com commits atômicos por item acima
2. PR com: diff, screenshots mobile/desktop, Lighthouse reports
3. `docs/auditoria-acoes-pendentes.md` atualizado
4. Handoff atualizado em `work/V1_FASE1_HANDOFF.md`

---

## Próxima Fase (Preview)
**Fase 2: Entrada e Consulta Guiada** — convite seguro, formulários versionados, entidade de consulta, navegação por etapas. Requer migrações DB (`patient_invites`, `form_templates`, `consultations`).