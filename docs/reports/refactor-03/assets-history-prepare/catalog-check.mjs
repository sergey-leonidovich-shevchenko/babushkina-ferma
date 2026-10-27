// Compare actual exported catalogs and the current preparation attachment.
import assert from 'node:assert/strict'
import { readFile, writeFile } from 'node:fs/promises'
import { readPlanningCatalog } from '../../../../wiki/scripts/planning-catalog.mjs'
import { firstLocationOverview } from '../../../../wiki/src/lib/first-location.ts'

const catalog = await readPlanningCatalog()
for (const folder of ['public', 'dist']) {
  assert.deepEqual(JSON.parse(await readFile(`wiki/${folder}/generated/planning.json`, 'utf8')).catalog, catalog)
}
const states = Object.fromEntries(['02', '03', '06'].map(id => [id, catalog.tasks.find(t => t.key === `refactoring--REFACTOR-${id}`).status]))
assert.deepEqual(states, { '02': 'done', '03': 'in_progress', '06': 'blocked' })
const held = catalog.tasks.find(t => t.key === 'refactoring--REFACTOR-06')
assert.ok(JSON.stringify(held).includes('новая прямая команда'))
const overview = firstLocationOverview(catalog)
assert.equal(overview.history.length, 83)
assert.equal(overview.accepted, false)
const site = JSON.parse(await readFile('wiki/dist/generated/catalog.json', 'utf8'))
assert.equal(site.meta.version, '0.0.364')
const article = site.entries.find(e => e.id === 'project-refactoring')
assert.ok(article.html.includes('Кандидат0.0.364') && article.html.includes('root481'))
const link = article.html.match(/href="([^"]+)" download="profile.json">Профиль подготовки/)
assert.ok(link)
assert.deepEqual(await readFile('wiki/dist/' + link[1]), await readFile(new URL('./profile.json', import.meta.url)))
await writeFile(new URL('./catalog.json', import.meta.url), JSON.stringify({
  version: site.meta.version, source_public_dist_equal: true, states, history: 83,
  VMAP_accepted: false, root_sources: 481, preparation_attachment_equal: true,
  user_stop_after_full03: true, REFACTOR06_requires_new_direct_command: true,
}, null, 2) + '\n', { flag: 'wx' })
console.log(JSON.stringify({ version: site.meta.version, states, history: 83, attachment_equal: true }))
