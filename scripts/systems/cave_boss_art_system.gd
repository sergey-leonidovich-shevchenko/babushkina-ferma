extends RefCounted

const ROOT := "res://assets/game/enemies/cave_boss/v1/"
static var _textures: Dictionary = {}
static var _frames: Dictionary = {}

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
	var result := 0
	for frame in catalog()[kind].frames:
		if int(frame.row) == row: result += 1
	return result

## Находит точную область кадра без округления предположительного размера сетки.
static func frame(kind: String, row: int, column: int) -> Dictionary:
	var safe_column := clampi(column, 0, count(kind,row) - 1)
	for value in catalog()[kind].frames:
		if int(value.row) == row and int(value.column) == safe_column: return value
	return {}

## Рисует отдельный спрайт с опорой на землю либо по центру для летающих объектов и вспышек.
static func draw(game: Node2D, kind: String, row: int, column: int, position: Vector2, size: float, centered: bool = false, tint: Color = Color.WHITE) -> void:
	var value := frame(kind,row,column)
	var region: Array = value.region
	var source := Rect2(float(region[0]),float(region[1]),float(region[2]),float(region[3]))
	var target_size := Vector2(size * source.size.x / source.size.y, size)
	var anchor := Vector2(0.5,0.5) if centered else Vector2(float(value.anchor[0]),float(value.anchor[1]))
	game.draw_texture_rect_region(texture(kind),Rect2(position - target_size * anchor,target_size),source,tint)
