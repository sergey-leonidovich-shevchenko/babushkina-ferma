extends SceneTree

const Points := preload("res://tools/qa/camera/visual_camera_points.gd")
const Observer := preload("res://tools/qa/world/shadows/readability_game.gd")
const Cases := preload("res://tools/qa/world/shadows/readability_cases.gd")
var output := ""
var profile := ""
var variant := ""
var size := Vector2i(1152, 648)
var game: Observer
var frames: Dictionary = {}
var failures: Array[String] = []


## Отказывается от headless, чужого профиля и существующего вывода до создания игры.
func _initialize() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--output="):
			output = argument.trim_prefix("--output=")
		elif argument.begins_with("--profile="):
			profile = argument.trim_prefix("--profile=")
		elif argument.begins_with("--variant="):
			variant = argument.trim_prefix("--variant=")
		elif argument == "--wide":
			size = Vector2i(1280, 720)
	if (
		not output.is_absolute_path()
		or DirAccess.dir_exists_absolute(output)
		or FileAccess.file_exists(output)
		or not profile.begins_with("Codex-VSHADOW-010-")
		or not profile.is_valid_filename()
		or DisplayServer.get_name() == "headless"
		or variant not in ["production", "on", "off", "no-loot"]
	):
		quit(2)
		return
	if OS.get_cmdline_user_args().has("--without-contacts") != (variant == "off"):
		quit(2)
		return
	ProjectSettings.set_setting("application/config/use_custom_user_dir", true)
	ProjectSettings.set_setting("application/config/custom_user_dir_name", profile)
	if (
		OS.get_user_data_dir().get_file() != profile
		or FileAccess.file_exists("user://farm-settings.cfg")
	):
		quit(2)
		return
	_start.call_deferred()


## Все варианты снимают ту же production-сцену; меняются только контролируемые контакты/добыча.
func _start() -> void:
	print("SHADOW STAGE: create game")
	if DirAccess.make_dir_recursive_absolute(output) != OK:
		quit(2)
		return
	var scene := Points.create_game()
	scene.set_script(Observer)
	game = scene as Observer
	# set_script создаёт новый state; seed нужен до production bootstrap в add_child.
	game.world_loot_seed = Points.SEED
	root.add_child(game)
	current_scene = game
	Points.configure(game, Cases.first_point())
	# Статичный QA ждёт каждый present; production idle может пропустить неизменённый кадр.
	OS.low_processor_usage_mode = false
	print("SHADOW STAGE: game configured")
	var loot_sources := Cases.save_loot_sources(game, output)
	if loot_sources.size() != Cases.ITEMS.size():
		quit(2)
		return
	root.title = "VSHADOW-010 | " + variant
	for attempt: int in 3:
		root.mode = Window.MODE_WINDOWED
		root.size = size
		root.show()
		root.grab_focus()
		await _settle(900)
		print("SHADOW STAGE: window settled ", attempt)
	for group: String in Cases.GROUPS:
		for minutes: int in [720, 1140]:
			var loot := Cases.configure(game, group, minutes, variant == "no-loot")
			await _capture(group + "-" + str(minutes), loot)
	var file := FileAccess.open(output.path_join("capture.json"), FileAccess.WRITE)
	if file == null:
		quit(2)
		return
	file.store_string(
		(
			JSON.stringify(
				{
					"schema": 1,
					"task": "VSHADOW-010",
					"variant": variant,
					"profile": profile,
					"user_dir": OS.get_user_data_dir(),
					"engine": Engine.get_version_info().string,
					"display": DisplayServer.get_name(),
					"renderer": RenderingServer.get_current_rendering_method(),
					"performance_eligible": false,
					"low_processor_usage_mode": OS.low_processor_usage_mode,
					"user_arguments": OS.get_cmdline_user_args(),
					"loot_sources": loot_sources,
					"frames": frames,
					"failures": failures
				},
				"\t"
			)
			+ "\n"
		)
	)
	print("SHADOW READABILITY NATIVE: ", frames.size(), " frames, ", failures)
	quit(0 if failures.is_empty() else 2)


## Ждёт отложенный draw после process_frame и читает только завершённый framebuffer.
func _redraw(count: int) -> void:
	for index: int in count:
		game.queue_redraw()
		await process_frame
		await RenderingServer.frame_post_draw


## Сохраняет обе стороны state-проверки и фактические области контактов/лутовых иконок.
func _capture(id: String, loot: Array[Dictionary]) -> void:
	DisplayServer.window_move_to_foreground()
	root.grab_focus()
	await _redraw(4)
	game.draw_records.clear()
	game.observe_draw = true
	var before: Dictionary = game.SaveSystem.snapshot(game)
	await _redraw(2)
	game.observe_draw = false
	var after: Dictionary = game.SaveSystem.snapshot(game)
	var image := root.get_texture().get_image()
	var snapshot := Points.snapshot(game, {"id": id})
	var bloom := false
	for environment_node: WorldEnvironment in root.find_children(
		"*", "WorldEnvironment", true, false
	):
		bloom = (
			bloom
			or (environment_node.environment != null and environment_node.environment.glow_enabled)
		)
	var valid: bool = (
		image != null
		and before == after
		and game.draw_records.size() == 2
		and root.visible
		and DisplayServer.window_get_size() == size
		and not bloom
		and snapshot.walkable == "walkable"
	)
	for record: Dictionary in game.draw_records:
		valid = valid and record.equal and record.geometry_equal
	if not valid:
		failures.append(id + ": window/state/callback/bloom/walkability failed: " + str(snapshot))
		return
	if image.save_png(output.path_join(id + ".png")) != OK:
		failures.append(id + ": PNG write failed")
		return
	print("SHADOW FRAME: ", id)
	frames[id] = {
		"snapshot": snapshot,
		"size": Points.pair(image.get_size()),
		"window": Points.pair(DisplayServer.window_get_size()),
		"focused": DisplayServer.window_is_focused(),
		"visible": root.visible,
		"bloom": bloom,
		"before": before,
		"after": after,
		"draws": game.draw_records.duplicate(true),
		"contacts": game.contacts(),
		"loot": loot
	}


## Размещение окна не продвигает остановленную симуляцию и не считается FPS-прогоном.
func _settle(milliseconds: int) -> void:
	DisplayServer.window_move_to_foreground()
	root.grab_focus()
	var deadline := Time.get_ticks_msec() + milliseconds
	while Time.get_ticks_msec() < deadline:
		game.queue_redraw()
		await process_frame
