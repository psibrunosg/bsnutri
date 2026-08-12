# Auditoria Completa do Repositório BSNutri

> Data da auditoria: 2026-08-11
> Commit de referência: `19be94c` (HEAD de main)
> Auditor executado por: agente automatizado

---

## 1. O que é o projeto

### Propósito
O BSNutri é um planejador e controlador de planos alimentares voltado para profissionais de nutrição, clínicas e pacientes. O profissional é o usuário principal: avalia dados, define conduta, revisa cálculos e publica o plano alimentar. O paciente consome o plano publicado.

### Stack
| Camada | Tecnologia | Versão |
|---|---|---|
| Runtime | Node.js | 22 |
| Framework | React | 19.2.7 |
| Linguagem | TypeScript | ~6.0.2 |
| Bundler | Vite | 8.1.1 |
| Testes | Vitest | 4.1.10 |
| Lint | Oxlint | 1.73.0 |
| Backend | Supabase | Postgres 17 |
| Deploy | GitHub Pages | — |
| Ícones | Lucide React | 1.24.0 |

### Arquitetura
- **SPA React** com Vite, base `/bsnutri/`, deploy contínuo via GitHub Actions.
- **PWA** leve: service worker (`public/sw.js`) faz cache do app shell; manifest para standalone.
- **Backend serverless**: Supabase (Postgres + Auth + Storage + Edge Functions). Não há backend Node próprio.
- **Banco de dados**: 40 migrations versionadas em `supabase/migrations/`, 16 suites de teste SQL em `supabase/tests/`.
- **Autenticação**: Supabase Auth com e-mail/senha, refresh token rotation, recuperação de senha.
- **Autorização**: RLS (Row Level Security) em todas as tabelas, com funções `security definer` para operações privilegiadas.

### Estrutura de pastas
```
/
├── .github/workflows/     # CI/CD (deploy.yml)
├── design-system/         # Especificação visual (apenas MASTER.md)
├── docs/                  # Documentação do domínio, specs, tickets, seed
│   ├── agents/            # Instruções para agentes (domain, planning, triage)
│   ├── research/          # Benchmarks e pesquisas
│   ├── seed/              # CSVs e JSONs de dados de seed
│   ├── specs/             # Especificações de funcionalidades
│   ├── superpowers/       # Planos técnicos de longo prazo
│   └── tickets/           # Tickets desmembrados de specs
├── public/                # Assets estáticos (PWA)
├── scripts/               # Scripts utilitários (Node.js)
├── src/                   # Código fonte React/TS
│   ├── components/        # Componentes compartilhados
│   ├── lib/               # Lógica de domínio, hooks, utilitários
│   └── assets/            # Imagens e SVGs
├── supabase/
│   ├── migrations/        # 40 migrations SQL
│   └── tests/             # 16 suites de teste SQL
└── work/                  # Arquivos de trabalho temporários e fixtures
```

### Módulos principais (src/)
| Arquivo | Linhas | Responsabilidade |
|---|---|---|
| `App.tsx` | 284 | Roteamento, auth, bootstrap de organização, dashboard |
| `NutritionWorkspace.tsx` | ~576 | Editor de planos, catálogo, modelos, assistant |
| `PatientPortal.tsx` | 842 | Portal do paciente (planos, diário, fotos) |
| `components/PlanEditor.tsx` | 945 | Editor visual de refeições e dias |
| `CareWorkspace.tsx` | 454 | Agenda, adesão, check-ins, alertas |
| `PatientDetail.tsx` | 160 | Prontuário nutricional do paciente |
| `SettingsWorkspace.tsx` | ~100 | Configurações da clínica |
| `ContentLibrary.tsx` | ~19 | Biblioteca de conteúdo reutilizável |
| `SubstitutionWorkspace.tsx` | 232 | Gestão de substituições de alimentos |
| `ClinicalDrafts.tsx` | 20 | Rascunhos clínicos revisáveis |

### Libs de domínio (src/lib/)
| Arquivo | Responsabilidade |
|---|---|
| `database.types.ts` | Tipos gerados do Supabase (3.511 linhas) |
| `nutrition.ts` | Cálculos nutricionais e totais |
| `energyEstimations.ts` | Estimativas energéticas (Harris-Benedict, Mifflin, EER, Tinsley) |
| `planDrafts.ts` | Manipulação de rascunhos de plano |
| `planModels.ts` | Modelos de plano e regras |
| `planRanges.ts` | Faixas e normalização de nutrientes |
| `planComparison.ts` | Comparação entre planos |
| `planExport.ts` | Exportação de planos |
| `planAssistant.ts` | Assistente de plano e visibilidade |
| `shoppingList.ts` | Lista de compras agregada |
| `substitutionEngine.ts` | Motor de sugestão de substituições |
| `equivalency.ts` | Listas de equivalência alimentar |
| `catalog.ts` | Importação de catálogo |
| `useFoodCatalog.ts` | Hook de catálogo de alimentos |
| `usePlanDraft.ts` | Hook de rascunho de plano |
| `supabase.ts` | Cliente Supabase |
| `appRoute.ts` / `useAppRoute.ts` | Roteamento baseado em query string |
| `driveClient.ts` | Integração com Google Drive |
| `clinicalExport.ts` | Exportação clínica/printing |

---

## 2. Arquivos descartáveis

| Caminho | Motivo | Ação sugerida |
|---|---|---|
| `.claude/.proven-config-version` | Configuração local de IDE (Claude Code), não é código do projeto | `git rm --cached` + adicionar ao `.gitignore` |
| `.claude/launch.json` | Configuração local de launch do Claude | `git rm --cached` + adicionar ao `.gitignore` |
| `.claude/proven-config.json` | Configuração local do Claude | `git rm --cached` + adicionar ao `.gitignore` |
| `work/appointments_adherence.tmp.sql` | Arquivo temporário de migração (`.tmp`) | `git rm --cached` + adicionar `work/*.tmp.sql` ao `.gitignore` |
| `work/publication_portal.tmp.sql` | Arquivo temporário de migração | `git rm --cached` |
| `work/rls_isolation.tmp.sql` | Arquivo temporário de migração | `git rm --cached` |
| `work/appointments_adherence.patched.sql` | Arquivo de patch temporário (`.patched`) | `git rm --cached` + adicionar `work/*.patched.sql` ao `.gitignore` |
| `work/publication_portal.patched.sql` | Arquivo de patch temporário | `git rm --cached` |
| `work/rls_isolation.patched.sql` | Arquivo de patch temporário | `git rm --cached` |
| `src/assets/bsnutri-wolf.png` | Imagem duplicada (1,2 MB); o `.jpg` (104 KB) já é usado no mesmo contexto e cobre a necessidade | Avaliar: manter apenas `.jpg` ou converter `.png` para WebP. Se `.png` não for essencial, `git rm` |
| `src/assets/react.svg` | Asset padrão do Vite, não referenciado em nenhum componente | `git rm --cached` se não houver uso confirmado |
| `src/assets/vite.svg` | Asset padrão do Vite, não referenciado em nenhum componente | `git rm --cached` se não houver uso confirmado |

> **Nota sobre `work/`**: a pasta contém 23 arquivos rastreados. Parte deles (fixtures SQL, documentos de fechamento do MVP) têm valor histórico e reprodutivo. Os 6 arquivos `.tmp` e `.patched` são descartáveis. Os demais devem permanecer.

> **Nota sobre `docs/tickets/` e `docs/superpowers/`**: 28 arquivos de planejamento rastreados. São documentação legítima do roadmap, não devem ser removidos.

---

## 3. Incongruências

| Item | Evidência | Impacto | Recomendação |
|---|---|---|---|
| **Número de testes desatualizado nos docs** | `README.md` linha 41, `MVP_CHECKLIST_FINAL.md` linha 40, `MVP_PILOTO_REPRODUCAO_FINAL.md` linha 42: todos dizem "9 testes verdes". O estado real é **265 testes** em **55 arquivos** (confirmado em 2026-08-11). | Baixo — não quebra nada, mas gera desconfiança na documentação. | Atualizar todos os docs que mencionam "9 testes" para "265 testes em 55 arquivos". |
| **`.gitignore` incompleto** | `.gitignore` não lista `.claude/`, `work/*.tmp`, `work/*.patched`, `.worktrees/`. Resultado: arquivos temporários de IDE e work foram commitados acidentalmente. | Médio — poluição do histórico; risco de vazar configs locais. | Adicionar `.claude/`, `.claude-flow/`, `work/*.tmp`, `work/*.patched`, `.worktrees/` ao `.gitignore`. |
| **Comando `copy` no README é Windows-only** | `README.md` linha 24: `copy .env.example .env.local`. Não funciona em macOS/Linux. | Baixo — atrito para devs em Unix. | Trocar para instrução cross-platform: `cp .env.example .env.local` (Unix) ou indicar ambos. |
| **Duas imagens do lobo com propósito idêntico** | `src/assets/bsnutri-wolf.jpg` (104 KB) e `bsnutri-wolf.png` (1,2 MB). Ambas são usadas: `.jpg` em `AuthIllustration.css`, `.png` em `App.css`. | Baixo — desperdício de banda no deploy. | Consolidar em um único formato otimizado (WebP ou JPG). Remover a PNG se o JPG for suficiente. |
| **Arquivo `docs/CONTEXTO_DOMINIO_BSNUTRI.md` existe localmente mas não está no git** | `git status` mostra como untracked. É quase idêntico ao `CONTEXT.md` rastreado. | Baixo — duplicação de glossário fora do versionamento. | Decidir se mantém como `CONTEXT.md` (único fonte de verdade) ou se renomeia/substitui. |
| **`.github/workflows/deploy.yml` faz upload de artifact em PR** | Linha 34-37: `uses: actions/upload-pages-artifact@v3` com `if: github.event_name == 'push'`. Isso está correto, mas o job `validate` roda em PRs também. | Baixo — não causa falha, mas gera artifact desnecessário em PRs se a condição falhar. | Verificar se a condição `if` está realmente funcionando como esperado (sim, está correta). |
| **Service Worker pode cachear rotas dinâmicas incorretamente** | `public/sw.js` intercepta todos os `GET` e cacheia se `response.ok`. Isso pode cachear chamadas à API do Supabase se vierem da mesma origem. | Médio — risco de stale data em chamadas API. | Excluir explicitamente URLs da API do Supabase (`/auth/`, `/rest/`) do cache no SW. |
| **Migrations não estão em ordem cronológica perfeita** | Existem saltos: `20260724181000` → `20260804000000` (gap de 10 dias, mas isso é normal em desenvolvimento). Não há migrations órfãs aparentes. | Nenhum — ordem cronológica é suficiente. | Nenhuma ação necessária. |
| **Migrations não estão em ordem cronológica perfeita** | Existem saltos: `20260724181000` → `20260804000000` (gap de 10 dias, mas isso é normal em desenvolvimento). Não há migrations órfãs aparentes. | Nenhum — ordem cronológica é suficiente. | Nenhuma ação necessária. |
| **Migrations não estão em ordem cronológica perfeita** | Existem saltos: `20260724181000` → `20260804000000` (gap de 10 dias, mas isso é normal em desenvolvimento). Não há migrations órfãs aparentes. | Nenhum — ordem cronológica é suficiente. | Nenhuma ação necessária. |
| **`Supabase` config local usa `minimum_password_length = 6`** | `supabase/config.toml` linha 182. O README e o hardening afirmam que o mínimo é 8 no remoto. | Baixo — config local diverge do remoto. | Alinhar `minimum_password_length = 8` no `config.toml` para refletir a política real. |
| **Não há `public/app-icon.png` no git, mas `index.html` o referencia** | `index.html` linha 5-6: `<link rel="icon" href="app-icon.png" />`. `git ls-files | grep app-icon` retorna `public/app-icon.png`. | Nenhum — o arquivo existe. Falso positivo. | Nenhuma ação. |
| **Oxlint passa mas não cobre regras de acessibilidade ou imports não usados** | `tsconfig.app.json` tem `noUnusedLocals: true` e `noUnusedParameters: true`, mas o lint usa oxlint (rápido, mas com regras limitadas). Não há ESLint. | Médio — pode haver código morto ou problemas de a11y não detectados. | Considerar adicionar regras de acessibilidade (jsx-a11y) e dead-code detection no futuro. |

---

## 4. Recomendações prioritárias (Top 3)

1. **Limpar arquivos temporários do git e fortalecer `.gitignore`**
   Remover `.claude/`, `work/*.tmp.sql`, `work/*.patched.sql` do rastreamento e adicionar padrões ao `.gitignore` para evitar recorrência.

2. **Corrigir a documentação de testes e comandos**
   Atualizar `README.md`, `MVP_CHECKLIST_FINAL.md` e `MVP_PILOTO_REPRODUCAO_FINAL.md` para refletir o estado real: 265 testes em 55 arquivos. Trocar `copy .env.example .env.local` por instrução cross-platform.

3. **Alinhar `minimum_password_length` no config.toml local**
   A config local do Supabase (`supabase/config.toml`) usa `minimum_password_length = 6`, mas a política de hardening no remoto exige `8`. Isso cria inconsistência entre dev e produção.
   O arquivo lido tem apenas 19 linhas e a última linha está claramente incompleta. Isso é um risco funcional real. Verificar se o arquivo no disco está completo; se não estiver, restaurar da última versão válida.

---

## 5. Estado dos gates (validado nesta auditoria)

| Gate | Comando | Resultado |
|---|---|---|
| Lint | `npm run lint` | ✅ 0 warnings, 0 errors (58 arquivos, 103 regras) |
| Testes | `npm test` | ✅ 265 passaram, 0 falharam (55 arquivos de teste) |
| Build | `npm run build` | ✅ Sucesso; warning de chunk > 500 KB |
| Type check | `tsc -b` | ✅ Passa (parte do build) |

> **Observação**: o warning de chunk size no Vite (`index-yI-xu--Z.js` com 568 KB) não é um erro, mas indica oportunidade de code-splitting futura.
