import { readFile } from 'node:fs/promises'
import { createHash } from 'node:crypto'
import { sourcePath } from './planning-catalog.mjs'

/** Проверяет очередь как представление существующих карточек, не создавая второй источник статусов. */
export function validateQueue(queue, catalog) {
  if (
    queue.schema !== 1 ||
    !/^[a-z][a-z0-9-]+$/.test(queue.id) ||
    !queue.title ||
    queue.planningOnly !== true ||
    queue.implementationAccepted !== false ||
    queue.plan !== 'visual'
  )
    throw new Error('Неверная область очереди пилота')
  const by = new Map(catalog.tasks.map((task) => [task.key, task]))
  const keys = queue.taskKeys
  if (
    !Array.isArray(keys) ||
    !keys.length ||
    keys.length > 64 ||
    new Set(keys).size !== keys.length ||
    keys.includes(queue.ownerKey) ||
    !by.has(queue.ownerKey)
  )
    throw new Error('Неверный состав очереди')
  const positions = new Map(keys.map((key, index) => [key, index]))
  if (
    !Array.isArray(queue.stages) ||
    !queue.stages.length ||
    queue.stages.some(
      (stage) =>
        !/^[a-z][a-z0-9-]+$/.test(stage.id) || !stage.title || !Array.isArray(stage.taskKeys)
    ) ||
    !queue.extraDependencies ||
    typeof queue.extraDependencies !== 'object' ||
    Array.isArray(queue.extraDependencies) ||
    Object.values(queue.extraDependencies).some(
      (deps) => !Array.isArray(deps) || deps.some((dep) => typeof dep !== 'string')
    )
  )
    throw new Error('Неверные этапы или условия очереди')
  const assigned = queue.stages.flatMap((stage) => stage.taskKeys)
  if (
    JSON.stringify(assigned) !== JSON.stringify(keys) ||
    new Set(queue.stages.map((stage) => stage.id)).size !== queue.stages.length
  )
    throw new Error('Этапы очереди расходятся с порядком задач')
  for (const key of keys) {
    const task = by.get(key)
    if (!task || task.plan !== queue.plan) throw new Error(`Неизвестная задача очереди: ${key}`)
    const deps = [
      ...task.dependencies.map((id) => `${task.plan}--${id}`),
      ...(queue.extraDependencies[key] ?? []),
    ]
    for (const dep of deps) {
      if (
        !by.has(dep) ||
        (dep !== queue.ownerKey &&
          (!positions.has(dep) || positions.get(dep) >= positions.get(key)))
      )
        throw new Error(`Потеряна зависимость или порядок очереди: ${key} → ${dep}`)
      if (task.status === 'done' && by.get(dep).status !== 'done')
        throw new Error(`Завершённая задача имеет открытый блокер: ${key}`)
    }
  }
  if (Object.keys(queue.extraDependencies).some((key) => !positions.has(key)))
    throw new Error('Условие относится к задаче вне очереди')
  const rows = keys
    .map((key) => by.get(key))
    .sort((a, b) => (a.id < b.id ? -1 : 1))
    .map((task) => [task.id, task.epic.slice(task.plan.length + 2), task.dependencies])
  const signature = createHash('sha256').update(JSON.stringify(rows)).digest('hex')
  if (signature !== queue.graphSignature)
    throw new Error('Зависимости изменились: пересоберите очередь pilot_rollout.py --write')
  return queue
}

/** Читает только зарегистрированные очереди внутри проекта и проверяет актуальный граф карточек. */
export async function readRolloutQueues(root, manifest, catalog) {
  const config = JSON.parse(await readFile(manifest, 'utf8'))
  const result = []
  for (const definition of config.queues ?? []) {
    if (result.some((queue) => queue.id === definition.id)) throw new Error('Повтор ID очереди')
    const queue = JSON.parse(await readFile(await sourcePath(root, definition.file), 'utf8'))
    if (queue.id !== definition.id) throw new Error('ID очереди не совпадает с реестром')
    result.push(validateQueue(queue, catalog))
  }
  return result
}

/** Разрешает редакционные ссылки только на существующие карточки и известные очереди Wiki. */
export function developmentLink(href, catalog, queues) {
  if (!href.startsWith('#/development/')) return undefined
  const url = new URL(href.slice(1), 'https://wiki.invalid')
  const board = url.pathname.match(/^\/development\/(epics|ideas|first-location)(?:\/([^/]+))?$/)
  if (board) {
    if (url.hash || url.search || (board[1] !== 'epics' && board[2]))
      throw new Error('Неверная внутренняя ссылка разработки')
    if (
      board[1] === 'epics' &&
      board[2] &&
      !catalog.epics.some((epic) => epic.key === decodeURIComponent(board[2]))
    )
      throw new Error('Ссылка ведёт к неизвестному эпику')
    return href
  }
  const match = url.pathname.match(/^\/development\/tasks(?:\/([^/]+))?$/)
  const params = [...url.searchParams.keys()]
  if (
    !match ||
    url.hash ||
    new Set(params).size !== params.length ||
    params.some((key) => !['queue', 'stage'].includes(key))
  )
    throw new Error('Неверная внутренняя ссылка разработки')
  if (match[1] && !catalog.tasks.some((task) => task.key === decodeURIComponent(match[1])))
    throw new Error('Ссылка ведёт к неизвестной задаче')
  const id = url.searchParams.get('queue')
  const stage = url.searchParams.get('stage')
  const queue = queues.find((item) => item.id === id)
  if ((id && !queue) || (stage && !queue?.stages.some((item) => item.id === stage)))
    throw new Error('Ссылка ведёт к неизвестной очереди/этапу')
  return href
}
