extends SceneTree

var passed := 0
var failed := 0


## Подготавливает новый QA-профиль без чтения игровых слотов пользователя.
func _initialize() -> void:
	ProjectSettings.set_setting("application/config/use_custom_user_dir", true)
	ProjectSettings.set_setting("application/config/custom_user_dir_name", "Codex-VFOLIAGE-009-review-" + str(Time.get_ticks_usec()))
	_run.call_deferred()


## Проверяет существующую runtime-политику до любых production-изменений.
func _run() -> void:
	preload("res://tests/suites/foliage_pause_suite.gd").run(self)
	print("FOLIAGE PAUSE REVIEW: ", passed, " passed, ", failed, " failed")
	quit(0 if failed == 0 else 1)


## Сохраняет конкретные отказы и честный общий результат профиля.
func expect(condition: bool, label: String) -> void:
	if condition:
		passed += 1
	else:
		failed += 1
		print("FAIL: ", label)
