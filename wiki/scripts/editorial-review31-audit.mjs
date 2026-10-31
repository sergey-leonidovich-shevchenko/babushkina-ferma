import assert from 'node:assert/strict'
import { readFile } from 'node:fs/promises'
import { createHash } from 'node:crypto'
import { execFileSync } from 'node:child_process'
import { fileURLToPath } from 'node:url'
import { readPlanningCatalog } from './planning-catalog.mjs'

// Pin historical comparisons to the reviewed main tree, never the caller's Git context.
const root = fileURLToPath(new URL('../../', import.meta.url))
const base = '7d8c62be8a98edcd34cf1ede3919625295c5076e'
const out = 'docs/reports/creative/2026-10-31'
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
const hash = (s) => createHash('sha256').update(s).digest('hex')
const data = await json(`${out}/proposals.json`)
const ideas = data.ideas
const ids = ideas.map((p) => p.id)
assert.equal(data.base, base)
assert.deepEqual(
  ids,
  Array.from({ length: 10 }, (_, n) => `IDEA-${312 + n}`)
)
assert.equal(data.gameplayImplemented, false)
const reserved = await json(`${out}/occupied-ids.json`)
assert.equal(Object.keys(reserved.ideas).length, 311)
assert.ok(ids.every((id) => !reserved.ideas[id]))
const refs = await json(`${out}/published-refs.json`)
assert.equal(refs.length, 9)
for (const ref of refs) {
  const past = JSON.parse(git('show', `${ref.head}:wiki/planning/state.json`))
  assert.deepEqual(
    reserved.byRef[ref.head],
    past.ideas.map((p) => p.id)
  )
}
const plan = await json(`${out}/plan.json`)
assert.equal(hash(await read(`${out}/previous-plan.json`)), plan.previousPlanSHA256)
assert.equal(
  hash(git('show', `${data.previousReviewHead}:docs/reports/creative/2026-10-30/plan.json`)),
  plan.previousPlanSHA256
)

// Preserve decisions and queue ownership while appending this review's own records.
const state = await json('wiki/planning/state.json')
const before = JSON.parse(old('wiki/planning/state.json'))
assert.equal(state.revision, before.revision + 1)
assert.deepEqual(state.ideas.slice(0, before.ideas.length), before.ideas)
assert.equal(state.ideas.length, before.ideas.length + 10)
for (const k of Object.keys(before).filter((k) => !['ideas', 'revision', 'updatedAt'].includes(k)))
  assert.deepEqual(state[k], before[k])
const grades = await json('wiki/planning/assessments.json')
const oldGrades = JSON.parse(old('wiki/planning/assessments.json'))
assert.deepEqual(grades.ideas.slice(0, oldGrades.ideas.length), oldGrades.ideas)
assert.equal(grades.ideas.length, oldGrades.ideas.length + 10)
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

// Use the application's real catalog parser to check tasks, dependencies and links.
const catalog = await readPlanningCatalog()
const all = new Map(catalog.tasks.map((t) => [t.id, t]))
const tasks = catalog.tasks.filter((t) => ids.some((id) => t.id.startsWith(id + '-')))
assert.equal(tasks.length, 43)
assert.ok(tasks.every((t) => t.status === 'backlog' && t.acceptance.length >= 3))
const mine = new Map(tasks.map((t) => [t.id, t]))
function visit(id, path = []) {
  assert.ok(!path.includes(id), [...path, id].join(' → '))
  for (const dep of mine.get(id)?.dependencies ?? []) {
    assert.ok(all.has(dep), `${id}: missing ${dep}`)
    if (mine.has(dep)) visit(dep, [...path, id])
  }
}
tasks.forEach((t) => visit(t.id))
const actors = ideas.flatMap((p) => p.actors)
assert.equal(actors.length, 14)
assert.equal(new Set(actors.map((a) => a[0])).size, 14)
assert.equal(actors.filter((a) => !a[2].includes('животное')).length, 13)
assert.equal(new Set(ideas.map((p) => p.place)).size, 10)
assert.equal(
  ideas.reduce((n, p) => n + p.dialogs.length, 0),
  30
)
assert.equal(
  ideas.reduce((n, p) => n + p.dialogs.reduce((m, d) => m + d[3].length, 0), 0),
  90
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
  for (const value of [p.summary, p.basis, p.balance, p.record, ...p.rules, ...p.tests])
    assert.ok(text.includes(value), `${p.id}: missing canonical text`)
  assert.ok(npcSource.includes(`"location":"${p.parent}"`), `${p.id}: parent not verified`)
  assert.ok(all.has(p.geometryOwner))
  assert.ok(text.includes(`Геометрия принадлежит ${p.geometryOwner}`))
  assert.equal(p.flow.length, 5)
  assert.equal(p.tests.length, 6)
  for (const [node, speaker, line, replies] of p.dialogs) {
    assert.ok(text.includes(speaker) && text.includes(line))
    assert.equal(replies.length, 3)
    replies.forEach(([hero, reply, effect], k) => {
      for (const value of [hero, reply, effect, `${p.id}-${node}-${k + 1}`])
        assert.ok(text.includes(value))
    })
  }
  for (const task of tasks.filter((t) => t.id.startsWith(p.id + '-') && !t.id.endsWith('-01')))
    for (const dep of p.dependencies) assert.ok(task.dependencies.includes(dep))
  const decision = state.ideas.find((v) => v.id === p.id)
  assert.equal(decision.status, 'proposed')
  assert.equal(decision.group, p.group)
  assert.deepEqual(decision.linkedEpics, [`${p.id.toLowerCase()}--${p.id}`])
  const grade = grades.ideas.find((v) => v.idea === p.id)
  assert.deepEqual(
    ['usefulness', 'interest', 'fit', 'synergy', 'cost', 'risk'].map((k) => grade[k]),
    p.scores
  )
  assert.equal(grade.value, p.scores[0] * 6 + p.scores[1] * 6 + p.scores[2] * 5 + p.scores[3] * 3)
  assert.equal(grade.familiarity, null)
  assert.equal(grade.confidence, 'hypothesis')
  assert.ok(grade.audience && grade.prototype && grade.analogue)
  assert.equal(grades.sources[grade.source].url, p.source[2])
  assert.ok(text.includes(p.source[2]))
}
const editor = all.get('IDEA-REVIEW-20261031')
assert.equal(editor.status, 'in_progress')
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

// The package changes editorial sources and mandatory version metadata only.
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
  'wiki/scripts/editorial-review31-audit.mjs',
])
for (const name of git('diff', '--name-only', '-z', base, '--').split('\0').filter(Boolean)) {
  assert.ok(
    allowed.has(name) ||
      /^docs\/epics\/ideas\/idea-3(1[2-9]|2[01])\//.test(name) ||
      name.startsWith(out + '/') ||
      /^wiki\/articles\/IDEA-3(1[2-9]|2[01])\.md$/.test(name) ||
      [
        'wiki/articles/creative-review-2026-10-31.md',
        'wiki/articles/ways-of-life-register.md',
      ].includes(name),
    `outside editorial scope: ${name}`
  )
}
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
      reservedPriorIds: 311,
      independentEpics: 10,
      implementationBacklog: 43,
      proposedAdultNPCs: 13,
      proposedAnimals: 1,
      dialogueNodes: 30,
      writtenReplies: 90,
      futureScenarios: 60,
      futureScenariosRun: 0,
      editorStatus: editor.status,
      dependencyGraph: 'valid',
      oldQueuesPreserved: true,
      gameplayImplemented: false,
      proposalSHA256: hash(await read(`${out}/proposals.json`)),
    },
    null,
    2
  )
)
