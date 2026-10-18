import { access, readFile } from 'node:fs/promises'
import { constants } from 'node:fs'
import { spawn } from 'node:child_process'
import { dirname, delimiter, join, resolve } from 'node:path'
import { fileURLToPath } from 'node:url'
import { homedir } from 'node:os'

export const wikiRoot = resolve(dirname(fileURLToPath(import.meta.url)), '..')
export const projectRoot = resolve(wikiRoot, '..')

/** Находит доступный исполняемый файл, не предполагая наличие PATH у запуска из Finder. */
export async function executable(candidates, mode = constants.X_OK) {
  for (const path of candidates.filter(Boolean)) {
    try {
      await access(path, mode)
      return path
    } catch {
      /* Проверяем следующий путь. */
    }
  }
  return undefined
}

/** Возвращает полный список системных вариантов команды без вызова оболочки. */
export function onPath(name) {
  return (process.env.PATH ?? '')
    .split(delimiter)
    .filter(Boolean)
    .map((path) => join(path, name))
}

/** Использует ту же локальную копию Godot, что и игра, либо выбранную разработчиком установку. */
export async function godotBinary() {
  let configured
  try {
    configured = (
      await readFile(
        join(homedir(), 'Library/Application Support/Бабушкина ферма/godot_path'),
        'utf8'
      )
    ).trim()
  } catch {
    /* Выбор ещё не сохранён. */
  }
  const value = await executable([
    process.env.WIKI_GODOT_BIN,
    process.env.FARM_GODOT_BIN,
    configured,
    join(projectRoot, 'tools/Godot.app/Contents/MacOS/Godot'),
    '/Applications/Godot.app/Contents/MacOS/Godot',
    join(homedir(), 'Applications/Godot.app/Contents/MacOS/Godot'),
    join(projectRoot, 'tools/Godot.exe'),
    ...onPath(process.platform === 'win32' ? 'godot.exe' : 'godot'),
  ])
  if (!value)
    throw new Error('Godot не найден. Используйте установленный движок игры или WIKI_GODOT_BIN.')
  return value
}

/** Запускает проверяемую команду с таймаутом и прекращает экспорт при любой ошибке движка. */
export function run(
  command,
  args,
  { cwd = wikiRoot, env = {}, engine = false, timeout = 240_000, quiet = false } = {}
) {
  return new Promise((accept, reject) => {
    const child = spawn(command, args, {
      cwd,
      env: {
        ...process.env,
        PATH: `${dirname(process.execPath)}${delimiter}${process.env.PATH ?? ''}`,
        ...env,
      },
      stdio: ['ignore', 'pipe', 'pipe'],
    })
    let output = ''
    let engineError = false
    let expired = false
    const timer = setTimeout(() => {
      expired = true
      child.kill('SIGTERM')
    }, timeout)
    const collect = (chunk) => {
      const text = chunk.toString()
      output = (output + text).slice(-40_000)
      if (!quiet) process.stdout.write(text)
      if (engine && /ERROR:|SCRIPT ERROR|Parse Error|Failed to load script/.test(output)) {
        engineError = true
        child.kill('SIGTERM')
      }
    }
    child.stdout.on('data', collect)
    child.stderr.on('data', collect)
    child.on('error', (error) => {
      clearTimeout(timer)
      reject(error)
    })
    child.on('close', (code) => {
      clearTimeout(timer)
      if (code !== 0 || engineError || expired)
        reject(
          new Error(
            `${expired ? 'Превышено время выполнения' : 'Не удалось выполнить проверку'}: ${args.join(' ')}\n${output}`
          )
        )
      else accept(output)
    })
  })
}

/** Подбирает закреплённый pnpm из runtime, PATH или стандартного npm без глобальной установки. */
export async function packageManager() {
  const configured = await executable([process.env.WIKI_PNPM_BIN], constants.R_OK)
  if (configured)
    return /\.[cm]?js$/.test(configured)
      ? { command: process.execPath, prefix: [configured] }
      : { command: configured, prefix: [] }
  // Штатная обёртка runtime сохраняет собственные правила запуска менеджера.
  const cli = await executable([
    ...onPath(process.platform === 'win32' ? 'pnpm.cmd' : 'pnpm'),
    join(homedir(), '.cache/codex-runtimes/codex-primary-runtime/dependencies/bin/fallback/pnpm'),
  ])
  if (cli) return { command: cli, prefix: [] }
  const script = await executable(
    [
      join(dirname(process.execPath), '../node_modules/pnpm/bin/pnpm.mjs'),
      join(
        homedir(),
        '.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/pnpm/bin/pnpm.mjs'
      ),
    ],
    constants.R_OK
  )
  if (script)
    return /\.[cm]?js$/.test(script)
      ? { command: process.execPath, prefix: [script] }
      : { command: script, prefix: [] }
  const npmScript = await executable(
    [
      join(dirname(process.execPath), 'node_modules/npm/bin/npm-cli.js'),
      join(dirname(process.execPath), '../lib/node_modules/npm/bin/npm-cli.js'),
    ],
    constants.R_OK
  )
  if (npmScript)
    return {
      command: process.execPath,
      prefix: [npmScript, 'exec', '--yes', '--package=pnpm@11.19.0', '--', 'pnpm'],
    }
  const npm = await executable(onPath(process.platform === 'win32' ? 'npm.cmd' : 'npm'))
  if (npm)
    return { command: npm, prefix: ['exec', '--yes', '--package=pnpm@11.19.0', '--', 'pnpm'] }
  throw new Error('Менеджер пакетов не найден. Установите Node.js с npm или задайте WIKI_PNPM_BIN.')
}

/** Выполняет команду менеджера пакетов с одинаковыми правилами для терминала и значка приложения. */
export async function pnpm(args, options = {}) {
  const manager = await packageManager()
  return run(manager.command, [...manager.prefix, ...args], options)
}
