extends "res://tests/suites/suite_base.gd"

const Layout := preload("res://scripts/systems/cave_layout_system.gd")
const Boss := preload("res://scripts/systems/cave_boss_system.gd")

## Проверяет точность кеша неподвижного декора и инвалидирование индекса босса при смене массива.
func run() -> void:
	test_cached_foundations_match_original_queries()
	test_boss_index_survives_replacements_and_reordering()

## Сценарий: круг героя проверяет весь пол шести комнат и точные касания объектов.
## Исходное состояние: сохранены исходные профили декора, колонн и алтаря; игрок имеет радиус 18.
## Ожидаемый результат: подготовленные Rect2 дают тот же результат, включая углы и края.
func test_cached_foundations_match_original_queries() -> void:
	var differences := 0
	for room in Layout.Rooms.IDS:
		var solids: Array = []
		if room == "cave_sanctum": solids.append_array(Layout.Rooms.Arena.solids())
		for prop in Layout.Rooms.decorations(room): solids.append(Layout.Assets.collision_rect(prop.kind,prop.position))
		var points: Array[Vector2] = []
		for y in range(120,1140,48):
			for x in range(40,2380,48): points.append(Vector2(x,y))
		for solid in solids:
			if not solid.has_area(): continue
			for corner in [solid.position,solid.end,solid.get_center()]:
				for offset in [Vector2.ZERO,Vector2(18,0),Vector2(17.99,0),Vector2(0,18)]: points.append(corner+offset)
		for point in points:
			var reference := false
			for solid in solids:
				if solid.has_area() and Layout._circle_in_rect(point,18,solid): reference = true; break
			if reference != Layout.blocks_decoration(point,18,room): differences += 1
	expect(differences == 0,"cached cave foundations match exhaustive original geometry at every probe")

## Сценарий: прогретый список врагов заменяется, переставляется и лишается босса.
## Исходное состояние: единственный хранитель найден и индекс записан в несохраняемые metadata.
## Ожидаемый результат: чужой враг не становится боссом; новое положение находится без устаревшего индекса.
func test_boss_index_survives_replacements_and_reordering() -> void:
	var game := make_game()
	var index := Boss.index(game)
	var boss: Dictionary = game.enemy_nodes[index]
	game.enemy_nodes.remove_at(index); game.enemy_nodes.push_front(boss)
	expect(Boss.index(game) == 0,"boss index follows rearranged array")
	game.enemy_nodes = game.CombatSystem.default_enemies()
	expect(Boss.index(game) == index,"boss index invalidates after replacing enemy array")
	game.enemy_nodes.clear()
	expect(Boss.index(game) == -1,"removed boss never aliases cached enemy")
	game.free()
