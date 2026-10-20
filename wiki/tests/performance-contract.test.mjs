import test from 'node:test'
import assert from 'node:assert/strict'
import { readFile } from 'node:fs/promises'
import { join } from 'node:path'
import { wikiRoot, projectRoot } from '../scripts/runtime.mjs'

// Сценарий: измеритель принят после полной отдельной нативной серии.
// Исходное состояние: полный raw-пакет и прежняя потеря фокуса сохранены раздельно.
// Ожидаемый результат: контракт принят, приёмки FPS/утечек и исторического отказа не подменены.
test('performance contract distinguishes accepted protocol from FPS and rejected history', async () => {
  const article = await readFile(join(wikiRoot,'articles/performance-contract.md'),'utf8')
  for (const text of ['Контракт измерений принят','потерей фокуса','complete=false','acceptance_granted=false','VPERF-009','VRELEASE-004']) {
    assert.ok(article.includes(text),text)
  }
  const summary = JSON.parse(await readFile(join(projectRoot,'docs/reports/visual-overhaul/vperf-001/summary.json'),'utf8'))
  assert.equal(summary.contract_accepted,true)
  assert.equal(summary.release_fps_accepted,false)
  assert.equal(summary.leak_plateau_accepted,false)
  assert.equal(summary.gpu_time_ms,null)
  assert.equal(Object.keys(summary.runs).length,4)
  assert.ok(summary.runs['long-cycle'].seconds>=600)
  const audit = JSON.parse(await readFile(join(projectRoot,'docs/reports/visual-overhaul/vperf-001/partial-audit.json'),'utf8'))
  assert.equal(audit.acceptance_granted,false)
  assert.equal(audit.source_complete,false)
  assert.deepEqual(audit.counts,{valid:3,rejected:1,missing:0})
})

// Сценарий: новая глава добавляется в существующий справочник без второго реестра готовности.
// Исходное состояние: указатель статей и исходная связь с маршрутом.
// Ожидаемый результат: стабильный ID, каноническая карточка, явные различия метрик.
test('performance contract source links the canonical first-location route', async () => {
  const index = JSON.parse(await readFile(join(wikiRoot,'articles/index.json'),'utf8'))
  assert.equal(index.filter(a=>a.id==='performance-contract').length,1)
  const article = await readFile(join(wikiRoot,'articles/performance-contract.md'),'utf8')
  for (const term of ['visual--VPERF-001','visual-pilot.md','CPU','RSS','GPU','null','p50/p95/p99/max']) assert.ok(article.includes(term),term)
})
