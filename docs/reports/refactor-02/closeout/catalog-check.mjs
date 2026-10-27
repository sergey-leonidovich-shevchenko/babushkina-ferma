// Verify the actual candidate source, both built copies and the downloaded receipt bytes.
import assert from 'node:assert/strict'
import { createHash } from 'node:crypto'
import { readFile, writeFile } from 'node:fs/promises'
import { readPlanningCatalog } from '../../../../wiki/scripts/planning-catalog.mjs'
import { firstLocationOverview } from '../../../../wiki/src/lib/first-location.ts'

const report = 'docs/reports/refactor-02/closeout/'
const catalog = await readPlanningCatalog()
const [published, built] = await Promise.all([
  readFile('wiki/public/generated/planning.json', 'utf8').then(JSON.parse),
  readFile('wiki/dist/generated/planning.json', 'utf8').then(JSON.parse),
])
assert.deepEqual(catalog, published.catalog)
assert.deepEqual(catalog, built.catalog)
const overview = firstLocationOverview(catalog)
const task = catalog.tasks.find((task) => task.key === 'refactoring--REFACTOR-02')
const next = catalog.tasks.find((task) => task.key === 'refactoring--REFACTOR-03')
assert.equal(task.status, 'done')
assert.equal(task.completion.date, '2026-10-27')
assert.equal(next.status, 'ready')
assert.deepEqual(overview.active.map((task) => task.key), ['wiki--IDEA-REVIEW-20261024'])
assert.equal(overview.history.length, 83)
assert.equal(overview.history.filter((task) => !task.completion?.date).length, 20)
assert.equal(overview.accepted, false)
const dated = overview.history.filter((task) => task.completion?.date === '2026-10-27')
assert.deepEqual(
  dated.map((task) => task.key),
  catalog.tasks.filter((task) => dated.some((item) => item.key === task.key)).map((task) => task.key)
)
const source = await readFile(report + 'completion.json')
const sha = createHash('sha256').update(source).digest('hex')
const attachment = `generated/attachments/${sha}.json`
for (const base of ['wiki/public/', 'wiki/dist/'])
  assert.deepEqual(await readFile(base + attachment), source)
const site = JSON.parse(await readFile('wiki/dist/generated/catalog.json', 'utf8'))
const guide = site.entries.find((entry) => entry.id === 'project-refactoring')
assert.ok(guide.html.includes(attachment))
assert.equal(site.meta.version, '0.0.355')
await writeFile(report + 'catalog.json', JSON.stringify({
  version: site.meta.version,
  source_public_dist_equal: true,
  plans: catalog.plans.length, epics: catalog.epics.length, tasks: catalog.tasks.length,
  active: overview.active.map(({key, context}) => ({key, context})),
  history: overview.history.length, unknown: 20, accepted: overview.accepted,
  dated_order: dated.map(({key, completion}) => ({key, date: completion.date, basis: completion.basis})),
  task, next, receipt: {attachment, sha256: sha, bytes: source.length, copies_equal: true},
}, null, 2) + '\n')
console.log(JSON.stringify({history: 83, unknown: 20, source_public_dist_equal: true, attachment}))
