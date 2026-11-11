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
	print("VIEWPORT ISOLATION REVIEW: ", passed, " passed, ", failed, " failed")
	quit(0 if failed == 0 else 1)


## Записывает точное нарушенное условие вместо общего оптимистичного статуса.
func expect(condition: bool, label: String) -> void:
	if condition:
		passed += 1
	else:
		failed += 1
		print("FAIL: ", label)
