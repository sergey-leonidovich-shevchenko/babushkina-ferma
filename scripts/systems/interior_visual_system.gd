extends RefCounted

const ATLAS := preload("res://assets/game/world_polish/village_polish_atlas.png")
const SOURCE_CELL := Vector2(128, 128)
const PROFILES := {
	"bed":{"cell":Vector2i(0,0),"visual_size":Vector2(144,120),"collision_size":Vector2(120,48)},
	"shop":{"cell":Vector2i(1,0),"visual_size":Vector2(216,120),"collision_size":Vector2(192,48)},
	"contracts":{"cell":Vector2i(2,0),"visual_size":Vector2(192,120),"collision_size":Vector2(168,48)},
	"forge":{"cell":Vector2i(3,0),"visual_size":Vector2(192,144),"collision_size":Vector2(144,72)},
	"home_chest":{"cell":Vector2i(4,0),"visual_size":Vector2(96,96),"collision_size":Vector2(72,48)},
}
const ROOM_PROPS := {
	"cottage_interior":[{"kind":"bed","position":Vector2(340,318)}],
	"shop_interior":[{"kind":"shop","position":Vector2(576,300)},{"kind":"home_chest","position":Vector2(840,318),"decorative":true}],
	"guild_interior":[{"kind":"contracts","position":Vector2(576,300)},{"kind":"home_chest","position":Vector2(850,318),"decorative":true}],
	"forge_interior":[{"kind":"forge","position":Vector2(576,310)},{"kind":"home_chest","position":Vector2(850,318),"decorative":true}],
}


## Возвращает единый визуальный и физический профиль интерьерного объекта.
static func profile(kind: String) -> Dictionary:
	return PROFILES.get(kind, {})


## Возвращает исходную ячейку строгого атласа 5×4 без захвата соседних рисунков.
static func source_rect(kind: String) -> Rect2:
	var cell: Vector2i = PROFILES[kind].cell
	return Rect2(Vector2(cell) * SOURCE_CELL, SOURCE_CELL)


## Рассчитывает рисунок от нижней центральной опоры объекта.
static func destination_rect(kind: String, position: Vector2) -> Rect2:
	var size: Vector2 = PROFILES[kind].visual_size
	return Rect2(position - Vector2(size.x * 0.5, size.y), size)


## Рассчитывает честный footprint у пола независимо от высоты рисунка.
static func collision_rect(kind: String, position: Vector2) -> Rect2:
	var size: Vector2 = PROFILES[kind].collision_size
	return Rect2(position - Vector2(size.x * 0.5, size.y), size)


## Возвращает тематический набор комнаты либо стабильную пару для дополнительного этажа.
static func props(location: String) -> Array:
	if ROOM_PROPS.has(location):
		return ROOM_PROPS[location]
	var kinds := ["bed", "shop", "contracts", "forge"]
	return [{"kind":kinds[posmod(location.hash(),kinds.size())],"position":Vector2(410,310)},{"kind":"home_chest","position":Vector2(770,330),"decorative":true}]


## Возвращает коллизии всей мебели комнаты из тех же профилей, что использует рисунок.
static func collision_rects(location: String) -> Array[Rect2]:
	var result: Array[Rect2] = []
	for prop in props(location):
		result.append(collision_rect(String(prop.kind), Vector2(prop.position)))
	return result


## Рисует объект из строгой ячейки с общей нижней опорой и без искажения соседних спрайтов.
static func draw(canvas: Node2D, kind: String, position: Vector2, modulate: Color = Color.WHITE) -> void:
	canvas.draw_texture_rect_region(ATLAS, destination_rect(kind,position), source_rect(kind), modulate)


## Настраивает чистый контрольный кадр выбранной комнаты из аргумента capture-interior.
static func configure_preview(game: Node, arguments: PackedStringArray) -> void:
	for argument in arguments:
		if not argument.begins_with("--capture-interior="): continue
		var location := argument.trim_prefix("--capture-interior=")
		if not game.BuildingSystem.INTERIORS.has(location): return
		game.language_screen=false; game.title_screen=false; game.current_location=location; game.player=game.BuildingSystem.INTERIORS[location].spawn; game.tutorial_visible=false
		if location=="cottage_interior": game.home_chest_owned=true
		game.set_meta("capture_interior_frames",6); game.set_meta("capture_interior_location",location); game.set_meta("capture_first_level_clean",true)
		return


## Сохраняет нативный игровой кадр комнаты после стабилизации viewport и завершает capture-процесс.
static func update_preview_capture(game: Node) -> bool:
	if not game.has_meta("capture_interior_frames"): return false
	var frames_left:=int(game.get_meta("capture_interior_frames"))-1; game.set_meta("capture_interior_frames",frames_left)
	if frames_left>0: return false
	game.remove_meta("capture_interior_frames"); var location:=String(game.get_meta("capture_interior_location")); game.remove_meta("capture_interior_location")
	var image:=game.get_viewport().get_texture().get_image()
	if image==null: game.push_error("Renderer не предоставил кадр интерьера"); game.get_tree().quit(); return true
	if image.get_size()!=Vector2i(1152,648): image.resize(1152,648,Image.INTERPOLATE_NEAREST)
	var output:=ProjectSettings.globalize_path("res://assets/generated/level_drafts/interior_%s_ingame_preview.png"%location); var error:=image.save_png(output)
	if error!=OK: game.push_error("Не удалось сохранить предпросмотр интерьера %s: %s"%[location,error])
	game.get_tree().quit(); return true
