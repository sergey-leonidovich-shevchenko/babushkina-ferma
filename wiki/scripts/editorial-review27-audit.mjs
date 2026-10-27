import assert from 'node:assert/strict'
import { execFileSync } from 'node:child_process'
import { readFile } from 'node:fs/promises'
import { join } from 'node:path'
import MarkdownIt from 'markdown-it'
import { projectRoot } from './runtime.mjs'
import { readPlanningCatalog } from './planning-catalog.mjs'

const directory = 'docs/reports/creative/2026-10-27'
const read = (path) => readFile(join(projectRoot, path), 'utf8')
const json = async (path) => JSON.parse(await read(path))
const plan = await json(`${directory}/plan.json`)
const git = (...args) =>
  execFileSync('git', args, { cwd: projectRoot, encoding: 'utf8', maxBuffer: 32 * 1024 * 1024 })
const previous = (path) => JSON.parse(git('show', `${plan.base}:${path}`))
const preserve = (oldRows, rows, key) => {
  const byId = new Map(rows.map((row) => [row[key], row]))
  assert.equal(byId.size, rows.length, `duplicate ${key}`)
  for (const row of oldRows)
    assert.deepEqual(byId.get(row[key]), row, `changed ${key}: ${row[key]}`)
}
const state = await json('wiki/planning/state.json')
const oldState = previous('wiki/planning/state.json')
preserve(oldState.ideas, state.ideas, 'id')
assert.deepEqual(state.groups, oldState.groups)
assert.deepEqual(state.epicGroups, oldState.epicGroups)
assert.equal(state.revision, oldState.revision + 1)
assert.equal(state.ideas.length, oldState.ideas.length + 10)
const ratings = await json('wiki/planning/assessments.json')
const oldRatings = previous('wiki/planning/assessments.json')
preserve(oldRatings.ideas, ratings.ideas, 'idea')
for (const [id, source] of Object.entries(oldRatings.sources))
  assert.deepEqual(ratings.sources[id], source)
const sources = await json('wiki/planning/sources.json')
const oldSources = previous('wiki/planning/sources.json')
for (const source of oldSources.plans) {
  const wanted = structuredClone(source)
  if (wanted.id === 'wiki') wanted.expected++
  assert.deepEqual(
    sources.plans.find((row) => row.id === source.id),
    wanted
  )
}
assert.deepEqual(sources.queues, oldSources.queues)
preserve(previous('wiki/articles/index.json'), await json('wiki/articles/index.json'), 'id')

// Сверяем полный diff принятой базы, чтобы не потерять исторические файлы и чужую реализацию.
const baselinePaths = new Set(git('ls-tree', '-r', '--name-only', plan.base).trim().split('\n'))
const allowed = new Set(plan.allowedExisting)
const changed = git('diff', '--name-only', '-z', plan.base, '--').split('\0').filter(Boolean)
for (const path of changed)
  if (baselinePaths.has(path)) assert(allowed.has(path), `unrelated existing source: ${path}`)
const cardSource = 'docs/backlog/wiki-workspace-2026-10/README.md'
assert(
  (await read(cardSource)).startsWith(git('show', `${plan.base}:${cardSource}`)),
  'existing cards/history changed'
)
const reserved = new Set(plan.reservedPRs.flatMap((row) => row.ids))
assert.equal(reserved.size, 20)
assert.equal(plan.ideas.length, 10)
const catalog = await readPlanningCatalog()
const byId = new Map(catalog.tasks.map((row) => [row.id, row]))
assert.equal(byId.size, catalog.tasks.length)
const visiting = new Set(),
  done = new Set()
function visit(id) {
  assert(byId.has(id), `missing dependency: ${id}`)
  assert(!visiting.has(id), `cycle: ${id}`)
  if (done.has(id)) return
  visiting.add(id)
  for (const dependency of byId.get(id).dependencies) visit(dependency)
  visiting.delete(id)
  done.add(id)
}
for (const id of byId.keys()) visit(id)

const md = new MarkdownIt({ html: false, linkify: true })
let taskCount = 0,
  nodes = 0,
  answers = 0,
  scenarios = 0
for (const idea of plan.ideas) {
  assert(!reserved.has(idea.n))
  assert(idea.n >= 262 && idea.n <= 271)
  const record = state.ideas.find((row) => row.id === idea.id)
  assert.equal(record.status, 'proposed')
  assert.equal(record.group, idea.group)
  assert.deepEqual(record.linkedEpics, [idea.epic])
  const source = sources.plans.find((row) => row.id === `idea-${idea.n}`)
  assert.equal(source.group, idea.group)
  assert.equal(source.expected, idea.tasks.length)
  const tasks = catalog.tasks.filter((row) => row.id.startsWith(`${idea.id}-`))
  assert.equal(tasks.length, idea.tasks.length)
  assert.equal(tasks[0].dependencies.length, 0, 'paper stage must stand alone')
  for (const task of tasks) {
    assert.equal(task.status, 'backlog')
    assert(task.acceptance.length >= 2)
    assert(task.goal.length > 20)
  }
  for (const task of tasks.slice(1)) {
    assert(task.dependencies.includes('IDEA-232-04'))
    assert(task.dependencies.includes('VMAP-003'))
  }
  const assessment = ratings.ideas.find((row) => row.idea === idea.id)
  for (const key of ['usefulness', 'interest', 'fit', 'synergy', 'cost', 'risk'])
    assert(assessment[key] >= 1 && assessment[key] <= 5)
  assert.equal(
    assessment.value,
    6 * assessment.usefulness +
      6 * assessment.interest +
      5 * assessment.fit +
      3 * assessment.synergy
  )
  assert.equal(assessment.confidence, 'hypothesis')
  assert.equal(assessment.familiarity, idea.n === 266 ? 2 : null)
  assert(assessment.prototype.length > 100 && assessment.rationale.length > 150)
  assert(ratings.sources[assessment.source])
  const article = await read(`wiki/articles/${idea.id}.md`)
  const tokens = md.parse(article, {})
  const tableCount = tokens.filter((token) => token.type === 'table_open').length
  assert.equal(tableCount, 4, `two dialogues, tasks, ratings tables: ${idea.id}`)
  assert.equal((article.match(new RegExp(`### D${idea.n}-`, 'g')) ?? []).length, 2)
  assert.equal((article.match(new RegExp(`\\*\\*F${idea.n}-\\d{2}\\.\\*\\*`, 'g')) ?? []).length, 6)
  for (const [, , line, choices] of idea.dialogs) {
    assert(line.length > 20 && choices.length === 3)
    for (const [answer, response, effect] of choices)
      assert(answer.length > 10 && response.length > 10 && effect.length > 5)
  }
  assert(article.includes('сейчас не выполнены'))
  assert(article.includes('Сохранение и совместимость'))
  assert(article.includes('Риски и способы проверки'))
  taskCount += tasks.length
  nodes += 2
  answers += 6
  scenarios += 6
}
assert.equal(taskCount, 43)
assert.equal(byId.get(plan.task).status, 'in_progress')
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
    preservedIdeas: oldState.ideas.length,
    preservedRatings: oldRatings.ideas.length,
    ideas: state.ideas.length,
    assessments: ratings.ideas.length,
    reserved: reserved.size,
    plans: catalog.plans.length,
    epics: catalog.epics.length,
    tasks: catalog.tasks.length,
    futureTasks: taskCount,
    dialogueNodes: nodes,
    answers,
    futureScenarios: scenarios,
    acceptedExistingFilesPreserved:
      baselinePaths.size - changed.filter((path) => baselinePaths.has(path)).length,
    formatting: formatting.map((command) => ({ command: ['git', ...command], exitCode: 0 })),
    gameplayImplemented: false,
    audienceTested: false,
  })
)
