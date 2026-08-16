import { readdirSync, readFileSync, statSync } from 'node:fs'
import { resolve, join } from 'node:path'

const forbiddenMarkers = [
  'SUPABASE_PROF_EMAIL',
  'SUPABASE_PROF_PASSWORD',
  'Dados reais sincronizados do Supabase',
  'DB_TEMPLATES',
]

/**
 * As chaves do protótipo podem aparecer no pacote porque o importador legado
 * precisa lê-las e apagá-las. O que não pode existir é gravação clínica no
 * navegador: qualquer `setItem` com essas chaves reprova o artefato.
 */
const legacyStorageKeys = ['bsnutri-patients', 'bsnutri-plans']
const clinicalWritePatterns = legacyStorageKeys.flatMap((key) => [
  new RegExp(`setItem\\(\\s*["'\`]${key}`),
  new RegExp(`setItem\\(\\s*[A-Za-z_$][\\w$]*\\s*,[^)]*${key}`),
])

function filesIn(directory) {
  return readdirSync(directory, { withFileTypes: true }).flatMap((entry) => {
    const path = join(directory, entry.name)
    if (entry.isDirectory()) return filesIn(path)
    return entry.isFile() ? [path] : []
  })
}

const artifactDirectory = resolve(process.argv[2] ?? 'dist')

if (!statSync(artifactDirectory).isDirectory()) {
  throw new Error(`Build artifact directory not found: ${artifactDirectory}`)
}

const violations = filesIn(artifactDirectory).flatMap((path) => {
  const contents = readFileSync(path, 'utf8')
  return [
    ...forbiddenMarkers.filter((marker) => contents.includes(marker)).map((marker) => `${marker} in ${path}`),
    ...clinicalWritePatterns
      .filter((pattern) => pattern.test(contents))
      .map((pattern) => `gravação clínica em localStorage (${pattern}) in ${path}`),
  ]
})

if (violations.length > 0) {
  console.error(`Unsafe build artifact:\n${violations.join('\n')}`)
  process.exitCode = 1
} else {
  console.log(`Build artifact verified: ${artifactDirectory}`)
}
