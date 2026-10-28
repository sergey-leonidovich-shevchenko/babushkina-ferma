import assert from 'node:assert/strict'
import { readFile } from 'node:fs/promises'
import { execFileSync } from 'node:child_process'
import { join } from 'node:path'
import { createHash } from 'node:crypto'
import { projectRoot } from './runtime.mjs'
import { readPlanningCatalog } from './planning-catalog.mjs'

// This editorial audit checks a confirmed plan, not the unimplemented game effect.
const base = 'd609ab4fa6d82d6d013265183f018b8836abf7cc'
const environment = Object.fromEntries(
  Object.entries(process.env).filter(([key]) => !key.startsWith('GIT_'))
)
const git = (...args) =>
  execFileSync('git', ['--no-optional-locks', ...args], {
    cwd: projectRoot,
    env: environment,
    maxBuffer: 16 * 1024 * 1024,
  })
const read = (path) => readFile(join(projectRoot, path), 'utf8')
const original = (path) => git('show', `${base}:${path}`).toString()
const parse = async (path) => JSON.parse(await read(path))
const sha = (value) => createHash('sha256').update(value).digest('hex')
const profile = await parse('docs/reports/title-00/profiles.json')
const atlas = await parse('docs/reports/world-atlas-2026-10/atlas-data.json')
assert.equal(profile.base, base)
assert.equal(profile.status, 'confirmed_design_not_implemented')
assert.equal(profile.places.length, 52)
assert.equal(profile.bosses.length, 20)
assert.equal(new Set(profile.places.map((p) => p.id)).size, 52)
assert.equal(new Set(profile.bosses.map((p) => p.id)).size, 20)
const current = profile.places.filter((p) => p.presence === 'current_map')
assert.equal(current.length, 30)
assert.deepEqual(
  current.map((p) => p.runtime).sort(),
  atlas.nodes
    .flatMap((n) => n.locations ?? [])
    .map((p) => p.id)
    .sort()
)
assert.deepEqual(
  profile.places
    .filter((p) => p.id.startsWith('atlas.'))
    .map((p) => p.atlas)
    .sort(),
  atlas.nodes
    .filter((n) => !n.locations?.length && n.id !== 'global')
    .map((n) => n.id)
    .sort()
)
assert.equal(profile.places.filter((p) => p.mode === 'settlement').length, 6)
assert.equal(profile.places.find((p) => p.runtime === 'village_river').mode, 'district')
assert.equal(profile.places.find((p) => p.id === 'atlas.ivy').runtime, null)
assert.equal(profile.places.find((p) => p.id === 'zone.grandma_farm').presence, 'planned_boundary')
assert.equal(
  profile.excluded.some((p) => p.id === 'atlas.global'),
  true
)
assert.equal(profile.bosses.filter((p) => p.presence === 'planned').length, 15)
assert.equal(profile.bosses.find((p) => p.id === 'drowned_captain').mode, 'compact')
assert.equal(
  profile.bosses.find((p) => p.id === 'forest_guardian').presence,
  'current_quest_predicate'
)

// Human tables must contain every data row, including the caveats that prevent false implementation claims.
for (const [kind, article] of [
  ['places', 'location-title-places'],
  ['bosses', 'location-title-bosses'],
]) {
  const text = await read(`wiki/articles/${article}.md`)
  const rows = text.split('\n').filter((line) => /^\| `/.test(line))
  assert.equal(rows.length, profile[kind].length)
  for (const item of profile[kind]) {
    const row = rows.find((line) => line.startsWith(`| \`${item.id}\``))
    assert.ok(row, item.id)
    for (const field of ['name', 'motif', 'motion'])
      assert.ok(row.includes(item[field]), `${item.id}: ${field}`)
    if (kind === 'bosses') assert.ok(row.includes(item.constraint), item.id)
  }
}

// Preserve existing editor decisions and every prior source entry; this plan does not occupy an IDEA number.
for (const file of [
  'wiki/planning/state.json',
  'wiki/planning/assessments.json',
  'docs/reports/world-atlas-2026-10/atlas-data.json',
]) {
  assert.equal(sha(await read(file)), sha(original(file)), file)
}
const sources = await parse('wiki/planning/sources.json')
const oldSources = JSON.parse(original('wiki/planning/sources.json'))
assert.deepEqual(sources, {
  ...oldSources,
  plans: [
    ...oldSources.plans,
    {
      id: 'location-titles',
      title: 'Названия мест и представление боссов',
      format: 'markdown',
      group: 'visual',
      expected: 25,
      epics: [
        {
          id: 'TITLE',
          title: 'Названия мест и представление боссов',
          file: 'docs/epics/location-title-reveals/TASKS.md',
        },
      ],
    },
  ],
})
const articles = await parse('wiki/articles/index.json')
assert.deepEqual(articles.slice(3), JSON.parse(original('wiki/articles/index.json')))
assert.deepEqual(
  articles.slice(0, 3).map((p) => p.id),
  ['location-title-reveals', 'location-title-places', 'location-title-bosses']
)
const catalog = await readPlanningCatalog()
const tasks = catalog.tasks.filter((t) => t.plan === 'location-titles')
assert.equal(tasks.length, 25)
assert.equal(tasks[0].id, 'TITLE-00')
assert.equal(tasks[0].status, 'in_progress')
assert.ok(
  tasks[0].result.includes(
    'https://github.com/sergey-leonidovich-shevchenko/babushkina-ferma/pull/23'
  )
)
assert.ok(tasks.slice(1).every((t) => t.status === 'backlog'))
const ids = new Set(catalog.tasks.map((t) => t.id))
const byId = new Map(tasks.map((t) => [t.id, t]))
function visit(id, path = []) {
  assert.ok(!path.includes(id), `Cycle: ${[...path, id].join(' -> ')}`)
  for (const dependency of byId.get(id)?.dependencies ?? []) {
    assert.ok(ids.has(dependency), `${id}: missing ${dependency}`)
    if (byId.has(dependency)) visit(dependency, [...path, id])
  }
}
tasks.forEach((t) => visit(t.id))
for (const task of tasks) {
  assert.ok(task.goal.length > 70 && task.acceptance.length >= 3, task.id)
  if (task.id !== 'TITLE-00') {
    assert.ok(task.content.includes('новая прямая команда'), task.id)
    assert.ok(task.content.includes('VMAP-003'), task.id)
  }
}
const scene = await read('wiki/design/title-reveals.html')
assert.ok(
  scene.replace(/\s+/g, ' ').includes('Игра, её бой, пауза, сохранения и FPS здесь не проверяются')
)
assert.ok(!/<(?:script|link)[^>]+(?:src|href)=/i.test(scene))
assert.ok(!/fetch\(|localStorage|sessionStorage|res:\/\//.test(scene))
const changed = git('diff', '--name-only', '-z', base, '--').toString().split('\0').filter(Boolean)
const prefixes = ['docs/epics/location-title-reveals/', 'docs/reports/title-00/']
const allowed = new Set([
  'VERSION',
  'project.godot',
  'Бабушкина ферма.app/Contents/Info.plist',
  'docs/backlog/README.md',
  'wiki/planning/sources.json',
  'wiki/articles/index.json',
  'wiki/scripts/title-catalog-audit.mjs',
  'wiki/design/title-reveals.html',
  ...articles.slice(0, 3).map((a) => `wiki/articles/${a.file}`),
])
assert.ok(
  changed.every((p) => allowed.has(p) || prefixes.some((prefix) => p.startsWith(prefix))),
  changed.join('\n')
)
assert.equal(
  (await read('docs/backlog/README.md'))
    .split('\n')
    .filter((line) => !line.startsWith('| [TITLE —'))
    .join('\n'),
  original('docs/backlog/README.md')
)
assert.equal(
  (await read('project.godot')).replace(/^config\/version=.*$/m, ''),
  original('project.godot').replace(/^config\/version=.*$/m, '')
)
console.log(
  JSON.stringify(
    {
      base,
      places: 52,
      currentMaps: 30,
      futureAtlasPlaces: 20,
      settlements: 6,
      encounters: 20,
      futureEncounters: 15,
      tasks: 25,
      implementationBacklog: 24,
      preservedIdeaArticles: catalog.ideaArticles.length,
      preservedStateIdeas: (await parse('wiki/planning/state.json')).ideas.length,
      stateUnchanged: true,
      assessmentsUnchanged: true,
      atlasUnchanged: true,
      dependencyGraph: 'valid',
      gameplayImplemented: false,
      futureGameplayScenariosRun: 0,
    },
    null,
    2
  )
)
