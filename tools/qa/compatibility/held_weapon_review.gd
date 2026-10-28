extends "res://tools/qa/compatibility/livestock_review.gd"

## Проверяет спрятанную экипировку, активные полные позы и прежнее оружие с учётом смещения камеры.
func _initialize() -> void:
	preload("res://tests/suites/held_weapon_visibility_suite.gd").new(self).run()
	preload("res://tests/suites/hero_action_visual_suite.gd").new(self).run()
	preload("res://tests/suites/hero_combat_visual_suite.gd").new(self).run()
	preload("res://tests/suites/hero_action_suite.gd").new(self).run()
	preload("res://tests/suites/animation_suite.gd").new(self).test_held_weapons_follow_camera_in_every_direction()
	print("HELD WEAPON REVIEW: %d passed, %d failed"%[passed,failed]); quit(0 if failed==0 else 1)
