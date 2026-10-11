extends "res://tools/livestock_review.gd"

## Проверяет контакт дальних атак и основные боевые сценарии до общего quality gate.
func _initialize() -> void:
	preload("res://tests/suites/enemy_projectile_suite.gd").new(self).run()
	preload("res://tests/suites/enemy_levels_suite.gd").new(self).run()
	preload("res://tests/suites/enemy_animation_suite.gd").new(self).run()
	print("RANGED REVIEW: %d passed, %d failed"%[passed,failed])
	quit(0 if failed==0 else 1)
