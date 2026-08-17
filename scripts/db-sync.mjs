#!/usr/bin/env node
/**
 * Paridade entre o banco remoto (Supabase) e a cópia local versionada.
 *
 * Comandos:
 *   push    aplica as migrations pendentes no remoto e no local, nessa ordem,
 *           e regrava `supabase/schema.sql`.
 *   dump    regrava `supabase/schema.sql` a partir do banco local (padrão) ou
 *           do remoto (`--linked`). Só estrutura, nunca dados.
 *   verify  compara as migrations aplicadas no remoto com os arquivos do
 *           diretório e reporta divergência.
 *
 * Regra do projeto: toda alteração de banco passa por migration versionada e é
 * aplicada no local e no remoto. Nunca só no remoto. Por isso `push` recusa a
 * execução quando a stack local não está no ar, antes de tocar no remoto.
 *
 * `BSNUTRI_SUPABASE_ARGV` (JSON com o argv base da CLI) e `BSNUTRI_SCHEMA_PATH`
 * existem para os testes substituírem o binário `supabase` por um dublê e
 * escreverem o dump fora do repositório. Não usar em produção.
 */
import { spawnSync } from 'node:child_process'
import { existsSync, readFileSync, readdirSync, renameSync, rmSync } from 'node:fs'
import { dirname, join, resolve } from 'node:path'
import { fileURLToPath } from 'node:url'

const projectRoot = resolve(dirname(fileURLToPath(import.meta.url)), '..')
const migrationsDirectory = join(projectRoot, 'supabase', 'migrations')

/** Caminho relativo ao projeto: vira argumento de linha de comando. */
const schemaPath = process.env.BSNUTRI_SCHEMA_PATH ?? 'supabase/schema.sql'
const schemaTemporaryPath = `${schemaPath}.tmp`

const migrationFilePattern = /^(\d{14})_.+\.sql$/
const versionPattern = /^\d{14}$/

/**
 * A CLI do Supabase troca a saída para JSON quando detecta que está rodando sob
 * um agente. Toda leitura de saída fixa `--output-format text` para o parser não
 * depender dessa detecção.
 */
const textOutputFlags = ['--output-format', 'text']

// ---------------------------------------------------------------- helpers puros

/** Versões (timestamp de 14 dígitos) dos arquivos de migration do diretório. */
export function migrationVersionsFromFileNames(fileNames) {
  return fileNames
    .map((name) => migrationFilePattern.exec(name)?.[1])
    .filter((version) => version !== undefined)
    .sort()
}

/**
 * Lê a coluna REMOTE da tabela impressa por `supabase migration list`.
 * A tabela usa `│` (ou `|`) como separador e a segunda coluna é a remota.
 * A CLI 2.110 envolve cada célula em crases; versões antigas não envolvem.
 */
export function parseRemoteVersions(output) {
  const versions = output
    .split(/\r?\n/)
    .map((line) => line.split(/[│|]/)[1]?.replace(/`/g, '').trim())
    .filter((cell) => cell !== undefined && versionPattern.test(cell))
  return [...new Set(versions)].sort()
}

/** Divergência entre o diretório de migrations e o histórico de um banco. */
export function diffMigrations(directoryVersions, appliedVersions) {
  const applied = new Set(appliedVersions)
  const directory = new Set(directoryVersions)
  return {
    pending: directoryVersions.filter((version) => !applied.has(version)),
    unknown: appliedVersions.filter((version) => !directory.has(version)),
  }
}

export function describeDiff(label, diff) {
  if (diff.pending.length === 0 && diff.unknown.length === 0) {
    return `${label}: em paridade com supabase/migrations.`
  }
  const lines = [`${label}: DIVERGENTE.`]
  if (diff.pending.length > 0) {
    lines.push(`  no diretório e não aplicadas (${diff.pending.length}): ${diff.pending.join(', ')}`)
  }
  if (diff.unknown.length > 0) {
    lines.push(`  aplicadas e sem arquivo no diretório (${diff.unknown.length}): ${diff.unknown.join(', ')}`)
  }
  return lines.join('\n')
}

/**
 * Sentinela do repositório público: um dump de estrutura não pode conter linhas
 * de dados. O `pg_dump` emite dados como `COPY ... FROM stdin;` ou `INSERT INTO`
 * em maiúsculas no início da linha; o SQL escrito à mão neste repositório é todo
 * minúsculo, então a checagem é sensível a caixa para não acusar corpo de função.
 */
export function dataStatementsIn(sql) {
  return sql
    .split(/\r?\n/)
    .filter((line) => /^COPY\s+\S+.*FROM stdin;/.test(line) || /^INSERT INTO\s/.test(line))
}

// ------------------------------------------------------------------ execução

function supabaseArgv() {
  const override = process.env.BSNUTRI_SUPABASE_ARGV
  return override ? JSON.parse(override) : ['supabase']
}

/**
 * Roda a CLI do Supabase na raiz do projeto. No Windows o `supabase` instalado
 * é um `.cmd`, que só executa via shell; o dublê dos testes é um executável
 * real e dispensa o shell.
 */
function runSupabase(args, { capture = false } = {}) {
  const [command, ...prefix] = supabaseArgv()
  return spawnSync(command, [...prefix, ...args], {
    cwd: projectRoot,
    encoding: 'utf8',
    shell: process.env.BSNUTRI_SUPABASE_ARGV === undefined,
    stdio: capture ? ['inherit', 'pipe', 'pipe'] : 'inherit',
  })
}

function fail(message) {
  console.error(message)
  process.exit(1)
}

function localStackStatus() {
  return runSupabase(['status', ...textOutputFlags], { capture: true })
}

function requireLocalStack(commandName) {
  const status = localStackStatus()
  if (status.status === 0) return

  fail(
    [
      `A stack local do Supabase não está no ar, então \`npm run ${commandName}\` não vai rodar.`,
      '',
      'A cópia local é a referência versionada do banco. Seguir sem ela deixaria o',
      'local para trás e a paridade com o remoto viraria mentira.',
      '',
      'Para destravar:',
      '  1. abrir o Docker Desktop na mão e esperar o daemon responder',
      '  2. npx supabase start',
      `  3. repetir npm run ${commandName}`,
      '',
      'Saída de `supabase status`:',
      `${(status.stderr || status.stdout || status.error?.message || '(sem saída)').trim()}`,
    ].join('\n'),
  )
}

function directoryVersions() {
  return migrationVersionsFromFileNames(readdirSync(migrationsDirectory))
}

// ------------------------------------------------------------------- comandos

function commandPush(extraArgs) {
  // A checagem do local vem antes de qualquer chamada ao remoto: de propósito.
  requireLocalStack('db:push')

  console.log('\n> Aplicando migrations no REMOTO (projeto vinculado)...')
  const remote = runSupabase(['db', 'push', '--linked', ...extraArgs])
  if (remote.status !== 0) {
    fail('Falha ao aplicar no remoto. Nada foi aplicado no local. Corrija a migration e repita.')
  }

  console.log('\n> Aplicando as mesmas migrations no LOCAL...')
  const local = runSupabase(['db', 'push', '--local', ...extraArgs])
  if (local.status !== 0) {
    fail(
      [
        'O remoto foi atualizado, mas o LOCAL falhou: os bancos estão fora de paridade.',
        'Rode `npx supabase db reset` (apaga só o banco local) e depois `npm run db:verify`.',
      ].join('\n'),
    )
  }

  if (extraArgs.includes('--dry-run')) {
    console.log('\nSimulação concluída. `supabase/schema.sql` não foi tocado.')
    return
  }

  console.log('\n> Regravando o dump de estrutura versionado...')
  commandDump([])
}

function commandDump(extraArgs) {
  const fromLinked = extraArgs.includes('--linked')
  const source = fromLinked ? '--linked' : '--local'
  if (!fromLinked) requireLocalStack('db:dump')

  const absoluteTemporary = resolve(projectRoot, schemaTemporaryPath)
  rmSync(absoluteTemporary, { force: true })

  const dump = runSupabase(['db', 'dump', source, '-f', schemaTemporaryPath, ...textOutputFlags])
  if (dump.status !== 0 || !existsSync(absoluteTemporary)) {
    rmSync(absoluteTemporary, { force: true })
    fail(`Falha ao gerar o dump de estrutura a partir de ${source}.`)
  }

  const sql = readFileSync(absoluteTemporary, 'utf8')
  const dataStatements = dataStatementsIn(sql)
  if (dataStatements.length > 0) {
    rmSync(absoluteTemporary, { force: true })
    fail(
      [
        'O dump gerado contém linhas de dados e o repositório é PÚBLICO.',
        `${schemaPath} não foi alterado. Primeiras ocorrências:`,
        ...dataStatements.slice(0, 5).map((line) => `  ${line.slice(0, 120)}`),
      ].join('\n'),
    )
  }

  renameSync(absoluteTemporary, resolve(projectRoot, schemaPath))
  console.log(`${schemaPath} atualizado a partir de ${source} (${sql.split(/\r?\n/).length} linhas, só estrutura).`)
}

function commandVerify() {
  const versions = directoryVersions()
  console.log(`supabase/migrations: ${versions.length} migrations versionadas.`)

  const remote = runSupabase(['migration', 'list', '--linked', ...textOutputFlags], { capture: true })
  if (remote.status !== 0) {
    fail(
      [
        'Não foi possível ler o histórico de migrations do remoto.',
        'Confira `npx supabase login` e `npx supabase link --project-ref qjclholskxmtxqqentuz`.',
        `${(remote.stderr || remote.stdout || remote.error?.message || '').trim()}`,
      ].join('\n'),
    )
  }

  const remoteDiff = diffMigrations(versions, parseRemoteVersions(remote.stdout ?? ''))
  console.log(describeDiff('remoto', remoteDiff))

  let localDiff = { pending: [], unknown: [] }
  if (localStackStatus().status === 0) {
    const local = runSupabase(['migration', 'list', '--local', ...textOutputFlags], { capture: true })
    if (local.status !== 0) fail('Não foi possível ler o histórico de migrations do banco local.')
    localDiff = diffMigrations(versions, parseRemoteVersions(local.stdout ?? ''))
    console.log(describeDiff('local', localDiff))
  } else {
    console.log('local: não verificado (stack local fora do ar). Suba com `npx supabase start`.')
  }

  const divergent = [remoteDiff, localDiff].some((diff) => diff.pending.length > 0 || diff.unknown.length > 0)
  if (divergent) fail('\nDivergência encontrada. Rode `npm run db:push` para reaplicar em ambos.')
  console.log('\nBancos e diretório em paridade.')
}

const usage = `Uso: node scripts/db-sync.mjs <push|dump|verify> [flags da CLI do Supabase]

  push            aplica migrations no remoto e no local e regrava ${schemaPath}
  push --dry-run  simula em ambos, sem gravar nada
  dump            regrava ${schemaPath} a partir do banco local
  dump --linked   regrava ${schemaPath} a partir do remoto
  verify          compara o histórico aplicado com supabase/migrations`

export function main(argv) {
  const [command, ...extraArgs] = argv
  if (command === 'push') return commandPush(extraArgs)
  if (command === 'dump') return commandDump(extraArgs)
  if (command === 'verify') return commandVerify()
  fail(usage)
}

const invokedPath = process.argv[1] ? resolve(process.argv[1]) : ''
if (invokedPath === resolve(fileURLToPath(import.meta.url))) {
  main(process.argv.slice(2))
}
