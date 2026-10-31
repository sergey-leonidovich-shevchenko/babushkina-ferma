extends RefCounted

const SOURCE := preload("res://assets/game/locations/overworld/modular/riverbed_material_v1.png")
const CELL := 768.0

static var _texture: CanvasTexture
static var _meshes: Dictionary = {}


## Возвращает один сглаженный материал дна; старые пиксельные ресурсы не наследуют его sampler.
static func texture() -> CanvasTexture:
	if _texture == null:
		_texture = CanvasTexture.new()
		_texture.diffuse_texture = SOURCE
		_texture.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		_texture.texture_repeat = CanvasItem.TEXTURE_REPEAT_DISABLED
	return _texture


## Описывает только изображение дна: физика, глубина и разрешение рыбалки остаются у WaterTopology.
static func profile() -> Dictionary:
	return {
		"source_size": SOURCE.get_size(),
		"world_cell": Vector2(CELL, CELL),
		"physical_authority": false,
		"sampling": "mirrored_cells",
		"draw_calls_per_geometry": 1,
	}


## Зеркалит соседние UV-ячейки, поэтому сгенерированные противоположные края никогда не стыкуются.
static func uv_at(point: Vector2, cell: Vector2i) -> Vector2:
	var local := (point - Vector2(cell) * CELL) / CELL
	if posmod(cell.x, 2) == 1:
		local.x = 1.0 - local.x
	if posmod(cell.y, 2) == 1:
		local.y = 1.0 - local.y
	return local.clamp(Vector2.ZERO, Vector2.ONE)


## Собирает все отсечённые участки в один неизменяемый меш и повторно использует его между кадрами.
static func mesh(polygons: Array, cache_key: StringName) -> ArrayMesh:
	if _meshes.has(cache_key):
		return _meshes[cache_key]
	var vertices := PackedVector2Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	var bounds := _bounds(polygons)
	var first_cell := Vector2i((bounds.position / CELL).floor())
	var last_cell := Vector2i((bounds.end / CELL).ceil()) - Vector2i.ONE
	for y in range(first_cell.y, last_cell.y + 1):
		for x in range(first_cell.x, last_cell.x + 1):
			var cell := Vector2i(x, y)
			var frame := _cell_polygon(cell)
			for polygon: PackedVector2Array in polygons:
				for clipped: PackedVector2Array in Geometry2D.intersect_polygons(polygon, frame):
					_append_polygon(vertices, uvs, indices, clipped, cell)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	var result := ArrayMesh.new()
	result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	_meshes[cache_key] = result
	return result


## Рисует дно одной GPU-командой под отдельной полупрозрачной поверхностью воды.
static func draw(
	canvas: CanvasItem, polygons: Array, cache_key: StringName, tint: Color = Color.WHITE
) -> void:
	canvas.draw_mesh(mesh(polygons, cache_key), texture(), Transform2D.IDENTITY, tint)


## Возвращает число вершин готового меша для профильной проверки бюджета без render target.
static func vertex_count(polygons: Array, cache_key: StringName) -> int:
	var arrays: Array = mesh(polygons, cache_key).surface_get_arrays(0)
	var vertices: PackedVector2Array = arrays[Mesh.ARRAY_VERTEX]
	return vertices.size()


## Объединяет границы водных полигонов, чтобы обходить только затронутые ячейки материала.
static func _bounds(polygons: Array) -> Rect2:
	var initialized := false
	var bounds := Rect2()
	for polygon: PackedVector2Array in polygons:
		for point in polygon:
			if not initialized:
				bounds = Rect2(point, Vector2.ZERO)
				initialized = true
			else:
				bounds = bounds.expand(point)
	return bounds


## Возвращает прямоугольник одной мировой ячейки для точного отсечения водной геометрии.
static func _cell_polygon(cell: Vector2i) -> PackedVector2Array:
	var start := Vector2(cell) * CELL
	var finish := start + Vector2.ONE * CELL
	return PackedVector2Array(
		[start, Vector2(finish.x, start.y), finish, Vector2(start.x, finish.y)]
	)


## Триангулирует отсечённый фрагмент и добавляет согласованные вершины, UV и индексы в общий меш.
static func _append_polygon(
	vertices: PackedVector2Array,
	uvs: PackedVector2Array,
	indices: PackedInt32Array,
	polygon: PackedVector2Array,
	cell: Vector2i
) -> void:
	if polygon.size() < 3:
		return
	var triangles := Geometry2D.triangulate_polygon(polygon)
	if triangles.is_empty():
		return
	var start := vertices.size()
	for point in polygon:
		vertices.append(point)
		uvs.append(uv_at(point, cell))
	for index in triangles:
		indices.append(start + index)
