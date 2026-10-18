import test from 'node:test'
import assert from 'node:assert/strict'
import { mkdtemp, writeFile, chmod, rm } from 'node:fs/promises'
import { join } from 'node:path'
import { tmpdir } from 'node:os'
import { packageManager } from '../scripts/runtime.mjs'

// Сценарий: в PATH есть штатная обёртка pnpm, также существует голый bundled script.
// Исходное состояние: временный executable и отдельная явная настройка.
// Ожидаемый результат: launcher сохраняет правила обёртки; явный выбор пользователя имеет приоритет.
test('launcher prefers the available pnpm wrapper and respects an explicit override', async () => {
  const root = await mkdtemp(join(tmpdir(), 'farm-wiki-runtime-'))
  const oldPath = process.env.PATH,
    oldManager = process.env.WIKI_PNPM_BIN
  try {
    const wrapper = join(root, process.platform === 'win32' ? 'pnpm.cmd' : 'pnpm')
    await writeFile(wrapper, '#!/bin/sh\nexit 0\n')
    await chmod(wrapper, 0o755)
    delete process.env.WIKI_PNPM_BIN
    process.env.PATH = root
    assert.deepEqual(await packageManager(), { command: wrapper, prefix: [] })
    const script = join(root, 'chosen.mjs')
    await writeFile(script, '')
    process.env.WIKI_PNPM_BIN = script
    assert.deepEqual(await packageManager(), { command: process.execPath, prefix: [script] })
  } finally {
    if (oldPath === undefined) delete process.env.PATH
    else process.env.PATH = oldPath
    if (oldManager === undefined) delete process.env.WIKI_PNPM_BIN
    else process.env.WIKI_PNPM_BIN = oldManager
    await rm(root, { recursive: true, force: true })
  }
})
