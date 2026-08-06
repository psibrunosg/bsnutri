# Auditoria do mapa de execução, 24/07/2026

Escopo: conferência das issues #7 e #8–#39 contra os arquivos presentes no worktree. “Implementado” exige evidência de fluxo e teste pertinente; “parcial” significa que há base reutilizável, mas algum critério de aceite ainda não está comprovado. Nenhuma issue está fechada no GitHub nesta data.

## Leitura executiva

- **#8 é a interrupção imediata.** O portal já possui base para planos, diário, metas e conteúdos, mas uma falha em `organization_branding` ainda impede o carregamento clínico porque a consulta opcional participa do erro global. O teste de reprodução foi registrado no handoff `work/handoffs/bsnutri_23_07_2026_1705.md`.
- A maior parte dos tickets #10–#27 está **parcial**, não ausente: há migrations, telas e testes de base que devem ser completados, não reescritos.
- A fronteira recomendada após #8 é **#9 e #10**: consolidar estados reutilizáveis de carregamento/erro e fechar procedência/importação do catálogo. Isso desbloqueia a busca cultural (#11), receitas (#12) e o motor de substituições (#15).

## Auditoria por issue

| Issue | Estado | Evidência atual | Lacuna decisiva |
|---|---|---|---|
| #7 Programa total | Parcial | `docs/specs/bsnutri-development-program-v1.md`; 32 issues abertas | Programa publicado, mas execução não concluída. |
| #8 Portal resiliente | Parcial, com bug aberto | `src/PatientPortal.tsx`, `src/PatientPortal.test.tsx`, `src/lib/driveClient.ts` | Falha opcional de marca ainda derruba o bloco clínico; faltam retries independentes de marca/conteúdo/resumo. |
| #9 Sistema visual | Parcial | `src/App.css`, `src/App.tsx`, testes UI existentes | Não há contrato único comprovado para vazio, carregamento, erro, foco e retry nas jornadas principais. |
| #10 Procedência/importação | Parcial | `supabase/migrations/20260713023752_nutrition_catalog_and_plan_drafts.sql`, `20260723184909_catalog_entities.sql`, `supabase/tests/catalog_entities.test.sql` | Há fonte e unicidade, mas não fluxo de prévia, validação e publicação de importação. |
| #11 Busca cultural/renders | Parcial | `src/lib/catalog.ts`, `src/lib/catalog.test.ts`, `public/food-renders/`, `20260723201500_food_render_paths.sql` | Busca e renders têm base; favoritos/recentes persistentes e filtros combináveis completos não estão comprovados. |
| #12 Receitas/medidas | Pendente | Apenas especificações em `docs/tickets/post-mvp-market-features-v1/05-recipes-and-household-measures.md` | Não há tabelas, cálculo de rendimento ou editor de receitas no produto. |
| #13 Faixas/edição rápida | Parcial | `src/lib/planModels.ts`, `src/NutritionWorkspace.tsx`, `supabase/migrations/20260723190844_plan_template_profiles.sql` | Perfis existem; faixas por refeição, lote e justificativa de alertas não estão integralmente demonstrados. |
| #14 Comparação/auditoria | Parcial | `supabase/migrations/20260713025127_immutable_publication_and_patient_portal.sql`, `supabase/tests/publication_portal.test.sql` | Imutabilidade e evento de publicação existem; comparação clínica e preview idêntico ao snapshot não. |
| #15 Motor de substituições | Parcial | `src/SubstitutionWorkspace.tsx`, `supabase/migrations/20260713032602_controlled_substitutions.sql` | Há solicitação/revisão; falta ranqueador determinístico por nutrientes, cultura, restrição e impacto explicável. |
| #16 Curadoria/substituição paciente | Parcial | `PatientPortal.tsx`, `SubstitutionWorkspace.tsx`, migration de substituições controladas | Alternativas básicas aparecem; ordenar, bloquear, limitar e registrar uso vinculado à versão precisam fechar. |
| #17 Visibilidade clínica | Parcial | `src/lib/planAssistant.ts`, `src/PatientPortal.tsx`, `src/PatientPortal.test.tsx` | UI respeita `visibility`; ainda falta provar versionamento seguro e ausência do dado oculto na consulta. |
| #18 Diário publicado | Parcial | `PatientPortal.tsx`, `20260713031025_appointments_and_adherence.sql`, `appointments_adherence.test.sql` | Check-in e vínculo existem; estado “extra” e cobertura completa da nova taxonomia ainda faltam. |
| #19 Contexto/foto | Parcial | `PatientPortal.tsx`, `src/lib/driveClient.ts`, `20260717141500_diary_photo_drive_metadata.sql`, testes do portal | Texto sobrevive à falha de upload; validação completa de tipo/tamanho e todos os cenários de recusa não estão comprovados. |
| #20 Resumo/fila | Parcial | `20260717143000_follow_up_alert_rules.sql`, `20260717143500_follow_up_queue.sql`, respectivos testes SQL | Regras e fila existem; resumo por contexto e interface de conduta/revisão ainda incompletos. |
| #21 Metas | Parcial | `20260723210000_patient_progress_and_content_library.sql`, `PatientPortal.tsx`, `patient_progress_content_library.test.sql` | Metas ativas são exibidas; check-in, revisão, substituição, encerramento e nota privada não. |
| #22 Hoje/compras | Parcial | `PatientPortal.tsx` (`TodayHome`, `ShoppingList`) | Página Hoje e lista base existem; período derivado da versão e fluxo responsivo completo carecem de prova. |
| #23 Exames/evolução | Parcial | `20260715162102_clinical_consents_and_labs.sql`, `src/App.tsx`, `src/PatientDetail.tsx` | Base de laboratórios existe; comparações válidas, anexos e completude clínica não estão fechados. |
| #24 Biblioteca educativa | Parcial | `src/ContentLibrary.tsx`, `20260723210000_patient_progress_and_content_library.sql`, teste SQL | Versionamento e entrega estão presentes; pastas, tags, validade, sequência e visualização ainda não. |
| #25 Pré-consulta/resumo | Parcial | `20260717160000_intake_consultation_templates.sql`, `PatientPortal.tsx`, `CareWorkspace.tsx` | Formulário e respostas existem; painel longitudinal com pendências separadas não está comprovado. |
| #26 Rascunhos auditáveis | Parcial | `src/ClinicalDrafts.tsx`, `src/lib/planDrafts.ts`, `20260723220000_reviewable_drafts_branding_exports.sql` | Rascunho estruturado local existe; fatos usados, decisões e auditoria de revisão ainda são incompletos. |
| #27 PDFs/exportações | Parcial | `src/lib/clinicalExport.ts`, `clinicalExport.test.ts`, migration de branding/export | Há impressão/exportação de resumo; PDF completo de plano/evolução, paginação e auditoria de acesso faltam. |
| #28 Mensagens/tarefas | Pendente | Specs existem; sem tela/migration específica encontrada | Não há modelos, preferências, limite ou histórico de comunicação. |
| #29 Recepção | Pendente | `appointments_adherence` cobre agenda, mas não papel/tela de recepção | Faltam permissões, ações administrativas e testes negativos próprios. |
| #30 Gestão de equipe | Pendente | Estrutura inicial de perfis em migrations antigas | Sem UI/fluxo de equipe, convites revogáveis, serviços e relatórios. |
| #31 Hardening transversal | Parcial | `docs/rls-test-matrix.md`, `supabase/tests/rls_isolation.test.sql`, testes de Drive | RLS tem cobertura relevante; restauração testada, sessões/convites revogáveis e monitoramento ainda faltam. |
| #32 PWA/mobile | Pendente | Não há manifesto/service worker PWA no worktree | Sem offline, retomada e ações rápidas profissionais. |
| #33 Contrato modelos especializados | Pendente | `src/lib/planModels.ts` possui perfis gerais | Não há contrato com população, fontes, limites, alertas e revisor obrigatório. |
| #34 Low FODMAP | Pendente | Sem implementação específica | Depende de #33. |
| #35 Cetogênico | Pendente | Sem implementação específica | Depende de #33. |
| #36 Renal | Pendente | Sem implementação específica | Depende de #33. |
| #37 Bariátrico | Pendente | Sem implementação específica | Depende de #33. |
| #38 Gestação/lactação | Pendente | Sem implementação específica | Depende de #33. |
| #39 Pediatria/avançadas | Pendente | Sem implementação específica | Depende de #33. |

## Fronteira de execução recomendada

1. **#8**: separar consultas essenciais e opcionais no `PatientPortal`, guardar falha por módulo e adicionar teste de regressão da marca indisponível.
2. **#9**: extrair somente os estados visuais que #8 realmente reutilizar, sem criar uma biblioteca nova de componentes.
3. **#10**: fechar o pipeline de catálogo com staging de importação, validação e publicação, reaproveitando as entidades e constraints já existentes.
4. **#11 e #13 em paralelo**: busca cultural/renders e edição de plano usam bases diferentes após #10; ambos preparam #15.
5. **#12, #14 e #15**: receitas, versões e motor de substituições. Só depois seguir para diário, fila e metas (#16–#22).

## Verificação realizada

- GitHub: issues #7–#39 abertas em 24/07/2026.
- Worktree: há alterações não commitadas, tratadas como evidência de trabalho em curso, não como entrega concluída.
- Evidência de testes encontrada em Vitest para portal/catálogo/modelos/exportação e em pgTAP para catálogo, publicação, progresso, fila e RLS. Esta auditoria não executou a suíte nem migrations; portanto ela não afirma que o ambiente remoto está validado.
