extends RefCounted

const PLAYER_IDLE := preload("res://assets/game/characters/farmer_idle.png")
const PLAYER_WALK := preload("res://assets/game/characters/farmer_walk.png")
const PLAYER_SWORD_ATTACK := preload("res://assets/game/characters/farmer_sword_attack.png")
const SLIME_IDLE := preload("res://assets/game/enemies/slime_idle.png")
const SLIME_ATTACK := preload("res://assets/game/enemies/slime_attack.png")
const SLIME_HURT := preload("res://assets/game/enemies/slime_hurt.png")
const SLIME_DEATH := preload("res://assets/game/enemies/slime_death.png")
const PLANT_IDLE := preload("res://assets/game/enemies/predator_plant_idle.png")
const PLANT_HURT := preload("res://assets/game/enemies/predator_plant_hurt.png")
const PLANT_DEATH := preload("res://assets/game/enemies/predator_plant_death.png")
const ORC_IDLE := preload("res://assets/game/enemies/orc_idle.png")
const ORC_HURT := preload("res://assets/game/enemies/orc_hurt.png")
const ORC_DEATH := preload("res://assets/game/enemies/orc_death.png")


static func draw_player(game: Node2D) -> void:
	var position: Vector2 = game.player.round()
	var moving: bool = game.get_movement_direction() != Vector2.ZERO
	var row: int = game.PlayerSystem.direction_row(game.facing)
	var texture: Texture2D = PLAYER_WALK if moving else PLAYER_IDLE
	var frame_count := 6 if moving else 12
	var frame: int = game.PlayerSystem.animation_frame(game.walk_animation_time, moving) if moving else game.AnimationSystem.frame(game.walk_animation_time, frame_count, 7.0)
	var attacking: bool = game.player_attack_timer > 0.0
	if attacking and game.equipped_weapon in ["forest_sword", "crystal_sword"]:
		texture = PLAYER_SWORD_ATTACK
		frame_count = 8
		frame = game.AnimationSystem.frame(game.AnimationSystem.PLAYER_ATTACK_DURATION - game.player_attack_timer, frame_count, 17.0, false)
	var bob := roundf(game.PlayerSystem.sprite_bob(game.walk_animation_time, moving)) if not attacking else 0.0
	var attack_progress: float = 1.0 - game.player_attack_timer / game.AnimationSystem.PLAYER_ATTACK_DURATION if attacking else 0.0
	var attack_offset: Vector2 = game.facing * sin(attack_progress * PI) * 7.0
	var shadow := PackedVector2Array()
	for point_index in 16:
		var angle := TAU * point_index / 16.0
		shadow.append(position + Vector2(cos(angle) * 18.0, 8.0 + sin(angle) * 6.0))
	game.draw_colored_polygon(shadow, Color(0.08, 0.11, 0.10, 0.35))
	if moving and frame in [0, 3]:
		var dust: Vector2 = position - game.facing * 12.0 + Vector2(0, 7)
		game.draw_circle(dust + Vector2(-7, 1), 3.0, Color(0.70, 0.66, 0.55, 0.38))
		game.draw_circle(dust + Vector2(6, -1), 2.0, Color(0.70, 0.66, 0.55, 0.28))
	game.draw_texture_rect_region(texture, Rect2(position - Vector2(40, 66) + Vector2(0, bob) + attack_offset, Vector2(80, 80)), Rect2(frame * 64, row * 64, 64, 64))
	if game.equipped_weapon == "crystal_sword" and attacking:
		game.draw_circle(position + game.facing * 34.0, 8.0, Color(0.30, 0.95, 1.0, 0.28))
	elif game.equipped_weapon == "bow":
		var pull := 20.0 if attacking else 15.0
		game.draw_arc(position + game.facing * 18.0, pull, -1.4, 1.4, 12, Color("b77a45"), 4)


static func draw_slime(game: Node2D) -> bool:
	if not game.AnimationSystem.slime_is_visible(game):
		return false
	var state: String = game.slime_visual_state
	var texture: Texture2D = SLIME_IDLE
	var count := 6
	if state == "hurt": texture = SLIME_HURT; count = 6
	elif state == "attack": texture = SLIME_ATTACK; count = 8
	elif state == "death": texture = SLIME_DEATH; count = 10
	var frame: int = game.AnimationSystem.frame(game.slime_visual_time, count, 11.0, state != "death")
	game.draw_texture_rect_region(texture, Rect2(game.slime_position - Vector2(32, 40), Vector2(64, 64)), Rect2(frame * 64, 0, 64, 64))
	return true


static func draw_enemy(game: Node2D, enemy: Dictionary) -> void:
	var state: String = enemy.get("visual_state", "idle")
	var kind: String = enemy.kind
	var texture: Texture2D
	var frames := 4
	if kind == "plant":
		texture = PLANT_IDLE
		if state == "hurt": texture = PLANT_HURT; frames = 6
		elif state == "death": texture = PLANT_DEATH; frames = 8
	elif kind == "orc":
		texture = ORC_IDLE
		if state == "hurt": texture = ORC_HURT; frames = 6
		elif state == "death": texture = ORC_DEATH; frames = 8
	else:
		texture = game.enemy_sprite_texture(kind)
	var frame: int = game.AnimationSystem.frame(enemy.get("visual_time", 0.0), frames, 10.0, state == "idle")
	var row: int = game.enemy_direction_row(game.player - enemy.position)
	var size := 82.0 if kind == "plant" else 74.0
	var modulate := Color.WHITE
	if state == "hurt": modulate = Color(1.0, 0.55, 0.55)
	elif state == "death": modulate.a = clampf(1.4 - enemy.visual_time, 0.0, 1.0)
	if kind in ["plant", "orc"]:
		game.draw_texture_rect_region(texture, Rect2(enemy.position - Vector2(size * 0.5, size * 0.64), Vector2(size, size)), Rect2(frame * 64, row * 64, 64, 64), modulate)
	else:
		var bob := sin(Time.get_ticks_msec() / 180.0) * 2.0
		size = 124.0 if kind == "cave_guardian" else (92.0 if kind == "skeleton" else 108.0)
		var squash := 1.0 - 0.18 * clampf(enemy.get("visual_time", 0.0) / game.AnimationSystem.DEATH_DURATION, 0.0, 1.0) if state == "death" else 1.0
		game.draw_texture_rect(texture, Rect2(enemy.position - Vector2(size * 0.5, size * (0.70 + bob / 100.0)), Vector2(size, size * squash)), false, modulate)
