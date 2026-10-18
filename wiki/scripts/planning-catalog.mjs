import { readFile, realpath, readdir } from 'node:fs/promises'
import { resolve, join, sep } from 'node:path'
import { projectRoot, wikiRoot } from './runtime.mjs'

export const taskStatuses = ['backlog', 'ready', 'blocked', 'in_progress', 'done']
const idPattern = /\b[A-Z][A-Z0-9]*(?:-[A-Z0-9]+)+\b/g

/** Разрешает только существующий источник внутри репозитория, включая символьные ссылки. */
export async function sourcePath(root, path) {
  const base = await realpath(root)
  const file = await realpath(resolve(root, path))
  if (!file.startsWith(`${base}${sep}`)) throw new Error('Источник плана выходит за проект')
  return file
}

/** Убирает служебную разметку, сохраняя текст ссылок, символы условий и числа. */
export function plain(value = '') {
  return String(value)
    .replace(/\[([^\]]+)\]\([^)]*\)/g, '$1')
    .replace(/\*\*([^*]+)\*\*/g, '$1')
    .replace(/`([^`]+)`/g, '$1')
    .replace(/<a\s[^>]*><\/a>/g, '')
    .trim()
}

/** Извлекает поля редакционных карточек без превращения таблицы-указателя в задачи. */
function fields(body) {
  const matches = [...body.matchAll(/^\*\*([^*\n]+)\*\*\s*/gm)]
  return Object.fromEntries(
    matches.map((match, index) => [
      match[1].replace(/:$/, ''),
      body.slice(match.index + match[0].length, matches[index + 1]?.index ?? body.length).trim(),
    ])
  )
}

/** Приводит список критериев к читаемым пунктам, не меняя отметок исходного плана. */
function bullets(text = '') {
  return text
    .split('\n')
    .filter((line) => /^\s*[-*]\s+/.test(line))
    .map((line) => plain(line.replace(/^\s*[-*]\s+(?:\[[ xX]\]\s*)?/, '')))
}

/** Читает только явно оформленные карточки с ID, результатом и собственным статусом. */
export function markdownTasks(markdown, epic, plan) {
  const headings = [
    ...markdown.matchAll(/^#{2,3} ([A-Z][A-Z0-9]*(?:-[A-Z0-9]+)+)\s+[—–-]\s+(.+)$/gm),
  ]
  return headings.map((heading, index) => {
    const id = heading[1]
    const body = markdown.slice(
      heading.index + heading[0].length,
      headings[index + 1]?.index ?? markdown.length
    )
    const values = fields(body)
    const table = markdown
      .split('\n')
      .find(
        (line) =>
          line.startsWith('|') && new RegExp(`^\\|\\s*(?:\\[)?${id}(?:\\]|\\s|\\|)`).test(line)
      )
    const columns = table?.split('|').slice(1, -1).map(plain) ?? []
    const statusColumn = columns.findIndex((value) => taskStatuses.includes(value))
    const bodyStatus = body.match(
      /Статус:\*{0,2}\s*`?(backlog|ready|blocked|in_progress|done)\b/i
    )?.[1]
    const tableStatus = columns[statusColumn]
    if (bodyStatus && tableStatus && bodyStatus !== tableStatus)
      throw new Error(`Статусы карточки и указателя расходятся: ${id}`)
    const status = bodyStatus ?? tableStatus
    if (!status) throw new Error(`У карточки ${id} нет явного статуса`)
    const goal = values['Результат и объём'] ?? values['Задача'] ?? values['Делаем'] ?? ''
    const dependencyText =
      values['Внутренние блокеры'] ?? (statusColumn >= 0 ? columns[statusColumn + 1] : '') ?? ''
    const dependencies = [
      ...new Set([
        ...(dependencyText.match(idPattern) ?? []),
        ...(plan.id === 'water'
          ? [...dependencyText.matchAll(/\b(\d{2})\b/g)].map((match) => `WATER-${match[1]}`)
          : []),
      ]),
    ]
    return {
      key: `${plan.id}--${id}`,
      id,
      title: plain(heading[2]),
      plan: plan.id,
      epic: epic.key,
      status: status.toLowerCase(),
      priority: body.match(/Приоритет:\*{0,2}\s*(P[0-3])/)?.[1] ?? '',
      size:
        body.match(/Объём:\*{0,2}\s*([SML])\b/)?.[1] ??
        (/^[SML]$/.test(columns[statusColumn - 1]) ? columns[statusColumn - 1] : ''),
      goal: plain(goal),
      acceptance: bullets(values['Приёмка']),
      dependencies,
      result: plain(
        values['Подтверждения / результат'] ?? (status === 'done' ? values['Проверки'] : '') ?? ''
      ),
      sections: Object.entries(values)
        .filter(
          ([label]) =>
            ![
              'Статус',
              'Приёмка',
              'Результат и объём',
              'Задача',
              'Делаем',
              'Внутренние блокеры',
              'Подтверждения / результат',
            ].includes(label)
        )
        .map(([title, text]) => ({ title, text: plain(text) }))
        .concat(dependencyText ? [{ title: 'Условия из плана', text: plain(dependencyText) }] : []),
      source: epic.source,
      content: `## ${id} — ${heading[2]}\n${body}`,
    }
  })
}

/** Приводит две существующие схемы JSON к одному виду, не записывая их обратно. */
function jsonTask(task, plan) {
  if (!taskStatuses.includes(task.status)) throw new Error(`Неизвестный статус ${task.id}`)
  return {
    key: `${plan.id}--${task.id}`,
    id: task.id,
    title: task.title,
    plan: plan.id,
    epic: `${plan.id}--${task.epic}`,
    status: task.status,
    priority: task.priority ?? '',
    size: task.size ?? task.estimate ?? '',
    goal: task.outcome ?? task.goal ?? '',
    acceptance: task.acceptance ?? [],
    dependencies: task.dependencies ?? task.depends_on ?? [],
    result: [task.result, ...(task.evidence ?? [])].filter(Boolean).join('\n'),
    sections: [
      ['scope', 'Объём'],
      ['verification', 'Проверка'],
      ['needs', 'Внешние условия'],
      ['risk', 'Риск'],
      ['rollback', 'Восстановление'],
      ['baseline', 'Исходное состояние'],
    ]
      .filter(([key]) => task[key]?.length)
      .map(([key, title]) => ({
        title,
        text: Array.isArray(task[key]) ? task[key].join('\n') : String(task[key]),
      })),
    source: plan.file,
    content: JSON.stringify(task, null, 2),
  }
}

/** Читает необязательный источник, не скрывая повреждённый файл или выход из проекта. */
async function optionalSource(root, file) {
  try {
    return await readFile(await sourcePath(root, file), 'utf8')
  } catch (error) {
    if (error.code === 'ENOENT') return undefined
    throw error
  }
}

/** Подключает новые стандартные планы, чтобы параллельная постановка сразу появлялась в Wiki. */
async function discoverPlans(root, registered) {
  const extra = []
  for (const parent of ['docs/epics', 'docs/backlog']) {
    let directories
    try {
      directories = await readdir(await sourcePath(root, parent), { withFileTypes: true })
    } catch (error) {
      if (error.code === 'ENOENT') continue
      throw error
    }
    for (const directory of directories
      .filter((item) => item.isDirectory())
      .sort((a, b) => a.name.localeCompare(b.name))) {
      const prefix = `${parent}/${directory.name}/`
      if (
        registered.some(
          (plan) =>
            plan.file?.startsWith(prefix) ||
            plan.directory?.startsWith(prefix) ||
            plan.epics?.some((epic) => epic.file.startsWith(prefix))
        )
      )
        continue
      const file = `${prefix}backlog.json`
      const json = await optionalSource(root, file)
      const markdown = await optionalSource(root, `${prefix}TASKS.md`)
      const readme = await optionalSource(root, `${prefix}README.md`)
      const id = directory.name.replace(/-\d{4}-\d{2}$/, '')
      const title = plain((readme ?? markdown ?? id).split('\n')[0].replace(/^#+\s*/, ''))
      if (json) {
        const data = JSON.parse(json)
        if (Array.isArray(data.tasks) && Array.isArray(data.epics))
          extra.push({ id, title, format: 'json', file, group: 'gameplay', discovered: true })
      } else if (markdown) {
        const first = markdown.match(/^#{2,3} ([A-Z][A-Z0-9]*(?:-[A-Z0-9]+)+)\s+[—–-]/m)
        if (first)
          extra.push({
            id,
            title,
            format: 'markdown',
            group: 'gameplay',
            discovered: true,
            epics: [{ id: first[1].replace(/-[^-]+$/, ''), title, file: `${prefix}TASKS.md` }],
          })
      }
    }
  }
  return extra
}

/** Собирает фактические эпики и задачи всех зарегистрированных планов в одном каталоге. */
export async function readPlanningCatalog({
  root = projectRoot,
  manifest = join(wikiRoot, 'planning/sources.json'),
} = {}) {
  const config = JSON.parse(await readFile(manifest, 'utf8'))
  if (config.schema !== 1 || !Array.isArray(config.plans))
    throw new Error('Неизвестный реестр планов')
  const definitions = config.discoverPlans
    ? [...config.plans, ...(await discoverPlans(root, config.plans))]
    : config.plans
  const plans = [],
    epics = [],
    tasks = []
  for (const plan of definitions) {
    const start = tasks.length
    plans.push({ id: plan.id, title: plan.title })
    if (plan.format === 'json') {
      const source = JSON.parse(await readFile(await sourcePath(root, plan.file), 'utf8'))
      epics.push(
        ...source.epics.map((epic) => ({
          key: `${plan.id}--${epic.id}`,
          id: epic.id,
          title: epic.title,
          goal: epic.goal ?? '',
          plan: plan.id,
          group: plan.group,
          source: plan.file,
        }))
      )
      tasks.push(...source.tasks.map((task) => jsonTask(task, plan)))
    } else if (['markdown', 'markdown-directory'].includes(plan.format)) {
      let definitions = plan.epics
      if (plan.format === 'markdown-directory') {
        const directory = await sourcePath(root, plan.directory)
        definitions = await Promise.all(
          (await readdir(directory))
            .filter((file) => /^\d+.*\.md$/.test(file))
            .sort()
            .map(async (file) => {
              const source = `${plan.directory}/${file}`
              const text = await readFile(await sourcePath(root, source), 'utf8')
              return {
                id: `${plan.epicPrefix}-${file.split('-')[0]}`,
                title: plain(text.split('\n')[0].replace(/^#+\s*/, '')),
                file: source,
              }
            })
        )
      }
      for (const definition of definitions) {
        const epic = {
          key: `${plan.id}--${definition.id}`,
          id: definition.id,
          title: definition.title,
          goal: '',
          plan: plan.id,
          group: plan.group,
          source: definition.file,
        }
        epics.push(epic)
        tasks.push(
          ...markdownTasks(
            await readFile(await sourcePath(root, definition.file), 'utf8'),
            epic,
            plan
          )
        )
      }
    } else throw new Error(`Неизвестный формат плана: ${plan.id}`)
    if (plan.expected !== undefined && tasks.length - start !== plan.expected)
      throw new Error(
        `План ${plan.id}: ожидалось ${plan.expected}, прочитано ${tasks.length - start} задач`
      )
  }
  for (const values of [
    plans.map((plan) => plan.id),
    epics.map((epic) => epic.key),
    tasks.map((task) => task.key),
  ])
    if (values.length !== new Set(values).size) throw new Error('Повтор ID в реестре разработки')
  const epicKeys = new Set(epics.map((epic) => epic.key))
  if (tasks.some((task) => !epicKeys.has(task.epic))) throw new Error('Задача без эпика')
  const articleFile = await sourcePath(root, 'wiki/articles/index.json')
  const ideaArticles = JSON.parse(await readFile(articleFile, 'utf8'))
    .filter((entry) => /^IDEA-\d+$/.test(entry.id))
    .map((entry) => ({
      id: entry.id,
      title: entry.title.replace(/^IDEA-\d+\s*[—–-]\s*/, ''),
      description: entry.summary,
      article: entry.id,
    }))
  return { plans, epics, tasks, ideaArticles }
}
