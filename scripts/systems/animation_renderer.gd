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


## Отрисовывает героя по текущему состоянию игры.
static func draw_player(game: Node2D) -> void:
	var position: Vector2 = game.player.round()
	var moving: bool = game.get_movement_direction() != Vector2.ZERO
	var row: int = game.PlayerSystem.direction_row(game.facing)
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
	var cell_size := Vector2(game.HERO_PROGRESSION_ATLAS.get_width() / 4.0, game.HERO_PROGRESSION_ATLAS.get_height() / 4.0)
	var skin_stage: int = game.SkillSystem.hero_skin_stage(game.player_level)
	var source := Rect2(Vector2(skin_stage, row) * cell_size, cell_size)
	game.draw_living_atlas_sprite(game.HERO_PROGRESSION_ATLAS, source, position + attack_offset, Vector2(82, 82), game.walk_animation_time, moving, 0.0)
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
	if kind in game.CombatSystem.PIRATE_FAMILIES:
		draw_pirate_enemy(game, enemy, state)
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
	var kind: String = enemy.kind
	var motion: Dictionary = game.PresentationSystem.living_motion(float(enemy.get("visual_time", 0.0)), bool(enemy.get("moving", false)), float(enemy.level))
	var position: Vector2 = enemy.position + motion.offset
	var alpha := clampf(1.4 - float(enemy.get("visual_time", 0.0)), 0.0, 1.0) if state == "death" else 1.0
	var hurt := 0.45 if state == "hurt" else 0.0
	var skin := Color("79a56d") if kind == "zombie_pirate" else Color("ddb08a")
	var coat := Color("315777") if kind == "pirate" else (Color("66523f") if kind == "zombie_pirate" else Color("456d79"))
	if kind == "drowned_captain": skin = Color("779b91"); coat = Color("6e2636")
	if kind == "sea_ghost":
		var ghost_color := Color(0.48 + hurt, 0.9, 0.92, 0.62 * alpha)
		game.draw_circle(position - Vector2(0, 14), 25, ghost_color)
		game.draw_colored_polygon(PackedVector2Array([position+Vector2(-25,-8),position+Vector2(25,-8),position+Vector2(18,35),position+Vector2(7,25),position+Vector2(-4,36),position+Vector2(-16,25)]), ghost_color)
		game.draw_circle(position + Vector2(-9,-18), 4, Color(0.06,0.18,0.24,alpha)); game.draw_circle(position + Vector2(9,-18), 4, Color(0.06,0.18,0.24,alpha))
		game.draw_arc(position, 34 + sin(float(enemy.visual_time) * 5.0) * 3.0, 0, TAU, 24, Color(0.55,0.98,1.0,0.24 * alpha), 3)
		return
	var shadow := PackedVector2Array()
	for point_index in 16:
		var angle := TAU * point_index / 16.0
		shadow.append(position + Vector2(cos(angle) * 25.0, 34.0 + sin(angle) * 8.0))
	game.draw_colored_polygon(shadow, Color(0.05,0.09,0.11,0.32 * alpha))
	game.draw_rect(Rect2(position + Vector2(-21,-2),Vector2(42,45)), coat.lightened(hurt), true)
	game.draw_circle(position - Vector2(0,20), 22, skin.lightened(hurt))
	game.draw_circle(position + Vector2(-8,-23), 3, Color("1b2328")); game.draw_circle(position + Vector2(8,-23), 3, Color("1b2328"))
	game.draw_line(position + Vector2(-18,-44),position + Vector2(18,-44),Color("241b20",alpha),12)
	game.draw_colored_polygon(PackedVector2Array([position+Vector2(-29,-43),position+Vector2(0,-67),position+Vector2(29,-43)]), Color("2c2027",alpha))
	game.draw_circle(position + Vector2(0,-50), 7, Color("ece5cf",alpha)); game.draw_line(position+Vector2(-6,-56),position+Vector2(6,-44),Color("2c2027",alpha),3); game.draw_line(position+Vector2(6,-56),position+Vector2(-6,-44),Color("2c2027",alpha),3)
	if kind == "drowned_captain": game.draw_arc(position - Vector2(0,4), 35, -2.4, -0.7, 12, Color("e5bf54",alpha), 6)
