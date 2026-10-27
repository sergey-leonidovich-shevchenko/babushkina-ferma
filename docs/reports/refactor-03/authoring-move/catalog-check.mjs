// Current authoring move: compare canonical tasks with both generated Wiki catalogs.
import assert from 'node:assert/strict'
import { readFile, writeFile } from 'node:fs/promises'
import { readPlanningCatalog } from '../../../../wiki/scripts/planning-catalog.mjs'
import { firstLocationOverview } from '../../../../wiki/src/lib/first-location.ts'

const output = new URL('./catalog.json', import.meta.url)
const catalog = await readPlanningCatalog()
for (const prefix of ['wiki/public/', 'wiki/dist/']) {
  const snapshot = JSON.parse(await readFile(prefix + 'generated/planning.json', 'utf8'))
  assert.deepEqual(snapshot.catalog, catalog)
}
const overview = firstLocationOverview(catalog)
assert.equal(overview.history.length, 83)
assert.equal(overview.history.filter(task => !task.completion?.date).length, 20)
assert.equal(overview.accepted, false)
assert.deepEqual(overview.active.map(task => task.key), ['refactoring--REFACTOR-03', 'wiki--IDEA-REVIEW-20261024'])
const states = Object.fromEntries(['02', '03', '06'].map(id => [id, catalog.tasks.find(task => task.key === `refactoring--REFACTOR-${id}`).status]))
assert.deepEqual(states, { '02': 'done', '03': 'in_progress', '06': 'blocked' })
const site = JSON.parse(await readFile('wiki/dist/generated/catalog.json', 'utf8'))
assert.equal(site.meta.version, '0.0.358')
const article = site.entries.find(entry => entry.id === 'project-refactoring')
assert.ok(article.summary.includes('REFACTOR-03 в работе'))
assert.ok(article.html.includes('513'))
assert.ok(article.html.includes('/pull/21'))
const profileLink = article.html.match(/href="([^"]+)" download="profile.json">Адресные проверки нового расположения/)
assert.ok(profileLink, 'Current profile attachment is visible in generated article')
const profile = await readFile('wiki/dist/' + profileLink[1])
assert.deepEqual(profile, await readFile(new URL('./profile.json', import.meta.url)))
await writeFile(output, JSON.stringify({
  version: site.meta.version, source_public_dist_equal: true,
  history: 83, unknown: 20, accepted_VMAP: false,
  active: overview.active.map(task => task.key), states,
  article_summary: article.summary, root_tools: 513,
  current_profile_attachment_equal: true,
}, null, 2) + '\n', { flag: 'wx' })
console.log(JSON.stringify({ version: site.meta.version, states, source_public_dist_equal: true }))
