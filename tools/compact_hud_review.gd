extends SceneTree

const GAME_SCENE := preload("res://main.tscn")
const VILLAGE := preload("res://scripts/systems/village_map_data.gd")
const INVENTORY_STATE := preload("res://scripts/state/inventory_state.gd")
const OUTPUT := "res://assets/generated/ui/compact_hud"
const REPORT_PATH := "res://docs/reports/compact_hud_review.json"
const PROFILES := [
	{"id":"16x9", "size":Vector2i(1152, 648)},
	{"id":"16x10", "size":Vector2i(1280, 800)},
	{"id":"ultrawide", "size":Vector2i(1680, 720)},
]
const USER_FILES := ["user://farm-save.json", "user://farm-save-2.json", "user://farm-save-3.json", "user://farm-settings.cfg"]

var game: Node2D
var checks: Array[Dictionary] = []
var screenshots: Array[Dictionary] = []
var fingerprints: Dictionary = {}
var letterbox: Node2D


class ReviewGame extends "res://scripts/game.gd":
	## Отключает только автоматический bootstrap, способный мигрировать настройки и потребить запрос новой игры.
	func _ready() -> void:
		pass


class LetterboxMask extends Node2D:
	var extent := Vector2.ZERO
	var content := Rect2()

	## Закрывает внеигровые поля физического canvas так же, как настоящий оконный режим KEEP.
	func _draw() -> void:
		var color := Color("0b1512")
		for rect in [Rect2(0, 0, extent.x, content.position.y), Rect2(0, content.end.y, extent.x, extent.y-content.end.y), Rect2(0, content.position.y, content.position.x, content.size.y), Rect2(content.end.x, content.position.y, extent.x-content.end.x, content.size.y)]:
			if rect.has_area(): draw_rect(rect, color)


## Дожидается готовности настоящего native-окна; headless не выдаётся за визуальную проверку.
func _initialize() -> void:
	_run.call_deferred()


## Снимает матрицу реальных GPU-кадров, проверяет ввод и завершается только в своём экземпляре Godot.
func _run() -> void:
	var prepare_only := "--prepare-only" in OS.get_cmdline_user_args()
	if DisplayServer.get_name() == "headless" and not prepare_only:
		push_error("COMPACT HUD: используйте native renderer без --headless")
		quit(2)
		return
	fingerprints = _user_fingerprints()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	_bootstrap_without_user_writes()
	if prepare_only:
		_review_controls()
		var failed := checks.filter(func(check): return not bool(check.ok)).size()
		print("COMPACT HUD HARNESS READY: ", checks.size() - failed, " passed, ", failed, " failed; files unchanged=", fingerprints == _user_fingerprints())
		quit(0 if failed == 0 and fingerprints == _user_fingerprints() else 1)
		return
	root.mode = Window.MODE_WINDOWED
	await create_timer(0.4).timeout
	_review_controls()
	for profile in PROFILES:
		for locale in game.LocaleSystem.LOCALES:
			game.LocaleSystem.set_locale(locale, false)
			for scenario in ["normal", "stress", "inventory"]:
				_configure_scenario(scenario)
				await _capture(profile, String(locale), scenario)
	for path in USER_FILES:
		_check(_user_fingerprints()[path] == fingerprints[path], "Файл пользователя не изменён", {"path":path})
	_finish()


## Инициализирует штатные ресурсы и мир main.tscn без чтения/сохранения пользовательской игры или миграции настроек.
func _bootstrap_without_user_writes() -> void:
	seed(20260909)
	game = GAME_SCENE.instantiate()
	game.set_script(ReviewGame)
	game.world_loot_seed = 20260909
	game.audio_enabled = false
	# До добавления в дерево production-сервисы не вызывают Settings.load и не запускают аудио.
	game.GameBootstrap._initialize_services(game)
	game.GameBootstrap._initialize_world(game)
	game.GameBootstrap._initialize_runtime_systems(game)
	root.add_child(game)
	current_scene = game
	game.set_process(false)
	game.set_physics_process(false)
	game.language_screen = false
	game.title_screen = false
	game.settings_state.fullscreen_enabled = false
	game.settings_state.screen_shake_enabled = false
	game.settings_state.text_scale = 1.2
	game.InputSystem.apply_control_preset("standard")
	game.current_location = "overworld"
	game.player = VILLAGE.START
	game.facing = Vector2.DOWN
	game.day = 5
	game.game_minutes = 386
	game.state.world.weather_day = 5
	game.state.world.weather = "clear"
	game.state.world.estate.event = ""
	game.FarmLifeSystem.state(game).cutscene = ""
	game.FarmLifeSystem.state(game).first_day = 6
	game.discovery_current = {}
	game.message = ""
	game.hud_message_timer = 0.0
	game.update_camera()
	game.sync_background_location()
	game.sync_background_environment()
	game.get_node("WorldBackground").position = -game.camera_offset
	var masks := CanvasLayer.new()
	masks.layer = 127
	root.add_child(masks)
	letterbox = LetterboxMask.new()
	masks.add_child(letterbox)
	_check(game.LocaleSystem.LOCALES == ["ru", "en", "es", "de", "fr", "zh"], "Матрица использует все шесть реально поддерживаемых языков")


## Проверяет центры десяти слотов мышью/тачем и закрытие рюкзака настоящим маршрутизатором сцены.
func _review_controls() -> void:
	for index in 10:
		var rect: Rect2 = game.InterfaceRenderer.hotbar_rect(index)
		var click := InputEventMouseButton.new()
		click.button_index = MOUSE_BUTTON_LEFT
		click.pressed = true
		click.position = rect.get_center()
		game._input(click)
		_check(game.selected_hotbar == index, "Клик по видимому быстрому слоту выбирает его", {"slot":index})
		var touch := InputEventScreenTouch.new()
		touch.position = rect.get_center()
		touch.pressed = true
		game._input(touch)
		_check(game.selected_hotbar == index, "Тач по видимому быстрому слоту выбирает его", {"slot":index})
		if index > 0:
			var previous: Rect2 = game.InterfaceRenderer.hotbar_rect(index - 1)
			_check(not rect.intersects(previous), "Соседние быстрые слоты не пересекаются", {"slot":index})
	game.open_inventory()
	var close := InputEventMouseButton.new()
	close.button_index = MOUSE_BUTTON_LEFT
	close.pressed = true
	close.position = game.ItemWindowRenderer.close_button_rect(game).get_center()
	game._input(close)
	_check(not game.inventory_open, "Крестик рюкзака закрывает его после выбора быстрых предметов")
	game.touch_controls_visible = false


## Готовит обычные количества, предельные подписи и рюкзак, не изменяя данные за пределами QA-сцены.
func _configure_scenario(scenario: String) -> void:
	game.inventory_open = false
	game.state.inventory.counts = INVENTORY_STATE.INITIAL_COUNTS.duplicate(true)
	game.hotbar_slots = INVENTORY_STATE.DEFAULT_HOTBAR.duplicate()
	game.coins = 20
	game.skill_points = 0
	game.inventory_scroll_row = 0
	game.inventory_selected = 0
	game.state.inventory.set_count("seeds", 8)
	game.state.inventory.set_count("apple", 3)
	game.state.inventory.set_count("berries", 0)
	game.state.inventory.set_count("mushroom", 0)
	game.selected_hotbar = 2
	game.tutorial_visible = true
	game.energy = 11
	game.player_hp = 100
	game.day = 5
	game.game_minutes = 386
	game.touch_controls_visible = false
	if scenario in ["stress", "inventory"]:
		game.grant_tester_kit()
		game.state.inventory.set_count("seeds", 999)
		game.state.inventory.set_count("apple", 12345)
		game.state.inventory.set_count("berries", 1)
		game.state.inventory.set_count("mushroom", 999)
		game.selected_hotbar = 9
		game.energy = 3
		game.player_hp = 35
		game.day = 9999
		game.game_minutes = 1439
	if scenario == "inventory": game.open_inventory()
	game.message = ""
	game.hud_message_timer = 0.0
	game.queue_redraw()
	game.get_node("WorldBackground").queue_redraw()


## Снимает физический framebuffer каждого формата; здесь нет ресайза ранее сделанного PNG.
func _capture(profile: Dictionary, locale: String, scenario: String) -> void:
	var expected: Vector2i = profile.size
	var image: Image
	for attempt in 8:
		root.size = expected
		# KEEP root-texture исключает letterbox-поля; физический canvas сохраняет их и рисует сцену тем же единым масштабом.
		root.content_scale_size = expected
		root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
		root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
		var layout: Dictionary = game.UiScaleSystem.viewport_layout(Vector2(expected))
		var transform := Transform2D.IDENTITY.scaled(Vector2.ONE * float(layout.scale))
		transform.origin = layout.offset
		root.canvas_transform = transform
		letterbox.extent = Vector2(expected)
		letterbox.content = Rect2(layout.offset, layout.content_size)
		letterbox.queue_redraw()
		game.queue_redraw()
		await process_frame
		await process_frame
		await RenderingServer.frame_post_draw
		image = root.get_texture().get_image()
		if image.get_size() == expected: break
		await create_timer(0.2).timeout
	var label := "%s_%s_%s_120" % [profile.id, locale, scenario]
	var path := OUTPUT.path_join(label + ".png")
	var error := image.save_png(ProjectSettings.globalize_path(path))
	_check(error == OK and image.get_size() == expected, "Native framebuffer сохранён в ожидаемом размере", {"case":label,"actual":[image.get_width(), image.get_height()],"expected":[expected.x, expected.y]})
	screenshots.append({"case":label,"locale":locale,"scenario":scenario,"profile":profile.id,"text_scale":1.2,"path":path,"width":image.get_width(),"height":image.get_height(),"sha256":FileAccess.get_sha256(path)})
	print("COMPACT HUD CAPTURE: ", label, " size=", image.get_size())


## Записывает результат конкретной проверяемой предпосылки отдельно от субъективного визуального осмотра.
func _check(ok: bool, description: String, detail: Dictionary = {}) -> void:
	checks.append({"ok":ok,"description":description,"detail":detail})
	if not ok: push_error("COMPACT HUD: " + description + " " + str(detail))


## Считывает контрольные суммы без модификации трёх слотов и конфигурации пользователя.
func _user_fingerprints() -> Dictionary:
	var result := {}
	for path in USER_FILES:
		result[path] = FileAccess.get_sha256(path) if FileAccess.file_exists(path) else "absent"
	return result


## Сохраняет только QA-отчёт; число контрактов не называется покрытием кода.
func _finish() -> void:
	var failed := checks.filter(func(check): return not bool(check.ok)).size()
	var report := {"schema":1,"renderer":RenderingServer.get_current_rendering_method(),"source":"main.tscn; QA bootstrap omits settings migration and menu request consumption","image_pipeline":"Native GPU framebuffer at each physical size; UiScaleSystem keep-transform applied before drawing to preserve letterbox fields in capture; no PNG resizing","version":ProjectSettings.get_setting("application/config/version"),"locales":game.LocaleSystem.LOCALES,"text_scale":1.2,"captures":screenshots,"checks":checks,"passed":checks.size()-failed,"failed":failed,"user_files_unchanged":fingerprints==_user_fingerprints(),"visual_review":"Screenshots require independent visual inspection; assertions are not line coverage."}
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(REPORT_PATH.get_base_dir()))
	var output := FileAccess.open(REPORT_PATH, FileAccess.WRITE)
	if output == null:
		push_error("COMPACT HUD: нельзя сохранить отчёт")
		quit(3)
		return
	output.store_string(JSON.stringify(report, "  ") + "\n")
	output.close()
	print("COMPACT HUD REVIEW: ", checks.size()-failed, " passed, ", failed, " failed, ", screenshots.size(), " native captures")
	quit(0 if failed == 0 else 1)
