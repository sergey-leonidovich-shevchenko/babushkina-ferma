export interface IdeaDraft {
  title: string
  description: string
  notes: string
  group: string
}

/** Сохраняет только местные правки, подтягивая остальные поля после конфликта вкладок. */
export function refreshIdeaDraft(
  current: IdeaDraft,
  previous: IdeaDraft,
  incoming: IdeaDraft
): IdeaDraft {
  const field = (key: keyof IdeaDraft) =>
    current[key] !== previous[key] ? current[key] : incoming[key]
  return {
    title: field('title'),
    description: field('description'),
    notes: field('notes'),
    group: field('group'),
  }
}
