import test from 'node:test'
import assert from 'node:assert/strict'
import {readFile} from 'node:fs/promises'
const read=async path=>readFile(new URL(path,import.meta.url),'utf8')

test('post-motion guide separates resolved contact, QA shader and future live art',async()=>{
  const text=await read('../articles/post-motion-frame.md')
  for(const value of ['VRENDER-008','после коллизий','Read-only','F12','reduced motion','160 PNG / 320','VMAP-003','не FPS','не объявляется исправленной']) assert.ok(text.includes(value),value)
  assert.equal((text.match(/route\.mp4/g)||[]).length,4)
  const index=JSON.parse(await read('../articles/index.json'))
  assert.equal(index.filter(r=>r.id==='post-motion-frame').length,1)
})

test('post-motion native proof contains both complete windows and full-state comparisons',async()=>{
  const data=JSON.parse(await read('../../docs/reports/visual-overhaul/vrender-008/summary.json'))
  assert.ok(data.production_publisher)
  assert.equal(data.performance_eligible,false);assert.equal(data.full_map_accepted,false)
  assert.equal(Object.values(data.windows).reduce((n,w)=>n+w.before_png+w.after_png,0),160)
  assert.equal(Object.values(data.windows).reduce((n,w)=>n+w.draw_callbacks,0),320)
  for(const w of Object.values(data.windows)){
    assert.equal(w.full_save_pairs,40);assert.equal(w.rgba_equal_pairs,40);assert.equal(w.videos,2)
    assert.deepEqual(w.changed_image_indices,[]);assert.ok(w.shader_matches);assert.equal(w.actual_wall_steps,8)
  }
})
