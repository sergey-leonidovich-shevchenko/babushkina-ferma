extends "res://scripts/presentation/village_ground_layer.gd"

const FlowerGroups := preload("res://tools/qa/performance/decor_batching/flower_groups.gd")
const BridgeLayers := preload("res://scripts/presentation/overworld_bridge_layers.gd")
const RegionTerrain := preload("res://scripts/presentation/village_region_terrain.gd")
const FLOWER_TINT := Color(0.92, 0.95, 0.84, 0.88)

var _batches: Array[MultiMeshInstance2D] = []
var _clip := Rect2()


## Устанавливает один из двух кандидатов в экземпляре StaticCover стенда.
func prepare(spatial: bool) -> void:
	assert(_batches.is_empty())
	var groups := FlowerGroups.build(spatial)
	var first_group := groups[0]
	var first_rects: Array[Rect2] = first_group.rects
	var mesh := _flower_mesh(first_rects[0].size)
	for group in groups:
		var rects: Array[Rect2] = group.rects
		var bounds: Rect2 = group.bounds
		var instances := MultiMesh.new()
		instances.transform_format = MultiMesh.TRANSFORM_2D
		instances.mesh = mesh
		instances.instance_count = rects.size()
		for index in rects.size():
			instances.set_instance_transform_2d(index, Transform2D(0.0, rects[index].position))
		instances.custom_aabb = AABB(
			Vector3(bounds.position.x, bounds.position.y, -1.0),
			Vector3(bounds.size.x, bounds.size.y, 2.0)
		)
		var batch := MultiMeshInstance2D.new()
		batch.multimesh = instances
		batch.texture = FlowerGroups.Ambient.ATLAS
		batch.self_modulate = FLOWER_TINT
		batch.show_behind_parent = true
		_batches.append(batch)
		add_child(batch)
	queue_redraw()


## Сохраняет прежний слой мостов и дорожек поверх групп цветов в том же кеше.
func _draw() -> void:
	_sync_batches()
	if _batches.is_empty() or not cover or holes:
		super._draw()
		return
	paint_count += 1
	BridgeLayers.draw_ground(self, separate_bridge_rails)
	RegionTerrain.paths(self, "overworld", soft_ground_edges, rectangular_roads, joined_roads)


## Ограничивает отправку кандидата фактической областью перерисовки кеша.
func set_capture_clip(rect: Rect2) -> void:
	_clip = rect
	_sync_batches()


func _sync_batches() -> void:
	for batch in _batches:
		var bounds := batch.multimesh.custom_aabb
		var rect := Rect2(
			Vector2(bounds.position.x, bounds.position.y), Vector2(bounds.size.x, bounds.size.y)
		)
		batch.visible = (
			cover
			and not holes
			and season != "winter"
			and (not _clip.has_area() or _clip.intersects(rect))
		)


## Читает отправленные опоры из экземпляров меша после прохода отрисовки.
func capture_batches(active_only: bool) -> Array:
	var result := []
	for batch in _batches:
		if active_only and not batch.is_visible_in_tree():
			continue
		var group := []
		for index in batch.multimesh.instance_count:
			var anchor := batch.multimesh.get_instance_transform_2d(index).origin + Vector2(36, 48)
			group.append([roundi(anchor.x), roundi(anchor.y)])
		result.append(group)
	return result


## Переносит исходную ячейку цветов на прямоугольный меш с общей текстурой.
static func _flower_mesh(size: Vector2) -> ArrayMesh:
	var texture_size := FlowerGroups.Ambient.ATLAS.get_size()
	var cell := FlowerGroups.Ambient.source_rect("flowers")
	var uv_first := cell.position / texture_size
	var uv_end := cell.end / texture_size
	var surface := []
	surface.resize(Mesh.ARRAY_MAX)
	surface[Mesh.ARRAY_VERTEX] = PackedVector2Array(
		[Vector2.ZERO, Vector2(size.x, 0), size, Vector2(0, size.y)]
	)
	surface[Mesh.ARRAY_TEX_UV] = PackedVector2Array(
		[uv_first, Vector2(uv_end.x, uv_first.y), uv_end, Vector2(uv_first.x, uv_end.y)]
	)
	surface[Mesh.ARRAY_INDEX] = PackedInt32Array([0, 1, 2, 0, 2, 3])
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, surface)
	return mesh
