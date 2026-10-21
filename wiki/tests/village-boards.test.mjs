import test from 'node:test'
import assert from 'node:assert/strict'
import { readFile } from 'node:fs/promises'
const read = async path => readFile(new URL(path, import.meta.url), 'utf8')

test('notice guide separates blank sprites and live six-locale labels', async () => {
  const text = await read('../articles/village-boards.md')
  for (const word of ['VPROP-006', '72×24', '24 px', 'шести языках', 'VMAP-003', '30 побайтовых']) assert.ok(text.includes(word), word)
  const index = JSON.parse(await read('../articles/index.json'))
  assert.equal(index.filter(row => row.id === 'village-boards').length, 1)
})

test('notice proof contains actual locale bodies, two windows and offscreen controls', async () => {
  const data = JSON.parse(await read('../../docs/reports/visual-overhaul/vprop-006/summary.json'))
  assert.equal(data.performance_eligible, false)
  assert.deepEqual(data.locales, ['ru', 'en', 'es', 'de', 'fr', 'zh'])
  assert.equal(Object.values(data.windows).reduce((n, w) => n + w.before_png + w.after_png, 0), 140)
  assert.equal(Object.values(data.windows).reduce((n, w) => n + w.draw_callbacks, 0), 624)
  for (const row of Object.values(data.windows)) {
    assert.ok(row.outside_props_equal && row.gallery_backgrounds === 4 && row.locale_route_cases === 18 && row.locale_body_equal === 15)
    for (const key of ['interior', 'market-control', 'fence-control']) assert.equal(row.changed_pixels[key], 0)
  }
})
