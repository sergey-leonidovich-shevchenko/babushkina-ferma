extends RefCounted

const Points := preload("res://tools/qa/camera/visual_camera_points.gd")
const Existing := preload("res://tools/qa/world/lighting/inventory_cases.gd")
const Fixture := preload("res://tools/qa/world/lighting/daycycle/game.gd")
const Reference := preload("res://scripts/presentation/visual_reference_mode.gd")
const Save := preload("res://scripts/systems/save_system.gd")
const Context := preload("res://scripts/presentation/viewport_world_context.gd")
const LEGACY := &"daylight_palette_legacy"
const CASES: Array[Dictionary] = [
	{"id": "street-dawn", "room": "west-lamp", "minutes": 360.0},
	{"id": "street-day", "room": "west-lamp", "minutes": 720.0},
	{"id": "street-dusk", "room": "west-lamp", "minutes": 1140.0},
	{"id": "street-night", "room": "west-lamp", "minutes": 1320.0},
	{"id": "home-dawn", "room": "home", "minutes": 360.0},
	{"id": "home-day", "room": "home", "minutes": 720.0},
	{"id": "home-dusk", "room": "home", "minutes": 1140.0},
	{"id": "home-night", "room": "home", "minutes": 1320.0},
	{"id": "market-dusk", "room": "west-lamp", "minutes": 1140.0},
	{"id": "eclipse-night", "room": "west-lamp", "minutes": 1320.0},
]


## Подменяет лишь наблюдателя; seed и настоящая main-сцена одинаковы в двух Git-экспортах.
static func create(parent: Node) -> Fixture:
	var scene := Points.create_game()
	scene.set_script(Fixture)
	var game := scene as Fixture
	game.world_loot_seed = Points.SEED
	parent.add_child(game)
	return game


## Тип сохраняется и в baseline: условное выражение Godot теряет Array[String].
static func capture_modes(baseline: bool) -> Array[String]:
	var result: Array[String] = ["palette"]
	if not baseline:
		result.append("legacy")
		result.append("reference")
	return result


## Существующая угроза перенесена только внутри QA fixture к фиксированной камере первой карты.
static func configure(game: Fixture, entry: Dictionary) -> void:
	var room: String = entry.room
	var minutes: float = entry.minutes
	Existing.configure(game, room, int(minutes))
	game.game_minutes = minutes
	game.settings_state.vsync_enabled = false
	game.hazard_nodes = (
		preload("res://scripts/systems/environment_hazard_system.gd").default_hazards()
	)
	if entry.id == "market-dusk":
		game.current_location = "village_market"
		game.sync_background_location()
		game.sync_background_environment()
		game.update_camera()
	if entry.id == "eclipse-night":
		game.day = 5
		game.state.world.weather_day = 5
		game.state.world.weather = "clear"
	var original: Dictionary = game.hazard_nodes[3]
	var threat := original.duplicate(true)
	threat.location = game.current_location
	threat.position = game.player + Vector2(140, 0)
	threat.target = game.player
	threat.windup = 0.2
	threat.cooldown = 2.1
	threat.pulse = 0.0
	game.hazard_nodes.append(threat)
	mode(game, "palette")


## Reference mode — существующее выключение эффектов; legacy — только палитра одного canvas.
static func mode(game: Fixture, value: String) -> void:
	Reference.disable(game)
	game.set_meta(LEGACY, value == "legacy")
	if value == "reference":
		Reference.enable(game)
	game.bad_hud = false
	game.hidden_target = ""
	game.hud_only = false
	var background := game.get_node("WorldBackground") as CanvasItem
	background.visible = true


## Сохраняет полный save, реальную геометрию и идентификаторы владельцев отдельно от имён файлов.
static func state(game: Fixture) -> Dictionary:
	return {
		"save": Save.snapshot(game),
		"geometry": Existing.snapshot(game, "daycycle"),
		"owner": Context.read(game),
		"legacy": game.get_meta(LEGACY, false),
		"reference": Reference.active(game),
	}


## Применяет настоящее оконное преобразование к логической области; учитывает крайние пиксели.
static func pixel_rect(bounds: Rect2, stretch: Transform2D) -> Array[int]:
	var native := stretch * bounds
	var left := floori(native.position.x)
	var top := floori(native.position.y)
	return [left, top, ceili(native.end.x) - left, ceili(native.end.y) - top]


## Вызывает завершённый production draw без синхронного чтения изображения.
static func redraw(tree: SceneTree, game: Fixture, count: int = 3) -> void:
	for index: int in count:
		game.queue_redraw()
		await tree.process_frame
		await RenderingServer.frame_post_draw


## Три чередующихся повтора отделяют CPU submission от software frame-интервалов.
static func measure(tree: SceneTree, game: Fixture) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	configure(game, CASES[2])
	for repeat: int in 3:
		var modes: Array[String] = ["palette", "legacy", "reference"]
		if repeat == 1:
			modes.reverse()
		elif repeat == 2:
			modes = ["legacy", "reference", "palette"]
		for value: String in modes:
			mode(game, value)
			await redraw(tree, game, 20)
			var before := state(game)
			game.draw_microseconds.clear()
			game.measure_draw = true
			var intervals: Array[int] = []
			var observations: Array[Dictionary] = []
			var previous := Time.get_ticks_usec()
			for index: int in 60:
				await redraw(tree, game, 1)
				var now := Time.get_ticks_usec()
				intervals.append(now - previous)
				var window := DisplayServer.window_get_size()
				(
					observations
					. append(
						{
							"tick_us": now,
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
						"mode": value,
						"repeat": repeat,
						"warmup": 20,
						"before": before,
						"after": state(game),
						"draw_us": game.draw_microseconds.duplicate(),
						"frame_us": intervals,
						"observations": observations,
						"engine_max_fps": Engine.max_fps,
						"vsync": DisplayServer.window_get_vsync_mode(),
					}
				)
			)
	return result
