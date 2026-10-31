import test from 'node:test'
import assert from 'node:assert/strict'
import { readFile } from 'node:fs/promises'
import { join } from 'node:path'
import { wikiRoot } from '../scripts/runtime.mjs'

const catalog = JSON.parse(await readFile(join(wikiRoot, 'public/generated/catalog.json'), 'utf8'))
const article = catalog.entries.find(entry => entry.category === 'guides' && entry.id === 'underwater-bottom')

test('underwater bottom publishes same-camera evidence and user-controlled native video', async () => {
  assert.ok(article?.html)
  for (const term of ['VSHORE-002', '1254×1254', '36 вершин', 'physical_authority', 'не замер FPS']) {
    assert.ok(article.html.includes(term), term)
  }
  assert.match(article.html, /<video controls playsinline preload="metadata"/)
  assert.doesNotMatch(article.html, /autoplay/)
  for (const [, path] of article.html.matchAll(/(?:src|href)="(generated\/[^"]+)"/g)) {
    assert.ok((await readFile(join(wikiRoot, 'public', path))).length)
  }
})

test('underwater bottom keeps later water and whole-map owners open', () => {
  for (const id of ['visual-pilot', 'artist-packet']) {
    const route = catalog.entries.find(entry => entry.category === 'guides' && entry.id === id)
    assert.match(route.html, /href="#\/guides\/underwater-bottom"/)
  }
  for (const owner of ['VSHORE-003', 'VSHORE-004', 'VSHORE-005', 'VSHORE-006']) {
    assert.ok(article.html.includes(owner), owner)
  }
})
