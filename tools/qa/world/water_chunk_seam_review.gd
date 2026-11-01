extends SceneTree

const GameScript := preload("res://scripts/game.gd")

var passed := 0
var failed := 0


## Проверяет топологию, навигацию, рыбалку и визуальный стык в отдельном профиле.
func _initialize() -> void:
	ProjectSettings.set_setting("application/config/use_custom_user_dir", true)
	(
		ProjectSettings
		. set_setting(
			"application/config/custom_user_dir_name",
			"Codex-VSHORE-004-Tests-" + str(Time.get_ticks_usec()),
		)
	)
	var suites: Array[GDScript] = [
		preload("res://tests/suites/water_topology_suite.gd"),
		preload("res://tests/suites/water_navigation_suite.gd"),
		preload("res://tests/suites/water_fishing_suite.gd"),
		preload("res://tests/suites/water_visual_suite.gd"),
	]
	for suite: GDScript in suites:
		var instance: Object = suite.new(self)
		instance.call("run")
	print("WATER CHUNK SEAM: %d passed, %d failed" % [passed, failed])
	quit(0 if failed == 0 else 1)


## Создаёт минимальный игровой контекст без чтения обычных пользовательских данных.
func make_game() -> Node:
	var game := GameScript.new()
	game._ready()
	game.LocaleSystem.set_locale("ru")
	game.language_screen = false
	game.title_screen = false
	return game


## Считает результат тем же контрактом, который используют штатные suites.
func expect(condition: bool, label: String) -> void:
	if condition:
		passed += 1
		print("PASS: ", label)
	else:
		failed += 1
		push_error("FAIL: " + label)
