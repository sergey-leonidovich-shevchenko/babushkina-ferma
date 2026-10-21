import test from 'node:test'
import assert from 'node:assert/strict'
import { readFile } from 'node:fs/promises'

const read = async path => readFile(new URL(path, import.meta.url), 'utf8')

test('lamp guide separates body and light while preserving calendar and collision', async () => {
  const text = await read('../articles/village-lamps.md')
  for (const word of ['VPROP-004', '24×24', '18:00', '05:00', 'Пауза', 'VMAP-003']) assert.ok(text.includes(word), word)
  const index = JSON.parse(await read('../articles/index.json'))
  assert.equal(index.filter(row => row.id === 'village-lamps').length, 1)
})

test('lamp report contains real normal night passes and separated glow on four backgrounds', async () => {
  const data = JSON.parse(await read('../../docs/reports/visual-overhaul/vprop-004/summary.json'))
  assert.equal(data.performance_eligible, false)
  assert.equal(Object.values(data.windows).reduce((n, w) => n + w.before_png + w.after_png, 0), 84)
  assert.equal(Object.values(data.windows).reduce((n, w) => n + w.draw_callbacks, 0), 400)
  for (const row of Object.values(data.windows)) {
    assert.ok(row.outside_lamp_equal && row.separate_glow && row.gallery_backgrounds === 4)
    assert.ok(row.glow_comparison.minimum_luma_gain > 5 && row.glow_comparison.body_outside_glow_equal)
    assert.equal(row.changed_pixels['bench-control'], 0)
  }
})
