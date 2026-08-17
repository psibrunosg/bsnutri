import { spawnSync } from 'node:child_process'
import { existsSync, mkdtempSync, readFileSync, readdirSync, rmSync, writeFileSync } from 'node:fs'
import { tmpdir } from 'node:os'
import { join, resolve } from 'node:path'
import { afterEach, beforeAll, describe, expect, it } from 'vitest'

import { dataStatementsIn, diffMigrations, migrationVersionsFromFileNames, parseRemoteVersions } from './db-sync.mjs'

const projectRoot = resolve(process.cwd())
const scriptPath = join(projectRoot, 'scripts', 'db-sync.mjs')

/**
 * Dublê da CLI do Supabase: registra cada chamada em `FAKE_LOG` e responde
 * conforme as variáveis de ambiente, sem Docker e sem rede.
 */
const fakeCliSource = `
import { appendFileSync, writeFileSync } from 'node:fs'

const args = process.argv.slice(2)
appendFileSync(process.env.FAKE_LOG, JSON.stringify(args) + '\\n')

const exitWith = (name) => process.exit(Number(process.env[name] ?? '0'))

if (args[0] === 'status') exitWith('FAKE_STATUS_EXIT')

if (args[0] === 'db' && args[1] === 'push') {
  exitWith(args.includes('--linked') ? 'FAKE_PUSH_REMOTE_EXIT' : 'FAKE_PUSH_LOCAL_EXIT')
}

if (args[0] === 'db' && args[1] === 'dump') {
  writeFileSync(args[args.indexOf('-f') + 1], process.env.FAKE_DUMP_CONTENT ?? '')
  exitWith('FAKE_DUMP_EXIT')
}

if (args[0] === 'migration' && args[1] === 'list') {
  const versions = JSON.parse(process.env.FAKE_LIST_VERSIONS ?? '[]')
  const rows = versions.map((version) => \`   \\\`\${version}\\\` | \\\`\${version}\\\` | \\\`2026-08-16 00:00:00\\\`\`)
  process.stdout.write(['   Local            | Remote           | Time (UTC)', ...rows].join('\\n'))
  process.exit(0)
}

process.exit(0)
`

const temporaryDirectories: string[] = []
let fakeCliPath = ''
let directoryVersions: string[] = []

function createTemporaryDirectory() {
  const directory = mkdtempSync(join(tmpdir(), 'bsnutri-db-sync-'))
  temporaryDirectories.push(directory)
  return directory
}

beforeAll(() => {
  const fakeDirectory = mkdtempSync(join(tmpdir(), 'bsnutri-db-sync-cli-'))
  fakeCliPath = join(fakeDirectory, 'fake-supabase.mjs')
  writeFileSync(fakeCliPath, fakeCliSource)
  directoryVersions = migrationVersionsFromFileNames(readdirSync(join(projectRoot, 'supabase', 'migrations')))
  return () => rmSync(fakeDirectory, { force: true, recursive: true })
})

afterEach(() => {
  for (const directory of temporaryDirectories.splice(0)) {
    rmSync(directory, { force: true, recursive: true })
  }
})

function runDbSync(args: string[], environment: Record<string, string> = {}) {
  const logPath = join(createTemporaryDirectory(), 'calls.log')
  writeFileSync(logPath, '')
  const result = spawnSync(process.execPath, [scriptPath, ...args], {
    encoding: 'utf8',
    env: {
      ...process.env,
      BSNUTRI_SUPABASE_ARGV: JSON.stringify([process.execPath, fakeCliPath]),
      FAKE_LOG: logPath,
      ...environment,
    },
  })
  const calls = readFileSync(logPath, 'utf8')
    .split('\n')
    .filter(Boolean)
    .map((line) => (JSON.parse(line) as string[]).join(' '))
  return { ...result, calls }
}

describe('db:push', () => {
  it('recusa a execução quando a stack local não está no ar, sem tocar no remoto', () => {
    const result = runDbSync(['push'], { FAKE_STATUS_EXIT: '1' })

    expect(result.status).toBe(1)
    expect(result.stderr).toContain('stack local do Supabase não está no ar')
    expect(result.stderr).toContain('npx supabase start')
    expect(result.calls).toEqual(['status --output-format text'])
  })

  it('aplica no remoto, depois no local, e regrava o dump de estrutura', () => {
    const schemaPath = join(createTemporaryDirectory(), 'schema.sql')
    const result = runDbSync(['push'], {
      BSNUTRI_SCHEMA_PATH: schemaPath,
      FAKE_DUMP_CONTENT: 'create table public.exemplo (id uuid primary key);\n',
    })

    expect(result.status).toBe(0)
    expect(result.calls).toEqual([
      'status --output-format text',
      'db push --linked',
      'db push --local',
      'status --output-format text',
      `db dump --local -f ${schemaPath}.tmp --output-format text`,
    ])
    expect(readFileSync(schemaPath, 'utf8')).toContain('create table public.exemplo')
  })

  it('não aplica no local quando o remoto falha', () => {
    const result = runDbSync(['push'], { FAKE_PUSH_REMOTE_EXIT: '1' })

    expect(result.status).toBe(1)
    expect(result.stderr).toContain('Falha ao aplicar no remoto')
    expect(result.calls).toEqual(['status --output-format text', 'db push --linked'])
  })

  it('avisa que os bancos ficaram fora de paridade quando o local falha', () => {
    const result = runDbSync(['push'], { FAKE_PUSH_LOCAL_EXIT: '1' })

    expect(result.status).toBe(1)
    expect(result.stderr).toContain('fora de paridade')
  })

  it('em --dry-run simula nos dois bancos e não regrava o dump', () => {
    const result = runDbSync(['push', '--dry-run'])

    expect(result.status).toBe(0)
    expect(result.calls).toEqual([
      'status --output-format text',
      'db push --linked --dry-run',
      'db push --local --dry-run',
    ])
  })
})

describe('db:dump', () => {
  it('recusa um dump com linhas de dados e preserva o arquivo anterior', () => {
    const schemaPath = join(createTemporaryDirectory(), 'schema.sql')
    writeFileSync(schemaPath, 'create table public.anterior (id int);\n')

    const result = runDbSync(['dump'], {
      BSNUTRI_SCHEMA_PATH: schemaPath,
      FAKE_DUMP_CONTENT: 'COPY public.patients (id, name) FROM stdin;\n1\tMaria\n\\.\n',
    })

    expect(result.status).toBe(1)
    expect(result.stderr).toContain('repositório é PÚBLICO')
    expect(readFileSync(schemaPath, 'utf8')).toContain('anterior')
    expect(existsSync(`${schemaPath}.tmp`)).toBe(false)
  })

  it('aceita --linked sem exigir a stack local', () => {
    const schemaPath = join(createTemporaryDirectory(), 'schema.sql')
    const result = runDbSync(['dump', '--linked'], {
      BSNUTRI_SCHEMA_PATH: schemaPath,
      FAKE_STATUS_EXIT: '1',
      FAKE_DUMP_CONTENT: 'create schema public;\n',
    })

    expect(result.status).toBe(0)
    expect(result.calls).toEqual([`db dump --linked -f ${schemaPath}.tmp --output-format text`])
  })
})

describe('db:verify', () => {
  it('aprova quando o remoto tem exatamente as migrations do diretório', () => {
    const result = runDbSync(['verify'], {
      FAKE_STATUS_EXIT: '1',
      FAKE_LIST_VERSIONS: JSON.stringify(directoryVersions),
    })

    expect(result.status).toBe(0)
    expect(result.stdout).toContain('remoto: em paridade')
    expect(result.stdout).toContain('local: não verificado')
  })

  it('reprova e nomeia a migration que falta no remoto', () => {
    const missing = directoryVersions[directoryVersions.length - 1]
    const result = runDbSync(['verify'], {
      FAKE_STATUS_EXIT: '1',
      FAKE_LIST_VERSIONS: JSON.stringify(directoryVersions.slice(0, -1)),
    })

    expect(result.status).toBe(1)
    expect(result.stdout).toContain(missing)
    expect(result.stderr).toContain('Divergência encontrada')
  })

  it('também confere o banco local quando a stack está no ar', () => {
    const result = runDbSync(['verify'], {
      FAKE_LIST_VERSIONS: JSON.stringify(directoryVersions),
    })

    expect(result.status).toBe(0)
    expect(result.stdout).toContain('local: em paridade')
    expect(result.calls).toContain('migration list --local --output-format text')
  })
})

describe('helpers', () => {
  it('lê a coluna remota no formato com crases da CLI atual', () => {
    const output = [
      '   Local            | Remote           | Time (UTC)',
      '  ------------------|------------------|-----------------------',
      '   `20260713022042` | `20260713022042` | `2026-07-13 02:20:42`',
      '   `20260713022415` |                  | `2026-07-13 02:24:15`',
      '                    | `20250101000000` | `2025-01-01 00:00:00`',
    ].join('\n')

    expect(parseRemoteVersions(output)).toEqual(['20250101000000', '20260713022042'])
  })

  it('lê a coluna remota no formato antigo, sem crases e com barra unicode', () => {
    const output = [
      '        LOCAL      │     REMOTE     │     TIME (UTC)',
      '  ─────────────────┼────────────────┼─────────────────────',
      '    20260713022042 │ 20260713022042 │ 2026-07-13 02:20:42',
      '    20260713022415 │                │ 2026-07-13 02:24:15',
    ].join('\n')

    expect(parseRemoteVersions(output)).toEqual(['20260713022042'])
  })

  it('ignora arquivos que não seguem o padrão de migration', () => {
    const versions = migrationVersionsFromFileNames([
      '20260713022042_initial.sql',
      'README.md',
      'rascunho.sql',
      '20260713022415_harden.sql',
    ])

    expect(versions).toEqual(['20260713022042', '20260713022415'])
  })

  it('separa migrations pendentes de migrations sem arquivo', () => {
    const diff = diffMigrations(['1', '2', '3'], ['1', '3', '9'])

    expect(diff).toEqual({ pending: ['2'], unknown: ['9'] })
  })

  it('acusa dados no dump sem confundir com corpo de função em minúsculas', () => {
    const sql = [
      'create function f() returns void as $$',
      'insert into public.audit (id) values (1);',
      '$$ language sql;',
      'COPY public.patients (id) FROM stdin;',
      'INSERT INTO public.foods VALUES (1);',
    ].join('\n')

    expect(dataStatementsIn(sql)).toEqual([
      'COPY public.patients (id) FROM stdin;',
      'INSERT INTO public.foods VALUES (1);',
    ])
  })
})
