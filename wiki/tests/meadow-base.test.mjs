import test from 'node:test'
import assert from 'node:assert/strict'
import {readFile} from 'node:fs/promises'
import {join} from 'node:path'
import {projectRoot,wikiRoot} from '../scripts/runtime.mjs'

// Сценарий: глава доступна через каталог и показывает реальные сравнения новой основы травы.
// Исходное состояние: финальная серия C в двух окнах и отдельный лист 5×5 при 120%.
// Ожидаемый результат: четыре изображения и первичные JSON существуют, данные не превращаются в заявления FPS.
test('meadow guide exposes source-bound native art and actual comparison evidence',async()=>{
  const article=await readFile(join(wikiRoot,'articles/meadow-base.md'),'utf8')
  const index=JSON.parse(await readFile(join(wikiRoot,'articles/index.json'),'utf8'))
  assert.equal(index.filter(x=>x.id==='meadow-base').length,1)
  for(const value of ['visual--VGROUND-001','visual-pilot.md','ground-layers.md','art-source.json','summary.json','native/source.json','retained.json']) assert.ok(article.includes(value),value)
  const images=[...article.matchAll(/!\[[^\]]*\]\(([^)]+)\)/g)]
  assert.equal(images.length,4)
  for(const image of images) assert.ok((await readFile(join(wikiRoot,'articles',image[1]))).length>1000)
  const summary=JSON.parse(await readFile(join(projectRoot,'docs/reports/visual-overhaul/vground-001/summary.json'),'utf8'))
  assert.equal(summary.performance_eligible,false); assert.equal(summary.gpu_time_ms,null)
  for(const row of Object.values(summary.windows)) {assert.equal(row.png_count,24); assert.equal(row.draw_callbacks,81); assert.equal(row.draw_calls_before,row.draw_calls_after)}
})

// Сценарий: читатель оценивает частичный перенос первой локации и его ограничения.
// Исходное состояние: новая трава, прежние дороги/берега, остановленная симуляция и сохранённый откат.
// Ожидаемый результат: художественные/сезонные ограничения и неизвестная стоимость явно названы.
test('meadow guide preserves art, simulation, memory and full-map limits',async()=>{
  const article=await readFile(join(wikiRoot,'articles/meadow-base.md'),'utf8')
  for(const value of ['1 200','512×512 + mipmaps','не FPS-замер','не является снежным','VMAP-003','зеркальная периодичность','старый ресурс сохранён','1,33 МиБ','1,33']) assert.ok(article.includes(value),value)
  const source=JSON.parse(await readFile(join(projectRoot,'docs/reports/visual-overhaul/vground-001/art-source.json'),'utf8'))
  assert.equal(source.generator,'built-in image_gen'); assert.equal(source.selected,'masters/grass-calm-v2.png')
})
