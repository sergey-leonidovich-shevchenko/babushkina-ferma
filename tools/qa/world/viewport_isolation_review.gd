# Review запускает сценарий через расширенный динамический тестовый SceneTree.
@warning_ignore_start(
	"untyped_declaration",
	"unsafe_call_argument",
	"unsafe_cast",
	"unsafe_method_access",
	"unsafe_property_access",
	"unsafe_void_return"
)
extends SceneTree

const Points := preload("res://tools/qa/camera/visual_camera_points.gd")
const Observer := preload("res://tools/qa/world/render_order_game.gd")

var passed := 0
var failed := 0


## Прогоняет контракт двух viewport в отдельном профиле без пользовательских сохранений.
func _initialize() -> void:
	ProjectSettings.set_setting("application/config/use_custom_user_dir", true)
	(
		ProjectSettings
		. set_setting(
			"application/config/custom_user_dir_name",
			"Codex-VRENDER-009-review-" + str(Time.get_ticks_usec()),
		)
	)
	_run.call_deferred()


## Запускает сцены после входа корневого окна в дерево, как штатный test runner.
func _run() -> void:
	preload("res://tests/suites/viewport_world_context_suite.gd").run(self)
	await _test_legacy_save_draw()
	print("VIEWPORT ISOLATION REVIEW: ", passed, " passed, ", failed, " failed")
	quit(0 if failed == 0 else 1)


## Загружает старый документ без fences и наблюдает первый настоящий production draw.
func _test_legacy_save_draw() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1152, 648)
	viewport.disable_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var game := Points.create_game()
	game.set_script(Observer)
	viewport.add_child(game)
	Points.configure(game, Points.registry().points[0])
	var document: Dictionary = game.SaveSystem.snapshot(game)
	document.estate.expansion.erase("fences")
	var applied: bool = game.SaveSystem.apply(game, document)
	var before: Dictionary = game.SaveSystem.snapshot(game)
	game.draw_records.clear()
	game.observe_draw = true
	game.queue_redraw()
	for iteration in 4:
		await process_frame
		if not game.draw_records.is_empty():
			break
	game.observe_draw = false
	var record: Dictionary = game.draw_records[0] if not game.draw_records.is_empty() else {}
	expect(
		(
			applied
			and before.estate.expansion.has("fences")
			and game.SaveSystem.snapshot(game) == before
			and record.get("equal", false)
		),
		"first production draw after a legacy save keeps the normalized full snapshot",
	)
	viewport.queue_free()


## Записывает точное нарушенное условие вместо общего оптимистичного статуса.
func expect(condition: bool, label: String) -> void:
	if condition:
		passed += 1
	else:
		failed += 1
		print("FAIL: ", label)
