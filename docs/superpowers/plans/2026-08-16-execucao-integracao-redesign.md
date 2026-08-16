# Execução — Integrar o redesign V2 ao aplicativo real (Tasks 3 a 8)

> Branch: `codex/integrar-redesign-app-real`
> Plano de referência: `docs/superpowers/plans/2026-08-15-integrar-redesign-app-real.md`
> Iniciado em 2026-08-16

## Estado inicial

Tasks 1 e 2 concluídas antes desta sessão (fundação técnica, pipeline seguro, sessão,
navegação e shell responsivo). Base: 29 arquivos de teste, 64 testes verdes.

Módulos legados do commit funcional `5f2fe2c` estavam neutralizados como `export {}`
e suítes correspondentes reduzidas a `expect(true)`. O núcleo clínico não operava.

## Task 3 — Migração clínica e cadastro transacional

Status: **concluída**

- `supabase/migrations/20260816100000_patient_intake_transaction.sql`
  - `patients.tags text[]`, `anthropometry.hip_cm`, `anthropometry.arm_cm`.
  - RPC `create_patient_intake` SECURITY INVOKER: deriva autoria de `auth.uid()`,
    gera código anônimo com retry em colisão e grava paciente + avaliação +
    antropometria + auditoria em uma transação.
- `supabase/tests/patient_intake.test.sql` — 13 asserções: gravação completa,
  normalização de tags, autoria derivada, vínculo antropometria↔avaliação,
  ausência de antropometria vazia, rollback transacional e isolamento
  multi-organização.
- `src/lib/clinicalMetrics.ts` (+ testes) — idade em anos completos com `null`
  quando não há data de nascimento, IMC, categoria, RCQ, variação de peso e
  `isEstimateInputComplete`. Nenhum valor padrão é presumido.
- `src/lib/patients.ts` (+ testes) — `PatientDataSource`, mapeamento de resumo
  preservando nutrientes ausentes, busca sem acento/caixa e normalização de tags.
- `src/lib/usePatientDirectory.ts`, `src/lib/usePatientRecord.ts` — carga do
  diretório e da ficha, com falha parcial por módulo.
- Páginas conectadas: `Dashboard`, `Patients`, `PatientWizard`, `PatientDetail`.
- `src/components/ProfessionalWorkspace.tsx` — roteia as páginas dentro do Shell.
- `src/components/NutritionalEstimator.tsx` — restaurado sem idade fixa: idade vem
  da data de nascimento e o cálculo fica bloqueado sem sexo biológico, peso e
  estatura informados.
- `src/lib/database.types.ts` — tipos completados para `nutritional_estimates`,
  `patients.tags`, `anthropometry.hip_cm/arm_cm` e `create_patient_intake`.
- `src/test/supabaseStub.ts` — stub encadeável para testes de UI sem rede.

Decisão registrada: campos de medida usam `type="text"` com `inputMode="decimal"`.
`type="number"` descarta silenciosamente `68,5` em pt-BR e transformaria uma medida
informada em ausente.

## Task 4 — Catálogo e modelos revisáveis

Status: **concluída**

- `supabase/migrations/20260816110000_plan_template_review_and_provenance.sql`
  - `plan_templates.status` (`needs_review`/`approved`/`archived`), `provenance`,
    `reviewed_by`, `reviewed_at`, `review_notes` e restrição de consistência.
  - Backfill: todo modelo existente entra como `needs_review`, com a origem
    (`seed`/`plan`/`manual`) preservada em `provenance`.
  - RPC `review_plan_template` restrita a owner/admin/nutricionista.
  - `copy_plan_template_to_patient` recriado com a guarda de aprovação: modelo não
    aprovado é recusado com `42501` no próprio banco, não só na interface.
- `supabase/tests/plan_template_review.test.sql` — 9 asserções, incluindo bloqueio
  server-side na chamada direta do copiador e isolamento multi-organização.
- `src/lib/catalogSearch.ts` (+ testes) — busca paginada em runtime, 30 por página,
  `count: 'exact'`, escape de curingas e nutriente ausente preservado como ausente.
- `src/lib/planTemplates.ts` (+ testes) — listagem de 24 por página **sem** carregar
  `snapshot`, detalhe sob demanda, revisão e aplicação.
- `src/lib/useDebouncedValue.ts` (+ testes) — uma consulta por pausa, não por tecla.
- `src/pages/Catalog.tsx` e `src/pages/Templates.tsx` (+ testes de UI).
- Rota e navegação `catalog` acrescentadas ao shell.
- Restaurados de `5f2fe2c`: `nutrition.ts`, `catalog.ts` e suas suítes reais.

## Task 5 — Editor clínico e publicação imutável

Status: **concluída**

- `supabase/migrations/20260816120000_plan_draft_autosave.sql` — RPC
  `autosave_plan_version`, que grava na versão de rascunho aberta sem criar um
  plano novo e recusa versão bloqueada ou plano publicado.
- `supabase/tests/plan_draft_autosave.test.sql` — 7 asserções, incluindo
  isolamento multi-organização e imutabilidade após a publicação.
- `src/lib/usePlanDraft.ts` reescrito sobre o hook funcional de `5f2fe2c`:
  - **Autosave saiu do `localStorage` e passou para o banco.** Nenhum dado clínico
    permanece no navegador. O gatilho é o conteúdo, com atraso de 1,5 s.
  - `copyActiveDayTo` devolve `needsConfirmation` quando o destino já tem
    conteúdo; a substituição só ocorre com confirmação explícita.
  - Catálogo deixou de ser carregado inteiro: os itens vêm da busca paginada.
- `src/lib/pdf.ts` reescrito: `toPublishedPlanDocument` devolve `null` para
  rascunho e versão em revisão, e só carrega substituições ativas da própria
  versão publicada. `jspdf` entra por import dinâmico.
- `src/pages/PlanBuilder.tsx` — três regiões (contexto, edição de um dia por vez,
  análise e publicação), indicador de autosave e bloqueio do PDF fora da
  versão publicada.
- Restaurados de `5f2fe2c`: `planDrafts`, `planAssistant`, `planModels`,
  `planRanges`, `planComparison`, `shoppingList`, `substitutionEngine`,
  `equivalency`, `clinicalExport` e suas suítes reais.

## Task 6 — Portal real do paciente

Status: **concluída**

- `src/lib/usePatientPortal.ts` — plano publicado vigente, metas, água, check-ins,
  trocas, conteúdos, pré-consulta, resumo semanal e lista de compras, com falha
  parcial por módulo.
- `src/pages/Portal.tsx` — abas Hoje, Meu plano, Diário, Compras, Conteúdos e
  Pré-consulta; paciente e responsável usam o mesmo caminho, e o isolamento
  continua sendo garantido pela sessão e pelo RLS.
- Rascunho nunca aparece: a consulta filtra `status = 'published'` e usa a
  versão publicada corrente.

## Task 7 — Importador legado e remoção de duplicatas

Status: **concluída**

- Removidos `src/lib/store.tsx`, `src/lib/data.ts` e `src/lib/types.ts`, além dos
  mocks do store em `Shell.test.tsx` e `Login.test.tsx`.
- `src/App.test.tsx` deixou de testar o protótipo e passou a cobrir a recusa de
  inicialização sem configuração do Supabase.
- Removidos os módulos neutralizados `CareWorkspace`, `ClinicalDrafts`,
  `ContentLibrary`, `NutritionWorkspace`, `PatientDetail` (raiz), `PatientPortal`,
  `SettingsWorkspace`, `SubstitutionWorkspace` e `useFoodCatalog`, com as suítes
  `expect(true)` correspondentes. Nenhum `expect(true)` resta no repositório.
- `src/lib/legacyImport.ts` (+ testes) — leitura controlada de
  `bsnutri-patients`/`bsnutri-plans`, prévia com contagem e descartes, importação
  paciente a paciente com relatório de falhas e limpeza apenas sob confirmação.
  Os pacientes entram marcados com a tag `prototype-v2`.
- `src/components/LegacyImportBanner.tsx` — nada é enviado sem ação explícita.
  Planos antigos não são importados: a estrutura do protótipo não corresponde ao
  plano clínico versionado.

## Task 8 — Qualidade, documentação e corte

Status: **concluída**

- Framer Motion removido: a única transição restante (entrada do painel de login)
  virou animação CSS que respeita `prefers-reduced-motion`. `recharts` também saiu,
  por não ter uso no aplicativo integrado.
- `npm audit` passou de 3 vulnerabilidades (2 altas) para zero.
- Lazy-load de `Catalog`, `PatientDetail`, `PlanBuilder` e `Templates`; `jspdf`
  entra por import dinâmico. Entrada caiu de 502 kB para **267 kB** e nenhum
  fragmento passa de 500 kB.
- `scripts/verify-build-artifact.mjs` deixou de proibir a simples menção às chaves
  do protótipo — que o importador precisa ler — e passou a reprovar o que
  realmente importa: `setItem` clínico no navegador.
- Acessibilidade: `src/test/accessibility.test.tsx` roda o axe sobre login, shell,
  diretório e cadastro. Zero violações WCAG 2 A/AA verificáveis em jsdom.
- Playwright (`npm run test:e2e`, 7 cenários) contra o pacote construído: recusa
  explícita sem configuração, ausência de credencial e de gravação clínica no
  pacote, acessibilidade e zero overflow em 375, 768, 1024 e 1440 px.
- README atualizado com os comandos e o número real de testes.

## Gates ao final da execução

| Gate | Resultado |
|---|---|
| `npm run lint` | verde |
| `tsc -b` | verde |
| `npm test` | 156 testes em 36 arquivos, verde |
| `npm run build` + `verify:artifact` | verde, entrada 267 kB |
| `npm run test:e2e` | 7 cenários, verde |
| `npm audit` | 0 vulnerabilidades |
| `supabase test db` | 18 suítes, 183 testes, verde |

## Defeitos pré-existentes encontrados ao rodar as suítes SQL

A primeira execução local de `supabase test db` desde o redesign revelou que o
banco nunca havia sido aplicado do zero. Corrigidos nesta sessão:

1. **`20260713022415`** — `revoke execute on function public.rls_auto_enable()`
   sem guarda. A função só existe em bancos antigos, então toda aplicação a
   partir do zero (local e CI) morria na segunda migration. Agora é condicional.
2. **`20260816130000`** — `public.publish_plan_version` é SECURITY INVOKER e
   chama `private.plan_assistant_has_steps`, que estava revogada de
   `authenticated`. **Nenhuma publicação funcionava**: toda tentativa devolvia
   "permission denied for function plan_assistant_has_steps". Sozinho, esse
   conserto derrubou as falhas de `publication_portal` de 9 para 1.
3. **`20260816140000`** — `20260717163138_plan_assistant_shell.sql` recriou
   `private.validate_version_ready` sem as verificações que
   `20260717140000_plan_quality_gates.sql` havia acrescentado vinte minutos
   antes, revertendo em silêncio a exigência de metas obrigatórias e
   micronutrientes prioritários. Definição completa restaurada.
4. **`20260816150000`** — `public.import_catalog_foods` declara
   `returns table (id uuid, name text)` e referenciava `id` e `name` sem
   qualificação. **Toda importação de catálogo falhava** com
   "column reference \"id\" is ambiguous".

Fixtures pgTAP também estavam quebradas e foram corrigidas: lista `VALUES` com
comprimento errado (`catalog_entities`), subconsulta com múltiplas linhas
(`diet_catalog_seed`), inserção de dias em versão já bloqueada
(`drive_config_isolation`), `throws_ok` usado com regex onde cabia `throws_like`
e contagem de alimentos globais refém do seed.

As suítes que aplicam modelo (`plan_template_snapshot_apply`,
`plan_template_profiles`, `post_mvp_market_features`) passaram a aprovar o modelo
antes de aplicá-lo, refletindo o novo contrato da Task 4.

## Pendente para o corte final

- Publicação no GitHub Pages continua represada até a aprovação.
