extends RefCounted

const PirateShipSystem := preload("res://scripts/systems/pirate_ship_system.gd")
const VillageLayoutSystem := preload("res://scripts/systems/village_layout_system.gd")

## Выполняет операцию «перемещения» и возвращает результат согласно контракту метода.
static func move(game: Node, motion: Vector2) -> void:
	if game.DebugOverlaySystem.noclip(game):
		game.player += motion
		return
	var step_count := maxi(1, ceili(motion.length() / 8.0))
	var step := motion / float(step_count)
	var was_blocked := false
	for _index in step_count:
		var horizontal: Vector2 = game.player + Vector2(step.x, 0.0)
		if is_walkable(game, horizontal):
			game.player = horizontal
		elif not is_zero_approx(step.x):
			was_blocked = true
		var vertical: Vector2 = game.player + Vector2(0.0, step.y)
		if is_walkable(game, vertical):
			game.player = vertical
		elif not is_zero_approx(step.y):
			was_blocked = true
	if was_blocked:
		game.notify_tutorial("collision")

## Проверяет заявленное методом условие без изменения игрового состояния.
static func is_walkable(game: Node, position: Vector2) -> bool:
	return walkability_reason(game, position) == "walkable"


## Объясняет результат навигации кодом конкретного препятствия для игровой диагностики.
static func walkability_reason(game: Node, position: Vector2) -> String:
	if game.DebugPlaygroundSystem.active(game): return "walkable" if game.DebugPlaygroundSystem.is_walkable(game, position, game.PLAYER_RADIUS) else "debug_obstacle"
	if game.MoonGladeSystem.blocks_position(game, position, game.PLAYER_RADIUS): return "guardian"
	if game.BuildingSystem.is_interior(game.current_location):
		if game.FarmLifeSystem.blocks_position(game,position,game.PLAYER_RADIUS): return "furniture"
		if game.current_location == "cottage_interior" and game.home_chest_owned and circle_intersects_rect(position,game.PLAYER_RADIUS,game.InteriorVisualSystem.collision_rect("home_chest",game.StorageSystem.CHEST_POSITION)):
			return "storage"
		return "walkable" if game.BuildingSystem.is_walkable_inside(game.current_location, position, game.PLAYER_RADIUS) else "interior"
	if game.current_location == "pirate_ship" and not PirateShipSystem.is_walkable(position, game.PLAYER_RADIUS): return "ship"
	if position.x < 40.0 or position.x > game.WORLD_SIZE.x - 40.0 or position.y < 120.0 or position.y > game.WORLD_SIZE.y - 80.0:
		return "boundary"
	for building_id in game.BuildingSystem.buildings_at(game.current_location):
		for solid in game.BuildingSystem.collision_rects(building_id):
			if circle_intersects_rect(position,game.PLAYER_RADIUS,solid): return "building"
		if not game.BuildingSystem.can_enter(game,building_id) and circle_intersects_rect(position,game.PLAYER_RADIUS,game.BuildingSystem.door_rect(building_id)): return "building"
	if game.EnvironmentVisualSystem.blocks_biome_position(game.current_location, position, game.PLAYER_RADIUS):
		return "biome_prop"
	if game.EnvironmentVisualSystem.blocks_event_position(game.current_location, position, game.PLAYER_RADIUS):
		return "event_prop"
	if game.FenceSystem.blocks_position(game,position,game.PLAYER_RADIUS): return "player_fence"
	if game.current_location in ["cave", "cursed"]:
		for decoration in game.CAVE_DECORATIONS:
			if circle_intersects_rect(position,game.PLAYER_RADIUS,game.CaveVisualSystem.collision_rect(decoration)):
				return "cave_prop"
	elif game.current_location == "overworld":
		if game.VillageEventSystem.blocks_position(game, position, game.PLAYER_RADIUS): return "village_event"
		if VillageLayoutSystem.is_water(position, game.PLAYER_RADIUS):
			return "water"
		if VillageLayoutSystem.blocks_scenic_prop(position, game.PLAYER_RADIUS):
			return "scenic_prop"
		for tree in game.state.world.tree_nodes:
			if game.TreeSystem.is_solid(tree) and circle_intersects_rect(position,game.PLAYER_RADIUS,game.TreeSystem.collision_rect(tree)):
				return "tree"
		for fence_rect in game.BuildingSystem.farm_fence_rects():
			if circle_intersects_rect(position, game.PLAYER_RADIUS, fence_rect):
				return "fence"
		var solid_rects := [
			game.BuildingSystem.SELL_CRATE_RECT, Rect2(game.workbench_position - Vector2(32, 20), Vector2(64, 44))
		]
		for rect in solid_rects:
			if circle_intersects_rect(position, game.PLAYER_RADIUS, rect):
				return "world_prop"
		if game.slime_alive and position.distance_to(game.slime_position) < game.PLAYER_RADIUS + 28.0:
			return "enemy"
	for enemy in game.enemy_nodes:
		if enemy.alive and enemy.location == game.current_location and position.distance_to(enemy.position) < game.PLAYER_RADIUS + 30.0:
			return "enemy"
	for hazard in game.hazard_nodes:
		if hazard.location == game.current_location and position.distance_to(hazard.position) < game.PLAYER_RADIUS + 30.0:
			return "hazard"
	for node in game.resource_nodes:
		if node.hits > 0 and node.location == game.current_location and circle_intersects_rect(position,game.PLAYER_RADIUS,game.ResourceSystem.collision_rect(node)):
			return "resource"
	for container in game.world_loot_nodes:
		if container.location==game.current_location and circle_intersects_rect(position,game.PLAYER_RADIUS,game.WorldLootRenderer.collision_rect(container.kind,container.position)):
			return "loot"
	for food in game.food_nodes:
		if food.get("location", "overworld") != game.current_location:
			continue
		var collision:Rect2=game.OrchardSystem.collision_rect(food.position,game.OrchardSystem.stage(food)) if game.OrchardSystem.handles(food.kind) else game.ForageSystem.collision_rect(food)
		if circle_intersects_rect(position,game.PLAYER_RADIUS,collision):
			return "forage"
	return "walkable"

## Выполняет изолированную операцию своей подсистемы и возвращает результат согласно контракту.
static func circle_intersects_rect(center: Vector2, radius: float, rect: Rect2) -> bool:
	var closest := Vector2(clampf(center.x, rect.position.x, rect.end.x), clampf(center.y, rect.position.y, rect.end.y))
	return center.distance_squared_to(closest) < radius * radius


## Перемещает мобильного врага по двум осям, позволяя скользить вдоль препятствий.
static func move_enemy(game: Node, enemy_index: int, motion: Vector2) -> Vector2:
	if enemy_index < 0 or enemy_index >= game.enemy_nodes.size():
		return Vector2.ZERO
	var position: Vector2 = game.enemy_nodes[enemy_index].position
	var horizontal := position + Vector2(motion.x, 0.0)
	if enemy_position_walkable(game, horizontal, enemy_index):
		position = horizontal
	var vertical := position + Vector2(0.0, motion.y)
	if enemy_position_walkable(game, vertical, enemy_index):
		position = vertical
	return position


## Проверяет путь врага без ложного столкновения с ним самим.
static func enemy_position_walkable(game: Node, position: Vector2, enemy_index: int) -> bool:
	const RADIUS := 27.0
	if game.current_location == "pirate_ship" and not PirateShipSystem.is_walkable(position, RADIUS): return false
	if position.x < 40.0 or position.x > game.WORLD_SIZE.x - 40.0 or position.y < 120.0 or position.y > game.WORLD_SIZE.y - 80.0:
		return false
	for building_id in game.BuildingSystem.buildings_at(game.current_location):
		if circle_intersects_rect(position,RADIUS,game.BuildingSystem.collision_rect(building_id)):
			return false
	if game.EnvironmentVisualSystem.blocks_biome_position(game.current_location, position, RADIUS):
		return false
	if game.current_location == "overworld":
		if VillageLayoutSystem.is_water(position, RADIUS):
			return false
		if VillageLayoutSystem.blocks_scenic_prop(position, RADIUS):
			return false
		for tree in game.state.world.tree_nodes:
			if game.TreeSystem.is_solid(tree) and circle_intersects_rect(position,RADIUS,game.TreeSystem.collision_rect(tree)): return false
	for index in game.enemy_nodes.size():
		if index == enemy_index:
			continue
		var other: Dictionary = game.enemy_nodes[index]
		if other.alive and other.location == game.current_location and position.distance_to(other.position) < RADIUS * 2.0:
			return false
	for hazard in game.hazard_nodes:
		if hazard.location == game.current_location and position.distance_to(hazard.position) < RADIUS + 30.0:
			return false
	for node in game.resource_nodes:
		if node.hits > 0 and node.location == game.current_location and circle_intersects_rect(position,RADIUS,game.ResourceSystem.collision_rect(node)):
			return false
	return true
