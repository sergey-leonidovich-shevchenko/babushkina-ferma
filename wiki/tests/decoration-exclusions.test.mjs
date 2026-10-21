import test from 'node:test'
import assert from 'node:assert/strict'
import {readFile} from 'node:fs/promises'
import {join} from 'node:path'
import {projectRoot,wikiRoot} from '../scripts/runtime.mjs'

test('decoration guide publishes diagnostic comparison, ordinary control and exact policy',async()=>{
  const article=await readFile(join(wikiRoot,'articles/decoration-exclusions.md'),'utf8')
  const index=JSON.parse(await readFile(join(wikiRoot,'articles/index.json'),'utf8'))
  assert.equal(index.filter(x=>x.id==='decoration-exclusions').length,1)
  for(const word of ['visual--VGROUND-008','visual-pilot.md','summary.json','native/source.json','1152/policy.json'])assert.ok(article.includes(word),word)
  const images=[...article.matchAll(/!\[[^\]]*\]\(([^)]+)\)/g)]
  assert.equal(images.length,3)
  for(const image of images)assert.ok((await readFile(join(wikiRoot,'articles',image[1]))).length>1000)
  const summary=JSON.parse(await readFile(join(projectRoot,'docs/reports/visual-overhaul/vground-008/summary.json'),'utf8'))
  for(const row of Object.values(summary.windows)){
    assert.equal(row.png_count,54);assert.equal(row.draw_callbacks,208)
    assert.equal(row.ordinary_exact_cases,10);assert.equal(row.rain_pixel_equality,false)
    assert.deepEqual(row.snapshot_only_cases,['rain','interior','returned'])
    assert.equal(row.accepted,86);assert.equal(row.rejected,200)
  }
})

test('decoration guide keeps dormant seed, manual priority and performance limits explicit',async()=>{
  const article=await readFile(join(wikiRoot,'articles/decoration-exclusions.md'),'utf8')
  for(const word of ['не вызывается','диагностические','512','47 профильных','10 Python','системным часам','F12','VPERF','VMAP-003'])assert.ok(article.includes(word),word)
  const source=JSON.parse(await readFile(join(projectRoot,'docs/reports/visual-overhaul/vground-008/native/source.json'),'utf8'))
  assert.equal(source.complete,true);assert.equal(source.performance_eligible,false)
  assert.equal(typeof source.static_coexistence,'boolean');assert.ok(Array.isArray(source.initial_jobs))
})
