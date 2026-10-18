import test from 'node:test'
import assert from 'node:assert/strict'
import { readFile, writeFile, mkdtemp, rm, mkdir, symlink } from 'node:fs/promises'
import { join } from 'node:path'
import { tmpdir } from 'node:os'
import { readPlanningCatalog, markdownTasks, sourcePath } from '../scripts/planning-catalog.mjs'
import { createPlanningStore, agentBrief } from '../scripts/planning-store.mjs'
import { createWikiServer, listen } from '../scripts/server.mjs'
import { wikiRoot } from '../scripts/runtime.mjs'

const catalog = await readPlanningCatalog()
// Решения пользователя меняются во время разработки и не являются fixture теста.
const seed = {
  schema: 1,
  revision: 0,
  groups: [...new Set([...catalog.epics.map((epic) => epic.group), 'world', 'visual'])].map(
    (id) => ({ id, title: id })
  ),
  epicGroups: {},
  ideas: [
    {
      id: 'IDEA-001',
      title: 'Пробная идея',
      description: 'Замысел для проверки',
      group: 'visual',
      status: 'proposed',
      notes: '',
      linkedEpics: [],
      history: [],
    },
    {
      id: 'IDEA-002',
      title: 'Существующая постановка',
      description: 'Уже есть карточки',
      group: 'world',
      status: 'planned',
      notes: '',
      linkedPlans: ['living-world'],
      linkedEpics: [],
      history: [],
    },
  ],
}

/** Даёт каждому сценарию собственную запись без изменений рабочего проекта. */
async function fixture(t) {
  const root = await mkdtemp(join(tmpdir(), 'farm-wiki-planning-'))
  t.after(() => rm(root, { recursive: true, force: true }))
  const file = join(root, 'state.json')
  await writeFile(file, JSON.stringify(seed))
  const store = createPlanningStore(file)
  return {
    root,
    file,
    store,
    change: (action) => store.change({ revision: 0, ...action }, catalog),
  }
}

/** Поднимает настоящий loopback API с временным хранилищем и общим каталогом только для чтения. */
async function apiFixture(t, existing) {
  const fixtureData = existing ?? (await fixture(t))
  const server = createWikiServer(fixtureData.root, {
    planning: { store: fixtureData.store, loadCatalog: async () => catalog },
  })
  const port = await listen(server, 0)
  t.after(() => {
    server.close()
    server.closeAllConnections()
  })
  const url = `http://127.0.0.1:${port}`
  const post = (action, headers = {}) =>
    fetch(`${url}/__wiki/planning/change`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', 'X-Wiki-Planning': '1', ...headers },
      body: JSON.stringify({ revision: 0, ...action }),
    })
  return { ...fixtureData, server, url, post }
}

// Сценарий: все существующие планы открыты в общей навигации.
// Исходное состояние: актуальные JSON и редакционные карточки Markdown.
// Ожидаемый результат: импорт полон, фактические статусы и критерии сохранены.
test('planning imports every registered plan and preserves source statuses and acceptance', async () => {
  const sources = JSON.parse(await readFile(join(wikiRoot, 'planning/sources.json'), 'utf8'))
  for (const plan of sources.plans)
    assert.equal(catalog.tasks.filter((task) => task.plan === plan.id).length, plan.expected)
  assert.ok(catalog.plans.length >= sources.plans.length)
  assert.ok(catalog.epics.length >= 58)
  assert.equal(catalog.tasks.filter((task) => task.plan === 'living-world').length, 200)
  assert.equal(catalog.tasks.find((task) => task.id === 'WATER-01').status, 'done')
  assert.equal(catalog.tasks.find((task) => task.id === 'WATER-02').status, 'blocked')
  assert.deepEqual(catalog.tasks.find((task) => task.id === 'WATER-04').dependencies, [
    'WATER-02',
    'WATER-03',
  ])
  assert.equal(catalog.tasks.find((task) => task.id === 'FAUNA-06').status, 'backlog')
  assert.ok(catalog.tasks.find((task) => task.id === 'FAUNA-06').acceptance.length >= 3)
  assert.ok(catalog.tasks.find((task) => task.id === 'ECHO-02').dependencies.includes('ECHO-01'))
  assert.ok(
    catalog.tasks.find((task) => task.id === 'VPIPELINE-004').content.includes('acceptance')
  )
  const { workspace } = { workspace: await createPlanningStore().read(catalog) }
  assert.ok(workspace.ideas.some((idea) => idea.id === 'IDEA-002'))
})

// Сценарий: другой агент добавил стандартный план без изменения реестра Wiki.
// Исходное состояние: TASKS.md с одной карточкой, затем с двумя.
// Ожидаемый результат: новые планы и карточки видны без ручного дублирования.
test('new standard plans are discovered with live task counts', async (t) => {
  const { root } = await fixture(t)
  await mkdir(join(root, 'docs/epics/sample-2026-10'), { recursive: true })
  await mkdir(join(root, 'wiki/articles'), { recursive: true })
  await writeFile(join(root, 'wiki/articles/index.json'), '[]')
  const manifest = join(root, 'sources.json')
  await writeFile(manifest, JSON.stringify({ schema: 1, discoverPlans: true, plans: [] }))
  const file = join(root, 'docs/epics/sample-2026-10/TASKS.md')
  const first = '# Пробный план\n\n## TEST-01 — Первая\n\n**Статус:** backlog\n'
  await writeFile(file, first)
  let actual = await readPlanningCatalog({ root, manifest })
  assert.equal(actual.plans[0].id, 'sample')
  assert.equal(actual.tasks.length, 1)
  await writeFile(file, first + '\n## TEST-02 — Вторая\n\n**Статус:** ready\n')
  actual = await readPlanningCatalog({ root, manifest })
  assert.equal(actual.tasks.length, 2)
  assert.equal(actual.tasks[1].status, 'ready')
})

// Сценарий: Markdown содержит указатель и карточки, а статус удалён либо неизвестен.
// Исходное состояние: одна собственная карточка.
// Ожидаемый результат: таблица не создаёт дубликатов; потерянный статус не превращается в backlog.
test('markdown adapter ignores index entries and refuses an unstated status', () => {
  const epic = { key: 'test--TEST', source: 'card.md' },
    plan = { id: 'test' }
  const text =
    '| TEST-01 | preview |\n\n## TEST-01 — Реальная задача\n\n**Статус:** done\n\n**Приёмка:**\n\n- Условие.\n'
  assert.equal(markdownTasks(text, epic, plan).length, 1)
  assert.equal(markdownTasks(text, epic, plan)[0].status, 'done')
  assert.throws(
    () => markdownTasks(text.replace('Статус:** done', 'Статус:** unknown'), epic, plan),
    /статуса/
  )
  assert.throws(
    () => markdownTasks(text.replace('| TEST-01 | preview |', '| TEST-01 | blocked |'), epic, plan),
    /расходятся/
  )
})

// Сценарий: источник плана пытается открыть файл за пределами проекта.
// Исходное состояние: временная папка с символической ссылкой наружу.
// Ожидаемый результат: исходные пути и ссылки одинаково ограничены.
test('planning sources cannot escape the repository through paths or symlinks', async (t) => {
  const { root } = await fixture(t)
  await mkdir(join(root, 'inside'))
  await symlink(join(root, 'state.json'), join(root, 'inside/outside.json'))
  await assert.rejects(() => sourcePath(join(root, 'inside'), '../state.json'), /выходит/)
  await assert.rejects(() => sourcePath(join(root, 'inside'), 'outside.json'), /выходит/)
})

// Сценарий: пользователь одобряет идею и перезапускает хранилище.
// Исходное состояние: proposal IDEA-001, реализация ещё не принята.
// Ожидаемый результат: сохранены статус, история и ревизия; задачи не меняются.
test('approval survives a new store instance and leaves implementation untouched', async (t) => {
  const { file, change } = await fixture(t)
  const before = JSON.stringify(catalog.tasks)
  await change({ type: 'set-idea-status', id: 'IDEA-001', status: 'approved' })
  const result = await createPlanningStore(file).read(catalog)
  const idea = result.ideas.find((item) => item.id === 'IDEA-001')
  assert.equal(idea.status, 'approved')
  assert.deepEqual(idea.history[0].from, 'proposed')
  assert.equal(result.revision, 1)
  assert.match(agentBrief(idea), /AGENTS\.md/)
  assert.equal(JSON.stringify(catalog.tasks), before)
})

// Сценарий: две вкладки сохраняют решения по одной ревизии.
// Исходное состояние: обе видели revision 0.
// Ожидаемый результат: одна запись проходит, другая явно конфликтует без перезаписи.
test('stale and simultaneous edits cannot overwrite a newer decision', async (t) => {
  const { store, change } = await fixture(t)
  const results = await Promise.allSettled([
    change({ type: 'set-idea-status', id: 'IDEA-001', status: 'approved' }),
    change({ type: 'set-idea-status', id: 'IDEA-001', status: 'archived' }),
  ])
  assert.equal(results.filter((value) => value.status === 'fulfilled').length, 1)
  assert.equal(results.find((value) => value.status === 'rejected').reason.status, 409)
  const after = await store.read(catalog)
  await assert.rejects(
    () => change({ type: 'create-group', title: 'Устаревшая запись' }),
    (error) => error.status === 409
  )
  assert.deepEqual(await store.read(catalog), after)
})

// Сценарий: идея превращается в постановку, затем возвращается на уточнение.
// Исходное состояние: предложение и существующий эпик.
// Ожидаемый результат: нельзя закрыть проработку без реальных связей; возврат не удаляет задачи.
test('refinement needs approval and actual epics and can be reopened', async (t) => {
  const { store, change } = await fixture(t)
  const epic = catalog.epics[0].key
  await assert.rejects(
    () => change({ type: 'plan-idea', id: 'IDEA-001', epics: [epic] }),
    /одобрите/
  )
  await change({ type: 'set-idea-status', id: 'IDEA-001', status: 'approved' })
  await assert.rejects(
    () => change({ revision: 1, type: 'plan-idea', id: 'IDEA-001', epics: [] }),
    /нужны/
  )
  await change({ revision: 1, type: 'set-idea-status', id: 'IDEA-001', status: 'refining' })
  await change({ revision: 2, type: 'plan-idea', id: 'IDEA-001', epics: [epic, epic] })
  let idea = (await store.read(catalog)).ideas.find((item) => item.id === 'IDEA-001')
  assert.equal(idea.status, 'planned')
  assert.deepEqual(idea.linkedEpics, [epic])
  await change({ revision: 3, type: 'set-idea-status', id: 'IDEA-001', status: 'approved' })
  idea = (await store.read(catalog)).ideas.find((item) => item.id === 'IDEA-001')
  assert.deepEqual(idea.linkedEpics, [epic])
})

// Сценарий: новую идею добавляют после редакционной статьи с большим номером.
// Исходное состояние: статья существует, но ещё не сохранена редакционной операцией.
// Ожидаемый результат: статья появляется предложением, новый ID не дублирует её номер.
test('new ideas and article ideas share one collision-free sequence', async (t) => {
  const { store } = await fixture(t)
  const extended = {
    ...catalog,
    ideaArticles: [
      ...catalog.ideaArticles,
      { id: 'IDEA-999', title: 'Новая статья', description: 'Новый замысел', article: 'IDEA-999' },
    ],
  }
  const before = await store.read(extended)
  assert.equal(before.ideas.find((idea) => idea.id === 'IDEA-999').status, 'proposed')
  const after = await store.change(
    { revision: 0, type: 'create-idea', title: 'Сад', description: 'Тихое место', group: 'world' },
    extended
  )
  assert.equal(after.ideas.at(-1).id, 'IDEA-1000')
  const edited = await store.change(
    {
      revision: 1,
      type: 'edit-idea',
      id: 'IDEA-1000',
      title: 'Тихий сад',
      description: 'Место для птиц',
      group: 'world',
      notes: 'Без обязательной награды',
    },
    extended
  )
  assert.equal(edited.ideas.at(-1).notes, 'Без обязательной награды')
})

// Сценарий: пользователь переименовывает группу и переносит эпик.
// Исходное состояние: задачи принадлежат прежнему плану.
// Ожидаемый результат: меняется только группировка; исходные владельцы и статусы не меняются.
test('group creation renaming and moving do not duplicate or mutate tasks', async (t) => {
  const { store, change } = await fixture(t)
  const before = JSON.stringify(catalog)
  const first = await change({ type: 'create-group', title: 'Первая неделя' })
  const id = first.groups.at(-1).id
  await change({ revision: 1, type: 'rename-group', id, title: 'Первые семь дней' })
  await change({ revision: 2, type: 'move-epic', epic: catalog.epics[0].key, group: id })
  assert.equal((await store.read(catalog)).epicGroups[catalog.epics[0].key], id)
  assert.equal(JSON.stringify(catalog), before)
})

// Сценарий: неверное действие, чужая группа и пустой текст.
// Исходное состояние: валидный файл и нулевая ревизия.
// Ожидаемый результат: файл остаётся побайтно прежним, блокировка освобождается.
test('invalid mutations are atomic and release the write lock', async (t) => {
  const { file, change } = await fixture(t)
  const original = await readFile(file)
  for (const action of [
    { type: 'move-epic', epic: 'unknown', group: 'world' },
    { type: 'create-idea', title: '', description: 'Text', group: 'world' },
    { type: 'create-idea', title: 'Name', description: 'Text', group: 'unknown' },
    { type: 'set-idea-status', id: 'IDEA-001', status: 'done' },
    { type: 'plan-idea', id: 'IDEA-001', epics: ['../outside'] },
  ]) {
    await assert.rejects(() => change(action))
    assert.deepEqual(await readFile(file), original)
    await assert.rejects(() => readFile(`${file}.lock`), { code: 'ENOENT' })
  }
  await change({ type: 'create-group', title: 'После отказа' })
})

// Сценарий: повреждённый файл редакционных решений.
// Исходное состояние: JSON не читается.
// Ожидаемый результат: нет молчаливого сброса в пустое хранилище.
test('corrupt saved state is never replaced with a blank workspace', async (t) => {
  const { file, store, change } = await fixture(t)
  await writeFile(file, '{broken')
  await assert.rejects(() => store.read(catalog))
  await assert.rejects(() => change({ type: 'create-group', title: 'Нельзя потерять старое' }))
  assert.equal(await readFile(file, 'utf8'), '{broken')
})

// Сценарий: одобрение из браузера, запрос очереди и перезапуск сервера.
// Исходное состояние: локальный API, временный файл.
// Ожидаемый результат: изменение сохранено и видно агенту и новому процессу.
test('HTTP approval queue and server restart preserve decisions', async (t) => {
  const fixtureData = await fixture(t)
  const { url, post } = await apiFixture(t, fixtureData)
  let response = await fetch(`${url}/__wiki/planning`)
  assert.equal(response.status, 200)
  assert.equal((await response.json()).readOnly, false)
  assert.equal(response.headers.get('cache-control'), 'no-store')
  response = await post({ type: 'set-idea-status', id: 'IDEA-001', status: 'approved' })
  assert.equal(response.status, 200)
  const queue = await (await fetch(`${url}/__wiki/planning/queue`)).json()
  assert.equal(queue.ideas.length, 1)
  assert.match(queue.ideas[0].brief, /IDEA-001/)
  const restarted = await apiFixture(t, {
    ...fixtureData,
    store: createPlanningStore(fixtureData.file),
  })
  const persisted = await (await fetch(`${restarted.url}/__wiki/planning/queue`)).json()
  assert.deepEqual(persisted, queue)
  response = await post({ type: 'set-idea-status', id: 'IDEA-001', status: 'archived' })
  assert.equal(response.status, 409)
})

// Сценарий: сборка запущена статическим сервером без API планирования.
// Исходное состояние: доступен только сохранённый обзор.
// Ожидаемый результат: нет скрытой возможности записи рабочего реестра.
test('static review exposes no planning mutation API', async (t) => {
  const { root, file } = await fixture(t)
  const before = await readFile(file)
  const server = createWikiServer(root, { planning: false })
  const port = await listen(server, 0)
  t.after(() => {
    server.close()
    server.closeAllConnections()
  })
  const url = `http://127.0.0.1:${port}`
  assert.equal((await fetch(`${url}/__wiki/planning`)).status, 404)
  assert.equal((await fetch(`${url}/__wiki/planning/change`, { method: 'POST' })).status, 405)
  assert.equal((await (await fetch(`${url}/__wiki/status`)).json()).planning, 0)
  assert.deepEqual(await readFile(file), before)
})

// Сценарий: чужая страница, простой HTML POST и испорченный JSON.
// Исходное состояние: локальная Wiki с возможностью записи.
// Ожидаемый результат: браузерный origin и явный JSON-запрос обязательны; запись не происходит.
test('HTTP writes reject cross-origin malformed oversized and non-JSON requests', async (t) => {
  const { url, post, file } = await apiFixture(t)
  const before = await readFile(file)
  const action = { type: 'set-idea-status', id: 'IDEA-001', status: 'approved' }
  assert.equal((await post(action, { Origin: 'https://foreign.invalid' })).status, 403)
  assert.equal((await post(action, { 'X-Wiki-Planning': '' })).status, 403)
  assert.equal((await post(action, { 'Content-Type': 'text/plain' })).status, 403)
  assert.equal(
    (
      await fetch(`${url}/__wiki/planning/change`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json', 'X-Wiki-Planning': '1' },
        body: '{',
      })
    ).status,
    400
  )
  assert.equal((await post({ ...action, notes: 'x'.repeat(280000) })).status, 413)
  assert.equal((await fetch(`${url}/__wiki/planning/missing`)).status, 404)
  assert.deepEqual(await readFile(file), before)
})
