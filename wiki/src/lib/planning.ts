import { computed, ref, shallowRef } from 'vue'
import { assetUrl } from './catalog.ts'

export interface PlanGroup {
  id: string
  title: string
}
export interface PlanEpic {
  key: string
  id: string
  title: string
  goal: string
  plan: string
  group: string
  source: string
}
export interface PlanTask {
  key: string
  id: string
  title: string
  plan: string
  epic: string
  status: string
  priority: string
  size: string
  goal: string
  acceptance: string[]
  dependencies: string[]
  result: string
  sections: { title: string; text: string }[]
  source: string
  content: string
}
export type IdeaStatus = 'proposed' | 'approved' | 'refining' | 'planned' | 'archived'
export interface PlanIdea {
  id: string
  title: string
  description: string
  status: IdeaStatus
  group: string
  notes: string
  article?: string
  linkedEpics: string[]
  linkedPlans?: string[]
  createdAt?: string
  updatedAt?: string
  history: { at: string; type: string; from?: string; to?: string }[]
}
export interface PlanningData {
  schema: number
  readOnly: boolean
  catalog: { plans: { id: string; title: string }[]; epics: PlanEpic[]; tasks: PlanTask[] }
  workspace: {
    schema: number
    revision: number
    groups: PlanGroup[]
    epicGroups: Record<string, string>
    ideas: PlanIdea[]
    updatedAt?: string
  }
}

export const planning = shallowRef<PlanningData>()
export const planningError = ref('')
export const planningMessage = ref('')
export const planningLoading = ref(false)
export const planningSaving = ref(false)
export const ideaLabels: Record<IdeaStatus, string> = {
  proposed: 'Предложение',
  approved: 'Одобрено',
  refining: 'В проработке',
  planned: 'Задачи созданы',
  archived: 'Отложено',
}
export const taskLabels: Record<string, string> = {
  backlog: 'В плане',
  ready: 'Готова к работе',
  blocked: 'Заблокирована',
  in_progress: 'В работе',
  done: 'Завершена',
}
export const refinementIdeas = computed(
  () =>
    planning.value?.workspace.ideas.filter((idea) =>
      ['approved', 'refining'].includes(idea.status)
    ) ?? []
)

/** Загружает живые решения, а при статическом просмотре явно запрещает запись. */
export async function loadPlanning() {
  if (planningLoading.value) return
  planningLoading.value = true
  planningError.value = ''
  try {
    let response = await fetch('/__wiki/planning', {
      cache: 'no-store',
      signal: AbortSignal.timeout(15000),
    })
    if (!response.ok) throw new Error('Сервер недоступен')
    const value = (await response.json()) as PlanningData
    if (value.schema !== 1 || !value.catalog?.tasks || !value.workspace?.ideas)
      throw new Error('Неверный формат')
    planning.value = value
  } catch {
    try {
      const response = await fetch(assetUrl('generated/planning.json'), { cache: 'no-store' })
      if (!response.ok) throw new Error('Нет сохранённого обзора')
      const value = (await response.json()) as PlanningData
      if (value.schema !== 1 || !value.catalog?.tasks || !value.workspace?.ideas)
        throw new Error('Неверный формат')
      planning.value = { ...value, readOnly: true }
    } catch {
      planningError.value = 'Не удалось открыть планы. Запустите Wiki ещё раз и повторите загрузку.'
      if (planning.value) planning.value = { ...planning.value, readOnly: true }
    }
  } finally {
    planningLoading.value = false
  }
}

/** Сохраняет одну редакционную операцию, не меняя экран при неуспешной записи. */
export async function changePlanning(action: Record<string, unknown>) {
  if (!planning.value || planning.value.readOnly || planningSaving.value) return false
  planningSaving.value = true
  planningError.value = ''
  planningMessage.value = ''
  try {
    const response = await fetch('/__wiki/planning/change', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', 'X-Wiki-Planning': '1' },
      body: JSON.stringify({ ...action, revision: planning.value.workspace.revision }),
      signal: AbortSignal.timeout(15000),
    })
    const value = (await response.json()) as {
      error?: string
      workspace: PlanningData['workspace']
    }
    if (!response.ok) throw new Error(value.error ?? 'Не удалось сохранить изменения')
    planning.value = { ...planning.value, workspace: value.workspace }
    planningMessage.value = 'Сохранено в проекте'
    return true
  } catch (error) {
    planningError.value = error instanceof Error ? error.message : 'Не удалось сохранить изменения'
    return false
  } finally {
    planningSaving.value = false
  }
}

/** Сохраняет поиск, фильтры и закладки обычными адресами страниц. */
export function developmentPath(section: string, id?: string) {
  return `/development/${section}${id ? `/${encodeURIComponent(id)}` : ''}`
}

/** Проверяет текст без зависимости от регистра и буквы ё. */
export function matchesQuery(query: string, ...values: string[]) {
  const normalize = (text: string) => text.toLocaleLowerCase().replace(/ё/g, 'е')
  return normalize(query)
    .split(/\s+/)
    .filter(Boolean)
    .every((word) => normalize(values.join(' ')).includes(word))
}

/** Находит конкретную карточку зависимости, предпочитая тот же план. */
export function findTask(id: string, plan?: string) {
  return (
    planning.value?.catalog.tasks.find((task) => task.id === id && task.plan === plan) ??
    planning.value?.catalog.tasks.find((task) => task.id === id)
  )
}

/** Копирует явный текст задания, оставляя ошибку видимой при запрете буфера обмена. */
export async function copyPlanningText(value: string) {
  try {
    await navigator.clipboard.writeText(value)
    planningMessage.value = 'Задание скопировано'
  } catch {
    planningError.value = 'Браузер не разрешил копирование. Выделите текст задания вручную.'
  }
}
