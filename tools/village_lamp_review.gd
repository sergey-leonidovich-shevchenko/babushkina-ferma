extends SceneTree
var passed:=0
var failed:=0

## Проверяет фонари и отдельное свечение в отдельном профиле без обычных сохранений пользователя.
func _initialize() -> void:
	ProjectSettings.set_setting("application/config/use_custom_user_dir",true)
	ProjectSettings.set_setting("application/config/custom_user_dir_name","Codex-VPROP-004-review-"+str(Time.get_ticks_usec()))
	preload("res://tests/suites/village_lamp_suite.gd").run(self)
	print("LAMP REVIEW: ",passed," passed, ",failed," failed");quit(0 if failed==0 else 1)

## Записывает точное имя нарушенного условия вместо оптимистичного общего результата.
func expect(condition:bool,label:String) -> void:
	if condition:passed+=1
	else:failed+=1;print("FAIL: ",label)
