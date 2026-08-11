extends RefCounted

const MAX_HEALTH := 3
const CHOP_RANGE := 104.0
const REGROW_DURATION := 30.0
const GROWTH_STAGE_DURATION := REGROW_DURATION / 3.0
const POSITIONS := [Vector2(1740,260),Vector2(1900,235),Vector2(2160,250),Vector2(1860,470),Vector2(1940,820),Vector2(2110,900),Vector2(2280,790),Vector2(2180,520)]


## Создаёт независимые состояния взрослых деревьев из единого списка лесных позиций.
static func default_nodes() -> Array:
	var result: Array = []
	for index in POSITIONS.size():
		result.append({"id":"tree_%d" % index,"position":POSITIONS[index],"health":MAX_HEALTH,"stage":3,"regrow_timer":REGROW_DURATION,"hit_flash":0.0})
	return result


## Обновляет вспышку удара и три видимые стадии восстановления каждого срубленного дерева.
static func update(game: Node, delta: float) -> void:
	for index in game.state.world.tree_nodes.size():
		var tree: Dictionary = game.state.world.tree_nodes[index]
		tree.hit_flash = maxf(float(tree.get("hit_flash", 0.0)) - delta, 0.0)
		if int(tree.stage) < 3:
			var previous_stage: int = tree.stage
			tree.regrow_timer = minf(float(tree.regrow_timer) + delta, REGROW_DURATION)
			var next_stage := mini(3, floori(float(tree.regrow_timer) / GROWTH_STAGE_DURATION))
			if next_stage >= 2 and game.current_location == "overworld" and game.player.distance_to(tree.position + Vector2(0, 35)) < game.PLAYER_RADIUS + 42.0:
				next_stage = 1; tree.regrow_timer = minf(float(tree.regrow_timer), GROWTH_STAGE_DURATION * 2.0 - 0.01)
			tree.stage = next_stage
			if int(tree.stage) >= 3:
				tree.health = MAX_HEALTH
				game.notify_tutorial("tree_regrow")
			elif int(tree.stage) > previous_stage:
				tree.hit_flash = 0.28
		game.state.world.tree_nodes[index] = tree


## Находит ближайшее взрослое дерево в радиусе удара или сообщает об отсутствии цели.
static func nearest_grown_tree(game: Node) -> int:
	if game.current_location != "overworld": return -1
	var nearest := -1
	var nearest_distance := CHOP_RANGE
	for index in game.state.world.tree_nodes.size():
		var tree: Dictionary = game.state.world.tree_nodes[index]
		var distance: float = game.player.distance_to(tree.position + Vector2(0, 28))
		if int(tree.stage) == 3 and distance < nearest_distance:
			nearest = index; nearest_distance = distance
	return nearest


## Рубит ближайшее дерево топором, расходует силы, выдаёт древесину и запускает восстановление пня.
static func chop_nearby(game: Node) -> bool:
	if game.inventory_item_count("axe") <= 0 or game.selected_tool != game.Tool.AXE:
		game.message = game.LocaleSystem.text("need_axe")
		return false
	if not game.AdventurePolishSystem.can_use(game, "axe"): return false
	if game.energy <= 0:
		game.message = game.LocaleSystem.text("no_energy")
		return false
	var index := nearest_grown_tree(game)
	if index < 0:
		game.message = game.LocaleSystem.text("no_tree")
		return false
	var tree: Dictionary = game.state.world.tree_nodes[index]
	tree.health -= 1; tree.hit_flash = 0.22; game.energy -= 1
	game.change_inventory_count("wood", 1); game.award_xp(1); game.play_sfx("chop"); game.notify_tutorial("tree_chop")
	game.AdventurePolishSystem.consume_durability(game, "axe")
	if int(tree.health) <= 0:
		tree.health = 0; tree.stage = 0; tree.regrow_timer = 0.0
		game.message = game.LocaleSystem.text("tree_felled", [REGROW_DURATION])
		game.notify_tutorial("tree_fall")
	else:
		game.message = game.LocaleSystem.text("tree_hit", [tree.health, MAX_HEALTH])
	game.state.world.tree_nodes[index] = tree
	return true


## Проверяет, должна ли текущая стадия дерева блокировать движение героя и существ.
static func is_solid(tree: Dictionary) -> bool:
	return int(tree.get("stage", 3)) >= 2


## Возвращает долю завершённого восстановления для полосы над пнём или саженцем.
static func regrow_progress(tree: Dictionary) -> float:
	return clampf(float(tree.get("regrow_timer", REGROW_DURATION)) / REGROW_DURATION, 0.0, 1.0)
