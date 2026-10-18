import { createHash } from 'node:crypto'
import { readFile, realpath, mkdir, writeFile, stat } from 'node:fs/promises'
import { resolve, sep, extname, join } from 'node:path'

/** Публикует только небольшие CSV/JSON из отчётов проекта, исключая ссылки за пределы каталога. */
export async function reportAttachment(path, destination, projectRoot) {
  const boundary = await realpath(resolve(projectRoot, 'docs/reports'))
  if (!boundary.startsWith(`${await realpath(projectRoot)}${sep}`))
    throw new Error('Вложение должно быть CSV/JSON внутри docs/reports')
  const absolute = await realpath(path)
  const extension = extname(absolute).toLowerCase()
  if (!absolute.startsWith(`${boundary}${sep}`) || !['.csv', '.json'].includes(extension))
    throw new Error('Вложение должно быть CSV/JSON внутри docs/reports')
  if ((await stat(absolute)).size > 8 * 1024 * 1024)
    throw new Error('Вложение отчёта превышает 8 MiB')
  const bytes = await readFile(absolute)
  const name = `${createHash('sha256').update(bytes).digest('hex')}${extension}`
  await mkdir(join(destination, 'attachments'), { recursive: true })
  await writeFile(join(destination, 'attachments', name), bytes)
  return `generated/attachments/${name}`
}
