import test from 'node:test'
import assert from 'node:assert/strict'
import { readFile } from 'node:fs/promises'
import { join } from 'node:path'
import { wikiRoot } from '../scripts/runtime.mjs'

const catalog = JSON.parse(await readFile(join(wikiRoot, 'public/generated/catalog.json'), 'utf8'))
const article = catalog.entries.find(entry => entry.category === 'guides' && entry.id === 'water-topology-mask')

test('water topology mask publishes native same-camera evidence and fixed-clock video', async () => {
  assert.ok(article?.html)
  for (const term of ['VSHORE-003', '550', '20 кардинальных', '871', 'не замер FPS']) {
    assert.ok(article.html.includes(term), term)
  }
  assert.match(article.html, /<video controls playsinline preload="metadata"/)
  assert.doesNotMatch(article.html, /autoplay/)
  for (const [, path] of article.html.matchAll(/(?:src|href)="(generated\/[^"]+)"/g)) {
    assert.ok((await readFile(join(wikiRoot, 'public', path))).length)
  }
})

test('water topology mask keeps later shore, motion and whole-map owners open', () => {
  const bottom = catalog.entries.find(entry => entry.category === 'guides' && entry.id === 'underwater-bottom')
  const pilot = catalog.entries.find(entry => entry.category === 'guides' && entry.id === 'visual-pilot')
  assert.match(bottom.html, /href="#\/guides\/water-topology-mask"/)
  assert.match(pilot.html, /href="#\/guides\/water-topology-mask"/)
  for (const owner of ['VSHORE-004', 'VSHORE-005', 'VSHORE-006', 'WATER-06', 'VMAP-003']) {
    assert.ok(article.html.includes(owner), owner)
  }
})
