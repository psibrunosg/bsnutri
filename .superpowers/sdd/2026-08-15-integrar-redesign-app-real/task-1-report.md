# Task 1: Fundação técnica, executor e pipeline seguro

## Escopo entregue

- Vitest configurado de forma serial com `vmThreads`, sem paralelismo entre arquivos e com um worker.
- Cliente e tipos do Supabase restaurados do commit `5f2fe2c`.
- Removidos o `prebuild`, o sincronizador autenticado e `src/lib/realdata.ts`.
- O workflow voltou a usar `npm ci` e não expõe mais as credenciais de profissional. O build recebe apenas a URL e a chave anônima do Supabase.
- O build termina em `verify:artifact`, que falha quando encontra credenciais, chaves de armazenamento clínico ou marcadores do catálogo sincronizado.
- O store temporário deixou de persistir pacientes ou planos no navegador. Os consumidores do módulo removido usam apenas os dados de demonstração não clínicos já existentes, sem catálogo sincronizado nem listas de equivalência incorporadas.
- `package-lock.json` foi regenerado e validado por `npm ci`.

## Arquivos alterados

- `.github/workflows/deploy.yml`
- `package.json`
- `package-lock.json`
- `vite.config.ts`
- `scripts/verify-build-artifact.mjs`
- `scripts/verify-build-artifact.test.ts`
- `src/lib/supabase.ts`
- `src/lib/supabase.test.ts`
- `src/lib/database.types.ts`
- `src/lib/data.ts`
- `src/lib/store.tsx`
- `src/lib/pdf.ts`
- `src/pages/PatientDetail.tsx`
- `src/pages/Portal.tsx`
- Removidos: `scripts/sync-catalog.mjs` e `src/lib/realdata.ts`.

## TDD: RED e GREEN

O comportamento que cada teste protege foi definido antes da implementação:

1. Sem variáveis públicas de Supabase, o cliente deve informar configuração ausente. A remoção anterior do cliente fazia a exportação resultar em `undefined`.
2. Um artefato contendo `bsnutri-patients` deve ser rejeitado.
3. Um artefato sem credenciais, armazenamento clínico ou marcadores de sincronização deve ser aceito.

### RED observado

Com os testes novos e antes do código de produção:

```text
npx vitest run src/lib/supabase.test.ts scripts/verify-build-artifact.test.ts --pool=vmThreads --no-file-parallelism --maxWorkers=1
3 testes falharam
- isSupabaseConfigured recebido como undefined, esperado false
- o verificador não existia e não reportava bsnutri-patients
- o verificador ausente retornava status 1 para um artefato seguro
```

### GREEN observado

Após restaurar o cliente e implementar o verificador:

```text
npm test -- src/lib/supabase.test.ts scripts/verify-build-artifact.test.ts
2 arquivos passaram, 3 testes passaram
```

## Verificação final

| Comando | Resultado |
| --- | --- |
| `npm ci --no-audit --no-fund` | passou, 268 pacotes instalados a partir do lockfile |
| `npm test` | passou, 22 arquivos e 25 testes |
| `npm run lint` | passou com 2 avisos preexistentes de Fast Refresh em `src/lib/store.tsx` |
| `npm run build` | passou e executou `verify:artifact` |
| `npm run verify:artifact` | passou para `dist` |
| busca dos seis marcadores proibidos em `dist` | nenhuma ocorrência |
| `git diff --check` | passou |

## Self-review

- O verificador examina recursivamente todos os arquivos do artefato e lista cada marcador e arquivo infrator antes de retornar código 1.
- A checagem é parte do script `build`, portanto também roda no workflow antes do upload do Pages.
- Não houve alteração do Pages, push ou uso de `npm audit fix --force`.

## Pendências e riscos

- O build informa um chunk de 1,19 MB acima de 500 kB. A divisão de chunks e o lazy loading são previstos para a Task 8.
- A substituição do store temporário pelo fluxo Supabase real permanece nas tarefas seguintes; esta tarefa só elimina sua persistência clínica e o conteúdo sincronizado do build.
