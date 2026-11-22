extends SceneTree

var passed := 0
var failed := 0


## Запускает реальные переключения и документы только в отдельном пользовательском каталоге.
func _initialize() -> void:
	ProjectSettings.set_setting("application/config/use_custom_user_dir", true)
	ProjectSettings.set_setting(
		"application/config/custom_user_dir_name",
		"Codex-VCOMPAT-010-review-" + str(Time.get_ticks_usec())
	)
	preload("res://tests/suites/visual_rollback_suite.gd").run(self)
	print("VISUAL ROLLBACK REVIEW: ", passed, " passed, ", failed, " failed")
	quit(0 if failed == 0 else 1)


## Считает фактические утверждения; отказ не позволяет объявить профиль успешным.
func expect(value: bool, label: String) -> void:
	if value:
		passed += 1
	else:
		failed += 1
		print("FAIL: ", label)
