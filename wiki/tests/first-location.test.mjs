import test from 'node:test'
import assert from 'node:assert/strict'
import { readPlanningCatalog } from '../scripts/planning-catalog.mjs'
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
// Ожидаемый результат: обзор показывает новое состояние без второго реестра и не включает активную задачу другой карты.
test('live changes update active cards and per-epic counts', () => {
  const data = structuredClone(catalog)
  for (const task of data.tasks) task.status = 'backlog'
  const task = data.tasks.find((task) => task.key === 'visual--VGROUND-001')
  task.status = 'in_progress'
  data.tasks.find((task) => task.key === 'visual--VMAP-004').status = 'in_progress'
  let view = firstLocationOverview(data)
  assert.deepEqual(
    view.active.map((task) => task.key),
    [task.key]
  )
  assert.equal(
    view.groups.flatMap((group) => group.epics).find((row) => row.key === task.epic).counts
      .in_progress,
    1
  )
  task.status = 'done'
  view = firstLocationOverview(data)
  assert.equal(view.active.length, 0)
  assert.equal(
    view.groups.flatMap((group) => group.epics).find((row) => row.key === task.epic).counts.done,
    1
  )
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
