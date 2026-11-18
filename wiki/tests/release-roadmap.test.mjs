import test from 'node:test'
import assert from 'node:assert/strict'
import { readFile } from 'node:fs/promises'
import { readPlanningCatalog } from '../scripts/planning-catalog.mjs'
import { validateWorkspace } from '../scripts/planning-store.mjs'
import {
  releaseRoadmap,
  releaseMaps,
  demoMaps,
  roadmapClosure,
} from '../src/lib/release-roadmap.ts'

const catalog = await readPlanningCatalog()
const pilot = JSON.parse(
  await readFile(
    new URL('../../docs/reports/visual-overhaul/vrelease-001/queue.json', import.meta.url)
  )
)

// Реальный каталог: каждая из существующих карт имеет ровно одно место в программе выпуска.
test('release roadmap covers 10 demo maps and all 30 existing maps without losing canonical tasks', () => {
  const stages = releaseRoadmap(catalog.tasks, pilot.taskKeys)
  assert.equal(stages.length, 5)
  assert.equal(demoMaps.length, 10)
  assert.equal(releaseMaps.length, 30)
  assert.equal(new Set(releaseMaps.map(([id]) => id)).size, 30)
  const maps = [
    'overworld',
    ...stages
      .flatMap((stage) => stage.cards)
      .filter((card) => card.map)
      .map((card) => card.map),
  ]
  assert.deepEqual([...maps].sort(), releaseMaps.map(([id]) => id).sort())
  for (const stage of stages) {
    assert.deepEqual(stage.issues, [])
    assert.equal(new Set(stage.tasks.map((task) => task.key)).size, stage.tasks.length)
    assert.equal(stage.done, stage.tasks.filter((task) => task.status === 'done').length)
    for (const card of stage.cards) {
      assert.deepEqual(card.issues, [])
      assert.ok(card.tasks.length)
      assert.ok(new Set(card.tasks.map((task) => task.epic)).size >= 2, card.id)
    }
  }
  assert.ok(stages[0].tasks.some((task) => task.id === 'VSHORE-006'))
  assert.ok(stages[2].tasks.some((task) => task.id === 'DEMO-006'))
  assert.ok(stages[3].tasks.some((task) => task.id === 'RELEASE-004'))
})

// Нельзя принять выпуск одним ошибочным done, если фактическая карта или предшествующий шаг открыты.
test('demo and full release gates require complete previous stages and refresh with canonical statuses', () => {
  const tasks = structuredClone(catalog.tasks)
  for (const task of tasks) task.status = 'done'
  let stages = releaseRoadmap(tasks, pilot.taskKeys)
  assert.ok(stages.every((stage) => stage.accepted))
  const forest = tasks.find((task) => task.key === 'visual--VMAP-006')
  forest.status = 'in_progress'
  stages = releaseRoadmap(tasks, pilot.taskKeys)
  assert.equal(stages[0].accepted, true)
  assert.equal(stages[1].accepted, false)
  assert.equal(stages[2].accepted, false)
  assert.equal(stages[3].accepted, false)
  forest.status = 'done'
  tasks.find((task) => task.key === 'release--RELEASE-004').status = 'in_progress'
  stages = releaseRoadmap(tasks, pilot.taskKeys)
  assert.equal(stages[2].accepted, true)
  assert.equal(stages[3].accepted, false)
  assert.equal(stages[4].accepted, false)
})

test('missing map or stale pilot never appears as a complete release', () => {
  const tasks = catalog.tasks
    .map((task) => ({ ...task, status: 'done' }))
    .filter((task) => task.key !== 'visual--VMAP-033')
  const stages = releaseRoadmap(tasks, pilot.taskKeys, 'Очередь требует пересборки')
  assert.ok(stages[0].issues.includes('Очередь требует пересборки'))
  assert.ok(stages[0].cards[0].issues.includes('Очередь требует пересборки'))
  assert.ok(stages[1].issues.some((issue) => issue.includes('VMAP-033')))
  assert.ok(stages.every((stage) => !stage.accepted))
  assert.ok(stages[1].cards.find((card) => card.id === 'village_garden').tasks.length)
})

// Дубли общих блокеров не увеличивают счётчик; цикл и неоднозначный внешний ID видны как ошибка.
test('dependency traversal deduplicates and rejects cycles and ambiguous external IDs', () => {
  const sample = catalog.tasks[0]
  const row = (plan, id, dependencies = []) => ({
    ...sample,
    plan,
    id,
    key: `${plan}--${id}`,
    dependencies,
  })
  const tasks = [
    row('a', 'ROOT-01', ['BASE-01', 'BASE-02']),
    row('a', 'BASE-01', ['SHARED-01']),
    row('a', 'BASE-02', ['SHARED-01']),
    row('b', 'SHARED-01'),
  ]
  let result = roadmapClosure(['a--ROOT-01', 'a--BASE-01'], tasks)
  assert.equal(result.tasks.length, 4)
  assert.deepEqual(result.issues, [])
  tasks[3].dependencies = ['ROOT-01']
  result = roadmapClosure(['a--ROOT-01'], tasks)
  assert.ok(result.issues.some((issue) => issue.includes('Цикл')))
  tasks[3].dependencies = []
  tasks.push(row('c', 'SHARED-01'))
  result = roadmapClosure(['a--ROOT-01'], tasks)
  assert.ok(result.issues.some((issue) => issue.includes('однозначная')))
})

// Реальные ворота демо: паспорт не заменяет выбор, движение и приёмку обоих тел.
test('hero guide is published and reachable from the release roadmap', async () => {
  const built = JSON.parse(
    await readFile(new URL('../public/generated/catalog.json', import.meta.url), 'utf8')
  )
  const guide = built.entries.find(
    (entry) => entry.category === 'guides' && entry.id === 'demo-heroes'
  )
  const roadmap = built.entries.find((entry) => entry.id === 'release-roadmap')
  assert.ok(guide)
  assert.ok(guide.tags.includes('HERO'))
  assert.match(roadmap.html, /#\/guides\/demo-heroes/)
  assert.match(guide.html, /#\/development\/epics\/hero--HERO/)
})

test('demo requires both hero production and acceptance, including missing task failures', () => {
  const tasks = structuredClone(catalog.tasks)
  for (const task of tasks) task.status = 'done'
  const hero = tasks.find((task) => task.key === 'hero--HERO-02')
  const art = tasks.find((task) => task.key === 'visual--VACTOR-003')
  const demoArt = tasks.find((task) => task.key === 'release--DEMO-007')
  assert.ok(demoArt.dependencies.includes('HERO-02'))
  const gate = roadmapClosure(['release--DEMO-006'], tasks)
  assert.deepEqual(gate.issues, [])
  for (const id of [
    'VANIM-002',
    'VACTOR-001',
    'VACTOR-002',
    'VACTOR-003',
    'VACTOR-004',
    'HERO-01',
    'HERO-02',
  ]) {
    assert.ok(
      gate.tasks.some((task) => task.id === id),
      id
    )
  }
  for (const pending of [hero, art]) {
    pending.status = 'blocked'
    const stages = releaseRoadmap(tasks, pilot.taskKeys)
    const card = stages[1].cards.find((card) => card.id === 'heroes')
    assert.ok(card.tasks.some((task) => task.key === pending.key && task.status === 'blocked'))
    assert.equal(stages[1].accepted, false)
    assert.equal(stages[2].accepted, false)
    pending.status = 'done'
  }
  const missing = releaseRoadmap(
    tasks.filter((task) => task !== hero),
    pilot.taskKeys
  )
  assert.equal(missing[2].accepted, false)
  assert.ok(missing[1].issues.some((issue) => issue.includes('HERO-02')))
})

test('editorial workspace stays valid and rollout does not mutate decisions or canonical statuses', async () => {
  const state = JSON.parse(await readFile(new URL('../planning/state.json', import.meta.url)))
  validateWorkspace(state, catalog)
  const idea = state.ideas.find((idea) => idea.id === 'IDEA-192')
  const before = JSON.stringify({ state, catalog })
  releaseRoadmap(catalog.tasks, pilot.taskKeys)
  assert.equal(JSON.stringify({ state, catalog }), before)
  assert.deepEqual(idea.linkedEpics, ['idea-192--IDEA-192'])
  const task = catalog.tasks.find((task) => task.key === 'idea-192--IDEA-192-01')
  assert.ok(task.dependencies.includes('DEMO-006'))
  for (const task of catalog.tasks.filter((task) => task.plan === 'release')) {
    assert.ok(task.acceptance.length >= 3)
  }
})
