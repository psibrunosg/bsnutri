import { mkdirSync, mkdtempSync, rmSync, writeFileSync } from 'node:fs'
import { tmpdir } from 'node:os'
import { dirname, join } from 'node:path'
import { spawnSync } from 'node:child_process'
import { afterEach, expect, it } from 'vitest'

const temporaryDirectories: string[] = []

const forbiddenMarkers = [
  ['SUPABASE_PROF_EMAIL', 'runtime.js'],
  ['SUPABASE_PROF_PASSWORD', 'runtime.js'],
  ['Dados reais sincronizados do Supabase', 'catalog.js'],
  ['DB_TEMPLATES', 'assets/nested/catalog.js'],
] as const

const clinicalWrites = [
  ['bsnutri-patients', 'localStorage.setItem("bsnutri-patients", JSON.stringify(patients))'],
  ['bsnutri-plans', 'localStorage.setItem(`bsnutri-plans`, body)'],
] as const

function createArtifact(contents: string, relativePath = 'app.js') {
  const directory = mkdtempSync(join(tmpdir(), 'bsnutri-artifact-'))
  temporaryDirectories.push(directory)
  const artifactPath = join(directory, relativePath)
  mkdirSync(dirname(artifactPath), { recursive: true })
  writeFileSync(artifactPath, contents)
  return directory
}

afterEach(() => {
  for (const directory of temporaryDirectories.splice(0)) {
    rmSync(directory, { force: true, recursive: true })
  }
})

it.each(forbiddenMarkers)('rejects a build artifact containing %s in %s', (marker, relativePath) => {
  const artifactDirectory = createArtifact(`const marker = ${JSON.stringify(marker)}`, relativePath)

  const result = spawnSync(process.execPath, ['scripts/verify-build-artifact.mjs', artifactDirectory], {
    encoding: 'utf8',
  })

  expect(result.status).toBe(1)
  expect(result.stderr).toContain(marker)
})

it.each(clinicalWrites)('rejects a build artifact that writes %s to localStorage', (marker, source) => {
  const artifactDirectory = createArtifact(source, 'clinical-storage.js')

  const result = spawnSync(process.execPath, ['scripts/verify-build-artifact.mjs', artifactDirectory], {
    encoding: 'utf8',
  })

  expect(result.status).toBe(1)
  expect(result.stderr).toContain(marker)
})

it('accepts the legacy importer, which only reads and clears the prototype keys', () => {
  const artifactDirectory = createArtifact(
    'const K="bsnutri-patients";storage.getItem(K);storage.removeItem("bsnutri-plans")',
    'legacy-import.js',
  )

  const result = spawnSync(process.execPath, ['scripts/verify-build-artifact.mjs', artifactDirectory], {
    encoding: 'utf8',
  })

  expect(result.status).toBe(0)
})

it('accepts an artifact without credentials, local clinical storage, or synchronization markers', () => {
  const artifactDirectory = createArtifact('const app = "safe"')

  const result = spawnSync(process.execPath, ['scripts/verify-build-artifact.mjs', artifactDirectory], {
    encoding: 'utf8',
  })

  expect(result.status).toBe(0)
})
