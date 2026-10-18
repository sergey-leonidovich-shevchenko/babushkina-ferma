import type { PlanTask } from './planning.ts'

export interface RolloutQueue {
  schema: number
  id: string
  title: string
  description: string
  guide: string
  plan: string
  ownerKey: string
  planningOnly: boolean
  implementationAccepted: boolean
  taskKeys: string[]
  extraDependencies: Record<string, string[]>
  stages: { id: string; title: string; goal: string; taskKeys: string[] }[]
}

/** Объединяет реальные зависимости карточки с дополнительными условиями пилота. */
export function queueBlockers(
  task: PlanTask,
  queue: RolloutQueue,
  tasks: PlanTask[] | Map<string, PlanTask>
) {
  const by = tasks instanceof Map ? tasks : new Map(tasks.map((item) => [item.key, item]))
  return [
    ...new Set([
      ...task.dependencies.map((id) => `${task.plan}--${id}`),
      ...(queue.extraDependencies[task.key] ?? []),
    ]),
  ].filter((key) => by.get(key)?.status !== 'done')
}

/** Отклоняет устаревший порядок при живом обновлении карточек, не выдавая его за актуальную очередь. */
export function queueIssue(queue: RolloutQueue, tasks: PlanTask[]) {
  const by = new Map(tasks.map((task) => [task.key, task]))
  const order = new Map(queue.taskKeys.map((key, index) => [key, index]))
  for (const key of queue.taskKeys) {
    const task = by.get(key)
    if (!task) return `Нет карточки ${key}. Обновите Wiki.`
    for (const dep of [
      ...task.dependencies.map((id) => `${task.plan}--${id}`),
      ...(queue.extraDependencies[key] ?? []),
    ])
      if (
        !by.has(dep) ||
        (dep !== queue.ownerKey && (!order.has(dep) || order.get(dep)! >= order.get(key)!))
      )
        return 'Зависимости изменились. Пересоберите Wiki и очередь.'
    if (task.status === 'done' && queueBlockers(task, queue, by).length)
      return 'У завершённой карточки остались условия пилота. Требуется проверка плана.'
  }
  return ''
}

/** Считает прогресс и рекомендацию только из текущего каталога без изменения его статусов. */
export function queueProgress(queue: RolloutQueue, tasks: PlanTask[]) {
  const by = new Map(tasks.map((task) => [task.key, task]))
  const ordered = queue.taskKeys
    .map((key) => by.get(key))
    .filter((task): task is PlanTask => !!task)
  const available = (task: PlanTask) => !queueBlockers(task, queue, by).length
  return {
    total: ordered.length,
    done: ordered.filter((task) => task.status === 'done').length,
    next: ordered.find((task) => task.status === 'ready' && available(task)),
    preparable: ordered.find((task) => task.status === 'backlog' && available(task)),
  }
}

/** Сохраняет заданную очередью сортировку и не подменяет неизвестную очередь полным списком задач. */
export function queueTasks(tasks: PlanTask[], queue?: RolloutQueue, stage?: string) {
  if (!queue) return []
  const keys = stage
    ? (queue.stages.find((item) => item.id === stage)?.taskKeys ?? [])
    : queue.taskKeys
  const by = new Map(tasks.map((task) => [task.key, task]))
  return keys.map((key) => by.get(key)).filter((task): task is PlanTask => !!task)
}
