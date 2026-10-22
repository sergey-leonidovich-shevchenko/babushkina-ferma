import test from 'node:test'
import assert from 'node:assert/strict'
import fs from 'node:fs'

test('shadow guide keeps material, contact and future solar projection distinct', () => {
  const text = fs.readFileSync(new URL('../articles/shadow-inventory.md', import.meta.url), 'utf8')
  for (const term of ['VSHADOW-001', 'VMAP-003', 'VSHADOW-002…010', 'alpha≥250', '1/255', 'статическая проверка', 'Игровая графика и код не заменены']) assert.ok(text.includes(term))
  assert.equal((text.match(/!\[/g) || []).length, 6)
})

test('shadow audit includes actual complete native contact controls', () => {
  const root = new URL('../../docs/reports/visual-overhaul/vshadow-001/', import.meta.url)
  const audit = JSON.parse(fs.readFileSync(new URL('inventory.json', root), 'utf8'))
  const proof = JSON.parse(fs.readFileSync(new URL('summary.json', root), 'utf8'))
  assert.equal(audit.assets.length, 45)
  assert.equal(audit.renderer_rules.length, 18)
  assert.equal(proof.native_cases, 16)
  assert.equal(proof.target_callbacks, 96)
  assert.equal(proof.game_callbacks, 32)
  assert.equal(proof.dynamic_solar_implemented, false)
  assert.equal(proof.performance_eligible, false)
  assert.equal(proof.full_map_accepted, false)
})
