# Reproducao final do piloto BSNutri

Atualizado em sexta-feira, 17 de julho de 2026.

## Objetivo

Repetir a validacao final do MVP em outro computador com a menor ambiguidade possivel.

## Pre-requisitos

1. Node.js 22
2. npm
3. acesso ao repositorio
4. credenciais do projeto Supabase
5. navegador Chrome instalado

## Variaveis usadas na reproducao

Definir fora do repositorio:

1. `BSNUTRI_DB_URL`
2. `SUPABASE_ACCESS_TOKEN`
3. `PROJECT_REF=qjclholskxmtxqqentuz`

## Commit de referencia

1. `dabbf0c`

## Etapa 1. Validacao local

```powershell
npm ci
npm run lint
npm test
npm run build
```

Esperado:

1. lint verde
2. 9 testes verdes
3. build verde com `dist/`

## Etapa 2. Advisors de seguranca do banco

```powershell
npx --yes supabase@latest db advisors --type security --db-url $env:BSNUTRI_DB_URL
```

Esperado:

1. `No issues found`

## Etapa 3. Confirmacao minima do Auth

```powershell
$headers = @{ Authorization = \"Bearer $env:SUPABASE_ACCESS_TOKEN\" }
$resp = Invoke-RestMethod -Uri \"https://api.supabase.com/v1/projects/$env:PROJECT_REF/config/auth\" -Headers $headers -Method Get
@{
  password_min_length = $resp.password_min_length
  password_hibp_enabled = $resp.password_hibp_enabled
  mailer_autoconfirm = $resp.mailer_autoconfirm
  refresh_token_rotation_enabled = $resp.refresh_token_rotation_enabled
} | ConvertTo-Json
```

Esperado:

1. `password_min_length = 8`
2. `refresh_token_rotation_enabled = true`
3. `mailer_autoconfirm = false`
4. `password_hibp_enabled = false`

## Decisao de hardening do piloto

1. `SECURITY DEFINER` e permissoes de execucao foram aceitas para o MVP porque o advisor remoto de seguranca retornou sem achados.
2. `password_min_length` foi elevado para `8`.
3. `password_hibp_enabled` ficou `false` por decisao de piloto.
4. Base oficial da decisao:
   a documentacao atual do Supabase informa que leaked password protection existe no Pro Plan ou acima.
5. Compensacoes aceitas no MVP:
   email com confirmacao obrigatoria,
   refresh token rotation ativa,
   sem anonymous auth,
   smoke publicado validado nos 3 papeis.

## Etapa 4. Smoke publicado

Abrir:

1. `https://psibrunosg.github.io/bsnutri/`

Entrar com:

1. `mvp2.profissional@teste.com`
2. `mvp2.recepcao@teste.com`
3. `mvp2.paciente@teste.com`

Esperado:

1. `profissional` abre `Pacientes`
2. `recepcao` abre `Agenda e adesão`
3. `paciente` abre `Olá, Paciente`
4. nenhuma chamada indevida de `claim_patient_access`
5. nenhum erro de rede nas 3 jornadas

## Criterio de encerramento

Pode chamar de MVP encerrado quando:

1. etapas 1 a 4 baterem com o esperado
2. o deploy publicado refletir o commit de referencia ou commit posterior equivalente
3. nenhuma nova regressao aparecer em banco, auth ou UI principal
