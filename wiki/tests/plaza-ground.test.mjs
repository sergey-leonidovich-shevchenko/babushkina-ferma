import test from 'node:test'
import assert from 'node:assert/strict'
import {readFile} from 'node:fs/promises'
import {join} from 'node:path'
import {projectRoot,wikiRoot} from '../scripts/runtime.mjs'

// Native frames and original art records must stay accessible from the published guide.
test('plaza guide exposes the final native comparison and original art',async()=>{
  const article=await readFile(join(wikiRoot,'articles/plaza-ground.md'),'utf8')
  const index=JSON.parse(await readFile(join(wikiRoot,'articles/index.json'),'utf8'))
  assert.equal(index.filter(x=>x.id==='plaza-ground').length,1)
  for(const value of ['visual--VGROUND-006','visual-pilot.md','summary.json','art-source.json','native/source.json']) assert.ok(article.includes(value),value)
  const images=[...article.matchAll(/!\[[^\]]*\]\(([^)]+)\)/g)]
  assert.equal(images.length,4)
  for(const image of images) assert.ok((await readFile(join(wikiRoot,'articles',image[1]))).length>1000)
  const summary=JSON.parse(await readFile(join(projectRoot,'docs/reports/visual-overhaul/vground-006/summary.json'),'utf8'))
  for(const row of Object.values(summary.windows)) {
    assert.equal(row.png_count,37);assert.equal(row.draw_callbacks,121)
    assert.equal(row.mask.alpha_exact_after_recolor,true);assert.equal(row.mask.levels,11)
    assert.ok(row.material.new.std<row.material.old.std*.8)
    assert.ok(row.spring.mean>.05)
  }
})

// Frozen visual acceptance must never become performance or whole-map acceptance.
test('plaza proof keeps static process policy and release limits explicit',async()=>{
  const source=JSON.parse(await readFile(join(projectRoot,'docs/reports/visual-overhaul/vground-006/native/source.json'),'utf8'))
  const summary=JSON.parse(await readFile(join(projectRoot,'docs/reports/visual-overhaul/vground-006/summary.json'),'utf8'))
  assert.equal(source.complete,true);assert.equal(source.performance_eligible,false)
  assert.equal(source.static_coexistence,true);assert.ok(source.initial_jobs.length>0)
  assert.equal(summary.performance_eligible,false);assert.equal(summary.gpu_time_ms,null)
  const art=JSON.parse(await readFile(join(projectRoot,'docs/reports/visual-overhaul/vground-006/art-source.json'),'utf8'))
  assert.equal(art.mode,'built-in image_gen');assert.deepEqual(art.runtime_size,[512,512])
  assert.ok((await readFile(join(projectRoot,art.master))).length>1000)
  const article=await readFile(join(wikiRoot,'articles/plaza-ground.md'),'utf8')
  for(const value of ['VMAP-003','VPERF','RSS/VRAM','120 callbacks','26','10 Python']) assert.ok(article.includes(value),value)
})
