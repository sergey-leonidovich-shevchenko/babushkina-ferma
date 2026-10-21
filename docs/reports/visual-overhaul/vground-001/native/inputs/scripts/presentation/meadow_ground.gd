extends RefCounted

const SOURCE := preload("res://assets/game/locations/overworld/modular/grass_painted_v2.png")
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
	if posmod(cell.x, 2) == 1: local.x = 1.0 - local.x
	if posmod(cell.y, 2) == 1: local.y = 1.0 - local.y
	return local

## Собирает ограниченную сетку один раз на размер карты, не создавая узлов на каждую плитку.
static func mesh(size: Vector2) -> ArrayMesh:
	if _meshes.has(size): return _meshes[size]
	var vertices := PackedVector2Array(); var uv := PackedVector2Array(); var indices := PackedInt32Array()
	for y in int(ceil(size.y / CELL)):
		for x in int(ceil(size.x / CELL)):
			var a := Vector2(x, y) * CELL; var b := (a + Vector2.ONE * CELL).min(size)
			var start := vertices.size(); var cell := Vector2i(x, y)
			for point in [a, Vector2(b.x, a.y), b, Vector2(a.x, b.y)]:
				vertices.append(point); uv.append(uv_at(point, cell))
			indices.append_array(PackedInt32Array([start,start+1,start+2,start,start+2,start+3]))
	var arrays := []; arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices; arrays[Mesh.ARRAY_TEX_UV] = uv; arrays[Mesh.ARRAY_INDEX] = indices
	var result := ArrayMesh.new(); result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	_meshes[size] = result
	return result

## Рисует неподвижный материал одной командой внутри прежнего кеша либо полного холодного fallback.
static func draw(canvas: Node2D, size: Vector2, tint: Color) -> void:
	canvas.draw_mesh(mesh(size), texture(), Transform2D.IDENTITY, tint)
