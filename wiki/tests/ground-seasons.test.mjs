import test from 'node:test'
import assert from 'node:assert/strict'
import {readFile} from 'node:fs/promises'
import {join} from 'node:path'
import {projectRoot,wikiRoot} from '../scripts/runtime.mjs'

test('seasonal ground guide exposes five natural climates and real first-map evidence',async()=>{
  const article=await readFile(join(wikiRoot,'articles/ground-seasons.md'),'utf8')
  const index=JSON.parse(await readFile(join(wikiRoot,'articles/index.json'),'utf8'))
  assert.equal(index.filter(x=>x.id==='ground-seasons').length,1)
  for(const word of ['visual--VGROUND-010','visual-pilot.md','summary.json','native/source.json','1152/capture.json'])assert.ok(article.includes(word),word)
  const images=[...article.matchAll(/!\[[^\]]*\]\(([^)]+)\)/g)]
  assert.equal(images.length,2)
  for(const image of images)assert.ok((await readFile(join(wikiRoot,'articles',image[1]))).length>1000)
  const summary=JSON.parse(await readFile(join(projectRoot,'docs/reports/visual-overhaul/vground-010/summary.json'),'utf8'))
  for(const row of Object.values(summary.windows)){
    assert.equal(row.png_count,44);assert.equal(row.draw_callbacks,152);assert.equal(row.climates,5)
    assert.equal(row.retained_meshes,41);assert.equal(row.identical_rules,1200);assert.equal(row.identical_bridge_motions,8)
    assert.equal(row.alpha_exact,true);assert.equal(row.spring_return_exact,true);assert.equal(row.retained_targets,1)
    assert.equal(row.pause_resume_cache_exact,true);assert.equal(row.pause_saved_events_only.length,2)
  }
})

test('seasonal guide preserves fixture, pause-event and performance limitations',async()=>{
  const article=await readFile(join(wikiRoot,'articles/ground-seasons.md'),'utf8')
  for(const word of ['34 профильных','11 Python','88','304','120','pause_menu','снежный покров не добавлен','VPERF','VMAP-003','системным часам'])assert.ok(article.includes(word),word)
  const source=JSON.parse(await readFile(join(projectRoot,'docs/reports/visual-overhaul/vground-010/native/source.json'),'utf8'))
  assert.equal(source.complete,true);assert.equal(source.performance_eligible,false)
  assert.equal(typeof source.static_coexistence,'boolean');assert.ok(Array.isArray(source.initial_jobs))
})
