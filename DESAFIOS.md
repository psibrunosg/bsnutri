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

## Suíte lenta por decisão

`vite.config.ts` fixa `pool: 'forks'`, `fileParallelism: false` e `maxWorkers: 1`
para estabilidade no Windows/CI. A suíte completa leva ~50 s. Durante o
desenvolvimento, rodar só os arquivos afetados (`npx vitest run <arquivo>`) e
deixar a suíte inteira para o fechamento.
