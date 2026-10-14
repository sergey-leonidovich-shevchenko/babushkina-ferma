extends "res://tools/paper_theme_review.gd"

## Проверяет восстановление, настройки, реакцию героя и прежние угрозы в одном профильном прогоне.
func _initialize() -> void:
	for suite in [preload("res://tests/suites/menu_suite.gd"),preload("res://tests/suites/adventure_polish_suite.gd"),preload("res://tests/suites/player_contact_suite.gd"),preload("res://tests/suites/cave_boss_suite.gd"),preload("res://tests/suites/paper_theme_suite.gd")]: suite.new(self).run()
	print("RECOVERY REVIEW: %d passed, %d failed"%[passed,failed]); quit(0 if failed==0 else 1)
