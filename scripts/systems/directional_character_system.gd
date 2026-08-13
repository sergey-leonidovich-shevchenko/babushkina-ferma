extends RefCounted

const COLUMNS := 4
const ROWS := 8
const WALK_FPS := 8.0
const HERO_BASE_SIZE := Vector2(86, 86)
const HERO_VISUAL_SCALE := 0.92
const HERO_DRAW_SIZE := HERO_BASE_SIZE * HERO_VISUAL_SCALE
const HERO_SHADOW_RADII := Vector2(18, 6) * HERO_VISUAL_SCALE
const AnimationAssetRegistry := preload("res://scripts/systems/animation_asset_registry.gd")

const HERO_TEXTURES := [
	preload("res://assets/game/characters/directional/hero_farmer_walk_8dir.png"),
	preload("res://assets/game/characters/directional/hero_scout_walk_8dir.png"),
	preload("res://assets/game/characters/directional/hero_guardian_walk_8dir.png"),
	preload("res://assets/game/characters/directional/hero_moon_walk_8dir.png"),
]
const NPC_TEXTURES := [
	preload("res://assets/game/characters/directional/npc_grandmother_walk_8dir.png"),
	preload("res://assets/game/characters/directional/npc_official_walk_8dir.png"),
	preload("res://assets/game/characters/directional/npc_herbalist_walk_8dir.png"),
]
const COMPANION_TEXTURES := {
	"mila": preload("res://assets/game/characters/directional/companion_mila_walk_8dir.png"),
	"borislav": preload("res://assets/game/characters/directional/companion_borislav_walk_8dir.png"),
	"luna": preload("res://assets/game/characters/directional/companion_luna_walk_8dir.png"),
}


## Возвращает область одного кадра атласа 4 × 8 для заданного направления и времени шага.
static func source_rect(texture: Texture2D, direction: Vector2, animation_time: float, moving: bool) -> Rect2:
	var cell_size := Vector2(texture.get_width() / float(COLUMNS), texture.get_height() / float(ROWS))
	var row: int = AnimationAssetRegistry.direction_index(direction)
	var frame: int = int(animation_time * WALK_FPS) % COLUMNS if moving else 0
	return Rect2(Vector2(frame, row) * cell_size, cell_size)


## Рисует героя в облике, соответствующем текущему диапазону уровней.
static func draw_hero(game: Node2D, position: Vector2, direction: Vector2, moving: bool, modulate: Color = Color.WHITE) -> void:
	var stage: int = game.SkillSystem.hero_skin_stage(game.player_level)
	draw_actor(game, HERO_TEXTURES[stage], position, HERO_DRAW_SIZE, direction, game.walk_animation_time, moving, modulate, HERO_SHADOW_RADII)


## Рисует один из трёх архетипов жителя с полноценным направленным циклом шага.
static func draw_npc(game: Node2D, sprite_index: int, position: Vector2, direction: Vector2, moving: bool, tint: Color = Color.WHITE) -> void:
	if sprite_index < 0 or sprite_index >= NPC_TEXTURES.size():
		return
	draw_actor(game, NPC_TEXTURES[sprite_index], position, Vector2(96, 96), direction, game.walk_animation_time, moving, tint)


## Рисует выбранного напарника по его фактическому направлению движения.
static func draw_companion(game: Node2D, companion_id: String, position: Vector2, direction: Vector2, moving: bool) -> void:
	if not COMPANION_TEXTURES.has(companion_id):
		return
	draw_actor(game, COMPANION_TEXTURES[companion_id], position, Vector2(100, 100), direction, game.walk_animation_time, moving)


## Рисует общий спрайт актёра с единой точкой опоры у ног и мягкой тенью.
static func draw_actor(game: Node2D, texture: Texture2D, position: Vector2, size: Vector2, direction: Vector2, animation_time: float, moving: bool, modulate: Color = Color.WHITE, shadow_radii: Vector2 = Vector2(18, 6)) -> void:
	draw_soft_shadow(game, position + Vector2(0, 25), shadow_radii)
	if moving:
		var destination := Rect2(position - Vector2(size.x * 0.5, size.y * 0.68), size)
		var world_transform: Vector2 = -game.camera_offset
		game.draw_set_transform(world_transform + position, 0.0, Vector2.ONE)
		var local_destination := Rect2(destination.position - position, destination.size)
		game.draw_texture_rect_region(texture, local_destination, source_rect(texture, direction, animation_time, true), modulate)
		game.draw_set_transform(world_transform, 0.0, Vector2.ONE)
		return
	var phase: float = fposmod((position.x + position.y) * 0.013, TAU)
	var motion: Dictionary = game.PresentationSystem.living_motion(animation_time, false, phase)
	var world_transform: Vector2 = -game.camera_offset
	game.draw_set_transform(world_transform + position + Vector2(motion.offset), float(motion.rotation), motion.scale)
	game.draw_texture_rect_region(texture, Rect2(Vector2(-size.x * 0.5, -size.y * 0.68), size), source_rect(texture, direction, animation_time, false), modulate)
	game.draw_set_transform(world_transform, 0.0, Vector2.ONE)


## Рисует компактную эллиптическую тень, согласованную с точкой опоры персонажа.
static func draw_soft_shadow(game: Node2D, center: Vector2, radii: Vector2) -> void:
	var points := PackedVector2Array()
	for step in 16:
		var angle := TAU * step / 16.0
		points.append(center + Vector2(cos(angle) * radii.x, sin(angle) * radii.y))
	game.draw_colored_polygon(points, Color(0.05, 0.08, 0.08, 0.22))
