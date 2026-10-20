extends "res://tests/test_game.gd"

## Выполняет существующие положительные и отрицательные WATER сценарии в отдельном профиле.
func _initialize() -> void:
	ProjectSettings.set_setting("application/config/use_custom_user_dir",true)
	ProjectSettings.set_setting("application/config/custom_user_dir_name","Codex-VSHORE-001-Tests")
	for suite in [preload("res://tests/suites/water_topology_suite.gd"),preload("res://tests/suites/water_navigation_suite.gd"),preload("res://tests/suites/water_fishing_suite.gd"),preload("res://tests/suites/water_visual_suite.gd")]: suite.new(self).run()
	print("SHORE WATER TESTS: %d passed, %d failed"%[passed,failed])
	quit(0 if failed==0 else 1)
