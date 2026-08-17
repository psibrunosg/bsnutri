# BSNutri Agent Guide

Use this file for repo-level agent instructions.

## Regra de banco de dados (obrigatória)

Toda alteração de banco passa por migration versionada em `supabase/migrations/` e
é aplicada **no local e no remoto**. Nunca só no remoto.

- Aplique com `npm run db:push`. Ele confere a stack local antes de tocar no
  remoto e recusa a execução se o Docker estiver fora do ar. Não contorne com
  `supabase db push` direto.
- Nunca altere o banco pelo painel do Supabase. O que não está em migration não
  chega ao banco local nem a `supabase/schema.sql`.
- `supabase/schema.sql` é a cópia local versionada da estrutura. Regenere com
  `npm run db:dump` (o `db:push` já faz isso no fim). Só estrutura: dado de
  paciente jamais entra no repositório, que é público.
- Antes de fechar uma tarefa que mexeu em banco, rode `npm run db:verify` e
  confirme paridade entre remoto, local e diretório.
- Motivo e alternativas descartadas: `docs/adr/0001-paridade-entre-banco-remoto-e-copia-local.md`.
  Mapa do que ainda prende o projeto ao Supabase: `docs/portabilidade-postgres.md`.

## Agent skills

### Issue tracker

Issues and PRDs are tracked in GitHub Issues for `psibrunosg/bsnutri`. See `docs/agents/issue-tracker.md`.

### Triage labels

Use the default Matt Pocock triage label vocabulary. See `docs/agents/triage-labels.md`.

### Domain docs

This is a single-context repo: read root domain docs and root ADRs when they exist. See `docs/agents/domain.md`.

### Planning workflow

For every development or audit plan, read and follow `docs/agents/planning-workflow.md`.
