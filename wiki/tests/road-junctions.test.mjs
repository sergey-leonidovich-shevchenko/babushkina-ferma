import test from 'node:test'
import assert from 'node:assert/strict'
import {readFile} from 'node:fs/promises'
import {join} from 'node:path'
import {projectRoot,wikiRoot} from '../scripts/runtime.mjs'

// Сценарий: глава открывает фактические кадры соединений и независимый контроль покрытия.
// Исходное состояние: серия A с одинаковыми камерой, материалом и полным альфа-каналом.
// Ожидаемый результат: четыре изображения и первичные данные доступны, критерии единого прохода выполнены.
test('road junction guide exposes native pairs and independent union proof',async()=>{
  const article=await readFile(join(wikiRoot,'articles/road-junctions.md'),'utf8')
  const index=JSON.parse(await readFile(join(wikiRoot,'articles/index.json'),'utf8'))
  assert.equal(index.filter(x=>x.id==='road-junctions').length,1)
  for(const value of ['visual--VGROUND-005','axial-roads.md','visual-pilot.md','summary.json','native/source.json','retained.json']) assert.ok(article.includes(value),value)
  const images=[...article.matchAll(/!\[[^\]]*\]\(([^)]+)\)/g)]
  assert.equal(images.length,4)
  for(const image of images) assert.ok((await readFile(join(wikiRoot,'articles',image[1]))).length>1000)
  const summary=JSON.parse(await readFile(join(projectRoot,'docs/reports/visual-overhaul/vground-005/summary.json'),'utf8'))
  for(const row of Object.values(summary.windows)) {
    assert.equal(row.png_count,34); assert.equal(row.draw_callbacks,105)
    assert.equal(row.mask.alpha_max_error,0); assert.ok(row.mask.single_pass_color.max<=1)
    assert.equal(row.mask.alpha_exact_after_recolor,true); assert.equal(row.mask.arm_width_pixels.length,5)
    assert.ok(row.junctions['junction-north'].mean>.05)
  }
})

// Сценарий: принятые стыки не закрывают всю карту и стоимость живого мира.
// Исходное состояние: статичные пары с прежними навигацией и слотами.
// Ожидаемый результат: в главе явно названы откат, сохранность правил и незавершённые ворота.
test('road junction guide keeps gameplay and release boundaries explicit',async()=>{
  const article=await readFile(join(wikiRoot,'articles/road-junctions.md'),'utf8')
  for(const value of ['166 010','1 200','восемь движений','23 профильных','9 Python','не FPS-замер','без миграции слотов','VMAP-003','снежный набор','не равен RSS/VRAM']) assert.ok(article.includes(value),value)
  const summary=JSON.parse(await readFile(join(projectRoot,'docs/reports/visual-overhaul/vground-005/summary.json'),'utf8'))
  assert.equal(summary.performance_eligible,false); assert.equal(summary.gpu_time_ms,null)
})
