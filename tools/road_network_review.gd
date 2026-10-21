extends SceneTree

var passed := 0
var failed := 0

## Выполняет логические проверки отдельно от обычных настроек и сохраняемых слотов.
func _initialize() -> void:
	ProjectSettings.set_setting("application/config/use_custom_user_dir",true)
	ProjectSettings.set_setting("application/config/custom_user_dir_name","Codex-VGROUND-005-review-"+str(Time.get_ticks_usec()))
	preload("res://tests/suites/road_network_suite.gd").run(self)
	print("ROAD NETWORK: ",passed," passed, ",failed," failed")
	quit(0 if failed==0 else 1)

## Фиксирует каждое утверждение без выдачи headless за нативную графику или FPS.
func expect(condition: bool, label: String) -> void:
	if condition: passed+=1
	else: failed+=1; print("FAIL: ",label)
