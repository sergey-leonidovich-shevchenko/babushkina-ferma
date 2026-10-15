import test from 'node:test'
import assert from 'node:assert/strict'
import { readFile } from 'node:fs/promises'
import { join } from 'node:path'
import { wikiRoot } from '../scripts/runtime.mjs'
import { productionPlan } from '../src/lib/production-plan.ts'

const catalog = JSON.parse(await readFile(join(wikiRoot, 'public/generated/catalog.json'), 'utf8'))
const cases = JSON.parse(await readFile(join(wikiRoot, 'public/generated/production-cases.json'), 'utf8'))

// Сценарий: каждый рецепт и дополнительные партии сравниваются с игровым расчётом.
// Исходное состояние: свежие граф и эталоны, выгруженные действующим Godot.
// Ожидаемый результат: сырьё, остатки, порядок, бонусы и остановки полностью совпадают.
test('browser plans match every Godot recipe and batch fixture', () => {
  assert.equal(cases.length, catalog.coverage.craft + 12)
  const before = JSON.stringify(catalog.production)
  for (const sample of cases) {
    const inputs = JSON.stringify(sample)
    const result = productionPlan(catalog.production.recipes, sample.index, sample.stock, sample.batches, sample.choices, sample.options)
    assert.deepEqual(result, sample.result, `recipe ${sample.index}, batches ${sample.batches}`)
    assert.equal(JSON.stringify(sample), inputs)
  }
  assert.equal(JSON.stringify(catalog.production), before)
})

// Сценарий: страницы рецептов используют адреса и источники общего графа.
// Исходное состояние: полный экспорт игрового каталога.
// Ожидаемый результат: каждая статья связана с единственным реальным индексом, листья имеют источник.
test('recipe articles and external sources remain connected', () => {
  const graph = catalog.production
  const items = new Set(catalog.entries.filter((entry) => entry.category === 'items').map((entry) => entry.id))
  for (const entry of catalog.entries.filter((entry) => entry.category === 'craft')) {
    assert.equal(graph.recipes[entry.recipe_index].id, entry.id)
    assert.equal(graph.recipes[entry.recipe_index].output, entry.output)
  }
  for (const sample of cases.slice(0, catalog.coverage.craft)) {
    for (const [kind, count] of Object.entries(sample.result.missing)) {
      assert.ok(items.has(kind) && count > 0, kind)
      assert.ok(graph.sources[kind]?.length, `missing source: ${kind}`)
    }
  }
})

// Сценарий: побочный продукт нужен раньше основного, а зависимость может замкнуться.
// Исходное состояние: маленькие графы с известными материальными балансами.
// Ожидаемый результат: основной выход переиспользуется, цикл требует внешний предмет.
test('byproducts rounding and cycles keep material conservation', () => {
  const recipes = [
    { id: 'honey', output: 'honey', count: 1, inputs: { comb: 1 }, byproducts: { wax: 1 } },
    { id: 'candle', output: 'candle', count: 1, inputs: { wax: 2, honey: 1 } },
  ]
  const result = productionPlan(recipes, 1)
  assert.deepEqual(result.missing, { comb: 2 })
  assert.deepEqual(result.remaining, { honey: 1 })
  const cycle = [{ id: 'a', output: 'a', count: 1, inputs: { b: 1 } }, { id: 'b', output: 'b', count: 1, inputs: { a: 1 } }]
  assert.deepEqual(productionPlan(cycle, 0).missing, { a: 1 })
  assert.deepEqual(productionPlan(cycle, 0).warnings, ['cycle:a'])
})

// Сценарий: огромная ветвящаяся цепь и неверный корень ограничиваются безопасно.
// Исходное состояние: двадцать уровней с удвоением и запрос тысячи партий.
// Ожидаемый результат: расчёт помечен неполным и не строит бесконечный список.
test('hard depth and operation limits reject misleading full plans', () => {
  const recipes = Array.from({ length: 20 }, (_, index) => ({ id: String(index), output: `node${index}`, count: 1, inputs: { [`node${index + 1}`]: 2 } }))
  const result = productionPlan(recipes, 0, {}, 999)
  assert.equal(result.truncated, true)
  assert.ok(result.steps.length <= 4096)
  assert.equal(productionPlan(recipes, -1).truncated, true)
})
