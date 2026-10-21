import test from 'node:test'
import assert from 'node:assert/strict'
import {readFile} from 'node:fs/promises'
import {join} from 'node:path'
import {projectRoot,wikiRoot} from '../scripts/runtime.mjs'

// Сценарий: глава показывает форму нового торца отдельно от мягкости и материала.
// Исходное состояние: серия A, одинаковая камера и прозрачные листы старой/новой маски.
// Ожидаемый результат: кадры и первичные данные доступны, фактическая форма подтверждена.
test('axial road guide exposes native flat-end proof and canonical task',async()=>{
  const article=await readFile(join(wikiRoot,'articles/axial-roads.md'),'utf8')
  const index=JSON.parse(await readFile(join(wikiRoot,'articles/index.json'),'utf8'))
  assert.equal(index.filter(x=>x.id==='axial-roads').length,1)
  for(const value of ['visual--VGROUND-004','ground-edges.md','visual-pilot.md','summary.json','native/source.json','retained.json']) assert.ok(article.includes(value),value)
  const images=[...article.matchAll(/!\[[^\]]*\]\(([^)]+)\)/g)]
  assert.equal(images.length,4)
  for(const image of images) assert.ok((await readFile(join(wikiRoot,'articles',image[1]))).length>1000)
  const summary=JSON.parse(await readFile(join(projectRoot,'docs/reports/visual-overhaul/vground-004/summary.json'),'utf8'))
  for(const row of Object.values(summary.windows)) {assert.equal(row.png_count,27); assert.equal(row.draw_callbacks,81); assert.deepEqual(row.mask.flat_end_alpha,[255,255,255]); assert.deepEqual(row.mask.legacy_end_alpha,[166,255,141]); assert.equal(row.mask.alpha_exact_after_recolor,true)}
})

// Сценарий: форма не объявляется новым проходом, зимним набором или полной приёмкой карты.
// Исходное состояние: прежние коллизии и материалы, статичные кадры и обратимый флаг.
// Ожидаемый результат: сохранность правил и открытые ворота FPS/VMAP явно названы.
test('axial road guide preserves navigation, legacy rollback and release limits',async()=>{
  const article=await readFile(join(wikiRoot,'articles/axial-roads.md'),'utf8')
  for(const value of ['1 200','восемь диагональных','прежнего AABB','24 профильных','11 Python','не FPS-замер','без миграции слотов','VMAP-003','снежный набор','не является RSS/VRAM']) assert.ok(article.includes(value),value)
  const summary=JSON.parse(await readFile(join(projectRoot,'docs/reports/visual-overhaul/vground-004/summary.json'),'utf8'))
  assert.equal(summary.performance_eligible,false); assert.equal(summary.gpu_time_ms,null)
})
