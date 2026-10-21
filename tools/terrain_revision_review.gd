extends SceneTree

var passed := 0
var failed := 0

## Проверяет локальные ревизии отдельно от обычного пользовательского каталога.
func _initialize() -> void:
	ProjectSettings.set_setting("application/config/use_custom_user_dir",true)
	ProjectSettings.set_setting("application/config/custom_user_dir_name","Codex-VGROUND-009-review-"+str(Time.get_ticks_usec()))
	preload("res://tests/suites/terrain_revision_suite.gd").run(self)
	print("TERRAIN REVISION: ",passed," passed, ",failed," failed")
	quit(0 if failed==0 else 1)

## Записывает утверждения с понятным нарушенным условием.
func expect(condition: bool, label: String) -> void:
	if condition: passed+=1
	else: failed+=1; print("FAIL: ",label)
