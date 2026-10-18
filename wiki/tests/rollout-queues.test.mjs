import test from 'node:test'
import assert from 'node:assert/strict'
import { writeFile, mkdtemp, rm, mkdir, symlink } from 'node:fs/promises'
import { join } from 'node:path'
import { tmpdir } from 'node:os'
import { readPlanningCatalog } from '../scripts/planning-catalog.mjs'
import { readRolloutQueues, validateQueue, developmentLink } from '../scripts/rollout-queues.mjs'
import { projectRoot, wikiRoot } from '../scripts/runtime.mjs'
import { queueTasks, queueProgress, queueBlockers, queueIssue } from '../src/lib/task-queue.ts'

const catalog = await readPlanningCatalog()
const manifest = join(wikiRoot, 'planning/sources.json')
const [queue] = await readRolloutQueues(projectRoot, manifest, catalog)

/** Изолирует состояния: будущие реальные закрытия карточек не меняют исходные условия сценария. */
function readyFixture() {
  const tasks = structuredClone(catalog.tasks)
  for (const task of tasks) task.status = 'done'
  tasks.find((task) => task.id === 'VBASE-002').status = 'ready'
  tasks.find((task) => task.id === 'VBASE-005').status = 'backlog'
  return tasks
}

test('registered pilot contains the full bounded graph without copied statuses', () => {
  assert.equal(queue.id, 'village-pilot')
  assert.equal(queue.taskKeys.length, 52)
  assert.deepEqual(
    queue.stages.map((stage) => stage.taskKeys.length),
    [31, 21]
  )
  assert.equal(queue.taskKeys.includes(queue.ownerKey), false)
  for (const id of ['VPROP-001', 'VPROP-008', 'VPROP-009', 'VPROP-010'])
    assert.equal(queue.taskKeys.includes(`visual--${id}`), false)
  assert.ok(queue.taskKeys.includes('visual--VCAMERA-006'))
  assert.equal(/"status"/.test(JSON.stringify(queue)), false)
  assert.equal(queue.implementationAccepted, false)
  assert.deepEqual(validateQueue(queue, catalog), queue)
})

test('queue rejects unknown cards, missing closure, cycles and invalid stage order', () => {
  for (const mutate of [
    (q) => {
      q.taskKeys[0] = 'visual--UNKNOWN-001'
    },
    (q) => {
      q.taskKeys.splice(q.taskKeys.indexOf('visual--VPROP-003'), 1)
    },
    (q) => {
      q.extraDependencies['visual--VBASE-002'] = ['visual--VBASE-005']
    },
    (q) => {
      q.stages.reverse()
    },
    (q) => {
      q.taskKeys.push(...q.taskKeys)
    },
    (q) => {
      q.stages[0].taskKeys.push(q.stages[0].taskKeys[0])
    },
    (q) => {
      q.extraDependencies['visual--VICON-001'] = []
    },
    (q) => {
      q.stages = null
    },
  ]) {
    const bad = structuredClone(queue)
    mutate(bad)
    assert.throws(() => validateQueue(bad, catalog))
  }
})

test('changed canonical dependencies require a refreshed build even with a still valid order', () => {
  const changed = structuredClone(catalog)
  changed.tasks.find((task) => task.id === 'VBASE-005').dependencies.push('VBASE-002')
  assert.throws(() => validateQueue(queue, changed), /Зависимости изменились/)
})

test('a completed acceptance cannot hide an open extra condition', () => {
  const changed = { ...catalog, tasks: readyFixture() }
  for (const task of changed.tasks) task.status = 'done'
  changed.tasks.find((task) => task.id === 'VPROP-003').status = 'backlog'
  assert.throws(() => validateQueue(queue, changed), /Завершённая задача.*блокер/)
})

test('registered queues reject traversal, escaping symlinks, duplicate IDs and mismatched names', async (t) => {
  const root = await mkdtemp(join(tmpdir(), 'wiki-rollout-'))
  const outside = await mkdtemp(join(tmpdir(), 'wiki-rollout-outside-'))
  t.after(() => rm(root, { recursive: true, force: true }))
  t.after(() => rm(outside, { recursive: true, force: true }))
  await mkdir(join(root, 'docs'), { recursive: true })
  await writeFile(join(root, 'docs/queue.json'), JSON.stringify(queue))
  await writeFile(join(outside, 'queue.json'), JSON.stringify(queue))
  await symlink(join(outside, 'queue.json'), join(root, 'docs/link.json'))
  for (const definitions of [
    [{ id: queue.id, file: '../queue.json' }],
    [{ id: queue.id, file: 'docs/link.json' }],
    [{ id: 'another-pilot', file: 'docs/queue.json' }],
    [
      { id: queue.id, file: 'docs/queue.json' },
      { id: queue.id, file: 'docs/queue.json' },
    ],
  ]) {
    await writeFile(join(root, 'sources.json'), JSON.stringify({ queues: definitions }))
    await assert.rejects(readRolloutQueues(root, join(root, 'sources.json'), catalog))
  }
})

test('editorial links resolve only real tasks and known queue stages', () => {
  for (const href of [
    '#/development/tasks?queue=village-pilot',
    '#/development/tasks?queue=village-pilot&stage=foundation',
    '#/development/tasks/visual--VBASE-002',
  ])
    assert.equal(developmentLink(href, catalog, [queue]), href)
  assert.equal(developmentLink('https://example.org/', catalog, [queue]), undefined)
  for (const href of [
    '#/development/tasks/visual--UNKNOWN-001',
    '#/development/tasks?queue=unknown',
    '#/development/tasks?stage=foundation',
    '#/development/tasks?queue=village-pilot&stage=unknown',
    '#/development/tasks?queue=village-pilot&queue=unknown',
    '#/development/tasks?file=state.json',
    '#/development/tasks/visual--%ZZ',
    '#/development/other',
  ])
    assert.throws(() => developmentLink(href, catalog, [queue]))
})

test('live status changes update progress without mutating tasks or queue', () => {
  const tasks = readyFixture()
  // Откроем зависящие от VBASE-002 карточки: done с открытым условием был бы ошибкой плана.
  for (const task of tasks) if (queueBlockers(task, queue, tasks).length) task.status = 'backlog'
  const snapshot = JSON.stringify({ queue, tasks })
  const first = queueProgress(queue, tasks)
  assert.equal(first.next.id, 'VBASE-002')
  assert.equal(first.preparable.id, 'VBASE-005')
  assert.equal(first.total, 52)
  assert.equal(JSON.stringify({ queue, tasks }), snapshot)
  tasks.find((task) => task.id === 'VBASE-002').status = 'done'
  const second = queueProgress(queue, tasks)
  assert.equal(second.done, first.done + 1)
  assert.notEqual(second.next?.id, 'VBASE-002')
})

test('backlog and externally blocked tasks are never recommended as ready', () => {
  const tasks = readyFixture()
  tasks.find((task) => task.id === 'VBASE-002').status = 'blocked'
  assert.equal(queueProgress(queue, tasks).next, undefined)
  assert.equal(queueProgress(queue, tasks).preparable.id, 'VBASE-005')
  tasks.find((task) => task.id === 'VBASE-002').status = 'backlog'
  assert.equal(queueProgress(queue, tasks).next, undefined)
})

test('stage filters preserve dependency order and unknown routes return no global fallback', () => {
  assert.deepEqual(
    queueTasks(catalog.tasks, queue).map((task) => task.key),
    queue.taskKeys
  )
  assert.equal(queueTasks(catalog.tasks, queue, 'foundation').length, 31)
  assert.equal(queueTasks(catalog.tasks, queue, 'static-preview').length, 21)
  assert.deepEqual(queueTasks(catalog.tasks, queue, 'unknown'), [])
  assert.deepEqual(queueTasks(catalog.tasks), [])
})

test('live refresh exposes missing or later dependencies and false done cards', () => {
  const tasks = readyFixture()
  assert.match(
    queueIssue(
      queue,
      tasks.filter((task) => task.id !== 'VPROP-003')
    ),
    /Нет карточки|Зависимости/
  )
  tasks.find((task) => task.id === 'VBASE-002').dependencies.push('VRELEASE-002')
  assert.match(queueIssue(queue, tasks), /Зависимости изменились/)
  const other = readyFixture()
  assert.match(queueIssue(queue, other), /открыты|условия/)
  const prop = other.find((task) => task.id === 'VRELEASE-002')
  other.find((task) => task.id === 'VPROP-003').status = 'backlog'
  assert.ok(queueBlockers(prop, queue, other).includes('visual--VPROP-003'))
})
