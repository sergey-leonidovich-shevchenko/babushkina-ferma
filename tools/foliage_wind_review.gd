extends SceneTree
var passed:=0
var failed:=0
## Запускает профиль в свежем каталоге; headless принимает контракт, а не видимый shader или FPS.
func _initialize()->void:
	ProjectSettings.set_setting("application/config/use_custom_user_dir",true);ProjectSettings.set_setting("application/config/custom_user_dir_name","Codex-VFOLIAGE-003-review-"+str(Time.get_ticks_usec()))
	_run.call_deferred()
## Проверяет настоящий профиль и общую документацию методов после входа SceneTree.
func _run()->void:
	preload("res://tests/suites/foliage_wind_suite.gd").run(self)
	preload("res://tests/suites/architecture_suite.gd").test_all_methods_have_russian_documentation(self)
	print("FOLIAGE WIND REVIEW: ",passed," passed, ",failed," failed");quit(0 if failed==0 else 1)
## Считает реальные условия и выводит нарушения без подмены нативной приёмки.
func expect(value:bool,label:String)->void:
	if value:passed+=1
	else:failed+=1;print("FAIL: ",label)
