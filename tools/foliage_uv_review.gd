extends SceneTree

var passed:=0
var failed:=0

## Проверяет CPU-контракт UV и документирование в свежем профиле; headless не принимает shader на GPU.
func _initialize()->void:
	ProjectSettings.set_setting("application/config/use_custom_user_dir",true);ProjectSettings.set_setting("application/config/custom_user_dir_name","Codex-VFOLIAGE-002-review-"+str(Time.get_ticks_usec()))
	preload("res://tests/suites/foliage_uv_suite.gd").run(self)
	preload("res://tests/suites/architecture_suite.gd").test_all_methods_have_russian_documentation(self)
	print("FOLIAGE UV REVIEW: ",passed," passed, ",failed," failed");quit(0 if failed==0 else 1)

## Считает настоящие условия и выводит нарушения без фиктивной GPU-приёмки.
func expect(value:bool,label:String)->void:
	if value:passed+=1
	else:failed+=1;print("FAIL: ",label)
