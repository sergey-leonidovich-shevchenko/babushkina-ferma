import test from 'node:test'
import assert from 'node:assert/strict'
import {readFile} from 'node:fs/promises'
import {join} from 'node:path'
import {projectRoot,wikiRoot} from '../scripts/runtime.mjs'

// Сценарий: глава показывает действительные сравнения кромки и независимый цвет покрытия.
// Исходное состояние: финальная серия B, два окна и прозрачные GPU-листы маски/сменного материала.
// Ожидаемый результат: изображения, JSON и реальные количественные свидетельства доступны читателю.
test('ground edge guide exposes native mask independence and canonical task',async()=>{
  const article=await readFile(join(wikiRoot,'articles/ground-edges.md'),'utf8')
  const index=JSON.parse(await readFile(join(wikiRoot,'articles/index.json'),'utf8'))
  assert.equal(index.filter(x=>x.id==='ground-edges').length,1)
  for(const value of ['visual--VGROUND-003','meadow-base.md','visual-pilot.md','ground-layers.md','summary.json','native/source.json','retained.json']) assert.ok(article.includes(value),value)
  const images=[...article.matchAll(/!\[[^\]]*\]\(([^)]+)\)/g)]
  assert.equal(images.length,4)
  for(const image of images) assert.ok((await readFile(join(wikiRoot,'articles',image[1]))).length>1000)
  const summary=JSON.parse(await readFile(join(projectRoot,'docs/reports/visual-overhaul/vground-003/summary.json'),'utf8'))
  for(const row of Object.values(summary.windows)) {assert.equal(row.png_count,26); assert.equal(row.draw_callbacks,81); assert.equal(row.mask.alpha_exact_after_recolor,true); assert.equal(row.mask.levels,11); assert.ok(row.mask.max_step<=64)}
})

// Сценарий: читатель отличает новую кромку земли от воды, FPS и всей карты.
// Исходное состояние: остановленная симуляция, прежние текстуры/правила, готовая геометрия в одном кеше.
// Ожидаемый результат: область приёмки и неизвестная стоимость не расширены редакционным текстом.
test('ground edge guide preserves static scope and open release gates',async()=>{
  const article=await readFile(join(wikiRoot,'articles/ground-edges.md'),'utf8')
  for(const value of ['1 200','11 уровней альфы','42/255','18 профильных','девять Python','Это не FPS-замер','GPU timer','кромка воды','снежный набор','VMAP-003','не является RSS']) assert.ok(article.includes(value),value)
  const summary=JSON.parse(await readFile(join(projectRoot,'docs/reports/visual-overhaul/vground-003/summary.json'),'utf8'))
  assert.equal(summary.performance_eligible,false); assert.equal(summary.gpu_time_ms,null)
})
