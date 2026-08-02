extends RefCounted

## Чистые расчёты представления. Они не рисуют и не меняют игровое состояние,
## поэтому renderer и тесты используют один контракт.

static func forage_sprite_layout(forage_sprites: Dictionary, kind: String, position: Vector2) -> Dictionary:
	var sprite: Dictionary = forage_sprites.get(kind, {})
	if sprite.is_empty():
		return {}
	return {
		"source": sprite.source,
		"destination": Rect2(position - Vector2(sprite.anchor), Vector2(sprite.size)),
	}


static func animation_frame(elapsed_ms: int, frame_count: int, frame_ms: int = 140) -> int:
	if frame_count <= 0 or frame_ms <= 0:
		return 0
	return int(elapsed_ms / frame_ms) % frame_count


static func enemy_direction_row(direction: Vector2) -> int:
	if absf(direction.x) > absf(direction.y):
		return 2 if direction.x < 0.0 else 3
	return 1 if direction.y < 0.0 else 0


static func interaction_position(game: Node, interaction: String) -> Vector2:
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
		"guild_master": game.guild_master_position,
		"herbalist": game.herbalist_position,
		"shop": Vector2(972, 278),
		"crate": Vector2(820, 420),
		"workbench": game.workbench_position,
		"loot": game.slime_position,
		"cave_entrance": game.cave_entrance_position,
		"cave_exit": game.cave_exit_position,
		"world_gate": game.world_gate_position,
	}.get(interaction, Vector2.ZERO)


static func discovery_card_rect() -> Rect2:
	return Rect2(824, 354, 310, 108)

