extends "res://tools/qa/ground/color_patch_capture.gd"

var view: SubViewport
var paint: Paint
var trace: Array[String] = []


class Paint:
	extends Node2D
	var revision := 0
	var trace: Array[String] = []

	## Записывает фактическую сборку команд перед заливкой контрольного слоя.
	func _draw() -> void:
		trace.append("draw:" + str(revision))
		draw_rect(Rect2(0, 0, 32, 32), Color.GREEN if revision == 0 else Color.RED)


## Разрешает пробу только в удалённом X11 с отдельным профилем и свежим выводом.
func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="):
			folder = arg.trim_prefix("--output=")
		elif arg.begins_with("--profile="):
			profile = arg.trim_prefix("--profile=")
		elif arg == "--wide":
			size = Vector2i(1280, 720)
	virtual_display = true
	if (
		OS.get_name() != "Linux"
		or OS.get_environment("CI") != "true"
		or DisplayServer.get_name() != "X11"
		or not folder.is_absolute_path()
		or DirAccess.dir_exists_absolute(folder)
		or not profile.begins_with("Codex-QA-06-")
		or "/" in profile
		or "\\" in profile
	):
		push_error("Remote X11, fresh output and isolated profile required")
		quit(2)
		return
	# GLES создаёт дерево кеша до _initialize. После смены user:// воспроизводим
	# только папки, чтобы запись новых шейдеров не обращалась к отсутствующему пути.
	var cache_directories := _cache_layout(ProjectSettings.globalize_path("user://shader_cache"))
	ProjectSettings.set_setting("application/config/use_custom_user_dir", true)
	ProjectSettings.set_setting("application/config/custom_user_dir_name", profile)
	for relative in cache_directories:
		var cache_path := OS.get_user_data_dir().path_join("shader_cache").path_join(relative)
		if DirAccess.make_dir_recursive_absolute(cache_path) != OK:
			push_error("Cannot create isolated shader cache directory")
			quit(2)
			return
	_start.call_deferred()


## Читает только структуру папок GLES; файлы кеша и данные пользователя не копируются.
func _cache_layout(path: String, prefix: String = "") -> Array[String]:
	var directories: Array[String] = [prefix]
	if not DirAccess.dir_exists_absolute(path):
		return directories
	for child in DirAccess.get_directories_at(path):
		directories.append_array(_cache_layout(path.path_join(child), prefix.path_join(child)))
	return directories


## Вызывает настоящий унаследованный helper на отложенной смене команд одноразового кеша.
func _start() -> void:
	if not OS.get_user_data_dir().ends_with(profile):
		push_error("Isolated profile was not applied")
		quit(2)
		return
	if DirAccess.make_dir_recursive_absolute(folder) != OK:
		quit(2)
		return
	# Без добавления игры в дерево не запускаются её _ready, сохранения и игровая сцена.
	game = GameScript.new()
	root.title = "QA-06 | deferred canvas redraw"
	root.mode = Window.MODE_WINDOWED
	root.size = size
	view = SubViewport.new()
	view.size = Vector2i(32, 32)
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(view)
	paint = Paint.new()
	paint.trace = trace
	view.add_child(paint)
	for index in 5:
		await RenderingServer.frame_post_draw
	var initial := view.get_texture().get_image().get_pixel(16, 16).to_html()
	if initial != "00ff00ff" or DisplayServer.window_get_size() != size:
		push_error("Native window or initial green cache was not established")
		game.free()
		quit(2)
		return
	view.render_target_update_mode = SubViewport.UPDATE_DISABLED
	trace.clear()
	# Подписка предшествует await внутри helper: новый draw ставится в ту же фазу process_frame.
	process_frame.connect(_request_revision, CONNECT_ONE_SHOT)
	await _redraw(1)
	var result := view.get_texture().get_image()
	var pixel := result.get_pixel(16, 16).to_html()
	trace.append("read:" + pixel)
	var code := 0 if pixel == "ff0000ff" and "draw:1" in trace else 1
	if result.save_png(folder.path_join("readback.png")) != OK:
		code = 2
	_write(
		"probe.json",
		{
			"schema": 1,
			"task": "QA-06",
			"initial": initial,
			"requested": "ff0000ff",
			"readback": pixel,
			"trace": trace,
			"window": Points.pair(DisplayServer.window_get_size()),
			"engine": Engine.get_version_info().string,
			"display": DisplayServer.get_name(),
			"profile": profile,
			"exit_code": code,
			"performance_eligible": false,
		}
	)
	game.free()
	quit(code)


## Меняет команды перед возобновлением helper, повторяя одноразовую сборку кеша грунта.
func _request_revision() -> void:
	trace.append("request:1")
	paint.revision = 1
	paint.queue_redraw()
	view.render_target_update_mode = SubViewport.UPDATE_ONCE
	RenderingServer.frame_post_draw.connect(_complete_revision, CONNECT_ONE_SHOT)


## Останавливает одноразовый кеш по тому же сигналу, который использует WorldBackground.
func _complete_revision() -> void:
	trace.append("complete")
	view.render_target_update_mode = SubViewport.UPDATE_DISABLED
