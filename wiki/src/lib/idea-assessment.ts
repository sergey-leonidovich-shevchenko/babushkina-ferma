export interface IdeaAssessment {
  idea: string
  usefulness: number
  interest: number
  fit: number
  synergy: number
  cost: number
  risk: number
  familiarity: number | null
  value: number
  confidence: string
  audience: string
  rationale: string
  prototype: string
  source: string | null
  analogue: string
  reviewedAt: string
  reviewTrigger: string
}

export interface AssessmentCatalog {
  schema: number
  method: string
  scale: number
  reviewedAt: string
  sources: Record<string, { title: string; url: string; scope: string }>
  ideas: IdeaAssessment[]
}

/** Считает обсуждаемую ценность; стоимость и риск остаются отдельными шкалами. */
export function assessmentValue(
  row: Pick<IdeaAssessment, 'usefulness' | 'interest' | 'fit' | 'synergy'>
) {
  return 6 * row.usefulness + 6 * row.interest + 5 * row.fit + 3 * row.synergy
}

/** Отклоняет выдуманные нули, неизвестные источники и несовместимые шкалы. */
export function validateAssessments(data: AssessmentCatalog): AssessmentCatalog {
  if (data.schema !== 1 || data.scale !== 5 || data.method !== 'designer-hypothesis-v1')
    throw new Error('Неизвестная шкала оценки идей')
  const ids = new Set<string>()
  for (const row of data.ideas) {
    if (!/^IDEA-\d{3,}$/.test(row.idea) || ids.has(row.idea))
      throw new Error('Повтор или неверный ID оценки')
    ids.add(row.idea)
    for (const field of ['usefulness', 'interest', 'fit', 'synergy', 'cost', 'risk'] as const)
      if (!Number.isInteger(row[field]) || row[field] < 1 || row[field] > 5)
        throw new Error(`Оценка ${row.idea}: неверная шкала ${field}`)
    if (
      row.value !== assessmentValue(row) ||
      (row.familiarity !== null &&
        (!Number.isInteger(row.familiarity) || row.familiarity < 1 || row.familiarity > 5)) ||
      (row.familiarity !== null && !row.source) ||
      (row.source !== null && !data.sources[row.source]) ||
      !['hypothesis', 'pilot', 'validated'].includes(row.confidence) ||
      !/^\d{4}-\d{2}-\d{2}$/.test(row.reviewedAt) ||
      ![row.audience, row.rationale, row.prototype, row.analogue, row.reviewTrigger].every(
        (value) => typeof value === 'string' && value.trim().length > 0
      )
    )
      throw new Error(`Оценка ${row.idea}: нет обоснования или неверная ценность`)
  }
  for (const source of Object.values(data.sources))
    if (!source.title || !source.scope || !/^https:\/\//.test(source.url))
      throw new Error('У сравнения нет проверяемого источника')
  return data
}

/** Отсутствие оценки остаётся отсутствием, а не нулём полезности. */
export function assessmentFor(data: AssessmentCatalog, id: string) {
  return data.ideas.find((row) => row.idea === id)
}

/** Сортирует экспертные оценки без смены статусов и очередности разработки. */
export function compareAssessmentIdeas(
  a: { id: string },
  b: { id: string },
  order: string,
  data: AssessmentCatalog
) {
  const recent = () => b.id.localeCompare(a.id, 'ru', { numeric: true })
  if (!['value', 'interest', 'usefulness', 'cost'].includes(order)) return recent()
  const first = assessmentFor(data, a.id)
  const second = assessmentFor(data, b.id)
  if (!first || !second) return first ? -1 : second ? 1 : recent()
  const field = order as 'value' | 'interest' | 'usefulness' | 'cost'
  return (
    (order === 'cost' ? first[field] - second[field] : second[field] - first[field]) || recent()
  )
}

/** Сохраняет только явно зарегистрированные внутренние адреса прежних карточек. */
export function legacyDevelopmentPath(path: string, links: Record<string, string>) {
  const target = Object.hasOwn(links, path) ? links[path] : undefined
  return target && /^\/(development\/tasks\/|guides\/)[A-Za-z0-9-]+$/.test(target)
    ? target
    : undefined
}
