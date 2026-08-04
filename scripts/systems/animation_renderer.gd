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
const EnemyAnimationLibrary := preload("res://scripts/systems/enemy_animation_library.gd")


## Отрисовывает героя по текущему состоянию игры.
static func draw_player(game: Node2D) -> void:
	var position: Vector2 = game.player.round()
	var moving: bool = game.get_movement_direction() != Vector2.ZERO
	var attacking: bool = game.player_attack_timer > 0.0
	var attack_progress: float = 1.0 - game.player_attack_timer / game.AnimationSystem.PLAYER_ATTACK_DURATION if attacking else 0.0
	var attack_offset: Vector2 = game.facing * sin(attack_progress * PI) * 7.0
	var shadow := PackedVector2Array()
	for point_index in 16:
		var angle := TAU * point_index / 16.0
		shadow.append(position + Vector2(cos(angle) * 18.0, 8.0 + sin(angle) * 6.0))
	game.draw_colored_polygon(shadow, Color(0.08, 0.11, 0.10, 0.35))
	var walk_frame: int = game.PlayerSystem.animation_frame(game.walk_animation_time, moving)
	if moving and walk_frame in [0, 3]:
		var dust: Vector2 = position - game.facing * 12.0 + Vector2(0, 7)
		game.draw_circle(dust + Vector2(-7, 1), 3.0, Color(0.70, 0.66, 0.55, 0.38))
		game.draw_circle(dust + Vector2(6, -1), 2.0, Color(0.70, 0.66, 0.55, 0.28))
	var clothes_palette := [Color.WHITE, Color("d5ebff"), Color("ffe0cf"), Color("dcf0d1"), Color("eadcff")]
	var clothes_index := clampi(int(game.state.player.profile.get("clothes", 0)), 0, clothes_palette.size() - 1)
	var hero_modulate: Color = Color(0.72, 0.82, 1.0, 0.38) if game.invisibility_timer > 0.0 else clothes_palette[clothes_index]
	game.DirectionalCharacterSystem.draw_hero(game, position + attack_offset, game.facing, moving, hero_modulate)
	if game.equipped_weapon == "crystal_sword" and attacking:
		game.draw_line(position + game.facing * 10.0, position + game.facing * 39.0, Color("b9f7ff"), 6.0)
		game.draw_circle(position + game.facing * 34.0, 8.0, Color(0.30, 0.95, 1.0, 0.28))
	elif game.equipped_weapon == "forest_sword" and attacking:
		game.draw_line(position + game.facing * 10.0, position + game.facing * 37.0, Color("e4ddd0"), 6.0)
	elif game.equipped_weapon == "bow":
		var pull := 20.0 if attacking else 15.0
		game.draw_arc(position + game.facing * 18.0, pull, -1.4, 1.4, 12, Color("b77a45"), 4)


## Отрисовывает слизня по текущему состоянию игры.
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


## Отрисовывает врага по текущему состоянию игры.
static func draw_enemy(game: Node2D, enemy: Dictionary) -> void:
	var state: String = enemy.get("visual_state", "idle")
	var kind: String = enemy.kind
	if kind in EnemyAnimationLibrary.CORE_FAMILIES or kind in EnemyAnimationLibrary.PIRATE_FAMILIES:
		EnemyAnimationLibrary.draw_enemy(game, enemy, state, game.AnimationSystem.ENEMY_ATTACK_DURATION)
		return
	var column: int = game.CombatSystem.FAMILY_ORDER.find(kind)
	var rank: int = game.CombatSystem.visual_rank(int(enemy.get("level", 1)))
	var cell_size := Vector2(game.ENEMY_RANK_ATLAS.get_width() / 5.0, game.ENEMY_RANK_ATLAS.get_height() / 3.0)
	var source := Rect2(Vector2(column, rank) * cell_size, cell_size)
	var size := 96.0 if kind == "plant" else (126.0 if kind == "cave_guardian" else (104.0 if kind == "undead" else 96.0))
	var modulate := Color.WHITE
	if state == "hurt": modulate = Color(1.0, 0.55, 0.55)
	elif state == "death": modulate.a = clampf(1.4 - enemy.visual_time, 0.0, 1.0)
	var direction: Vector2 = enemy.get("direction", Vector2.DOWN)
	game.draw_living_atlas_sprite(game.ENEMY_RANK_ATLAS, source, enemy.position, Vector2(size, size), float(enemy.get("visual_time", 0.0)), bool(enemy.get("moving", false)), float(column) * 0.9, direction.x < -0.1, modulate)


## Рисует живых и мёртвых пиратов процедурно с дыханием, шагом, рангом и реакцией на удар.
static func draw_pirate_enemy(game: Node2D, enemy: Dictionary, state: String) -> void:
	game.VisualAssetSystem.draw_pirate_enemy(game, enemy, state)
