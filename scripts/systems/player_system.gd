extends RefCounted

const WALK_FRAME_COUNT := 6
const WALK_FPS := 10.0

## Выполняет изолированную операцию своей подсистемы и возвращает результат согласно контракту.
static func movement_direction(game: Node) -> Vector2:
	if game.state.fishing.phase in [game.FishingSystem.PHASE_CHARGING, game.FishingSystem.PHASE_WAITING, game.FishingSystem.PHASE_BITE, game.FishingSystem.PHASE_MINIGAME]: return Vector2.ZERO
	return Vector2(
		float(game.move_right_held) - float(game.move_left_held),
		float(game.move_down_held) - float(game.move_up_held)
	).normalized()

## Обновляет относящуюся к методу часть состояния на текущем кадре.
static func update_movement_key(game: Node, event: InputEventKey) -> bool:
	var held := event.pressed
	if game.InputSystem.matches(event,"move_left"): game.move_left_held = held
	elif game.InputSystem.matches(event,"move_right"): game.move_right_held = held
	elif game.InputSystem.matches(event,"move_up"): game.move_up_held = held
	elif game.InputSystem.matches(event,"move_down"): game.move_down_held = held
	else: return false
	return true

## Выполняет изолированную операцию своей подсистемы и возвращает результат согласно контракту.
static func clear_keys(game: Node) -> void:
	game.move_left_held = false
	game.move_right_held = false
	game.move_up_held = false
	game.move_down_held = false
	game.action_held = false
	game.attack_held = false

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
