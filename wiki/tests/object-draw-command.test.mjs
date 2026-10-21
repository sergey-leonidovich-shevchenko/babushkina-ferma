import test from 'node:test'
import assert from 'node:assert/strict'
import {readFile} from 'node:fs/promises'
import {join} from 'node:path'
import {projectRoot,wikiRoot} from '../scripts/runtime.mjs'

test('object command guide publishes actual descriptor data and the pending native gate',async()=>{
  const article=await readFile(join(wikiRoot,'articles/object-draw-command.md'),'utf8')
  const index=JSON.parse(await readFile(join(wikiRoot,'articles/index.json'),'utf8'))
  assert.equal(index.filter(x=>x.id==='object-draw-command').length,1)
  for(const value of ['visual--VRENDER-004','visual-pilot.md','contract.json','sampling-notes.json','41 профильная','Десять Python','синтетических','Карточка не завершена'])assert.ok(article.includes(value),value)
  const diagram=await readFile(join(projectRoot,'docs/reports/visual-overhaul/vrender-004/contract.svg'),'utf8')
  assert.ok(diagram.includes('нативная приёмка ожидается'))
  const contract=JSON.parse(await readFile(join(projectRoot,'docs/reports/visual-overhaul/vrender-004/contract.json'),'utf8'))
  assert.equal(contract.production_pass_enabled,false);assert.equal(contract.commands.length,3)
  for(const command of contract.commands){assert.deepEqual(command.local_uv,[0,0,1,1]);assert.equal(command.world,'overworld')}
})

test('unfinished command contract never unlocks a live pass or claims native results',async()=>{
  const article=await readFile(join(wikiRoot,'articles/object-draw-command.md'),'utf8')
  for(const value of ['80 PNG / 248 draw — план, не результат','VRENDER-005','не получает `done`','shader-атрибут','VMAP-003'])assert.ok(article.includes(value),value)
  const plan=JSON.parse(await readFile(join(projectRoot,'docs/epics/visual-overhaul-2026-10/backlog.json'),'utf8'))
  assert.equal(plan.tasks.find(x=>x.id==='VRENDER-004').status,'in_progress')
  assert.equal(plan.tasks.find(x=>x.id==='VRENDER-005').status,'backlog')
})
