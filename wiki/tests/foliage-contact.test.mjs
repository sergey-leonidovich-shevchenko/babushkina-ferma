import test from 'node:test'
import assert from 'node:assert/strict'
import fs from 'node:fs'

test('contact guide exposes controlled motion and distinguishes visible foot from input', () => {
  const text = fs.readFileSync(new URL('../articles/foliage-contact.md', import.meta.url), 'utf8')
  for (const word of ['VFOLIAGE-004', 'VFOLIAGE-005', 'видимой стопы', '1424', '178', '1189', 'APNG', 'не является измерением FPS']) assert.ok(text.includes(word), word)
  assert.equal((text.match(/!\[/g) || []).length, 3)
})

test('contact evidence contains native positive and exact-zero controls', () => {
  const data = JSON.parse(fs.readFileSync(new URL('../../docs/reports/visual-overhaul/vfoliage-004/summary.json', import.meta.url), 'utf8'))
  assert.equal(data.performance_eligible, false)
  assert.equal(data.hardware_input_accepted, false)
  for (const width of ['1152', '1280']) {
    assert.equal(data.windows[width].cases, 89)
    assert.equal(data.windows[width].max_geometry_rgba, 0)
    assert.equal(data.windows[width].positive_controls, 54)
    assert.equal(data.windows[width].zero_controls, 26)
  }
})
