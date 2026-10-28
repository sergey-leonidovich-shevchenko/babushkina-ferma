extends "res://tools/qa/compatibility/dev_cabinet_review.gd"

## Запускает изолированную проверку телепорта без доступа к пользовательским сохранениям.
func _initialize() -> void:
	ProjectSettings.set_setting("application/config/use_custom_user_dir",true)
	ProjectSettings.set_setting("application/config/custom_user_dir_name","Codex-QA-Teleport-Review")
	preload("res://tests/suites/qa_teleport_suite.gd").new(self).run()
	print("QA TELEPORT REVIEW: %d passed, %d failed"%[passed,failed]); quit(0 if failed==0 else 1)
