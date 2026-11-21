extends "res://tools/qa/world/render_order_game.gd"

const WorldSpace := preload("res://scripts/systems/world_projection_system.gd")
const Renderer := preload("res://scripts/systems/render_system.gd")
const Probe := preload("res://tools/qa/world/lighting/light_probe.gd")
var light_calls: Array[Dictionary] = []
var observe_lights := false
var hud_only := false
var measure_draw := false
var draw_microseconds: Array[int] = []


## Замер не включает snapshot-проверки; обычный draw по-прежнему вызывает production-оркестратор.
func _draw() -> void:
	light_calls.clear()
	var start := Time.get_ticks_usec() if measure_draw else 0
	if hud_only:
		draw_set_transform(Vector2.ZERO)
		Renderer.draw_screen(self, false)
	else:
		super._draw()
	if measure_draw:
		draw_microseconds.append(Time.get_ticks_usec() - start)


## Записывает фактический вызов и его координаты отдельно для каждого игрового canvas.
func record_light_call(owner: String, bounds: Rect2) -> void:
	if not observe_lights:
		return
	var a := bounds.position
	var b := bounds.end
	if owner == "window-ray":
		a = WorldSpace.world_to_screen(self, a)
		b = WorldSpace.world_to_screen(self, b)
	var stretch := get_viewport().get_stretch_transform()
	a = stretch * a
	b = stretch * b
	light_calls.append(
		{
			"owner": owner,
			"rect": [a.x, a.y, b.x - a.x, b.y - a.y],
			"viewport": get_viewport().get_instance_id(),
			"off": Probe.is_off(self)
		}
	)
