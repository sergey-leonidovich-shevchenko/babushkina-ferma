extends SceneTree

var passed := 0
var failed := 0


## Выполняет профильные сценарии только в уже проверенном отдельном userdata.
func _initialize() -> void:
	if not OS.get_user_data_dir().get_file().begins_with("Codex-VWEATHER-001-"):
		quit(2)
		return
	_run.call_deferred()


## Готовый SceneTree позволяет проверить настоящий producer с входом в дерево.
func _run() -> void:
	preload("res://tests/suites/weather_visual_clock_suite.gd").run(self)
	print("WEATHER CLOCK REVIEW: ", passed, " passed, ", failed, " failed")
	quit(0 if failed == 0 else 1)


## Записывает точный отказ вместо оптимистичного общего счётчика.
func expect(condition: bool, label: String) -> void:
	if condition:
		passed += 1
	else:
		failed += 1
		print("FAIL: ", label)
