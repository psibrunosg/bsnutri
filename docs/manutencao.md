# Guia de Manutenção do BSNutri

> Última validação: 2026-08-11
> Commit de referência: `19be94c`

---

## 1. Visão rápida

### Stack
| Camada | Tecnologia |
|---|---|
| Frontend | React 19 + TypeScript 6 + Vite 8 |
| Testes | Vitest 4 + jsdom + Testing Library |
| Lint | Oxlint 1.73 |
| Backend | Supabase (Postgres 17, Auth, Storage) |
| Deploy | GitHub Pages via GitHub Actions |
| Ícones | Lucide React |

### Deploy
- URL pública: `https://psibrunosg.github.io/bsnutri/`
- Workflow: `.github/workflows/deploy.yml`
- Gatilho: push para `main`
- Secrets do Actions: `VITE_SUPABASE_URL`, `VITE_SUPABASE_ANON_KEY`

### Mapa de documentação
| Documento | Para quê |
|---|---|
| `README.md` | Setup local, fluxo Supabase, validação, contribuição |
| `CONTEXT.md` | Glossário do domínio (profissional, paciente, publicação, etc.) |
| `docs/agents/planning-workflow.md` | Workflow de planejamento e desenvolvimento autônomo |
| `docs/agents/issue-tracker.md` | Convenções do GitHub Issues |
| `docs/agents/triage-labels.md` | Vocabulário de labels |
| `docs/auditoria-projeto.md` | Auditoria completa do repositório |
| `docs/MVP_*.md` | Artefatos de fechamento do MVP (status, checklist, reprodução) |
| `docs/nutrition-data-policy.md` | Política de dados nutricionais |
| `design-system/bsnutri/MASTER.md` | Paleta, tipografia, componentes, motion |

---

## 2. Comandos do dia a dia

```bash
# Instalar dependências
npm ci

# Servidor de desenvolvimento
npm run dev

# Validar antes de qualquer push
npm run lint      # oxlint
npm test          # vitest run
npm run build     # tsc + vite build

# Preview do build local
npm run preview

# Testes SQL (requer Supabase CLI + Docker)
supabase start
supabase db reset
supabase test db
supabase stop
```

### Armadilhas conhecidas

1. **O lint é oxlint, não ESLint.**
   Oxlint é rápido mas não cobre acessibilidade (jsx-a11y) nem regras de imports não usados. O TypeScript (`noUnusedLocals`, `noUnusedParameters`) pega parte do código morto, mas não tudo. Se adicionar ESLint no futuro, valide que não quebra o CI.

2. **O build falha se `tsc -b` encontrar erros.**
   `npm run build` roda `tsc -b && vite build`. Qualquer erro de tipo bloqueia o deploy. Corrija antes de push.

3. **O Supabase local usa `minimum_password_length = 6` por padrão.**
   O remoto está com `8`. Se testar auth localmente, lembre-se de que a política do remoto é mais restritiva.

4. **Git worktrees existem em `.worktrees/`.**
   Há worktrees ativos (`fundacao-tecnica-tokens-e-tipos`, `stabilize-weekly-plan-release`). Não os delete sem verificar se há trabalho não commitado.

5. **O service worker cacheia tudo que responde 200.**
   `public/sw.js` intercepta todos os GET e cacheia se `response.ok`. Se a API do Supabase estiver na mesma origem, ela será cacheada. Ao tocar no SW, exclua explicitamente `/auth/` e `/rest/`.

6. **Migrations são incrementais e não devem ser reescritas.**
   Uma vez aplicadas no remoto, não edite. Crie uma nova migration com correção.

---

## 3. Estado atual dos gates

Validado em 2026-08-11 no commit `19be94c`:

| Gate | Comando | Resultado |
|---|---|---|
| Lint | `npm run lint` | ✅ 0 warnings, 0 errors (58 arquivos, 103 regras) |
| Testes | `npm test` | ✅ 265 passaram, 0 falharam (55 arquivos de teste) |
| Build | `npm run build` | ✅ Sucesso; warning de chunk > 500 KB |
| Type check | `tsc -b` | ✅ Passa (parte do build) |

> ⚠️ O warning de chunk size no Vite (`index-yI-xu--Z.js` com 568 KB) não é erro, mas indica oportunidade de code-splitting futura.

---

## 4. Dívidas vivas

Cada item: o que é, onde está, o que fazer ao tocar na área.

### 1. Separação entre estimativa nutricional e meta nutricional
- **O que é:** O glossário (`CONTEXT.md`) define "estimativa nutricional" como resultado calculado por método identificado e "meta nutricional" como valor escolhido pelo profissional. O código hoje trata tudo como `targets: Record<string, number>` sem rastro de método, versão ou fonte.
- **Onde:** `src/NutritionWorkspace.tsx`, `src/lib/planModels.ts`.
- **Ao tocar:** Não confunda estimativa automática com meta manual. Se adicionar cálculo automatizado, crie uma entidade separada para a estimativa (com protocolo, entradas, premissas) e consuma-a como ponto de partida para a meta.

### 2. Isolamento por organização depende de `.eq()` no client
- **O que é:** O frontend filtra dados com `.eq('organization_id', ...)` em vários pontos (`App.tsx`, `NutritionWorkspace.tsx`, `PatientDetail.tsx`). A segurança real vem das RLS no Postgres, mas o padrão de dupla defesa (client + RLS) precisa ser mantido.
- **Onde:** Todos os `supabase.from(...).eq('organization_id', ...)`.
- **Ao tocar:** Nunca remova o `.eq('organization_id', ...)` do client sem garantir que a RLS equivalente está ativa e testada (`supabase/tests/rls_isolation.test.sql`).

### 3. Duas imagens do lobo no repo
- **O que é:** `bsnutri-wolf.jpg` (104 KB) e `bsnutri-wolf.png` (1,2 MB) servem ao mesmo propósito visual. Ambas são usadas em CSS diferentes.
- **Onde:** `src/assets/bsnutri-wolf.*`, `src/App.css`, `src/AuthIllustration.css`.
- **Ao tocar:** Consolide em um único formato otimizado (WebP ou JPG). Remova a PNG se o JPG for suficiente para reduzir o tamanho do bundle.

### 4. Service Worker pode cachear API
- **O que é:** `public/sw.js` intercepta todos os GET. Se a API do Supabase estiver na mesma origem, chamadas `/auth/` e `/rest/` podem ser cacheadas indevidamente.
- **Onde:** `public/sw.js`.
- **Ao tocar:** Adicione early-return para URLs da API antes do cache.

### 5. Oxlint não cobre acessibilidade
- **O que é:** Não há ESLint nem regras jsx-a11y. Problemas de acessibilidade (ex: labels faltantes, contrastes) não são detectados automaticamente.
- **Onde:** Todo o `src/`.
- **Ao tocar:** Faça revisão manual de a11y ao alterar componentes interativos. Verifique `cursor: pointer`, focus visível, labels associadas, contrastes.

### 6. `ContentLibrary.tsx` está densamente compactado
- **O que é:** O componente tem apenas 19 linhas com JSX monolítico. Isso dificulta manutenção.
- **Onde:** `src/ContentLibrary.tsx`.
- **Ao tocar:** Se precisar adicionar funcionalidade, considere refatorar para múltiplas funções ou subcomponentes antes de crescer o arquivo.

### 7. Configuração local do Supabase diverge do remoto
- **O que é:** `supabase/config.toml` usa `minimum_password_length = 6`, mas o remoto usa `8`.
- **Onde:** `supabase/config.toml` linha 182.
- **Ao tocar:** Alinhe a config local com o remoto para evitar surpresas ao testar auth.

---

## 5. Convenções do repositório

### Workflow de desenvolvimento
1. Criar branch curta a partir de `main`.
2. Implementar a menor fatia funcional com teste quando houver lógica não trivial.
3. Validar localmente: `npm run lint && npm test && npm run build`.
4. Se houver mudança de schema ou policy: `supabase test db`.
5. Commit com mensagem descritiva (ver abaixo).
6. Push e abrir PR (ou merge direto em `main` se for deploy de piloto).

### Commits
Use mensagens no imperativo, em português:
- `feat: adiciona ...`
- `fix: corrige ...`
- `test: cobre ...`
- `docs: atualiza ...`
- `chore: remove ...`
- `ci: ajusta ...`

### Issues
- Usamos GitHub Issues (`psibrunosg/bsnutri`).
- Labels: `needs-triage`, `needs-info`, `ready-for-agent`, `ready-for-human`, `wontfix`.
- Não usamos PRs como surface de triagem.

---

## 6. Checklist pré-commit

Antes de qualquer push para `main`, execute e confirme:

- [ ] `npm run lint` passa sem warnings
- [ ] `npm test` passa (265 testes em 55 arquivos — atual se houver mudança)
- [ ] `npm run build` gera `dist/` sem erros
- [ ] Se mudou banco: `supabase test db` passa
- [ ] Não há dados reais de pacientes em commits
- [ ] Não há credenciais (`service_role`, tokens) em commits
- [ ] Não há arquivos `.tmp`, `.patched`, `.local` de IDE sendo commitados
- [ ] Documentação foi atualizada se houver mudança de comportamento

---

## 7. Regras para manter este documento atualizado

1. **Data de validação:** Ao rodar `lint/test/build` e confirmar que os gates estão verdes, atualize a seção "Estado atual dos gates" com a data e o commit.
2. **Novas dívidas:** Se durante o desenvolvimento você encontrar um padrão problemático que não pode ser resolvido na fatia atual, adicione-o à seção "Dívidas vivas" com o template: o que é / onde / o que fazer ao tocar.
3. **Remover dívidas resolvidas:** Quando uma dívida for paga (refatoração, correção, ou decisão consciente de aceitar), mova-a para uma seção "Dívidas resolvidas" no final do documento com data e commit.
4. **Novos comandos ou armadilhas:** Se o workflow mudar (nova dependência, novo script, novo gate), atualize as seções 2 e 6 imediatamente.
5. **Não deixe para depois:** Atualizações neste documento devem fazer parte do mesmo commit que introduz a mudança relevante.
