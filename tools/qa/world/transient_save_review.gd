extends SceneTree

var passed:=0
var failed:=0

## Прогоняет граничные типы, настоящий snapshot и старые документы в отдельном пользовательском каталоге.
func _initialize()->void:
	ProjectSettings.set_setting("application/config/use_custom_user_dir",true)
	ProjectSettings.set_setting("application/config/custom_user_dir_name","Codex-VCOMPAT-001-review-"+str(Time.get_ticks_usec()))
	preload("res://tests/suites/transient_visual_save_suite.gd").run(self)
	print("TRANSIENT SAVE REVIEW: ",passed," passed, ",failed," failed");quit(0 if failed==0 else 1)

func expect(value:bool,label:String)->void:
	if value:passed+=1
	else:failed+=1;print("FAIL: ",label)
