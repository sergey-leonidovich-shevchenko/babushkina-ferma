extends RefCounted

const COLUMNS := 4
const ROWS := 8
const WALK_FPS := 8.0
const HERO_BASE_SIZE:=Vector2(96,96)
const HERO_VISUAL_SCALE:=1.0
const HERO_DRAW_SIZE:=HERO_BASE_SIZE
const NPC_DRAW_SIZE:=Vector2(96,96)
const COMPANION_DRAW_SIZE:=Vector2(96,96)
const GROUND_OFFSET:=Vector2.ZERO
const HERO_SHADOW_RADII:=Vector2(18,6)
const AnimationAssetRegistry := preload("res://scripts/systems/animation_asset_registry.gd")
const HeroVisualSystem := preload("res://scripts/systems/hero_visual_system.gd")
const GrandmotherVisualSystem := preload("res://scripts/systems/grandmother_visual_system.gd")
const Residents := preload("res://scripts/systems/resident_visual_system.gd")

const HERO_TEXTURES := [
	HeroVisualSystem.WALK_MASTER,
]
const NPC_TEXTURES := [
	GrandmotherVisualSystem.MASTER,
	preload("res://assets/game/characters/walk_v2/npc_official.png"),
	preload("res://assets/game/characters/walk_v2/npc_herbalist.png"),
]
const COMPANION_TEXTURES := {
	"mila": preload("res://assets/game/characters/walk_v2/companion_mila.png"),
	"borislav": preload("res://assets/game/characters/walk_v2/companion_borislav.png"),
	"luna": preload("res://assets/game/characters/walk_v2/companion_luna.png"),
}


## Выбирает авторский кадр новых четырёхракурсных персонажей или ячейку прежнего атласа 4 × 8.
static func source_rect(texture: Texture2D, direction: Vector2, animation_time: float, moving: bool) -> Rect2:
	if texture == HeroVisualSystem.WALK_MASTER: return HeroVisualSystem.source_rect(direction, animation_time, moving)
	if texture == GrandmotherVisualSystem.MASTER: return GrandmotherVisualSystem.pose(direction, animation_time, moving).source
	if Residents.handles(texture): return Residents.pose(texture,direction,animation_time,moving).source
	var cell_size := Vector2(texture.get_width() / float(COLUMNS), texture.get_height() / float(ROWS))
	var row: int = AnimationAssetRegistry.direction_index(direction)
	var frame: int = int(animation_time * WALK_FPS) % COLUMNS if moving else 0
	return Rect2(Vector2(frame, row) * cell_size, cell_size)


## Рисует нового четырёхнаправленного героя с неподвижной точкой стоп в физической позиции.
static func draw_hero(game: Node2D, position: Vector2, direction: Vector2, moving: bool, modulate: Color = Color.WHITE) -> void:
	HeroVisualSystem.draw_actor(game, position, direction, moving, modulate)


## Рисует новый четырёхракурсный цикл бабушки; остальные жители сохраняют собственные восемь направлений.
static func draw_npc(game: Node2D, sprite_index: int, position: Vector2, direction: Vector2, moving: bool, tint: Color = Color.WHITE) -> void:
	if sprite_index < 0 or sprite_index >= NPC_TEXTURES.size():
		return
	if sprite_index == 0:
		GrandmotherVisualSystem.draw_actor(game, position, direction, moving, tint)
		return
	draw_actor(game, NPC_TEXTURES[sprite_index], position, NPC_DRAW_SIZE, direction, game.walk_animation_time, moving, tint)


## Рисует выбранного напарника по его фактическому направлению движения.
static func draw_companion(game: Node2D, companion_id: String, position: Vector2, direction: Vector2, moving: bool) -> void:
	if not COMPANION_TEXTURES.has(companion_id):
		return
	draw_actor(game, COMPANION_TEXTURES[companion_id], position, COMPANION_DRAW_SIZE, direction, game.walk_animation_time, moving)


## Возвращает резервную рамку актёра от общей физической точки стоп без старого смещения вниз.
static func actor_rect(position:Vector2,size:Vector2)->Rect2:
	return Rect2(position+GROUND_OFFSET-Vector2(size.x*0.5,size.y),size)


## Даёт инспектору точную рамку нового NPC, оставляя стандартную рамку у старых архетипов.
static func npc_rect(sprite_index: int, position: Vector2, direction: Vector2, time: float, moving: bool) -> Rect2:
	if sprite_index == 0: return GrandmotherVisualSystem.destination(position, GrandmotherVisualSystem.pose(direction,time,moving))
	if sprite_index>0 and sprite_index<NPC_TEXTURES.size(): return Residents.destination(position,Residents.pose(NPC_TEXTURES[sprite_index],direction,time,moving))
	return actor_rect(position, NPC_DRAW_SIZE)

## Даёт инспектору ту же рамку самостоятельного напарника, которую рисует игровой renderer.
static func companion_rect(kind: String, position: Vector2, direction: Vector2, time: float, moving: bool) -> Rect2:
	if not COMPANION_TEXTURES.has(kind): return Rect2()
	return Residents.destination(position,Residents.pose(COMPANION_TEXTURES[kind],direction,time,moving))


## Проверяет четыре ракурса героя и бабушки, а также прежние восьмиракурсные наборы остальных жителей и напарников.
static func profiles_are_valid()->bool:
	if HERO_DRAW_SIZE!=Vector2(96,96) or NPC_DRAW_SIZE!=Vector2(96,96) or COMPANION_DRAW_SIZE!=Vector2(96,96): return false
	if not HeroVisualSystem.profiles_are_valid() or not GrandmotherVisualSystem.profiles_are_valid(): return false
	for texture in NPC_TEXTURES.slice(1)+COMPANION_TEXTURES.values():
		if texture.get_size()!=Vector2(512,1024) or texture.get_width()%COLUMNS!=0 or texture.get_height()%ROWS!=0: return false
	return true


## Сохраняет контрольный игровой кадр героя, жителей и напарников в общих модульных рамках.
static func update_preview_capture(game:Node)->bool:
	if not game.has_meta("capture_character_frames"): return false
	var frames_left:=int(game.get_meta("capture_character_frames"))-1; game.set_meta("capture_character_frames",frames_left)
	if frames_left>0: return false
	game.remove_meta("capture_character_frames"); var image:=game.get_viewport().get_texture().get_image()
	if image==null: game.get_tree().quit(); return true
	var output:=ProjectSettings.globalize_path("res://assets/generated/level_drafts/characters_ingame_preview.png"); var error:=image.save_png(output)
	if error!=OK: push_error("Не удалось сохранить предпросмотр человеческих персонажей: %s"%error)
	game.get_tree().quit(); return true


## Готовит отдельную витрину героя, жителей и напарников, не нагружая загрузчик сцены деталями предпросмотра.
static func configure_preview(game: Node, capture: bool) -> void:
	game.language_screen = false
	game.title_screen = false
	game.current_location = "overworld"
	game.player = Vector2(700, 850)
	game.tutorial_visible = false
	game.npc_position = Vector2(500, 810)
	game.guild_master_position = Vector2(650, 790)
	game.herbalist_position = Vector2(830, 810)
	game.recruited_companions.assign(["mila", "borislav", "luna"])
	game.active_companions.assign(["mila", "borislav", "luna"])
	game.companion_positions = {"mila": Vector2(560, 930), "borislav": Vector2(700, 930), "luna": Vector2(840, 930)}
	if capture:
		game.enemy_nodes = []
		game.hazard_nodes = []
		game.wildlife_nodes = []
		game.set_meta("capture_character_frames", 8)
		game.set_meta("capture_first_level_clean", true)


## Рисует общий спрайт актёра с единой точкой опоры у ног и мягкой тенью.
static func draw_actor(game: Node2D, texture: Texture2D, position: Vector2, size: Vector2, direction: Vector2, animation_time: float, moving: bool, modulate: Color = Color.WHITE, shadow_radii: Vector2 = Vector2(18, 6)) -> void:
	if Residents.handles(texture): Residents.draw_actor(game,texture,position,direction,moving,modulate); return
	draw_soft_shadow(game,position+GROUND_OFFSET,shadow_radii)
	if moving:
		var destination:=actor_rect(position,size)
		var projection:=preload("res://scripts/systems/world_projection_system.gd")
		projection.apply(game,position)
		var local_destination := Rect2(destination.position - position, destination.size)
		game.draw_texture_rect_region(texture, local_destination, source_rect(texture, direction, animation_time, true), modulate)
		projection.apply(game)
		return
	var phase: float = fposmod((position.x + position.y) * 0.013, TAU)
	var motion: Dictionary = game.PresentationSystem.living_motion(animation_time, false, phase)
	var projection:=preload("res://scripts/systems/world_projection_system.gd")
	projection.apply(game,position+Vector2(motion.offset),float(motion.rotation),motion.scale)
	game.draw_texture_rect_region(texture, actor_rect(Vector2.ZERO,size), source_rect(texture, direction, animation_time, false), modulate)
	projection.apply(game)


## Рисует компактную эллиптическую тень, согласованную с точкой опоры персонажа.
static func draw_soft_shadow(game: Node2D, center: Vector2, radii: Vector2) -> void:
	var points := PackedVector2Array()
	for step in 16:
		var angle := TAU * step / 16.0
		points.append(center + Vector2(cos(angle) * radii.x, sin(angle) * radii.y))
	game.draw_colored_polygon(points, Color(0.05, 0.08, 0.08, 0.22))
