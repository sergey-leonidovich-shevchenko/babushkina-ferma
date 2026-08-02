extends RefCounted

const PLAYER_ATTACK_DURATION := 0.48
const HURT_DURATION := 0.32
const ENEMY_ATTACK_DURATION := 0.55
const DEATH_DURATION := 0.88


## Выполняет изолированную операцию своей подсистемы и возвращает результат согласно контракту.
static func initialize_enemy(enemy: Dictionary) -> Dictionary:
	if not enemy.has("visual_state"):
		enemy.visual_state = "idle"
	if not enemy.has("visual_time"):
		enemy.visual_time = 0.0
	return enemy


## Выполняет изолированную операцию своей подсистемы и возвращает результат согласно контракту.
static func update(game: Node, delta: float) -> void:
	game.player_attack_timer = maxf(game.player_attack_timer - delta, 0.0)
	game.slime_visual_time += delta
	if game.slime_visual_state == "hurt" and game.slime_visual_time >= HURT_DURATION:
		game.slime_visual_state = "idle"
		game.slime_visual_time = 0.0
	elif game.slime_visual_state == "attack" and game.slime_visual_time >= ENEMY_ATTACK_DURATION:
		game.slime_visual_state = "idle"
		game.slime_visual_time = 0.0
	for index in game.enemy_nodes.size():
		var enemy: Dictionary = initialize_enemy(game.enemy_nodes[index])
		enemy.visual_time += delta
		if enemy.visual_state == "hurt" and enemy.visual_time >= HURT_DURATION:
			enemy.visual_state = "idle"
			enemy.visual_time = 0.0
		elif enemy.visual_state == "attack" and enemy.visual_time >= ENEMY_ATTACK_DURATION:
			enemy.visual_state = "idle"
			enemy.visual_time = 0.0
		game.enemy_nodes[index] = enemy


## Выполняет изолированную операцию своей подсистемы и возвращает результат согласно контракту.
static func begin_player_attack(game: Node) -> void:
	game.player_attack_timer = PLAYER_ATTACK_DURATION


## Выполняет изолированную операцию своей подсистемы и возвращает результат согласно контракту.
static func hit_enemy(enemy: Dictionary, defeated: bool) -> Dictionary:
	enemy.visual_state = "death" if defeated else "hurt"
	enemy.visual_time = 0.0
	return enemy


## Выполняет изолированную операцию своей подсистемы и возвращает результат согласно контракту.
static func hit_slime(game: Node, defeated: bool) -> void:
	game.slime_visual_state = "death" if defeated else "hurt"
	game.slime_visual_time = 0.0


## Выполняет изолированную операцию своей подсистемы и возвращает результат согласно контракту.
static func begin_slime_attack(game: Node) -> void:
	game.slime_visual_state = "attack"
	game.slime_visual_time = 0.0


## Выполняет изолированную операцию своей подсистемы и возвращает результат согласно контракту.
static func enemy_is_visible(enemy: Dictionary) -> bool:
	return enemy.alive or (enemy.get("visual_state", "idle") == "death" and enemy.get("visual_time", 0.0) < DEATH_DURATION)


## Выполняет изолированную операцию своей подсистемы и возвращает результат согласно контракту.
static func slime_is_visible(game: Node) -> bool:
	return game.slime_alive or (game.slime_visual_state == "death" and game.slime_visual_time < DEATH_DURATION)


## Выполняет операцию «кадра» и возвращает результат согласно контракту метода.
static func frame(time: float, frame_count: int, fps: float, looped: bool = true) -> int:
	if frame_count <= 1:
		return 0
	var value := int(maxf(time, 0.0) * fps)
	return value % frame_count if looped else mini(value, frame_count - 1)
