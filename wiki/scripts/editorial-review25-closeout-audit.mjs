import assert from 'node:assert/strict'
import { execFileSync } from 'node:child_process'
import { createHash } from 'node:crypto'
import { readFile, writeFile, mkdtemp, rm } from 'node:fs/promises'
import { tmpdir } from 'node:os'
import { join } from 'node:path'
import { projectRoot } from './runtime.mjs'
import { readPlanningCatalog } from './planning-catalog.mjs'

const report = 'docs/reports/creative/2026-10-26-review25-closeout'
const cardFile = 'docs/backlog/wiki-workspace-2026-10/README.md'
const marker = '## IDEA-REVIEW-20261025 — '
const article = 'wiki/articles/creative-review25-acceptance.md'
const script = 'wiki/scripts/editorial-review25-closeout-audit.mjs'
const mutable = new Set([
  'TESTING.md', 'docs/backlog/README.md', cardFile, 'wiki/articles/index.json',
  'VERSION', 'project.godot', 'Бабушкина ферма.app/Contents/Info.plist',
])

function git(args, options = {}) {
  return execFileSync('git', args, { cwd: projectRoot, maxBuffer: 64 * 1024 * 1024, ...options })
}
const text = (path) => readFile(join(projectRoot, path), 'utf8')
const json = async (path) => JSON.parse(await text(path))
const at = (ref, path) => git(['show', `${ref}:${path}`]).toString()
const sha256 = (value) => createHash('sha256').update(value).digest('hex')

// Один base закрепляет факт приёмки. Будущая main не меняет смысл этого отчёта.
function verifyAcceptance(completion) {
  const { acceptedMain, approvedHead, review, ci } = completion
  assert.equal(completion.task, 'IDEA-REVIEW-20261025')
  assert(review.body.startsWith('APPROVED') && review.body.includes(approvedHead))
  assert(review.url.endsWith('pullrequestreview-5647129421'))
  assert.equal(ci.pullRequestRun.conclusion, 'success')
  assert.equal(ci.pushRun.conclusion, 'success')
  assert.equal(ci.checks, '8/8 success')
  assert.equal(git(['rev-parse', `${acceptedMain}^{tree}`]).toString(), git(['rev-parse', `${approvedHead}^{tree}`]).toString())
  assert(git(['show', '-s', '--format=%P', acceptedMain]).toString().split(/\s+/).includes(approvedHead))
  git(['merge-base', '--is-ancestor', acceptedMain, 'HEAD'])
}

// Сверяем весь прежний index, а не только выбранные игровые каталоги. Добавления
// разрешены исключительно в новом отчёте и двух новых источниках Wiki.
function verifyFiles(base) {
  const previous = new Map()
  for (const row of git(['ls-tree', '-rz', '--full-tree', base]).toString().split('\0').filter(Boolean)) {
    const [header, path] = row.split('\t')
    previous.set(path, header.split(' ')[2])
  }
  const current = new Map()
  for (const row of git(['ls-files', '-s', '-z']).toString().split('\0').filter(Boolean)) {
    const [header, path] = row.split('\t')
    assert.equal(header.split(' ')[2], '0', `неразрешённый конфликт ${path}`)
    current.set(path, header.split(' ')[1])
  }
  for (const [path, blob] of previous) {
    if (!mutable.has(path)) assert.equal(current.get(path), blob, `изменён прежний файл ${path}`)
  }
  for (const path of current.keys()) {
    if (!previous.has(path)) assert(path === article || path === script || path.startsWith(`${report}/`), `лишнее добавление ${path}`)
  }
  assert.equal(git(['diff', '--name-only']).toString(), '', 'есть незастейдженные изменения')
  const historical = [...previous].filter(([path]) => path.startsWith('docs/reports/') || path.startsWith('wiki/reports/') || /^wiki\/articles\/creative-review-.*\.md$/.test(path))
  return {
    unchangedPreviousFiles: previous.size - mutable.size,
    historicalFiles: historical.length,
    historicalManifestSHA256: sha256(historical.map(([path, blob]) => `${path}\t${blob}`).sort().join('\n')),
  }
}

// Парсер читает реальный принятый набор из отдельной временной капсулы; никакой
// чужой checkout не переключается, а входы root/manifest заданы явно.
async function previousCatalog(base) {
  const root = await mkdtemp(join(tmpdir(), 'review25-closeout-'))
  try {
    const sources = JSON.parse(at(base, 'wiki/planning/sources.json'))
    const paths = ['docs/backlog', 'docs/epics', 'wiki/planning', 'wiki/articles', ...(sources.queues ?? []).map((queue) => queue.file)]
    execFileSync('tar', ['-x', '-C', root], { input: git(['archive', base, ...paths]) })
    return await readPlanningCatalog({ root, manifest: join(root, 'wiki/planning/sources.json') })
  } finally {
    await rm(root, { recursive: true, force: true })
  }
}

function verifyGraph(tasks) {
  const map = new Map(tasks.map((task) => [task.id, task]))
  assert.equal(map.size, tasks.length)
  const visited = new Set()
  const active = new Set()
  function visit(id) {
    assert(map.has(id), `неизвестная зависимость ${id}`)
    assert(!active.has(id), `цикл ${id}`)
    if (visited.has(id)) return
    active.add(id)
    for (const dependency of map.get(id).dependencies) visit(dependency)
    active.delete(id)
    visited.add(id)
  }
  for (const id of map.keys()) visit(id)
}

async function main() {
  const completion = await json(`${report}/completion.json`)
  verifyAcceptance(completion)
  const base = completion.acceptedMain
  const files = verifyFiles(base)
  const oldCardFile = at(base, cardFile)
  const card = await text(cardFile)
  assert.equal(card.slice(0, card.indexOf(marker)), oldCardFile.slice(0, oldCardFile.indexOf(marker)))
  assert.equal(completion.previousCardMarkdown, oldCardFile.slice(oldCardFile.indexOf(marker)))
  for (const path of ['VERSION', 'project.godot', 'Бабушкина ферма.app/Contents/Info.plist']) {
    assert.equal(at(base, path).replaceAll('0.0.341', '<VERSION>'), (await text(path)).replaceAll('0.0.342', '<VERSION>'))
  }
  assert.equal((await text('VERSION')).trim(), '0.0.342')
  const index = await json('wiki/articles/index.json')
  assert.equal(new Set(index.map((row) => row.id)).size, index.length)
  assert.deepEqual(index.filter((row) => row.id !== 'creative-review25-acceptance'), JSON.parse(at(base, 'wiki/articles/index.json')))
  assert.equal(index.filter((row) => row.id === 'creative-review25-acceptance').length, 1)
  const current = await readPlanningCatalog()
  const previous = await previousCatalog(base)
  const map = new Map(current.tasks.map((task) => [task.id, task]))
  assert.equal(current.tasks.length, previous.tasks.length)
  for (const task of previous.tasks) {
    const actual = map.get(task.id)
    if (task.id !== completion.task) assert.deepEqual(actual, task, `чужая карточка ${task.id}`)
    else {
      for (const key of Object.keys(task)) {
        if (!['status', 'result', 'sections', 'content'].includes(key)) assert.deepEqual(actual[key], task[key], `границы закрытия ${key}`)
      }
      assert.equal(task.status, 'in_progress')
      assert.equal(actual.status, 'done')
      assert(actual.result.includes(completion.approvedHead) && actual.result.includes(completion.acceptedMain))
      assert(actual.result.includes('/pull/8'))
    }
  }
  verifyGraph(current.tasks)
  const future = current.tasks.filter((task) => /^idea-(23[2-9]|24\d|25[01])--/.test(task.epic))
  assert.equal(future.length, 86)
  assert(future.every((task) => task.status === 'backlog'))
  assert.equal(map.get('IDEA-REVIEW-20261024').status, 'in_progress')
  assert.equal(map.get('VFOLIAGE-010').status, 'done')
  assert.equal(map.get('REFACTOR-00').status, 'done')
  assert.equal(map.get('REFACTOR-01').status, 'ready')
  assert.equal((await json('wiki/planning/state.json')).ideas.length, 241)
  assert.equal((await json('wiki/planning/assessments.json')).ideas.length, 80)
  let commitEvidence = 'not checked before commit'
  if (process.argv.includes('--committed')) {
    const trailers = git(['log', `${base}..HEAD`, '--format=%B']).toString().match(/^Task-Complete: IDEA-REVIEW-20261025$/gm) ?? []
    assert.equal(trailers.length, 1)
    commitEvidence = 'one exact Task-Complete trailer in the closeout branch'
  }
  const sourceSHA256 = {}
  for (const path of [...mutable, article, script, `${report}/completion.json`]) sourceSHA256[path] = sha256(await readFile(join(projectRoot, path)))
  const result = {
    checkedAt: new Date().toISOString(), status: 'pass', base,
    ...files, task: { id: completion.task, from: 'in_progress', to: 'done' },
    unchangedOtherTasks: previous.tasks.length - 1, futureBacklogCards: future.length,
    catalog: { plans: current.plans.length, epics: current.epics.length, tasks: current.tasks.length },
    ideas: 241, assessments: 80, metadata: '0.0.342', commitEvidence, sourceSHA256,
    scope: 'Only accepted editorial work is closed. Gameplay, audience, FPS and VMAP-003 are not accepted.',
  }
  if (process.argv.includes('--write')) await writeFile(join(projectRoot, report, 'preservation.json'), `${JSON.stringify(result, null, 2)}\n`)
  process.stdout.write(`${JSON.stringify(result, null, 2)}\n`)
}

await main()
