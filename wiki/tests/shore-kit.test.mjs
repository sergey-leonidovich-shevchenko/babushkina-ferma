import test from 'node:test'
import assert from 'node:assert/strict'
import { readFile } from 'node:fs/promises'
import { join } from 'node:path'
import { wikiRoot, projectRoot } from '../scripts/runtime.mjs'

const catalog = JSON.parse(await readFile(join(wikiRoot,'public/generated/catalog.json'),'utf8'))
const article = catalog.entries.find(e => e.category === 'guides' && e.id === 'shore-kit')

// Сценарий: визуальная проверка собранного комплекта без исходников игры.
// Исходное состояние: свежая сборка с кадрами узкого/широкого моста и нативным роликом.
// Ожидаемый результат: изображения доступны, видео управляется пользователем, исходные JSON не изменены.
test('shore kit publishes bridge comparison, native camera video and exact manifests', async () => {
  assert.ok(article?.html)
  assert.match(article.html, /48 до 72/)
  assert.match(article.html, /<video controls playsinline preload="metadata"/)
  assert.doesNotMatch(article.html, /autoplay/)
  for (const [, path] of article.html.matchAll(/(?:src|href)="(generated\/[^\"]+)"/g)) {
    assert.ok((await readFile(join(wikiRoot,'public',path))).length)
  }
  for (const [, path, filename] of article.html.matchAll(/href="([^\"]+)" download="([^\"]+)"/g)) {
    const prefix = filename === 'capture.json' ? 'native/' : ''
    assert.deepEqual(await readFile(join(wikiRoot,'public',path)),await readFile(join(projectRoot,'docs/reports/visual-overhaul/vshore-001',prefix+filename)))
  }
})

// Сценарий: комплект не выдаётся за игровое внедрение и полный набор масок.
// Исходное состояние: статья связана с главным маршрутом и паспортом художника.
// Ожидаемый результат: обе ссылки стабильны, владельцы оставшейся проверки явно названы.
test('shore kit remains on first-map course and preserves open runtime gates', () => {
  for (const id of ['visual-pilot','artist-packet']) {
    const route = catalog.entries.find(e => e.category === 'guides' && e.id === id)
    assert.match(route.html, /href="#\/guides\/shore-kit"/)
  }
  for (const term of ['VSHORE-003','WATER-04','96×192','не замер FPS']) assert.ok(article.html.includes(term),term)
})
