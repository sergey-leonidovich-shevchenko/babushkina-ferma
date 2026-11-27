extends RefCounted

const Map := preload("res://scripts/systems/village_map_data.gd")
const Ambient := preload("res://scripts/systems/village_ambient_renderer.gd")
const CHUNK_SIZE := Vector2(480, 336)


## Границы партии берутся из полных прямоугольников спрайтов, включая выступы за границу клетки.
static func build(spatial: bool) -> Array[Dictionary]:
	var chunks: Dictionary[Vector2i, Dictionary] = {}
	for anchor: Vector2 in Map.FLOWERS:
		var key := Vector2i((anchor / CHUNK_SIZE).floor()) if spatial else Vector2i.ZERO
		var rect := Ambient.destination_rect(anchor)
		if not chunks.has(key):
			var rects: Array[Rect2] = [rect]
			chunks[key] = {"cell": key, "bounds": rect, "rects": rects}
			continue
		var group: Dictionary = chunks[key]
		var previous: Rect2 = group.bounds
		var rects: Array[Rect2] = group.rects
		group["bounds"] = previous.merge(rect)
		rects.append(rect)
	var keys := chunks.keys()
	keys.sort()
	var result: Array[Dictionary] = []
	for key: Vector2i in keys:
		result.append(chunks[key])
	return result


## Считает ожидаемые партии и отдельные спрайты для области обновления кеша.
static func counts(groups: Array[Dictionary], clip: Rect2) -> Dictionary:
	var active_groups := 0
	var submitted := 0
	var visible := 0
	for group in groups:
		var bounds: Rect2 = group.bounds
		if not bounds.intersects(clip):
			continue
		active_groups += 1
		var rects: Array[Rect2] = group.rects
		submitted += rects.size()
		for rect in rects:
			if clip.intersects(rect):
				visible += 1
	return {"groups": active_groups, "submitted": submitted, "visible": visible}
