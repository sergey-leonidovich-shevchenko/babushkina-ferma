extends "res://tools/paper_theme_review.gd"

## Сравнивает каждый пиксель кеша и реальные опоры анимации без чтения пользовательских слотов.
func _initialize() -> void:
	preload("res://tests/suites/prepared_pixel_cache_suite.gd").new(self).run()
	preload("res://tests/suites/hero_visual_suite.gd").new(self).run()
	preload("res://tests/suites/grandmother_visual_suite.gd").new(self).run()
	preload("res://tests/suites/wildlife_combat_comfort_suite.gd").new(self).run()
	print("PREPARED PIXELS REVIEW: %d passed, %d failed"%[passed,failed]); quit(0 if failed==0 else 1)
