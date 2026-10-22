import test from 'node:test'
import assert from 'node:assert/strict'
import fs from 'node:fs'

test('wind guide exposes native motion and preserves the limits of acceptance', () => {
  const text = fs.readFileSync(new URL('../articles/foliage-wind.md', import.meta.url), 'utf8')
  for (const term of ['VFOLIAGE-003', 'VFOLIAGE-004', 'VMAP-003', 'APNG', '68 случаев', '12 отсчётов', 'MultiMesh', 'не является измерением FPS']) assert.ok(text.includes(term), term)
  assert.ok(text.includes('native/1152/motion.png'))
  assert.ok(text.includes('native/1280/wind-24/window.png'))
})

test('native wind accepts two real windows and actual fixed root bands', () => {
  const root = new URL('../../docs/reports/visual-overhaul/vfoliage-003/', import.meta.url)
  const data = JSON.parse(fs.readFileSync(new URL('summary.json', root), 'utf8'))
  assert.equal(data.performance_eligible, false)
  assert.equal(data.hardware_input_accepted, false)
  assert.equal(data.full_map_accepted, false)
  for (const width of ['1152', '1280']) {
    assert.equal(data.windows[width].cases, 68)
    assert.equal(data.windows[width].fixed_root_bands, 544)
    assert.equal(data.windows[width].max_geometry_rgba, 0)
    assert.equal(data.windows[width].motion_samples, 49)
  }
})
