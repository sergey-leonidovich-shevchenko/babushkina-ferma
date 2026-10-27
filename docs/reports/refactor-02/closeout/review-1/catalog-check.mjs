// Check the new review receipt against the actual source and both exported copies.
import assert from 'node:assert/strict'
import { createHash } from 'node:crypto'
import { readFile, writeFile } from 'node:fs/promises'
import { readPlanningCatalog } from '../../../../../wiki/scripts/planning-catalog.mjs'
import { firstLocationOverview } from '../../../../../wiki/src/lib/first-location.ts'

const root = 'docs/reports/refactor-02/closeout/review-1/'
const catalog = await readPlanningCatalog()
for (const prefix of ['wiki/public/', 'wiki/dist/']) {
  const file = JSON.parse(await readFile(prefix + 'generated/planning.json', 'utf8'))
  assert.deepEqual(file.catalog, catalog)
}
const overview = firstLocationOverview(catalog)
assert.equal(overview.history.length, 83)
assert.equal(overview.history.filter((task) => !task.completion?.date).length, 20)
assert.equal(overview.accepted, false)
assert.deepEqual(overview.active.map((task) => task.key), ['wiki--IDEA-REVIEW-20261024'])
const task = catalog.tasks.find((task) => task.key === 'refactoring--REFACTOR-02')
assert.equal(task.status, 'done')
assert.equal(task.completion.date, '2026-10-27')
assert.equal(catalog.tasks.find((task) => task.key === 'refactoring--REFACTOR-03').status, 'ready')
const source = await readFile(root + 'result.json')
const sha = createHash('sha256').update(source).digest('hex')
const attachment = `generated/attachments/${sha}.json`
for (const prefix of ['wiki/public/', 'wiki/dist/'])
  assert.deepEqual(await readFile(prefix + attachment), source)
const site = JSON.parse(await readFile('wiki/dist/generated/catalog.json', 'utf8'))
assert.equal(site.meta.version, '0.0.356')
assert.ok(site.entries.find((entry) => entry.id === 'project-refactoring').html.includes(attachment))
await writeFile(root + 'catalog.json', JSON.stringify({
  version: site.meta.version, source_public_dist_equal: true,
  history: 83, unknown: 20, accepted_VMAP: false,
  active: overview.active.map((task) => task.key),
  task: {status: task.status, completion: task.completion},
  next_status: 'ready', receipt: {attachment, sha256: sha, bytes: source.length, copies_equal: true},
}, null, 2) + '\n')
console.log(JSON.stringify({version: site.meta.version, history: 83, unknown: 20, attachment}))
