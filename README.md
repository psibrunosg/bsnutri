# BSNutri

Planejador e controlador de planos alimentares para profissionais, clinicas e pacientes.

Stack atual:

1. React
2. TypeScript
3. Vite
4. Supabase
5. GitHub Pages

## Requisitos

1. Node.js 22
2. npm
3. Supabase CLI
4. Docker Desktop apenas para stack local e testes SQL

## Configuracao local

```bash
npm ci
copy .env.example .env.local
```

Preencha `.env.local` com os dados publicos de **Project Settings > API** no Supabase:

```env
VITE_SUPABASE_URL=https://SEU_PROJECT_REF.supabase.co
VITE_SUPABASE_ANON_KEY=SUA_CHAVE_ANON_OU_PUBLISHABLE
```

Nunca coloque `service_role`, senha do banco, token pessoal ou dados reais de pacientes em variaveis `VITE_*`, commits, fixtures ou screenshots.

Para rodar localmente:

```bash
npm run dev
```

## Supabase

Projeto remoto atual:

1. ref: `qjclholskxmtxqqentuz`

Fluxo normal de migrations:

```bash
supabase login
supabase link --project-ref qjclholskxmtxqqentuz
supabase migration list
supabase db push --dry-run
supabase db push
```

Regras:

1. usar `supabase db push --dry-run` antes de aplicar no remoto
2. nao reescrever migrations ja aplicadas
3. usar apenas dados sinteticos
4. nao compartilhar access token, service role ou senha do banco

Stack local com Docker:

```bash
supabase start
supabase db reset
supabase test db
supabase stop
```

`supabase db reset` apaga somente o banco local.

## Validacao local

Rodar sempre antes de publicar:

```bash
npm run lint
npm test
npm run build
```

Se houver mudanca de banco ou policy, rodar tambem:

```bash
supabase test db
```

## GitHub Pages

O deploy usa `.github/workflows/deploy.yml`.

Em push para `main`, o workflow executa:

1. `npm ci`
2. `npm run lint`
3. `npm test`
4. `npm run build`
5. upload de `dist`
6. deploy no GitHub Pages

Secrets publicos esperados no GitHub Actions:

1. `VITE_SUPABASE_URL`
2. `VITE_SUPABASE_ANON_KEY`

No Supabase, manter:

1. `https://psibrunosg.github.io/bsnutri/` em `Site URL`
2. `https://psibrunosg.github.io/bsnutri/` em `Redirect URLs`

## Fechamento do MVP

O MVP so pode ser chamado de concluido quando estas 3 jornadas estiverem provadas no deploy publicado:

1. `profissional` entra, acessa paciente e opera plano sem erro bloqueante
2. `paciente` entra e consome somente conteudo publicado
3. `recepcao` entra e opera agenda sem navegar em dados clinicos

### Ordem final de validacao

1. rodar `npm run lint`
2. rodar `npm test`
3. rodar `npm run build`
4. publicar a versao atual em `main`
5. esperar os jobs `validate` e `deploy` verdes
6. abrir `https://psibrunosg.github.io/bsnutri/`
7. repetir o smoke com:
   `mvp2.profissional@teste.com`
   `mvp2.recepcao@teste.com`
   `mvp2.paciente@teste.com`

### Evidencia minima para aprovar

1. `profissional` entra e ve dashboard ou paciente sem erro bloqueante
2. `recepcao` cai direto em agenda e sem menu clinico
3. `paciente` entra, ve plano vigente e nao chama `claim_patient_access` sem necessidade
4. o deploy publicado reflete o frontend local mais recente
5. `lint`, `test` e `build` continuam verdes
6. as suites SQL centrais continuam validadas

### Estado real em sexta-feira, 17 de julho de 2026

1. `profissional`: provado no deploy publicado
2. `paciente`: provado no deploy publicado
3. `recepcao`: provado no deploy publicado
4. `lint`, `test` e `build`: provados localmente
5. suites SQL centrais: provadas
6. hardening minimo do Supabase: fechado
7. reproducao final do piloto: consolidada

### Artefatos de apoio

1. `docs/MVP_INDEX.md`
2. `docs/MVP_AUDITORIA_STATUS.md`
3. `docs/MVP_CHECKLIST_FINAL.md`
4. `docs/MVP_PILOTO_REPRODUCAO_FINAL.md`
5. `work/MVP_FECHAMENTO_FINAL.md`
6. `G:\Meu Drive\0.Jarvis\11_handoffs\bsnutri_17_07_2026_0925.md`

## Fluxo de contribuicao

1. criar branch curta
2. adicionar migrations incrementais
3. validar lint, testes, build e testes SQL quando aplicavel
4. publicar somente dados sinteticos
5. abrir pull request ou publicar em `main` quando o alvo for deploy do piloto
