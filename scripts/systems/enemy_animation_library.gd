extends RefCounted

const CORE_WALK := preload("res://assets/game/enemies/animated/core_enemy_walk_8dir.png")
const CORE_ACTIONS := preload("res://assets/game/enemies/animated/core_enemy_actions_8dir.png")
const PIRATE_WALK := preload("res://assets/game/enemies/animated/pirate_enemy_walk_8dir.png")
const PIRATE_ACTIONS := preload("res://assets/game/enemies/animated/pirate_enemy_actions_8dir.png")
const AnimationAssetRegistry := preload("res://scripts/systems/animation_asset_registry.gd")
const CreatureVisualProfileSystem:=preload("res://scripts/systems/creature_visual_profile_system.gd")

const TILE_SIZE := Vector2(128, 128)
const WALK_FRAMES := 3
const WALK_FPS := 7.0
const ACTION_FRAMES := 3
const CORE_FAMILIES := ["orc", "skeleton", "undead", "cave_guardian"]
const PIRATE_FAMILIES := ["pirate", "zombie_pirate", "sea_ghost", "drowned_captain"]
const ACTION_KINDS := {
	"orc":"melee", "skeleton":"shoot", "undead":"cast", "cave_guardian":"slam",
	"pirate":"shoot", "zombie_pirate":"melee", "sea_ghost":"cast", "drowned_captain":"shoot",
}


## Возвращает разновидность боевой анимации семейства: удар, выстрел, заклинание или сокрушение.
static func action_kind(kind: String) -> String:
	return ACTION_KINDS.get(kind, "melee")


## Возвращает индекс семейства внутри одного из двух атласов.
static func family_index(kind: String) -> int:
	var families: Array = PIRATE_FAMILIES if kind in PIRATE_FAMILIES else CORE_FAMILIES
	return families.find(kind)


## Возвращает нужный атлас движения для обычного или пиратского противника.
static func walk_texture(kind: String) -> Texture2D:
	return PIRATE_WALK if kind in PIRATE_FAMILIES else CORE_WALK


## Возвращает нужный атлас боевых действий для обычного или пиратского противника.
static func action_texture(kind: String) -> Texture2D:
	return PIRATE_ACTIONS if kind in PIRATE_FAMILIES else CORE_ACTIONS


## Рассчитывает прямоугольник одного кадра по семейству, направлению и локальному кадру.
static func source_rect(kind: String, direction: Vector2, local_frame: int) -> Rect2:
	var column := family_index(kind) * WALK_FRAMES + clampi(local_frame, 0, WALK_FRAMES - 1)
	var row := AnimationAssetRegistry.direction_index(direction)
	return Rect2(Vector2(column * 128, row * 128), TILE_SIZE)


## Выбирает зацикленный кадр ходьбы или спокойную центральную стойку.
static func walk_frame(time: float, moving: bool) -> int:
	return int(time * WALK_FPS) % WALK_FRAMES if moving else 1


## Выбирает неповторяющийся кадр боевого действия по нормализованному прогрессу.
static func action_frame(progress: float) -> int:
	return mini(floori(clampf(progress, 0.0, 0.999) * ACTION_FRAMES), ACTION_FRAMES - 1)


## Подменяет отделившийся снаряд на последний кадр позы, чтобы тело врага не исчезало.
static func body_action_frame(kind: String, frame_index: int) -> int:
	if kind in ["skeleton", "undead"] and frame_index == 2: return 1
	if kind == "cave_guardian" and frame_index == 1: return 0
	return frame_index


## Возвращает исходный кадр отделившегося снаряда или магического эффекта.
static func effect_frame(kind: String) -> int:
	if kind in ["skeleton", "undead"]: return 2
	if kind == "cave_guardian": return 1
	return -1


## Готовит витрину восьми направленных врагов, где одновременно проверяются движение и разные типы атак.
static func configure_preview(game: Node) -> void:
	game.language_screen = false
	game.title_screen = false
	game.current_location = "overworld"
	game.player = Vector2(1150, 610)
	game.tutorial_visible = false
	game.message = ""
	var kinds: Array = CORE_FAMILIES + PIRATE_FAMILIES
	for index in game.enemy_nodes.size():
		var enemy: Dictionary = game.enemy_nodes[index]
		if index >= kinds.size():
			enemy.location = "preview_hidden"
			game.enemy_nodes[index] = enemy
			continue
		enemy.kind = kinds[index]
		enemy.location = "overworld"
		enemy.level = 1 + index % 5
		enemy.max_hp = game.CombatSystem.max_hp(enemy.kind, enemy.level)
		enemy.hp = enemy.max_hp
		enemy.alive = true
		enemy.position = Vector2(790 + (index % 4) * 230, 500 + floori(index / 4.0) * 260)
		enemy.home = enemy.position
		enemy.direction = enemy.position.direction_to(game.player)
		enemy.moving = index % 2 == 0
		enemy.attack_timer = 0.18 + float(index % 4) * 0.22
		enemy.visual_state = "idle"
		enemy.visual_time = float(index) * 0.11
		enemy.action_kind = game.CombatSystem.enemy_action_kind(enemy.kind)
		enemy.action_target = game.player
		game.enemy_nodes[index] = enemy


## Рисует один кадр противника с общей привязкой ног и масштабом конкретного семейства.
static func draw_actor(game: Node2D, enemy: Dictionary, texture: Texture2D, frame_index: int, modulate: Color) -> void:
	var kind: String = enemy.kind
	var size:=CreatureVisualProfileSystem.enemy_size(int(enemy.get("level",1)))
	var destination:=CreatureVisualProfileSystem.actor_rect(enemy.position,size)
	game.draw_texture_rect_region(texture, destination, source_rect(kind, enemy.get("direction", Vector2.DOWN), frame_index), modulate)


## Рисует отделившуюся стрелу, магический заряд или кристальный удар между врагом и целью.
static func draw_action_effect(game: Node2D, enemy: Dictionary, progress: float) -> void:
	var kind: String = enemy.kind
	var frame_index := effect_frame(kind)
	if frame_index < 0 or progress < 0.32: return
	var start: Vector2 = enemy.position
	var target: Vector2 = enemy.get("action_target", start + enemy.get("direction", Vector2.DOWN) * 100.0)
	var travel := clampf((progress - 0.32) / 0.58, 0.0, 1.0)
	var position := target if kind == "cave_guardian" else start.lerp(target, travel)
	var size := 86.0 if kind == "cave_guardian" else 58.0
	var destination := Rect2(position - Vector2(size * 0.5, size * 0.62), Vector2(size, size))
	game.draw_texture_rect_region(action_texture(kind), destination, source_rect(kind, enemy.get("direction", Vector2.DOWN), frame_index))


## Рисует полное состояние врага: ходьбу, боевое действие, получение урона или смерть.
static func draw_enemy(game: Node2D, enemy: Dictionary, state: String, attack_duration: float) -> void:
	var modulate := Color.WHITE
	if state == "hurt": modulate = Color(1.0, 0.48, 0.48)
	elif state == "death": modulate.a = clampf(1.15 - float(enemy.get("visual_time", 0.0)), 0.0, 1.0)
	if state == "attack":
		var progress := clampf(float(enemy.get("visual_time", 0.0)) / attack_duration, 0.0, 1.0)
		var frame_index := action_frame(progress)
		draw_actor(game, enemy, action_texture(enemy.kind), body_action_frame(enemy.kind, frame_index), modulate)
		draw_action_effect(game, enemy, progress)
		return
	draw_actor(game, enemy, walk_texture(enemy.kind), walk_frame(float(enemy.get("visual_time", 0.0)), bool(enemy.get("moving", false))), modulate)
