extends RefCounted

const CELL := 128
const PIVOT := Vector2(64,120)
const Registry := preload("res://scripts/systems/animation_asset_registry.gd")
static var _bounds = preload("res://scripts/systems/weak_owner_cache.gd").new(32)

## Узнаёт подготовленный набор жителей, сохраняя совместимость редактора со старыми ресурсами.
static func handles(texture: Texture2D) -> bool:
	return texture.resource_path.begins_with("res://assets/game/characters/walk_v2/")

## Измеряет видимое тело внутри безопасных ячеек один раз до первого шага.
static func warmup(texture: Texture2D) -> void:
	var key := texture.get_rid().get_id()
	if _bounds.fetch(texture,key) != null: return
	var image := texture.get_image()
	var regions := []
	for index in 32:
		var cell := Rect2i((index%4)*CELL,(index/4)*CELL,CELL,CELL)
		regions.append(image.get_region(cell).get_used_rect())
	_bounds.store(texture,key,regions)

## Выбирает восемь прежних направлений и целый кадр тела с общей измеренной опорой.
static func pose(texture: Texture2D, direction: Vector2, time: float, moving: bool) -> Dictionary:
	warmup(texture)
	var row := Registry.direction_index(direction)
	var frame := int(maxf(time,0.0)*8.0)%4 if moving else 0
	var cell := Vector2((frame)*CELL,row*CELL)
	var bounds: Rect2i = _bounds.fetch(texture,texture.get_rid().get_id())[row*4+frame]
	return {"texture":texture,"source":Rect2(Vector2(bounds.position)+cell,Vector2(bounds.size)),"pivot":PIVOT-Vector2(bounds.position),"scale":1.0}

## Строит рамку реально рисуемого тела от той же физической точки, что и герой.
static func destination(position: Vector2, frame: Dictionary) -> Rect2:
	return Rect2(position-Vector2(frame.pivot),Rect2(frame.source).size)

## Рисует подготовленного жителя без процедурного наклона и движения тени относительно ботинок.
static func draw_actor(game: Node2D, texture: Texture2D, position: Vector2, direction: Vector2, moving: bool, tint: Color = Color.WHITE) -> void:
	var frame := pose(texture,direction,game.walk_animation_time,moving)
	game.DirectionalCharacterSystem.draw_soft_shadow(game,position,Vector2(15,5))
	game.draw_texture_rect_region(texture,destination(position,frame),frame.source,tint)
