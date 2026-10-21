import test from 'node:test'
import assert from 'node:assert/strict'
import {readFile} from 'node:fs/promises'
const read=async path=>readFile(new URL(path,import.meta.url),'utf8')

test('selected pass guide records the actual scope, phase and default-on fallback',async()=>{
  const text=await read('../articles/pilot-object-pass.md')
  for(const value of ['VRENDER-005','648,576','behind_actors','default-on','F12','VMAP-003','136 PNG / 544']) assert.ok(text.includes(value),value)
  const index=JSON.parse(await read('../articles/index.json'))
  assert.equal(index.filter(r=>r.id==='pilot-object-pass').length,1)
})

test('selected pass proof contains actual command and one-call refusal outcomes in two viewports',async()=>{
  const data=JSON.parse(await read('../../docs/reports/visual-overhaul/vrender-005/summary.json'))
  assert.ok(data.production_pass_enabled&&data.default_enabled)
  assert.equal(data.layer,'behind_actors');assert.equal(data.selected_object,'board:648:576')
  assert.equal(data.performance_eligible,false);assert.equal(data.full_map_accepted,false)
  assert.equal(Object.values(data.windows).reduce((n,w)=>n+w.before_png+w.after_png,0),136)
  assert.equal(Object.values(data.windows).reduce((n,w)=>n+w.draw_callbacks,0),544)
  for(const w of Object.values(data.windows)){
    assert.ok(w.all_rgba_equal&&w.default_on_exercised&&w.foreground_other_world_hud_retained)
    assert.equal(w.rgba_pairs,45);assert.equal(w.actual_routes.command,32);assert.equal(w.actual_routes.fallback,24);assert.equal(w.cache_max,3)
  }
})
