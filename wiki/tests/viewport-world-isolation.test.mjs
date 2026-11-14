import test from 'node:test'
import assert from 'node:assert/strict'
import {readFile} from 'node:fs/promises'
const read=async path=>readFile(new URL(path,import.meta.url),'utf8')

test('viewport guide defines bounded ownership and keeps the full overworld route explicit',async()=>{
  const text=await read('../articles/viewport-world-isolation.md')
  for(const value of ['VRENDER-009','игра → viewport → фон','F12','village_market','20 production draw','VMAP-003','не FPS-допуск']) assert.ok(text.includes(value),value)
  assert.equal((text.match(/vrender-009\/native\/[a-z-]+\.png/g)||[]).length,3)
  const index=JSON.parse(await read('../articles/index.json'))
  assert.equal(index.filter(row=>row.id==='viewport-world-isolation').length,1)
})

test('native summary binds two owners, five cases and every full save pair',async()=>{
  const data=JSON.parse(await read('../../docs/reports/visual-overhaul/vrender-009/summary.json'))
  assert.equal(data.task,'VRENDER-009');assert.equal(data.native_cases,5)
  assert.equal(data.production_draws,20);assert.equal(data.full_save_pairs,20)
  assert.equal(data.performance_eligible,false);assert.equal(data.full_map_accepted,false)
  assert.deepEqual(data.configuration.window,[1152,648])
  assert.notEqual(data.owners.game.game,data.owners.preview.game)
  assert.equal(data.images.length,15)
})
