# ADR 0001 — Paridade entre o banco remoto e a cópia local versionada

- Status: aceito
- Data: 2026-08-16
- Contexto do projeto: BSNutri sobre Supabase (`qjclholskxmtxqqentuz`), repositório público

## Contexto

Até aqui o fluxo de banco era `supabase db push` contra o projeto remoto. A cópia
local (stack Docker) só era levantada quando alguém queria rodar `supabase test db`,
e ficava meses atrás do remoto sem que ninguém percebesse.

Isso cria dois riscos concretos:

1. **Aprisionamento.** O único banco íntegro é o do Supabase. Migrar para servidor
   próprio no futuro dependeria de conseguir extrair estrutura de um serviço
   gerenciado, com o projeto já em produção.
2. **Verdade única não verificável.** Sem uma cópia local em dia, ninguém consegue
   responder "o que exatamente existe no banco hoje" sem abrir o painel do Supabase.
   O diretório `supabase/migrations/` é a intenção; o remoto é o fato; e nada
   comparava os dois.

O dono do projeto pediu, textualmente, uma cópia local do banco e uma regra que
force a atualização do local sempre que o remoto for atualizado.

## Decisão

**Toda alteração de banco passa por migration versionada e é aplicada no local e
no remoto. Nunca só no remoto.**

Três decisões de apoio:

1. **`npm run db:push` é o único caminho de aplicação.** O script
   (`scripts/db-sync.mjs`) confere a stack local **antes** de tocar no remoto e
   recusa a execução se o Docker/stack estiver fora do ar. Aplicar só no remoto e
   declarar sincronização seria pior do que falhar.
2. **A estrutura do banco é versionada em `supabase/schema.sql`.** Dump gerado por
   `npm run db:dump` a partir do banco local, **apenas estrutura**. O script
   inspeciona o resultado e recusa qualquer linha de dados (`COPY ... FROM stdin`,
   `INSERT INTO`) antes de gravar, porque o repositório é público e o banco tem
   dado clínico.
3. **A paridade é auditável por comando.** `npm run db:verify` compara o histórico
   aplicado no remoto (e no local, quando a stack está no ar) com os arquivos de
   `supabase/migrations/` e nomeia a divergência.

## Consequências

Boas:

- A estrutura completa do banco passa a existir no repositório em SQL padrão, num
  arquivo único, revisável em diff. É o ponto de partida de qualquer migração para
  Postgres próprio.
- Divergência entre ambientes vira erro visível (`db:verify`), não descoberta
  tardia em produção.
- Quem não tem Docker no ar não consegue mais atualizar o remoto pela ferramenta do
  projeto. Isso é intencional.

Custos aceitos:

- Alterar banco passa a exigir Docker Desktop no ar. Em máquina fria isso custa
  alguns minutos.
- `supabase/schema.sql` tem ~880 KB e muda a cada migration. É ruído em diff, mas
  é o preço de ter a estrutura versionada de forma legível.
- O dump vem do banco **local**. Se alguém aplicar algo direto no painel do
  Supabase (fora de migration), o dump não vai enxergar — e é exatamente por isso
  que `db:verify` existe.

## Alternativas descartadas

- **Dump a partir do remoto (`db:dump --linked`) como padrão.** Continua disponível
  como flag, mas exige senha do banco de produção em uso rotineiro e não prova nada
  sobre o local. O objetivo é justamente manter o local vivo.
- **Backup binário (`pg_dump -Fc`) versionado.** Não é revisável em diff, e num
  repositório público um dump binário é um convite a vazar dado sem ninguém ver.
- **Confiar no `supabase db push` puro com disciplina humana.** Já é o que existia.
  Falhou em silêncio.
