# 01 - Assistente obrigatório do editor

**What to build:** o nutricionista abre ou cria um plano e passa por um assistente obrigatório até a publicação. O assistente registra etapa atual, objetivo, metas, refeições, equivalentes, revisão e publicação, sem criar um modelo de dados separado do plano.

**Blocked by:** None - can start immediately.

**Status:** implemented

- [x] O plano em rascunho mostra a etapa atual do assistente.
- [x] O nutricionista consegue avançar e voltar entre etapas sem perder dados.
- [x] A publicação não fica disponível enquanto etapas obrigatórias não forem concluídas.
- [x] O assistente usa a versão de plano existente e preserva publicação imutável.
- [x] Há teste cobrindo retomada de rascunho no meio do assistente.

## Implementacao

Entregue em 17/07/2026.

Arquivos principais:

- `src/lib/planAssistant.ts`
- `src/lib/planDrafts.ts`
- `src/NutritionWorkspace.tsx`
- `src/NutritionWorkspace.test.ts`
- `supabase/migrations/20260717163138_plan_assistant_shell.sql`
- `supabase/tests/publication_portal.test.sql`

Validado com `npm test`, `npm run lint`, `npm run build` e `git diff --check`.

Pendente de ambiente: `npx supabase test db --local supabase\tests\publication_portal.test.sql` nao rodou porque Docker/Supabase local nao esta disponivel neste computador.
