extends RefCounted

const SLIME_IDLE := preload("res://assets/game/enemies/slime_idle.png")
const SLIME_ATTACK := preload("res://assets/game/enemies/slime_attack.png")
const SLIME_HURT := preload("res://assets/game/enemies/slime_hurt.png")
const SLIME_DEATH := preload("res://assets/game/enemies/slime_death.png")
const SLIME_VISUAL_SIZE := Vector2(72,72)
const EnemyAnimationLibrary := preload("res://scripts/systems/enemy_animation_library.gd")


## Отрисовывает героя по текущему состоянию игры.
static func draw_player(game: Node2D) -> void:
	var position: Vector2 = game.player.round()
	var visual_scale: float = game.DirectionalCharacterSystem.HERO_VISUAL_SCALE
	var moving: bool = game.get_movement_direction() != Vector2.ZERO
	var attacking: bool = game.player_attack_timer > 0.0
	var attack_progress: float = 1.0 - game.player_attack_timer / game.AnimationSystem.PLAYER_ATTACK_DURATION if attacking else 0.0
	var attack_offset: Vector2 = game.facing * sin(attack_progress * PI) * 7.0 * visual_scale
	var walk_frame: int = game.PlayerSystem.animation_frame(game.walk_animation_time, moving)
	if moving and walk_frame in [0, 3]:
		var dust: Vector2 = position - game.facing * 12.0 * visual_scale + Vector2(0, 7) * visual_scale
		game.draw_circle(dust + Vector2(-7, 1) * visual_scale, 3.0 * visual_scale, Color(0.70, 0.66, 0.55, 0.38))
		game.draw_circle(dust + Vector2(6, -1) * visual_scale, 2.0 * visual_scale, Color(0.70, 0.66, 0.55, 0.28))
	var clothes_palette := [Color.WHITE, Color("d5ebff"), Color("ffe0cf"), Color("dcf0d1"), Color("eadcff")]
	var clothes_index := clampi(int(game.state.player.profile.get("clothes", 0)), 0, clothes_palette.size() - 1)
	var hero_modulate: Color = Color(0.72, 0.82, 1.0, 0.38) if game.invisibility_timer > 0.0 else clothes_palette[clothes_index]
	game.DirectionalCharacterSystem.draw_hero(game, position + attack_offset, game.facing, moving, hero_modulate)
	game.WorldPolishRenderer.draw_held_weapon(game,game.equipped_weapon,position,game.facing,attacking,visual_scale)


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
	game.draw_texture_rect_region(texture, game.CreatureVisualProfileSystem.actor_rect(game.slime_position,SLIME_VISUAL_SIZE), Rect2(frame * 64, 0, 64, 64))
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
	var size:Vector2=game.CreatureVisualProfileSystem.enemy_size(int(enemy.get("level",1)))
	var modulate := Color.WHITE
	if state == "hurt": modulate = Color(1.0, 0.55, 0.55)
	elif state == "death": modulate.a = clampf(1.4 - enemy.visual_time, 0.0, 1.0)
	var direction: Vector2 = enemy.get("direction", Vector2.DOWN)
	game.draw_living_atlas_sprite(game.ENEMY_RANK_ATLAS,source,enemy.position,size,float(enemy.get("visual_time",0.0)),bool(enemy.get("moving",false)),float(column)*0.9,direction.x<-0.1,modulate)


## Рисует живых и мёртвых пиратов процедурно с дыханием, шагом, рангом и реакцией на удар.
static func draw_pirate_enemy(game: Node2D, enemy: Dictionary, state: String) -> void:
	game.VisualAssetSystem.draw_pirate_enemy(game, enemy, state)
