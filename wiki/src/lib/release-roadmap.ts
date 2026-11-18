import type { PlanTask } from './planning.ts'
import { locationPortions } from './first-location.ts'

export interface RoadmapCard {
  id: string
  title: string
  outcome: string
  keys: string[]
  map?: string
}

export interface RoadmapStage {
  id: string
  title: string
  outcome: string
  marker: string
  cards: RoadmapCard[]
}

/** Состав выпуска — решение о границах продукта; статусы всегда приходят из каталога. */
export const demoMaps = [
  'overworld',
  'forest',
  'village_market',
  'village_garden',
  'village_river',
  'village_workyard',
  'village_orchard',
  'cottage_interior',
  'shop_interior',
  'guild_interior',
]

export const releaseMaps = [
  ['overworld', 'Деревня и ферма', 3],
  ['forest', 'Лес и Страж чащи', 6],
  ['rocky', 'Каменистая область', 9],
  ['ruins', 'Орочьи руины', 12],
  ['cave', 'Кристальные пещеры', 15],
  ['cursed', 'Проклятая земля', 18],
  ['glassworks', 'Мастерская стеклодува', 21],
  ['pirate_ship', 'Корабль «Чёрная сельдь»', 24],
  ['moon_glade', 'Лунная поляна', 27],
  ['village_market', 'Торговая слобода', 30],
  ['village_garden', 'Сад травницы', 33],
  ['village_river', 'Речная переправа', 36],
  ['village_workyard', 'Ремесленный двор', 39],
  ['village_orchard', 'Яблоневый сад', 42],
  ['cave_fungal', 'Грибной зал', 45],
  ['cave_moon', 'Лунный грот', 48],
  ['cave_lake', 'Подземное озеро', 51],
  ['cave_mine', 'Старая шахта', 54],
  ['cave_sanctum', 'Забытое святилище', 57],
  ['cellar_workshop', 'Подвал-мастерская', 60],
  ['cottage_interior', 'Дом бабушки', 63],
  ['shop_interior', 'Сельская лавка', 66],
  ['guild_interior', 'Зал гильдии', 69],
  ['forge_interior', 'Кузница', 72],
  ['chapel_interior', 'Лунная часовня', 75],
  ['prison_interior', 'Тюрьма руин', 78],
  ['tower_interior', 'Башня мага', 81],
  ['castle_hall', 'Большой зал замка', 84],
  ['castle_upper', 'Верхний этаж замка', 87],
  ['castle_dungeon', 'Подземелье замка', 90],
] as const

const card = (id: string, title: string, outcome: string, keys: string[]): RoadmapCard => ({
  id,
  title,
  outcome,
  keys,
})

/** Каждая карта получает собственные VMAP и общую приёмку ресурсов соответствующего выпуска. */
function mapCard([map, title, final]: (typeof releaseMaps)[number]): RoadmapCard {
  const demo = demoMaps.includes(map)
  return {
    id: map,
    map,
    title,
    outcome: 'Комплект рисунков → свет и атмосфера → штатный маршрут, сохранения и бюджет.',
    keys: [
      ...[final - 2, final - 1, final].map((id) => `visual--VMAP-${String(id).padStart(3, '0')}`),
      demo ? 'release--DEMO-002' : 'release--RELEASE-001',
    ],
  }
}

/** Три шага демо, затем полный продукт и обслуживание; существующая очередь первой карты сохранена. */
export function roadmapStages(tasks: PlanTask[], pilotKeys: readonly string[]): RoadmapStage[] {
  const first = locationPortions(tasks, pilotKeys)[0]!
  return [
    {
      id: 'foundation',
      title: '1. Живописная и плавная первая локация',
      marker: 'Первая локация принята',
      outcome:
        'Довести эталон A до всей overworld: рисунок, движение, свет и измеренная плавность.',
      cards: [
        card(
          'overworld',
          'Деревня и ферма целиком',
          'Вся карта, оба моста, фасады, жители, посадки и атмосфера. Итог — VMAP-003.',
          [...first.tasks.map((task) => task.key), ...first.missing]
        ),
      ],
    },
    {
      id: 'chapter',
      title: '2. Законченное первое приключение',
      marker: 'Глава собрана',
      outcome:
        '10 доступных карт с финальным рисунком. Ферма → мост → лесной страж → редкое семя → выбор награды.',
      cards: [
        card(
          'scope',
          'Границы демо и комплект ресурсов',
          'Проверить все выходы, расписания жителей, услуги и награды. Ни одного доступного недорисованного места.',
          ['release--DEMO-001', 'release--DEMO-002']
        ),
        card(
          'heroes',
          'Два героя: выбор и живое движение',
          'Мужской и женский образы, плавная походка, действия и предметы в руках. Выбор в начале игры и сохранения; сначала проба 3D → 2D.',
          [
            'visual--VANIM-002',
            'visual--VACTOR-001',
            'visual--VACTOR-002',
            'visual--VACTOR-003',
            'visual--VACTOR-004',
            'hero--HERO-01',
            'hero--HERO-02',
          ]
        ),
        ...releaseMaps
          .filter(([map]) => map !== 'overworld' && demoMaps.includes(map))
          .map(mapCard),
        card(
          'demo-art',
          'Вся графика демо принята',
          'Сверить готовые ресурсы с ведомостью: все 10 карт, герой, жители, Страж, предметы и доступные состояния.',
          ['release--DEMO-007']
        ),
        card(
          'story',
          'Первые дни, бой и завершение главы',
          'Понятная цель, честные атаки, однократные награды и свободное возвращение домой после финала.',
          [
            'base--WORLD-01',
            'base--WORLD-04',
            'base--WORLD-06',
            'base--WORLD-07',
            'release--DEMO-003',
          ]
        ),
        card(
          'presentation',
          'Интерфейс, отклик и звук',
          'Читаемый HUD, фокус меню, все шесть языков, обратная связь действий и спокойная звуковая среда.',
          ['base--UX-01', 'base--UX-02', 'base--UX-03', 'base--UX-04', 'release--DEMO-004']
        ),
      ],
    },
    {
      id: 'demo',
      title: '3. Проверить и выпустить демо',
      marker: 'ДЕМО ГОТОВО',
      outcome:
        'Свежая установка, реальные игроки и устройства, стабильный кадр, сохранения и распространяемая сборка.',
      cards: [
        card(
          'quality',
          'Плавность и надёжность на устройствах',
          'Принять профили качества и существующие технические блокеры без подмены замеров роликом.',
          ['base--OPT-13', 'base--QA-02', 'base--QA-03', 'visual--VPERF-010', 'visual--VCOMPAT-010']
        ),
        card(
          'playtest',
          'Внешний плейтест и исправления',
          'Проверить понимание, темп, удовольствие и достижимость финала на обычных запасах.',
          ['base--QA-04', 'release--DEMO-005']
        ),
        card(
          'demo-release',
          'Релизный кандидат демо',
          'Сборка с финальной графикой всех 10 карт, отключёнными средствами разработки, номером версии и инструкцией.',
          ['base--QA-05', 'release--DEMO-006']
        ),
      ],
    },
    {
      id: 'release',
      title: 'Полная игра · после демо',
      marker: 'ПОЛНАЯ ИГРА ГОТОВА',
      outcome:
        'Оформить остальные 20 существующих карт, связать всю кампанию и принять выпуск 1.0.',
      cards: [
        card(
          'full-scope',
          'Состав 1.0 и контент всей кампании',
          'Все 30 существующих карт; завершённый сюжет, достижимая экономика и каталог доступных ресурсов.',
          ['release--RELEASE-001', 'release--RELEASE-002']
        ),
        ...releaseMaps.filter(([map]) => !demoMaps.includes(map)).map(mapCard),
        card(
          'footprints',
          'Следы на мокрой земле',
          'Одобренный небольшой визуальный выпуск IDEA-192 после демо. Ограниченный слой, без новой механики грязи.',
          ['idea-192--IDEA-192-01', 'idea-192--IDEA-192-02', 'idea-192--IDEA-192-03']
        ),
        card(
          'full-release',
          'Приёмка всей игры и выпуск 1.0',
          'Все карты и доступный каталог оформлены, кампания пройдена, экспорт и миграция демо проверены.',
          [
            'visual--VRELEASE-008',
            'visual--VRELEASE-010',
            'release--RELEASE-003',
            'release--RELEASE-004',
          ]
        ),
      ],
    },
    {
      id: 'aftercare',
      title: 'После релиза · поддержка и дополнения',
      marker: 'План следующих выпусков',
      outcome:
        'Сначала исправления и отзывы. Дополнение получает отдельную тему и собственную приёмку.',
      cards: [
        card(
          'patches',
          'Патчи и качество жизни',
          'Собрать воспроизводимые проблемы, исправлять потери прогресса в первую очередь, проверять обновление и откат.',
          ['release--LIVE-001']
        ),
        card(
          'dlc',
          'Предпроект будущего DLC',
          'Выбрать самостоятельное приключение после отзывов на 1.0; проверить интерес, цену производства и сохранения.',
          ['release--LIVE-002']
        ),
      ],
    },
  ]
}

/** Разворачивает реальные зависимости. Пропуски, неоднозначные ID и циклы запрещают отметку готовности. */
export function roadmapClosure(keys: readonly string[], tasks: PlanTask[]) {
  const byKey = new Map(tasks.map((task) => [task.key, task]))
  const byId = new Map<string, PlanTask[]>()
  for (const task of tasks) byId.set(task.id, [...(byId.get(task.id) ?? []), task])
  const visited = new Set<string>()
  const visiting = new Set<string>()
  const issues = new Set<string>()
  const resolved: PlanTask[] = []
  function visit(key: string) {
    if (visiting.has(key)) {
      issues.add(`Цикл зависимостей: ${key}`)
      return
    }
    if (visited.has(key)) return
    const task = byKey.get(key)
    if (!task) {
      issues.add(`Нет карточки: ${key}`)
      return
    }
    visiting.add(key)
    for (const id of task.dependencies) {
      const local = byKey.get(`${task.plan}--${id}`)
      const candidates = byId.get(id) ?? []
      const dependency = local ?? (candidates.length === 1 ? candidates[0] : undefined)
      if (dependency) visit(dependency.key)
      else issues.add(`Не найдена однозначная зависимость ${id} для ${task.id}`)
    }
    visiting.delete(key)
    visited.add(key)
    resolved.push(task)
  }
  for (const key of keys) visit(key)
  return { tasks: resolved, issues: [...issues] }
}

/** Счётчик шага уникален; общие задачи могут быть видны в нескольких карточках, но не умножают прогресс. */
export function releaseRoadmap(tasks: PlanTask[], pilotKeys: readonly string[], pilotIssue = '') {
  let previousAccepted = true
  return roadmapStages(tasks, pilotKeys).map((stage) => {
    const cards = stage.cards.map((entry) => {
      const closure = roadmapClosure(entry.keys, tasks)
      if (stage.id === 'foundation' && pilotIssue) closure.issues.push(pilotIssue)
      const own = closure.tasks.filter((task) => entry.keys.includes(task.key))
      return {
        ...entry,
        ...closure,
        ownDone: own.filter((task) => task.status === 'done').length,
        ownTotal: new Set(entry.keys).size,
        done: closure.tasks.filter((task) => task.status === 'done').length,
      }
    })
    const closure = roadmapClosure(
      stage.cards.flatMap((entry) => entry.keys),
      tasks
    )
    if (stage.id === 'foundation' && pilotIssue) closure.issues.push(pilotIssue)
    const done = closure.tasks.filter((task) => task.status === 'done').length
    const complete =
      !closure.issues.length && closure.tasks.length > 0 && done === closure.tasks.length
    const accepted = previousAccepted && complete
    const waitingPrevious = !previousAccepted
    previousAccepted = accepted
    return { ...stage, cards, ...closure, done, accepted, waitingPrevious }
  })
}
