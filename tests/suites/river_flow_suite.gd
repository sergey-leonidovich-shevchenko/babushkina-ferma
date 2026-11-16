extends "res://tests/suites/suite_base.gd"

const WaterMapRegistry := preload("res://scripts/systems/water_map_registry.gd")
const WaterSurface := preload("res://scripts/presentation/village_water_surface.gd")
const RiverFlow := preload("res://scripts/presentation/village_river_flow.gd")


## Проверяет локальные профили и непрерывное течение на сетке первой локации.
func run() -> void:
	test_surface_quality_and_wrapped_phase_are_local()
	test_river_atlas_matches_straights_and_bends()


## Сценарий: независимые поверхности меняют профиль и фазу одного материала.
## Исходное состояние: два владельца ожидают один шейдер, но имеют разные часы.
## Результат: low оставляет широкую рябь, обёртка совпадает, static возвращает прежний draw.
func test_surface_quality_and_wrapped_phase_are_local() -> void:
	var primary := WaterSurface.new()
	var secondary := WaterSurface.new()
	primary.apply_profile("normal", 1.25)
	secondary.apply_profile("low", 2.5)
	var normal := primary.material as ShaderMaterial
	var low := secondary.material as ShaderMaterial
	var river_layer := primary.get_node("RiverCurrent") as Node2D
	var low_river_layer := secondary.get_node("RiverCurrent") as Node2D
	var river := river_layer.material as ShaderMaterial
	var low_river := low_river_layer.material as ShaderMaterial
	expect(
		(
			normal != low
			and normal.shader == low.shader
			and normal.shader == WaterSurface.SurfaceShader
		),
		"water shares shader source without sharing owner uniforms",
	)
	var normal_fine: bool = normal.get_shader_parameter("fine_ripples")
	var low_fine: bool = low.get_shader_parameter("fine_ripples")
	expect(normal_fine and not low_fine, "low quality removes only the fine ripple branch")
	var river_directed: bool = river.get_shader_parameter("directed")
	var low_directed: bool = low_river.get_shader_parameter("directed")
	var pond_directed: bool = normal.get_shader_parameter("directed") == true
	var low_river_fine: bool = low_river.get_shader_parameter("fine_ripples")
	var normal_atlas: Variant = river.get_shader_parameter("flow_coordinates")
	var low_atlas: Variant = low_river.get_shader_parameter("flow_coordinates")
	var atlas_shared: bool = normal_atlas is Texture2D and normal_atlas == low_atlas
	expect(
		(
			river_directed
			and low_directed
			and not pond_directed
			and not low_river_fine
			and atlas_shared
		),
		"both river profiles share a cached flow atlas; the pond retains standing ripples",
	)
	var phase: Vector2 = normal.get_shader_parameter("ripple_offset")
	var travel: float = river.get_shader_parameter("flow_phase")
	primary.apply_profile("normal", 1.25 + WaterSurface.LOOP_SECONDS)
	var wrapped_phase: Vector2 = normal.get_shader_parameter("ripple_offset")
	expect(
		phase == wrapped_phase and primary.material == normal,
		"water phase wraps to exactly the same value without replacing the material",
	)
	var wrapped_travel: float = river.get_shader_parameter("flow_phase")
	expect(travel == wrapped_travel, "downstream travel wraps without a phase jump")
	primary.apply_profile("normal", 1.25, false)
	var comparison_directed: bool = river.get_shader_parameter("directed")
	expect(
		not comparison_directed and primary.material == normal,
		"the diagnostic control retains the previous animation with the same materials",
	)
	primary.apply_profile("static", 2.5)
	expect(
		primary.material == null and river_layer.material == null and secondary.material == low,
		"static uses the old surface",
	)
	primary.apply_profile("normal", INF)
	expect(primary.material == null, "non-finite water phase leaves the previous surface usable")
	primary.apply_profile("low", 2.5)
	expect(primary.material == normal, "switching qualities reuses one material per water owner")
	primary.free()
	secondary.free()


## Сценарий: атлас читается вдоль пяти прямых и связывает обе стороны четырёх изгибов.
## Исходное состояние: русло собрано из того же маршрута, что и физическая вода.
## Результат: оси совпадают с топологией, на стыке координаты сохраняются.
func test_river_atlas_matches_straights_and_bends() -> void:
	var field := RiverFlow.field()
	var bounds: Vector4 = field.bounds
	var texture: ImageTexture = field.texture
	var image := texture.get_image()
	var topology := WaterMapRegistry.geometry("overworld")
	var samples: Array[Vector2] = [
		Vector2(300, 284),
		Vector2(580, 372),
		Vector2(756, 452),
		Vector2(1036, 700),
		Vector2(1180, 956)
	]
	for point in samples:
		var axis := Vector2(topology.flow_at(point))
		var normal := Vector2(-axis.y, axis.x)
		var start := _flow_texel(image, bounds, point)
		var down := _flow_texel(image, bounds, point + axis * 8.0) - start
		var across := _flow_texel(image, bounds, point + normal * 8.0) - start
		expect(
			down == Vector2(8, 0) and across == Vector2(0, 8),
			"packed river flow follows the actual cardinal axis at %s" % point,
		)
	var reaches := RiverFlow._reaches()
	for index in range(1, reaches.size(), 2):
		var turn := reaches[index]
		var before := reaches[index - 1]
		var after := reaches[index + 1]
		for radius: float in [24.0, 48.0, 72.0]:
			var entry := turn.origin - turn.outgoing * radius
			var exit := turn.origin + turn.direction * radius
			expect(
				(
					before.coordinates(entry).is_equal_approx(turn.coordinates(entry))
					and after.coordinates(exit).is_equal_approx(turn.coordinates(exit))
					and turn.coordinates(exit).x > turn.coordinates(entry).x
				),
				"river bend %d is continuous across entry and exit at radius %d" % [index, radius],
			)


## Распаковывает байты полного GPU-атласа по тем же формулам, что и шейдер.
func _flow_texel(image: Image, bounds: Vector4, point: Vector2) -> Vector2:
	var cell := Vector2i((point - Vector2(bounds.x, bounds.y)) / RiverFlow.STEP)
	var pixel := image.get_pixelv(cell)
	return (
		Vector2(pixel.r8 * 256 + pixel.g8, pixel.b8 * 256 + pixel.a8) / RiverFlow.PRECISION
		- Vector2(RiverFlow.STEP, RiverFlow.CROSS_ORIGIN)
	)
