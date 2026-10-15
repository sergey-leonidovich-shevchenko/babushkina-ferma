extends "res://tools/dev_cabinet_review.gd"

## Проверяет чистый план воды без слотов пользователя, новой графики и живой сцены.
func _initialize() -> void:
	ProjectSettings.set_setting("application/config/use_custom_user_dir",true)
	ProjectSettings.set_setting("application/config/custom_user_dir_name","Codex-Water-Topology")
	preload("res://tests/suites/water_topology_suite.gd").new(self).run()
	print("WATER TOPOLOGY: %d passed, %d failed"%[passed,failed]); quit(0 if failed==0 else 1)
