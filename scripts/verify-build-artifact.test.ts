import { mkdtempSync, rmSync, writeFileSync } from 'node:fs'
import { tmpdir } from 'node:os'
import { join } from 'node:path'
import { spawnSync } from 'node:child_process'
import { afterEach, expect, it } from 'vitest'

const temporaryDirectories: string[] = []

function createArtifact(contents: string) {
  const directory = mkdtempSync(join(tmpdir(), 'bsnutri-artifact-'))
  temporaryDirectories.push(directory)
  writeFileSync(join(directory, 'app.js'), contents)
  return directory
}

afterEach(() => {
  for (const directory of temporaryDirectories.splice(0)) {
    rmSync(directory, { force: true, recursive: true })
  }
})

it('rejects a build artifact that embeds a forbidden clinical storage marker', () => {
  const artifactDirectory = createArtifact('const cache = "bsnutri-patients"')

  const result = spawnSync(process.execPath, ['scripts/verify-build-artifact.mjs', artifactDirectory], {
    encoding: 'utf8',
  })

  expect(result.status).toBe(1)
  expect(result.stderr).toContain('bsnutri-patients')
})

it('accepts an artifact without credentials, local clinical storage, or synchronization markers', () => {
  const artifactDirectory = createArtifact('const app = "safe"')

  const result = spawnSync(process.execPath, ['scripts/verify-build-artifact.mjs', artifactDirectory], {
    encoding: 'utf8',
  })

  expect(result.status).toBe(0)
})
