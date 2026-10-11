extends RefCounted

const BASE_CELL:=24
const ATLAS:=preload("res://assets/game/expansion_pack/expansion_atlas.png")
const SOURCE_CELL:=Vector2(128,128)
const FURNITURE_TEXTURES := {
	"rustic_table": preload("res://assets/game/items/catalog/rustic_table.png"),
	"wooden_chair": preload("res://assets/game/items/catalog/wooden_chair.png"),
	"woven_rug": preload("res://assets/game/items/catalog/woven_rug.png"),
	"potted_fern": preload("res://assets/game/items/catalog/potted_fern.png"),
	"wooden_wardrobe": preload("res://assets/game/items/catalog/wooden_wardrobe.png"),
}
static var _furniture_regions: Dictionary = {}
const PROFILES:={
	"pig":{"cell":Vector2i(4,0),"visual":Vector2(96,72),"collision":Vector2(48,24)},
	"hen":{"cell":Vector2i(0,0),"visual":Vector2(72,72),"collision":Vector2(48,24)},
	"cow":{"cell":Vector2i(1,0),"visual":Vector2(96,96),"collision":Vector2(48,24)},
	"sheep":{"cell":Vector2i(2,0),"visual":Vector2(96,96),"collision":Vector2(48,24)},
	"trough":{"cell":Vector2i(3,0),"visual":Vector2(96,72),"collision":Vector2(72,24)},
	"museum":{"cell":Vector2i(0,1),"visual":Vector2(96,96),"collision":Vector2(72,48)},
	"rustic_table":{"cell":Vector2i(0,2),"visual":Vector2(96,72),"collision":Vector2(72,48)},
	"wooden_chair":{"cell":Vector2i(1,2),"visual":Vector2(72,72),"collision":Vector2(48,24)},
	"woven_rug":{"cell":Vector2i(2,2),"visual":Vector2(96,72),"collision":Vector2.ZERO},
	"potted_fern":{"cell":Vector2i(3,2),"visual":Vector2(72,96),"collision":Vector2(48,24)},
	"wooden_wardrobe":{"cell":Vector2i(4,2),"visual":Vector2(96,120),"collision":Vector2(72,48)},
	"secret":{"cell":Vector2i(0,3),"visual":Vector2(96,72),"collision":Vector2(72,48)},
	"raid_banner":{"cell":Vector2i(4,3),"visual":Vector2(72,96),"collision":Vector2.ZERO},
}


## Возвращает независимый профиль ячейки, модульного размера и видимого основания объекта фермерской жизни.
static func profile(kind:String)->Dictionary:
	return Dictionary(PROFILES.get(kind,{})).duplicate(true)


## Возвращает целую исходную ячейку строгого атласа без дробной выборки соседей.
static func source_rect(kind:String)->Rect2:
	var cell:=Vector2(profile(kind).get("cell",Vector2i.ZERO))
	return Rect2(cell*SOURCE_CELL,SOURCE_CELL)


## Строит видимый прямоугольник относительно единой нижней точки опоры.
static func visual_rect(kind:String,ground_position:Vector2)->Rect2:
	var size:=Vector2(profile(kind).get("visual",Vector2.ZERO))
	return Rect2(ground_position-Vector2(size.x*0.5,size.y),size)


## Строит прямоугольное основание из того же профиля, что используется отрисовкой.
static func collision_rect(kind:String,ground_position:Vector2)->Rect2:
	var size:=Vector2(profile(kind).get("collision",Vector2.ZERO))
	return Rect2(ground_position-Vector2(size.x*0.5,size.y),size)


## Проверяет строгую сетку исходника и кратность всех игровых размеров базовой клетке 24 px.
static func profiles_are_valid()->bool:
	if ATLAS.get_size()!=Vector2(640,512) or PROFILES.size()!=13: return false
	for kind in PROFILES:
		var data:=profile(kind); var cell:=Vector2i(data.cell); var visual:=Vector2(data.visual); var collision:=Vector2(data.collision)
		if cell.x<0 or cell.x>=5 or cell.y<0 or cell.y>=4: return false
		if int(visual.x)%BASE_CELL!=0 or int(visual.y)%BASE_CELL!=0: return false
		if collision!=Vector2.ZERO and (int(collision.x)%BASE_CELL!=0 or int(collision.y)%BASE_CELL!=0): return false
	return true


## Рисует одну семантическую ячейку атласа без неравномерного растяжения и случайного размера.
static func draw(canvas:CanvasItem,kind:String,ground_position:Vector2,tint:Color=Color.WHITE)->void:
	if not PROFILES.has(kind): return
	if FURNITURE_TEXTURES.has(kind):
		canvas.draw_texture_rect_region(FURNITURE_TEXTURES[kind], furniture_sprite_rect(kind, ground_position), furniture_source(kind), tint)
		return
	canvas.draw_texture_rect_region(ATLAS,visual_rect(kind,ground_position),source_rect(kind),tint)


## Один раз находит содержимое уже очищенного отдельного PNG без осколков соседних ячеек атласа.
static func furniture_source(kind: String) -> Rect2:
	if not _furniture_regions.has(kind):
		var texture: Texture2D = FURNITURE_TEXTURES[kind]
		_furniture_regions[kind] = Rect2(texture.get_image().get_used_rect())
	return _furniture_regions[kind]


## Вписывает мебель по пропорциям рисунка, сохраняя нижнюю опору и модульную область выбора.
static func furniture_sprite_rect(kind: String, ground_position: Vector2) -> Rect2:
	var bounds := visual_rect(kind, ground_position)
	var source := furniture_source(kind)
	var scale := minf(bounds.size.x / source.size.x, bounds.size.y / source.size.y)
	var size := source.size * scale
	return Rect2(Vector2(bounds.get_center().x - size.x * 0.5, bounds.end.y - size.y), size)


## Проверяет пересечение круглого персонажа с модульным основанием объекта.
static func circle_intersects_rect(center:Vector2,radius:float,rect:Rect2)->bool:
	if rect.size==Vector2.ZERO: return false
	var closest:=Vector2(clampf(center.x,rect.position.x,rect.end.x),clampf(center.y,rect.position.y,rect.end.y))
	return center.distance_squared_to(closest)<radius*radius


## Готовит чистый игровой кадр животных и кормушки для ручной проверки масштаба и опор.
static func configure_preview(game:Node,arguments:PackedStringArray)->bool:
	if "--capture-farm-life" not in arguments: return false
	game.language_screen=false; game.title_screen=false; game.current_location="overworld"; game.state.world.estate.level=3; game.player=Vector2(690,850); game.day=4; game.tutorial_visible=false
	game.set_meta("capture_first_level_clean",true); game.set_meta("capture_farm_life_frames",8)
	return true


## Сохраняет контрольный кадр фермерской жизни после полноценных кадров отрисовки.
static func update_preview_capture(game:Node)->bool:
	if not game.has_meta("capture_farm_life_frames"): return false
	var frames_left:=int(game.get_meta("capture_farm_life_frames"))-1; game.set_meta("capture_farm_life_frames",frames_left)
	if frames_left>0: return false
	game.remove_meta("capture_farm_life_frames"); var image:=game.get_viewport().get_texture().get_image()
	if image==null: game.get_tree().quit(); return true
	var output:=ProjectSettings.globalize_path("res://assets/generated/level_drafts/farm_life_ingame_preview.png"); var error:=image.save_png(output)
	if error!=OK: push_error("Не удалось сохранить предпросмотр фермерской жизни: %s"%error)
	game.get_tree().quit(); return true
