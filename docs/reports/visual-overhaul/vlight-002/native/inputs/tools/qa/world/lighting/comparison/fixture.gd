extends "res://tools/qa/world/lighting/inventory_game.gd"

const Lantern := preload("res://scripts/presentation/village_lamp_visual.gd")
const Layout := preload("res://scripts/systems/village_layout_system.gd")
const PropRenderer := preload("res://scripts/systems/village_prop_renderer.gd")
const Projector := preload("res://scripts/systems/world_projection_system.gd")
const LightProfile := preload("res://assets/game/locations/overworld/lamps/profile.json")

var mode := "off"
var ground := Vector2.ZERO
var local_light: PointLight2D
var blocker: LightOccluder2D
var radial: GradientTexture2D
var fixture_draws := 0


## Создаёт источник и текстуру один раз; режимы переключают параметры, а не ресурсы.
func install() -> void:
	set_meta("qa_lantern_comparison", true)
	radial = GradientTexture2D.new()
	radial.width = 256
	radial.height = 256
	radial.fill = GradientTexture2D.FILL_RADIAL
	radial.fill_from = Vector2(0.5, 0.5)
	radial.fill_to = Vector2(1.0, 0.5)
	var gradient := Gradient.new()
	var offsets := PackedFloat32Array()
	var colors := PackedColorArray()
	for index: int in LightProfile.data.glow.radii.size():
		var radius: float = LightProfile.data.glow.radii[index]
		offsets.append(radius / 32.0)
		var value: float = LightProfile.data.glow.alpha[index]
		colors.append(Color(value, value, value, 1.0))
	gradient.offsets = offsets
	gradient.colors = colors
	radial.gradient = gradient
	local_light = PointLight2D.new()
	local_light.texture = radial
	local_light.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	local_light.blend_mode = Light2D.BLEND_MODE_ADD
	local_light.color = Color(1.0, 0.77, 0.36)
	local_light.range_layer_min = 0
	local_light.range_layer_max = 0
	local_light.shadow_filter = Light2D.SHADOW_FILTER_PCF5
	local_light.shadow_filter_smooth = 1.0
	add_child(local_light)
	blocker = LightOccluder2D.new()
	var polygon := OccluderPolygon2D.new()
	# Явная QA-аппроксимация нижней стойки, не готовый production-контур предмета.
	polygon.polygon = PackedVector2Array(
		[Vector2(-2.0, 9.0), Vector2(2.0, 9.0), Vector2(2.0, 28.0), Vector2(-2.0, 28.0)]
	)
	blocker.occluder = polygon
	blocker.sdf_collision = false
	add_child(blocker)


## Сохраняет прежний центр стекла и радиус; в доме ставится тот же сухой QA-корпус.
func configure_light(next_mode: String) -> void:
	mode = next_mode
	ground = Vector2(646, 470)
	if current_location == "overworld":
		var found := false
		for placement: Dictionary in Layout.PROP_PLACEMENTS:
			var position: Vector2 = placement.position
			if placement.kind == "lamp" and position == Vector2(768, 552):
				ground = position + PropRenderer.GROUND_OFFSET
				found = true
				break
		if not found:
			push_error("comparison source lamp is missing")
	var zoom := Projector.zoom(self)
	var center := Projector.world_to_screen(self, Lantern.emitter(ground))
	local_light.position = center
	local_light.texture_scale = 64.0 * zoom / 256.0
	local_light.energy = Lantern.intensity(game_minutes)
	local_light.enabled = mode in ["local", "shadow"] and local_light.energy > 0.0
	local_light.shadow_enabled = mode == "shadow"
	blocker.position = center
	blocker.scale = Vector2.ONE * zoom
	blocker.visible = mode == "shadow"
	queue_redraw()


## Вызывает настоящую оркестрацию; измерение включает и маску, и добавленный корпус.
func _draw() -> void:
	var measuring := measure_draw
	measure_draw = false
	var started := Time.get_ticks_usec() if measuring else 0
	super._draw()
	if not hud_only and local_light != null:
		if current_location != "overworld":
			Projector.apply(self)
			Lantern.draw(self, ground)
		draw_set_transform(Vector2.ZERO)
		if mode == "mask":
			Lantern.draw_glow(
				self,
				Projector.world_to_screen(self, ground),
				Projector.zoom(self),
				WorldEventSystem.darkness(game_minutes)
			)
		fixture_draws += 1
	measure_draw = measuring
	if measuring:
		draw_microseconds.append(Time.get_ticks_usec() - started)


## Записывает фактические настройки и RID для проверки переиспользования и активного режима.
func light_state() -> Dictionary:
	return {
		"mode": mode,
		"ground": [ground.x, ground.y],
		"production_ground_offset": [PropRenderer.GROUND_OFFSET.x, PropRenderer.GROUND_OFFSET.y],
		"center": [local_light.position.x, local_light.position.y],
		"radius": 32.0 * Projector.zoom(self),
		"energy": local_light.energy,
		"enabled": local_light.enabled,
		"shadow_enabled": local_light.shadow_enabled,
		"shadow_filter": local_light.shadow_filter,
		"texture": [radial.width, radial.height],
		"texture_rid": radial.get_rid().get_id(),
		"texture_scale": local_light.texture_scale,
		"normal_maps_added": false,
		"production_materials_changed": false,
		"occluder": "QA stem rectangle, x[-2,2] y[9,28] relative to emitter",
		"hud_canvas_layer": 2,
		"light_canvas_layer_range": [0, 0]
	}
