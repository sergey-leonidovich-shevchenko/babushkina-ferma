import test from 'node:test'
import assert from 'node:assert/strict'
import { readPlanningCatalog } from '../scripts/planning-catalog.mjs'
import { createWikiServer, listen } from '../scripts/server.mjs'
import {
  firstLocationGroups,
  firstLocationOverview,
  firstLocationTasks,
} from '../src/lib/first-location.ts'

const catalog = await readPlanningCatalog()

// Сценарий: обзор дублирует выбранные эпики без переноса их владельцев и статусов.
// Исходное состояние: действующий общий каталог, включая WATER и VIS.
// Ожидаемый результат: все 22 ссылки разрешаются в исходные эпики и исходные задачи остаются прежними.
test('first location resolves all selected epics without changing the catalog', () => {
  const before = JSON.stringify(catalog)
  const view = firstLocationOverview(catalog)
  const rows = view.groups.flatMap((group) => group.epics)
  assert.equal(firstLocationGroups.length, 5)
  assert.equal(rows.length, 22)
  assert.equal(new Set(rows.map((row) => row.key)).size, 22)
  assert.ok(rows.every((row) => row.epic && row.total > 0))
  assert.ok(rows.some((row) => row.key === 'water--WATER'))
  assert.equal(JSON.stringify(catalog), before)
})

// Сценарий: завершение других карт не увеличивает прогресс первой локации.
// Исходное состояние: все VMAP/VRELEASE помечены завершёнными, а нужные первой карте открыты.
// Ожидаемый результат: счётчики ограничены 3 и 5 карточками, приёмка остаётся открытой.
test('map and release progress exclude other locations and later releases', () => {
  const data = structuredClone(catalog)
  for (const task of data.tasks) {
    if (task.epic === 'visual--VMAP' || task.epic === 'visual--VRELEASE') task.status = 'done'
    if (
      [
        'VMAP-001',
        'VMAP-002',
        'VMAP-003',
        'VRELEASE-001',
        'VRELEASE-002',
        'VRELEASE-003',
        'VRELEASE-004',
        'VRELEASE-005',
      ].includes(task.id)
    )
      task.status = 'backlog'
  }
  const view = firstLocationOverview(data)
  const rows = view.groups.flatMap((group) => group.epics)
  assert.deepEqual(
    [
      rows.find((row) => row.key === 'visual--VMAP').total,
      rows.find((row) => row.key === 'visual--VMAP').counts.done,
    ],
    [3, 0]
  )
  assert.deepEqual(
    [
      rows.find((row) => row.key === 'visual--VRELEASE').total,
      rows.find((row) => row.key === 'visual--VRELEASE').counts.done,
    ],
    [5, 0]
  )
  assert.equal(view.accepted, false)
  assert.equal(
    firstLocationTasks('visual--VMAP', data.tasks).some((task) => task.id === 'VMAP-004'),
    false
  )
})

// Сценарий: обновление источника меняет активную карточку и счётчики.
// Исходное состояние: изолированный каталог без активных задач, затем VGROUND-001 последовательно в работе и завершена.
// Ожидаемый результат: обзор показывает всю фактическую работу с контекстом, но чужая карта не меняет счётчик первой.
test('live changes update active cards and per-epic counts', () => {
  const data = structuredClone(catalog)
  for (const task of data.tasks) task.status = 'backlog'
  const task = data.tasks.find((task) => task.key === 'visual--VGROUND-001')
  task.status = 'in_progress'
  data.tasks.find((task) => task.key === 'visual--VMAP-004').status = 'in_progress'
  let view = firstLocationOverview(data)
  assert.deepEqual(
    view.active.map((task) => task.key),
    [task.key, 'visual--VMAP-004']
  )
  assert.equal(
    view.groups.flatMap((group) => group.epics).find((row) => row.key === task.epic).counts
      .in_progress,
    1
  )
  task.status = 'done'
  view = firstLocationOverview(data)
  assert.deepEqual(
    view.active.map((task) => task.key),
    ['visual--VMAP-004']
  )
  assert.match(view.active[0].context, /Другое направление/)
  assert.equal(
    view.groups.flatMap((group) => group.epics).find((row) => row.key === task.epic).counts.done,
    1
  )
})

// Реальный технический статус виден без добавления REFACTOR в22 графических эпика.
test('current technical work is visible without accepting or inflating the map', () => {
  const data = structuredClone(catalog)
  for (const task of data.tasks) if (task.status === 'in_progress') task.status = 'backlog'
  const task = data.tasks.find((task) => task.key === 'refactoring--REFACTOR-01')
  task.status = 'in_progress'
  const view = firstLocationOverview(data)
  assert.deepEqual(
    view.active.map((task) => task.key),
    [task.key]
  )
  assert.match(view.active[0].context, /Технический приоритет.*tools/)
  assert.equal(view.groups.flatMap((group) => group.epics).length, 22)
  assert.equal(view.accepted, false)
  assert.equal(
    view.history.some((entry) => entry.key === task.key),
    false
  )
  task.status = 'ready'
  assert.equal(firstLocationOverview(data).active.length, 0)
})

// ID не являются хронологией; одинаковые и отсутствующие даты сохраняют порядок источника.
test('history uses canonical done, stable dates, and bounded route/support scopes', () => {
  const sample = catalog.tasks.find((task) => task.key === 'visual--VGROUND-001')
  const row = (id, date, status = 'done', extra = {}) => ({
    ...sample,
    id,
    key: id,
    status,
    completion: { date, basis: 'fixture', evidence: [] },
    ...extra,
  })
  const tasks = [
    row('VGROUND-999', null),
    row('VGROUND-003', '2026-10-19'),
    row('VGROUND-001', '2026-10-20'),
    row('VGROUND-002', '2026-10-20'),
    row('VGROUND-998', null),
    row('VGROUND-005', '2099-01-01', 'in_progress'),
    row('VMAP-004', '2099-01-02', 'done', { epic: 'visual--VMAP' }),
    row('REFACTOR-00', '2026-10-21', 'done', {
      plan: 'refactoring',
      epic: 'refactoring--REFACTOR',
    }),
    row('WIKI-001', '2026-10-18', 'done', { plan: 'wiki', epic: 'wiki--WIKI' }),
    row('IDEA-REVIEW-20261026', '2099-01-03', 'done', { plan: 'wiki', epic: 'wiki--WIKI' }),
  ]
  const data = { ...catalog, tasks }
  const before = JSON.stringify(data)
  let view = firstLocationOverview(data)
  assert.deepEqual(
    view.history.map((task) => task.id),
    [
      'REFACTOR-00',
      'VGROUND-001',
      'VGROUND-002',
      'VGROUND-003',
      'WIKI-001',
      'VGROUND-999',
      'VGROUND-998',
    ]
  )
  assert.equal(JSON.stringify(data), before)
  tasks[5].status = 'done'
  view = firstLocationOverview(data)
  assert.equal(view.active.length, 0)
  assert.equal(view.history[0].id, 'VGROUND-005')
})

// Сценарий: подготовка и статичный показ не означают приёмку всей карты.
// Исходное состояние: пилот завершён, VMAP-003 отсутствует либо открыт, рядом есть одноимённая чужая задача.
// Ожидаемый результат: принято только явное done настоящей visual--VMAP-003, потерянные данные остаются видимыми.
test('only the canonical final acceptance completes the first location', () => {
  const data = structuredClone(catalog)
  for (const task of data.tasks) task.status = task.id.startsWith('VRELEASE-') ? 'done' : 'backlog'
  assert.equal(firstLocationOverview(data).accepted, false)
  const gate = data.tasks.find((task) => task.key === 'visual--VMAP-003')
  data.tasks.push({ ...gate, plan: 'other', key: 'other--VMAP-003', status: 'done' })
  assert.equal(firstLocationOverview(data).accepted, false)
  gate.status = 'done'
  assert.equal(firstLocationOverview(data).accepted, true)
  data.tasks = data.tasks.filter((task) => task.key !== gate.key)
  const view = firstLocationOverview(data)
  assert.equal(view.accepted, false)
  assert.equal(view.milestones.find((gate) => gate.id === 'VMAP-003').task, undefined)
})

// Сценарий: полный каталог и отсутствие источника нельзя принять за объём первой карты.
// Исходное состояние: действующий каталог, затем удалён один эпик обзора.
// Ожидаемый результат: производственные эпики явно подписаны, потерянная ссылка не замещается другой карточкой.
test('catalog-wide scopes and missing epic data remain explicit', () => {
  let rows = firstLocationOverview(catalog).groups.flatMap((group) => group.epics)
  for (const id of ['VBUILD', 'VACTOR', 'VPLANT'])
    assert.match(rows.find((row) => row.key === `visual--${id}`).scope, /Весь каталог.*VMAP-001/)
  const data = { ...catalog, epics: catalog.epics.filter((epic) => epic.key !== 'visual--VGROUND') }
  rows = firstLocationOverview(data).groups.flatMap((group) => group.epics)
  assert.equal(rows.find((row) => row.key === 'visual--VGROUND').epic, undefined)
})

// Настоящий API повторно загружает один каталог: active/history меняются вместе, без старого done в истории.
test('API refresh keeps active work and completion history coherent', async (t) => {
  const data = structuredClone(catalog)
  const task = data.tasks.find((task) => task.key === 'visual--VGROUND-001')
  const server = createWikiServer(process.cwd(), {
    planning: {
      loadCatalog: async () => structuredClone(data),
      store: { read: async () => ({ schema: 1, revision: 0, ideas: [] }) },
    },
  })
  const port = await listen(server, 0)
  t.after(() => {
    server.closeAllConnections()
    server.close()
  })
  const refresh = async () => {
    const response = await fetch(`http://127.0.0.1:${port}/__wiki/planning`)
    assert.equal(response.status, 200)
    assert.equal(response.headers.get('cache-control'), 'no-store')
    return firstLocationOverview((await response.json()).catalog)
  }
  task.status = 'in_progress'
  let view = await refresh()
  assert.ok(view.active.some((row) => row.key === task.key))
  assert.equal(
    view.history.some((row) => row.key === task.key),
    false
  )
  task.status = 'done'
  task.completion = { date: '2026-10-26', basis: 'fixture', evidence: [] }
  view = await refresh()
  assert.equal(
    view.active.some((row) => row.key === task.key),
    false
  )
  assert.equal(view.history[0].key, task.key)
  for (const row of data.tasks) if (row.status === 'in_progress') row.status = 'backlog'
  assert.equal((await refresh()).active.length, 0)
})
