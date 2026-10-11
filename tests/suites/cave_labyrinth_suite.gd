extends "res://tests/suites/suite_base.gd"

const Rooms := preload("res://scripts/systems/cave_room_data.gd")
const Layout := preload("res://scripts/systems/cave_layout_system.gd")
const Content := preload("res://scripts/systems/cave_dungeon_content.gd")


## Проверяет связность лабиринта, реальные проходы, изоляцию добычи, воду и совместимость снимков.
func run() -> void:
	test_rooms_form_a_reciprocal_labyrinth_with_a_loop()
	test_every_room_has_connected_floor_and_reachable_content()
	test_tunnels_travel_both_ways_without_bouncing()
	test_depleted_veins_and_drops_stay_in_their_room()
	test_water_and_rock_partition_block_real_movement()
	test_save_round_trip_and_legacy_room_defaults()
	test_only_deep_sanctuary_exposes_the_world_exit()


## Сценарий: исследователь проходит по всем ответвлениям лабиринта и возвращается другим путём.
## Исходное состояние: шесть комнат имеют двусторонние туннели и разные схемы пола.
## Ожидаемый результат: все комнаты достижимы от входа, есть кольцо, а каждый переход имеет обратную дверь.
func test_rooms_form_a_reciprocal_labyrinth_with_a_loop() -> void:
	var visited := {"cave":true}; var pending: Array = ["cave"]; var links := 0
	while not pending.is_empty():
		var room: String = pending.pop_back()
		for passage in Rooms.passages(room):
			links += 1
			var reverse: Array = Rooms.passages(passage.target).filter(func(link): return link.port == passage.arrival and link.target == room and link.arrival == passage.port)
			expect(reverse.size() == 1,"%s/%s has a reciprocal tunnel" % [room,passage.port])
			if not visited.has(passage.target): visited[passage.target] = true; pending.append(passage.target)
	expect(visited.size() == 6 and links/2 >= visited.size(),"all six cave rooms are connected with a genuine alternative loop")
	var shapes := {}
	for room in Rooms.IDS: shapes[str(Rooms.floor_polygon(room))] = true
	expect(shapes.size() == 6,"each cave room has its own floor plan")
	expect(Rooms.POOLS.has("cave_lake") and not Rooms.ROCKS.has("cave_sanctum"),"lake keeps its water and the selected sanctuary leaves a clear central arena")


## Сценарий: герой исследует пол каждой комнаты, подходит к дверям, сундукам и жиле.
## Исходное состояние: используется настоящая навигация со стенами, водой и ресурсами; подвижные враги исключены.
## Ожидаемый результат: доступный пол связен, входы безопасны, весь постоянный интерактивный контент достижим.
func test_every_room_has_connected_floor_and_reachable_content() -> void:
	var game := make_game(); game.world_loot_nodes.clear()
	game.enemy_nodes[game.CaveBossSystem.index(game)].alive = false
	for room in Rooms.IDS:
		game.current_location = room; game.player = Layout.safe_start(room)
		var reached := _reachable(game)
		expect(reached.walkable.size() > 100 and reached.visited.size() == reached.walkable.size(),"%s has one connected walkable floor" % room)
		for passage in Rooms.passages(room):
			expect(_near(reached.visited,passage.position,38),"%s/%s passage can be reached by walking" % [room,passage.port])
		for node in game.resource_nodes:
			if node.location == room: expect(_near(reached.visited,node.position,92),"%s/%s deposit is reachable" % [room,node.kind])
		for spawn in Content.LOOT:
			if spawn.location == room:
				for position in spawn.positions: expect(_near(reached.visited,position,92),"%s chest has a reachable interaction point" % room)
		for enemy in game.enemy_nodes:
			if enemy.location == room: expect(not Layout.blocks_position(enemy.home,27,room) and not Layout.blocks_water(enemy.home,27,room),"%s enemy spawns on dry cave floor" % room)
		for passage in Rooms.passages(room):
			game.current_location = passage.target
			expect(game.NavigationSystem.walkability_reason(game,passage.spawn,-1,false) == "walkable","%s arrival from %s is not inside a vein or rock" % [passage.target,room])
			game.current_location = room
	game.free()


## Сценарий: герой входит в ответвление, не двигается после появления и возвращается через ту же дверь.
## Исходное состояние: переходы выполняет обычный автоматический контроллер; комнаты и объекты не пересоздаются.
## Ожидаемый результат: работает прямой и обратный маршрут, стоящий герой не прыгает между комнатами сам.
func test_tunnels_travel_both_ways_without_bouncing() -> void:
	var game := make_game(); game.enter_cave(); game.player = Rooms.PORTS.deep
	game.location_transition_armed = true; game.location_transition_cooldown = 0
	expect(game.LocationTransitionSystem.update(game,0) and game.current_location == "cave_fungal","entrance tunnel automatically enters the mushroom hall")
	var arrival: Vector2 = game.player
	expect(not game.LocationTransitionSystem.update(game,1) and game.player == arrival and game.current_location == "cave_fungal","standing at a safe arrival never causes an immediate return")
	for port in ["right","bottom","left","bottom","left"]:
		game.player = Rooms.PORTS[port]; game.location_transition_armed = true; game.location_transition_cooldown = 0
		expect(game.LocationTransitionSystem.update(game,0),"automatic tunnel route accepts %s" % port)
		expect(game.NavigationSystem.walkability_reason(game,game.player,-1,false) == "walkable","automatic tunnel puts the player on valid floor")
	expect(game.current_location == "cave","the mushroom, moon, lake and mine loop returns to the entrance hall")
	expect(game.tutorial_events_completed.has("cave_labyrinth"),"first internal passage completes the labyrinth tutorial")
	game.player = Rooms.PORTS.deep
	expect(game.GameInteractionRouter.perform(game) and game.current_location == "cave_fungal","context interaction also enters the actual cave tunnel")
	expect(game.PresentationSystem.interaction_position(game,"cave_passage:top") == Rooms.PORTS.top,"interaction highlight uses the true tunnel position")
	game.free()


## Сценарий: игрок истощает грибную жилу, оставляет камень, уходит в лунный грот и возвращается.
## Исходное состояние: комнаты имеют отдельные объекты и предметы с явно сохранённой локацией.
## Ожидаемый результат: добыча не восстанавливается, чужой предмет нельзя подобрать или увидеть в инспекторе.
func test_depleted_veins_and_drops_stay_in_their_room() -> void:
	var game := make_game(); game.current_location = "cave_fungal"; game.enemy_nodes.clear(); game.world_loot_nodes.clear()
	game.has_pickaxe = true; game.selected_tool = game.Tool.PICKAXE
	var node: Dictionary = game.resource_nodes[9]; game.player = node.position+Vector2(0,72)
	for hit in int(node.hits): expect(game.mine_resource(9),"mushroom-room deposit can actually be mined")
	game.change_inventory_count("stone",1); game.inventory_slots[0] = "stone"; game.inventory_selected = 0
	expect(game.drop_selected_item(),"player leaves a real item in the mushroom room")
	var drop: Dictionary = game.dropped_items.back()
	expect(drop.location == "cave_fungal","new drop records the cave room that owns it")
	game.current_location = "cave_moon"; game.player = drop.position
	expect(not game.collect_dropped_item(game.dropped_items.size()-1),"same coordinates in a different room do not allow pickup")
	var objects: Array[Dictionary] = game.DebugObjectInspectorSystem.candidates(game)
	expect(not objects.any(func(object): return String(object.id).begins_with("drop:")),"inspector does not expose another room's dropped item")
	game.current_location = "cave_fungal"
	expect(game.resource_nodes[9].hits == 0 and game.collect_dropped_item(game.dropped_items.size()-1),"return keeps the vein depleted and allows retrieving the local drop")
	game.free()


## Сценарий: герой и противник пытаются пересечь берег озера и проходят по открытому центру святилища.
## Исходное состояние: изображение озера совпадает с навигацией, вариант А не содержит центральной скалы.
## Ожидаемый результат: большие движения останавливаются у берега, в святилище есть место для уклонения.
func test_water_and_rock_partition_block_real_movement() -> void:
	var game := make_game(); game.current_location = "cave_lake"; game.enemy_nodes.clear(); game.world_loot_nodes.clear()
	game.player = Vector2(960,360); game.move_player_with_collisions(Vector2(0,240))
	expect(game.player.y > 360 and game.player.y < 552 and not Layout.blocks_water(game.player,game.PLAYER_RADIUS,"cave_lake"),"player stops on the visible irregular lake bank")
	expect(game.NavigationSystem.walkability_reason(game,Vector2(960,552)) == "cave_water","lake surface is a specific impassable navigation area")
	game.enemy_nodes = game.CombatSystem.default_enemies().filter(func(enemy): return enemy.location == "cave_lake")
	game.enemy_nodes[0].position = Vector2(960,360); game.player = Vector2(1200,288)
	var enemy_end: Vector2 = game.NavigationSystem.move_enemy(game,0,Vector2(0,240))
	expect(enemy_end.y < 552 and not Layout.blocks_water(enemy_end,27,"cave_lake"),"enemy cannot tunnel across underground water")
	game.current_location = "cave_sanctum"
	expect(game.NavigationSystem.walkability_reason(game,Vector2(1200,600),-1,false) == "walkable","selected sanctuary centre remains open for dodging")
	expect(game.NavigationSystem.walkability_reason(game,Vector2(1008,600),-1,false) == "walkable","floor beside the altar remains traversable")
	game.free()


## Сценарий: снимок лунного грота загружается, затем загружается старая пещера без новых комнат.
## Исходное состояние: изменены жила, здоровье врага и оставленный предмет; старый снимок хранит только прежние индексы.
## Ожидаемый результат: комната и прогресс восстанавливаются, старые индексы не сдвигаются, новые комнаты получают начальный контент.
func test_save_round_trip_and_legacy_room_defaults() -> void:
	var source := make_game(); source.current_location = "cave_moon"; source.player = Vector2(648,432)
	source.resource_nodes[12].hits = 1; source.enemy_nodes.back().hp = 7
	source.dropped_items = [{"kind":"stone","count":2,"position":Vector2(648,480),"location":"cave_fungal"}]
	var saved: Dictionary = source.SaveSystem.snapshot(source)
	var restored := make_game()
	expect(restored.SaveSystem.apply(restored,saved) and restored.current_location == "cave_moon" and restored.player == source.player,"normal save restores exact cave room and valid position")
	expect(restored.resource_nodes[12].hits == 1 and restored.enemy_nodes.back().hp == 7,"room-specific veins and enemy progress survive loading")
	expect(restored.dropped_items[0].location == "cave_fungal","drop ownership survives a save made in another cave room")
	expect(restored.WorldMapSystem.current_region(restored) == "cave","cave rooms share their real region on the world map")
	saved.location = "cave"; saved.player = [408,960]; saved.resource_hits.resize(9); saved.resource_hits[2] = 0
	saved.enemies.resize(source.CombatSystem.SPAWNS.size()); saved.containers = saved.containers.filter(func(container): return not String(container.location).begins_with("cave_"))
	saved.drops[0].erase("location")
	expect(restored.SaveSystem.apply(restored,saved),"pre-labyrinth cave snapshot remains valid")
	expect(restored.resource_nodes[2].hits == 0 and restored.resource_nodes[12].hits == 3,"legacy vein indices stay stable and absent new-room progress resets to its defaults")
	expect(restored.world_loot_nodes.any(func(container): return container.location == "cave_sanctum"),"legacy snapshot receives missing room chests without removing old ones")
	expect(restored.dropped_items[0].location == "cave","legacy drop belongs to the location where its snapshot was saved")
	expect(restored.enemy_nodes.back().alive and restored.enemy_nodes.back().hp == restored.enemy_nodes.back().max_hp,"absent new-room enemy progress receives fresh defaults when loading another snapshot")
	var invalid := saved.duplicate(true); invalid.drops[0].location = 42
	var before: Dictionary = restored.SaveSystem.snapshot(restored)
	expect(not restored.SaveSystem.apply(restored,invalid) and restored.SaveSystem.snapshot(restored) == before,"invalid drop-room field is rejected before any state mutation")
	source.free(); restored.free()


## Сценарий: игрок ищет внешний проход в разных комнатах, а затем достигает глубокого святилища.
## Исходное состояние: только северный туннель святилища связан с проклятой землёй и открывается после победы.
## Ожидаемый результат: другие комнаты не предлагают прежний короткий переход мира; конечный выход работает.
func test_only_deep_sanctuary_exposes_the_world_exit() -> void:
	var game := make_game()
	for room in Rooms.IDS:
		game.current_location = room; game.player = Rooms.PORTS.deep
		if room == "cave_sanctum": continue
		expect(game.nearest_interaction() != "world_gate" and not game.LocationTransitionSystem.activate(game,"world_gate"),"%s does not bypass the cave labyrinth" % room)
	game.current_location = "cave_sanctum"; game.player = game.world_gate_position
	expect(not game.LocationTransitionSystem.activate(game,"world_gate"),"living sanctuary guardian seals the onward exit")
	game.enemy_nodes[game.CaveBossSystem.index(game)].alive = false
	expect(game.nearest_interaction() == "world_gate","sanctuary exposes the actual onward world passage")
	expect(game.LocationTransitionSystem.activate(game,"world_gate") and game.current_location == "cursed","deep passage retains the existing onward world connection")
	game.free()


## Обходит проходимые клетки настоящей навигации без временных коллизий противников.
func _reachable(game: Node) -> Dictionary:
	var walkable := {}
	for y in 25:
		for x in 50:
			var cell := Vector2i(x,y)
			if game.NavigationSystem.walkability_reason(game,Vector2(cell)*48+Vector2(24,24),-1,false) == "walkable": walkable[cell] = true
	var start := Vector2i(game.player/48); var visited := {start:true}; var queue: Array = [start]; var cursor := 0
	while cursor < queue.size():
		var cell: Vector2i = queue[cursor]; cursor += 1
		for direction in [Vector2i.UP,Vector2i.DOWN,Vector2i.LEFT,Vector2i.RIGHT]:
			var next: Vector2i = cell+direction
			if walkable.has(next) and not visited.has(next): visited[next] = true; queue.append(next)
	return {"walkable":walkable,"visited":visited}


## Находит достигнутую клетку в реальном радиусе взаимодействия с жилой или дверью.
func _near(visited: Dictionary, position: Vector2, distance: float) -> bool:
	for cell in visited:
		if (Vector2(cell)*48+Vector2(24,24)).distance_to(position) <= distance: return true
	return false
