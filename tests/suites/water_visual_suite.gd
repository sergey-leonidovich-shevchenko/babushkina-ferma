extends "res://tests/suites/suite_base.gd"

const VillageLayoutSystem := preload("res://scripts/systems/village_layout_system.gd")
const WaterLayoutData := preload("res://scripts/systems/water_layout_data.gd")
const WaterMapRegistry := preload("res://scripts/systems/water_map_registry.gd")
const WaterVisualSystem := preload("res://scripts/systems/water_visual_system.gd")
const UnderwaterBottom := preload("res://scripts/presentation/underwater_bottom.gd")
const Terrain := preload("res://scripts/systems/village_terrain_renderer.gd")


## Запускает все сценарии водного визуального контракта в фиксированном порядке.
func run() -> void:
	preload("res://tests/suites/water_chunk_seam_suite.gd").new(context).run()
	test_water_catalog_animation_and_navigation_share_the_24px_grid()
	test_registry_visual_snapshots_cover_all_water_semantics()
	test_underwater_bottom_is_visual_only_and_retained()


## Сценарий: вода, берега, рыба и всплески используют один визуальный профиль.
## Исходное состояние: есть поверхность, берега, углы, русло и CC0-эффекты.
## Результат: тайлы 24 px, маски разрешаются, а сетка совпадает с навигацией.
func test_water_catalog_animation_and_navigation_share_the_24px_grid() -> void:
	expect(
		(
			WaterVisualSystem.SURFACE_KINDS.size() == 6
			and WaterVisualSystem.SHORE_KINDS.size() == 6
			and WaterVisualSystem.RIVER_KINDS.size() == 6
			and WaterVisualSystem.MODULES.size() == 19
		),
		"water catalog owns six surfaces six shores six river modules and an isolated pond"
	)
	for kind: String in WaterVisualSystem.MODULES:
		var texture: Texture2D = WaterVisualSystem.texture(kind)
		var image: Image = texture.get_image()
		expect(
			(
				texture.get_size() == Vector2(24, 24)
				and image.get_pixel(0, 0).a > 0.99
				and image.get_pixel(23, 23).a > 0.99
			),
			"%s is an opaque crop-safe 24 px water module" % kind
		)
	for mask in 16:
		var variant: Dictionary = WaterVisualSystem.variant_for_mask(
			mask, Vector2i(7, 11), mask % 4
		)
		var kind: String = variant.kind
		var rotation: float = variant.rotation
		expect(
			WaterVisualSystem.MODULES.has(kind) and fmod(absf(rotation), PI * 0.5) < 0.001,
			"water neighbor mask %d resolves to a registered quarter-turn module" % mask
		)
	for missing_diagonal in 4:
		var variant: Dictionary = WaterVisualSystem.variant_for_mask(
			15, Vector2i(7, 11), 0, 15 & ~(1 << missing_diagonal)
		)
		var kind: String = variant.kind
		var rotation: float = variant.rotation
		var rotations: Array[float] = [0.0, PI * 0.5, PI, -PI * 0.5]
		expect(
			kind == "shore_inner_corner" and is_equal_approx(rotation, rotations[missing_diagonal]),
			"missing diagonal %d resolves to the matching concave shoreline" % missing_diagonal
		)
	for frame in 4:
		expect(
			(
				String(WaterVisualSystem.surface_kind(Vector2i(7, 0), frame))
				in WaterVisualSystem.SURFACE_KINDS
			),
			"animated surface frame %d stays inside the native water catalog" % frame
		)
	var cells := WaterVisualSystem.first_location_cells(VillageLayoutSystem, "spring")
	var mismatches: Array = []
	for row in range(VillageLayoutSystem.OVERWORLD_TILE_COUNT.y):
		for col in range(VillageLayoutSystem.OVERWORLD_TILE_COUNT.x):
			var cell := Vector2i(col, row)
			var center := VillageLayoutSystem.tile_center(cell)
			if cells.has(cell) != WaterMapRegistry.has_surface("overworld", center):
				mismatches.append(cell)
	expect(
		cells.size() > 250 and mismatches.is_empty(),
		"visible modular water cells and physical surface share one 24 px authority"
	)
	for bridge: Rect2 in VillageLayoutSystem.BRIDGES:
		var center_cell := Vector2i(Vector2(bridge.get_center()) / 24.0)
		expect(
			cells.has(center_cell) and not VillageLayoutSystem.is_water(bridge.get_center(), 0.0),
			"bridge center keeps the canonical water surface beneath the independent deck"
		)
	var effect_kinds: Array[String] = ["fish", "splash", "bubbles"]
	for effect_kind: String in effect_kinds:
		var effect: Dictionary = WaterVisualSystem.effect_profile(effect_kind)
		var source: Vector2 = effect.source_size
		var content: Vector2 = effect.content_size
		var frame_count: int = effect.frames
		var last := WaterVisualSystem.effect_source_rect(effect_kind, frame_count - 1)
		var sheet: Texture2D = WaterVisualSystem.EFFECT_SHEETS[effect_kind]
		expect(
			(
				fmod(content.x, source.x) == 0.0
				and fmod(content.y, source.y) == 0.0
				and last.end.x <= sheet.get_width()
			),
			"%s keeps integer pixel scale and crop-safe final frame" % effect_kind
		)
	var fish_profile: Dictionary = WaterVisualSystem.effect_profile("fish")
	var splash_profile: Dictionary = WaterVisualSystem.effect_profile("splash")
	var fish_size: Vector2 = fish_profile.visual_size
	var splash_size: Vector2 = splash_profile.visual_size
	expect(
		fish_size == Vector2(48, 48) and splash_size == Vector2(72, 72),
		"fish uses 48 px and splash uses the agreed 72 px modular frame"
	)
	var renderer_source := FileAccess.get_file_as_string("res://scripts/game_renderer.gd")
	var editor_source := FileAccess.get_file_as_string(
		"res://scripts/systems/level_editor_validation_system.gd"
	)
	expect(
		(
			renderer_source.contains("WaterVisualSystem.draw_first_location_animations")
			and not renderer_source.contains("FISH_ANIMATION")
		),
		"world animation delegates water effects instead of owning sprite dimensions"
	)
	expect(
		(
			editor_source.contains("WaterVisualSystem.variant_for_mask")
			and editor_source.contains("WaterVisualSystem.module_path")
		),
		"level editor consumes the same water topology and module catalog as runtime"
	)
	var preview := Image.load_from_file(
		ProjectSettings.globalize_path(
			"res://assets/generated/level_drafts/water_navigation_ingame_preview.png"
		)
	)
	expect(
		preview != null and preview.get_size() == Vector2i(1152, 648),
		"water migration keeps a current F10 gameplay preview for visible contour and bridge review"
	)


## Сценарий: все встроенные водные карты отдают визуальную маску через тот же ограниченный реестр.
## Исходное состояние: блокирующие реки и озеро, декоративный пруд и морской фон.
## Результат: каждый профиль содержит покрытие и метаданные, а сухая карта остаётся пустой.
func test_registry_visual_snapshots_cover_all_water_semantics() -> void:
	for location: String in WaterLayoutData.PROFILE_KINDS:
		var snapshot: Dictionary = WaterMapRegistry.visual(location)
		var regions: Array = snapshot.regions
		var polygons: Array = snapshot.polygons
		expect(
			not regions.is_empty() and not polygons.is_empty(),
			"registry publishes canonical visual coverage for " + location,
		)
		for region: Dictionary in regions:
			var depth: float = region.depth
			var bank: String = region.bank
			expect(
				depth >= 0.0 and depth <= 1.0 and bank in ["earth", "stone", "cave"],
				"registry keeps valid depth and bank metadata for " + location,
			)
	var moon_snapshot: Dictionary = WaterMapRegistry.visual("moon_glade")
	var moon_regions: Array = moon_snapshot.regions
	var moon: Dictionary = moon_regions[0]
	var moon_kind: String = moon.kind
	var moon_blocking: bool = moon.blocking
	expect(
		moon_kind == "decorative" and not moon_blocking,
		"decorative water keeps visual coverage without inheriting blocking physics",
	)
	var dry_snapshot: Dictionary = WaterMapRegistry.visual("forest")
	var dry_polygons: Array = dry_snapshot.polygons
	expect(
		dry_polygons.is_empty(),
		"unknown dry location does not manufacture a visual water mask",
	)
	var left_chunk: Dictionary = WaterMapRegistry.visual_chunk("overworld", Vector2i.ZERO)
	var right_chunk: Dictionary = WaterMapRegistry.visual_chunk("overworld", Vector2i.RIGHT)
	var left_masks: Dictionary = left_chunk.neighbor_masks
	var right_masks: Dictionary = right_chunk.neighbor_masks
	var left_edges: Dictionary = left_chunk.filled_edges
	var right_edges: Dictionary = right_chunk.filled_edges
	var left_east_mask: int = left_masks[Vector2i(15, 10)]
	var right_west_mask: int = right_masks[Vector2i(16, 10)]
	var left_east_filled: int = left_edges.east
	var right_west_filled: int = right_edges.west
	expect(
		(
			(left_east_mask & 2) != 0
			and (right_west_mask & 8) != 0
			and left_east_filled > 0
			and right_west_filled > 0
		),
		"overworld registry preserves the real river across its 16-cell chunk boundary",
	)


## Сценарий: живописное дно повторяется под прежними контурами реки и пруда.
## Исходное состояние: мастер 1254px, прозрачная поверхность и прежняя геометрия.
## Результат: UV бесшовны, mesh кешируется, а физический профиль не меняется.
func test_underwater_bottom_is_visual_only_and_retained() -> void:
	var profile := WaterVisualSystem.bottom_profile()
	var source_size: Vector2 = profile.source_size
	var world_cell: Vector2 = profile.world_cell
	var physical_authority: bool = profile.physical_authority
	var draw_calls_per_geometry: int = profile.draw_calls_per_geometry
	expect(
		(
			source_size == Vector2(1254, 1254)
			and world_cell == Vector2(768, 768)
			and not physical_authority
			and draw_calls_per_geometry == 1
		),
		"underwater profile declares one retained visual draw and no physical authority",
	)
	expect(
		(
			UnderwaterBottom.SOURCE.get_image().has_mipmaps()
			and (
				UnderwaterBottom.texture().texture_filter
				== CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
			)
			and UnderwaterBottom.texture().texture_repeat == CanvasItem.TEXTURE_REPEAT_DISABLED
		),
		"riverbed owns a filtered mipmapped sampler without leaking repeat state",
	)
	var horizontal := true
	var vertical := true
	for y in 4:
		for x in 4:
			for step in 9:
				var edge := Vector2(x + 1, y + float(step) / 8.0) * UnderwaterBottom.CELL
				if (
					UnderwaterBottom.uv_at(edge, Vector2i(x, y))
					!= UnderwaterBottom.uv_at(edge, Vector2i(x + 1, y))
				):
					horizontal = false
				edge = Vector2(x + float(step) / 8.0, y + 1) * UnderwaterBottom.CELL
				if (
					UnderwaterBottom.uv_at(edge, Vector2i(x, y))
					!= UnderwaterBottom.uv_at(edge, Vector2i(x, y + 1))
				):
					vertical = false
	expect(
		horizontal and vertical,
		"all sampled riverbed seams read the same source edge through mirrored UV cells",
	)
	var polygons: Array[PackedVector2Array] = Terrain.surface_polygons(true)
	expect(
		polygons.size() == 1,
		"river and pond merge into one render-only polygon without double alpha at their overlap",
	)
	var mesh := UnderwaterBottom.mesh(polygons, &"water-suite-clipped")
	var vertices := UnderwaterBottom.vertex_count(polygons, &"water-suite-clipped")
	expect(
		(
			mesh == UnderwaterBottom.mesh(polygons, &"water-suite-clipped")
			and mesh.get_surface_count() == 1
			and vertices > 20
			and vertices < 500
		),
		"clipped river and pond reuse one bounded mesh instead of per-cell nodes or per-frame geometry",
	)
	expect(
		(
			FileAccess.get_sha256(
				"res://assets/game/locations/overworld/modular/riverbed_material_v1.png"
			)
			== FileAccess.get_sha256(
				"res://docs/reports/visual-overhaul/vshore-002/masters/riverbed-master-v1.png"
			)
		),
		"runtime riverbed remains a byte-exact copy of the selected external master",
	)
	var spring := Terrain.water_surface_tint("spring")
	var rain := Terrain.water_surface_tint("spring", "rain")
	var shallow := Terrain.water_depth_tint(spring, 0.2)
	var deep := Terrain.water_depth_tint(spring, 0.8)
	expect(
		(
			spring.a > 0.5
			and spring.a < 0.65
			and shallow != deep
			and shallow.a < deep.a
			and rain.a == spring.a
			and rain.get_luminance() < spring.get_luminance()
		),
		"water stays translucent enough for the bottom while rain only darkens its color",
	)
	var layer_source := FileAccess.get_file_as_string(
		"res://scripts/presentation/village_ground_layer.gd"
	)
	expect(
		layer_source.find("draw_underwater_bottom") < layer_source.find("draw_surface"),
		"split terrain draws the bottom before the surface and keeps bridges in the cover pass",
	)
