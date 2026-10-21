import test from 'node:test'
import assert from 'node:assert/strict'
import { readFile } from 'node:fs/promises'
const read = async path => readFile(new URL(path, import.meta.url), 'utf8')

test('static pilot guide distinguishes modular study and real overworld controls', async () => {
  const text=await read('../articles/static-pilot.md')
  for(const term of ['VRELEASE-002','VMAP-003','ordinary/rollback','слот','отдельн','FPS']) assert.ok(text.includes(term),term)
  const index=JSON.parse(await read('../articles/index.json'))
  assert.equal(index.filter(r=>r.id==='static-pilot').length,1)
})

test('static pilot proof has all predecessors, actual pairs and no whole-map/live/performance claim', async () => {
  const data=JSON.parse(await read('../../docs/reports/visual-overhaul/vrelease-002/summary.json'))
  assert.equal(data.predecessors,51)
  assert.equal(data.standalone_study,true)
  for(const flag of ['performance_eligible','full_map_accepted','live_pilot_accepted','focus_required']) assert.equal(data[flag],false)
  assert.equal(Object.values(data.windows).reduce((n,w)=>n+w.png,0),44)
  assert.equal(Object.values(data.windows).reduce((n,w)=>n+w.draw_callbacks,0),304)
  for(const w of Object.values(data.windows)) assert.ok(w.outside_props_equal&&w.ordinary_rollback_equal&&w.old_slot_loaded&&w.home_enter_exit&&w.study_pairs===8)
})
