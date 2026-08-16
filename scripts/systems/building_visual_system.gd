extends RefCounted

const BASE_CELL := 24
const DOOR_SIZE := Vector2(48,24)
const TEXTURES := {
	"cottage":preload("res://assets/game/buildings/exteriors/cottage.png"),
	"shop_house":preload("res://assets/game/buildings/exteriors/shop_house.png"),
	"guild_hall":preload("res://assets/game/buildings/exteriors/guild_hall.png"),
	"forge":preload("res://assets/game/buildings/exteriors/forge.png"),
	"chapel":preload("res://assets/game/buildings/exteriors/chapel.png"),
	"prison":preload("res://assets/game/buildings/exteriors/prison.png"),
	"wizard_tower":preload("res://assets/game/buildings/exteriors/wizard_tower.png"),
	"moon_castle":preload("res://assets/game/buildings/exteriors/moon_castle.png"),
}
const PROFILES := {
	"cottage":{"visual_size":Vector2(336,408),"foundation_size":Vector2(288,120)},
	"shop_house":{"visual_size":Vector2(384,360),"foundation_size":Vector2(336,120)},
	"guild_hall":{"visual_size":Vector2(408,408),"foundation_size":Vector2(360,144)},
	"forge":{"visual_size":Vector2(360,384),"foundation_size":Vector2(312,144)},
	"chapel":{"visual_size":Vector2(288,408),"foundation_size":Vector2(240,144)},
	"prison":{"visual_size":Vector2(384,336),"foundation_size":Vector2(336,144)},
	"wizard_tower":{"visual_size":Vector2(312,432),"foundation_size":Vector2(264,168)},
	"moon_castle":{"visual_size":Vector2(432,384),"foundation_size":Vector2(384,168)},
}
const PREVIEW_BUILDINGS := {"rocky":"forge","cursed":"chapel","forest":"wizard_tower","ruins":"moon_castle"}


## Возвращает независимый фасад здания без дробной выборки соседней ячейки исходного атласа.
static func texture(building_id: String) -> Texture2D:
	return TEXTURES.get(building_id,TEXTURES.cottage)


## Возвращает общий профиль фасада, фундамента, двери и нижней точки опоры.
static func profile(building_id: String) -> Dictionary:
	var result:Dictionary=PROFILES.get(building_id,PROFILES.cottage).duplicate(true)
	result.anchor="bottom_center"; result.ground_gap=BASE_CELL; result.door_size=DOOR_SIZE
	return result


## Возвращает прямоугольник фасада так, чтобы нижняя видимая ступень совпадала с координатой двери.
static func destination_rect(building_id: String, door: Vector2) -> Rect2:
	var size:=Vector2(profile(building_id).visual_size)
	return Rect2(door-Vector2(size.x*0.5,size.y-BASE_CELL),size)


## Возвращает честную интерактивную область двери шириной две базовые клетки.
static func door_rect(building_id: String, door: Vector2) -> Rect2:
	var size:=Vector2(profile(building_id).door_size)
	return Rect2(door-Vector2(size.x*0.5,size.y),size)


## Делит твёрдый фундамент на левую и правую части, оставляя видимый дверной проём свободным.
static func collision_rects(building_id: String, door: Vector2) -> Array[Rect2]:
	var data:=profile(building_id); var foundation:=Vector2(data.foundation_size); var half_gap:=float(Vector2(data.door_size).x)*0.5; var side_width:=foundation.x*0.5-half_gap
	var top:=door.y-BASE_CELL-foundation.y; var left:=door.x-foundation.x*0.5
	return [Rect2(left,top,side_width,foundation.y),Rect2(door.x+half_gap,top,side_width,foundation.y)]


## Возвращает полный внешний контур фундамента для врагов и обзорных диагностических данных.
static func collision_bounds(building_id: String, door: Vector2) -> Rect2:
	var foundation:=Vector2(profile(building_id).foundation_size)
	return Rect2(door-Vector2(foundation.x*0.5,foundation.y+BASE_CELL),foundation)


## Проверяет модульность и соответствие импортированной текстуры заявленному визуальному размеру.
static func profile_is_valid(building_id: String) -> bool:
	if not TEXTURES.has(building_id) or not PROFILES.has(building_id): return false
	var data:=profile(building_id); var visual:=Vector2(data.visual_size); var foundation:=Vector2(data.foundation_size)
	return texture(building_id).get_size()==visual and int(visual.x)%BASE_CELL==0 and int(visual.y)%BASE_CELL==0 and int(foundation.x)%BASE_CELL==0 and int(foundation.y)%BASE_CELL==0 and Vector2(data.door_size)==DOOR_SIZE


## Рисует один внешний фасад один к одному без source-rect и скрытого растяжения дробной ячейки.
static func draw_building(canvas: Node2D, building_id: String, door: Vector2, tint: Color = Color.WHITE) -> void:
	canvas.draw_texture_rect(texture(building_id),destination_rect(building_id,door),false,tint)


## Готовит контрольный кадр здания в его настоящем внешнем биоме.
static func configure_preview(game: Node, location: String) -> bool:
	if not PREVIEW_BUILDINGS.has(location): return false
	var building_id:=String(PREVIEW_BUILDINGS[location]); var door:=Vector2(game.BuildingSystem.BUILDINGS[building_id].door)
	game.language_screen=false; game.title_screen=false; game.current_location=location; game.player=door+Vector2(0,84); game.tutorial_visible=false; game.set_meta("capture_first_level_clean",true)
	game.set_meta("capture_building_frames",8); game.set_meta("capture_building_location",location)
	return true


## Выбирает внешний биом по аргументу автоматического визуального прогона.
static func configure_from_arguments(game: Node, arguments: PackedStringArray) -> bool:
	if "--capture-building-collision" in arguments:
		configure_preview(game,"rocky")
		var debug_state:Dictionary=game.DebugOverlaySystem.default_state()
		debug_state.grid_size=BASE_CELL; debug_state.opacity=0.30; debug_state.hitboxes=true
		game.set_meta(game.DebugOverlaySystem.META_KEY,debug_state); game.DebugOverlaySystem.refresh_grid(game)
		game.set_meta("capture_building_location","collision")
		return true
	for location in PREVIEW_BUILDINGS:
		if "--capture-building-%s"%location in arguments: return configure_preview(game,location)
	return false


## Сохраняет контрольный кадр внешнего здания после нескольких полноценно отрисованных кадров.
static func update_preview_capture(game: Node) -> bool:
	if not game.has_meta("capture_building_frames"): return false
	var frames_left:=int(game.get_meta("capture_building_frames"))-1; game.set_meta("capture_building_frames",frames_left)
	if frames_left>0: return false
	game.remove_meta("capture_building_frames"); var location:=String(game.get_meta("capture_building_location","overworld")); game.remove_meta("capture_building_location")
	var image:=game.get_viewport().get_texture().get_image()
	if image==null: game.push_error("Renderer не предоставил кадр здания"); game.get_tree().quit(); return true
	var output:=ProjectSettings.globalize_path("res://assets/generated/level_drafts/building_%s_ingame_preview.png"%location); var error:=image.save_png(output)
	if error!=OK: game.push_error("Не удалось сохранить предпросмотр здания %s: %s"%[location,error])
	game.get_tree().quit(); return true
