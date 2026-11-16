extends "res://tools/qa/compatibility/dev_cabinet_review.gd"

const WaterSuite := preload("res://tests/suites/water_visual_compatibility_suite.gd")


## Выбирает отдельный профиль и ждёт входа корневого viewport в дерево.
func _initialize() -> void:
	ProjectSettings.set_setting("application/config/use_custom_user_dir", true)
	ProjectSettings.set_setting(
		"application/config/custom_user_dir_name", "Codex-VCOMPAT-005-" + str(Time.get_ticks_usec())
	)
	_run.call_deferred()


## Запускает парный сценарий через те же проверки, что и полный игровой набор.
func _run() -> void:
	WaterSuite.new(self).run()
	print("WATER VISUAL COMPATIBILITY: %d passed, %d failed" % [passed, failed])
	quit(0 if failed == 0 else 1)
