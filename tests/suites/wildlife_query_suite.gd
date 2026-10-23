extends "res://tests/suites/suite_base.gd"

const Navigation := preload("res://scripts/systems/navigation_system.gd")
const WildlifeNavigation := preload("res://scripts/systems/wildlife_navigation_system.gd")


## Сравнивает пакетные пробы животных с исходным полным обходом и проверяет срок жизни выборки.
func run() -> void:
	test_local_queries_match_complete_collision_reasons()
	test_local_view_keeps_live_objects_and_new_batch_sees_spawns()
	test_previous_map_view_falls_back_after_teleport()
	test_foreign_game_view_is_rejected()
	test_wildlife_trajectory_matches_reference_substeps()


## Сценарий: звери проверяют землю, воду и препятствия на восьми настоящих картах.
## Исходное состояние: полный новый мир и отдельная рабочая выборка каждой активной локации.
## Ожидаемый результат: причина каждой пробы совпадает с полным обходом, чужие карты не копируются в пакет.
func test_local_queries_match_complete_collision_reasons() -> void:
	var game := make_game()
	var differences: Array[String] = []
	for location in [
		"overworld", "forest", "rocky", "ruins", "cave", "cursed", "pirate_ship", "cottage_interior"
	]:
		game.current_location = location
		var query := Navigation.location_query(game)
		for y in range(140, 1140, 140):
			for x in range(60, 2380, 140):
				var point := Vector2(x + 0.35, y + 0.75)
				for include_enemies in [false, true]:
					var full := Navigation.walkability_reason(game, point, -1, include_enemies)
					var local := Navigation.walkability_reason(
						game, point, -1, include_enemies, true, query
					)
					if full != local and differences.size() < 10:
						differences.append("%s %s: %s/%s" % [location, point, full, local])
		expect(
			query.resources.all(func(node): return node.location == location),
			"resource view contains only the current map: " + location
		)
		expect(
			query.containers.all(func(node): return node.location == location),
			"container view contains only the current map: " + location
		)
		expect(
			query.food.all(func(node): return node.get("location", "overworld") == location),
			"food view retains the legacy default map: " + location
		)
	expect(
		differences.is_empty(),
		"local batch preserves all sampled real collision reasons: %s" % [differences]
	)
	game.free()


## Сценарий: две независимые игры находятся на одной карте с различными живыми ресурсами.
## Исходное состояние: в первой игре свободная земля, во второй на ней стоит камень.
## Ожидаемый результат: случайно переданная чужая выборка отвергается и не скрывает препятствия другой игры.
func test_foreign_game_view_is_rejected() -> void:
	var first := make_game()
	var second := make_game()
	first.current_location = "overworld"
	second.current_location = "overworld"
	first.resource_nodes.clear()
	second.state.world.tree_nodes.clear()
	second.resource_nodes = [
		{"location": "overworld", "position": Vector2(1850, 576), "hits": 1, "kind": "stone"}
	]
	var point: Vector2 = second.ResourceSystem.collision_rect(second.resource_nodes[0]).get_center()
	var foreign := Navigation.location_query(first)
	expect(
		Navigation.walkability_reason(second, point, -1, true, true, foreign) == "resource",
		"local batch is bound to its actual game owner"
	)
	first.free()
	second.free()


## Сценарий: в пакете добывается камень, затем следующий пакет получает новый ресурс и еду старого формата.
## Исходное состояние: две карты ресурсов и живой словарь камня на свободной земле первой локации.
## Ожидаемый результат: изменения hits видны немедленно, новые объекты попадают в следующую выборку, чужие массивы не меняются.
func test_local_view_keeps_live_objects_and_new_batch_sees_spawns() -> void:
	var game := make_game()
	game.current_location = "overworld"
	game.state.world.tree_nodes.clear()
	game.resource_nodes = [
		{"location": "overworld", "position": Vector2(1850, 576), "hits": 1, "kind": "stone"},
		{"location": "forest", "position": Vector2(1850, 576), "hits": 1, "kind": "stone"},
	]
	game.food_nodes = [{"position": Vector2(2200, 650), "kind": "apple"}]
	var query := Navigation.location_query(game)
	var point: Vector2 = game.ResourceSystem.collision_rect(game.resource_nodes[0]).get_center()
	expect(
		query.resources.size() == 1 and game.resource_nodes.size() == 2,
		"local view avoids remote nodes without removing original world objects"
	)
	expect(
		is_same(query.resources[0], game.resource_nodes[0]),
		"filtered obstacles share the live dictionary instead of freezing a copy"
	)
	expect(
		Navigation.walkability_reason(game, point, -1, true, true, query) == "resource",
		"batch still blocks the complete live resource footprint"
	)
	game.resource_nodes[0].hits = 0
	expect(
		Navigation.walkability_reason(game, point, -1, true, true, query) == "walkable",
		"mining the resource is visible in the same batch"
	)
	game.resource_nodes.append(
		{"location": "overworld", "position": Vector2(1850, 576), "hits": 1, "kind": "stone"}
	)
	var next_query := Navigation.location_query(game)
	expect(
		(
			next_query.resources.size() == 2
			and Navigation.walkability_reason(game, point, -1, true, true, next_query) == "resource"
		),
		"next synchronous batch sees newly added blockers without a cache invalidation protocol"
	)
	expect(next_query.food.size() == 1, "food without a location remains an overworld obstacle")
	game.free()


## Сценарий: переход меняет карту, пока вызывающий код ещё держит предыдущую рабочую выборку.
## Исходное состояние: подготовленная выборка деревни и полный мир с настоящими препятствиями пещеры.
## Ожидаемый результат: чужая выборка не скрывает ни одного препятствия новой карты.
func test_previous_map_view_falls_back_after_teleport() -> void:
	var game := make_game()
	game.current_location = "overworld"
	var query := Navigation.location_query(game)
	game.current_location = "cave"
	var matches := true
	for y in range(140, 900, 120):
		for x in range(60, 2200, 120):
			var point := Vector2(x, y)
			matches = (
				matches
				and (
					Navigation.walkability_reason(game, point, -1, true, true, query)
					== Navigation.walkability_reason(game, point)
				)
			)
	expect(
		matches, "map switch discards a foreign local view and preserves exact collision reasons"
	)
	game.free()


## Сценарий: все живые звери деревни многократно идут по диагонали и скользят около препятствий.
## Исходное состояние: настоящая геометрия, одинаковые отдельные состояния зверя и 60 физических подшагов.
## Ожидаемый результат: выборка не меняет восстановление habitat, точные позиции, радиус дома или обход стены.
func test_wildlife_trajectory_matches_reference_substeps() -> void:
	var game := make_game()
	game.current_location = "overworld"
	var query := Navigation.location_query(game)
	var matches := true
	for original in game.wildlife_nodes:
		if original.location != "overworld" or not original.alive:
			continue
		var reference: Dictionary = original.duplicate(true)
		var selected: Dictionary = original.duplicate(true)
		WildlifeNavigation.ensure_habitat(game, reference)
		WildlifeNavigation.ensure_habitat(game, selected, query)
		matches = matches and reference == selected
		for tick in 60:
			var direction := Vector2.RIGHT.rotated(float(tick) * 0.11)
			reference.position = WildlifeNavigation.steer(game, reference, direction, 4.0, 320.0)
			selected.position = WildlifeNavigation.steer(
				game, selected, direction, 4.0, 320.0, query
			)
			matches = matches and reference.position == selected.position
	expect(matches, "local query preserves exact habitat and every reference wildlife substep")
	game.free()
