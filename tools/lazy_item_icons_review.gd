extends "res://tools/paper_theme_review.gd"

## Проверяет все размеры, источники и окраски предметов вместе с взаимодействиями хранилищ.
func _initialize() -> void:
	preload("res://tests/suites/lazy_item_icons_suite.gd").new(self).run()
	preload("res://tests/suites/item_icon_contract_suite.gd").new(self).run()
	preload("res://tests/suites/storage_grid_suite.gd").new(self).run()
	preload("res://tests/suites/storage_actions_suite.gd").new(self).run()
	print("LAZY ITEM ICONS REVIEW: %d passed, %d failed"%[passed,failed]); quit(0 if failed==0 else 1)
