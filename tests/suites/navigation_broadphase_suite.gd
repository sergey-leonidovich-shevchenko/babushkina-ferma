extends "res://tests/suites/suite_base.gd"

const Broadphase := preload("res://scripts/systems/navigation_broadphase_system.gd")


## Запускает сравнение ускоренного запроса с полным обходом и контракт неизменности живых коллизий.
func run() -> void:
	preload("res://tests/suites/wildlife_query_suite.gd").new(context).run()
	test_indexed_navigation_matches_exhaustive_navigation()
	test_cached_geometry_preserves_live_changes()
	test_dynamic_bound_covers_every_registered_family()
	test_stationary_geometry_is_built_only_once()


## Сценарий: герой проверяет всю деревню и повторяемые точки остальных локаций с обычным кругом коллизии.
## Исходное состояние: новый мир, все реальные здания, декорации, ресурсы и живые существа оставлены на месте.
## Ожидаемый результат: spatial buckets дают ту же точную причину блокировки, что полный исходный обход.
func test_indexed_navigation_matches_exhaustive_navigation() -> void:
	var game := make_game()
	var differences: Array[String] = []
	for location in ["overworld", "forest", "rocky", "ruins", "cave", "cursed", "pirate_ship", "cottage_interior"]:
		game.current_location = location
		var step := 36 if location == "overworld" else 120
		for y in range(120, 1140, step):
			for x in range(40, 2380, step):
				var point := Vector2(x + 0.35, y + 0.75)
				var indexed: String = game.NavigationSystem.walkability_reason(game, point)
				var reference: String = game.NavigationSystem.walkability_reason(game, point, -1, true, false)
				if indexed != reference and differences.size() < 10: differences.append("%s %s: %s / %s" % [location, point, indexed, reference])
	expect(differences.is_empty(), "indexed navigation exactly matches exhaustive collision reasons across eight locations: %s" % [differences])
	game.free()


## Сценарий: после прогрева карты игрок срубает дерево, добывает жилу и получает ключ от часовни.
## Исходное состояние: в свободном участке стоят живая взрослая крона и затем камень, дверь часовни закрыта.
## Ожидаемый результат: динамические изменения видны немедленно, постоянный индекс не замораживает мир или unlock.
func test_cached_geometry_preserves_live_changes() -> void:
	var game := make_game()
	game.current_location = "overworld"
	game.state.world.tree_nodes = [{"position": Vector2(1850, 576), "stage": 3}]
	expect(game.NavigationSystem.walkability_reason(game, Vector2(1850, 600)) == "tree", "live adult tree still blocks its exact foundation after static index warmup")
	game.state.world.tree_nodes[0].stage = 0
	expect(game.NavigationSystem.walkability_reason(game, Vector2(1850, 600)) == "walkable", "chopped tree opens the path immediately without rebuilding static geometry")
	game.resource_nodes = [{"location": "overworld", "position": Vector2(1850, 576), "hits": 1, "kind": "stone"}]
	var point: Vector2 = game.ResourceSystem.collision_rect(game.resource_nodes[0]).get_center()
	expect(game.NavigationSystem.walkability_reason(game, point) == "resource", "new resource is checked live instead of disappearing behind the static cache")
	game.resource_nodes[0].hits = 0
	expect(game.NavigationSystem.walkability_reason(game, point) == "walkable", "mined resource opens its exact footprint in the same update")
	game.current_location = "cursed"
	var door: Vector2 = game.BuildingSystem.door_rect("chapel").get_center()
	game.change_inventory_count("ancient_key", -game.inventory_item_count("ancient_key"))
	expect(Broadphase.blocks(game, "building", door, game.PLAYER_RADIUS), "cached chapel door checks its current locked state")
	game.change_inventory_count("ancient_key", 1)
	expect(not Broadphase.blocks(game, "building", door, game.PLAYER_RADIUS), "receiving the key immediately opens the already-indexed chapel door")
	game.free()


## Сценарий: все семьи растений, деревьев, ресурсов и контейнеров проходят консервативное дальнее отсечение.
## Исходное состояние: профили всех стадий строятся в нулевой точке без изменений их геометрии.
## Ожидаемый результат: запас broadphase полностью покрывает каждое основание; увеличение будущего профиля не пройдёт незаметно.
func test_dynamic_bound_covers_every_registered_family() -> void:
	var game := make_game()
	var bounds: Array[Rect2] = [game.ResourceSystem.collision_rect({"position": Vector2.ZERO})]
	for stage in 4:
		bounds.append(game.TreeSystem.collision_rect({"position": Vector2.ZERO, "stage": stage}))
		bounds.append(game.OrchardSystem.collision_rect(Vector2.ZERO, stage))
	for kind in game.ForageSystem.TYPES: bounds.append(game.ForageSystem.collision_rect({"position": Vector2.ZERO, "kind": kind}))
	for kind in game.WorldLootRenderer.WorldLootVisualSystem.kinds(): bounds.append(game.WorldLootRenderer.collision_rect(kind, Vector2.ZERO))
	var safe := Rect2(Vector2.ONE * -Broadphase.DYNAMIC_HALF_EXTENT, Vector2.ONE * Broadphase.DYNAMIC_HALF_EXTENT * 2.0)
	var valid := true
	for rect in bounds: valid = valid and safe.encloses(rect)
	expect(valid, "all registered live collider families fit inside the conservative broadphase envelope")
	game.free()


## Сценарий: сто F10-проб повторно запрашивают неизменные фундаменты деревни далеко от зданий.
## Исходное состояние: индекс зданий уже подготовлен, число его построений запомнено.
## Ожидаемый результат: профиль не пересобирается, дальняя проба посещает меньше объектов, чем полный обход.
func test_stationary_geometry_is_built_only_once() -> void:
	var game := make_game()
	game.current_location = "overworld"
	var group := Broadphase.geometry(game, "building")
	var before := Broadphase.build_count
	for _probe in 100: Broadphase.blocks(game, "building", Vector2(600, 1000), game.PLAYER_RADIUS)
	expect(before == Broadphase.build_count, "repeated actor and F10 navigation queries reuse one immutable geometry index")
	expect(Broadphase.candidates(group, Vector2(600, 1000), game.PLAYER_RADIUS).size() < group.entries.size(), "spatial query rejects distant foundations before exact collision work")
	game.free()
