import test from 'node:test'
import assert from 'node:assert/strict'
import {readFile} from 'node:fs/promises'
const read=async path=>readFile(new URL(path,import.meta.url),'utf8')

test('plant-depth guide exposes actual comparisons and keeps live-art acceptance separate',async()=>{
  const text=await read('../articles/plant-depth.md')
  for(const value of ['VRENDER-006','ground_y -6','F12','288 PNG / 576','30Гц','не FPS','VMAP-003','без непрозрачного дубля'])assert.ok(text.includes(value),value)
  assert.equal((text.match(/\.mp4/g)||[]).length,4)
  assert.equal((text.match(/\.png/g)||[]).length,4)
  const index=JSON.parse(await read('../articles/index.json'))
  assert.equal(index.filter(r=>r.id==='plant-depth').length,1)
})

test('plant-depth proof covers both windows, actual dispatch and unchanged legacy pictures',async()=>{
  const data=JSON.parse(await read('../../docs/reports/visual-overhaul/vrender-006/summary.json'))
  assert.equal(data.task,'VRENDER-006');assert.equal(data.plant_depth_enabled,true)
  assert.equal(data.performance_eligible,false);assert.equal(data.full_map_accepted,false)
  assert.deepEqual(Object.keys(data.windows),['1152','1280'])
  assert.equal(Object.values(data.windows).reduce((n,w)=>n+w.before_png+w.after_png,0),288)
  assert.equal(Object.values(data.windows).reduce((n,w)=>n+w.draw_callbacks,0),576)
  for(const w of Object.values(data.windows)){
    assert.equal(w.before_png,48);assert.equal(w.after_png,96);assert.equal(w.exact_legacy_pairs,48)
    assert.equal(w.full_state_triples,48);assert.equal(w.videos,3)
    assert.deepEqual(w.changed_enabled_frames,[6,10,14,15])
    assert.ok(w.single_dispatch&&w.queue_cleared&&w.equal_root_pixels_stable)
  }
})
