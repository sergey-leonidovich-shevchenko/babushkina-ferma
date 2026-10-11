extends RefCounted

const ROOT := "res://assets/game/enemies/cave_boss/v1/"
static var _textures: Dictionary = {}
static var _frames: Dictionary = {}
static var _rows: Dictionary = {}

## Читает один каталог областей и опор, не анализируя большие изображения в игровом кадре.
static func catalog() -> Dictionary:
	if _frames.is_empty(): _frames = JSON.parse_string(FileAccess.get_file_as_string(ROOT + "frames.json"))
	return _frames

## Загружает атлас один раз и повторно использует текстуру для всех кадров существ и эффектов.
static func texture(kind: String) -> Texture2D:
	if not _textures.has(kind): _textures[kind] = load(ROOT + kind + ".png")
	return _textures[kind]

## Возвращает число реальных кадров строки, включая пять самостоятельных кадров кристаллов.
static func count(kind: String, row: int) -> int:
	return prepared_rows(kind).get(row, []).size()

## Индексирует области и опоры один раз; горячая отрисовка не перебирает каталог и не собирает Rect2 заново.
static func prepared_rows(kind: String) -> Dictionary:
	if _rows.has(kind): return _rows[kind]
	var rows: Dictionary = {}
	for value in catalog().get(kind, {}).get("frames", []):
		var row := int(value.row)
		if not rows.has(row): rows[row] = []
		var prepared: Dictionary = value.duplicate(true)
		var region: Array = value.region
		prepared.source = Rect2(region[0],region[1],region[2],region[3])
		prepared.pivot = Vector2(value.anchor[0],value.anchor[1])
		rows[row].append(prepared)
	for values in rows.values(): values.sort_custom(func(a,b): return int(a.column) < int(b.column))
	_rows[kind] = rows
	return rows

## Находит точную область кадра без округления предположительного размера сетки.
static func frame(kind: String, row: int, column: int) -> Dictionary:
	var values: Array = prepared_rows(kind).get(row, [])
	return {} if values.is_empty() else values[clampi(column,0,values.size()-1)]

## Рисует отдельный спрайт с опорой на землю либо по центру для летающих объектов и вспышек.
static func draw(game: Node2D, kind: String, row: int, column: int, position: Vector2, size: float, centered: bool = false, tint: Color = Color.WHITE) -> void:
	var value := frame(kind,row,column)
	if value.is_empty(): return
	var source: Rect2 = value.source
	var target_size := Vector2(size * source.size.x / source.size.y, size)
	var anchor: Vector2 = Vector2(0.5,0.5) if centered else value.pivot
	game.draw_texture_rect_region(texture(kind),Rect2(position - target_size * anchor,target_size),source,tint)
