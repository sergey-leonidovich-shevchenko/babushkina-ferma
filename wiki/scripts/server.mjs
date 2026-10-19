import { createServer } from 'node:http'
import { readFile, realpath, stat, mkdir, writeFile } from 'node:fs/promises'
import { resolve, join, sep, extname } from 'node:path'
import { fileURLToPath } from 'node:url'
import { createHash } from 'node:crypto'
import { projectRoot, wikiRoot } from './runtime.mjs'
import { createPlanningApi } from './planning-api.mjs'

export const identity = createHash('sha256').update(projectRoot).digest('hex')
const mime = {
  '.html': 'text/html; charset=utf-8',
  '.js': 'text/javascript; charset=utf-8',
  '.css': 'text/css; charset=utf-8',
  '.json': 'application/json; charset=utf-8',
  '.svg': 'image/svg+xml',
  '.png': 'image/png',
  '.jpg': 'image/jpeg',
  '.webp': 'image/webp',
  '.mp4': 'video/mp4',
  '.ttf': 'font/ttf',
  '.woff2': 'font/woff2',
  '.txt': 'text/plain; charset=utf-8',
}

/** Разрешает только файлы сборки, включая проверку ссылок и закодированных попыток выхода из папки. */
export async function resolveAsset(root, pathname) {
  let decoded
  try {
    decoded = decodeURIComponent(pathname)
  } catch {
    return { error: 400 }
  }
  if (decoded.includes('\0') || decoded.includes('\\')) return { error: 400 }
  const file = resolve(root, `.${decoded === '/' ? '/index.html' : decoded}`)
  if (!file.startsWith(`${resolve(root)}${sep}`)) return { error: 403 }
  try {
    const actual = await realpath(file)
    const base = await realpath(root)
    if (!actual.startsWith(`${base}${sep}`)) return { error: 403 }
    const info = await stat(actual)
    return info.isFile() ? { file: actual, info } : { error: 404 }
  } catch {
    return { error: 404 }
  }
}

/** Создаёт локальную wiki с отдельным редакционным API без доступа к игровым слотам. */
export function createWikiServer(root, { project = identity, token = '', planning, allowSameOriginFrames = false } = {}) {
  const planningApi = planning === false ? undefined : createPlanningApi(planning)
  const server = createServer(async (request, response) => {
    response.setHeader('X-Content-Type-Options', 'nosniff')
    response.setHeader('X-Frame-Options', allowSameOriginFrames ? 'SAMEORIGIN' : 'DENY')
    response.setHeader('Referrer-Policy', 'no-referrer')
    const pathname = new URL(request.url ?? '/', 'http://127.0.0.1').pathname
    if (pathname === '/__wiki/status' && request.method === 'GET') {
      response.setHeader('Content-Type', mime['.json'])
      response.setHeader('Cache-Control', 'no-store')
      response.end(
        JSON.stringify({
          app: 'moon-valley-wiki',
          project,
          pid: process.pid,
          planning: planningApi ? 1 : 0,
        })
      )
      return
    }
    if (pathname === '/__wiki/stop') {
      if (request.method !== 'POST' || !token || request.headers['x-wiki-token'] !== token) {
        response.writeHead(403)
        response.end()
        return
      }
      response.writeHead(204)
      response.end()
      server.close()
      server.closeIdleConnections()
      return
    }
    if (planningApi && (await planningApi(request, response, pathname))) return
    if (!['GET', 'HEAD'].includes(request.method ?? '')) {
      response.writeHead(405)
      response.end()
      return
    }
    const result = await resolveAsset(root, pathname)
    if (result.error) {
      response.writeHead(result.error)
      response.end(result.error === 404 ? 'Страница не найдена' : 'Недопустимый адрес')
      return
    }
    try {
      const type = extname(result.file).toLowerCase()
      const bytes = await readFile(result.file)
      response.setHeader('Content-Type', mime[type] ?? 'application/octet-stream')
      response.setHeader('Content-Length', bytes.byteLength)
      response.setHeader(
        'Cache-Control',
        /\/(?:assets|generated\/sprites)\//.test(pathname)
          ? 'public, max-age=31536000, immutable'
          : 'no-cache'
      )
      response.writeHead(200)
      response.end(request.method === 'HEAD' ? undefined : bytes)
    } catch {
      response.writeHead(503)
      response.end('Обновляем wiki. Попробуйте ещё раз.')
    }
  })
  return server
}

/** Ищет свободный локальный порт, не останавливая и не заменяя чужие приложения. */
export async function listen(server, requested = 4174) {
  for (let port = requested; port <= requested + 20; port++) {
    try {
      await new Promise((accept, reject) => {
        server.once('error', reject)
        server.listen(port, '127.0.0.1', () => {
          server.removeListener('error', reject)
          accept()
        })
      })
      return server.address().port
    } catch (error) {
      if (error.code !== 'EADDRINUSE') throw error
    }
  }
  throw new Error('Не удалось найти свободный локальный порт wiki')
}

/** Запускает отдельный сервер и сохраняет защищённую запись для повторного запуска и остановки. */
async function main() {
  const token = process.env.WIKI_STOP_TOKEN ?? ''
  const server = createWikiServer(join(wikiRoot, 'dist'), { token })
  const port = await listen(server, Number(process.env.WIKI_PORT ?? 4174))
  await mkdir(join(wikiRoot, '.cache'), { recursive: true, mode: 0o700 })
  await writeFile(
    join(wikiRoot, '.cache/server.json'),
    JSON.stringify({ app: 'moon-valley-wiki', project: identity, port, pid: process.pid, token }),
    { mode: 0o600 }
  )
  console.log(`WIKI SERVER: http://127.0.0.1:${port}/`)
}
if (process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url))
  main().catch((error) => {
    console.error(error.message)
    process.exitCode = 1
  })
