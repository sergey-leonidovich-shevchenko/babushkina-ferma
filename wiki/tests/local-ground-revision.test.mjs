import test from 'node:test'
import assert from 'node:assert/strict'
import {readFile} from 'node:fs/promises'
import {join} from 'node:path'
import {projectRoot,wikiRoot} from '../scripts/runtime.mjs'

test('local ground guide exposes real soil frames, scope diagram and exact revision records',async()=>{
  const article=await readFile(join(wikiRoot,'articles/local-ground-revision.md'),'utf8')
  const index=JSON.parse(await readFile(join(wikiRoot,'articles/index.json'),'utf8'))
  assert.equal(index.filter(x=>x.id==='local-ground-revision').length,1)
  for(const word of ['visual--VGROUND-009','visual-pilot.md','summary.json','native/source.json','1152/capture.json'])assert.ok(article.includes(word),word)
  const images=[...article.matchAll(/!\[[^\]]*\]\(([^)]+)\)/g)]
  assert.equal(images.length,3)
  for(const image of images)assert.ok((await readFile(join(wikiRoot,'articles',image[1]))).length>1000)
  const summary=JSON.parse(await readFile(join(projectRoot,'docs/reports/visual-overhaul/vground-009/summary.json'),'utf8'))
  for(const row of Object.values(summary.windows)){
    assert.equal(row.png_count,40);assert.equal(row.draw_callbacks,106)
    assert.equal(row.changed_cache_pixels,69120);assert.equal(row.outside_changed_pixels,0)
    assert.equal(row.local_equals_full,true);assert.equal(row.first_local_equals_full,true)
    assert.equal(row.retained_target_count,1);assert.equal(row.plot_affected_meshes,5)
    assert.equal(row.historical_control.eligible,false)
  }
})

test('local update proof keeps performance, fixture and rollback limitations explicit',async()=>{
  const article=await readFile(join(wikiRoot,'articles/local-ground-revision.md'),'utf8')
  for(const word of ['local_terrain_updates=false','60 профильных','9 Python','32','120','физический ввод','VPERF','VMAP-003','loot/RNG'])assert.ok(article.includes(word),word)
  const source=JSON.parse(await readFile(join(projectRoot,'docs/reports/visual-overhaul/vground-009/native/source.json'),'utf8'))
  assert.equal(source.complete,true);assert.equal(source.performance_eligible,false)
  assert.equal(typeof source.static_coexistence,'boolean');assert.ok(Array.isArray(source.initial_jobs))
})
