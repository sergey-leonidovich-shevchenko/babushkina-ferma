// Check the isolated published candidate; the concurrent Team plan stays outside this tree.
import assert from 'node:assert/strict'
import { readFile, writeFile } from 'node:fs/promises'
import { readPlanningCatalog } from '../../../../wiki/scripts/planning-catalog.mjs'
import { firstLocationOverview } from '../../../../wiki/src/lib/first-location.ts'

const catalog = await readPlanningCatalog()
for (const directory of ['public', 'dist']) {
  assert.deepEqual(JSON.parse(await readFile(`wiki/${directory}/generated/planning.json`, 'utf8')).catalog, catalog)
}
const tasks = catalog.tasks.filter(t => t.key.startsWith('refactoring--'))
assert.equal(tasks.length, 7)
const states = Object.fromEntries(['02', '03', '06'].map(id => [id, catalog.tasks.find(t => t.key === `refactoring--REFACTOR-${id}`).status]))
assert.deepEqual(states, { '02': 'done', '03': 'in_progress', '06': 'blocked' })
assert.ok(JSON.stringify(catalog.tasks.find(t => t.key === 'refactoring--REFACTOR-03')).includes('0.0.367'))
const overview = firstLocationOverview(catalog)
assert.equal(overview.history.length, 83)
assert.equal(overview.accepted, false)
const site = JSON.parse(await readFile('wiki/dist/generated/catalog.json', 'utf8'))
assert.equal(site.meta.version, '0.0.367')
const article = site.entries.find(e => e.id === 'project-refactoring')
assert.ok(article.html.includes('Подготовка0.0.367 alpha/slicing'))
const link = article.html.match(/href="([^"]+)" download="profile.json">Профиль до переноса367/)
assert.ok(link)
assert.deepEqual(await readFile('wiki/dist/' + link[1]), await readFile(new URL('./profile.json', import.meta.url)))
await writeFile(new URL('./catalog.json', import.meta.url), JSON.stringify({
  version: site.meta.version, source_public_dist_equal: true, states, history: 83,
  VMAP_accepted: false, root_sources: 420, profile_attachment_equal: true, profile_href: link[1],
  parallel07_excluded_from_QA: true, refactor_cards_in_candidate: 7, REFACTOR06_started: false,
}, null, 2) + '\n', { flag: 'wx' })
console.log(JSON.stringify({ version: site.meta.version, states, history: 83, profile_attachment_equal: true }))
