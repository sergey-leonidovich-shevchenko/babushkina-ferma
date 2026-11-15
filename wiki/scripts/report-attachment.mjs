import { createHash } from 'node:crypto'
import { readFile, realpath, mkdir, writeFile, stat } from 'node:fs/promises'
import { resolve, sep, extname, join, dirname } from 'node:path'
import { isDeepStrictEqual } from 'node:util'

const maxReportSize = 8 * 1024 * 1024
const pngSignature = Buffer.from('89504e470d0a1a0a0000000d49484452', 'hex')

async function publishAttachment(bytes, name, destination) {
  if (destination) {
    await mkdir(join(destination, 'attachments'), { recursive: true })
    await writeFile(join(destination, 'attachments', name), bytes)
  }
  return `generated/attachments/${name}`
}

/** Публикует небольшие CSV/JSON и диагностические MP4 из отчётов, исключая выход из каталога. */
export async function reportAttachment(path, destination, projectRoot) {
  const boundary = await realpath(resolve(projectRoot, 'docs/reports'))
  if (!boundary.startsWith(`${await realpath(projectRoot)}${sep}`))
    throw new Error('Вложение должно быть CSV/JSON/MP4 внутри docs/reports')
  const absolute = await realpath(path)
  const extension = extname(absolute).toLowerCase()
  if (!absolute.startsWith(`${boundary}${sep}`) || !['.csv', '.json', '.mp4'].includes(extension))
    throw new Error('Вложение должно быть CSV/JSON/MP4 внутри docs/reports')
  if ((await stat(absolute)).size > maxReportSize)
    throw new Error('Вложение отчёта превышает 8 MiB')
  const bytes = await readFile(absolute)
  if (extension === '.mp4' && bytes.subarray(4, 8).toString('ascii') !== 'ftyp')
    throw new Error('У диагностического видео отсутствует сигнатура MP4')
  const name = `${createHash('sha256').update(bytes).digest('hex')}${extension}`
  return publishAttachment(bytes, name, destination)
}

async function nativeFile(boundary, path) {
  const absolute = await realpath(path)
  if (!absolute.startsWith(`${boundary}${sep}`)) return
  const file = await stat(absolute)
  if (file.isFile() && file.size <= maxReportSize) return absolute
}

async function nativeCapture(boundary, path) {
  const file = await nativeFile(boundary, path)
  if (file) return readFile(file)
}

/** Публикует оба исходных кадра одного проверенного случая или пропускает всю пару. */
export async function reportComparison(reference, projectRoot, { destination, published } = {}) {
  const { manifest, case: caseId, label } = reference ?? {}
  if (
    typeof manifest !== 'string' ||
    !manifest.startsWith('docs/reports/') ||
    !manifest.endsWith('.json') ||
    typeof caseId !== 'string' ||
    !/^[a-z0-9]+(?:-[a-z0-9]+)*$/.test(caseId) ||
    typeof label !== 'string' ||
    !label.trim()
  )
    return

  const boundary = await realpath(resolve(projectRoot, 'docs/reports')).catch(() => undefined)
  if (!boundary?.startsWith(`${await realpath(projectRoot)}${sep}`)) return
  const manifestPath = resolve(projectRoot, manifest)
  const keys = [`${caseId}-before`, `${caseId}-after`]
  try {
    const raw = await nativeCapture(boundary, manifestPath)
    if (!raw) return
    const { captures, pairs } = JSON.parse(raw) ?? {}
    const [before, after] = keys.map((key) => captures?.[key])
    const pair = pairs?.[caseId]
    if (
      !before ||
      !after ||
      pair?.other_pixels_equal !== true ||
      typeof before.location !== 'string' ||
      before.location !== after.location ||
      !Number.isFinite(before.scale) ||
      before.scale !== after.scale ||
      !Array.isArray(before.camera) ||
      !isDeepStrictEqual(before.camera, after.camera) ||
      !isDeepStrictEqual(before.camera, pair.camera) ||
      !before.owner ||
      !isDeepStrictEqual(before.owner, after.owner) ||
      before.png === after.png
    )
      return

    const digests = [before.png, after.png]
    const bytes = await Promise.all(
      keys.map((key) => nativeCapture(boundary, join(dirname(manifestPath), `${key}.png`)))
    )
    if (
      !bytes.every(
        (data, index) =>
          data?.length >= 24 &&
          data.subarray(0, pngSignature.length).equals(pngSignature) &&
          createHash('sha256').update(data).digest('hex') === digests[index]
      )
    )
      return
    const [beforeSize, afterSize] = bytes.map((data) => [
      data.readUInt32BE(16),
      data.readUInt32BE(20),
    ])
    if (!isDeepStrictEqual(beforeSize, afterSize) || beforeSize.includes(0)) return
    const [width, height] = beforeSize
    const [beforeUrl, afterUrl] = await Promise.all(
      bytes.map((data, i) => publishAttachment(data, `${digests[i]}.png`, destination))
    )
    if (published) {
      const publicRoot = await realpath(published)
      const publishedFiles = await Promise.all(
        [beforeUrl, afterUrl].map((url) => nativeFile(publicRoot, join(publicRoot, url)))
      )
      if (publishedFiles.some((file) => !file)) return
    }
    return { label, before: beforeUrl, after: afterUrl, width, height }
  } catch (error) {
    if (error instanceof SyntaxError || ['ENOENT', 'ENOTDIR', 'ELOOP'].includes(error.code)) return
    throw error
  }
}

/** Создаёт управляемый пользователем плеер только для уже опубликованного локального отчёта. */
export function reportVideo(source, label) {
  if (!/^generated\/attachments\/[a-f0-9]{64}\.mp4$/.test(source))
    throw new Error('Видео должно ссылаться на опубликованное вложение отчёта')
  const escaped = String(label).replace(
    /[&<>"']/g,
    (value) =>
      ({
        '&': '&amp;',
        '<': '&lt;',
        '>': '&gt;',
        '"': '&quot;',
        "'": '&#39;',
      })[value]
  )
  return `<video controls playsinline preload="metadata" aria-label="${escaped}"><source src="${source}" type="video/mp4"></video>`
}
