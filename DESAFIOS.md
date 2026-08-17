# Desafios recorrentes do BSNutri

Pontos de fricção que já custaram tempo e tendem a voltar. Ler antes de começar.

## Onde o trabalho acontece

O redesign integrado vive no worktree `.worktrees/integrar-redesign-app-real`
(branch `codex/integrar-redesign-app-real`), não em `main`. Rodar gates no
diretório errado dá "tudo verde" enganoso, porque `main` ainda é o aplicativo
anterior. Conferir `git worktree list` antes de editar.

## `database.types.ts` é mantido à mão

Não há acesso ao gerador do Supabase nesta máquina. Toda migration que
acrescenta tabela, coluna, enum ou RPC exige editar `src/lib/database.types.ts`
manualmente, senão `tsc -b` reprova com "not assignable to parameter of type".

Atenção: os blocos `Returns` das funções que devolvem uma tabela repetem o shape
da linha. Ao acrescentar uma coluna, o mesmo trecho aparece várias vezes no
arquivo — usar `replace_all` e conferir a contagem.

## `type="number"` descarta vírgula decimal

Em pt-BR o profissional digita `68,5`. Um `<input type="number">` devolve string
vazia nesse caso, transformando uma medida informada em ausente, em silêncio.
Campos numéricos clínicos usam `type="text"` com `inputMode="decimal"` e
normalização de vírgula na leitura.

## Vitest x Playwright

`vitest` varre `e2e/` e falha com "Playwright Test did not expect test.describe()
to be called here". O `vite.config.ts` precisa manter `test.exclude` com
`e2e/**`.

No Windows, `vite preview` publica em `localhost` e o Playwright espera
`127.0.0.1`. O `webServer.command` precisa de `--host 127.0.0.1`, senão o start
estoura o timeout de 120 s sem explicação útil.

## Suítes SQL dependem de Docker

`supabase test db` exige Docker Desktop no ar. Iniciar o Docker Desktop por
linha de comando não sobe o daemon de forma confiável em sessão automatizada:
uma tentativa esperou mais de seis minutos sem `docker info` responder. Quando
isso acontecer, abrir o Docker Desktop na mão antes de pedir a execução.

## A CLI do Supabase muda o formato de saída quando detecta um agente

Rodando sob Claude Code/Codex, `supabase status` e `supabase migration list`
respondem em JSON, não na tabela de texto. Qualquer script que leia a saída
precisa passar `--output-format text` explicitamente, senão o parser volta vazio
e o resultado é pior que um erro: um "tudo em paridade" falso.

No formato texto da CLI 2.110 cada célula da tabela vem entre crases
(`` `20260713022042` ``). Versões anteriores não usavam crases e separavam com
`│` em vez de `|`. O parser em `scripts/db-sync.mjs` aceita os dois.

## Container parado impede `supabase start`

Depois de um desligamento sujo do Docker, `supabase start` morre com
`Conflict. The container name "/supabase_db_bsnutri" is already in use`. A saída
é `npx supabase stop` (que remove os containers e preserva o volume de dados) e
subir de novo. Não precisa apagar volume nem resetar o banco.

Vale registrar o contraponto ao item do Docker acima: nesta sessão o
`Start-Process "C:\Program Files\Docker\Docker\Docker Desktop.exe"` seguido de
polling em `docker info` respondeu em 30 s. Tentar antes de desistir, com teto de
~3 min.

## `.cmd` do Windows não roda em `spawn` sem shell

O `supabase` instalado globalmente é um `.cmd`. Desde o hardening do Node, um
`spawnSync('supabase', ...)` sem `shell: true` falha na cara. `scripts/db-sync.mjs`
usa `shell: true` no caminho de produção e dispensa o shell quando o dublê de
teste está injetado por `BSNUTRI_SUPABASE_ARGV` — o dublê é um `.mjs` executado
pelo próprio Node, e sem shell os caminhos com espaço não precisam de aspas.

## Conflito de portas com outro projeto Supabase local

Há outra stack Supabase nesta máquina (`gestaopessoas.github.io`) que ocupa
54321–54327. Com ela no ar, `supabase start` do BSNutri falha com
`Bind for 0.0.0.0:54322 failed: port is already allocated`.

Não parar a stack alheia. A saída é deslocar temporariamente as portas em
`supabase/config.toml` (54321→54421, 54322→54422, 54320→54420, 54329→54429,
54323→54423, 54324→54424, 54327→54427), rodar os testes e reverter o arquivo com
`git checkout -- supabase/config.toml`.

## Fixtures pgTAP esbarram nos próprios guardas

Três armadilhas que já custaram uma rodada inteira de depuração:

1. `plans_workflow_guard` recusa `update` direto em `status`, `reviewed_at`,
   `published_at` e `current_published_version_id`. A fixture precisa envolver
   esses updates em `select set_config('bsnutri.workflow_rpc','on',true)` e
   desligar em seguida.
2. `days_lock_guard` e `meals_lock_guard` recusam inserção em versão já
   bloqueada. Montar dias, refeições e itens **antes** de gravar `locked_at`.
3. `throws_ok` compara a mensagem literalmente. Para padrão, usar `throws_like`
   com `%`, nunca regex `.*`.

Assertivas que contam linhas de seed (`count(*) from foods where
organization_id is null`) envelhecem a cada migration de seed: filtrar pelo
registro da própria fixture.

## Datas em teste dependem de fuso

`new Date('2026-08-16')` é meia-noite UTC, que em UTC-3 cai no dia 15. Testes de
idade e de data usam meio-dia local (`new Date('2026-08-16T12:00:00')`).

## Banco: nunca aplicar só no remoto

`npm run db:push` aplica no remoto e no local, nessa ordem, e recusa a execução
se a stack local estiver fora do ar. Se aparecer a tentação de rodar
`supabase db push` direto porque o Docker está pesado, o resultado é a cópia
local envelhecendo em silêncio — foi exatamente isso que motivou a regra
(`docs/adr/0001-paridade-entre-banco-remoto-e-copia-local.md`).

O guarda do `db:dump` é sensível a caixa: recusa `COPY ... FROM stdin;` e
`INSERT INTO` em maiúsculas (como o `pg_dump` emite dados), mas aceita o
`insert into` minúsculo dos corpos de função. Se algum dia alguém escrever SQL
em maiúsculas nas migrations, o dump vai passar a acusar dado que não existe.

## Suíte lenta por decisão

`vite.config.ts` fixa `pool: 'forks'`, `fileParallelism: false` e `maxWorkers: 1`
para estabilidade no Windows/CI. A suíte completa leva ~50 s. Durante o
desenvolvimento, rodar só os arquivos afetados (`npx vitest run <arquivo>`) e
deixar a suíte inteira para o fechamento.
