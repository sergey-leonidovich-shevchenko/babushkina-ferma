extends SceneTree

var passed := 0
var failed := 0


## Создаёт отдельный QA-профиль; обычные сохранения пользователя не открываются.
func _initialize() -> void:
	ProjectSettings.set_setting("application/config/use_custom_user_dir", true)
	ProjectSettings.set_setting("application/config/custom_user_dir_name", "Codex-VFOLIAGE-010-review-" + str(Time.get_ticks_usec()))
	_run.call_deferred()


## Выполняет настоящий suite и печатает выбранные детерминированные маршруты для нативного плана.
func _run() -> void:
	preload("res://tests/suites/foliage_visibility_suite.gd").run(self)
	var review := preload("res://tests/helpers/foliage_visibility_scenario.gd")
	var game := review.Scenario.create(self)
	print("ROUTES: ", JSON.stringify(review.pack(review.routes(game))))
	game.free()
	print("FOLIAGE VISIBILITY REVIEW: ", passed, " passed, ", failed, " failed")
	quit(0 if failed == 0 else 1)


## Сохраняет предметный отказ без подмены итогового результата.
func expect(condition: bool, label: String) -> void:
	if condition: passed += 1
	else:
		failed += 1
		print("FAIL: ", label)
