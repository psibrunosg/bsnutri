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

Status: pendente

## Task 5 — Editor clínico e publicação imutável

Status: pendente

## Task 6 — Portal real do paciente

Status: pendente

## Task 7 — Importador legado e remoção de duplicatas

Status: pendente. `src/lib/store.tsx`, `src/lib/data.ts` e `src/lib/types.ts`
ainda existem porque `PlanBuilder`, `Templates` e `Portal` dependem deles até as
Tasks 5 e 6.

## Task 8 — Qualidade, documentação e corte

Status: pendente
