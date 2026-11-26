extends RefCounted

const UV := preload("res://scripts/presentation/foliage_uv.gd")
const Roots := preload("res://scripts/presentation/foliage_root_profile.gd")
const ShaderSource := preload("res://scripts/presentation/foliage_wind.gdshader")
const SLOT := 96
const PAD := 12
const COLUMNS := 4
const CAPACITY := 64
const AMPLITUDE := 1.35
const PLANT_SIZE := 72.0
const FILTER_MARGIN := 2

static var _coverage_atlas: WeakRef
static var _coverage_cache: Dictionary[Rect2i, Rect2i] = {}


## Вычисляет пространственную фазу из мировой опоры, не трогая игровой или глобальный RNG.
static func phase(anchor: Vector2) -> float:
	return fposmod(anchor.x * 0.017 + anchor.y * 0.031, TAU)


## Даёт независимый CPU-эталон горизонтального изгиба без вертикального сдвига.
static func bend(seconds: float, anchor: Vector2) -> Vector2:
	if not is_finite(seconds) or not anchor.is_finite():
		return Vector2.ZERO
	var value := phase(anchor)
	return Vector2(
		AMPLITUDE * (0.78 * sin(seconds * 0.95 + value) + 0.22 * sin(seconds * 1.61 + value * 1.7)),
		0
	)


## Оставляет в слоте запас под изгиб. Соседние слоты не соприкасаются.
static func slot(index: int) -> Rect2:
	return Rect2(Vector2(index % COLUMNS, index / COLUMNS) * SLOT, Vector2.ONE * SLOT)


## Создаёт максимум одну группу на вид, с общей геометрией и отдельной фазой каждого экземпляра.
static func build(
	rows: Array, atlas: Texture2D, scale: int, trim_padding: bool = false
) -> Dictionary:
	if rows.is_empty() or rows.size() > CAPACITY or atlas == null or scale < 1 or scale > 4:
		return {}
	var viewport := SubViewport.new()
	viewport.name = "WindAtlas"
	viewport.disable_3d = true
	viewport.transparent_bg = true
	viewport.size = Vector2i(COLUMNS * SLOT, ceili(float(rows.size()) / COLUMNS) * SLOT) * scale
	viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	var groups: Dictionary[String, Array] = {}
	var nodes: Array[MultiMeshInstance2D] = []
	var content: Dictionary[String, Rect2] = {}
	var cache: Dictionary[Rect2i, Rect2i] = {}
	if trim_padding:
		cache = _atlas_coverage(atlas)
	var atlas_image: Image
	for index in rows.size():
		var row: Dictionary = rows[index]
		var kind: String = row.kind
		if not groups.has(kind):
			groups[kind] = []
		groups[kind].append(index)
	for kind in groups:
		var profile := Roots.profile(kind)
		if profile.is_empty() or profile.flexible != true:
			viewport.free()
			return {}
		var indices: Array = groups[kind]
		var multi := MultiMesh.new()
		multi.transform_format = MultiMesh.TRANSFORM_2D
		multi.use_custom_data = true
		var first_row: Dictionary = rows[indices[0]]
		var region: Rect2 = first_row.source
		var source_size: Vector2i = profile.size
		var root: Vector2i = profile.root
		var lock_y: int = profile.lock_y
		var top: int = profile.top
		var bounds := Rect2i()
		if trim_padding:
			var source := Rect2i(region)
			if cache.has(source):
				bounds = cache[source]
			else:
				if atlas_image == null:
					atlas_image = atlas.get_image()
				bounds = source_content(atlas_image, source)
				if cache.size() < CAPACITY:
					cache[source] = bounds
		var mesh_data := UV.mesh_data(kind, PLANT_SIZE / source_size.x)
		if bounds.has_area():
			# На сетке 1× исходные треугольники и композит камыша сохраняют байты мягкой альфы.
			if scale > 1:
				_trim_mesh_width(mesh_data, bounds)
			if scale > 1 or kind != "reeds":
				content[kind] = composite_rect(bounds, region.size)
		multi.mesh = UV.make_mesh(mesh_data)
		multi.instance_count = indices.size()
		for instance in indices.size():
			var index: int = indices[instance]
			var row: Dictionary = rows[index]
			var anchor: Vector2 = row.anchor
			var origin := (
				slot(index).position
				+ Vector2.ONE * PAD
				+ Vector2(root) * PLANT_SIZE / Vector2(source_size)
			)
			multi.set_instance_transform_2d(
				instance, Transform2D(0, Vector2.ONE * scale, 0, origin * scale)
			)
			multi.set_instance_custom_data(instance, Color(phase(anchor), index, 0, 0))
		var material := ShaderMaterial.new()
		material.shader = ShaderSource
		material.set_shader_parameter("source_atlas", atlas)
		material.set_shader_parameter("atlas_size", atlas.get_size())
		material.set_shader_parameter(
			"source_rect",
			Vector4(region.position.x, region.position.y, region.size.x, region.size.y)
		)
		material.set_shader_parameter("lock_v", float(lock_y) / source_size.y)
		material.set_shader_parameter("top_v", float(top) / source_size.y)
		var node := MultiMeshInstance2D.new()
		node.name = String(kind)
		node.multimesh = multi
		node.material = material
		viewport.add_child(node)
		nodes.append(node)
	return {
		"viewport": viewport,
		"groups": nodes,
		"scale": scale,
		"rows": rows,
		"trim_padding": trim_padding,
		"content": content
	}


## Импортированная текстура неизменна между сменами масштаба. У нового атласа свой кеш.
static func _atlas_coverage(atlas: Texture2D) -> Dictionary[Rect2i, Rect2i]:
	if not atlas is CompressedTexture2D:
		var empty: Dictionary[Rect2i, Rect2i] = {}
		return empty
	if _coverage_atlas == null or _coverage_atlas.get_ref() != atlas:
		_coverage_atlas = weakref(atlas)
		_coverage_cache.clear()
	return _coverage_cache


## Сохраняет все непрозрачные тексели и ещё два для фильтра, даже у мягкой полупрозрачной кромки.
static func source_content(atlas: Image, source: Rect2i) -> Rect2i:
	if atlas == null or atlas.is_empty() or atlas.is_compressed():
		return Rect2i()
	if not Rect2i(Vector2i.ZERO, atlas.get_size()).encloses(source):
		return Rect2i()
	var used := atlas.get_region(source).get_used_rect()
	if not used.has_area():
		return Rect2i()
	return used.grow(FILTER_MARGIN).intersection(Rect2i(Vector2i.ZERO, source.size))


## Меняет только X у сетки ветра: узлы по Y и вес изгиба остаются там же.
static func _trim_mesh_width(data: Dictionary, bounds: Rect2i) -> void:
	var arrays: Array = data.arrays
	var vertices: PackedVector2Array = arrays[Mesh.ARRAY_VERTEX]
	var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
	var source: Vector2i = data.size
	var left := float(bounds.position.x) / source.x
	var right := float(bounds.end.x) / source.x
	var root: Vector2 = data.root
	var scale: float = data.scale
	for index in vertices.size():
		var x := lerpf(left, right, uvs[index].x)
		uvs[index].x = x
		vertices[index].x = (x * source.x - root.x) * scale
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_TEX_UV] = uvs


## Номинальная опора и сетка семплирования слота сохраняются. Границы кратны мировому пикселю.
static func composite_rect(bounds: Rect2i, source_size: Vector2) -> Rect2:
	var scale := Vector2.ONE * PLANT_SIZE / source_size
	var crop := Rect2(
		Vector2.ONE * PAD + Vector2(bounds.position) * scale, Vector2(bounds.size) * scale
	)
	# Включает полный изгиб и запас для билинейной выборки двух проходов.
	crop = crop.grow(UV.MAX_BEND + FILTER_MARGIN)
	var first := crop.position.floor()
	return Rect2(first, crop.end.ceil() - first).intersection(
		Rect2(Vector2.ZERO, Vector2.ONE * SLOT)
	)


## Проецирует область слота в исходный прямоугольник растения и сохраняет опору.
static func world_destination(plant: Rect2, crop: Rect2) -> Rect2:
	var full := plant.grow(PAD)
	var scale := full.size / SLOT
	return Rect2(full.position + crop.position * scale, crop.size * scale)
