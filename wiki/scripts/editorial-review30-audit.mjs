import assert from 'node:assert/strict'
import { readFile } from 'node:fs/promises'
import { execFileSync } from 'node:child_process'
import { createHash } from 'node:crypto'
import { join } from 'node:path'
import { projectRoot } from './runtime.mjs'
import { readPlanningCatalog } from './planning-catalog.mjs'

// Pin the reviewed baseline; a hook or another worktree must not select Git inputs.
const base = '464328853c2fbbed1410ac0312de75c3fee7cfa2'
const out = 'docs/reports/creative/2026-10-30'
const environment = Object.fromEntries(
  Object.entries(process.env).filter(([key]) => !key.startsWith('GIT_'))
)
const git = (...args) =>
  execFileSync('git', ['--no-optional-locks', ...args], {
    cwd: projectRoot,
    env: environment,
    maxBuffer: 32 * 1024 * 1024,
  })
const read = (path) => readFile(join(projectRoot, path), 'utf8')
const json = async (path) => JSON.parse(await read(path))
const old = (path) => git('show', `${base}:${path}`).toString()
const digest = (value) => createHash('sha256').update(value).digest('hex')
const review = await json(`${out}/proposals.json`)
const ideas = review.ideas
const ids = ideas.map((idea) => idea.id)
assert.deepEqual(
  ids,
  Array.from({ length: 10 }, (_, i) => `IDEA-${i + 302}`)
)
assert.equal(review.base, base)
assert.equal(review.gameplayImplemented, false)
assert.equal(review.futureTestsRun, 0)

// Reserve IDs from every published reviewed head without importing pending content.
const published = await json(`${out}/published-refs.json`)
const occupied = new Set(JSON.parse(old('wiki/planning/state.json')).ideas.map((i) => i.id))
assert.equal(published.refs.length, 7)
for (const ref of published.refs) {
  assert.match(ref.head, /^[0-9a-f]{40}$/)
  const state = JSON.parse(git('show', `${ref.head}:wiki/planning/state.json`).toString())
  state.ideas.forEach((i) => occupied.add(i.id))
}
assert.equal(occupied.size, 301)
assert.ok(ids.every((id) => !occupied.has(id)))
assert.equal(published.previousReviewHead, review.previousReviewHead)
const plan = await json(`${out}/plan.json`)
assert.equal(digest(await read(`${out}/previous-plan.json`)), plan.previousPlanSHA256)
assert.equal(
  digest(git('show', `${review.previousReviewHead}:docs/reports/creative/2026-10-29/plan.json`)),
  plan.previousPlanSHA256
)

// Old decisions, scores, queues, source entries and index rows remain intact.
const originalState = JSON.parse(old('wiki/planning/state.json'))
const state = await json('wiki/planning/state.json')
assert.equal(state.revision, originalState.revision + 1)
assert.deepEqual(state.ideas.slice(0, originalState.ideas.length), originalState.ideas)
for (const key of Object.keys(originalState).filter(
  (k) => !['revision', 'updatedAt', 'ideas'].includes(k)
)) {
  assert.deepEqual(state[key], originalState[key], key)
}
assert.equal(state.ideas.length, originalState.ideas.length + 10)
const originalGrades = JSON.parse(old('wiki/planning/assessments.json'))
const grades = await json('wiki/planning/assessments.json')
assert.deepEqual(grades.ideas.slice(0, originalGrades.ideas.length), originalGrades.ideas)
for (const [key, value] of Object.entries(originalGrades.sources))
  assert.deepEqual(grades.sources[key], value)
assert.equal(grades.ideas.length, originalGrades.ideas.length + 10)
const originalSources = JSON.parse(old('wiki/planning/sources.json'))
const sources = await json('wiki/planning/sources.json')
const previousPlans = structuredClone(originalSources.plans)
previousPlans.find((p) => p.id === 'wiki').expected += 1
assert.deepEqual(sources.plans.slice(0, previousPlans.length), previousPlans)
assert.deepEqual(sources.queues, originalSources.queues)
assert.equal(sources.plans.length, previousPlans.length + 10)
const oldIndex = JSON.parse(old('wiki/articles/index.json'))
const index = await json('wiki/articles/index.json')
assert.deepEqual(index.slice(0, oldIndex.length), oldIndex)
assert.equal(index.length, oldIndex.length + 13)
assert.ok(
  (await read('docs/backlog/wiki-workspace-2026-10/README.md')).startsWith(
    old('docs/backlog/wiki-workspace-2026-10/README.md')
  )
)

const catalog = await readPlanningCatalog()
const tasks = catalog.tasks.filter((t) => ids.some((id) => t.id.startsWith(`${id}-`)))
assert.equal(tasks.length, 44)
assert.ok(tasks.every((t) => t.status === 'backlog' && t.acceptance.length >= 3))
const allTasks = new Map(catalog.tasks.map((t) => [t.id, t]))
const mine = new Map(tasks.map((t) => [t.id, t]))
const visit = (id, path = []) => {
  assert.ok(!path.includes(id), [...path, id].join(' -> '))
  for (const dep of mine.get(id)?.dependencies ?? []) {
    assert.ok(allTasks.has(dep), `${id}: missing ${dep}`)
    if (mine.has(dep)) visit(dep, [...path, id])
  }
}
tasks.forEach((t) => visit(t.id))
const actors = ideas.flatMap((p) => p.actors.map(([id]) => id))
assert.equal(actors.length, 10)
assert.equal(new Set(actors).size, 10)
assert.equal(new Set(ideas.map((p) => p.place)).size, 10)
assert.equal(
  ideas.reduce((sum, p) => sum + p.dialog.length, 0),
  30
)
assert.equal(
  ideas.reduce((sum, p) => sum + p.dialog.reduce((n, node) => n + node[3].length, 0), 0),
  90
)
assert.equal(
  ideas.reduce((sum, p) => sum + p.tests.length, 0),
  60
)
const headings = [
  'Суть, польза',
  'Основа, последние',
  'Пошаговый игровой',
  'Правила, числа',
  'Написанные разговоры',
  'Интерфейс, обучение',
  'Предметные этапы',
  'Риски и способы',
  'Наблюдаемая приёмка',
  'Оценки, референс',
]
for (const proposal of ideas) {
  const text = await read(`wiki/articles/${proposal.id}.md`)
  assert.ok(text.length > 10000, `${proposal.id}: insufficient detail`)
  for (const heading of headings) assert.ok(text.includes(heading), `${proposal.id}: ${heading}`)
  for (const value of [proposal.summary, proposal.basis, proposal.balance, proposal.record])
    assert.ok(text.includes(value))
  for (const rule of proposal.rules) assert.ok(text.includes(rule), `${proposal.id}: rule`)
  const geometryTask = allTasks.get(proposal.geometryOwner)
  assert.ok(geometryTask && geometryTask.id.startsWith(`${proposal.id}-`))
  assert.ok(text.includes(`Геометрия/рабочая зона — ${proposal.geometryOwner}.`))
  const register = await read('wiki/articles/new-pursuits-register.md')
  assert.ok(register.includes(`/${proposal.id.toLowerCase()}--${proposal.geometryOwner}`))
  assert.equal(proposal.dialog.length, 3)
  assert.equal(proposal.tests.length, 6)
  for (const [key, speaker, line, choices] of proposal.dialog) {
    assert.ok(text.includes(line) && text.includes(`${proposal.id}-${key}`) && speaker)
    assert.equal(choices.length, 3)
    choices.forEach((choice) => choice.forEach((value) => assert.ok(text.includes(value))))
  }
  proposal.tests.forEach((expected, i) =>
    assert.ok(
      text.includes(`F${proposal.n}-${String(i + 1).padStart(2, '0')}`) && text.includes(expected)
    )
  )
  const decision = state.ideas.find((i) => i.id === proposal.id)
  assert.equal(decision.status, 'proposed')
  assert.equal(decision.group, proposal.group)
  assert.deepEqual(decision.linkedEpics, [`${proposal.id.toLowerCase()}--${proposal.id}`])
  const grade = grades.ideas.find((i) => i.idea === proposal.id)
  const scores = ['usefulness', 'interest', 'fit', 'synergy', 'cost', 'risk'].map(
    (key) => grade[key]
  )
  assert.deepEqual(scores, proposal.scores)
  assert.ok(scores.every((n) => Number.isInteger(n) && n >= 1 && n <= 5))
  assert.equal(grade.value, 6 * scores[0] + 6 * scores[1] + 5 * scores[2] + 3 * scores[3])
  assert.equal(grade.familiarity, null)
  assert.ok(grade.audience && grade.prototype && grade.analogue && grades.sources[grade.source])
  const source = sources.plans.find((p) => p.id === proposal.id.toLowerCase())
  assert.equal(source.expected, proposal.tasks.length)
  assert.equal(source.group, proposal.group)
  const own = tasks.filter((t) => t.id.startsWith(`${proposal.id}-`))
  assert.equal(own.length, proposal.tasks.length)
  for (const task of own.filter((t) => !t.id.endsWith('-01'))) {
    assert.ok(proposal.dependencies.every((id) => task.dependencies.includes(id)))
  }
}
const editor = allTasks.get('IDEA-REVIEW-20261030')
assert.equal(editor?.status, 'in_progress')
assert.ok(editor.source.includes('wiki-workspace'))
// A published URL is required as soon as its publication manifest exists.
try {
  const publication = await json(`${out}/publication.json`)
  assert.match(
    publication.pullRequest,
    /^https:\/\/github\.com\/sergey-leonidovich-shevchenko\/babushkina-ferma\/pull\/\d+$/
  )
  assert.ok(
    (await read('docs/backlog/wiki-workspace-2026-10/README.md')).includes(publication.pullRequest)
  )
} catch (error) {
  if (error.code !== 'ENOENT') throw error
}

// Clamp edits to the new design package, established pointers and version metadata.
const allowed = new Set([
  'TESTING.md',
  'VERSION',
  'project.godot',
  'Бабушкина ферма.app/Contents/Info.plist',
  'wiki/planning/state.json',
  'wiki/planning/assessments.json',
  'wiki/planning/sources.json',
  'wiki/articles/index.json',
  'wiki/articles/idea-feature-epics.md',
  'docs/epics/ideas/README.md',
  'docs/backlog/README.md',
  'docs/backlog/wiki-workspace-2026-10/README.md',
  'wiki/scripts/editorial-review30-audit.mjs',
  'wiki/articles/new-pursuits-contracts.md',
  'wiki/articles/new-pursuits-register.md',
  'wiki/articles/creative-review-2026-10-30.md',
  ...ids.map((id) => `wiki/articles/${id}.md`),
])
const changed = git('diff', '--name-only', '-z', base, '--').toString().split('\0').filter(Boolean)
assert.ok(
  changed.every(
    (path) =>
      allowed.has(path) ||
      path.startsWith(`${out}/`) ||
      ids.some((id) => path.startsWith(`docs/epics/ideas/${id.toLowerCase()}/`))
  ),
  changed.join('\n')
)
assert.equal(
  (await read('project.godot')).replace(/^config\/version=.*$/m, ''),
  old('project.godot').replace(/^config\/version=.*$/m, '')
)
console.log(
  JSON.stringify(
    {
      base,
      newIdeas: 10,
      priorIdeasPreserved: originalState.ideas.length,
      priorAssessmentsPreserved: originalGrades.ideas.length,
      reservedPriorIds: occupied.size,
      nextUsed: [302, 311],
      independentEpics: 10,
      implementationBacklog: 44,
      proposedActors: 10,
      dialogueNodes: 30,
      writtenReplies: 90,
      futureScenarios: 60,
      futureScenariosRun: 0,
      editorStatus: editor.status,
      dependencyGraph: 'valid',
      oldQueuesPreserved: true,
      gameplayImplemented: false,
      proposalSHA256: digest(await read(`${out}/proposals.json`)),
      publishedHeads: published.refs,
    },
    null,
    2
  )
)
