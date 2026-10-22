extends SceneTree
var passed:=0
var failed:=0
## Запускает профиль после готовности дерева в отдельной папке без пользовательских слотов.
func _initialize()->void:
	ProjectSettings.set_setting("application/config/use_custom_user_dir",true);ProjectSettings.set_setting("application/config/custom_user_dir_name","Codex-VFOLIAGE-005-review-"+str(Time.get_ticks_usec()))
	_run.call_deferred()
## Проверяет реальную скорость, старый пространственный контакт и русские комментарии.
func _run()->void:
	preload("res://tests/suites/foliage_speed_suite.gd").run(self)
	preload("res://tests/suites/foliage_contact_suite.gd").run(self)
	preload("res://tests/suites/architecture_suite.gd").test_all_methods_have_russian_documentation(self)
	print("FOLIAGE SPEED REVIEW: ",passed," passed, ",failed," failed");quit(0 if failed==0 else 1)
## Считает настоящие условия и печатает отдельную причину сбоя.
func expect(value:bool,label:String)->void:
	if value:passed+=1
	else:failed+=1;print("FAIL: ",label)
