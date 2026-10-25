import assert from 'node:assert/strict'
import { execFileSync } from 'node:child_process'
import { readFile, writeFile } from 'node:fs/promises'
import { join } from 'node:path'
import MarkdownIt from 'markdown-it'
import { projectRoot } from './runtime.mjs'
import { readPlanningCatalog } from './planning-catalog.mjs'

const reportDirectory = join(projectRoot, 'docs/reports/creative/2026-10-24')
const markdown = new MarkdownIt()

async function readJson(relativePath) {
  return JSON.parse(await readFile(join(projectRoot, relativePath), 'utf8'))
}

// База — main при начале обзора. Сравнение с HEAD потеряло бы старые решения
// после первого же коммита; закреплённый SHA сохраняет смысл этой проверки.
function baselineJson(base, relativePath) {
  return JSON.parse(
    execFileSync('git', ['show', `${base}:${relativePath}`], {
      cwd: projectRoot,
      encoding: 'utf8',
      maxBuffer: 16 * 1024 * 1024,
    })
  )
}

function assertPreservedRows(before, after, key, label) {
  const indexed = new Map(after.map((row) => [row[key], row]))
  assert.equal(indexed.size, after.length, `${label}: повторный ID`)
  for (const previous of before) {
    assert.deepEqual(indexed.get(previous[key]), previous, `${label}: ${previous[key]}`)
  }
}

async function checkPreservedDecisions(plan) {
  const state = await readJson('wiki/planning/state.json')
  const before = baselineJson(plan.base, 'wiki/planning/state.json')
  assertPreservedRows(before.ideas, state.ideas, 'id', 'старые идеи/история')
  assert.deepEqual(state.groups, before.groups, 'редакционные группы')
  assert.deepEqual(state.epicGroups, before.epicGroups, 'чужие переназначения')
  assert.equal(state.revision, before.revision + 1)
  assert.equal(state.ideas.length, before.ideas.length + plan.ideas.length)

  const assessments = await readJson('wiki/planning/assessments.json')
  const oldAssessments = baselineJson(plan.base, 'wiki/planning/assessments.json')
  assertPreservedRows(oldAssessments.ideas, assessments.ideas, 'idea', 'старые оценки')
  for (const [key, value] of Object.entries(oldAssessments.sources)) {
    assert.deepEqual(assessments.sources[key], value, `источник ${key}`)
  }

  const sources = await readJson('wiki/planning/sources.json')
  const oldSources = baselineJson(plan.base, 'wiki/planning/sources.json')
  for (const previous of oldSources.plans) {
    const expected = structuredClone(previous)
    if (expected.id === 'wiki') expected.expected += 1 // Только новая редакционная карточка.
    assert.deepEqual(
      sources.plans.find((row) => row.id === previous.id),
      expected
    )
  }
  assert.deepEqual(sources.queues, oldSources.queues)
  return {
    state,
    assessments,
    preservedIdeas: before.ideas.length,
    preservedAssessments: oldAssessments.ideas.length,
  }
}

function checkDependencyGraph(tasks) {
  const byId = new Map(tasks.map((task) => [task.id, task]))
  assert.equal(byId.size, tasks.length, 'повторные игровые ID')
  const visiting = new Set()
  const visited = new Set()
  function visit(id) {
    assert(byId.has(id), `неизвестный блокер ${id}`)
    assert(!visiting.has(id), `цикл зависимостей ${id}`)
    if (visited.has(id)) return
    visiting.add(id)
    for (const dependency of byId.get(id).dependencies) visit(dependency)
    visiting.delete(id)
    visited.add(id)
  }
  for (const id of byId.keys()) visit(id)
}

// Проверяем именно table tokens движка Wiki: обычный поиск строки пропустил бы
// ошибку, когда строка с | находится после абзаца и уже не является таблицей.
function tableText(source) {
  let tableDepth = 0
  const rows = []
  for (const token of markdown.parse(source, {})) {
    if (token.type === 'table_open') tableDepth += 1
    else if (token.type === 'table_close') tableDepth -= 1
    else if (tableDepth > 0 && token.type === 'inline') rows.push(token.content)
  }
  return rows.join('\n')
}

async function checkNewStories(plan, preserved, catalog) {
  const index = await readJson('wiki/articles/index.json')
  const previousIndex = baselineJson(plan.base, 'wiki/articles/index.json')
  // Указатель уже изменён этой подборкой; его старое резюме «пятьдесят»
  // заменено без числа. Адрес, заголовок, файл и метки сохранены.
  const expectedIndex = previousIndex.map((row) =>
    row.id === 'idea-feature-epics'
      ? {
          ...row,
          summary:
            'Каталог самостоятельных тематических эпиков с подробными контрактами, предметными задачами и раздельными оценками.',
        }
      : row
  )
  assertPreservedRows(expectedIndex, index, 'id', 'статьи Wiki')
  let dialogueNodes = 0
  let playerAnswers = 0
  const sections = [
    'Суть и польза игроку',
    'Основа проекта, зависимости и отличие',
    'Сценарий от знакомства до последствия',
    'Правила и состояния',
    'Написанные разговоры и ответы',
    'Интерфейс, обучение, графика и звук',
    'Минимальный выпуск и предметные этапы',
    'Риски и способы проверки',
    'Наблюдаемая приёмка — шесть сценариев',
    'Оценка, референс и очередность',
  ]
  const tableSources = await Promise.all(
    ['wiki/articles/idea-feature-epics.md', 'docs/epics/ideas/README.md'].map(async (path) =>
      tableText(await readFile(join(projectRoot, path), 'utf8'))
    )
  )

  for (const idea of plan.ideas) {
    assert(!plan.reservedPR.ideas.includes(idea.id), `занят номер ${idea.id}`)
    const record = preserved.state.ideas.find((row) => row.id === idea.id)
    assert.equal(record.status, 'proposed')
    assert.equal(record.group, idea.group)
    assert.deepEqual(record.linkedEpics, [`${idea.id.toLowerCase()}--${idea.id}`])
    const epic = catalog.epics.find((row) => row.key === record.linkedEpics[0])
    assert(epic, `не подключён эпик ${idea.id}`)
    const tasks = catalog.tasks.filter((row) => row.epic === epic.key)
    assert.equal(tasks.length, idea.taskCount)
    assert(tasks.every((row) => row.status === 'backlog'))
    assert(tasks.every((row) => row.goal && row.acceptance.length >= 2))
    for (const task of tasks) {
      const branch = task.content.match(/^\*\*Ветка:\*\* (codex\/[^\n]+)$/m)?.[1]
      assert(branch, `нет явной ветки ${task.id}`)
      execFileSync('git', ['check-ref-format', '--branch', branch], {
        cwd: projectRoot,
        stdio: 'pipe',
      })
    }
    assert.equal(tasks[0].dependencies.length, 0, 'бумажная стадия самостоятельна')

    const source = await readFile(join(projectRoot, `wiki/articles/${idea.id}.md`), 'utf8')
    for (const section of sections) assert(source.includes(`## ${section}\n`))
    const nodes = [...source.matchAll(new RegExp(`^### ${idea.id}-[a-z]+ — `, 'gm'))]
    assert.equal(nodes.length, idea.dialogueNodes)
    const answers = [...source.matchAll(/^\d+\. \*\*Герой:\*\*/gm)]
    assert.equal(answers.length, idea.dialogueNodes * 3)
    const scenarios = source
      .split('## Наблюдаемая приёмка — шесть сценариев\n')[1]
      .split('\n## ')[0]
    assert.equal([...scenarios.matchAll(/^\d+\. /gm)].length, 6)
    assert(source.includes('пока') || source.includes('не реализованы'))
    dialogueNodes += nodes.length
    playerAnswers += answers.length

    const rating = preserved.assessments.ideas.find((row) => row.idea === idea.id)
    const actualScores = ['usefulness', 'interest', 'fit', 'synergy', 'cost', 'risk'].map(
      (key) => rating[key]
    )
    assert.deepEqual(actualScores, idea.scores)
    const [usefulness, interest, fit, synergy] = actualScores
    assert.equal(rating.value, 6 * usefulness + 6 * interest + 5 * fit + 3 * synergy)
    assert.equal(rating.value, idea.value)
    assert.equal(rating.confidence, 'hypothesis')
    assert(rating.audience && rating.prototype && rating.analogue)
    const reference = preserved.assessments.sources[rating.source]
    assert(reference?.url.startsWith('https://'))
    assert(source.includes(reference.url), 'источник совпадает со статьёй')
    assert(
      source.includes(`(#/development/epics/${epic.key})`),
      'прямая ссылка на собственный эпик'
    )
    assert(
      source.includes(`[Предметные задачи](#/development/epics/${epic.key})`),
      'прямая ссылка на список карточек своего эпика'
    )
    const ratingRow = `| ${actualScores.map((score) => `${score}/5`).join(' | ')} | ${rating.value}/100 |`
    assert(source.includes(ratingRow), `баллы статьи ${idea.id}`)
    for (const table of tableSources)
      assert(table.includes(idea.id), `строка вне таблицы ${idea.id}`)
  }
  return { dialogueNodes, playerAnswers }
}

async function main() {
  const plan = await readJson('docs/reports/creative/2026-10-24/plan.json')
  assert.equal(plan.ideas.length, 10, 'десять самостоятельных идей')
  assert.equal(plan.gameplayImplemented, false)
  // Читается опубликованный head прошлого PR, а не только main с меньшим max-ID.
  const reserved = baselineJson(plan.reservedPR.head, 'wiki/planning/state.json')
  for (const id of plan.reservedPR.ideas) assert(reserved.ideas.some((row) => row.id === id))
  const preserved = await checkPreservedDecisions(plan)
  const catalog = await readPlanningCatalog()
  checkDependencyGraph(catalog.tasks)
  const content = await checkNewStories(plan, preserved, catalog)
  const editorial = catalog.tasks.find((row) => row.id === 'IDEA-REVIEW-20261024')
  assert.equal(editorial?.status, 'in_progress')
  assert.equal(editorial.dependencies.length, 0, 'редакционный обзор не ждёт будущую карту')
  assert(editorial.result.includes('ревью'))
  const result = {
    checkedAt: new Date().toISOString(),
    base: plan.base,
    status: 'pass',
    preservedIdeas: preserved.preservedIdeas,
    preservedAssessments: preserved.preservedAssessments,
    reservedFromPR2: plan.reservedPR.ideas,
    newIdeas: plan.ideas.length,
    futureTasks: plan.ideas.reduce((sum, idea) => sum + idea.taskCount, 0),
    ...content,
    futureScenarios: 60,
    plannedLocations: plan.plannedLocations,
    catalog: {
      plans: catalog.plans.length,
      epics: catalog.epics.length,
      tasks: catalog.tasks.length,
    },
    scope: 'Редакционная полнота и зависимости. Игровые сценарии и интерес аудитории не проверены.',
  }
  if (process.argv.includes('--write')) {
    await writeFile(
      join(reportDirectory, 'editorial-check.json'),
      `${JSON.stringify(result, null, 2)}\n`
    )
  }
  process.stdout.write(`${JSON.stringify(result, null, 2)}\n`)
}

await main()
