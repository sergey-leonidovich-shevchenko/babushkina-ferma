import test from 'node:test'
import assert from 'node:assert/strict'
import { readFile } from 'node:fs/promises'

const read = async path => readFile(new URL(path, import.meta.url), 'utf8')

test('street prop guide preserves cardinal directions, measured contacts and existing trade', async () => {
  const text = await read('../articles/village-street-props.md')
  for (const word of ['VPROP-003', '72×48', '60×54', 'восемь монет', 'сверху-слева', 'нулевую альфу', 'VMAP-003']) assert.ok(text.includes(word), word)
  const index = JSON.parse(await read('../articles/index.json'))
  assert.equal(index.filter(row => row.id === 'village-street-props').length, 1)
})

test('street report binds two genuine windows and four contrast backgrounds without FPS acceptance', async () => {
  const data = JSON.parse(await read('../../docs/reports/visual-overhaul/vprop-003/summary.json'))
  assert.equal(data.performance_eligible, false)
  assert.deepEqual(data.props, ['well', 'cart'])
  assert.equal(Object.keys(data.windows).length, 2)
  assert.equal(Object.values(data.windows).reduce((n, w) => n + w.before_png + w.after_png, 0), 64)
  assert.equal(Object.values(data.windows).reduce((n, w) => n + w.draw_callbacks, 0), 320)
  for (const row of Object.values(data.windows)) assert.ok(row.outside_street_equal && row.gallery_backgrounds === 4 && row.gallery_props === 2)
})
