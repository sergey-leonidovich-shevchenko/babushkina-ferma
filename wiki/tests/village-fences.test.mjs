import test from 'node:test'
import assert from 'node:assert/strict'
import { readFile } from 'node:fs/promises'
const read = async path => readFile(new URL(path, import.meta.url), 'utf8')

test('fence guide preserves open passages and scopes the first-map art', async () => {
  const text = await read('../articles/village-fences.md')
  for (const word of ['VPROP-005', '24 px', '16 масок', '8 px', 'VMAP-003', 'сохранения']) assert.ok(text.includes(word), word)
  const index = JSON.parse(await read('../articles/index.json'))
  assert.equal(index.filter(row => row.id === 'village-fences').length, 1)
})

test('fence proof contains two physical windows and bounded native comparisons', async () => {
  const data = JSON.parse(await read('../../docs/reports/visual-overhaul/vprop-005/summary.json'))
  assert.equal(data.performance_eligible, false)
  assert.deepEqual(Object.keys(data.windows), ['1152', '1280'])
  assert.equal(Object.values(data.windows).reduce((n, w) => n + w.before_png + w.after_png, 0), 56)
  assert.equal(Object.values(data.windows).reduce((n, w) => n + w.draw_callbacks, 0), 256)
  for (const row of Object.values(data.windows)) {
    assert.ok(row.outside_fence_equal && row.gallery_backgrounds === 4 && row.all_masks === 16 && row.gate_states === 4)
    assert.equal(row.changed_pixels.interior, 0)
  }
})
