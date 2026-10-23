extends "res://tests/test_game.gd"


## Открывает изолированный профиль для проверки совпадения навигационных подшагов животных.
func _initialize() -> void:
	ProjectSettings.set_setting("application/config/use_custom_user_dir", true)
	ProjectSettings.set_setting(
		"application/config/custom_user_dir_name",
		"Codex-Wildlife-Query-" + str(Time.get_ticks_usec())
	)
	_run.call_deferred()


## Сравнивает полные и локальные запросы настоящих карт, затем прежние гарантии F10 и покоя животных.
func _run() -> void:
	preload("res://tests/suites/wildlife_query_suite.gd").new(self).run()
	preload("res://tests/suites/debug_frame_budget_suite.gd").new(self).run()
	print("WILDLIFE QUERY REVIEW: ", passed, " passed, ", failed, " failed")
	quit(0 if failed == 0 else 1)
