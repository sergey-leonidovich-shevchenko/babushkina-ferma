import test from 'node:test'
import assert from 'node:assert/strict'
import { readFile } from 'node:fs/promises'
import {
  assessmentValue,
  assessmentFor,
  validateAssessments,
  compareAssessmentIdeas,
  legacyDevelopmentPath,
} from '../src/lib/idea-assessment.ts'
import { readPlanningCatalog } from '../scripts/planning-catalog.mjs'
import { developmentLink } from '../scripts/rollout-queues.mjs'

const load = async (name) =>
  JSON.parse(await readFile(new URL(`../planning/${name}`, import.meta.url), 'utf8'))
const scores = await load('assessments.json')
const migration = await load('idea-migration-2026-10-22.json')
const links = await load('legacy-development-links.json')
const catalog = await readPlanningCatalog()

// Сценарий: статья ведёт в свой настоящий эпик, а не в произвольный путь приложения.
test('editorial epic links accept registered owners and reject unknown targets', () => {
  for (const feature of migration.features) {
    const href = `#/development/epics/${feature.epic}`
    assert.equal(developmentLink(href, catalog, []), href)
  }
  assert.equal(developmentLink('#/development/ideas', catalog, []), '#/development/ideas')
  for (const href of [
    '#/development/epics/unknown--IDEA-155',
    '#/development/epics/idea-155--IDEA-155?file=state.json',
    '#/development/epics/idea-155--IDEA-155#extra',
    '#/development/ideas/unknown',
  ])
    assert.throws(() => developmentLink(href, catalog, []))
})

// Сценарий: дата обзора больше не смешивает самостоятельные механики.
// Исходное состояние: четыре старых контейнера и сорок постоянных ID идей.
// Ожидаемый результат: один собственный эпик/источник каждой идеи, старые контейнеры отсутствуют.
test('every migrated idea owns its own thematic epic and source', () => {
  assert.equal(migration.features.length, 40)
  assert.ok(migration.retiredEpics.every((key) => !catalog.epics.some((epic) => epic.key === key)))
  for (const feature of migration.features) {
    const epic = catalog.epics.find((item) => item.key === feature.epic)
    assert.ok(epic, feature.idea)
    assert.equal(epic.id, feature.idea)
    assert.equal(epic.group, feature.group)
    assert.ok(epic.goal.trim().length > 20)
    assert.equal(catalog.epics.filter((item) => item.plan === feature.plan).length, 1)
    const tasks = catalog.tasks.filter((item) => item.epic === epic.key)
    assert.ok(tasks.length >= 3)
    assert.ok(tasks.every((item) => item.id.startsWith(`${feature.idea}-`)))
  }
})

// Сценарий: задачи перенесены, а не созданы заново с потерей истории.
// Статусы могут законно меняться после миграции, поэтому тест не замораживает backlog навсегда.
test('all 123 preserved task IDs still have one owner and a working legacy target', () => {
  assert.equal(migration.preservedTasks.length, 123)
  for (const row of migration.preservedTasks) {
    const found = catalog.tasks.filter((task) => task.id === row.id)
    assert.equal(found.length, 1, row.id)
    assert.equal(found[0].key, row.newKey)
    assert.equal(
      legacyDevelopmentPath(`/development/tasks/${row.oldKey}`, links),
      `/development/tasks/${row.newKey}`
    )
  }
})

// Сценарий: читатель переходит из статьи в предметные задачи, а не в общий список дня.
test('canonical articles link to their own epic and every own task', async () => {
  for (const feature of migration.features) {
    const text = await readFile(
      new URL(`../articles/${feature.article}.md`, import.meta.url),
      'utf8'
    )
    assert.ok(text.includes(`#/development/epics/${feature.epic}`), feature.idea)
    for (const task of catalog.tasks.filter((item) => item.epic === feature.epic))
      assert.ok(text.includes(`#/development/tasks/${task.key}`), task.key)
    assert.ok(text.includes('Модель и единственный владелец'))
    assert.ok(text.includes('Сквозной пример'))
  }
})

// Сценарий: все старые ссылки зарегистрированы точно и не становятся открытым редиректом.
test('legacy redirects resolve once and reject unknown or external destinations', () => {
  const taskPaths = new Set(catalog.tasks.map((task) => `/development/tasks/${task.key}`))
  for (const [old, target] of Object.entries(links)) {
    assert.equal(legacyDevelopmentPath(old, links), target)
    assert.ok(taskPaths.has(target) || target === '/guides/idea-feature-epics')
    assert.equal(links[target], undefined)
  }
  assert.equal(legacyDevelopmentPath('/development/tasks/unknown--IDEA-155-01', links), undefined)
  assert.equal(legacyDevelopmentPath('/old', { '/old': 'https://example.com' }), undefined)
  assert.equal(legacyDevelopmentPath('/old', { '/old': '//example.com' }), undefined)
  assert.equal(legacyDevelopmentPath('toString', links), undefined)
})

// Сценарий: оценка отделяет интерес от пользы и инженерного риска.
test('assessment scales have valid evidence, distinct costs and reproducible value', () => {
  assert.equal(validateAssessments(scores), scores)
  for (const feature of migration.features) {
    const row = assessmentFor(scores, feature.idea)
    assert.ok(row)
    assert.equal(row.value, assessmentValue(row))
    assert.ok(row.prototype && row.audience && row.rationale)
  }
  const cards = assessmentFor(scores, 'IDEA-196')
  const savings = assessmentFor(scores, 'IDEA-195')
  assert.ok(cards.interest > savings.interest)
  assert.ok(cards.cost > savings.cost)
  assert.ok(savings.usefulness > cards.usefulness)
})

// Сценарий: нет источника или данных — не значит «редко» и не значит «бесполезно».
test('missing assessments and unverified analogues stay explicitly unknown', () => {
  assert.equal(assessmentFor(scores, 'IDEA-001'), undefined)
  const row = assessmentFor(scores, 'IDEA-192')
  assert.equal(row.familiarity, null)
  assert.equal(row.source, null)
  assert.ok(row.analogue.includes('не проверен'))
})

// Сценарий: ошибки авторского файла явно отклоняются до сборки.
test('invalid ranges, fabricated familiarity and duplicate IDs are rejected', () => {
  for (const value of [0, 6, NaN, Infinity, 2.5]) {
    const data = structuredClone(scores)
    data.ideas[0].interest = value
    assert.throws(() => validateAssessments(data))
  }
  const wrongValue = structuredClone(scores)
  wrongValue.ideas[0].value += 1
  assert.throws(() => validateAssessments(wrongValue))
  const noSource = structuredClone(scores)
  noSource.ideas[0].familiarity = 5
  assert.throws(() => validateAssessments(noSource))
  const unknown = structuredClone(scores)
  unknown.ideas[0].source = 'missing-source'
  assert.throws(() => validateAssessments(unknown))
  const duplicate = structuredClone(scores)
  duplicate.ideas.push(duplicate.ideas[0])
  assert.throws(() => validateAssessments(duplicate))
})

// Сценарий: сортировка помогает обсуждению и не переписывает решения.
test('assessment sorting keeps unassessed ideas last and never mutates records', () => {
  const before = JSON.stringify(scores)
  const rows = [{ id: 'IDEA-001' }, { id: 'IDEA-196' }, { id: 'IDEA-195' }]
  const interest = rows.slice().sort((a, b) => compareAssessmentIdeas(a, b, 'interest', scores))
  assert.deepEqual(
    interest.map((x) => x.id),
    ['IDEA-196', 'IDEA-195', 'IDEA-001']
  )
  const cheap = rows.slice().sort((a, b) => compareAssessmentIdeas(a, b, 'cost', scores))
  assert.deepEqual(
    cheap.map((x) => x.id),
    ['IDEA-195', 'IDEA-196', 'IDEA-001']
  )
  assert.equal(JSON.stringify(scores), before)
  assert.equal(rows[0].id, 'IDEA-001')
})
