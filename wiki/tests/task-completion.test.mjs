import test from 'node:test'
import assert from 'node:assert/strict'
import { mkdtemp, writeFile, rm, mkdir } from 'node:fs/promises'
import { tmpdir } from 'node:os'
import { join } from 'node:path'
import { execFileSync } from 'node:child_process'
import {
  completionDate,
  acceptedCompletions,
  enrichCompletions,
} from '../scripts/task-completion.mjs'
import { markdownTasks } from '../scripts/planning-catalog.mjs'

test('dates reject missing, locale guesses, calendar overflow and invalid timestamps', () => {
  for (const value of [
    null,
    undefined,
    '',
    'вчера',
    '20.10.2026',
    '2026-02-30',
    '2026-13-01',
    '2026-10-20T99:00:00Z',
    '2026-10-20 trailing',
  ])
    assert.equal(completionDate(value), null)
  assert.equal(completionDate('2024-02-29'), '2024-02-29')
  assert.equal(completionDate('2026-10-20T23:05:00+05:00'), '2026-10-20')
})

test('accepted graph uses merge acceptance date and latest accepted completion event', () => {
  const records = [
    { sha: 'a', parents: [], date: '2026-10-10', body: 'root' },
    {
      sha: 'b',
      parents: ['a'],
      date: '2099-10-01',
      body: 'Task-Complete: TASK-001\nTask-Complete: TASK-002',
    },
    {
      sha: 'c',
      parents: ['a', 'b'],
      date: '2026-10-20',
      body: 'Merge pull request #14 from feature',
    },
    {
      sha: 'd',
      parents: ['c'],
      date: '2026-10-21',
      body: 'Task-Complete: TASK-001\nTask-Complete:\nTASK-999',
    },
  ]
  const dates = acceptedCompletions(records, 'd')
  assert.equal(dates.get('TASK-001').date, '2026-10-21')
  assert.equal(dates.get('TASK-002').date, '2026-10-20')
  assert.equal(dates.has('TASK-999'), false)
  assert.match(dates.get('TASK-002').evidence[0].url, /pull\/14$/)
  assert.match(dates.get('TASK-002').evidence[1].url, /commit\/c$/)
})

/** Каждый опыт владеет отдельным настоящим repo с пробелами; Git-окружение hook очищено. */
async function fixture(t) {
  const root = await mkdtemp(join(tmpdir(), 'wiki completion git '))
  t.after(() => rm(root, { recursive: true, force: true }))
  const env = Object.fromEntries(
    Object.entries(process.env).filter(([key]) => !key.startsWith('GIT_'))
  )
  const git = (...args) =>
    execFileSync('git', ['-C', root, ...args], { env, encoding: 'utf8' }).trim()
  git('init', '-q', '-b', 'main')
  git('config', 'user.name', 'Wiki fixture')
  git('config', 'user.email', 'fixture@example.test')
  let counter = 0
  const commit = async (message, date) => {
    await writeFile(join(root, 'proof.txt'), String(++counter))
    git('add', 'proof.txt')
    execFileSync('git', ['-C', root, 'commit', '-q', '-m', message], {
      env: { ...env, GIT_AUTHOR_DATE: date, GIT_COMMITTER_DATE: date },
    })
    return git('rev-parse', 'HEAD')
  }
  await commit('root', '2026-10-10T10:00:00Z')
  return { root, env, git, commit }
}

const task = (id, extra = {}) => ({
  id,
  key: `fixture--${id}`,
  status: 'done',
  source: 'docs/tasks.md',
  content: '',
  ...extra,
})

test('real Git excludes unmerged future trailers and refreshes at accepted main changes', async (t) => {
  const { root, env, git, commit } = await fixture(t)
  git('switch', '-q', '-c', 'accepted-feature')
  await commit('Task-Complete: TASK-001', '2099-01-01T10:00:00Z')
  git('switch', '-q', 'main')
  execFileSync(
    'git',
    [
      '-C',
      root,
      'merge',
      '-q',
      '--no-ff',
      'accepted-feature',
      '-m',
      'Merge pull request #15 from feature',
    ],
    {
      env: { ...env, GIT_COMMITTER_DATE: '2026-10-20T10:00:00Z' },
    }
  )
  const accepted = git('rev-parse', 'HEAD')
  git('update-ref', 'refs/remotes/origin/main', accepted)
  git('switch', '-q', '-c', 'unmerged')
  await commit('Task-Complete: TASK-002', '2099-01-02T10:00:00Z')
  const rows = [task('TASK-001'), task('TASK-002'), task('TASK-003', { status: 'in_progress' })]
  const beforeConfig = git('config', '--local', '--list')
  const inherited = process.env.GIT_DIR
  process.env.GIT_DIR = '/nonexistent/hook-repository'
  try {
    await enrichCompletions(rows, root)
  } finally {
    if (inherited === undefined) delete process.env.GIT_DIR
    else process.env.GIT_DIR = inherited
  }
  assert.equal(rows[0].completion.date, '2026-10-20')
  assert.match(rows[0].completion.evidence[0].url, /pull\/15$/)
  assert.equal(rows[1].completion.date, null)
  assert.equal(rows[2].completion, undefined)
  assert.equal(git('config', '--local', '--list'), beforeConfig)
  git('switch', '-q', 'main')
  const next = await commit('Task-Complete: TASK-002', '2026-10-21T10:00:00Z')
  git('update-ref', 'refs/remotes/origin/main', next)
  await enrichCompletions(rows, root)
  assert.equal(rows[1].completion.date, '2026-10-21')
})

test('missing Git preserves explicit card dates, honest unknowns and canonical status', async (t) => {
  const root = await mkdtemp(join(tmpdir(), 'wiki exported '))
  t.after(() => rm(root, { recursive: true, force: true }))
  const rows = [
    task('TASK-001', { completion: { date: '2026-10-20' } }),
    task('TASK-002'),
    task('TASK-003', { status: 'ready', completion: { date: '2099-01-01' } }),
  ]
  await enrichCompletions(rows, root)
  assert.equal(rows[0].completion.date, '2026-10-20')
  assert.equal(rows[0].completion.basis, 'Явная дата в карточке')
  assert.equal(rows[1].completion.date, null)
  assert.equal(rows[1].completion.basis, 'Дата не указана')
  assert.equal(rows[2].completion, undefined)
})

test('ambiguous IDs and nonexistent proof files cannot acquire another task acceptance', async (t) => {
  const { root, git, commit } = await fixture(t)
  const accepted = await commit('Task-Complete: TASK-001', '2026-10-20T10:00:00Z')
  git('update-ref', 'refs/remotes/origin/main', accepted)
  const rows = [
    task('TASK-001', { content: '[fake](../docs/reports/missing.json)' }),
    task('TASK-001', { key: 'other--TASK-001' }),
  ]
  await enrichCompletions(rows, root)
  assert.ok(
    rows.every((row) => row.completion.date === null && row.completion.evidence.length === 0)
  )
})

test('explicit Markdown completion date is parsed independently of unrelated result dates', () => {
  const [row] = markdownTasks(
    '## WIKI-003 — Fixture\n\n**Статус:** done\n\n**Дата завершения:** 2026-10-20\n\n**Подтверждения / результат:** План от 2026-01-01',
    { key: 'wiki--WIKI', source: 'docs/tasks.md' },
    { id: 'wiki' }
  )
  assert.equal(row.completion.date, '2026-10-20')
  const [datedResult] = markdownTasks(
    '## WIKI-004 — Fixture\n\n**Статус:** done\n\n**Подтверждения / результат:** 2026-10-21: принято',
    { key: 'wiki--WIKI', source: 'docs/tasks.md' },
    { id: 'wiki' }
  )
  assert.equal(datedResult.completion.date, '2026-10-21')
})

test('proof links resolve accepted files, encode spaces, deduplicate PR and reject future paths', async (t) => {
  const { root, git, commit } = await fixture(t)
  const directory = 'docs/reports/space proof'
  await mkdir(join(root, directory), { recursive: true })
  await writeFile(join(root, directory, 'README.md'), '# Accepted proof')
  git('add', directory)
  const accepted = await commit('Task-Complete: TASK-001', '2026-10-20T10:00:00Z')
  git('update-ref', 'refs/remotes/origin/main', accepted)
  await writeFile(join(root, directory, 'future.json'), '{}')
  const rows = [
    task('TASK-001', {
      content:
        '[Report](reports/space proof/README.md)\n' +
        '[Future](reports/space proof/future.json)\n[Escape](../../etc/passwd)\n' +
        'https://github.com/sergey-leonidovich-shevchenko/babushkina-ferma/pull/14\n' +
        'https://github.com/sergey-leonidovich-shevchenko/babushkina-ferma/pull/14',
    }),
  ]
  await enrichCompletions(rows, root)
  const links = rows[0].completion.evidence
  assert.equal(links.length, 3)
  assert.ok(links.some((link) => link.url.endsWith('/docs/reports/space%20proof/README.md')))
  assert.ok(
    links.every((link) => !link.url.includes('future.json') && !link.url.includes('passwd'))
  )
})
