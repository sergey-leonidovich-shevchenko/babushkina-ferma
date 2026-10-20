extends RefCounted

const ROOT := "res://assets/game/farmyard/v1/"
static var _catalog: Dictionary = {}
static var _textures: Dictionary = {}

## Прогревает маленькие независимые кадры, не загружая большие исходные листы в игровую сцену.
static func warmup() -> void:
	if not _catalog.is_empty(): return
	_catalog=JSON.parse_string(FileAccess.get_file_as_string(ROOT+"frames.json"))
	for kind in _catalog:
		for entry in _catalog[kind]: _textures[entry.sprite]=load(ROOT+entry.sprite)

## Возвращает игровой кадр отдельного животного или постройки с общей нижней опорой.
static func frame(kind: String, index: int = 0) -> Dictionary:
	warmup()
	return _catalog[kind][clampi(index,0,_catalog[kind].size()-1)] if _catalog.has(kind) else {}

## Возвращает видимую область самостоятельного кадра с той же опорой, что использует отрисовка.
static func destination_rect(kind: String, index: int, position: Vector2) -> Rect2:
	var entry := frame(kind,index)
	if entry.is_empty(): return Rect2()
	return Rect2(position-Vector2(entry.pivot[0],entry.pivot[1]),Vector2(entry.size[0],entry.size[1]))

## Рисует мягкую эллиптическую контактную тень и спрайт в заранее подготовленном масштабе.
static func draw(game: Node2D, kind: String, index: int, position: Vector2, flip: bool = false) -> void:
	var entry := frame(kind,index)
	if entry.is_empty(): return
	var width := float(entry.size[0])
	var projection:=preload("res://scripts/systems/world_projection_system.gd")
	projection.apply(game,position,0,Vector2(1,0.30))
	game.draw_circle(Vector2.ZERO,width*0.38,Color(0.13,0.18,0.09,0.13))
	game.draw_circle(Vector2.ZERO,width*0.25,Color(0.10,0.14,0.07,0.12))
	projection.apply(game,position,0,Vector2(-1 if flip else 1,1))
	game.draw_texture(_textures[entry.sprite],-Vector2(entry.pivot[0],entry.pivot[1]))
	projection.apply(game)
