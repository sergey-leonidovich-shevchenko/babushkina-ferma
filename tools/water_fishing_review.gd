extends "res://tools/dev_cabinet_review.gd"

## Проверяет рыбалку и её визуальные позы в отдельном профиле без пользовательских слотов.
func _initialize() -> void:
	ProjectSettings.set_setting("application/config/use_custom_user_dir",true)
	ProjectSettings.set_setting("application/config/custom_user_dir_name","Codex-Water-Fishing")
	DirAccess.make_dir_recursive_absolute(OS.get_user_data_dir())
	for path in ["fishing_suite","garden_crafting_suite","hero_action_visual_suite","held_weapon_visibility_suite"]:
		load("res://tests/suites/%s.gd"%path).new(self).run()
	print("WATER FISHING: %d passed, %d failed"%[passed,failed]); quit(0 if failed==0 else 1)
