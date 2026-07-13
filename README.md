# BSNutri

Planejador e controlador de planos alimentares para profissionais, clínicas e pacientes. O piloto usa React, TypeScript, Vite, Supabase e GitHub Pages.

## Requisitos

- Node.js 22
- npm
- Supabase CLI
- Docker Desktop apenas para executar a stack e os testes SQL localmente

## Configuração local

```bash
npm ci
copy .env.example .env.local
```

Preencha `.env.local` com os dados públicos de **Project Settings > API** no Supabase:

```env
VITE_SUPABASE_URL=https://SEU_PROJECT_REF.supabase.co
VITE_SUPABASE_ANON_KEY=SUA_CHAVE_ANON_OU_PUBLISHABLE
```

Nunca coloque `service_role`, senha do banco, token pessoal ou dados reais de pacientes em arquivos `VITE_*`, commits, fixtures ou screenshots. Variáveis `VITE_*` são incorporadas ao frontend e ficam públicas.

Inicie a aplicação:

```bash
npm run dev
```

## Supabase CLI

O projeto remoto atual tem o ref `qjclholskxmtxqqentuz`.

```bash
supabase login
supabase link --project-ref qjclholskxmtxqqentuz
supabase migration list
supabase db push --dry-run
supabase db push
```

Use `db push --dry-run` antes de aplicar migrations remotas. A autenticação do CLI fica fora do repositório. Não compartilhe o access token.

Para trabalhar localmente, com Docker Desktop ativo:

```bash
supabase start
supabase db reset
supabase test db
supabase stop
```

`supabase db reset` apaga somente o banco local. Não execute comandos destrutivos contra o projeto remoto.

## Validação

```bash
npm run lint
npm test
npm run build
supabase test db
```

Os testes SQL em `supabase/tests` verificam o isolamento entre clínicas e as permissões dos papéis. Consulte também [docs/rls-test-matrix.md](docs/rls-test-matrix.md).

## GitHub Pages

O workflow `.github/workflows/deploy.yml` valida e publica a branch `main`. No GitHub, configure **Settings > Pages > Source** como **GitHub Actions**.

As variáveis do Supabase precisam existir durante o build. Cadastre em **Settings > Secrets and variables > Actions > Variables**:

- `VITE_SUPABASE_URL`
- `VITE_SUPABASE_ANON_KEY`

Quando o workflow passar a consumi-las, mantenha somente valores públicos nessas variáveis. GitHub Pages hospeda arquivos estáticos: autenticação, autorização e isolamento de dados dependem do Supabase RLS, nunca de esconder controles na interface.

## Fluxo de contribuição

1. Crie uma branch curta.
2. Adicione migrations incrementais. Não reescreva migrations já aplicadas.
3. Execute lint, testes, build e testes SQL.
4. Use apenas dados sintéticos.
5. Abra o pull request e aguarde o workflow.

