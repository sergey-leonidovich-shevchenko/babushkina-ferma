import test from 'node:test'
import assert from 'node:assert/strict'
import {readFile} from 'node:fs/promises'
import {join} from 'node:path'
import {projectRoot,wikiRoot} from '../scripts/runtime.mjs'

// Сценарий: глава объясняет штатное разделение и даёт настоящие источники нативного сравнения.
// Исходное состояние: один render target, финальная серия и подтверждённое владение водой/перекрытиями.
// Ожидаемый результат: четыре доказательства доступны, статус остаётся в канонической карточке.
test('ground layers publish native separation and canonical evidence links',async()=>{
  const article=await readFile(join(wikiRoot,'articles/ground-layers.md'),'utf8')
  const index=JSON.parse(await readFile(join(wikiRoot,'articles/index.json'),'utf8'))
  assert.equal(index.filter(x=>x.id==='ground-layers').length,1)
  for(const value of ['visual--VRENDER-003','visual-pilot.md','render-order.md','grass-methods.md','performance-contract.md','summary.json','native/source.json','1152/hot-loop.json','1152/cold.json']) assert.ok(article.includes(value),value)
  const summary=JSON.parse(await readFile(join(projectRoot,'docs/reports/visual-overhaul/vrender-003/summary.json'),'utf8'))
  assert.equal(summary.accepted,true); assert.equal(summary.frames,64); assert.equal(summary.draws,250)
  for(const metric of Object.values(summary.comparisons)) assert.ok(metric.max_channel_error<=1)
  for(const control of Object.values(summary.controls)) {assert.equal(control.legacy_draw_calls,140); assert.equal(control.split_draw_calls,142); assert.ok(control.opaque_bridge_probe.length===2); assert.equal(control.cold_first_frame.max_channel_error,0)}
})

// Сценарий: сохранность кеша не подменяет FPS и новую живопись.
// Исходное состояние: остановленная симуляция, пять модельных секунд и настоящий первый кадр.
// Ожидаемый результат: узкая приёмка видна в тексте и данных, картинки существуют и не выданы за новый дизайн.
test('ground layer proof keeps first-frame, FPS and art limits explicit',async()=>{
  const article=await readFile(join(wikiRoot,'articles/ground-layers.md'),'utf8')
  const summary=JSON.parse(await readFile(join(projectRoot,'docs/reports/visual-overhaul/vrender-003/summary.json'),'utf8'))
  for(const key of ['whole_map_accepted','live_gameplay_fps_accepted','new_water_art_accepted']) assert.equal(summary[key],false)
  assert.equal(summary.gpu_time_ms,null)
  for(const value of ['один SubViewport','UPDATE_DISABLED','одной реальной записью','не FPS-замер','модельных секунд','21 профильная','не выбранный дизайн','Старые перила']) assert.ok(article.includes(value),value)
  const images=[...article.matchAll(/!\[[^\]]*\]\(([^)]+)\)/g)]
  assert.equal(images.length,2)
  for(const image of images) assert.ok((await readFile(join(wikiRoot,'articles',image[1]))).length>1000)
})
