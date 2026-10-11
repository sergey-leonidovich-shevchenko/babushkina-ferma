extends "res://tests/suites/suite_base.gd"

const Layout := preload("res://scripts/systems/cave_layout_system.gd")
const MapData := preload("res://scripts/systems/cave_map_data.gd")
const Assets := preload("res://scripts/systems/cave_asset_system.gd")
const Lighting := preload("res://scripts/systems/cave_lighting_system.gd")
const EditorCatalog := preload("res://scripts/systems/level_editor_asset_catalog_system.gd")


## Запускает проверки проходимости пещеры, добычи, совместимости сохранений и повторного использования спрайтов.
func run() -> void:
	test_floor_is_connected_and_all_veins_are_reachable()
	test_walls_stop_player_and_enemy_without_tunneling()
	test_veins_yield_materials_and_release_depleted_bases()
	test_old_cave_save_keeps_progress_and_repairs_wall_positions()
	test_both_cave_routes_have_safe_spawns()
	test_editor_reuses_cave_profiles_in_other_locations()
	test_inspector_describes_real_walls_and_lighting_keeps_anchors()


## Сценарий: герой исследует новую пещеру от входа до каждого залежи и дальнего прохода.
## Исходное состояние: используется настоящая навигация с основаниями жил и декора; враги исключены из проверки маршрута.
## Ожидаемый результат: доступный пол образует одну область, а обе двери и все пять видов ресурсов достижимы.
func test_floor_is_connected_and_all_veins_are_reachable() -> void:
	var game := _cave_game()
	var floor := _reachable_floor(game)
	expect(floor.visited.size() == floor.walkable.size() and floor.visited.size() > 500, "cave walkable floor is one generous connected chamber")
	expect(_near_visited(floor.visited, MapData.DEEP_GATE, 38.0), "upper-right onward passage is reachable from the entrance")
	expect(_near_visited(floor.visited, MapData.EXIT, 38.0), "lower-left village exit is reachable from the entrance")
	var kinds := {}
	var cave_nodes := 0
	for node in game.resource_nodes:
		if node.location != "cave": continue
		cave_nodes += 1; kinds[node.kind] = true
		expect(_near_visited(floor.visited, node.position, 92.0), "a walkable mining stand reaches %s at %s" % [node.kind, node.position])
		expect(not Layout.blocks_position(node.position, game.PLAYER_RADIUS), "%s vein stands on the reachable side of the rock wall" % node.kind)
	expect(cave_nodes == 7 and kinds.size() == 5 and kinds.has("metal") and kinds.has("red_crystal"), "cave has seven real deposits covering stone, metal and three crystal colors")
	for enemy in game.enemy_nodes:
		if enemy.location == "cave": expect(not Layout.blocks_position(enemy.home, 27.0), "cave enemy home stays inside the new chamber")
	game.free()


## Сценарий: герой и противник делают большой шаг прямо в северную скалу.
## Исходное состояние: оба стоят на свободном полу; движение выполняется обычными подшагами навигации.
## Ожидаемый результат: они подходят к стене и останавливаются перед её основанием, не выходя наружу.
func test_walls_stop_player_and_enemy_without_tunneling() -> void:
	var game := _cave_game()
	game.enemy_nodes.clear(); game.player = Vector2(960,300)
	game.move_player_with_collisions(Vector2(0,-220))
	expect(game.player.y < 300 and game.player.y >= 192 + game.PLAYER_RADIUS + MapData.WALL_INSET, "player approaches the visible northern wall without tunneling")
	expect(game.NavigationSystem.walkability_reason(game, Vector2(960,214)) == "cave_wall", "wall footing has a specific navigation reason")
	expect(not game.NavigationSystem.is_walkable(game, Vector2(48,600)), "dark exterior rock mass is not walkable")
	expect(game.NavigationSystem.is_walkable(game, Vector2(720,600)), "old decorative cluster no longer creates an invisible central obstacle")
	var enemy: Dictionary = game.CombatSystem.default_enemies().filter(func(node): return node.location == "cave")[0]
	enemy.position = Vector2(960,300); game.enemy_nodes = [enemy]; game.player = MapData.START
	var result: Vector2 = game.NavigationSystem.move_enemy(game, 0, Vector2(0,-220))
	expect(result.y < 300 and result.y >= 192 + 27 + MapData.WALL_INSET, "enemy also stops its larger base at the same rock wall")
	expect(not Layout.blocks_position(result,27.0), "enemy final position remains inside the solid contour")
	game.free()


## Сценарий: игрок добывает каждую новую залежь до полного истощения.
## Исходное состояние: выбран исправный инструмент, а герой стоит на свободной точке в радиусе добычи.
## Ожидаемый результат: материал попадает в инвентарь, жила исчерпывается, её основание становится проходимым.
func test_veins_yield_materials_and_release_depleted_bases() -> void:
	var game := _cave_game()
	game.enemy_nodes.clear(); game.has_pickaxe = true; game.selected_tool = game.Tool.PICKAXE
	for index in game.resource_nodes.size():
		var node: Dictionary = game.resource_nodes[index]
		if node.location != "cave": continue
		game.player = _mining_stand(game, node.position)
		expect(game.NavigationSystem.is_walkable(game, game.player) and game.player.distance_to(node.position) <= 92.0, "miner stands on accessible floor near %s" % node.kind)
		var before: int = game.inventory_item_count(node.kind)
		var expected_yield := 0
		for hit in int(node.hits):
			expected_yield += game.SkillSystem.mined_count(game)
			expect(game.mine_resource(index), "pickaxe mines %s hit %d" % [node.kind,hit + 1])
		expect(game.inventory_item_count(node.kind) == before + expected_yield and int(node.hits) == 0, "%s depletion grants exactly its mining yield" % node.kind)
		expect(game.NavigationSystem.walkability_reason(game, node.position, -1, false) == "walkable", "%s depleted base is now traversable" % node.kind)
	expect(game.tutorial_events_completed.has("cave_veins"), "metal mining completes its new tutorial event")
	game.free()


## Сценарий: загружается старый снимок пещеры с пятью ресурсами и героем на месте новых скал.
## Исходное состояние: часть старых жил истощена, есть деньги и металл, один враг погиб, снимок содержит старые позиции.
## Ожидаемый результат: сохраняются награды, здоровье и добыча; новые жилы добавляются, заблокированные позиции исправляются.
func test_old_cave_save_keeps_progress_and_repairs_wall_positions() -> void:
	var source := _cave_game()
	source.player = Vector2(60,180); source.coins = 321; source.player_hp = 72
	source.change_inventory_count("metal", 9)
	source.resource_nodes[2].hits = 0; source.resource_nodes[3].hits = 1
	var enemy_index: int = 0
	for index in source.enemy_nodes.size():
		if source.enemy_nodes[index].location == "cave": enemy_index = index; break
	source.enemy_nodes[enemy_index].alive = false; source.enemy_nodes[enemy_index].hp = 0; source.enemy_nodes[enemy_index].position = Vector2(60,180)
	var data: Dictionary = source.SaveSystem.snapshot(source)
	data.resource_hits.resize(5)
	var restored := make_game()
	expect(restored.SaveSystem.apply(restored, data), "legacy cave snapshot loads through the normal save system")
	expect(restored.player == MapData.START and restored.NavigationSystem.is_walkable(restored, restored.player), "hero saved inside new rocks returns to the safe cave entrance")
	expect(restored.coins == 321 and restored.player_hp == 72 and restored.inventory_item_count("metal") == 9, "cave migration preserves money, health and collected metal")
	expect(restored.resource_nodes[2].hits == 0 and restored.resource_nodes[3].hits == 1, "legacy indexed resource depletion is preserved")
	expect(restored.resource_nodes.size() == 24 and restored.resource_nodes.slice(5,9).all(func(node): return node.hits == 3), "new cave veins keep initial hits when an old save has no entries")
	expect(not restored.enemy_nodes[enemy_index].alive and restored.enemy_nodes[enemy_index].hp == 0 and not Layout.blocks_position(restored.enemy_nodes[enemy_index].position,27), "dead enemy remains dead when its old position is repaired")
	data.player = [960,600]
	expect(restored.SaveSystem.apply(restored,data) and restored.player == Vector2(960,600), "valid saved cave position is kept")
	source.free(); restored.free()


## Сценарий: игрок входит из деревни, возвращается и затем проходит дальше через северо-восточный выход.
## Исходное состояние: переходы выполняются обычной системой дверей, без ручного изменения локации после активации.
## Ожидаемый результат: начальная точка безопасна, дверь возвращает в деревню, а северный туннель ведёт в грибной зал.
func test_both_cave_routes_have_safe_spawns() -> void:
	var game := make_game()
	game.enter_cave()
	expect(game.player == MapData.START and game.NavigationSystem.is_walkable(game,game.player), "village entrance places the hero on reachable cave floor")
	expect(game.player.distance_to(game.cave_exit_position) > game.LocationTransitionSystem.TRIGGER_RADIUS, "cave spawn stays outside the exit trigger")
	game.player = MapData.EXIT
	expect(game.LocationTransitionSystem.activate(game,"cave_exit") and game.current_location == "overworld", "lower-left door returns to the village")
	game.enter_cave(); game.player = MapData.DEEP_GATE
	expect(game.nearest_interaction() == "cave_passage:deep", "upper-right cave tunnel exposes its actual room transition")
	expect(game.LocationTransitionSystem.activate(game,"cave_passage:deep") and game.current_location == "cave_fungal", "upper-right passage enters the mushroom hall")
	game.free()


## Сценарий: дизайнер размещает пещерную жилу в другом биоме через обычную кисть редактора.
## Исходное состояние: самостоятельные PNG видны в каталоге с профилями игрового размера и нижней опоры.
## Ожидаемый результат: объект имеет правильный размер и коллизию основания, а пол доступен отдельным покрытием.
func test_editor_reuses_cave_profiles_in_other_locations() -> void:
	var game := make_game(); game.current_location = "forest"; game.camera_offset = Vector2.ZERO
	var state: Dictionary = game.LevelEditorSystem.default_state(game)
	var entry := EditorCatalog.metadata(Assets.texture("crystal_blue").resource_path)
	game.LevelEditorSystem.activate_asset(state,entry)
	expect(game.LevelEditorSystem.place_selected_asset(game,state,Vector2(720,600),false), "cave resource sprite can be placed on a different level")
	var object: Dictionary = state.objects[0]
	var bounds: Rect2 = game.LevelEditorSystem.object_bounds(object)
	var collision: Rect2 = game.LevelEditorSystem.RuntimeAuthoringSystem.collision_rect(object,bounds)
	expect(object.size == Vector2(120,120) and object.anchor == "bottom" and object.collision, "editor keeps the cave vein runtime module and anchor")
	expect(collision == Assets.collision_rect("crystal_blue",object.position), "published sprite footing matches the runtime cave vein profile")
	var floor := EditorCatalog.metadata(Assets.floor_texture().resource_path)
	expect(floor.category == "terrain" and floor.anchor == "tile" and not floor.collision, "cave floor is a reusable walkable ground material")
	game.free()


## Сценарий: инспектор изучает новую стену, а свечение кристалла меняется между кадрами.
## Исходное состояние: стены и свет используют общую схему, рисунки жил не сдвигаются.
## Ожидаемый результат: инспектор видит настоящие скалы, старые кластеры исчезают, пульсация не меняет физическую опору.
func test_inspector_describes_real_walls_and_lighting_keeps_anchors() -> void:
	var game := _cave_game()
	var objects: Array[Dictionary] = []
	game.DebugObjectInspectorSystem.append_world_props(game,objects)
	expect(objects.any(func(object): return String(object.id).begins_with("cave_wall:")), "inspector exposes the actual modular cave walls")
	expect(not objects.any(func(object): return String(object.id).begins_with("cave_decor:")), "inspector does not report removed invisible crystal clusters")
	var node: Dictionary = game.resource_nodes[2]
	var before: Rect2 = game.ResourceSystem.destination_rect(node)
	var tint_a := Lighting.vein_tint(node.kind,node.position,0)
	var tint_b := Lighting.vein_tint(node.kind,node.position,2)
	expect(not is_equal_approx(tint_a.a,tint_b.a) and game.ResourceSystem.destination_rect(node) == before, "crystal light breathes while the sprite and solid ground remain fixed")
	game.free()


## Создаёт пещеру без случайных контейнеров, чтобы проверки маршрутов зависели от постоянной схемы уровня.
func _cave_game() -> Node:
	var game := make_game()
	game.current_location = "cave"; game.player = MapData.START
	game.world_loot_nodes.clear()
	return game


## Обходит настоящий проходимый пол по сетке 48 пикселей без учёта временных позиций противников.
func _reachable_floor(game: Node) -> Dictionary:
	var walkable := {}
	for y in range(25):
		for x in range(50):
			var cell := Vector2i(x,y)
			if game.NavigationSystem.walkability_reason(game,Vector2(cell) * 48 + Vector2(24,24),-1,false) == "walkable": walkable[cell] = true
	var start := Vector2i(MapData.START / 48)
	var visited := {start: true}
	var queue: Array[Vector2i] = [start]
	var cursor := 0
	while cursor < queue.size():
		var cell: Vector2i = queue[cursor]; cursor += 1
		for direction in [Vector2i.UP,Vector2i.LEFT,Vector2i.RIGHT,Vector2i.DOWN]:
			var next: Vector2i = cell + direction
			if walkable.has(next) and not visited.has(next): visited[next] = true; queue.append(next)
	return {"walkable": walkable, "visited": visited}


## Находит доступную клетку в радиусе предметного взаимодействия с залежью или переходом.
func _near_visited(visited: Dictionary, position: Vector2, distance: float) -> bool:
	for cell in visited:
		if (Vector2(cell) * 48 + Vector2(24,24)).distance_to(position) <= distance: return true
	return false


## Выбирает безопасную точку добычи на свободной стороне жилы.
func _mining_stand(game: Node, position: Vector2) -> Vector2:
	for direction_index in 16:
		var candidate := position + Vector2.RIGHT.rotated(TAU * direction_index / 16.0) * 72.0
		if game.NavigationSystem.is_walkable(game,candidate): return candidate
	return Vector2.INF
