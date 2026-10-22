import test from 'node:test'
import assert from 'node:assert/strict'
import {readFile} from 'node:fs/promises'
const read=async path=>readFile(new URL(path,import.meta.url),'utf8')

test('save-boundary guide keeps progress, settings and transient resources distinct',async()=>{
  const text=await read('../articles/visual-save-boundary.md')
  for(const word of ['VCOMPAT-001','ShaderMaterial','до открытия tmp','version2','61 профильная','17 отрицательных','8 PNG / 16','VMAP-003','v1'])assert.ok(text.includes(word),word)
  assert.equal((text.match(/\.png/g)||[]).length,1)
  const index=JSON.parse(await read('../articles/index.json'))
  assert.equal(index.filter(r=>r.id==='visual-save-boundary').length,1)
})

test('native save evidence requires healthy writes and identical gameplay without a performance claim',async()=>{
  const data=JSON.parse(await read('../../docs/reports/visual-overhaul/vcompat-001/summary.json'))
  assert.equal(data.save_version,2);assert.equal(data.performance_eligible,false);assert.equal(data.full_map_accepted,false)
  assert.equal(Object.values(data.windows).reduce((n,w)=>n+w.before_png+w.after_png,0),8)
  assert.equal(Object.values(data.windows).reduce((n,w)=>n+w.draw_callbacks,0),16)
  for(const w of Object.values(data.windows))assert.ok(w.full_gameplay_equal&&w.native_gpu_reference&&w.before_unsafe_accepted&&w.after_primary_backup_preserved)
  const ownership=JSON.parse(await read('../../docs/reports/visual-overhaul/vcompat-001/ownership.json'))
  assert.equal(ownership.max_value_depth,64);assert.equal(ownership.save_version,2);assert.ok(ownership.snapshot_keys.includes('rng'))
})
