import test from 'node:test'
import assert from 'node:assert/strict'
import {readFile} from 'node:fs/promises'
import {join} from 'node:path'
import {projectRoot,wikiRoot} from '../scripts/runtime.mjs'

// The garden comparison and source records must be available from one searchable guide.
test('garden guide publishes real comparison, moisture panels and original art',async()=>{
  const article=await readFile(join(wikiRoot,'articles/garden-soil.md'),'utf8')
  const index=JSON.parse(await readFile(join(wikiRoot,'articles/index.json'),'utf8'))
  assert.equal(index.filter(x=>x.id==='garden-soil').length,1)
  for(const value of ['visual--VGROUND-007','visual-pilot.md','summary.json','art-source.json','native/source.json']) assert.ok(article.includes(value),value)
  const images=[...article.matchAll(/!\[[^\]]*\]\(([^)]+)\)/g)]
  assert.equal(images.length,4)
  for(const image of images)assert.ok((await readFile(join(wikiRoot,'articles',image[1]))).length>1000)
  const summary=JSON.parse(await readFile(join(projectRoot,'docs/reports/visual-overhaul/vground-007/summary.json'),'utf8'))
  for(const row of Object.values(summary.windows)){
    assert.equal(row.png_count,35);assert.equal(row.draw_callbacks,121)
    assert.ok(row.wetness.ratio<.8);assert.ok(Math.max(...row.wetness.join_deltas)<8)
    assert.equal(row.mask.alpha_exact_after_recolor,true)
  }
})

// The new soil must not become an unsupported farming expansion, memory or FPS claim.
test('garden proof preserves the first-map and static-only scope',async()=>{
  const source=JSON.parse(await readFile(join(projectRoot,'docs/reports/visual-overhaul/vground-007/native/source.json'),'utf8'))
  assert.equal(source.complete,true);assert.equal(source.performance_eligible,false)
  assert.equal(typeof source.static_coexistence,'boolean');assert.ok(Array.isArray(source.initial_jobs))
  const art=JSON.parse(await readFile(join(projectRoot,'docs/reports/visual-overhaul/vground-007/art-source.json'),'utf8'))
  assert.equal(art.mode,'built-in image_gen');assert.deepEqual(art.runtime_size,[512,512])
  for(const key of ['master','prompt','runtime'])assert.ok((await readFile(join(projectRoot,art[key]))).length>100)
  const article=await readFile(join(wikiRoot,'articles/garden-soil.md'),'utf8')
  for(const value of ['30 клеток','32 профильных','12 Python','120 callbacks','soft_garden=false','VMAP-003','VPERF','RSS/VRAM'])assert.ok(article.includes(value),value)
})
