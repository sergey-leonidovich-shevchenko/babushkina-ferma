extends SceneTree
var passed:=0
var failed:=0

## Выполняет адресные проверки в отдельном профиле без доступа к обычным слотам.
func _initialize()->void:
	ProjectSettings.set_setting("application/config/use_custom_user_dir",true)
	ProjectSettings.set_setting("application/config/custom_user_dir_name","Codex-VRENDER-008-review-"+str(Time.get_ticks_usec()))
	preload("res://tests/suites/post_motion_frame_suite.gd").run(self)
	print("POST MOTION REVIEW: ",passed," passed, ",failed," failed");quit(0 if failed==0 else 1)

## Записывает точное нарушенное условие вместо оптимистичного общего статуса.
func expect(condition:bool,label:String)->void:
	if condition:passed+=1
	else:failed+=1;print("FAIL: ",label)
