extends SceneTree

var passed := 0
var failed := 0

## Запускает профиль в отдельном каталоге и не выдаёт логические проверки за нативную графику.
func _initialize() -> void:
	ProjectSettings.set_setting("application/config/use_custom_user_dir",true)
	ProjectSettings.set_setting("application/config/custom_user_dir_name","Codex-VGROUND-007-review-"+str(Time.get_ticks_usec()))
	preload("res://tests/suites/garden_soil_suite.gd").run(self)
	print("GARDEN SOIL: ",passed," passed, ",failed," failed")
	quit(0 if failed==0 else 1)

## Фиксирует результат утверждения и понятное имя нарушенного условия.
func expect(condition: bool, label: String) -> void:
	if condition: passed+=1
	else: failed+=1; print("FAIL: ",label)
