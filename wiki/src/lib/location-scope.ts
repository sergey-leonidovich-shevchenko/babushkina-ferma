import type { PlanTask } from './planning.ts'

/** Техническое обслуживание курса; редакционные IDEA-обзоры не являются работой над картой. */
export function locationSupport(task: PlanTask) {
  return (
    (task.plan === 'refactoring' && task.epic === 'refactoring--REFACTOR') ||
    (task.plan === 'wiki' && /^WIKI-\d+$/.test(task.id)) ||
    (task.plan === 'base' &&
      ['base--EPIC-PERF', 'base--EPIC-SAFE', 'base--EPIC-QA', 'base--EPIC-UX'].includes(task.epic))
  )
}

/** Контекст объясняет приоритет, но не переопределяет статус или графическую приёмку. */
export function supportContext(task: PlanTask) {
  if (task.plan === 'refactoring')
    return 'Технический приоритет: упорядочивание tools перед продолжением графики. Приёмка карты остаётся за VMAP-003.'
  if (task.plan === 'wiki') return 'Обслуживание разработки: Wiki и прозрачный учёт работы.'
  return 'Техническое обслуживание: производительность, надёжность, интерфейс и QA.'
}
