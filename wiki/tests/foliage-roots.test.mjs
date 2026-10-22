import test from 'node:test'
import assert from 'node:assert/strict'
import fs from 'node:fs'

test('foliage roots article covers all native sheets and its scope', () => {
  const text = fs.readFileSync(new URL('../articles/foliage-roots.md', import.meta.url), 'utf8')
  for (let page = 1; page <= 4; page++) assert.ok(text.includes(`sheet-${page}.png`))
  for (const value of ['VFOLIAGE-001', 'VFOLIAGE-002', '373', '480', 'VMAP-003', 'reduced_motion']) assert.ok(text.includes(value))
  assert.ok(text.includes('физический ввод, FPS и память не принимаются'))
})

test('foliage roots evidence links resolve to complete actual data', () => {
  const root = new URL('../../docs/reports/visual-overhaul/vfoliage-001/', import.meta.url)
  const summary = JSON.parse(fs.readFileSync(new URL('summary.json', root), 'utf8'))
  const profiles = JSON.parse(fs.readFileSync(new URL('profiles.json', root), 'utf8'))
  const contract = JSON.parse(fs.readFileSync(new URL('native-admission.json', root), 'utf8'))
  assert.equal(summary.profiles, 13)
  assert.equal(summary.rgba_pairs, 20)
  assert.equal(profiles.entries.length, 13)
  assert.equal(contract.hardware_input_accepted, false)
  assert.equal(summary.performance_eligible, false)
  assert.equal(summary.full_map_accepted, false)
})
