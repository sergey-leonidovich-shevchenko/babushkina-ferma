// P2 changes live documentation, not planning status or the accepted visual route.
import assert from 'node:assert/strict'
import { readFile, writeFile } from 'node:fs/promises'
import { readPlanningCatalog } from '../../../../wiki/scripts/planning-catalog.mjs'
import { firstLocationOverview } from '../../../../wiki/src/lib/first-location.ts'

const catalog = await readPlanningCatalog()
for (const folder of ['public', 'dist']) {
  assert.deepEqual(JSON.parse(await readFile(`wiki/${folder}/generated/planning.json`, 'utf8')).catalog, catalog)
}
const overview = firstLocationOverview(catalog)
const states = Object.fromEntries(['02', '03', '06'].map(id => [id, catalog.tasks.find(task => task.key === `refactoring--REFACTOR-${id}`).status]))
assert.deepEqual(states, { '02': 'done', '03': 'in_progress', '06': 'blocked' })
assert.equal(overview.history.length, 83)
assert.equal(overview.accepted, false)
const site = JSON.parse(await readFile('wiki/dist/generated/catalog.json', 'utf8'))
assert.equal(site.meta.version, '0.0.359')
assert.ok(site.entries.find(entry => entry.id === 'project-refactoring').html.includes('/pull/21'))
await writeFile(new URL('./catalog.json', import.meta.url), JSON.stringify({
  version: site.meta.version, source_public_dist_equal: true, states,
  history: 83, accepted_VMAP: false, planning_status_unchanged: true,
}, null, 2) + '\n', { flag: 'wx' })
console.log(JSON.stringify({ version: site.meta.version, states }))
