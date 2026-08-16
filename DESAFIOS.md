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
esperei mais de seis minutos sem `docker info` responder. Migrations e testes
pgTAP novos ficam escritos e revisados, mas a execução precisa de uma sessão com
o Docker já rodando.

## Datas em teste dependem de fuso

`new Date('2026-08-16')` é meia-noite UTC, que em UTC-3 cai no dia 15. Testes de
idade e de data usam meio-dia local (`new Date('2026-08-16T12:00:00')`).

## Suíte lenta por decisão

`vite.config.ts` fixa `pool: 'forks'`, `fileParallelism: false` e `maxWorkers: 1`
para estabilidade no Windows/CI. A suíte completa leva ~50 s. Durante o
desenvolvimento, rodar só os arquivos afetados (`npx vitest run <arquivo>`) e
deixar a suíte inteira para o fechamento.
