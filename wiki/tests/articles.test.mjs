import test from 'node:test'
import assert from 'node:assert/strict'
import { mkdtemp, readFile, rm, writeFile } from 'node:fs/promises'
import { tmpdir } from 'node:os'
import { join } from 'node:path'
import { articles } from '../scripts/articles.mjs'
import { wikiRoot } from '../scripts/runtime.mjs'

// Сценарий: самостоятельные статьи имеют постоянные адреса и сохраняют явный статус идеи.
// Исходное состояние: действующий редакционный список и новая собранная Wiki.
// Ожидаемый результат: обе статьи найдены поиском, иллюстрация локальна, внутренние ссылки ведут в Wiki.
test('visual pipeline and numbered idea are published and linked', async () => {
  const source = await articles()
  const ids = source.map((entry) => entry.id)
  assert.ok(ids.includes('visual-pipeline') && ids.includes('IDEA-001'))
  const catalog = JSON.parse(await readFile(join(wikiRoot, 'public/generated/catalog.json'), 'utf8'))
  const pipeline = catalog.entries.find((entry) => entry.id === 'visual-pipeline')
  const idea = catalog.entries.find((entry) => entry.id === 'IDEA-001')
  assert.match(pipeline.html, /generated\/illustrations\//)
  assert.doesNotMatch(pipeline.html, /<h1>/)
  assert.match(pipeline.html, /#\/guides\/IDEA-001/)
  assert.match(idea.html, /#\/guides\/visual-pipeline/)
  assert.match(idea.html, /Статус: предложение/)
  assert.ok(pipeline.tags.includes('VPIPELINE-001'))
  const resource = catalog.entries.find((entry) => entry.id === 'visual-resources')
  assert.match(resource.html, /generated\/illustrations\//)
  assert.match(resource.html, /prop\.rustic_table/)
  assert.match(resource.html, /#\/guides\/IDEA-001/)
  assert.match(idea.html, /#\/guides\/visual-resources/)
  const sampling = catalog.entries.find((entry) => entry.id === 'visual-sampling')
  assert.ok(sampling.tags.includes('VPIPELINE-003'))
  assert.equal((sampling.html.match(/<img /g) ?? []).length, 2)
  assert.match(sampling.html, /#\/guides\/visual-resources/)
  assert.match(resource.html, /#\/guides\/visual-sampling/)
  assert.match(sampling.html, /painted_world/)
  assert.match(sampling.html, /VPIPELINE-004/)
  const padded = catalog.entries.find((entry) => entry.id === 'padded-atlases')
  assert.ok(padded.tags.includes('VPIPELINE-004'))
  assert.equal((padded.html.match(/<img /g) ?? []).length, 2)
  assert.match(padded.html, /#\/guides\/visual-sampling/)
  assert.match(sampling.html, /#\/guides\/padded-atlases/)
  assert.match(padded.html, /386/)
})

// Сценарий: неправильная статья должна прервать подготовку до публикации.
// Исходное состояние: собственная временная папка без игровых данных.
// Ожидаемый результат: повторы ID, пустое содержимое и выход за папку вызывают понятный отказ.
test('article manifest rejects duplicates, empty content and escaped paths', async () => {
  const root = await mkdtemp(join(tmpdir(), 'farm-wiki-articles-'))
  try {
    const row = { id: 'IDEA-002', file: 'idea.md', title: 'Идея', summary: 'Описание', tags: ['Идея'] }
    await writeFile(join(root, 'idea.md'), '# Будущая идея\n')
    await writeFile(join(root, 'index.json'), JSON.stringify([row]))
    assert.equal((await articles(root))[0].id, 'IDEA-002')
    await writeFile(join(root, 'index.json'), JSON.stringify([row, row]))
    await assert.rejects(articles(root), /повторный/)
    await writeFile(join(root, 'index.json'), JSON.stringify([{ ...row, file: '../outside.md' }]))
    await assert.rejects(articles(root), /выходит/)
    await writeFile(join(root, 'index.json'), JSON.stringify([row]))
    await writeFile(join(root, 'idea.md'), '  ')
    await assert.rejects(articles(root), /Пустая статья/)
  } finally {
    await rm(root, { recursive: true, force: true })
  }
})
