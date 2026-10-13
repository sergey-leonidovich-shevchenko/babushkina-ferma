import test from 'node:test'
import assert from 'node:assert/strict'
import { readFile } from 'node:fs/promises'
import { join } from 'node:path'
import { wikiRoot } from '../scripts/runtime.mjs'
import { normalize, createIndex, search, scaleMaterials } from '../src/lib/search.ts'

const catalog = JSON.parse(await readFile(join(wikiRoot, 'public/generated/catalog.json'), 'utf8'))
const index = createIndex(catalog.entries)

// Сценарий: игрок вводит ё или е, внутреннее имя, имя жителя или сочетание ингредиентов.
// Исходное состояние: настоящий справочник с полным поисковым индексом.
// Ожидаемый результат: поиск находит именно нужные страницы и ставит точное название выше упоминаний.
test('Russian aliases, actor names, ingredient combinations and internal IDs are searchable', () => {
  assert.equal(normalize('  МЁД_FIELD-MINT  '), 'мед field mint')
  assert.ok(
    search(index, 'мёд').some((entry) => entry.category === 'items' && entry.id === 'honey')
  )
  assert.equal(search(index, 'Агафья')[0].id, 'agafya')
  assert.ok(search(index, 'стекло песок').some((entry) => entry.id === 'furnace:glass'))
  assert.ok(search(index, 'field_mint').some((entry) => entry.id === 'field_mint'))
  assert.equal(search(index, 'Агафья невозможныйбуквальныйзапрос').length, 0)
})

// Сценарий: поиск ограничен одним разделом, затем запрос очищен.
// Исходное состояние: общий индекс всех материалов, станков и инструкций.
// Ожидаемый результат: фильтр не смешивает типы, пустой поиск возвращает все записи раздела.
test('category filtering and blank requests preserve catalog completeness', () => {
  assert.ok(search(index, 'сок', 'craft').every((entry) => entry.category === 'craft'))
  assert.equal(search(index, '', 'items').length, catalog.coverage.items)
  assert.equal(
    search(index, '', 'characters').length,
    catalog.entries.filter((entry) => entry.category === 'characters').length
  )
})

// Сценарий: игрок вычисляет материалы на несколько партий, включая некорректное или очень большое число.
// Исходное состояние: базовый рецепт с песком и углём без влияния талантов героя.
// Ожидаемый результат: материалы умножаются точно, входные данные не меняются, число партий ограничено 1–999.
test('batch calculator handles exact quantities and invalid input without changing the recipe', () => {
  const materials = [
    { id: 'sand', name: 'Песок', count: 3 },
    { id: 'coal', name: 'Уголь', count: 1 },
  ]
  assert.deepEqual(
    scaleMaterials(materials, 4).map((part) => part.count),
    [12, 4]
  )
  assert.deepEqual(
    scaleMaterials(materials, -8).map((part) => part.count),
    [3, 1]
  )
  assert.deepEqual(
    scaleMaterials(materials, NaN).map((part) => part.count),
    [3, 1]
  )
  assert.equal(scaleMaterials(materials, 1e9)[0].count, 2997)
  assert.equal(materials[0].count, 3)
})
