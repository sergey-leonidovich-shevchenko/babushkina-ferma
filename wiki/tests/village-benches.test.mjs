import test from 'node:test'
import assert from 'node:assert/strict'
import {readFile} from 'node:fs/promises'
import {join} from 'node:path'
import {projectRoot,wikiRoot} from '../scripts/runtime.mjs'

test('bench guide preserves first-map scope, three sides and corrected four-leg construction',async()=>{
  const article=await readFile(join(wikiRoot,'articles/village-benches.md'),'utf8')
  for(const text of ['visual--VPROP-002','visual-pilot.md','четыре ножки в каждом','Боковые мастера исправлены','50 нативных PNG / 224 draw','72×24','VMAP-003','summary.json','source.json','prompts.json'])assert.ok(article.includes(text),text)
  const source=JSON.parse(await readFile(join(projectRoot,'docs/reports/visual-overhaul/vprop-002/source.json'),'utf8'))
  assert.equal(source.leg_count,4);assert.deepEqual(source.orientation,['south','west','east'])
  for(const view of Object.values(source.views)){assert.equal(view.contacts.length,4);assert.equal(view.render_scale,.25)}
})

test('bench native report contains two accepted windows and no performance claim',async()=>{
  const report=JSON.parse(await readFile(join(projectRoot,'docs/reports/visual-overhaul/vprop-002/summary.json'),'utf8'))
  assert.equal(report.performance_eligible,false);assert.equal(report.leg_count,4)
  assert.deepEqual(Object.keys(report.windows),['1152','1280'])
  for(const row of Object.values(report.windows)){assert.equal(row.before_png,11);assert.equal(row.after_png,14);assert.equal(row.draw_callbacks,112);assert.equal(row.outside_bench_equal,true);assert.equal(row.changed_pixels.interior,0)}
  const index=JSON.parse(await readFile(join(wikiRoot,'articles/index.json'),'utf8'));assert.equal(index.filter(x=>x.id==='village-benches').length,1)
})
