extends SceneTree

var passed := 0
var failed := 0

## Запускает профиль в отдельном каталоге пользователя, не выдавая headless за визуальную приёмку.
func _initialize() -> void:
	ProjectSettings.set_setting("application/config/use_custom_user_dir",true)
	ProjectSettings.set_setting("application/config/custom_user_dir_name","Codex-VGROUND-001-review-"+str(Time.get_ticks_usec()))
	preload("res://tests/suites/meadow_ground_suite.gd").run(self)
	print("MEADOW: ",passed," passed, ",failed," failed")
	quit(0 if failed==0 else 1)

## Сохраняет отказ каждой проверки.
func expect(condition: bool, label: String) -> void:
	if condition: passed+=1
	else: failed+=1; print("FAIL: ",label)
