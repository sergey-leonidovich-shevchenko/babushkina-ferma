extends RefCounted

const Cases := preload("res://tools/qa/world/lighting/quality/cases.gd")
const Fixture := preload("res://tools/qa/world/lighting/quality/game.gd")


## Чередует три повтора; CPU draw отделён от frame-интервала и синхронного readback.
static func capture(tree: SceneTree, game: Fixture, baseline: bool) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	Cases.configure(game, Cases.ENTRIES[2])
	for repeat: int in 3:
		var modes := Cases.modes(baseline)
		if repeat == 1:
			modes.reverse()
		elif repeat == 2 and not baseline:
			modes = ["low", "off", "standard"]
		for selected: String in modes:
			Cases.mode(game, selected, baseline)
			await Cases.redraw(tree, game, 20)
			var before := Cases.state(game, baseline)
			game.draw_microseconds.clear()
			game.measure_draw = true
			var observations: Array[Dictionary] = []
			var started := Time.get_ticks_usec()
			var previous := started
			for index: int in 60:
				await Cases.redraw(tree, game, 1)
				var now := Time.get_ticks_usec()
				var window := DisplayServer.window_get_size()
				(
					observations
					. append(
						{
							"tick_us": now,
							"frame_us": now - previous,
							"process_frame": Engine.get_process_frames(),
							"window": [window.x, window.y],
							"visible": tree.root.visible,
							"focused": DisplayServer.window_is_focused(),
							"engine_max_fps": Engine.max_fps,
							"vsync": DisplayServer.window_get_vsync_mode(),
						}
					)
				)
				previous = now
			game.measure_draw = false
			(
				result
				. append(
					{
						"mode": selected,
						"repeat": repeat,
						"before": before,
						"after": Cases.state(game, baseline),
						"warmup": 20,
						"start_tick_us": started,
						"draw_us": game.draw_microseconds.duplicate(),
						"observations": observations,
					}
				)
			)
	return result
