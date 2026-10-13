import { shallowRef } from 'vue'
import type { Catalog, Category, Entry } from '../types.ts'
import { createIndex } from './search.ts'

export const categories: { id: Category; title: string; icon: string; description: string }[] = [
  {
    id: 'characters',
    title: 'Персонажи',
    icon: 'people',
    description:
      'Герои, жители, напарники и обитатели долины. У каждого — просмотр настоящих игровых анимаций.',
  },
  {
    id: 'missions',
    title: 'Миссии',
    icon: 'scroll',
    description: 'Основная история, первые дни на ферме, личные поручения и заказы гильдии.',
  },
  {
    id: 'buildings',
    title: 'Здания и станки',
    icon: 'house',
    description: 'Здания мира, строительство мастерской, ресурсы и три уровня рабочих мест.',
  },
  {
    id: 'craft',
    title: 'Крафт и алхимия',
    icon: 'hammer',
    description:
      'Все рецепты: ингредиенты, выход, рабочее место, ограничения и расчёт нескольких партий.',
  },
  {
    id: 'items',
    title: 'Предметы',
    icon: 'bag',
    description: 'Инструменты, еда, материалы и экипировка. Где получить и для чего использовать.',
  },
  {
    id: 'plants',
    title: 'Растения',
    icon: 'leaf',
    description: 'Огородные культуры и лекарственные травы, их урожай и способы обработки.',
  },
  {
    id: 'locations',
    title: 'Мир и локации',
    icon: 'map',
    description:
      'Районы деревни, биомы, лабиринт пещер и помещения — с переходами и местными жителями.',
  },
  {
    id: 'skills',
    title: 'Таланты',
    icon: 'spark',
    description: 'Способности героя, ранги и условия изучения.',
  },
  {
    id: 'fishing',
    title: 'Рыбалка',
    icon: 'fish',
    description: 'Виды рыб, размеры и условия ловли: время, глубина, сезон, погода и снасти.',
  },
  {
    id: 'guides',
    title: 'Руководство',
    icon: 'book',
    description: 'Как устроены ферма, путешествия и ремёсла. Полные инструкции и управление.',
  },
]
export const catalog = shallowRef<Catalog>()
export const entriesByKey = new Map<string, Entry>()
export let searchIndex: ReturnType<typeof createIndex> = []

/** Загружает готовый локальный справочник и один раз индексирует связи и текст. */
export async function loadCatalog() {
  const response = await fetch(`${import.meta.env.BASE_URL}generated/catalog.json`, {
    cache: 'no-cache',
  })
  if (!response.ok) throw new Error('Справочник не загрузился')
  const value = (await response.json()) as Catalog
  if (value.schema !== 1 || !Array.isArray(value.entries))
    throw new Error('Справочник нужно пересобрать')
  entriesByKey.clear()
  for (const entry of value.entries) entriesByKey.set(`${entry.category}/${entry.id}`, entry)
  searchIndex = createIndex(value.entries)
  catalog.value = value
}

/** Возвращает устойчивый адрес страницы для ссылки, истории браузера и копирования. */
export function entryPath(entry: Pick<Entry, 'category' | 'id'>) {
  return `/${entry.category}/${encodeURIComponent(entry.id)}`
}

/** Разрешает путь ресурса относительно сборки без зависимости от текущего адреса страницы. */
export function assetUrl(path: string) {
  return `${import.meta.env.BASE_URL}${path}`
}
