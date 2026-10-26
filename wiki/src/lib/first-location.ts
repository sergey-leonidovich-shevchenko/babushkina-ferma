import type { PlanEpic, PlanTask } from './planning.ts'
import { locationSupport, supportContext } from './location-scope.ts'

export const firstLocationGroups = [
  {
    title: 'Основание и художественный стандарт',
    goal: 'Мягкий стиль A, масштаб, камера и правильная сборка слоёв.',
    keys: [
      'visual--VART',
      'visual--VPIPELINE',
      'visual--VBASE',
      'visual--VCAMERA',
      'visual--VRENDER',
    ],
  },
  {
    title: 'Земля, вода и растительность',
    goal: 'Естественные тропы, низкий берег, прозрачная вода, объёмные деревья и живая трава.',
    keys: [
      'visual--VGROUND',
      'visual--VSHORE',
      'water--WATER',
      'visual--VTREE',
      'visual--VFOLIAGE',
    ],
  },
  {
    title: 'Предметы, фасады и обитатели',
    goal: 'Единый рисунок объектов, жителей, животных и посадок, видимых на первой карте.',
    keys: ['visual--VPROP', 'visual--VBUILD', 'visual--VACTOR', 'visual--VPLANT'],
  },
  {
    title: 'Свет и атмосфера',
    goal: 'Мягкие тени, общий свет, вечер, ночь и существующая погода.',
    keys: ['visual--VSHADOW', 'visual--VLIGHT', 'visual--VWEATHER'],
  },
  {
    title: 'Надёжность и приёмка',
    goal: 'Плавность, сохранения, редактор и завершение всей overworld до VMAP-003.',
    keys: [
      'visual--VPERF',
      'visual--VCOMPAT',
      'visual--VEDITOR',
      'visual--VRELEASE',
      'visual--VMAP',
    ],
  },
]

export const firstLocationMilestones = [
  { id: 'VRELEASE-002', title: 'Статичный пилот' },
  { id: 'VRELEASE-003', title: 'Живой пилот' },
  { id: 'VRELEASE-004', title: 'Производительность пилота' },
  { id: 'VMAP-001', title: 'Ведомость всей первой карты' },
  { id: 'VMAP-002', title: 'Свет и атмосфера всей карты' },
  { id: 'VMAP-003', title: 'Итоговая приёмка локации' },
]
const mapTasks = new Set(['VMAP-001', 'VMAP-002', 'VMAP-003'])
const releaseTasks = new Set([
  'VRELEASE-001',
  'VRELEASE-002',
  'VRELEASE-003',
  'VRELEASE-004',
  'VRELEASE-005',
])
const catalogEpics = new Set(['visual--VBUILD', 'visual--VACTOR', 'visual--VPLANT'])

/** Выбирает существующие карточки эпика, ограничивая карты и релиз первым участком программы. */
export function firstLocationTasks(key: string, tasks: PlanTask[]) {
  return tasks.filter(
    (task) =>
      task.epic === key &&
      (key !== 'visual--VMAP' || mapTasks.has(task.id)) &&
      (key !== 'visual--VRELEASE' || releaseTasks.has(task.id))
  )
}

/** Собирает обзор из текущих статусов без копирования задач и без общего процента готовности карты. */
export function firstLocationOverview(catalog: { epics: PlanEpic[]; tasks: PlanTask[] }) {
  const groups = firstLocationGroups.map((group) => ({
    ...group,
    epics: group.keys.map((key) => {
      const epic = catalog.epics.find((item) => item.key === key)
      const tasks = firstLocationTasks(key, catalog.tasks)
      const counts = Object.fromEntries(
        ['done', 'in_progress', 'ready', 'blocked', 'backlog'].map((status) => [
          status,
          tasks.filter((task) => task.status === status).length,
        ])
      )
      return {
        key,
        epic,
        counts,
        total: tasks.length,
        scope:
          key === 'visual--VMAP'
            ? 'Только первая карта · 3 карточки'
            : key === 'visual--VRELEASE'
              ? 'Первая очередь · 5 карточек'
              : catalogEpics.has(key)
                ? 'Весь каталог · состав первой карты уточнит VMAP-001'
                : 'Все карточки эпика',
      }
    }),
  }))
  const selected = new Set(groups.flatMap((group) => group.keys))
  const onRoute = (task: PlanTask) =>
    selected.has(task.epic) && firstLocationTasks(task.epic, [task]).length > 0
  const context = (task: PlanTask) =>
    onRoute(task)
      ? 'Маршрут первой локации'
      : locationSupport(task)
        ? supportContext(task)
        : 'Другое направление. Его статус не означает смену курса первой локации.'
  const active = catalog.tasks
    .filter((task) => task.status === 'in_progress')
    .sort((a, b) => {
      const priority = (task: PlanTask) =>
        task.plan === 'refactoring' ? 0 : onRoute(task) ? 1 : locationSupport(task) ? 2 : 3
      return priority(a) - priority(b)
    })
    .map((task) => ({ ...task, context: context(task) }))
  // stable sort сохраняет порядок источника для равных дат и неизвестных дат.
  const history = catalog.tasks
    .filter((task) => task.status === 'done' && (onRoute(task) || locationSupport(task)))
    .map((task) => ({ ...task, context: context(task) }))
    .sort((a, b) => {
      const left = a.completion?.date ?? ''
      const right = b.completion?.date ?? ''
      return left < right ? 1 : left > right ? -1 : 0
    })
  const milestones = firstLocationMilestones.map((gate) => ({
    ...gate,
    task: catalog.tasks.find((task) => task.plan === 'visual' && task.id === gate.id),
  }))
  return {
    groups,
    active,
    history,
    milestones,
    accepted: milestones.find((gate) => gate.id === 'VMAP-003')?.task?.status === 'done',
  }
}
