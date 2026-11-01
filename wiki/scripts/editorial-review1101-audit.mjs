import assert from 'node:assert/strict'
import { readFile } from 'node:fs/promises'
import { createHash } from 'node:crypto'
import { execFileSync } from 'node:child_process'
import { fileURLToPath } from 'node:url'
import { readPlanningCatalog } from './planning-catalog.mjs'

// Historical comparisons stay on the reviewed main tree, independent of caller cwd/Git.
const root = fileURLToPath(new URL('../../', import.meta.url))
const base = 'db28a6d3ef178c193200a5d33ad2107bcf148722'
const out = 'docs/reports/creative/2026-11-01'
const env = Object.fromEntries(Object.entries(process.env).filter(([k]) => !k.startsWith('GIT_')))
const git = (...args) =>
  execFileSync('git', ['--no-optional-locks', '-C', root, ...args], {
    env,
    encoding: 'utf8',
    maxBuffer: 64 * 1024 * 1024,
  })
const read = (p) => readFile(root + p, 'utf8')
const json = async (p) => JSON.parse(await read(p))
const old = (p) => git('show', `${base}:${p}`)
const sha = (s) => createHash('sha256').update(s).digest('hex')
const data = await json(`${out}/proposals.json`)
const ideas = data.ideas
const ids = ideas.map((p) => p.id)
assert.equal(data.base, base)
assert.equal(data.gameplayImplemented, false)
assert.deepEqual(
  ids,
  Array.from({ length: 10 }, (_, n) => `IDEA-${322 + n}`)
)
const reserved = await json(`${out}/occupied-ids.json`)
assert.equal(Object.keys(reserved.ideas).length, 321)
assert.ok(ids.every((id) => !reserved.ideas[id]))
const refs = await json(`${out}/published-refs.json`)
assert.equal(refs.length, 10)
for (const ref of refs) {
  const past = JSON.parse(git('show', `${ref.head}:wiki/planning/state.json`))
  assert.deepEqual(
    reserved.byRef[ref.head],
    past.ideas.map((p) => p.id)
  )
}
const branches = await json(`${out}/published-branches.json`)
assert.equal(branches.length, 20)
for (const branch of branches) {
  const past = JSON.parse(git('show', `${branch.head}:wiki/planning/state.json`))
  assert.equal(branch.count, past.ideas.length)
  assert.ok(past.ideas.every((p) => !ids.includes(p.id)))
}
const plan = await json(`${out}/plan.json`)
assert.equal(sha(await read(`${out}/previous-plan.json`)), plan.previousPlanSHA256)
assert.equal(
  sha(git('show', `${data.previousReviewHead}:docs/reports/creative/2026-10-31/plan.json`)),
  plan.previousPlanSHA256
)

// Append proposals without importing pending decisions or rewriting any existing history.
const state = await json('wiki/planning/state.json')
const before = JSON.parse(old('wiki/planning/state.json'))
assert.deepEqual(state.ideas.slice(0, before.ideas.length), before.ideas)
assert.equal(state.ideas.length, 251)
assert.equal(state.revision, before.revision + 1)
for (const key of Object.keys(before).filter(
  (k) => !['ideas', 'revision', 'updatedAt'].includes(k)
))
  assert.deepEqual(state[key], before[key])
const grades = await json('wiki/planning/assessments.json')
const oldGrades = JSON.parse(old('wiki/planning/assessments.json'))
assert.deepEqual(grades.ideas.slice(0, oldGrades.ideas.length), oldGrades.ideas)
assert.equal(grades.ideas.length, 90)
for (const [key, value] of Object.entries(oldGrades.sources))
  assert.deepEqual(grades.sources[key], value)
const sources = await json('wiki/planning/sources.json')
const oldSources = JSON.parse(old('wiki/planning/sources.json'))
oldSources.plans.find((p) => p.id === 'wiki').expected += 1
assert.deepEqual(sources.plans.slice(0, oldSources.plans.length), oldSources.plans)
assert.deepEqual(sources.queues, oldSources.queues)
assert.equal(sources.plans.length, oldSources.plans.length + 10)
const index = await json('wiki/articles/index.json')
const oldIndex = JSON.parse(old('wiki/articles/index.json'))
assert.deepEqual(index.slice(0, oldIndex.length), oldIndex)
assert.equal(index.length, oldIndex.length + 12)
assert.ok(
  (await read('docs/backlog/wiki-workspace-2026-10/README.md')).startsWith(
    old('docs/backlog/wiki-workspace-2026-10/README.md')
  )
)

// Use the production parser: task status, accepted IDs, real links and dependencies matter.
const catalog = await readPlanningCatalog()
const all = new Map(catalog.tasks.map((t) => [t.id, t]))
const tasks = catalog.tasks.filter((t) => ids.some((id) => t.id.startsWith(id + '-')))
assert.equal(tasks.length, 44)
assert.ok(tasks.every((t) => t.status === 'backlog' && t.acceptance.length >= 3))
const mine = new Map(tasks.map((t) => [t.id, t]))
function visit(id, path = []) {
  assert.ok(!path.includes(id), [...path, id].join(' → '))
  for (const dep of mine.get(id)?.dependencies ?? []) {
    assert.ok(all.has(dep), `${id}: missing dependency ${dep}`)
    if (mine.has(dep)) visit(dep, [...path, id])
  }
}
tasks.forEach((t) => visit(t.id))
const actors = ideas.flatMap((p) => p.actors)
assert.equal(actors.length, 15)
assert.equal(new Set(actors.map((a) => a[0])).size, 15)
assert.ok(actors.every((a) => a[2].startsWith('взросл')))
assert.equal(new Set(ideas.map((p) => p.place)).size, 10)
assert.equal(
  ideas.reduce((n, p) => n + p.dialogs.length, 0),
  31
)
assert.equal(
  ideas.reduce((n, p) => n + p.dialogs.reduce((m, d) => m + d.replies.length, 0), 0),
  93
)
const npcSource = old('scripts/systems/quest_system.gd')
for (const p of ideas) {
  const text = await read(`wiki/articles/${p.id}.md`)
  assert.ok(text.length > 10000)
  for (const part of [
    'Суть, потребность',
    'Основа, последние',
    'Пошаговый игровой',
    'Правила, состояния',
    'Написанные разговоры',
    'Интерфейс, обучение',
    'Первый полезный выпуск',
    'Риски и способы',
    'Наблюдаемая приёмка',
    'Оценки, референс',
  ])
    assert.ok(text.includes(part))
  for (const value of [
    p.summary,
    p.basis,
    p.balance,
    p.record,
    ...p.rules,
    ...p.tests,
    ...(p.content ?? []),
  ])
    assert.ok(text.includes(value), `${p.id}: missing canonical prose`)
  assert.ok(npcSource.includes(`"location":"${p.parent}"`), `${p.id}: parent not verified`)
  for (const actor of p.actors) assert.ok(!npcSource.includes(`"id":"${actor[0]}"`))
  assert.equal(p.flow.length, 5)
  assert.equal(p.tests.length, 6)
  assert.ok(text.includes(`Геометрия принадлежит ${p.geometryOwner}`))
  assert.ok(all.has(p.geometryOwner))
  p.dialogs.forEach((d, j) => {
    assert.equal(d.replies.length, 3)
    assert.ok(text.includes(d.speaker) && text.includes(d.line))
    d.replies.forEach((v, k) => {
      for (const value of [
        v.hero,
        v.reply,
        v.effect,
        `${p.id}-D${String(j + 1).padStart(2, '0')}-${k + 1}`,
      ])
        assert.ok(text.includes(value))
    })
  })
  for (const t of tasks.filter((t) => t.id.startsWith(p.id + '-') && !t.id.endsWith('-01')))
    for (const dep of p.dependencies) assert.ok(t.dependencies.includes(dep))
  const decision = state.ideas.find((v) => v.id === p.id)
  assert.equal(decision.status, 'proposed')
  assert.equal(decision.group, p.group)
  assert.deepEqual(decision.linkedEpics, [`${p.id.toLowerCase()}--${p.id}`])
  const grade = grades.ideas.find((v) => v.idea === p.id)
  assert.deepEqual(
    ['usefulness', 'interest', 'fit', 'synergy', 'cost', 'risk'].map((k) => grade[k]),
    p.scores
  )
  assert.equal(grade.value, 6 * p.scores[0] + 6 * p.scores[1] + 5 * p.scores[2] + 3 * p.scores[3])
  assert.equal(grade.familiarity, null)
  assert.equal(grade.confidence, 'hypothesis')
  assert.equal(grades.sources[grade.source].url, p.source.url)
  assert.ok(text.includes(p.source.url))
}
assert.ok(ideas.find((p) => p.id === 'IDEA-324').dependencies.includes('CASE-16'))
assert.equal(all.get('IDEA-REVIEW-20261101').status, 'in_progress')
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

// No implementation or earlier reports are part of this editorial proposal.
const allowed = new Set([
  'TESTING.md',
  'VERSION',
  'project.godot',
  'Бабушкина ферма.app/Contents/Info.plist',
  'docs/backlog/README.md',
  'docs/backlog/wiki-workspace-2026-10/README.md',
  'docs/epics/ideas/README.md',
  'wiki/articles/idea-feature-epics.md',
  'wiki/articles/index.json',
  'wiki/planning/state.json',
  'wiki/planning/assessments.json',
  'wiki/planning/sources.json',
  'wiki/scripts/editorial-review1101-audit.mjs',
])
for (const name of git('diff', '--name-only', '-z', base, '--').split('\0').filter(Boolean))
  assert.ok(
    allowed.has(name) ||
      /^docs\/epics\/ideas\/idea-3(2[2-9]|3[01])\//.test(name) ||
      name.startsWith(out + '/') ||
      /^wiki\/articles\/IDEA-3(2[2-9]|3[01])\.md$/.test(name) ||
      [
        'wiki/articles/creative-review-2026-11-01.md',
        'wiki/articles/river-and-memory-register.md',
      ].includes(name),
    `outside editorial scope: ${name}`
  )
assert.equal(
  (await read('project.godot')).replace(/config\/version="[^"]+"/, 'config/version="VERSION"'),
  old('project.godot').replace(/config\/version="[^"]+"/, 'config/version="VERSION"')
)
console.log(
  JSON.stringify(
    {
      base,
      newIdeas: 10,
      priorIdeasPreserved: 241,
      priorAssessmentsPreserved: 80,
      reservedPriorIds: 321,
      publishedBranches: branches.length,
      independentEpics: 10,
      implementationBacklog: 44,
      proposedAdultNPCs: 15,
      dialogueNodes: 31,
      writtenReplies: 93,
      futureScenarios: 60,
      futureScenariosRun: 0,
      editorStatus: 'in_progress',
      dependencyGraph: 'valid',
      oldQueuesPreserved: true,
      gameplayImplemented: false,
      proposalSHA256: sha(await read(`${out}/proposals.json`)),
    },
    null,
    2
  )
)
