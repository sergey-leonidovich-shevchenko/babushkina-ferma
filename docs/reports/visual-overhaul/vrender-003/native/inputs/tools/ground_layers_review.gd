extends SceneTree

var passed := 0
var failed := 0

## Изолирует даже профильную проверку от обычных пользовательских настроек и сохранений.
func _initialize() -> void:
	ProjectSettings.set_setting("application/config/use_custom_user_dir",true)
	ProjectSettings.set_setting("application/config/custom_user_dir_name","Codex-VRENDER-003-review-"+str(Time.get_ticks_usec()))
	preload("res://tests/suites/ground_layers_suite.gd").run(self)
	print("GROUND LAYERS: ",passed," passed, ",failed," failed; headless is not native/FPS acceptance")
	quit(0 if failed==0 else 1)

## Сохраняет конкретный отказ вместо усечения или молчаливого пропуска сценария.
func expect(condition: bool, label: String) -> void:
	if condition: passed+=1
	else: failed+=1; print("FAIL: ",label)
