extends RefCounted

const WALK_FRAME_COUNT := 6
const WALK_FPS := 10.0
const HELD_KEYS_META := &"player_movement_keys"
const VISUAL_MOTION_META := &"player_visual_motion"
const WALK_TIME_META := &"player_walk_time"

## Выполняет изолированную операцию своей подсистемы и возвращает результат согласно контракту.
static func movement_direction(game: Node) -> Vector2:
	if game.state.fishing.phase in [game.FishingSystem.PHASE_CHARGING, game.FishingSystem.PHASE_WAITING, game.FishingSystem.PHASE_BITE, game.FishingSystem.PHASE_MINIGAME]: return Vector2.ZERO
	return Vector2(
		float(game.move_right_held) - float(game.move_left_held),
		float(game.move_down_held) - float(game.move_up_held)
	).normalized()

## Учитывает каждую физическую клавишу, чтобы отпускание D не останавливало удерживаемую стрелку вправо.
static func update_movement_key(game: Node, event: InputEventKey) -> bool:
	for action in ["move_left", "move_right", "move_up", "move_down"]:
		if not game.InputSystem.matches(event, action):
			continue
		var pressed_keys: Dictionary = game.get_meta(HELD_KEYS_META, {})
		var action_keys: Dictionary = pressed_keys.get(action, {})
		var physical_key := event.physical_keycode if event.physical_keycode != 0 else event.keycode
		if event.pressed:
			action_keys[physical_key] = true
		else:
			action_keys.erase(physical_key)
		pressed_keys[action] = action_keys
		game.set_meta(HELD_KEYS_META, pressed_keys)
		game.set(action + "_held", not action_keys.is_empty())
		return true
	return false

## Выполняет изолированную операцию своей подсистемы и возвращает результат согласно контракту.
static func clear_keys(game: Node) -> void:
	preload("res://scripts/systems/action_lifecycle_system.gd").release_holds(game)
	game.move_left_held = false
	game.move_right_held = false
	game.move_up_held = false
	game.move_down_held = false
	game.action_held = false
	game.attack_held = false
	game.set_meta(HELD_KEYS_META, {})
	record_motion(game, Vector2.ZERO)


## Запоминает фактический шаг после коллизий и привязывает цикл ног к пройденному расстоянию.
static func record_motion(game: Node, motion: Vector2) -> void:
	game.set_meta(VISUAL_MOTION_META, motion)
	if motion.is_zero_approx():
		game.set_meta(WALK_TIME_META, 0.0)
		return
	var walk_time: float = float(game.get_meta(WALK_TIME_META, 0.0))
	game.set_meta(WALK_TIME_META, walk_time + motion.length() / maxf(float(game.speed), 1.0))


## Не проигрывает ходьбу у стены, при отпускании клавиш или поверх открытого игрового окна.
static func is_visually_moving(game: Node) -> bool:
	if game.language_screen or game.GameLoop.modal_active(game) or game.GameLoop.gameplay_window_open(game) or game.LevelEditorSystem.active(game):
		return false
	return movement_direction(game) != Vector2.ZERO and not Vector2(game.get_meta(VISUAL_MOTION_META, Vector2.ZERO)).is_zero_approx()


## Возвращает часы реального шага для ходьбы и непрерывные часы дыхания для покоя.
static func visual_animation_time(game: Node, moving: bool) -> float:
	return float(game.get_meta(WALK_TIME_META, 0.0)) if moving else game.walk_animation_time

## Обновляет анимации на текущем кадре.
static func update_animation(game: Node, delta: float) -> void:
	game.walk_animation_time += delta

## Выполняет изолированную операцию своей подсистемы и возвращает результат согласно контракту.
static func direction_row(direction: Vector2) -> int:
	if absf(direction.x) > absf(direction.y):
		return 1 if direction.x < 0.0 else 2
	return 3 if direction.y < 0.0 else 0

## Выполняет операцию «анимации кадра» и возвращает результат согласно контракту метода.
static func animation_frame(animation_time: float, moving: bool) -> int:
	if not moving:
		return 0
	return int(animation_time * WALK_FPS) % WALK_FRAME_COUNT

## Выполняет изолированную операцию своей подсистемы и возвращает результат согласно контракту.
static func sprite_bob(animation_time: float, moving: bool) -> float:
	if moving:
		return -1.5 if animation_frame(animation_time, true) in [1, 4] else 0.0
	return sin(animation_time * 2.4) * 0.65

## Выполняет изолированную операцию своей подсистемы и возвращает результат согласно контракту.
static func heal(game: Node, amount: int) -> int:
	var previous_hp: int = game.player_hp
	game.player_hp = mini(game.player_hp + amount, game.player_max_hp)
	return game.player_hp - previous_hp

## Выполняет изолированную операцию своей подсистемы и возвращает результат согласно контракту.
static func award_xp(game: Node, amount: int, reason: String = "") -> void:
	game.SkillSystem.award_character_xp(game, amount, reason)

## Обновляет эффектов на текущем кадре.
static func update_effects(game: Node, delta: float) -> void:
	game.PotionSystem.update_effects(game, delta)
