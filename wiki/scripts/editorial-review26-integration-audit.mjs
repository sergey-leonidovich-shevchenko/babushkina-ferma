import assert from 'node:assert/strict'
import { execFileSync } from 'node:child_process'
import { readFile } from 'node:fs/promises'
import { join } from 'node:path'
import { projectRoot } from './runtime.mjs'
import { readPlanningCatalog } from './planning-catalog.mjs'

const directory = 'docs/reports/creative/2026-10-26/integration-1'
const read = (path) => readFile(join(projectRoot, path), 'utf8')
const plan = JSON.parse(await read(`${directory}/plan.json`))
const git = (...args) =>
  execFileSync('git', args, { cwd: projectRoot, encoding: 'utf8', maxBuffer: 32 * 1024 * 1024 })
const previous = (base, path) => JSON.parse(git('show', `${base}:${path}`))
const rowsPreserved = (oldRows, rows, key) => {
  const byId = new Map(rows.map((row) => [row[key], row]))
  assert.equal(byId.size, rows.length, `duplicate ${key}`)
  for (const old of oldRows) assert.deepEqual(byId.get(old[key]), old, `${key} ${old[key]}`)
}

// Проверяем обе опубликованные стороны; новая metadata и указатели перечислены явно.
const currentState = JSON.parse(await read('wiki/planning/state.json'))
const currentRatings = JSON.parse(await read('wiki/planning/assessments.json'))
const currentSources = JSON.parse(await read('wiki/planning/sources.json'))
for (const base of [plan.base, plan.authorParent]) {
  const state = previous(base, 'wiki/planning/state.json')
  rowsPreserved(state.ideas, currentState.ideas, 'id')
  assert.deepEqual(currentState.groups, state.groups)
  assert.deepEqual(currentState.epicGroups, state.epicGroups)
  const ratings = previous(base, 'wiki/planning/assessments.json')
  rowsPreserved(ratings.ideas, currentRatings.ideas, 'idea')
  for (const [id, source] of Object.entries(ratings.sources))
    assert.deepEqual(currentRatings.sources[id], source)
  for (const source of previous(base, 'wiki/planning/sources.json').plans) {
    const wanted = structuredClone(source)
    if (wanted.id === 'wiki') wanted.expected++ // Обе стороны добавили по одной разной карточке.
    assert.deepEqual(
      currentSources.plans.find((row) => row.id === source.id),
      wanted
    )
  }
}

const allowed = new Set(plan.allowedExisting)
const acceptedPaths = new Set(git('ls-tree', '-r', '--name-only', plan.base).trim().split('\n'))
const acceptedChanges = git('diff', '--name-only', '-z', plan.base, '--')
  .split('\0')
  .filter(Boolean)
for (const path of acceptedChanges)
  if (acceptedPaths.has(path)) assert(allowed.has(path), `accepted source changed: ${path}`)
// Прежние материалы автора могут совпасть с принятой main. Исторические отчёты автора не меняются вовсе.
const authorChanges = git(
  'diff',
  '--name-only',
  '-z',
  plan.authorParent,
  '--',
  'docs/reports/creative'
)
  .split('\0')
  .filter(Boolean)
for (const path of authorChanges)
  assert(path.startsWith(`${directory}/`), `historical author proof changed: ${path}`)
const taskSource = 'docs/backlog/wiki-workspace-2026-10/README.md'
assert(
  (await read(taskSource)).startsWith(git('show', `${plan.base}:${taskSource}`)),
  'accepted cards changed'
)
const catalog = await readPlanningCatalog()
const taskMap = new Map(catalog.tasks.map((task) => [task.id, task]))
assert.equal(taskMap.size, catalog.tasks.length)
const visiting = new Set(),
  done = new Set()
function visit(id) {
  assert(taskMap.has(id), `missing dependency: ${id}`)
  assert(!visiting.has(id), `cycle: ${id}`)
  if (done.has(id)) return
  visiting.add(id)
  for (const dependency of taskMap.get(id).dependencies) visit(dependency)
  visiting.delete(id)
  done.add(id)
}
for (const id of taskMap.keys()) visit(id)
for (let n = 252; n <= 261; n++) {
  const idea = currentState.ideas.find((row) => row.id === `IDEA-${n}`)
  assert.equal(idea.status, 'proposed')
  const tasks = catalog.tasks.filter((row) => row.id.startsWith(`IDEA-${n}-`))
  assert(tasks.length >= 4)
  for (const task of tasks) assert.equal(task.status, 'backlog')
}
assert.equal(taskMap.get(plan.task).status, 'in_progress')
assert(taskMap.get(plan.task).content.includes('/pull/13'))
const formatting = process.argv.includes('--committed-range')
  ? [
      ['diff', '--check', `${plan.base}...HEAD`],
      ['diff', '--check', plan.base, 'HEAD'],
    ]
  : [
      ['diff', '--check', plan.base, '--'],
      ['diff', '--cached', '--check', plan.base, '--'],
    ]
for (const command of formatting) {
  try {
    git(...command)
  } catch (error) {
    if (error.stdout) process.stderr.write(error.stdout.toString())
    if (error.stderr) process.stderr.write(error.stderr.toString())
    throw error
  }
}
console.log(
  JSON.stringify({
    status: 'pass',
    base: plan.base,
    authorParent: plan.authorParent,
    ideas: currentState.ideas.length,
    assessments: currentRatings.ideas.length,
    plans: catalog.plans.length,
    epics: catalog.epics.length,
    tasks: catalog.tasks.length,
    acceptedExistingFilesPreserved:
      acceptedPaths.size - acceptedChanges.filter((path) => acceptedPaths.has(path)).length,
    historicalAuthorProofsChanged: 0,
    formatting: formatting.map((args) => ({ command: ['git', ...args], exitCode: 0 })),
    gameplayImplemented: false,
    audienceTested: false,
  })
)
