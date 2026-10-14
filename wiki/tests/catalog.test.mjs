import test from 'node:test'
import assert from 'node:assert/strict'
import { readFile } from 'node:fs/promises'
import { join } from 'node:path'
import { wikiRoot, projectRoot } from '../scripts/runtime.mjs'
import { validateCatalog, chapters } from '../scripts/prepare.mjs'

const catalog = JSON.parse(await readFile(join(wikiRoot, 'public/generated/catalog.json'), 'utf8'))
const version = (await readFile(join(projectRoot, 'VERSION'), 'utf8')).trim()

// Сценарий: статьи предметов, рецептов и растений используют окраску настоящего игрового сырья.
// Исходное состояние: свежий общий экспорт с травой, порошком, рудой и деталями.
// Ожидаемый результат: цвет не теряется в Wiki и совпадает у всех перекрёстных представлений предмета.
test('item tint is preserved in linked recipe and plant previews', () => {
  for (const id of ['field_mint', 'moon_grass_powder', 'iron_ore', 'wood_offcut']) {
    const item = catalog.entries.find((entry) => entry.category === 'items' && entry.id === id)
    assert.match(item.tint, /^[0-9a-f]{6}$/)
    assert.notEqual(item.tint, 'ffffff')
    for (const recipe of catalog.entries.filter(
      (entry) => entry.category === 'craft' && entry.output === id
    )) {
      assert.equal(recipe.tint, item.tint)
      assert.deepEqual(recipe.icon, item.icon)
    }
    const plant = catalog.entries.find((entry) => entry.category === 'plants' && entry.id === id)
    if (plant) {
      assert.equal(plant.tint, item.tint)
      assert.deepEqual(plant.icon, item.icon)
    }
  }
})

// Сценарий: все текущие каталоги доступны в браузере через самостоятельные статьи.
// Исходное состояние: свежая выгрузка из Godot, обогащённая руководством.
// Ожидаемый результат: количества и все перекрёстные ссылки соответствуют игре.
test('complete live catalogs and all cross-links validate', () => {
  const counts = validateCatalog(catalog)
  assert.equal(counts.items, catalog.coverage.items)
  assert.equal(counts.craft, catalog.coverage.craft)
  assert.equal(
    catalog.entries.filter(
      (entry) => entry.source === 'scripts/systems/quest_system.gd' && entry.category === 'missions'
    ).length,
    catalog.coverage.quests
  )
  assert.equal(
    catalog.entries.filter(
      (entry) => entry.category === 'buildings' && entry.id.startsWith('station-')
    ).length,
    catalog.coverage.stations
  )
  assert.equal(catalog.meta.version, version)
})

// Сценарий: просмотр каждого персонажа использует существующие кадры, которые помещаются в свой атлас.
// Исходное состояние: все герои, жители, напарники, звери и призывы экспортированы вместе с ресурсами.
// Ожидаемый результат: каждый PNG существует, размеры совпадают с метаданными, фиктивных направлений нет.
test('every sprite is a real PNG and every character can be inspected', async () => {
  for (const [path, expected] of Object.entries(catalog.images)) {
    const file = await readFile(join(wikiRoot, 'public', path))
    assert.equal(file.subarray(1, 4).toString(), 'PNG', path)
    assert.deepEqual([file.readUInt32BE(16), file.readUInt32BE(20)], expected, path)
  }
  const hero = catalog.entries.find(
    (entry) => entry.category === 'characters' && entry.id === 'hero'
  )
  assert.deepEqual(Object.keys(hero.animation.clips[1].frames).sort(), [
    'east',
    'north',
    'south',
    'west',
  ])
  assert.ok(hero.animation.clips.some((clip) => clip.id === 'bow'))
  assert.ok(hero.animation.clips.some((clip) => clip.id === 'pickaxe'))
  const skeleton = catalog.entries.find(
    (entry) => entry.category === 'characters' && entry.id === 'skeleton'
  )
  assert.equal(Object.keys(skeleton.animation.clips[1].frames).length, 8)
  assert.ok(skeleton.animation.clips.some((clip) => clip.id === 'attack'))
})

// Сценарий: страницы станков предлагают выбор направления для каждого уровня и строительной кучи.
// Исходное состояние: все станки экспортированы с уровнями и строительными кучами.
// Ожидаемый результат: доступны три видимых ракурса, задняя сторона не предлагается.
test('workstations only expose front and side views', () => {
  const stations = catalog.entries.filter(
    (entry) => entry.category === 'buildings' && entry.id.startsWith('station-')
  )
  assert.equal(stations.length, catalog.coverage.stations)
  for (const station of stations) {
    for (const clip of station.animation.clips) {
      assert.deepEqual(Object.keys(clip.frames).sort(), ['east', 'south', 'west'], station.id)
    }
  }
})

// Сценарий: каталог содержит повреждённую ссылку или выходящий за изображение кадр.
// Исходное состояние: независимые копии корректного справочника.
// Ожидаемый результат: ни один дефект не может попасть в опубликованную сборку.
test('broken references and sprite bounds stop publication', () => {
  const links = structuredClone(catalog)
  links.entries[0].relations.push({ category: 'items', id: 'missing', group: 'test', label: '' })
  assert.throws(() => validateCatalog(links), /Отсутствует связанная статья/)
  const frames = structuredClone(catalog)
  const actor = frames.entries.find((entry) => entry.animation)
  actor.animation.clips[0].frames[Object.keys(actor.animation.clips[0].frames)[0]][0].rect[2] =
    999999
  assert.throws(() => validateCatalog(frames), /Кадр выходит за атлас/)
})

// Сценарий: две главы имеют одинаковый заголовок, а текст содержит исходный HTML.
// Исходное состояние: Markdown-руководство, которое становится читаемыми страницами.
// Ожидаемый результат: адреса уникальны, содержимое сохраняется, технический заголовок не становится пустой статьёй.
test('guide chapters have stable unique addresses and complete text', () => {
  const entries = chapters(
    '# Guide\n\n## Мёд\nОписание и рецепт.\n## Мёд\nДругой раздел.',
    'game',
    'docs/GAME_GUIDE.md'
  )
  assert.deepEqual(
    entries.map((entry) => entry.id),
    ['game-мед', 'game-мед-1']
  )
  assert.ok(entries[0].summary.includes('рецепт'))
  assert.ok(
    catalog.entries
      .filter((entry) => entry.category === 'guides')
      .every((entry) => entry.html && !/<script\b/i.test(entry.html))
  )
})
