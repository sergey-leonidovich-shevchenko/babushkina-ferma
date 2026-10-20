import test from 'node:test'
import assert from 'node:assert/strict'
import { readFile } from 'node:fs/promises'
import { join } from 'node:path'
import { wikiRoot, projectRoot } from '../scripts/runtime.mjs'

const catalog = JSON.parse(await readFile(join(wikiRoot, 'public/generated/catalog.json'), 'utf8'))
const article = catalog.entries.find((e) => e.category === 'guides' && e.id === 'artist-packet')

// Сценарий: художник получает производственную статью без исходников.
// Исходное состояние: свежий экспорт Wiki с иллюстрациями и вложениями.
// Ожидаемый результат: все изображения и скачиваемые файлы доступны по адресам сборки, байты не изменены.
test('artist packet publishes every illustration and exact handoff download', async () => {
  assert.ok(article?.html)
  const images = [...article.html.matchAll(/<img[^>]+src="([^"]+)"/g)]
  assert.ok(images.length >= 10)
  for (const [, path] of images) {
    assert.match(path, /^generated\/illustrations\//)
    assert.ok((await readFile(join(wikiRoot, 'public', path))).length)
  }
  const downloads = [...article.html.matchAll(/href="([^"]+)" download="([^"]+)"/g)]
  assert.equal(downloads.length, 5)
  for (const [, path, filename] of downloads) {
    const source = filename === 'palette.json'
      ? 'docs/reports/visual-overhaul/vart-003/palette.json'
      : `docs/reports/visual-overhaul/vrelease-005/${filename}`
    assert.deepEqual(await readFile(join(wikiRoot, 'public', path)), await readFile(join(projectRoot, source)))
  }
})

// Сценарий: переход из основного маршрута и поиск комплекта.
// Исходное состояние: справочник с принятыми решениями, без новой партии в игре.
// Ожидаемый результат: стабильная ссылка и поисковый текст доступны, границы внедрения видны в статье.
test('artist packet is linked from the first-map route with honest release limits', () => {
  const route = catalog.entries.find((e) => e.category === 'guides' && e.id === 'visual-pilot')
  assert.match(route.html, /href="#\/guides\/artist-packet"/)
  assert.match(article.title, /Пакет художника/)
  for (const owner of ['VCOMPAT-002', 'VRELEASE-003', 'VCOMPAT-010', 'VMAP-003']) {
    assert.ok(article.html.includes(owner), owner)
  }
  assert.match(article.html, /не укладываются в абсолютный бюджет 60 FPS/)
})
