import assert from 'node:assert/strict'
import { execFileSync } from 'node:child_process'
import { readFile, writeFile, mkdtemp, rm } from 'node:fs/promises'
import { tmpdir } from 'node:os'
import { join } from 'node:path'
import MarkdownIt from 'markdown-it'
import { projectRoot } from './runtime.mjs'
import { readPlanningCatalog } from './planning-catalog.mjs'

const directory = 'docs/reports/creative/2026-10-25-pr8-integration-1'
const markdown = new MarkdownIt()

async function json(path) {
  return JSON.parse(await readFile(join(projectRoot, path), 'utf8'))
}

function git(args, options = {}) {
  return execFileSync('git', args, {
    cwd: projectRoot,
    maxBuffer: 32 * 1024 * 1024,
    ...options,
  })
}

function parentJson(ref, path) {
  return JSON.parse(git(['show', `${ref}:${path}`]).toString())
}

function preservedRows(before, after, key, label) {
  const map = new Map(after.map((row) => [row[key], row]))
  assert.equal(map.size, after.length, `${label}: повтор ID`)
  for (const row of before) assert.deepEqual(map.get(row[key]), row, `${label}: ${row[key]}`)
}

function graph(tasks) {
  const map = new Map(tasks.map((task) => [task.id, task]))
  assert.equal(map.size, tasks.length)
  const active = new Set()
  const visited = new Set()
  function visit(id) {
    assert(map.has(id), `неизвестная зависимость ${id}`)
    assert(!active.has(id), `цикл ${id}`)
    if (visited.has(id)) return
    active.add(id)
    for (const dependency of map.get(id).dependencies) visit(dependency)
    active.delete(id)
    visited.add(id)
  }
  for (const id of map.keys()) visit(id)
}

function tableText(source) {
  let depth = 0
  const rows = []
  for (const token of markdown.parse(source, {})) {
    if (token.type === 'table_open') depth += 1
    else if (token.type === 'table_close') depth -= 1
    else if (depth && token.type === 'inline') rows.push(token.content)
  }
  return rows.join('\n')
}

// Фиксируем blob-ID всех исторических отчётов обоих родителей. Проверка index
// дополняется diff по диску, чтобы unstaged-подмена не прошла как сохранность.
function reportTree(ref) {
  const paths = ['docs/reports', 'wiki/reports', 'wiki/articles']
  const tree = git(['ls-tree', '-rz', ref, '--', ...paths]).toString()
  const result = new Map()
  for (const entry of tree.split('\0').filter(Boolean)) {
    const [header, path] = entry.split('\t')
    if (
      path.startsWith('docs/reports/') ||
      path.startsWith('wiki/reports/') ||
      /^wiki\/articles\/creative-review-.*\.md$/.test(path)
    ) result.set(path, header.split(' ')[2])
  }
  return result
}

function checkHistoricalReports(plan) {
  const expected = reportTree(plan.acceptedMain)
  for (const [path, blob] of reportTree(plan.previousHead)) {
    if (expected.has(path)) assert.equal(expected.get(path), blob, `разные исторические родители: ${path}`)
    expected.set(path, blob)
  }
  const index = new Map()
  for (const entry of git(['ls-files', '-s', '-z', '--', 'docs/reports', 'wiki/reports', 'wiki/articles']).toString().split('\0').filter(Boolean)) {
    const [header, path] = entry.split('\t')
    index.set(path, header.split(' ')[1])
  }
  for (const [path, blob] of expected) assert.equal(index.get(path), blob, `изменён исторический отчёт: ${path}`)
  const changed = git(['diff', '--name-only', '-z', '--', 'docs/reports', 'wiki/reports', 'wiki/articles/creative-review-*.md']).toString().split('\0').filter(Boolean)
  assert(!changed.some((path) => expected.has(path)), 'исторический отчёт изменён вне index')
  return expected.size
}

// Временный снимок содержит только источники планов, без игровых ресурсов и
// чужого checkout. Параметры root/manifest исключают чтение текущего каталога.
async function acceptedCatalog(plan) {
  const root = await mkdtemp(join(tmpdir(), 'creative-pr8-main-'))
  try {
    const sources = parentJson(plan.acceptedMain, 'wiki/planning/sources.json')
    const paths = ['docs/backlog', 'docs/epics', 'wiki/planning', 'wiki/articles', ...(sources.queues ?? []).map((queue) => queue.file)]
    const archive = git(['archive', plan.acceptedMain, ...paths])
    execFileSync('tar', ['-x', '-C', root], { input: archive })
    return await readPlanningCatalog({ root, manifest: join(root, 'wiki/planning/sources.json') })
  } finally {
    await rm(root, { recursive: true, force: true })
  }
}

async function main() {
  const plan = await json(`${directory}/plan.json`)
  const state = await json('wiki/planning/state.json')
  const assessments = await json('wiki/planning/assessments.json')
  const sources = await json('wiki/planning/sources.json')
  const index = await json('wiki/articles/index.json')
  for (const ref of [plan.acceptedMain, plan.previousHead]) {
    const oldState = parentJson(ref, 'wiki/planning/state.json')
    preservedRows(oldState.ideas, state.ideas, 'id', 'идеи/решения/история')
    preservedRows(oldState.groups, state.groups, 'id', 'группы')
    for (const [key, value] of Object.entries(oldState.epicGroups)) assert.deepEqual(state.epicGroups[key], value)
    const oldRatings = parentJson(ref, 'wiki/planning/assessments.json')
    preservedRows(oldRatings.ideas, assessments.ideas, 'idea', 'оценки')
    for (const [key, value] of Object.entries(oldRatings.sources)) assert.deepEqual(assessments.sources[key], value)
    const oldSources = parentJson(ref, 'wiki/planning/sources.json')
    for (const previous of oldSources.plans) {
      const expected = structuredClone(previous)
      if (expected.id === 'wiki') expected.expected = plan.expected.wikiEditorialCards
      assert.deepEqual(sources.plans.find((row) => row.id === expected.id), expected)
    }
    assert.deepEqual(sources.queues, oldSources.queues)
    preservedRows(parentJson(ref, 'wiki/articles/index.json'), index, 'id', 'индекс статей')
  }
  assert.equal(state.revision, parentJson(plan.acceptedMain, 'wiki/planning/state.json').revision + 1)
  assert.equal(state.ideas.length, plan.expected.ideas)
  assert.equal(assessments.ideas.length, plan.expected.assessments)
  assert.equal(sources.plans.length, plan.expected.registeredPlans)
  const current = await readPlanningCatalog()
  graph(current.tasks)
  const accepted = await acceptedCatalog(plan)
  const tasks = new Map(current.tasks.map((row) => [row.id, row]))
  // content допускает добавленный соседний anchor в WIKI; смысловые поля всех
  // принятых карточек, включая их статусы/проверки/результаты, остаются прежними.
  for (const task of accepted.tasks) {
    const actual = tasks.get(task.id)
    assert(actual, `потеряна принятая ${task.id}`)
    for (const [key, value] of Object.entries(task)) {
      if (key !== 'content') assert.deepEqual(actual[key], value, `принятая ${task.id}.${key}`)
    }
  }
  assert.equal(tasks.get('VFOLIAGE-010').status, 'done')
  assert.equal(tasks.get('REFACTOR-00').status, 'done')
  assert.equal(tasks.get('REFACTOR-01').status, 'ready')
  assert.equal(tasks.get('IDEA-REVIEW-20261025').status, 'in_progress')
  assert(tasks.get('IDEA-REVIEW-20261025').result.includes('/pull/8'))
  const tables = await Promise.all(['wiki/articles/idea-feature-epics.md', 'docs/epics/ideas/README.md'].map(async (path) => tableText(await readFile(join(projectRoot, path), 'utf8'))))
  const snapshots = [
    parentJson(plan.acceptedMain, 'docs/reports/creative/2026-10-24/plan.json'),
    parentJson(plan.previousHead, 'docs/reports/creative/2026-10-25/plan.json'),
  ]
  let futureTasks = 0
  let dialogueNodes = 0
  let answers = 0
  for (const snapshot of snapshots) {
    for (const idea of snapshot.ideas) {
      const own = current.tasks.filter((task) => task.epic === `${idea.id.toLowerCase()}--${idea.id}`)
      assert.equal(own.length, idea.taskCount)
      assert(own.every((task) => task.status === 'backlog'))
      assert.equal(own[0].dependencies.length, 0)
      for (const task of own) {
        if (task.content.includes('теперь указана формальным блокером')) assert(task.dependencies.includes('IDEA-232-04'))
      }
      const source = await readFile(join(projectRoot, `wiki/articles/${idea.id}.md`), 'utf8')
      const nodes = [...source.matchAll(new RegExp(`^### ${idea.id}-[a-z]+ — `, 'gm'))]
      const replies = [...source.matchAll(/^\d+\. \*\*Герой:\*\*/gm)]
      assert.equal(nodes.length, idea.dialogueNodes)
      assert.equal(replies.length, idea.answerCount ?? idea.dialogueNodes * 3)
      // Снимок24 хранит счётчики, снимок25 — ещё и полные реплики.
      // Старый формат проверяем сильнее: вся статья равна принятому blob.
      if (!Array.isArray(idea.dialogue)) {
        assert.equal(source, git(['show', `${plan.acceptedMain}:wiki/articles/${idea.id}.md`]).toString())
      }
      for (const node of idea.dialogue ?? []) {
        assert(source.includes(node.condition))
        assert(source.includes(node.line))
        for (const answer of node.answers) for (const part of answer) assert(source.includes(part))
      }
      for (const table of tables) assert(table.includes(idea.id), `строка вне таблицы ${idea.id}`)
      const rating = assessments.ideas.find((row) => row.idea === idea.id)
      assert.equal(rating.value, 6 * rating.usefulness + 6 * rating.interest + 5 * rating.fit + 3 * rating.synergy)
      futureTasks += own.length
      dialogueNodes += nodes.length
      answers += replies.length
    }
  }
  assert.equal(futureTasks, 86)
  assert.equal(dialogueNodes, 63)
  assert.equal(answers, 190)
  for (const key of ['scripts', 'assets', 'tests', 'tools', '.githooks', 'main.tscn']) {
    assert.equal(git(['diff', '--name-only', plan.acceptedMain, '--', key]).toString(), '', `принятый код изменён: ${key}`)
  }
  const priority = await readFile(join(projectRoot, 'AGENTS.md'), 'utf8')
  assert(priority.includes('REFACTOR-01') && priority.includes('перед этой технической очередью'))
  const historicalReportFiles = checkHistoricalReports(plan)
  const result = {
    checkedAt: new Date().toISOString(),
    status: 'pass',
    parents: { acceptedMain: plan.acceptedMain, previousHead: plan.previousHead },
    ideas: state.ideas.length,
    assessments: assessments.ideas.length,
    futureTasks,
    dialogueNodes,
    answers,
    historicalReportFiles,
    catalog: { plans: current.plans.length, epics: current.epics.length, tasks: current.tasks.length },
    priority: ['REFACTOR-01', 'REFACTOR-02', 'REFACTOR-03', 'REFACTOR-06'],
    taskStatuses: { 'VFOLIAGE-010': 'done', 'REFACTOR-00': 'done', 'REFACTOR-01': 'ready', 'IDEA-REVIEW-20261025': 'in_progress' },
    scope: 'Интеграционная сохранность. Игровые механики предложений и интерес аудитории не проверены.',
  }
  assert.deepEqual(result.catalog, { plans: plan.expected.catalogPlans, epics: plan.expected.catalogEpics, tasks: plan.expected.catalogTasks })
  if (process.argv.includes('--write')) await writeFile(join(projectRoot, directory, 'preservation.json'), `${JSON.stringify(result, null, 2)}\n`)
  process.stdout.write(`${JSON.stringify(result, null, 2)}\n`)
}

await main()
