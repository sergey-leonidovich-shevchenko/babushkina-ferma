import assert from 'node:assert/strict'
import { execFileSync } from 'node:child_process'
import { readFile, writeFile, mkdtemp, rm } from 'node:fs/promises'
import { join } from 'node:path'
import { tmpdir } from 'node:os'
import MarkdownIt from 'markdown-it'
import { projectRoot } from './runtime.mjs'
import { readPlanningCatalog } from './planning-catalog.mjs'

// Ручной профиль именно этой редакционной подборки. Старые отчёты не обновляет.
const directory = 'docs/reports/creative/2026-10-26'
const json = async (path) => JSON.parse(await readFile(join(projectRoot, path), 'utf8'))
const git = (args) => execFileSync('git', args, { cwd: projectRoot, maxBuffer: 32 * 1024 * 1024 })
const at = (ref, path) => JSON.parse(git(['show', `${ref}:${path}`]).toString())
const plan = await json(`${directory}/plan.json`)
const state = await json('wiki/planning/state.json')
const ratings = await json('wiki/planning/assessments.json')
const sources = await json('wiki/planning/sources.json')
const index = await json('wiki/articles/index.json')

function preserved(before, after, key) {
  const rows = new Map(after.map((row) => [row[key], row]))
  assert.equal(rows.size, after.length, `повтор ${key}`)
  for (const row of before)
    assert.deepEqual(rows.get(row[key]), row, `изменена прежняя запись ${row[key]}`)
}

const previous = at(plan.base, 'wiki/planning/state.json')
preserved(previous.ideas, state.ideas, 'id')
assert.deepEqual(state.groups, previous.groups)
assert.deepEqual(state.epicGroups, previous.epicGroups)
assert.equal(state.revision, previous.revision + 1)
const oldRatings = at(plan.base, 'wiki/planning/assessments.json')
preserved(oldRatings.ideas, ratings.ideas, 'idea')
for (const [id, source] of Object.entries(oldRatings.sources))
  assert.deepEqual(ratings.sources[id], source)
preserved(at(plan.base, 'wiki/articles/index.json'), index, 'id')
const oldSources = at(plan.base, 'wiki/planning/sources.json')
for (const row of oldSources.plans) {
  const expected = structuredClone(row)
  if (expected.id === 'wiki') expected.expected += 1
  assert.deepEqual(
    sources.plans.find((source) => source.id === row.id),
    expected
  )
}
assert.deepEqual(sources.queues, oldSources.queues)
assert.equal(state.ideas.length, plan.expected.ideas)
assert.equal(ratings.ideas.length, plan.expected.assessments)
assert(
  state.ideas.every((idea) => !/^IDEA-22[2-9]$|^IDEA-23[01]$/.test(idea.id)),
  'резерв PR2 импортирован'
)

// Снимок принятых карточек читается из настоящего Git archive, а не текущей папки.
const root = await mkdtemp(join(tmpdir(), 'creative26-accepted-'))
let oldCatalog
try {
  const paths = [
    'docs/backlog',
    'docs/epics',
    'wiki/planning',
    'wiki/articles',
    ...(oldSources.queues ?? []).map((queue) => queue.file),
  ]
  execFileSync('tar', ['-x', '-C', root], { input: git(['archive', plan.base, ...paths]) })
  oldCatalog = await readPlanningCatalog({
    root,
    manifest: join(root, 'wiki/planning/sources.json'),
  })
} finally {
  await rm(root, { recursive: true, force: true })
}
const catalog = await readPlanningCatalog()
assert.equal(catalog.plans.length, plan.expected.plans)
assert.equal(catalog.epics.length, plan.expected.epics)
assert.equal(catalog.tasks.length, plan.expected.tasks)
const tasks = new Map(catalog.tasks.map((task) => [task.id, task]))
assert.equal(tasks.size, catalog.tasks.length)
for (const old of oldCatalog.tasks) {
  const actual = tasks.get(old.id)
  assert(actual, `потеряна карточка ${old.id}`)
  // Добавленный следующий anchor может расширить content последней WIKI-карточки.
  // Её смысловые поля, статус, разделы и результат должны остаться точными.
  for (const [key, value] of Object.entries(old))
    if (key !== 'content') assert.deepEqual(actual[key], value, `${old.id}.${key}`)
}
// Весь импортированный граф проверяется до отдельных новых карточек.
const visiting = new Set(),
  visited = new Set()
function visit(id) {
  assert(tasks.has(id), `неизвестная зависимость ${id}`)
  assert(!visiting.has(id), `цикл ${id}`)
  if (visited.has(id)) return
  visiting.add(id)
  for (const dependency of tasks.get(id).dependencies) visit(dependency)
  visiting.delete(id)
  visited.add(id)
}
for (const id of tasks.keys()) visit(id)
assert.equal(tasks.get(plan.task).status, 'in_progress')
assert.equal(tasks.get('IDEA-REVIEW-20261025').status, 'done')
assert.equal(tasks.get('IDEA-REVIEW-20261024').status, 'in_progress')
assert.equal(tasks.get('REFACTOR-01').status, 'ready')
assert.equal(tasks.get('VFOLIAGE-010').status, 'done')

// ID должен находиться именно в строке таблицы указателя, а не в случайном тексте.
function tableContent(source) {
  let depth = 0,
    text = ''
  for (const token of new MarkdownIt().parse(source, {})) {
    if (token.type === 'table_open') depth += 1
    if (token.type === 'table_close') depth -= 1
    if (depth && token.type === 'inline') text += `${token.content}\n`
  }
  return text
}
const tables = await Promise.all(
  ['docs/epics/ideas/README.md', 'wiki/articles/idea-feature-epics.md'].map(async (path) =>
    tableContent(await readFile(join(projectRoot, path), 'utf8'))
  )
)
let newTasks = 0,
  nodes = 0,
  answers = 0,
  scenarios = 0
for (const idea of plan.ideas) {
  const own = catalog.tasks.filter((task) => task.epic === `idea-${idea.n}--${idea.id}`)
  assert.equal(own.length, idea.stages.length)
  assert(own.every((task) => task.status === 'backlog'))
  assert.deepEqual(own[0].dependencies, [])
  assert(own[2].dependencies.includes('IDEA-232-04'))
  if ([253, 256, 258, 259, 260].includes(idea.n))
    assert(own[1].dependencies.includes('IDEA-232-04'))
  const row = state.ideas.find((item) => item.id === idea.id)
  assert.equal(row.status, 'proposed')
  assert.equal(row.group, idea.group)
  assert.deepEqual(row.linkedEpics, [`idea-${idea.n}--${idea.id}`])
  const source = await readFile(join(projectRoot, `wiki/articles/${idea.id}.md`), 'utf8')
  assert(source.includes(idea.mvp))
  // Linkify считает .md доменной зоной: ссылка на локальное правило не должна уйти наружу.
  for (const token of new MarkdownIt({ linkify: true }).parse(source, {})) {
    for (const child of token.children ?? []) {
      if (child.type === 'link_open') {
        assert(
          !/^https?:\/\/(testing|tasks)\.md(?:\/|$)/i.test(child.attrGet('href') ?? ''),
          'локальный файл стал внешним доменом'
        )
      }
    }
  }

  assert(!source.includes('](../../docs/epics/ideas/'), 'файловая ссылка TASKS уйдёт в общий поиск')
  assert(source.includes(`[Первый этап](#/development/tasks/idea-${idea.n}--${idea.id}-01)`))
  assert.equal([...source.matchAll(new RegExp(`^### D${idea.n}-`, 'gm'))].length, 3)
  for (const [speaker, line, replies] of idea.dialogue) {
    assert(source.includes(speaker) && source.includes(line))
    for (const reply of replies) for (const part of reply) assert(source.includes(part))
    nodes += 1
    answers += replies.length
  }
  for (let i = 1; i <= 6; i++) {
    assert(source.includes(`F${idea.n}-${String(i).padStart(2, '0')}`))
    scenarios += 1
  }
  for (const table of tables) assert(table.includes(idea.id), `строка вне таблицы ${idea.id}`)
  const rating = ratings.ideas.find((item) => item.idea === idea.id)
  assert.equal(
    rating.value,
    6 * rating.usefulness + 6 * rating.interest + 5 * rating.fit + 3 * rating.synergy
  )
  assert.equal(rating.confidence, 'hypothesis')
  assert(ratings.sources[rating.source])
  newTasks += own.length
}
assert.equal(newTasks, plan.expected.newGameplayTasks)
assert.equal(nodes, plan.expected.dialogueNodes)
assert.equal(answers, plan.expected.answers)
assert.equal(scenarios, plan.expected.futureScenarios)

// Проверяем байты каждого прежнего файла, кроме явно разрешённых указателей и metadata.
const mutable = new Set([
  'TESTING.md',
  'VERSION',
  'project.godot',
  'Бабушкина ферма.app/Contents/Info.plist',
  'docs/backlog/README.md',
  'docs/backlog/wiki-workspace-2026-10/README.md',
  'docs/epics/ideas/README.md',
  'wiki/articles/idea-feature-epics.md',
  'wiki/articles/index.json',
  'wiki/planning/state.json',
  'wiki/planning/sources.json',
  'wiki/planning/assessments.json',
])
// Один поток hash-object читает те же байты без тысяч дочерних процессов.
const entries = git(['ls-tree', '-rz', plan.base])
  .toString()
  .split('\0')
  .filter(Boolean)
  .map((entry) => {
    const [header, path] = entry.split('\t')
    return { path, blob: header.split(' ')[2] }
  })
  .filter((entry) => !mutable.has(entry.path))
const input = entries.map((entry) => JSON.stringify(entry.path)).join('\n') + '\n'
const hashes = execFileSync('git', ['hash-object', '--stdin-paths'], {
  cwd: projectRoot,
  input,
  maxBuffer: 4 * 1024 * 1024,
})
  .toString()
  .trim()
  .split('\n')
assert.equal(hashes.length, entries.length)
for (let i = 0; i < entries.length; i++)
  assert.equal(hashes[i], entries[i].blob, `изменён прежний файл ${entries[i].path}`)
const preservedFiles = entries.length
const historicalFiles = entries.filter(
  (entry) => entry.path.startsWith('docs/reports/') || entry.path.startsWith('wiki/reports/')
).length
const oldPaths = new Set(
  git(['ls-tree', '-rz', plan.base])
    .toString()
    .split('\0')
    .filter(Boolean)
    .map((entry) => entry.split('\t')[1])
)
const ownNew = (path) =>
  (path.startsWith(`${directory}/`) && /\.(md|json|png|gz)$/.test(path)) ||
  path === 'wiki/scripts/editorial-review26-audit.mjs' ||
  path === 'wiki/articles/creative-review-2026-10-26.md' ||
  /^wiki\/articles\/IDEA-25[2-9]\.md$|^wiki\/articles\/IDEA-26[01]\.md$/.test(path) ||
  /^docs\/epics\/ideas\/idea-(25[2-9]|26[01])\/(README|TASKS)\.md$/.test(path)
for (const path of git(['ls-files', '--cached', '--others', '--exclude-standard', '-z'])
  .toString()
  .split('\0')
  .filter(Boolean))
  assert(oldPaths.has(path) || ownNew(path), `чужой новый файл ${path}`)
for (const path of ['scripts', 'assets', 'tests', 'tools', '.githooks', 'main.tscn'])
  assert.equal(
    git(['diff', '--name-only', plan.base, '--', path]).toString(),
    '',
    `gameplay/QA-код изменён ${path}`
  )
if (plan.previousCheckpoint) {
  // Сырые результаты первого коммита не перезаписываются финальным прогоном.
  for (const name of [
    'gates-first.json',
    'full-hook-first.log.gz',
    'wiki-first.log.gz',
    'idea-390-343.png',
  ]) {
    const path = `${directory}/${name}`
    assert.equal(
      git(['hash-object', '--', path]).toString().trim(),
      git(['rev-parse', `${plan.previousCheckpoint}:${path}`])
        .toString()
        .trim(),
      `первый checkpoint изменён ${name}`
    )
  }
}
const result = {
  status: 'pass',
  base: plan.base,
  ideas: state.ideas.length,
  assessments: ratings.ideas.length,
  plans: catalog.plans.length,
  epics: catalog.epics.length,
  tasks: catalog.tasks.length,
  previousTasksPreserved: oldCatalog.tasks.length,
  newTasks,
  dialogueNodes: nodes,
  answers,
  futureScenarios: scenarios,
  preservedFiles,
  historicalFiles,
  gameplayImplemented: false,
  audienceTested: false,
}
if (process.argv.includes('--write'))
  await writeFile(
    join(projectRoot, directory, 'preservation.json'),
    `${JSON.stringify(result, null, 2)}\n`
  )
console.log(JSON.stringify(result))
