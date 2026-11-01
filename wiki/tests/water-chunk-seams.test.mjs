import test from 'node:test'
import assert from 'node:assert/strict'
import { readFile } from 'node:fs/promises'
import { join } from 'node:path'
import { wikiRoot } from '../scripts/runtime.mjs'

const catalog = JSON.parse(await readFile(join(wikiRoot, 'public/generated/catalog.json'), 'utf8'))
const article = catalog.entries.find(
  (entry) => entry.category === 'guides' && entry.id === 'water-chunk-seams'
)

test('water chunk seams publish same-camera equality and a broken control', async () => {
  assert.ok(article?.html)
  for (const term of ['VSHORE-004', '64', '48', '240', '892 / 0', 'не замер FPS']) {
    assert.ok(article.html.includes(term), term)
  }
  for (const alt of ['Полный план', 'Чанки с halo', 'Ложный берег без соседнего halo']) {
    assert.ok(article.html.includes(`alt="${alt}"`), alt)
  }
  const images = [...article.html.matchAll(/<img src="(generated\/illustrations\/[^"]+)"/g)].map(
    (match) => match[1]
  )
  assert.equal(images.length, 3)
  assert.equal(new Set(images).size, 2)
  assert.match(article.html, /<video controls playsinline preload="metadata"/)
  assert.doesNotMatch(article.html, /autoplay/)
  for (const [, path] of article.html.matchAll(/(?:src|href)="(generated\/[^\"]+)"/g)) {
    assert.ok((await readFile(join(wikiRoot, 'public', path))).length)
  }
})

test('water chunk seams preserve later animation, flow and whole-map owners', () => {
  const topology = catalog.entries.find(
    (entry) => entry.category === 'guides' && entry.id === 'water-topology-mask'
  )
  const pilot = catalog.entries.find(
    (entry) => entry.category === 'guides' && entry.id === 'visual-pilot'
  )
  assert.match(topology.html, /href="#\/guides\/water-chunk-seams"/)
  assert.match(pilot.html, /href="#\/guides\/water-chunk-seams"/)
  for (const owner of ['VSHORE-005', 'VSHORE-006', 'WATER-06', 'VMAP-003']) {
    assert.ok(article.html.includes(owner), owner)
  }
})
