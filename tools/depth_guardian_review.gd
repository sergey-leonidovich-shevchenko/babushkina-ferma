extends "res://tools/paper_theme_review.gd"

## Проверяет цельное тело хранителя, отделение эффекта и сохранение настоящих боевых действий.
func _initialize() -> void:
	for suite in [preload("res://tests/suites/enemy_animation_suite.gd"),preload("res://tests/suites/enemy_levels_suite.gd"),preload("res://tests/suites/enemy_projectile_suite.gd")]: suite.new(self).run()
	preload("res://tests/suites/architecture_suite.gd").test_world_sprite_manifest_tracks_grid_migration(self)
	print("GUARDIAN REVIEW: %d passed, %d failed"%[passed,failed]); quit(0 if failed==0 else 1)
