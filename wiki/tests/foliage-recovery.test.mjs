import test from 'node:test'
import assert from 'node:assert/strict'
import fs from 'node:fs'

test('recovery guide explains simulation timing, cleanup and limits honestly', () => {
  const text = fs.readFileSync(new URL('../articles/foliage-recovery.md', import.meta.url), 'utf8')
  for (const word of ['VFOLIAGE-006', '0,08', '0,18', '0,005', '64 записи', '30, 60 и 120', 'Пауза', 'Телепорт', 'не измерение FPS', 'VMAP-003', 'VCOMPAT-010']) assert.ok(text.includes(word), word)
  assert.equal((text.match(/!\[/g) || []).length, 3)
})

test('recovery evidence covers intermediate physics and actual GPU output', () => {
  const data = JSON.parse(fs.readFileSync(new URL('../../docs/reports/visual-overhaul/vfoliage-006/summary.json', import.meta.url), 'utf8'))
  assert.equal(data.performance_eligible, false)
  assert.equal(data.hardware_input_accepted, false)
  for (const width of ['1152', '1280']) {
    assert.equal(data.windows[width].cases, 59)
    assert.ok(data.windows[width].trace_samples > 300)
    assert.ok(data.windows[width].max_geometry_rgba <= 1)
    assert.equal(data.windows[width].fixed_root_bands, 472)
    assert.ok(data.windows[width].max_active <= 8)
  }
})
