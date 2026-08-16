# Integrar o redesign V2 ao aplicativo real

## Objetivo

Transformar o redesign publicado no aplicativo BSNutri conectado ao Supabase, preservando a linguagem visual nova e restaurando o domínio clínico, a autenticação, as políticas de acesso, a publicação imutável e o portal do paciente.

## Restrições globais

- Base visual: `b1fa174`; base funcional seletiva: `5f2fe2c`.
- Uma única entrega pública. O Pages atual não será alterado até todos os gates passarem.
- Escopo: profissional clínico e paciente. Recepção, agenda, equipe e administração ficam fora.
- Editor completo a partir de 1024 px. Em 375 e 768 px, autenticação, navegação, consulta e portal não podem ter overflow.
- Não criar segundo editor, segundo modelo de domínio ou segundo pipeline de PDF.
- Nenhuma credencial profissional ou dado do banco pode ser incorporado ao bundle.
- Nenhum dado clínico pode permanecer em `localStorage`, exceto leitura controlada pelo importador legado.
- Modelos não aprovados, substituições não revisadas e versões não revisadas não podem ser publicados.
- Nutriente ausente continua ausente; nunca converter `null` em zero.
- Usar TDD para todo comportamento novo e preservar as verificações funcionais da base anterior.

## Task 1: Fundação técnica, executor e pipeline seguro

- Configurar Vitest para execução serial confiável no Windows/CI e restaurar `npm ci` com lockfile coerente.
- Remover `prebuild`, `scripts/sync-catalog.mjs`, `src/lib/realdata.ts` e credenciais profissionais do workflow.
- Restaurar cliente Supabase e tipos do commit funcional, eliminando o build-time export do catálogo.
- Adicionar verificação de artefato que rejeite credenciais, chaves de `localStorage` clínico e marcadores de dados sincronizados.
- Preservar URL e chave anônima como únicas variáveis Supabase do frontend.
- Testes: scripts/pipeline, cliente sem configuração, artefato sem dados incorporados.

## Task 2: Navegação, sessão e shell responsivo

- Restaurar `AppRoute`/`useAppRoute` e expandir para dashboard, pacientes, novo paciente, ficha, nutrição, modelos, conteúdo e portal.
- Restaurar autenticação, onboarding de organização, membership, vínculo do paciente e estados de erro explícitos.
- Adaptar o shell novo aos papéis reais; recepção recebe tela segura de indisponibilidade.
- Implementar menu móvel, foco visível, reduced motion e URLs sem conteúdo clínico.
- Testes: parse/serialize, voltar/avançar, erro de bootstrap, roteamento por papel e shell em viewport estreita.

## Task 3: Migração clínica e cadastro transacional

- Adicionar `patients.tags`, `anthropometry.hip_cm`, `anthropometry.arm_cm` e a RPC `create_patient_intake` SECURITY INVOKER.
- A RPC deriva autores de `auth.uid()`, gera código anônimo e grava paciente, avaliação, antropometria e auditoria em uma transação.
- Conectar o wizard visual, sem sexo padrão nem idade fixa, e separar cadastro de estimativa nutricional.
- Restaurar dashboard, busca, ficha, evolução, objetivos, restrições, exames, rascunhos e conteúdo clínico.
- Testes: SQL multi-organização, rollback transacional e fluxo UI de criar/reabrir paciente.

## Task 4: Catálogo e modelos revisáveis

- Consultar catálogo em runtime, 30 resultados por página, com debounce e valores ausentes preservados.
- Listar 24 modelos por página sem snapshot; buscar detalhes sob demanda.
- Adicionar status/proveniência/validação a `plan_templates`; backfill como `needs_review`.
- Bloquear aplicação de modelo não aprovado na UI e no RPC `apply_plan_template_to_patient`.
- Testes: paginação, debounce, null sem zero, backfill, isolamento e bloqueio server-side.

## Task 5: Editor clínico e publicação imutável

- Integrar o visual novo ao `usePlanDraft`/`PlanEditor` funcional, em três regiões e um dia por vez.
- Reusar `save_plan_draft`, `review_plan_version` e `publish_plan_version`.
- Restaurar autosave, versões, metas, visibilidade, substituições revisadas, alertas e bloqueios de publicação.
- Copiar dia exige confirmação quando o destino contém conteúdo.
- Consolidar PDF para usar somente versão publicada e substituições prescritas/revisadas.
- Testes: rascunho independente, autosave, copiar dia, revisão/publicação e imutabilidade histórica.

## Task 6: Portal real do paciente

- Derivar paciente da sessão/RLS e mostrar somente versão publicada vigente.
- Restaurar resumo de hoje, água, metas, check-ins, diário, fotos, compras, pré-consulta, conteúdos e solicitações de substituição.
- Manter resultados de exames/notas profissionais privados salvo compartilhamento explícito.
- Garantir falhas parciais por módulo e persistência após reload.
- Testes: paciente, responsável, isolamento, check-ins, trocas e ausência de rascunhos.

## Task 7: Importador legado e remoção de duplicatas

- Detectar `bsnutri-patients`/`bsnutri-plans` após autenticação, sem upload automático.
- Exibir contagem/prévia, importar como `prototype-v2` em rascunho, relatar falhas e limpar apenas com confirmação.
- Remover store/tipos/seeds do protótipo, módulos `export {}`, testes `expect(true)` e pipelines duplicados.
- Testes: preview, importação parcial, descarte e preservação do armazenamento em erro.

## Task 8: Qualidade, documentação e corte

- Restaurar/substituir as verificações funcionais da base anterior e adicionar Playwright/axe às jornadas críticas.
- Lazy-load de editor, gráfico e PDF; remover Framer Motion quando só houver transição simples.
- Atender: entrada menor que 350 kB, nenhum chunk maior que 500 kB, 24 modelos/30 alimentos iniciais e zero overflow em 375/768/1024/1440.
- Atualizar design system, README, auditoria, status, issues e handoff.
- Rodar `npm ci`, lint, testes, build, SQL, Playwright, audit, artifact check e `git diff --check`.
- Inserir SHA no artefato e preparar rollback por redeploy, sem publicar antes da aprovação final.
