extends SceneTree

var passed := 0
var failed := 0

## Выполняет профиль камеры в отдельном тестовом каталоге; это не GPU- или художественная приёмка.
func _initialize() -> void:
	ProjectSettings.set_setting("application/config/use_custom_user_dir",true)
	ProjectSettings.set_setting("application/config/custom_user_dir_name","Codex-VCAMERA-002-Tests")
	preload("res://tests/suites/camera_quantization_suite.gd").run(self)
	preload("res://tests/suites/coordinate_contract_suite.gd").run(self)
	print("QUANTIZATION TESTS: %d passed, %d failed"%[passed,failed])
	quit(0 if failed==0 else 1)

## Записывает проверенное условие и точную причину отказа.
func expect(condition: bool, label: String) -> void:
	if condition: passed+=1
	else: failed+=1; push_error(label)
