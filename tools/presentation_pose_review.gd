extends SceneTree
var passed := 0
var failed := 0

## Проверяет общий отображаемый кадр в отдельном профиле, без нативных или FPS-заявлений.
func _initialize() -> void:
	ProjectSettings.set_setting("application/config/use_custom_user_dir",true)
	ProjectSettings.set_setting("application/config/custom_user_dir_name","Codex-VCAMERA-003-Tests")
	preload("res://tests/suites/presentation_pose_suite.gd").run(self)
	print("POSE TESTS: %d passed, %d failed"%[passed,failed])
	quit(0 if failed==0 and passed>=544 else 1)

## Записывает конкретное условие и сохраняет все отказы профиля.
func expect(condition: bool, label: String) -> void:
	if condition: passed+=1
	else: failed+=1; push_error(label)
