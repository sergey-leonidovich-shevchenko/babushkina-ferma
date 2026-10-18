import {
  access,
  copyFile,
  mkdir,
  open,
  readFile,
  readdir,
  rename,
  rm,
  writeFile,
} from 'node:fs/promises'
import { spawn } from 'node:child_process'
import { randomBytes } from 'node:crypto'
import { join, dirname } from 'node:path'
import { setTimeout as delay } from 'node:timers/promises'
import { wikiRoot, pnpm, run } from './runtime.mjs'
import { identity } from './server.mjs'

const cache = join(wikiRoot, '.cache')
const noOpen = process.argv.includes('--no-open') || process.env.WIKI_NO_OPEN === '1'

/** Проверяет принадлежность процесса этой wiki, а не просто занятость удобного порта. */
export async function runningServer() {
  try {
    const info = JSON.parse(await readFile(join(cache, 'server.json'), 'utf8'))
    if (
      info.project !== identity ||
      !Number.isInteger(info.port) ||
      info.port < 1 ||
      info.port > 65535
    )
      return undefined
    const response = await fetch(`http://127.0.0.1:${info.port}/__wiki/status`, {
      signal: AbortSignal.timeout(1000),
    })
    const status = await response.json()
    return status.app === 'moon-valley-wiki' && status.project === identity
      ? { ...info, planning: status.planning ?? 0 }
      : undefined
  } catch {
    return undefined
  }
}

/** Открывает готовый адрес штатным браузером, сохраняя корректность пробелов в путях и URL. */
async function openBrowser(url) {
  if (noOpen) return
  if (process.platform === 'darwin') await run('/usr/bin/open', [url], { quiet: true })
  else if (process.platform === 'win32')
    await run('rundll32.exe', ['url.dll,FileProtocolHandler', url], { quiet: true })
  else await run('xdg-open', [url], { quiet: true })
}

/** Сохраняет старые адреса спрайтов и хешированных модулей для уже открытой вкладки браузера. */
async function retainAssets(oldRoot, newRoot, prefix) {
  const from = join(oldRoot, prefix)
  const to = join(newRoot, prefix)
  let files
  try {
    files = await readdir(from, { withFileTypes: true })
  } catch {
    return
  }
  await mkdir(to, { recursive: true })
  for (const file of files) {
    if (!file.isFile()) continue
    try {
      await copyFile(join(from, file.name), join(to, file.name), 1)
    } catch (error) {
      if (error.code !== 'EEXIST') throw error
    }
  }
}

/** Подменяет сборку только после успешных проверок, оставляя прежнюю версию доступной при любой ошибке. */
export async function publishBuild(next, target = join(wikiRoot, 'dist')) {
  const backup = join(dirname(target), '.cache', `site-backup-${process.pid}`)
  await mkdir(dirname(backup), { recursive: true })
  await retainAssets(target, next, 'assets')
  await retainAssets(target, next, 'generated/sprites')
  try {
    await rename(target, backup)
  } catch (error) {
    if (error.code !== 'ENOENT') throw error
  }
  try {
    await rename(next, target)
  } catch (error) {
    try {
      await rename(backup, target)
    } catch {
      /* Сохраняем первоначальную ошибку. */
    }
    throw error
  }
  await rm(backup, { recursive: true, force: true })
}

/** Запускает сервер отдельным процессом, который продолжает работать после закрытия лаунчера. */
async function ensureServer() {
  const existing = await runningServer()
  if (existing?.planning === 1) return existing
  if (existing) {
    const response = await fetch(`http://127.0.0.1:${existing.port}/__wiki/stop`, {
      method: 'POST',
      headers: { 'x-wiki-token': existing.token },
    })
    if (!response.ok) throw new Error('Не удалось обновить локальный сервер Wiki')
    for (let attempt = 0; attempt < 30; attempt++) {
      if (!(await runningServer())) break
      await delay(100)
    }
  }
  const log = await open(join(cache, 'server.log'), 'a')
  const child = spawn(process.execPath, [join(wikiRoot, 'scripts/server.mjs')], {
    cwd: wikiRoot,
    env: { ...process.env, WIKI_STOP_TOKEN: randomBytes(32).toString('hex') },
    detached: true,
    stdio: ['ignore', log.fd, log.fd],
  })
  let startupError
  child.once('error', (error) => {
    startupError = error
  })
  child.unref()
  await log.close()
  for (let attempt = 0; attempt < 100; attempt++) {
    if (startupError) throw startupError
    const info = await runningServer()
    if (info) return info
    await delay(100)
  }
  throw new Error('Сервер wiki не подтвердил запуск. Подробности: wiki/.cache/server.log')
}

/** Исключает одновременные сборки от двойного щелчка, не удаляя блокировку живого владельца. */
async function acquireLock() {
  const path = join(cache, 'launch.lock')
  try {
    const file = await open(path, 'wx', 0o600)
    await file.writeFile(JSON.stringify({ pid: process.pid, project: identity }))
    await file.close()
    return true
  } catch (error) {
    if (error.code !== 'EEXIST') throw error
    let active = false
    try {
      const value = JSON.parse(await readFile(path, 'utf8'))
      if (value.project === identity) {
        process.kill(value.pid, 0)
        active = true
      }
    } catch {
      /* Владелец уже завершился. */
    }
    if (!active) {
      await rm(path, { force: true })
      return acquireLock()
    }
    return false
  }
}

/** Пересобирает сайт при каждом запуске и открывает браузер только после появления проверенной версии. */
async function main() {
  await mkdir(cache, { recursive: true, mode: 0o700 })
  if (process.argv.includes('--stop')) {
    const info = await runningServer()
    if (info)
      await fetch(`http://127.0.0.1:${info.port}/__wiki/stop`, {
        method: 'POST',
        headers: { 'x-wiki-token': info.token },
      })
    console.log('WIKI SERVER: stopped')
    return
  }
  if (!(await acquireLock())) {
    for (let attempt = 0; attempt < 360; attempt++) {
      await delay(500)
      try {
        await access(join(cache, 'launch.lock'))
      } catch {
        const info = await runningServer()
        if (info) {
          await openBrowser(`http://127.0.0.1:${info.port}/`)
          return
        }
        break
      }
    }
    throw new Error('Предыдущая сборка wiki ещё не завершилась или завершилась с ошибкой')
  }
  const next = join(cache, `site-${process.pid}`)
  try {
    try {
      await access(join(wikiRoot, 'node_modules/.modules.yaml'))
    } catch {
      await pnpm(['install', '--frozen-lockfile'])
    }
    const marker = join(cache, 'installed-lock.sha')
    const lock = await readFile(join(wikiRoot, 'pnpm-lock.yaml'), 'utf8')
    const checksum = (await import('node:crypto')).createHash('sha256').update(lock).digest('hex')
    let installed = ''
    try {
      installed = await readFile(marker, 'utf8')
    } catch {
      /* Первый запуск. */
    }
    if (installed !== checksum) {
      await pnpm(['install', '--frozen-lockfile'])
      await writeFile(marker, checksum)
    }
    await rm(next, { recursive: true, force: true })
    await pnpm(['run', 'build'], { env: { WIKI_BUILD_OUT: next }, timeout: 600_000 })
    await publishBuild(next)
    const info = await ensureServer()
    const url = `http://127.0.0.1:${info.port}/`
    await openBrowser(url)
    console.log(`WIKI READY: ${url}`)
  } finally {
    await rm(next, { recursive: true, force: true })
    await rm(join(cache, 'launch.lock'), { force: true })
  }
}
if (process.argv[1]?.endsWith('launch.mjs'))
  main().catch((error) => {
    console.error(error.message)
    process.exitCode = 1
  })
