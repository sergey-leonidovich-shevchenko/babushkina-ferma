extends "res://tools/qa/compatibility/dev_cabinet_review.gd"

## Проверяет физику и миграции воды в отдельном профиле без пользовательских слотов.
func _initialize() -> void:
	ProjectSettings.set_setting("application/config/use_custom_user_dir",true)
	ProjectSettings.set_setting("application/config/custom_user_dir_name","Codex-Water-Navigation")
	DirAccess.make_dir_recursive_absolute(OS.get_user_data_dir())
	if "--recovery-only" in OS.get_cmdline_user_args():
		preload("res://tests/suites/recovery_suite.gd").new(self).run()
		print("WATER RECOVERY: %d passed, %d failed"%[passed,failed]); quit(0 if failed==0 else 1); return
	for path in ["water_topology_suite","water_navigation_suite","village_map_suite","village_clearance_suite","village_regions_suite","fishing_suite","livestock_suite","player_corner_world_suite","recovery_suite"]:
		load("res://tests/suites/%s.gd"%path).new(self).run()
	print("WATER NAVIGATION: %d passed, %d failed"%[passed,failed]); quit(0 if failed==0 else 1)
