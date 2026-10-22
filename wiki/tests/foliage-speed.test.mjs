import test from 'node:test'
import assert from 'node:assert/strict'
import fs from 'node:fs'

test('speed guide explains actual movement and the controlled comparison', () => {
  const text = fs.readFileSync(new URL('../articles/foliage-speed.md', import.meta.url), 'utf8')
  for (const word of ['VFOLIAGE-005', 'VFOLIAGE-006', 'коллизиями', '30, 60 и 120', '273', '70', 'одинаковой частотой', 'не запись физической клавиатуры', '1,9', '5,71', 'VMAP-003']) assert.ok(text.includes(word), word)
  assert.equal((text.match(/!\[/g) || []).length, 3)
})

test('speed evidence contains actual GPU comparison without performance claims', () => {
  const data = JSON.parse(fs.readFileSync(new URL('../../docs/reports/visual-overhaul/vfoliage-005/summary.json', import.meta.url), 'utf8'))
  assert.equal(data.performance_eligible, false)
  assert.equal(data.hardware_input_accepted, false)
  for (const width of ['1152', '1280']) {
    assert.equal(data.windows[width].cases, 100)
    assert.equal(data.windows[width].max_geometry_rgba, 0)
    assert.equal(data.windows[width].slow_run_pairs, 8)
    assert.equal(data.windows[width].fixed_root_bands, 800)
  }
})
