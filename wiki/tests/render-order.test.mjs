import test from 'node:test'
import assert from 'node:assert/strict'
import {readFile} from 'node:fs/promises'
import {join} from 'node:path'
import {projectRoot,wikiRoot} from '../scripts/runtime.mjs'

// Сценарий: опубликован полный исходный порядок без выдачи его за GPU trace.
// Исходное состояние: принятый контракт и авторская глава Wiki.
// Ожидаемый результат: все реальные методные упоминания доступны в статье, карточка и маршрут канонические.
test('render order publishes complete source inventory and canonical route',async()=>{
  const article=await readFile(join(wikiRoot,'articles/render-order.md'),'utf8')
  const contract=JSON.parse(await readFile(join(projectRoot,'docs/reports/visual-overhaul/vrender-001/contract.json'),'utf8'))
  for(const c of contract.calls) assert.ok(article.includes('`'+c.receiver+'.'+c.method+'`'),c.receiver+'.'+c.method)
  for(const value of ['visual--VRENDER-001','visual-pilot.md','performance-contract.md','opaque_storage','draw_screen']) assert.ok(article.includes(value),value)
  const index=JSON.parse(await readFile(join(wikiRoot,'articles/index.json'),'utf8'))
  assert.equal(index.filter(e=>e.id==='render-order').length,1)
})

// Сценарий: нативная сохранность не принимается за новую графику или FPS.
// Исходное состояние: два окна, реальное дерево, полные snapshot и неизменённые PNG.
// Ожидаемый результат: доказательства доступны, границы приёмки и долг перил видимы.
test('render order preserves native proof and explicit rendering limits',async()=>{
  const article=await readFile(join(wikiRoot,'articles/render-order.md'),'utf8')
  const summary=JSON.parse(await readFile(join(projectRoot,'docs/reports/visual-overhaul/vrender-001/summary.json'),'utf8'))
  assert.equal(summary.pairs,18); assert.equal(summary.draws,72)
  assert.equal(summary.accepted,true)
  for(const key of ['fps_accepted','new_shader_accepted','whole_map_accepted']) assert.equal(summary[key],false)
  for(const value of ['0,34','1,0','перила запечены','SaveSystem.snapshot','1280×720','contract.json','summary.json','native/source.json']) assert.ok(article.includes(value),value)
  assert.equal((article.match(/!\[/g)??[]).length,3)
})
