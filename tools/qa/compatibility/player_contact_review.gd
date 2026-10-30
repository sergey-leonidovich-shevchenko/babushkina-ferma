extends "res://tools/qa/compatibility/livestock_review.gd"

## Проверяет физический контакт героя и дальние атаки врагов перед общим quality gate.
func _initialize() -> void:
	preload("res://tests/suites/player_contact_suite.gd").new(self).run()
	preload("res://tests/suites/enemy_projectile_suite.gd").new(self).run()
	print("PLAYER CONTACT REVIEW: %d passed, %d failed" % [passed,failed])
	quit(0 if failed==0 else 1)
