extends RefCounted

const PirateShipSystem := preload("res://scripts/systems/pirate_ship_system.gd")
const VillageLayoutSystem := preload("res://scripts/systems/village_layout_system.gd")
const Broadphase := preload("res://scripts/systems/navigation_broadphase_system.gd")
const CornerAssist := preload("res://scripts/systems/player_corner_assist_system.gd")
const CaveLayout := preload("res://scripts/systems/cave_layout_system.gd")

## Перемещает героя безопасными подшагами; необязательная помощь краю разрешена только для ручной ходьбы.
static func move(game: Node, motion: Vector2, corner_assist: bool = false) -> bool:
	if game.DebugOverlaySystem.noclip(game):
		game.player += motion
		return false
	var step_count := maxi(1, ceili(motion.length() / 8.0))
	var step := motion / float(step_count)
	var was_blocked := false
	var assisted := false
	for _index in step_count:
		var before: Vector2 = game.player
		var horizontal: Vector2 = game.player + Vector2(step.x, 0.0)
		if not is_zero_approx(step.x) and player_step_walkable(game, horizontal):
			game.player = horizontal
		elif not is_zero_approx(step.x):
			was_blocked = true
		var vertical: Vector2 = game.player + Vector2(0.0, step.y)
		if not is_zero_approx(step.y) and player_step_walkable(game, vertical):
			game.player = vertical
		elif not is_zero_approx(step.y):
			was_blocked = true
		if corner_assist and game.player.is_equal_approx(before):
			var correction := CornerAssist.resolve(game, step)
			if not correction.is_zero_approx():
				game.player += correction
				assisted = true
	if was_blocked:
		game.notify_tutorial("collision")
	return assisted

## Проверяет заявленное методом условие без изменения игрового состояния.
static func is_walkable(game: Node, position: Vector2) -> bool:
	return walkability_reason(game, position) == "walkable"


## Объясняет результат навигации кодом конкретного препятствия для игровой диагностики.
## Reference-режим отключает только broadphase для сравнений, не меняя правила коллизий или состояние мира.
static func walkability_reason(game: Node, position: Vector2, ignored_enemy: int = -1, include_enemies: bool = true, use_broadphase: bool = true) -> String:
	if game.DebugPlaygroundSystem.active(game): return "walkable" if game.DebugPlaygroundSystem.is_walkable(game, position, game.PLAYER_RADIUS) else "debug_obstacle"
	if game.PublishedLevelSystem.blocks_position(game,position,game.PLAYER_RADIUS): return "published_collision"
	if game.MoonGladeSystem.blocks_position(game, position, game.PLAYER_RADIUS): return "guardian"
	if game.BuildingSystem.is_interior(game.current_location):
		if game.FarmLifeSystem.blocks_position(game,position,game.PLAYER_RADIUS): return "furniture"
		if game.current_location == "cottage_interior" and game.home_chest_owned and circle_intersects_rect(position,game.PLAYER_RADIUS,game.InteriorVisualSystem.collision_rect("home_chest",game.StorageSystem.CHEST_POSITION)):
			return "storage"
		return "walkable" if game.BuildingSystem.is_walkable_inside(game.current_location, position, game.PLAYER_RADIUS) else "interior"
	if game.current_location == "pirate_ship" and not PirateShipSystem.is_walkable(position, game.PLAYER_RADIUS): return "ship"
	var bounds: Vector2 = game.WorldBoundsSystem.size(game.current_location)
	if position.x < 40.0 or position.x > bounds.x - 40.0 or position.y < 120.0 or position.y > bounds.y - 80.0:
		return "boundary"
	if CaveLayout.Rooms.is_cave(game.current_location):
		if CaveLayout.blocks_position(position,game.PLAYER_RADIUS,game.current_location): return "cave_wall"
		if CaveLayout.blocks_water(position,game.PLAYER_RADIUS,game.current_location): return "cave_water"
		if CaveLayout.blocks_decoration(position,game.PLAYER_RADIUS,game.current_location): return "cave_prop"
		if preload("res://scripts/systems/cave_boss_arena_system.gd").blocks_seal(game,position,game.PLAYER_RADIUS): return "cave_seal"
	if use_broadphase:
		if Broadphase.blocks(game, "building", position, game.PLAYER_RADIUS): return "building"
	else:
		for building_id in game.BuildingSystem.buildings_at(game.current_location):
			for solid in game.BuildingSystem.collision_rects(building_id):
				if circle_intersects_rect(position,game.PLAYER_RADIUS,solid): return "building"
			if not game.BuildingSystem.can_enter(game,building_id) and circle_intersects_rect(position,game.PLAYER_RADIUS,game.BuildingSystem.door_rect(building_id)): return "building"
	if game.EnvironmentVisualSystem.blocks_biome_position(game.current_location, position, game.PLAYER_RADIUS):
		return "biome_prop"
	if game.EnvironmentVisualSystem.blocks_event_position(game.current_location, position, game.PLAYER_RADIUS):
		return "event_prop"
	if game.FenceSystem.blocks_position(game,position,game.PLAYER_RADIUS): return "player_fence"
	if game.current_location == "cursed":
		for decoration in game.CAVE_DECORATIONS:
			if circle_intersects_rect(position,game.PLAYER_RADIUS,game.CaveVisualSystem.collision_rect(decoration)):
				return "cave_prop"
	elif game.current_location == "overworld":
		if game.VillageEventSystem.blocks_position(game, position, game.PLAYER_RADIUS): return "village_event"
		if VillageLayoutSystem.is_water(position, game.PLAYER_RADIUS):
			return "water"
		if (Broadphase.blocks(game, "scenic", position, game.PLAYER_RADIUS) if use_broadphase else VillageLayoutSystem.blocks_scenic_prop(position, game.PLAYER_RADIUS)):
			return "scenic_prop"
		for tree in game.state.world.tree_nodes:
			if use_broadphase and not Broadphase.near_dynamic(position, tree.position, game.PLAYER_RADIUS): continue
			if game.TreeSystem.is_solid(tree) and circle_intersects_rect(position,game.PLAYER_RADIUS,game.TreeSystem.collision_rect(tree)):
				return "tree"
		if use_broadphase:
			if Broadphase.blocks(game, "farm_fence", position, game.PLAYER_RADIUS): return "fence"
		else:
			for fence_rect in game.BuildingSystem.farm_fence_rects():
				if circle_intersects_rect(position, game.PLAYER_RADIUS, fence_rect): return "fence"
		var solid_rects := [
			game.BuildingSystem.SELL_CRATE_RECT, Rect2(game.workbench_position - Vector2(32, 20), Vector2(64, 44))
		]
		for rect in solid_rects:
			if circle_intersects_rect(position, game.PLAYER_RADIUS, rect):
				return "world_prop"
		if include_enemies and game.slime_alive and position.distance_to(game.slime_position) < game.PLAYER_RADIUS + 28.0:
			return "enemy"
	for enemy_index in game.enemy_nodes.size():
		var enemy: Dictionary = game.enemy_nodes[enemy_index]
		if include_enemies and enemy_index != ignored_enemy and enemy.alive and enemy.location == game.current_location and position.distance_to(enemy.position) < game.PLAYER_RADIUS + 30.0:
			return "enemy"
	for hazard in game.hazard_nodes:
		if hazard.location == game.current_location and position.distance_to(hazard.position) < game.PLAYER_RADIUS + 30.0:
			return "hazard"
	for node in game.resource_nodes:
		if node.hits<=0 or node.location!=game.current_location: continue
		if use_broadphase and not Broadphase.near_dynamic(position, node.position, game.PLAYER_RADIUS): continue
		if circle_intersects_rect(position,game.PLAYER_RADIUS,game.ResourceSystem.collision_rect(node)):
			return "resource"
	for container in game.world_loot_nodes:
		if container.location != game.current_location or not preload("res://scripts/systems/cave_boss_arena_system.gd").container_visible(game,container): continue
		if use_broadphase and not Broadphase.near_dynamic(position, container.position, game.PLAYER_RADIUS): continue
		if circle_intersects_rect(position,game.PLAYER_RADIUS,game.WorldLootRenderer.container_collision(container)):
			return "loot"
	for food in game.food_nodes:
		if food.get("location", "overworld") != game.current_location:
			continue
		if game.ForageSystem.Herbs.is_herb(String(food.kind)): continue
		if use_broadphase and not Broadphase.near_dynamic(position, food.position, game.PLAYER_RADIUS): continue
		var collision:Rect2=game.OrchardSystem.collision_rect(food.position,game.OrchardSystem.stage(food)) if game.OrchardSystem.handles(food.kind) else game.ForageSystem.collision_rect(food)
		if circle_intersects_rect(position,game.PLAYER_RADIUS,collision):
			return "forage"
	if include_enemies and game.current_location == "cave_sanctum":
		for minion in game.state.world.cave_boss.minions:
			if minion.alive and float(minion.emerge) <= 0.0 and position.distance_to(minion.position) < game.PLAYER_RADIUS + 22.0: return "enemy"
	return "walkable"

## Проверяет физическое основание; пустой профиль декора не превращается в невидимую круглую стену.
static func circle_intersects_rect(center: Vector2, radius: float, rect: Rect2) -> bool:
	if not rect.has_area(): return false
	var closest := Vector2(clampf(center.x, rect.position.x, rect.end.x), clampf(center.y, rect.position.y, rect.end.y))
	return center.distance_squared_to(closest) < radius * radius


## Разрешает выход из уже возникшего пересечения врага, но не вход в него и не проход сквозь стены.
static func player_step_walkable(game: Node, position: Vector2) -> bool:
	if is_walkable(game, position): return true
	if walkability_reason(game, position, -1, false) != "walkable": return false
	var current_depth := enemy_penetration(game, game.player)
	return current_depth > 0.0 and enemy_penetration(game, position) < current_depth - 0.001


## Измеряет суммарную глубину наложения героя на живых врагов для монотонного выхода наружу.
static func enemy_penetration(game: Node, position: Vector2) -> float:
	var depth := 0.0
	if game.current_location == "overworld" and game.slime_alive:
		depth += maxf(0.0, game.PLAYER_RADIUS + 28.0 - position.distance_to(game.slime_position))
	for enemy in game.enemy_nodes:
		if enemy.alive and enemy.location == game.current_location:
			depth += maxf(0.0, game.PLAYER_RADIUS + 30.0 - position.distance_to(enemy.position))
	if game.current_location == "cave_sanctum":
		for minion in game.state.world.cave_boss.minions:
			if minion.alive and float(minion.emerge) <= 0.0: depth += maxf(0.0, game.PLAYER_RADIUS + 22.0 - position.distance_to(minion.position))
	return depth


## Перемещает мобильного врага по двум осям, позволяя скользить вдоль препятствий.
static func move_enemy(game: Node, enemy_index: int, motion: Vector2) -> Vector2:
	if enemy_index < 0 or enemy_index >= game.enemy_nodes.size():
		return Vector2.ZERO
	var position: Vector2 = game.enemy_nodes[enemy_index].position
	var steps := maxi(1, ceili(motion.length() / 6.0))
	var step := motion / float(steps)
	for _index in steps:
		var horizontal := position + Vector2(step.x, 0.0)
		if not is_zero_approx(step.x) and enemy_position_walkable(game, horizontal, enemy_index, position): position = horizontal
		var vertical := position + Vector2(0.0, step.y)
		if not is_zero_approx(step.y) and enemy_position_walkable(game, vertical, enemy_index, position): position = vertical
	return position


## Проверяет путь врага без ложного столкновения с ним самим.
static func enemy_position_walkable(game: Node, position: Vector2, enemy_index: int, previous: Vector2 = Vector2.INF) -> bool:
	const RADIUS := 27.0
	if CaveLayout.Rooms.is_cave(game.current_location) and (CaveLayout.blocks_position(position,RADIUS,game.current_location) or CaveLayout.blocks_water(position,RADIUS,game.current_location) or CaveLayout.blocks_decoration(position,RADIUS,game.current_location)): return false
	# Общая карта препятствий учитывает также заборы, сундуки, события и опубликованные уровни.
	if walkability_reason(game, position, enemy_index) != "walkable": return false
	var player_distance: float = position.distance_to(game.player)
	if player_distance < game.PLAYER_RADIUS + 30.0:
		if not previous.is_finite() or player_distance <= previous.distance_to(game.player) + 0.001: return false
	if game.current_location == "pirate_ship" and not PirateShipSystem.is_walkable(position, RADIUS): return false
	var bounds: Vector2 = game.WorldBoundsSystem.size(game.current_location)
	if position.x < 40.0 or position.x > bounds.x - 40.0 or position.y < 120.0 or position.y > bounds.y - 80.0:
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
