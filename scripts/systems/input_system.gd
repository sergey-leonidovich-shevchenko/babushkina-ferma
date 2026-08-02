extends RefCounted

## Единственная точка регистрации gameplay-действий. UI может переназначить
## InputMap без изменений в бою, ферме или инвентаре.
const ACTION_BINDINGS := {
	"move_left": [KEY_A, KEY_LEFT],
	"move_right": [KEY_D, KEY_RIGHT],
	"move_up": [KEY_W, KEY_UP],
	"move_down": [KEY_S, KEY_DOWN],
	"use_item": [KEY_E, KEY_SPACE],
	"attack": [KEY_F],
	"inventory": [KEY_TAB, KEY_I],
	"quests": [KEY_J],
	"skills": [KEY_K],
	"save_game": [KEY_F5],
	"load_game": [KEY_F8],
}


static func ensure_default_actions() -> void:
	for action in ACTION_BINDINGS:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		if not InputMap.action_get_events(action).is_empty():
			continue
		for keycode in ACTION_BINDINGS[action]:
			var event := InputEventKey.new()
			event.physical_keycode = keycode
			InputMap.action_add_event(action, event)


static func set_action_key_state(game: Node, event: InputEventKey) -> bool:
	if event.keycode != KEY_E and event.keycode != KEY_SPACE:
		return false
	game.action_held = event.pressed
	if event.pressed and not event.echo:
		game.action_repeat_timer = game.ACTION_REPEAT_INTERVAL
	return true


static func set_attack_key_state(game: Node, event: InputEventKey) -> bool:
	if event.keycode != KEY_F:
		return false
	game.attack_held = event.pressed
	if event.pressed and not event.echo:
		game.attack_repeat_timer = game.ATTACK_REPEAT_INTERVAL
	return true


static func update_held_action(game: Node, delta: float) -> void:
	if not game.action_held or game.title_screen or game.shop_open or game.inventory_open:
		return
	game.action_repeat_timer -= delta
	if game.action_repeat_timer > 0.0:
		return
	game.action_repeat_timer = game.ACTION_REPEAT_INTERVAL
	perform_repeatable_action(game)


static func update_held_attack(game: Node, delta: float) -> void:
	if not game.attack_held or game.title_screen or game.shop_open or game.inventory_open:
		return
	game.attack_repeat_timer -= delta
	if game.attack_repeat_timer <= 0.0:
		game.attack_repeat_timer = game.ATTACK_REPEAT_INTERVAL
		game.attack_nearest_enemy()


static func perform_repeatable_action(game: Node) -> bool:
	var interaction: String = game.nearest_interaction()
	if interaction.begins_with("resource:"):
		return game.mine_resource(int(interaction.get_slice(":", 1)))
	if interaction.begins_with("drop:"):
		return game.collect_dropped_item(int(interaction.get_slice(":", 1)))
	if interaction.begins_with("food:"):
		return game.collect_food(int(interaction.get_slice(":", 1)))
	if game.current_location != "overworld":
		return false
	var held_kind: String = game.hotbar_slots[game.selected_hotbar]
	if not game.InventorySystem.data(held_kind).has("tool"):
		return false
	game.use_selected_tool()
	game.notify_tutorial("hold_action")
	return true


static func apply_immediate_key_response(game: Node, event: InputEventKey) -> void:
	if event.echo:
		return
	var direction := Vector2.ZERO
	match event.keycode:
		KEY_LEFT: direction = Vector2.LEFT
		KEY_RIGHT: direction = Vector2.RIGHT
		KEY_UP: direction = Vector2.UP
		KEY_DOWN: direction = Vector2.DOWN
	match event.physical_keycode:
		KEY_A: direction = Vector2.LEFT
		KEY_D: direction = Vector2.RIGHT
		KEY_W: direction = Vector2.UP
		KEY_S: direction = Vector2.DOWN
	if direction != Vector2.ZERO:
		game.facing = direction

