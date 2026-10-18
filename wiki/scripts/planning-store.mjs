import { readFile, open, rename, rm } from 'node:fs/promises'
import { join } from 'node:path'
import { randomUUID } from 'node:crypto'
import { wikiRoot } from './runtime.mjs'

export const ideaStatuses = ['proposed', 'approved', 'refining', 'planned', 'archived']

/** Ошибка с отдельным HTTP-статусом без публикации путей и системных подробностей. */
export class PlanningError extends Error {
  constructor(message, status = 400) {
    super(message)
    this.status = status
  }
}

/** Проверяет текст до изменения общей редакционной записи. */
function text(value, label, limit, empty = false) {
  if (typeof value !== 'string' || value.length > limit || (!empty && !value.trim()))
    throw new PlanningError(`Проверьте поле «${label}» (до ${limit} знаков)`)
  return value.trim()
}

/** Проверяет целостность сохранённого состояния и связей с настоящими эпиками. */
export function validateWorkspace(state, catalog) {
  if (
    state.schema !== 1 ||
    !Number.isSafeInteger(state.revision) ||
    state.revision < 0 ||
    !Array.isArray(state.groups) ||
    !state.groups.length ||
    !Array.isArray(state.ideas) ||
    !state.epicGroups ||
    Array.isArray(state.epicGroups) ||
    typeof state.epicGroups !== 'object'
  )
    throw new PlanningError('Неизвестный формат центра разработки', 500)
  const groups = new Set()
  for (const group of state.groups) {
    if (!/^[a-z][a-z0-9-]*$/.test(group.id) || groups.has(group.id))
      throw new PlanningError('Повтор или неверный ID группы', 500)
    text(group.title, 'Название группы', 100)
    groups.add(group.id)
  }
  const epics = new Set(catalog.epics.map((epic) => epic.key))
  const plans = new Set(catalog.plans.map((plan) => plan.id))
  if (catalog.epics.some((epic) => !groups.has(epic.group)))
    throw new PlanningError('У плана неизвестная группа', 500)
  for (const [key, group] of Object.entries(state.epicGroups))
    if (!epics.has(key) || !groups.has(group))
      throw new PlanningError('Неизвестный эпик или группа', 409)
  const ids = new Set()
  for (const idea of state.ideas) {
    if (
      !/^IDEA-\d{3,}$/.test(idea.id) ||
      ids.has(idea.id) ||
      !ideaStatuses.includes(idea.status) ||
      !groups.has(idea.group) ||
      !Array.isArray(idea.linkedEpics) ||
      !Array.isArray(idea.history)
    )
      throw new PlanningError('Повреждена карточка идеи', 500)
    text(idea.title, 'Название', 160)
    text(idea.description, 'Описание', 20000)
    text(idea.notes ?? '', 'Заметки', 20000, true)
    if (
      idea.linkedEpics.some((key) => !epics.has(key)) ||
      (idea.linkedPlans ?? []).some((key) => !plans.has(key))
    )
      throw new PlanningError('Идея ссылается на отсутствующий план', 409)
    if (idea.status === 'planned' && !idea.linkedEpics.length && !idea.linkedPlans?.length)
      throw new PlanningError('Для готовой постановки нужны связанные эпики', 409)
    ids.add(idea.id)
  }
  return state
}

/** Подтягивает новые редакционные статьи как предложения, сохраняя все прежние решения. */
function includeArticles(state, catalog) {
  for (const article of catalog.ideaArticles ?? [])
    if (!state.ideas.some((idea) => idea.id === article.id))
      state.ideas.push({
        ...article,
        status: 'proposed',
        group: state.groups[0].id,
        notes: '',
        linkedEpics: [],
        history: [],
      })
  return state
}

/** Формирует передаваемое агенту задание только для явно одобренной идеи. */
export function agentBrief(idea) {
  return (
    `${idea.id} — ${idea.title}\n\n${idea.description}\n\n${idea.notes ? `Замечания:\n${idea.notes}\n\n` : ''}` +
    'Проработай идею и создай задачи: сверь существующий код и планы, выбери единственного владельца, ' +
    'опиши результат, границы, зависимости и индивидуальную приёмку. Сохрани постоянные ID. ' +
    'Зарегистрируй новые эпики в wiki/planning/sources.json и свяжи их с идеей через центр разработки. ' +
    'Одобрение идеи не означает готовую реализацию. Соблюдай AGENTS.md и TESTING.md.'
  )
}

/** Изменяет только редакционные решения; статусы и содержание игровых задач здесь недоступны. */
function applyAction(state, action, catalog) {
  const now = new Date().toISOString()
  const group = (id) => {
    if (!state.groups.some((item) => item.id === id))
      throw new PlanningError('Группа больше не существует', 409)
    return id
  }
  if (action.type === 'create-group') {
    const title = text(action.title, 'Название группы', 100)
    if (state.groups.some((item) => item.title.toLocaleLowerCase() === title.toLocaleLowerCase()))
      throw new PlanningError('Группа с таким названием уже есть')
    state.groups.push({ id: `group-${randomUUID().slice(0, 8)}`, title })
    return
  }
  if (action.type === 'rename-group') {
    group(action.id)
    const title = text(action.title, 'Название группы', 100)
    if (
      state.groups.some(
        (item) =>
          item.id !== action.id && item.title.toLocaleLowerCase() === title.toLocaleLowerCase()
      )
    )
      throw new PlanningError('Группа с таким названием уже есть')
    state.groups.find((item) => item.id === action.id).title = title
    return
  }
  if (action.type === 'move-epic') {
    if (!catalog.epics.some((epic) => epic.key === action.epic))
      throw new PlanningError('Эпик не найден', 404)
    state.epicGroups[action.epic] = group(action.group)
    return
  }
  if (action.type === 'create-idea') {
    const number = Math.max(0, ...state.ideas.map((idea) => Number(idea.id.slice(5)))) + 1
    state.ideas.push({
      id: `IDEA-${String(number).padStart(3, '0')}`,
      title: text(action.title, 'Название', 160),
      description: text(action.description, 'Описание', 20000),
      notes: text(action.notes ?? '', 'Заметки', 20000, true),
      group: group(action.group),
      linkedEpics: [],
      status: 'proposed',
      createdAt: now,
      updatedAt: now,
      history: [{ at: now, type: 'created', to: 'proposed' }],
    })
    return
  }
  const idea = state.ideas.find((item) => item.id === action.id)
  if (!idea) throw new PlanningError('Идея не найдена', 404)
  if (action.type === 'edit-idea') {
    Object.assign(idea, {
      title: text(action.title, 'Название', 160),
      description: text(action.description, 'Описание', 20000),
      group: group(action.group),
      notes: text(action.notes ?? '', 'Заметки', 20000, true),
      updatedAt: now,
    })
    idea.history.push({ at: now, type: 'edited' })
    return
  }
  let next = action.status
  if (action.type === 'plan-idea') {
    if (!['approved', 'refining', 'planned'].includes(idea.status))
      throw new PlanningError('Сначала одобрите идею для проработки', 409)
    if (
      !Array.isArray(action.epics) ||
      action.epics.length > 200 ||
      action.epics.some((key) => !catalog.epics.some((epic) => epic.key === key))
    )
      throw new PlanningError('Выберите существующие эпики')
    idea.linkedEpics = [...new Set(action.epics)]
    next = 'planned'
  } else if (
    action.type !== 'set-idea-status' ||
    !['proposed', 'approved', 'refining', 'archived'].includes(next)
  ) {
    throw new PlanningError('Неизвестное действие')
  }
  const allowed = {
    proposed: ['approved', 'archived'],
    approved: ['proposed', 'refining', 'archived', 'planned'],
    refining: ['proposed', 'approved', 'archived', 'planned'],
    planned: ['approved', 'planned'],
    archived: ['proposed'],
  }
  if (!allowed[idea.status].includes(next))
    throw new PlanningError('Этот переход состояния недоступен', 409)
  idea.history.push({ at: now, type: 'status', from: idea.status, to: next })
  idea.status = next
  idea.updatedAt = now
}

/** Создаёт атомарное хранилище с ревизией и межпроцессной блокировкой без браузерного кеша. */
export function createPlanningStore(file = join(wikiRoot, 'planning/state.json')) {
  return {
    async read(catalog) {
      const state = includeArticles(JSON.parse(await readFile(file, 'utf8')), catalog)
      return validateWorkspace(state, catalog)
    },
    async change(action, catalog) {
      if (!action || typeof action !== 'object' || !Number.isSafeInteger(action.revision))
        throw new PlanningError('Нужна текущая ревизия центра разработки')
      let lock
      try {
        lock = await open(`${file}.lock`, 'wx', 0o600)
      } catch (error) {
        if (error.code === 'EEXIST')
          throw new PlanningError(
            'Другая запись уже выполняется. Обновите список и повторите.',
            409
          )
        throw error
      }
      const temporary = `${file}.${randomUUID()}.tmp`
      try {
        const state = await this.read(catalog)
        if (state.revision !== action.revision)
          throw new PlanningError(
            'Данные изменились в другой вкладке. Обновите список и повторите действие.',
            409
          )
        applyAction(state, action, catalog)
        state.revision++
        state.updatedAt = new Date().toISOString()
        validateWorkspace(state, catalog)
        const output = await open(temporary, 'wx', 0o600)
        try {
          await output.writeFile(`${JSON.stringify(state, null, 2)}\n`)
          await output.sync()
        } finally {
          await output.close()
        }
        await rename(temporary, file)
        return state
      } finally {
        await rm(temporary, { force: true })
        await lock.close()
        await rm(`${file}.lock`, { force: true })
      }
    },
  }
}
