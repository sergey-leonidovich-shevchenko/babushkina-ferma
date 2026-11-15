import assert from 'node:assert/strict'
import { createHash } from 'node:crypto'
import { readFile } from 'node:fs/promises'
import { join } from 'node:path'
import test from 'node:test'
import { wikiRoot } from '../scripts/runtime.mjs'

test('refactoring article links the accepted audit and publishes the closeout data', async () => {
  const catalog = JSON.parse(
    await readFile(join(wikiRoot, 'public/generated/catalog.json'), 'utf8')
  )
  const refactoring = catalog.entries.find(
    (entry) => entry.category === 'guides' && entry.id === 'project-refactoring'
  )
  const audit =
    'https://github.com/sergey-leonidovich-shevchenko/babushkina-ferma/blob/' +
    'a68ca8e02b5f3bc7ea980a5dcd7f3c10077b627e/docs/reports/refactor-08/README.md'
  assert.ok(
    refactoring?.html.includes(
      `<a href="${audit}" target="_blank" rel="noopener noreferrer">Ведомость и аудит</a>`
    ),
    'Ведомость должна вести к принятой версии аудита'
  )

  const source = await readFile(
    join(wikiRoot, '../docs/reports/refactor-08/closeout/completion.json')
  )
  const path = `generated/attachments/${createHash('sha256').update(source).digest('hex')}.json`
  assert.ok(
    refactoring.html.includes(`<a href="${path}" download="completion.json">Данные приёмки</a>`),
    'Данные приёмки должны открываться как локальное вложение'
  )
  assert.deepEqual(await readFile(join(wikiRoot, 'public', path)), source)
})
