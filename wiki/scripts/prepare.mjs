import { readFile, writeFile, mkdir, rm, rename, copyFile } from 'node:fs/promises'
import { createHash } from 'node:crypto'
import { basename, dirname, extname, join, relative, resolve, sep } from 'node:path'
import { fileURLToPath } from 'node:url'
import MarkdownIt from 'markdown-it'
import { wikiRoot, projectRoot, godotBinary, run } from './runtime.mjs'
import { articles } from './articles.mjs'
import { reportAttachment, reportVideo } from './report-attachment.mjs'
import { readRolloutQueues, developmentLink } from './rollout-queues.mjs'
import { readPlanningCatalog } from './planning-catalog.mjs'
import { createPlanningStore } from './planning-store.mjs'

/** Создаёт устойчивый адрес статьи по русскому заголовку. */
export function slug(text) {
  return text
    .normalize('NFKD')
    .toLowerCase()
    .replace(/ё/g, 'е')
    .replace(/\p{M}/gu, '')
    .replace(/[^\p{L}\p{N}]+/gu, '-')
    .replace(/^-|-$/g, '')
}

/** Делит руководство на самостоятельные главы, чтобы полнотекстовый поиск открывал нужное место. */
export function chapters(markdown, prefix, source) {
  const blocks = markdown.replace(/\r\n/g, '\n').split(/^## /m).slice(1)
  const seen = new Map()
  return blocks.map((block) => {
    const newline = block.indexOf('\n')
    const title = block.slice(0, newline).trim()
    const text = block.slice(newline + 1).trim()
    const base = `${prefix}-${slug(title)}`
    const repeat = seen.get(base) ?? 0
    seen.set(base, repeat + 1)
    return {
      category: 'guides',
      id: repeat ? `${base}-${repeat}` : base,
      title,
      summary: text
        .replace(/!\[[^\]]*\]\([^)]*\)/g, '')
        .replace(/\[([^\]]+)\]\([^)]*\)/g, '$1')
        .replace(/[#*`>|]/g, '')
        .slice(0, 210)
        .trim(),
      markdown: text,
      tags: [prefix === 'controls' ? 'Управление' : 'Руководство'],
      facts: [],
      sections: [],
      relations: [],
      ingredients: [],
      yields: [],
      source,
    }
  })
}

/** Копирует только явно указанные локальные иллюстрации, сохраняя их происхождение и контрольную сумму. */
async function illustration(path, destination) {
  const absolute = resolve(path)
  if (!absolute.startsWith(`${projectRoot}${sep}`))
    throw new Error('Иллюстрация выходит за папку игры')
  const bytes = await readFile(absolute)
  const name = `${createHash('sha256').update(bytes).digest('hex').slice(0, 24)}${extname(absolute)}`
  await mkdir(join(destination, 'illustrations'), { recursive: true })
  await writeFile(join(destination, 'illustrations', name), bytes)
  return `generated/illustrations/${name}`
}

/** Обогащает главы безопасным HTML и заменяет внутренние ссылки адресами wiki. */
async function renderGuides(entries, destination, planning, queues) {
  const md = new MarkdownIt({ html: false, linkify: true, typographer: true })
  for (const entry of entries.filter((value) => value.markdown)) {
    const tokens = md.parse(entry.markdown, {})
    const rewrite = async (list) => {
      for (const token of list) {
        if (token.children) await rewrite(token.children)
        if (token.type === 'image') {
          const source = token.attrGet('src') ?? ''
          if (/^https?:/i.test(source)) {
            token.attrSet('src', 'wiki-icon.svg')
            continue
          }
          if (/\.mp4$/i.test(source)) {
            const media = await reportAttachment(
              resolve(projectRoot, dirname(entry.source), source), destination, projectRoot
            )
            token.type = 'html_inline'
            token.content = reportVideo(media, token.content || 'Диагностическое видео')
            token.children = null
            continue
          }
          token.attrSet(
            'src',
            await illustration(resolve(projectRoot, dirname(entry.source), source), destination)
          )
          token.attrSet('loading', 'lazy')
        }
        if (token.type === 'link_open') {
          const href = token.attrGet('href') ?? ''
          const internal = developmentLink(href, planning, queues)
          if (internal) {
            token.attrSet('href', internal)
            continue
          }
          if (/^https?:/i.test(href)) {
            token.attrSet('target', '_blank')
            token.attrSet('rel', 'noopener noreferrer')
            continue
          }
          if (href.startsWith('#')) {
            token.attrSet('href', `#/guides/${encodeURIComponent(entry.id)}`)
            continue
          }
          const target = basename(href.split('#')[0])
          if (
            /\.(csv|json)$/i.test(target) &&
            resolve(projectRoot, dirname(entry.source), href.split('#')[0]).startsWith(
              `${resolve(projectRoot, 'docs/reports')}${sep}`
            )
          ) {
            token.attrSet(
              'href',
              await reportAttachment(
                resolve(projectRoot, dirname(entry.source), href.split('#')[0]),
                destination,
                projectRoot
              )
            )
            token.attrSet('download', target)
            continue
          }
          const resolved = relative(
            projectRoot,
            resolve(projectRoot, dirname(entry.source), href.split('#')[0])
          )
            .split(sep)
            .join('/')
          const found =
            entries.find((value) => value.category === 'guides' && value.source === resolved) ??
            entries.find(
              (value) => value.category === 'guides' && basename(value.source) === target
            )
          token.attrSet(
            'href',
            found
              ? `#/guides/${encodeURIComponent(found.id)}`
              : `#/search?q=${encodeURIComponent(target.replace(/\.[^.]+$/, '').replace(/[-_]/g, ' '))}`
          )
        }
      }
    }
    await rewrite(tokens)
    entry.html = md.renderer.render(tokens, md.options, {})
    delete entry.markdown
  }
}

/** Проверяет полноту каталогов и все материальные, маршрутные и спрайтовые ссылки до публикации сборки. */
export function validateCatalog(catalog) {
  const keys = new Set()
  const counts = {}
  for (const entry of catalog.entries) {
    const key = `${entry.category}/${entry.id}`
    if (keys.has(key)) throw new Error(`Повторная статья: ${key}`)
    if (!entry.title?.trim() || !entry.summary?.trim()) throw new Error(`Пустое описание: ${key}`)
    keys.add(key)
    counts[entry.category] = (counts[entry.category] ?? 0) + 1
  }
  for (const type of ['items', 'craft'])
    if (counts[type] !== catalog.coverage[type]) throw new Error(`Неполный каталог ${type}`)
  if (
    catalog.entries.filter(
      (entry) =>
        entry.category === 'characters' && entry.source === 'scripts/systems/quest_system.gd'
    ).length !== catalog.coverage.npcs
  )
    throw new Error('Неполный каталог жителей')
  for (const entry of catalog.entries) {
    for (const relation of entry.relations)
      if (!keys.has(`${relation.category}/${relation.id}`))
        throw new Error(
          `Отсутствует связанная статья: ${entry.id} → ${relation.category}/${relation.id}`
        )
    for (const part of [
      ...entry.ingredients,
      ...entry.yields,
      ...(entry.byproducts ?? []),
      ...(entry.salvage ?? []),
    ])
      if (
        part.id !== 'coins' &&
        (!keys.has(`items/${part.id}`) || !Number.isFinite(part.count) || part.count <= 0)
      )
        throw new Error(`Неверный материал: ${entry.id} → ${part.id}`)
    const frames = [
      ...(entry.icon ? [entry.icon] : []),
      ...(entry.animation?.clips.flatMap((clip) => Object.values(clip.frames).flat()) ?? []),
    ]
    if (entry.category === 'characters' && !entry.animation?.clips.length)
      throw new Error(`Нет просмотра персонажа: ${entry.id}`)
    for (const clip of entry.animation?.clips ?? [])
      if (
        !Object.keys(clip.frames).length ||
        Object.values(clip.frames).some((value) => !value.length) ||
        !Number.isFinite(clip.fps) ||
        clip.fps <= 0
      )
        throw new Error(`Пустая анимация: ${entry.id}/${clip.id}`)
    for (const frame of frames) {
      const size = catalog.images[frame.image]
      if (
        !size ||
        frame.rect.some((value) => !Number.isFinite(value)) ||
        frame.pivot.some((value) => !Number.isFinite(value)) ||
        !Number.isFinite(frame.scale) ||
        frame.scale <= 0
      )
        throw new Error(`Неверный кадр: ${entry.id}`)
      const [x, y, width, height] = frame.rect
      if (
        x < 0 ||
        y < 0 ||
        width <= 0 ||
        height <= 0 ||
        x + width > size[0] ||
        y + height > size[1]
      )
        throw new Error(`Кадр выходит за атлас: ${entry.id}`)
    }
  }
  return counts
}

/** Собирает актуальный справочник из игры и заменяет предыдущий каталог только после всех проверок. */
export async function prepare() {
  const destination = join(wikiRoot, '.cache', `export-${process.pid}`)
  const published = join(wikiRoot, 'public/generated')
  const backup = join(wikiRoot, '.cache', `generated-backup-${process.pid}`)
  await rm(destination, { recursive: true, force: true })
  await mkdir(destination, { recursive: true })
  try {
    const godot = await godotBinary()
    await run(godot, ['--headless', '--editor', '--path', projectRoot, '--quit'], {
      cwd: projectRoot,
      engine: true,
      quiet: true,
    })
    const output = await run(
      godot,
      ['--headless', '--path', projectRoot, '--script', 'res://wiki/scripts/export_catalog.gd'],
      { cwd: projectRoot, engine: true, env: { WIKI_EXPORT_DIRECTORY: destination } }
    )
    if (!output.includes('WIKI EXPORT:')) throw new Error('Экспорт не подтвердил завершение')
    const catalog = JSON.parse(await readFile(join(destination, 'catalog.json'), 'utf8'))
    for (const [path, prefix] of [
      ['docs/GAME_GUIDE.md', 'game'],
      ['docs/CONTROLS.md', 'controls'],
      ['wiki/README.md', 'wiki'],
      ['docs/WIKI_DEVELOPMENT.md', 'development'],
    ])
      catalog.entries.push(
        ...chapters(await readFile(join(projectRoot, path), 'utf8'), prefix, path)
      )
    catalog.entries.push(...(await articles()))
    const planning = await readPlanningCatalog()
    catalog.rolloutQueues = await readRolloutQueues(
      projectRoot,
      join(wikiRoot, 'planning/sources.json'),
      planning
    )
    await renderGuides(catalog.entries, destination, planning, catalog.rolloutQueues)
    const counts = validateCatalog(catalog)
    catalog.meta = {
      version: (await readFile(join(projectRoot, 'VERSION'), 'utf8')).trim(),
      counts,
    }
    catalog.cover = await illustration(
      join(projectRoot, 'docs/reports/village-regions-2026-10-13-overworld-gameplay.png'),
      destination
    )
    await mkdir(join(destination, 'fonts'), { recursive: true })
    await copyFile(
      join(projectRoot, 'assets/game/fonts/Alice-Regular.ttf'),
      join(destination, 'fonts/Alice-Regular.ttf')
    )
    await copyFile(
      join(projectRoot, 'assets/game/fonts/Alice-OFL.txt'),
      join(destination, 'fonts/Alice-OFL.txt')
    )
    await writeFile(join(destination, 'catalog.json'), JSON.stringify(catalog))
    const workspace = await createPlanningStore().read(planning)
    await writeFile(
      join(destination, 'planning.json'),
      JSON.stringify({
        schema: 1,
        catalog: planning,
        workspace,
        readOnly: true,
      })
    )
    try {
      await rename(published, backup)
    } catch (error) {
      if (error.code !== 'ENOENT') throw error
    }
    try {
      await rename(destination, published)
    } catch (error) {
      try {
        await rename(backup, published)
      } catch {
        /* Сохраняем первоначальную ошибку. */
      }
      throw error
    }
    await rm(backup, { recursive: true, force: true })
    console.log(
      `WIKI CONTENT: ${catalog.entries.length} articles; ${Object.entries(counts)
        .map(([key, count]) => `${key}=${count}`)
        .join(', ')}`
    )
    return catalog
  } finally {
    await rm(destination, { recursive: true, force: true })
  }
}

if (process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url))
  prepare().catch((error) => {
    console.error(error.message)
    process.exitCode = 1
  })
