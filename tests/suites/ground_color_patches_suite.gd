extends RefCounted

const Patches := preload("res://scripts/presentation/ground_color_patches.gd")
const Meadow := preload("res://scripts/presentation/meadow_ground.gd")
const MapData := preload("res://scripts/systems/village_map_data.gd")
const Terrain := preload("res://scripts/systems/village_terrain_renderer.gd")
const Points := preload("res://tools/qa/camera/visual_camera_points.gd")
const Farm := preload("res://scripts/systems/world_farming_system.gd")
const GameScript := preload("res://scripts/game.gd")
const BackgroundScript := preload("res://scripts/world_background.gd")


## Проверяет детерминизм, биомные различия, крупный масштаб и отсутствие влияния на правила мира.
static func run(context: SceneTree) -> void:
	var locations: Array[String] = [
		"overworld",
		"village_market",
		"village_garden",
		"village_river",
		"village_workyard",
		"village_orchard"
	]
	var biomes: Array[String] = []
	for location: String in locations:
		var biome := MapData.ground_biome(location)
		biomes.append(biome)
		context.call(
			&"expect",
			Patches.PROFILES.has(biome),
			"first-village location has a registered ground biome: %s" % location
		)
	context.call(
		&"expect",
		biomes.size() == locations.size() and _unique(biomes).size() == biomes.size(),
		"six first-village maps keep six independently seeded colour profiles"
	)

	var points: Array[Vector2] = [
		Vector2.ZERO, Vector2(192, 192), Vector2(768, 384), Vector2(1536, 960), Vector2(2399, 1199)
	]
	for biome: String in biomes:
		var first: Array[Color] = []
		var second: Array[Color] = []
		for point: Vector2 in points:
			first.append(Patches.color_at(point, biome))
			second.append(Patches.color_at(point, biome))
		context.call(&"expect", first == second, "biome colour field is deterministic: %s" % biome)
		context.call(
			&"expect",
			first.all(_bounded),
			"biome modulation stays inside the reviewed subtle range: %s" % biome
		)
	context.call(
		&"expect",
		_signatures(biomes, points).size() == biomes.size(),
		"biome seeds and palettes produce distinct sampled fields"
	)

	var previous := Patches.color_at(Vector2.ZERO, MapData.ground_biome("overworld"))
	var maximum_step := 0.0
	var minimum_channel := 2.0
	var maximum_channel := -1.0
	for x in range(48, 2401, 48):
		var color := Patches.color_at(Vector2(x, 576), MapData.ground_biome("overworld"))
		maximum_step = maxf(maximum_step, _distance(previous, color))
		minimum_channel = minf(minimum_channel, minf(color.r, minf(color.g, color.b)))
		maximum_channel = maxf(maximum_channel, maxf(color.r, maxf(color.g, color.b)))
		previous = color
	context.call(
		&"expect",
		maximum_step < 0.09,
		"48px samples blend smoothly without ruler-straight colour jumps: %.4f" % maximum_step
	)
	context.call(
		&"expect",
		maximum_channel - minimum_channel > 0.08,
		"world-scale field retains visible large colour variation"
	)

	var size := Vector2(2400, 1368)
	var patched := Meadow.mesh(size, MapData.ground_biome("overworld"), true)
	var plain := Meadow.mesh(size, MapData.ground_biome("overworld"), false)
	var arrays: Array = patched.surface_get_arrays(0)
	var plain_arrays: Array = plain.surface_get_arrays(0)
	var vertices: PackedVector2Array = arrays[Mesh.ARRAY_VERTEX]
	var colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
	var plain_colors: PackedColorArray = plain_arrays[Mesh.ARRAY_COLOR]
	context.call(
		&"expect",
		(
			patched == Meadow.mesh(size, MapData.ground_biome("overworld"), true)
			and patched.get_surface_count() == 1
		),
		"one retained mesh owns all colour patches for the map"
	)
	context.call(
		&"expect",
		colors.size() == vertices.size() and _all_white(plain_colors),
		"patches use vertex colours and the rollback mesh stays neutral"
	)
	context.call(
		&"expect",
		_shared_vertices_match(arrays),
		"duplicated tile-edge vertices receive exactly the same colour"
	)
	context.call(
		&"expect",
		Meadow.mesh(size, MapData.ground_biome("village_river"), true) != patched,
		"a different biome owns a separate retained mesh without per-cell nodes"
	)

	var seasonal: Array[Color] = []
	for season: String in ["spring", "summer", "autumn", "winter"]:
		seasonal.append(
			(
				Patches.color_at(Vector2(864, 672), MapData.ground_biome("overworld"))
				* Terrain.ground_tint(season, "clear")
			)
		)
	context.call(
		&"expect",
		_unique(seasonal).size() == 4,
		"the same deterministic patch remains season-responsive"
	)

	var game: GameScript = Points.create_game() as GameScript
	game._ready()
	var camera_point: Dictionary = Points.registry().points[0]
	Points.configure(game, camera_point)
	var background: BackgroundScript = game.get_node("WorldBackground") as BackgroundScript
	background._ready()
	var before := _rules(game)
	var saved: Dictionary = game.SaveSystem.snapshot(game)
	background.set_ground_color_patches(false)
	context.call(
		&"expect",
		not background.ground_color_patches and before == _rules(game),
		"neutral rollback preserves walkability and tillability"
	)
	background.set_ground_color_patches(true)
	context.call(
		&"expect",
		background.ground_color_patches and before == _rules(game),
		"colour patches preserve walkability and tillability"
	)
	context.call(
		&"expect",
		saved == game.SaveSystem.snapshot(game),
		"colour-patch toggle never enters the save schema"
	)
	game.free()


## Возвращает множество точных сигнатур без зависимости от порядка словаря.
static func _signatures(biomes: Array[String], points: Array) -> Dictionary:
	var result := {}
	for biome: String in biomes:
		var values := PackedFloat32Array()
		for point: Vector2 in points:
			var color := Patches.color_at(point, biome)
			values.append_array(PackedFloat32Array([color.r, color.g, color.b]))
		result[str(values)] = true
	return result


## Оставляет только уникальные значения для точных детерминированных проверок.
static func _unique(values: Array) -> Dictionary:
	var result := {}
	for value: Variant in values:
		result[value] = true
	return result


## Ограничивает модуляцию, чтобы пятна не спорили с дорожками, домами и персонажами.
static func _bounded(color: Color) -> bool:
	return (
		color.a == 1.0
		and color.r >= 0.65
		and color.r <= 1.13
		and color.g >= 0.84
		and color.g <= 1.12
		and color.b >= 0.59
		and color.b <= 1.05
	)


## Проверяет нейтральный rollback без недоступных Array-методов packed-контейнера.
static func _all_white(colors: PackedColorArray) -> bool:
	for color: Color in colors:
		if color != Color.WHITE:
			return false
	return true


## Измеряет максимальное поканальное изменение между соседними выборками.
static func _distance(first: Color, second: Color) -> float:
	return maxf(absf(first.r - second.r), maxf(absf(first.g - second.g), absf(first.b - second.b)))


## Проверяет, что цвет общей точки не зависит от ячейки, которая добавила вершину в mesh.
static func _shared_vertices_match(arrays: Array) -> bool:
	var seen := {}
	var vertices: PackedVector2Array = arrays[Mesh.ARRAY_VERTEX]
	var colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
	for index in vertices.size():
		var key := vertices[index]
		if seen.has(key) and seen[key] != colors[index]:
			return false
		seen[key] = colors[index]
	return true


## Читает настоящую навигацию и всю фермерскую сетку независимо от визуальной сетки.
static func _rules(game: GameScript) -> Array:
	var result := []
	for y in range(120, 1320, 48):
		for x in range(48, 2352, 48):
			var point := Vector2(x, y)
			result.append(
				[
					game.NavigationSystem.walkability_reason(game, point),
					Farm.tillability_reason(game, "overworld", Farm.cell_at(point))
				]
			)
	return result
