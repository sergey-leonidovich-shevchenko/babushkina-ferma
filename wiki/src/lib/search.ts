import type { Category, Entry, Material } from '../types.ts'

/** Нормализует русское ё, акценты и внутренние имена, сохраняя смысл слов запроса. */
export function normalize(text: string): string {
  return text
    .toLocaleLowerCase('ru')
    .replace(/ё/g, 'е')
    .normalize('NFKD')
    .replace(/\p{M}/gu, '')
    .replace(/[_-]+/g, ' ')
    .replace(/\s+/g, ' ')
    .trim()
}

/** Готовит полнотекстовый индекс описаний, наград, требований и связанных страниц. */
export function createIndex(entries: Entry[]) {
  const names = new Map(entries.map((entry) => [`${entry.category}/${entry.id}`, entry.title]))
  return entries.map((entry) => ({
    entry,
    title: normalize(entry.title),
    text: normalize(
      [
        entry.id,
        entry.title,
        entry.summary,
        ...entry.tags,
        ...entry.facts.flatMap((fact) => [fact.label, fact.value]),
        ...entry.sections.flatMap((section) => [section.title, section.text]),
        ...[
          ...entry.ingredients,
          ...entry.yields,
          ...(entry.byproducts ?? []),
          ...(entry.salvage ?? []),
          ...(entry.levels?.flatMap((level) => level.ingredients) ?? []),
        ].flatMap((part) => [part.id, part.name]),
        ...(entry.animation?.clips.map((clip) => clip.title) ?? []),
        ...entry.relations.map((link) => names.get(`${link.category}/${link.id}`) ?? ''),
        entry.html?.replace(/<[^>]+>/g, ' ') ?? '',
      ].join(' ')
    ),
  }))
}

/** Находит все слова запроса и поднимает точные названия выше упоминаний в длинных руководствах. */
export function search(
  index: ReturnType<typeof createIndex>,
  query: string,
  category?: Category
): Entry[] {
  const needle = normalize(query)
  const words = needle.split(' ').filter(Boolean)
  return index
    .filter(
      (row) =>
        (!category || row.entry.category === category) &&
        words.every((word) => row.text.includes(word))
    )
    .map((row) => ({
      entry: row.entry,
      score: !needle
        ? 0
        : (row.title === needle
            ? 100
            : row.title.startsWith(needle)
              ? 65
              : row.title.includes(needle)
                ? 40
                : 0) +
          words.filter((word) => row.title.includes(word)).length * 8 +
          (row.entry.category === 'characters' ? 3 : row.entry.category === 'items' ? 2 : 0),
    }))
    .sort((a, b) => b.score - a.score || a.entry.title.localeCompare(b.entry.title, 'ru'))
    .map((row) => row.entry)
}

/** Вычисляет количество материалов для выбранного числа партий, не имитируя инвентарь или производство. */
export function scaleMaterials(parts: Material[], batches: number): Material[] {
  const count = Number.isFinite(batches) ? Math.max(1, Math.min(999, Math.floor(batches))) : 1
  return parts.map((part) => ({ ...part, count: part.count * count }))
}
