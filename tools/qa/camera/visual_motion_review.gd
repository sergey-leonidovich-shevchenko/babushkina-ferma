extends SceneTree

var passed := 0
var failed := 0

## Выполняет профильный сценарий в отдельном пользовательском каталоге только для тестов.
func _initialize() -> void:
	ProjectSettings.set_setting("application/config/use_custom_user_dir",true)
	ProjectSettings.set_setting("application/config/custom_user_dir_name","Codex-VBASE-005-Tests")
	preload("res://tests/suites/visual_motion_suite.gd").run(self)
	print("MOTION TESTS: %d passed, %d failed"%[passed,failed]); quit(0 if failed==0 else 1)

## Сохраняет точное условие отказа, не выдавая headless за нативную приёмку.
func expect(condition: bool, label: String) -> void:
	if condition: passed+=1
	else: failed+=1; push_error(label)
