import test from 'node:test'
import assert from 'node:assert/strict'
import fs from 'node:fs'

test('local UV guide distinguishes safe sampling, geometric flip and failing shader control', () => {
  const text = fs.readFileSync(new URL('../articles/foliage-local-uv.md', import.meta.url), 'utf8')
  for (const term of ['VFOLIAGE-002', 'VFOLIAGE-003', 'VMAP-003', '413', '1/255', '2/255', '244/255', '21 сценарий']) assert.ok(text.includes(term))
  assert.equal((text.match(/window\.png/g) || []).length, 3)
  assert.ok(text.includes('физический ввод или FPS'))
})

test('local UV GPU evidence contains all profiles and actual negative controls', () => {
  const root = new URL('../../docs/reports/visual-overhaul/vfoliage-002/', import.meta.url)
  const data = JSON.parse(fs.readFileSync(new URL('summary.json', root), 'utf8'))
  const contract = JSON.parse(fs.readFileSync(new URL('native-admission.json', root), 'utf8'))
  assert.equal(data.profiles, 13)
  assert.equal(data.positive_gpu_triplets, 156)
  assert.equal(data.negative_gpu_triplets, 4)
  assert.equal(data.quad_callbacks, 960)
  assert.equal(data.performance_eligible, false)
  assert.equal(data.full_map_accepted, false)
  assert.equal(contract.sampling_rgba_max, 1)
})
