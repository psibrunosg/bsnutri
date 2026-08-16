import { readdirSync, readFileSync, statSync } from 'node:fs'
import { resolve, join } from 'node:path'

const forbiddenMarkers = [
  'SUPABASE_PROF_EMAIL',
  'SUPABASE_PROF_PASSWORD',
  'bsnutri-patients',
  'bsnutri-plans',
  'Dados reais sincronizados do Supabase',
  'DB_TEMPLATES',
]

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
  return forbiddenMarkers
    .filter((marker) => contents.includes(marker))
    .map((marker) => `${marker} in ${path}`)
})

if (violations.length > 0) {
  console.error(`Unsafe build artifact:\n${violations.join('\n')}`)
  process.exitCode = 1
} else {
  console.log(`Build artifact verified: ${artifactDirectory}`)
}
