extends RefCounted

const SOURCE := preload("res://assets/game/locations/overworld/modular/grass_painted_v2.png")
const ColorPatches := preload("res://scripts/presentation/ground_color_patches.gd")
const CELL := 192.0
static var _texture: CanvasTexture
static var _meshes: Dictionary = {}


## Подготавливает один сглаженный материал; остальные старые ресурсы не наследуют его фильтр.
static func texture() -> CanvasTexture:
	if _texture == null:
		_texture = CanvasTexture.new()
		_texture.diffuse_texture = SOURCE
		_texture.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		_texture.texture_repeat = CanvasItem.TEXTURE_REPEAT_DISABLED
	return _texture


## Зеркалит только UV соседней ячейки: общий край читает тот же край изображения без скачка цвета.
static func uv_at(point: Vector2, cell: Vector2i) -> Vector2:
	var local := (point - Vector2(cell) * CELL) / CELL
	if posmod(cell.x, 2) == 1:
		local.x = 1.0 - local.x
	if posmod(cell.y, 2) == 1:
		local.y = 1.0 - local.y
	return local


## Собирает одну цветную сетку на размер и биом, не создавая узлов или процессов на клетку.
static func mesh(
	size: Vector2, biome: String = ColorPatches.DEFAULT_BIOME, patches: bool = true
) -> ArrayMesh:
	var key := "%dx%d:%s:%d" % [roundi(size.x), roundi(size.y), biome, int(patches)]
	if _meshes.has(key):
		return _meshes[key]
	var vertices := PackedVector2Array()
	var uv := PackedVector2Array()
	var colors := PackedColorArray()
	var indices := PackedInt32Array()
	var rows := ceili(size.y / CELL)
	var columns := ceili(size.x / CELL)
	for y: int in rows:
		for x: int in columns:
			var a := Vector2(x, y) * CELL
			var b := (a + Vector2.ONE * CELL).min(size)
			var start := vertices.size()
			var cell := Vector2i(x, y)
			var points: Array[Vector2] = [a, Vector2(b.x, a.y), b, Vector2(a.x, b.y)]
			for point: Vector2 in points:
				vertices.append(point)
				uv.append(uv_at(point, cell))
				colors.append(ColorPatches.color_at(point, biome) if patches else Color.WHITE)
			indices.append_array(
				PackedInt32Array([start, start + 1, start + 2, start, start + 2, start + 3])
			)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_TEX_UV] = uv
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = indices
	var result := ArrayMesh.new()
	result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	_meshes[key] = result
	return result


## Рисует неподвижный биом одной командой внутри прежнего кеша либо полного холодного fallback.
static func draw(
	canvas: Node2D,
	size: Vector2,
	tint: Color,
	biome: String = ColorPatches.DEFAULT_BIOME,
	patches: bool = true
) -> void:
	canvas.draw_mesh(mesh(size, biome, patches), texture(), Transform2D.IDENTITY, tint)
