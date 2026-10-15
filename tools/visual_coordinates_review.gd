extends SceneTree

var passed := 0
var failed := 0

## Запускает профильную проверку координат без графики и без заявления о физическом устройстве.
func _initialize() -> void:
	ProjectSettings.set_setting("application/config/use_custom_user_dir",true)
	ProjectSettings.set_setting("application/config/custom_user_dir_name","Codex-VCAMERA-001-Tests")
	preload("res://tests/suites/coordinate_contract_suite.gd").run(self)
	print("COORDINATE TESTS: %d passed, %d failed"%[passed,failed]); quit(0 if failed==0 else 1)

## Регистрирует проверенное условие и сохраняет точное название отказа.
func expect(condition: bool, label: String) -> void:
	if condition: passed+=1
	else: failed+=1; push_error(label)
