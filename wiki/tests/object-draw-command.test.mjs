import test from 'node:test'
import assert from 'node:assert/strict'
import {readFile} from 'node:fs/promises'
import {join} from 'node:path'
import {projectRoot,wikiRoot} from '../scripts/runtime.mjs'

test('object command guide publishes actual descriptors and native acceptance',async()=>{
  const article=await readFile(join(wikiRoot,'articles/object-draw-command.md'),'utf8')
  const index=JSON.parse(await readFile(join(wikiRoot,'articles/index.json'),'utf8'))
  assert.equal(index.filter(x=>x.id==='object-draw-command').length,1)
  for(const value of ['visual--VRENDER-004','visual-pilot.md','contract.json','sampling-notes.json','summary.json','41 профильная','Десять Python','синтетических','ещё пять','Нативная серия VRENDER-004 проверена'])assert.ok(article.includes(value),value)
  const diagram=await readFile(join(projectRoot,'docs/reports/visual-overhaul/vrender-004/contract.svg'),'utf8')
  assert.ok(diagram.includes('80 PNG / 248 draw'))
  const contract=JSON.parse(await readFile(join(projectRoot,'docs/reports/visual-overhaul/vrender-004/contract.json'),'utf8'))
  assert.equal(contract.production_pass_enabled,false);assert.equal(contract.commands.length,3)
  for(const command of contract.commands){assert.deepEqual(command.local_uv,[0,0,1,1]);assert.equal(command.world,'overworld')}
})

test('accepted native contract keeps the production pass and FPS gate separate',async()=>{
  const article=await readFile(join(wikiRoot,'articles/object-draw-command.md'),'utf8')
  for(const value of ['80 PNG / 248 draw callbacks','VRENDER-005','старый API вызывается ровно один раз','shader-атрибут','VMAP-003'])assert.ok(article.includes(value),value)
  const report=JSON.parse(await readFile(join(projectRoot,'docs/reports/visual-overhaul/vrender-004/summary.json'),'utf8'))
  assert.equal(report.production_pass_enabled,false);assert.equal(report.performance_eligible,false)
  assert.deepEqual(Object.keys(report.windows),['1152','1280'])
  for(const row of Object.values(report.windows)){assert.equal(row.png_count,40);assert.equal(row.draw_callbacks,124);assert.equal(row.pixel_equal,true);assert.equal(row.fallback_cases,5)}
  const source=JSON.parse(await readFile(join(projectRoot,'docs/reports/visual-overhaul/vrender-004/native/source.json'),'utf8'))
  assert.equal(source.complete,true);assert.equal(source.base_commit,report.base_commit)
})
