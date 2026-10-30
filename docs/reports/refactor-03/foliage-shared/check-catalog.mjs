import assert from 'node:assert/strict'
import { readFile, writeFile } from 'node:fs/promises'
import { readPlanningCatalog } from '../../../../wiki/scripts/planning-catalog.mjs'
import { firstLocationOverview } from '../../../../wiki/src/lib/first-location.ts'

const catalog = await readPlanningCatalog()
for (const directory of ['public', 'dist']) {
  assert.deepEqual(JSON.parse(await readFile(`wiki/${directory}/generated/planning.json`, 'utf8')).catalog, catalog)
}
assert.equal(catalog.tasks.filter(t => t.key.startsWith('refactoring--')).length, 7)
const states = Object.fromEntries(['02', '03', '06'].map(id => [id, catalog.tasks.find(t => t.key === `refactoring--REFACTOR-${id}`).status]))
assert.deepEqual(states, { '02': 'done', '03': 'in_progress', '06': 'blocked' })
const overview = firstLocationOverview(catalog)
assert.equal(overview.history.length, 83)
assert.equal(overview.accepted, false)
const site = JSON.parse(await readFile('wiki/dist/generated/catalog.json', 'utf8'))
assert.equal(site.meta.version, '0.0.380')
const article = site.entries.find(e => e.id === 'project-refactoring')
assert.ok(article.html.includes('Финальный перенос REFACTOR-03, кандидат0.0.380'))
assert.ok(article.html.includes('Корень tools82→11'))
assert.ok(article.html.includes('Все779 назначений'))
assert.ok(article.html.includes('В текущем кандидате корень tools составляет11 исходников'))
assert.ok(!article.html.includes('после полного завершения03 останавливаемся;06 требует новой прямой команды'))
const link = article.html.match(/href="([^"]+)" download="after-profile.json">Профиль380/)
assert.ok(link)
assert.deepEqual(await readFile('wiki/dist/' + link[1]), await readFile(new URL('./after-profile.json', import.meta.url)))
const fullMap = article.html.match(/href="([^"]+)" download="full-plan-coverage.json">Полная карта779/)
assert.ok(fullMap)
assert.deepEqual(await readFile('wiki/dist/' + fullMap[1]), await readFile(new URL('./full-plan-coverage.json', import.meta.url)))
const result = { version: site.meta.version, source_public_dist_equal: true, states, history: 83,
  VMAP_accepted: false, root_sources: 11, source_moves: 77, map: 491, original_plan_rows: 779,
  profile_attachment_equal: true, profile_href: link[1], full_map_attachment_equal: true, full_map_href: fullMap[1],
  parallel07_excluded_from_QA: true, refactor_cards: 7 }
const output = process.argv[2] ?? 'catalog.json'
assert.ok(['catalog.json', 'catalog-final.json'].includes(output))
await writeFile(new URL('./' + output, import.meta.url), JSON.stringify(result, null, 2) + '\n', { flag: 'wx' })
console.log(JSON.stringify(result))
