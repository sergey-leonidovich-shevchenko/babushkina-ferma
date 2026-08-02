extends RefCounted

## Чистые расчёты представления. Они не рисуют и не меняют игровое состояние,
## Выполняет изолированную операцию своей подсистемы и возвращает результат согласно контракту.

static func forage_sprite_layout(forage_sprites: Dictionary, kind: String, position: Vector2) -> Dictionary:
	var sprite: Dictionary = forage_sprites.get(kind, {})
	if sprite.is_empty():
		return {}
	return {
		"source": sprite.source,
		"destination": Rect2(position - Vector2(sprite.anchor), Vector2(sprite.size)),
	}


## Выполняет операцию «анимации кадра» и возвращает результат согласно контракту метода.
static func animation_frame(elapsed_ms: int, frame_count: int, frame_ms: int = 140) -> int:
	if frame_count <= 0 or frame_ms <= 0:
		return 0
	return int(elapsed_ms / frame_ms) % frame_count


## Рассчитывает несинхронное дыхание в покое и пружинящий шаг при движении.
static func living_motion(time: float, moving: bool, phase_offset: float = 0.0) -> Dictionary:
	var speed := 8.5 if moving else 2.3
	var phase := time * speed + phase_offset
	if moving:
		return {
			"offset": Vector2(sin(phase * 0.5) * 1.2, -absf(sin(phase)) * 3.5),
			"scale": Vector2(1.0 + cos(phase) * 0.018, 1.0 - cos(phase) * 0.025),
			"rotation": sin(phase * 0.5) * 0.035,
		}
	return {
		"offset": Vector2(sin(phase * 0.5) * 0.45, sin(phase) * 0.8),
		"scale": Vector2(1.0 - sin(phase) * 0.006, 1.0 + sin(phase) * 0.012),
		"rotation": sin(phase * 0.5) * 0.009,
	}


## Выполняет изолированную операцию своей подсистемы и возвращает результат согласно контракту.
static func enemy_direction_row(direction: Vector2) -> int:
	if absf(direction.x) > absf(direction.y):
		return 2 if direction.x < 0.0 else 3
	return 1 if direction.y < 0.0 else 0


## Выполняет изолированную операцию своей подсистемы и возвращает результат согласно контракту.
static func interaction_position(game: Node, interaction: String) -> Vector2:
	if interaction.begins_with("building:") or interaction.begins_with("interior_"):
		return game.BuildingSystem.interaction_position(game, interaction)
	if interaction.begins_with("prisoner:"):
		return game.CompanionSystem.interaction_position(interaction)
	if interaction.begins_with("quest_npc:"):
		return game.QuestSystem.npc_position(game, interaction.get_slice(":", 1))
	if interaction == "home_chest":
		return game.StorageSystem.CHEST_POSITION
	for prefix in ["drop", "container", "resource", "food"]:
		if not interaction.begins_with(prefix + ":"):
			continue
		var collection: Array = {
			"drop": game.dropped_items,
			"container": game.world_loot_nodes,
			"resource": game.resource_nodes,
			"food": game.food_nodes,
		}[prefix]
		var index := int(interaction.get_slice(":", 1))
		return collection[index].position if index >= 0 and index < collection.size() else Vector2.ZERO
	return {
		"npc": game.npc_position,
		"shop": game.BuildingSystem.SHOP_STALL_POSITION,
		"crate": game.BuildingSystem.SELL_CRATE_POSITION,
		"workbench": game.workbench_position,
		"loot": game.slime_position,
		"cave_entrance": game.cave_entrance_position,
		"cave_exit": game.cave_exit_position,
		"world_gate": game.world_gate_position,
	}.get(interaction, Vector2.ZERO)


## Выполняет изолированную операцию своей подсистемы и возвращает результат согласно контракту.
static func discovery_card_rect() -> Rect2:
	return Rect2(824, 354, 310, 108)


## Собирает не более трёх активных целей и одну сводную строку для компактного HUD.
static func quest_tracker_lines(game: Node) -> Array[String]:
	var lines: Array[String] = []
	if game.quest_active:
		lines.append("Бабушкина морковь: %d/10" % mini(game.carrots, 10))
	for mission_id in game.QuestSystem.MISSIONS:
		if game.mission_states.get(mission_id) == game.QuestSystem.ACTIVE:
			lines.append("%s — %s" % [game.QuestSystem.mission_data(mission_id).title, game.QuestSystem.objective_text(game, mission_id)])
	if lines.size() > 3:
		var hidden_count := lines.size() - 3
		lines.resize(3); lines.append(game.LocaleSystem.ui("more_quests", [hidden_count]))
	return lines
