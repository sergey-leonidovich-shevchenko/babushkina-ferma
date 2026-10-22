extends SceneTree

var passed:=0
var failed:=0

## Запускает корневые паспорта и совместимость в отдельном каталоге без пользовательского слота.
func _initialize()->void:
	ProjectSettings.set_setting("application/config/use_custom_user_dir",true)
	ProjectSettings.set_setting("application/config/custom_user_dir_name","Codex-VFOLIAGE-001-review-"+str(Time.get_ticks_usec()))
	preload("res://tests/suites/foliage_root_suite.gd").run(self)
	preload("res://tests/suites/architecture_suite.gd").test_all_methods_have_russian_documentation(self)
	print("FOLIAGE ROOT REVIEW: ",passed," passed, ",failed," failed");quit(0 if failed==0 else 1)

## Считает фактические утверждения и печатает только нарушения.
func expect(value:bool,label:String)->void:
	if value:passed+=1
	else:failed+=1;print("FAIL: ",label)
