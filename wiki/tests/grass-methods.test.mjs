import test from 'node:test'
import assert from 'node:assert/strict'
import {readFile} from 'node:fs/promises'
import {join} from 'node:path'
import {projectRoot,wikiRoot} from '../scripts/runtime.mjs'

// Сценарий: статья показывает итог сравнительного опыта и обе версии CPU без смешивания.
// Исходное состояние: нативные источники и рассчитанные полные распределения.
// Ожидаемый результат: 30 запусков и 54 кадра доступны, выбранный метод и CPU-строка проверяемы.
test('grass methods publish distinct cost series and the canonical decision',async()=>{
  const article=await readFile(join(wikiRoot,'articles/grass-methods.md'),'utf8')
  const report=join(projectRoot,'docs/reports/visual-overhaul/vrender-002')
  const summary=JSON.parse(await readFile(join(report,'summary.json'),'utf8'))
  assert.equal(summary.chosen,'batch'); assert.equal(summary.accepted,true)
  assert.equal(summary.original_cost.run_count,24); assert.equal(summary.optimized_cpu_cost.run_count,6)
  assert.equal(summary.quality.frames,54); assert.equal(summary.quality.draws,216)
  assert.equal(summary.decision_cost['1024'].cpu.update_p95_median_ms,summary.optimized_cpu_cost.aggregate['1024'].cpu.update_p95_median_ms)
  assert.equal(summary.decision_cost['1024'].cpu_original.update_p95_median_ms,summary.original_cost.aggregate['1024'].cpu.update_p95_median_ms)
  for(const value of ['summary.json','bench/source.json','cpu-only/source.json','quality/source.json','visual--VRENDER-002','visual-pilot.md','performance-contract.md','render-order.md']) assert.ok(article.includes(value),value)
  const index=JSON.parse(await readFile(join(wikiRoot,'articles/index.json'),'utf8'))
  assert.equal(index.filter(e=>e.id==='grass-methods').length,1)
})

// Сценарий: меньшая CPU-доля не выдаётся за доказанную частоту показа или новое оформление карты.
// Исходное состояние: замороженная симуляция, доступные render boundaries и неизвестное GPU-время.
// Ожидаемый результат: ограничения видимы; картинки и отдельный путь источников сохранены.
test('grass comparison keeps visual prototype and live FPS acceptance separate',async()=>{
  const article=await readFile(join(wikiRoot,'articles/grass-methods.md'),'utf8')
  const summary=JSON.parse(await readFile(join(projectRoot,'docs/reports/visual-overhaul/vrender-002/summary.json'),'utf8'))
  for(const key of ['live_gameplay_fps_accepted','whole_map_accepted']) assert.equal(summary[key],false)
  assert.equal(summary.gpu_time_ms,null); assert.equal(summary.quality.full_foliage_contact_accepted,false)
  assert.ok(summary.decision_cost['1024'].items.render_p95_median_ms<summary.decision_cost['1024'].batch.render_p95_median_ms)
  for(const value of ['render p95 лучше','Улучшение FPS этим опытом не доказано','Симуляция игры остановлена','1437','18 Python','непрозрачные','Старые перила','не включён']) assert.ok(article.includes(value),value)
  const sources=[...article.matchAll(/!\[[^\]]*\]\(([^)]+)\)/g)].map(m=>m[1])
  assert.equal(sources.length,2)
  for(const source of sources) assert.ok((await readFile(join(wikiRoot,'articles',source))).length>1000)
})
