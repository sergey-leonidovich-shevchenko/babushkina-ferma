import { execFile } from 'node:child_process'
import { promisify } from 'node:util'
import { posix } from 'node:path'

const execute = promisify(execFile)
const repository = 'https://github.com/sergey-leonidovich-shevchenko/babushkina-ferma'
let cached

/** Принимает только настоящую календарную дату, а не нормализованный JS overflow. */
export function completionDate(value) {
  if (typeof value !== 'string') return null
  const match = /^(\d{4}-\d{2}-\d{2})(?:T\d{2}:\d{2}:\d{2}(?:\.\d+)?(?:Z|[+-]\d{2}:\d{2}))?$/.exec(
    value.trim()
  )
  if (!match || !Number.isFinite(Date.parse(value))) return null
  const day = new Date(`${match[1]}T00:00:00Z`)
  return day.toISOString().slice(0, 10) === match[1] ? match[1] : null
}

/** Git всегда читает явно выбранный repo, даже при запуске Wiki из hook/worktree. */
async function git(root, args) {
  const env = Object.fromEntries(
    Object.entries(process.env).filter(([key]) => !key.startsWith('GIT_'))
  )
  const { stdout } = await execute('git', ['-C', root, ...args], {
    env,
    maxBuffer: 32 * 1024 * 1024,
  })
  return stdout.trimEnd()
}

/** Привязывает completion-trailer к первому принятию его ветки в main, а не дате автора PR. */
export function acceptedCompletions(records, tip) {
  const nodes = new Map(records.map((record) => [record.sha, record]))
  const mainline = []
  for (let node = nodes.get(tip); node; node = nodes.get(node.parents[0])) mainline.push(node)
  const seen = new Set()
  const completions = new Map()
  for (const acceptance of mainline.reverse()) {
    const pending = [acceptance.sha]
    while (pending.length) {
      const sha = pending.pop()
      if (seen.has(sha)) continue
      seen.add(sha)
      const node = nodes.get(sha)
      if (!node) continue // Неполная локальная история не создаёт фиктивных старых событий.
      pending.push(...node.parents)
      for (const match of node.body.matchAll(
        /^Task-Complete:[ \t]*([A-Z][A-Z0-9]*(?:-[A-Z0-9]+)+)[ \t]*$/gm
      )) {
        const date = completionDate(acceptance.date)
        if (!date) continue
        const evidence = [
          { label: 'Принятие в main', url: `${repository}/commit/${acceptance.sha}` },
        ]
        const pr = acceptance.body.match(/^Merge pull request #(\d+)\b/m)?.[1]
        if (pr) evidence.unshift({ label: `PR #${pr}`, url: `${repository}/pull/${pr}` })
        completions.set(match[1], {
          date,
          basis: 'Дата принятия completion-коммита в main',
          evidence,
        })
      }
    }
  }
  return completions
}

/** Ограничивает историю общим принятым предком HEAD/main; невлитые feature-ветки исключены. */
async function acceptedHistory(root) {
  let accepted
  for (const ref of ['refs/remotes/origin/main', 'refs/heads/main']) {
    try {
      accepted = await git(root, ['merge-base', 'HEAD', ref])
      if (accepted) break
    } catch {
      /* В экспортированной копии Git или ref может отсутствовать; даты останутся неизвестны. */
    }
  }
  if (!accepted) return { completions: new Map(), files: new Set() }
  const key = `${root}\0${accepted}`
  if (cached?.key === key) return cached.value
  const value = (async () => {
    const [log, names] = await Promise.all([
      git(root, ['log', '--format=%H%x00%P%x00%cI%x00%B%x00%x1e', accepted]),
      git(root, ['ls-tree', '-r', '--name-only', accepted]),
    ])
    const records = log
      .split('\x1e')
      .filter((row) => row.trim())
      .map((row) => {
        const [sha, parents, date, body] = row.trimStart().split('\0')
        return { sha, parents: parents.split(' ').filter(Boolean), date, body }
      })
    return {
      accepted,
      completions: acceptedCompletions(records, accepted),
      files: new Set(names.split('\n')),
    }
  })()
  cached = { key, value }
  try {
    return await value
  } catch (error) {
    cached = undefined
    throw error
  }
}

/** Ссылки выводятся только на PR этого проекта и существующие в принятом Git доказательства. */
function evidenceLinks(task, history) {
  const links = []
  for (const match of task.content.matchAll(
    /https:\/\/github\.com\/sergey-leonidovich-shevchenko\/babushkina-ferma\/pull\/\d+(?:#[\w-]+)?/g
  ))
    links.push({ label: `PR #${match[0].match(/\/pull\/(\d+)/)[1]}`, url: match[0] })
  const candidates = [
    ...[...task.content.matchAll(/\[([^\]]+)\]\(([^)]+)\)/g)].map((match) => ({
      label: match[1],
      path: match[2],
      relative: true,
    })),
    ...[...task.content.matchAll(/"(docs\/reports\/[^"\n]+\.(?:json|md))"/g)].map((match) => ({
      label: `Материал: ${posix.basename(match[1])}`,
      path: match[1],
    })),
  ]
  for (const candidate of candidates) {
    const path = posix.normalize(
      candidate.relative ? posix.join(posix.dirname(task.source), candidate.path) : candidate.path
    )
    if (!path.startsWith('docs/reports/') || !history.files.has(path)) continue
    links.push({
      label: candidate.label,
      url: `${repository}/blob/${history.accepted}/${path.split('/').map(encodeURIComponent).join('/')}`,
    })
  }
  return links
}

/** Дополняет тот же атомарно загружаемый каталог; статусы и исходный порядок не меняет. */
export async function enrichCompletions(tasks, root) {
  let history
  try {
    history = await acceptedHistory(root)
  } catch {
    history = { completions: new Map(), files: new Set() }
  }
  const counts = new Map()
  for (const task of tasks) counts.set(task.id, (counts.get(task.id) ?? 0) + 1)
  for (const task of tasks) {
    if (task.status !== 'done') {
      delete task.completion
      continue
    }
    // Trailer с неоднозначным ID не присваивается произвольно одной из разных карточек.
    const accepted = counts.get(task.id) === 1 ? history.completions.get(task.id) : undefined
    const date = completionDate(task.completion?.date)
    const value = accepted ?? {
      date,
      basis: date ? 'Явная дата в карточке' : 'Дата не указана',
      evidence: [],
    }
    const evidence = [...value.evidence, ...evidenceLinks(task, history)]
    task.completion = {
      ...value,
      evidence: evidence.filter(
        (link, i) => evidence.findIndex((item) => item.url === link.url) === i
      ),
    }
  }
}
