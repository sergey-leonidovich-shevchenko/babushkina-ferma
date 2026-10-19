import { createHash } from 'node:crypto'
import { readFile, realpath, mkdir, writeFile, stat } from 'node:fs/promises'
import { resolve, sep, extname, join } from 'node:path'

/** Публикует небольшие CSV/JSON и диагностические MP4 из отчётов, исключая выход из каталога. */
export async function reportAttachment(path, destination, projectRoot) {
  const boundary = await realpath(resolve(projectRoot, 'docs/reports'))
  if (!boundary.startsWith(`${await realpath(projectRoot)}${sep}`))
    throw new Error('Вложение должно быть CSV/JSON/MP4 внутри docs/reports')
  const absolute = await realpath(path)
  const extension = extname(absolute).toLowerCase()
  if (!absolute.startsWith(`${boundary}${sep}`) || !['.csv', '.json', '.mp4'].includes(extension))
    throw new Error('Вложение должно быть CSV/JSON/MP4 внутри docs/reports')
  if ((await stat(absolute)).size > 8 * 1024 * 1024)
    throw new Error('Вложение отчёта превышает 8 MiB')
  const bytes = await readFile(absolute)
  if (extension === '.mp4' && bytes.subarray(4, 8).toString('ascii') !== 'ftyp')
    throw new Error('У диагностического видео отсутствует сигнатура MP4')
  const name = `${createHash('sha256').update(bytes).digest('hex')}${extension}`
  await mkdir(join(destination, 'attachments'), { recursive: true })
  await writeFile(join(destination, 'attachments', name), bytes)
  return `generated/attachments/${name}`
}

/** Создаёт управляемый пользователем плеер только для уже опубликованного локального отчёта. */
export function reportVideo(source, label) {
  if (!/^generated\/attachments\/[a-f0-9]{64}\.mp4$/.test(source))
    throw new Error('Видео должно ссылаться на опубликованное вложение отчёта')
  const escaped = String(label).replace(/[&<>"']/g, (value) => ({
    '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;',
  })[value])
  return `<video controls playsinline preload="metadata" aria-label="${escaped}"><source src="${source}" type="video/mp4"></video>`
}
