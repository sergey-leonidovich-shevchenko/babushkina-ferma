import test from 'node:test'
import assert from 'node:assert/strict'
import { readFile } from 'node:fs/promises'
const read = async path => readFile(new URL(path, import.meta.url), 'utf8')

test('trade guide records the neutral aliases, unchanged loot and focus limitation', async () => {
  const text = await read('../articles/village-trade.md')
  for (const word of ['VPROP-007', '48×24', 'три', 'фокус', 'VMAP-003', '0.38']) assert.ok(text.includes(word), word)
  const index = JSON.parse(await read('../articles/index.json'))
  assert.equal(index.filter(row => row.id === 'village-trade').length, 1)
})

test('trade native proof covers five actual loot slots and only static visible-window acceptance', async () => {
  const data = JSON.parse(await read('../../docs/reports/visual-overhaul/vprop-007/summary.json'))
  assert.equal(data.performance_eligible, false)
  assert.equal(data.focus_required, false)
  assert.deepEqual(data.kinds, ['stall', 'crate', 'barrel', 'sack'])
  assert.equal(Object.values(data.windows).reduce((n,w) => n + w.before_png + w.after_png, 0), 132)
  assert.equal(Object.values(data.windows).reduce((n,w) => n + w.draw_callbacks, 0), 656)
  for (const row of Object.values(data.windows)) {
    assert.ok(row.outside_props_equal && row.gallery_backgrounds === 4 && row.sack_slots === 5 && row.real_openings === 5)
    assert.equal(row.visible_frames, 66)
    assert.equal(row.focused_frames, 0)
    for (const key of ['interior', 'market-control']) assert.equal(row.changed_pixels[key], 0)
  }
})
