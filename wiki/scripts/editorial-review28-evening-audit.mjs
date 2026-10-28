import assert from 'node:assert/strict'
import { readFile } from 'node:fs/promises'
import { execFileSync } from 'node:child_process'
import { join } from 'node:path'
import { createHash } from 'node:crypto'
import { projectRoot } from './runtime.mjs'
import { readPlanningCatalog } from './planning-catalog.mjs'

// The audit is pinned to the accepted baseline; foreign Git settings never select its source/index.
const base = 'd609ab4fa6d82d6d013265183f018b8836abf7cc'
const out = 'docs/reports/creative/2026-10-28-evening'
const env = Object.fromEntries(
  Object.entries(process.env).filter(([key]) => !key.startsWith('GIT_'))
)
const git = (...args) =>
  execFileSync('git', ['--no-optional-locks', ...args], {
    cwd: projectRoot,
    env,
    maxBuffer: 32 * 1024 * 1024,
  })
const read = (path) => readFile(join(projectRoot, path), 'utf8')
const json = async (path) => JSON.parse(await read(path))
const old = (path) => git('show', `${base}:${path}`).toString()
const hash = (bytes) => createHash('sha256').update(bytes).digest('hex')
const review = await json(`${out}/proposals.json`)
const published = await json(`${out}/published-refs.json`)
const proposals = review.ideas
const newIds = proposals.map((d) => d.id)
assert.deepEqual(
  newIds,
  Array.from({ length: 10 }, (_, i) => `IDEA-${282 + i}`)
)
assert.equal(review.base, base)
assert.equal(review.gameplayImplemented, false)
assert.equal(review.futureTestsRun, 0)
assert.equal(new Set(proposals.map((p) => p.place)).size, 10)
assert.equal(new Set(proposals.map((p) => p.actorId)).size, 10)
assert.equal(
  proposals.reduce((n, p) => n + p.stages.length, 0),
  42
)
assert.equal(
  proposals.reduce((n, p) => n + p.dialog.length, 0),
  20
)
assert.equal(
  proposals.reduce((n, p) => n + p.dialog.reduce((v, d) => v + d[3].length, 0), 0),
  60
)
assert.ok(
  proposals.every((p) => p.tests.length === 6 && p.path.length === 6 && p.rules.length === 6)
)

// Reserve every published IDEA range without importing its unaccepted decisions.
const originalState = JSON.parse(old('wiki/planning/state.json'))
const occupied = new Map(originalState.ideas.map((p) => [p.id, p.title]))
for (const [number, first, last] of [
  [2, 222, 231],
  [13, 252, 261],
  [20, 262, 271],
  [22, 272, 281],
]) {
  const ref = published.find((p) => p.number === number)
  assert.ok(ref?.head && ref.merged === false)
  const entries = JSON.parse(git('show', `${ref.head}:wiki/planning/state.json`)).ideas.filter(
    (p) => Number(p.id.split('-')[1]) >= first && Number(p.id.split('-')[1]) <= last
  )
  assert.equal(entries.length, 10)
  entries.forEach((p) => {
    assert.ok(!occupied.has(p.id))
    occupied.set(p.id, p.title)
  })
}
assert.equal(occupied.size, 281)
assert.equal(Math.max(...[...occupied.keys()].map((id) => Number(id.split('-')[1]))), 281)
assert.ok(newIds.every((id) => !occupied.has(id)))
const state = await json('wiki/planning/state.json')
assert.equal(state.revision, originalState.revision + 1)
assert.equal(state.ideas.length, originalState.ideas.length + 10)
assert.deepEqual(state.ideas.slice(0, originalState.ideas.length), originalState.ideas)
const stripState = (value) =>
  Object.fromEntries(
    Object.entries(value).filter(([key]) => !['revision', 'updatedAt', 'ideas'].includes(key))
  )
assert.deepEqual(stripState(state), stripState(originalState))
const originalAssess = JSON.parse(old('wiki/planning/assessments.json'))
const assess = await json('wiki/planning/assessments.json')
assert.deepEqual(assess.ideas.slice(0, originalAssess.ideas.length), originalAssess.ideas)
for (const [id, source] of Object.entries(originalAssess.sources))
  assert.deepEqual(assess.sources[id], source)
assert.equal(assess.ideas.length, originalAssess.ideas.length + 10)

// Check each independent cycle, written conversation, rating and real backlog card.
const catalog = await readPlanningCatalog()
const mine = catalog.tasks.filter((t) => newIds.some((id) => t.id.startsWith(`${id}-`)))
assert.equal(mine.length, 42)
assert.ok(mine.every((t) => t.status === 'backlog' && t.acceptance.length >= 3))
const allIds = new Set(catalog.tasks.map((t) => t.id))
const ownTasks = new Map(mine.map((t) => [t.id, t]))
const visit = (id, path = []) => {
  assert.ok(!path.includes(id), [...path, id].join(' -> '))
  for (const dep of ownTasks.get(id)?.dependencies ?? []) {
    assert.ok(allIds.has(dep), `${id}: missing ${dep}`)
    if (ownTasks.has(dep)) visit(dep, [...path, id])
  }
}
mine.forEach((t) => visit(t.id))
const headings = [
  'Суть, потребность',
  'Основа проекта',
  'Сценарий от',
  'Правила, состояния',
  'Написанные разговоры',
  'Интерфейс, обучение',
  'Первый выпуск',
  'Риски баланса',
  'Наблюдаемая приёмка',
  'Оценка, изученный',
]
for (const p of proposals) {
  const text = await read(`wiki/articles/${p.id}.md`)
  assert.ok(text.length > 9000, `${p.id}: insufficient detail`)
  assert.ok(p.balanceHypothesis?.startsWith('Стартовая гипотеза баланса:'))
  assert.ok(text.includes(p.balanceHypothesis))
  assert.ok(
    headings.every((heading) => text.includes(heading)),
    p.id
  )
  for (const word of [p.title, p.actorId, p.place, p.summary, p.record, p.neighbor])
    assert.ok(text.includes(word), `${p.id}: missing ${word}`)
  assert.equal((text.match(new RegExp(`\\*\\*F${p.n}-\\d{2}`, 'g')) ?? []).length, 6)
  assert.ok(text.includes('сейчас не выполнены') && text.includes('не проверена'))
  for (const dialog of p.dialog) {
    assert.ok(text.includes(dialog[2]))
    for (const answer of dialog[3])
      assert.ok(
        answer.every((value) => text.includes(value)),
        p.id
      )
  }
  const row = state.ideas.find((d) => d.id === p.id)
  assert.equal(row.status, 'proposed')
  assert.deepEqual(row.linkedEpics, [`${p.id.toLowerCase()}--${p.id}`])
  const grade = assess.ideas.find((d) => d.idea === p.id)
  for (const [i, key] of ['usefulness', 'interest', 'fit', 'synergy', 'cost', 'risk'].entries()) {
    assert.equal(grade[key], p.scores[i])
    assert.ok(grade[key] >= 1 && grade[key] <= 5)
  }
  assert.equal(grade.familiarity, null)
  assert.equal(grade.confidence, 'hypothesis')
  assert.equal(
    grade.value,
    6 * grade.usefulness + 6 * grade.interest + 5 * grade.fit + 3 * grade.synergy
  )
  assert.ok(grade.audience && grade.prototype && grade.analogue && assess.sources[grade.source])
  const tasks = mine.filter((t) => t.id.startsWith(`${p.id}-`))
  assert.equal(tasks.length, p.stages.length)
  tasks
    .filter((t) => !t.id.endsWith('-01'))
    .forEach((t) => {
      assert.ok(t.dependencies.includes('VMAP-003') && t.dependencies.includes('IDEA-232-04'), t.id)
    })
}
const editor = catalog.tasks.find((p) => p.id === 'IDEA-REVIEW-20261028-EVENING')
assert.equal(editor?.status, 'in_progress')
assert.ok(editor.source.includes('wiki-workspace'))
const publication = await json(`${out}/publication.json`)
assert.equal(publication.status, 'in_progress')
assert.equal(publication.editorialTask, editor.id)
assert.equal(publication.number, 24)
assert.ok(editor.result.includes(publication.pr))
assert.equal(publication.balanceHypothesesAdded, 10)

// Existing sources/index entries must remain intact; the date creates no shared gameplay epic.
const originalSources = JSON.parse(old('wiki/planning/sources.json'))
const sources = await json('wiki/planning/sources.json')
const previousPlans = structuredClone(originalSources.plans)
previousPlans.find((p) => p.id === 'wiki').expected += 1
assert.deepEqual(sources.plans.slice(0, previousPlans.length), previousPlans)
assert.deepEqual(sources.queues, originalSources.queues)
assert.equal(sources.plans.length, previousPlans.length + 10)
for (const plan of sources.plans.slice(previousPlans.length)) {
  assert.ok(newIds.includes(plan.epics[0].id))
  assert.equal(plan.group, proposals.find((p) => p.id === plan.epics[0].id).group)
}
const originalIndex = JSON.parse(old('wiki/articles/index.json'))
const index = await json('wiki/articles/index.json')
assert.deepEqual(index.slice(0, originalIndex.length), originalIndex)
assert.equal(index.length, originalIndex.length + 13)
assert.ok(
  (await read('docs/backlog/wiki-workspace-2026-10/README.md')).startsWith(
    old('docs/backlog/wiki-workspace-2026-10/README.md')
  )
)
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
  'wiki/scripts/editorial-review28-evening-audit.mjs',
  'wiki/articles/resident-workshops-contracts.md',
  'wiki/articles/resident-workshops-register.md',
  'wiki/articles/creative-review-2026-10-28-evening.md',
  ...newIds.map((id) => `wiki/articles/${id}.md`),
])
const changed = git('diff', '--name-only', '-z', base, '--').toString().split('\0').filter(Boolean)
assert.ok(
  changed.every(
    (path) =>
      allowed.has(path) ||
      path.startsWith(`${out}/`) ||
      newIds.some((id) => path.startsWith(`docs/epics/ideas/${id.toLowerCase()}/`))
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
      priorAssessmentsPreserved: originalAssess.ideas.length,
      reservedPriorIds: occupied.size,
      nextUsed: [282, 291],
      independentEpics: 10,
      implementationBacklog: 42,
      editorStatus: editor.status,
      dialogueNodes: 20,
      writtenReplies: 60,
      futureScenarios: 60,
      futureScenariosRun: 0,
      gameplayImplemented: false,
      dependencyGraph: 'valid',
      oldQueuesPreserved: true,
      proposalSHA256: hash(await read(`${out}/proposals.json`)),
      publishedHeads: published,
    },
    null,
    2
  )
)
