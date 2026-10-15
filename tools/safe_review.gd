extends "res://tools/dev_cabinet_review.gd"

## Запускает выбранные проверки надёжности в изолированном каталоге без пользовательских слотов.
func _initialize() -> void:
	ProjectSettings.set_setting("application/config/use_custom_user_dir",true)
	ProjectSettings.set_setting("application/config/custom_user_dir_name","Codex-SAFE-Review")
	DirAccess.make_dir_recursive_absolute(OS.get_user_data_dir())
	for path in ["world_rng_suite","save_integrity_suite","inventory_transaction_suite","research_suite","storage_actions_suite","basement_suite","atomic_save_suite","focus_pause_suite"]:
		load("res://tests/suites/%s.gd"%path).new(self).run()
	print("SAFE REVIEW: %d passed, %d failed"%[passed,failed]); quit(0 if failed==0 else 1)
