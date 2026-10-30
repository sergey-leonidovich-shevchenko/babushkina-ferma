extends "res://tools/assets/contracts/visual_resources_review.gd"

const IntentSuite := preload("res://tests/suites/texture_intent_suite.gd")

## Проверяет назначения текстур и отказ от опасных материалов без сохранения игры.
func _initialize() -> void:
	IntentSuite.new(self).run()
	print("TEXTURE INTENT TESTS: %d passed, %d failed" % [passed,failed]); quit(0 if failed==0 else 1)
