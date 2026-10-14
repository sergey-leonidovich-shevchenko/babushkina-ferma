extends "res://tools/dev_cabinet_review.gd"

## Проверяет обслуживание, прежние спрайты и границы кешей в отдельном профиле без слотов пользователя.
func _initialize() -> void:
	ProjectSettings.set_setting("application/config/use_custom_user_dir",true)
	ProjectSettings.set_setting("application/config/custom_user_dir_name","Codex-Runtime-Maintenance-Tests")
	preload("res://tests/suites/runtime_maintenance_suite.gd").new(self).run()
	preload("res://tests/suites/prepared_pixel_cache_suite.gd").new(self).run()
	preload("res://tests/suites/editor_actor_source_suite.gd").new(self).run()
	print("RUNTIME MAINTENANCE TESTS: %d passed, %d failed"%[passed,failed]); quit(0 if failed==0 else 1)
