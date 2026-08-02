extends RefCounted

static func movement_direction(game: Node) -> Vector2:
	return Vector2(
		float(game.move_right_held) - float(game.move_left_held),
		float(game.move_down_held) - float(game.move_up_held)
	).normalized()

static func update_movement_key(game: Node, event: InputEventKey) -> bool:
	var held := event.pressed
	if event.keycode == KEY_LEFT or event.physical_keycode == KEY_A: game.move_left_held = held
	elif event.keycode == KEY_RIGHT or event.physical_keycode == KEY_D: game.move_right_held = held
	elif event.keycode == KEY_UP or event.physical_keycode == KEY_W: game.move_up_held = held
	elif event.keycode == KEY_DOWN or event.physical_keycode == KEY_S: game.move_down_held = held
	else: return false
	return true

static func clear_keys(game: Node) -> void:
	game.move_left_held = false
	game.move_right_held = false
	game.move_up_held = false
	game.move_down_held = false
	game.action_held = false
	game.attack_held = false

static func heal(game: Node, amount: int) -> int:
	var previous_hp: int = game.player_hp
	game.player_hp = mini(game.player_hp + amount, game.player_max_hp)
	return game.player_hp - previous_hp

static func award_xp(game: Node, amount: int, reason: String = "") -> void:
	game.player_xp += amount
	var leveled_up := false
	while game.player_xp >= game.XP_PER_LEVEL:
		game.player_xp -= game.XP_PER_LEVEL
		game.player_level += 1
		game.player_max_hp += 10
		game.player_hp = game.player_max_hp
		leveled_up = true
	if leveled_up:
		game.message = "Новый уровень %d! Максимум здоровья +10" % game.player_level
		game.notify_tutorial("level_up")
	elif not reason.is_empty(): game.message = "%s: +%d опыта" % [reason, amount]

static func update_effects(game: Node, delta: float) -> void:
	game.strength_timer = maxf(game.strength_timer - delta, 0.0)
	game.speed_timer = maxf(game.speed_timer - delta, 0.0)
	if game.regeneration_timer <= 0.0: return
	game.regeneration_timer = maxf(game.regeneration_timer - delta, 0.0)
	game.regeneration_tick_timer += delta
	while game.regeneration_tick_timer >= 1.0:
		game.regeneration_tick_timer -= 1.0
		heal(game, 5)
