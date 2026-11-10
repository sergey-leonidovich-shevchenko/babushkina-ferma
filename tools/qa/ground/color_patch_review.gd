extends SceneTree

var passed := 0
var failed := 0


## Запускает профильные проверки VGROUND-002 в отдельном headless-процессе.
func _initialize() -> void:
	ProjectSettings.set_setting("application/config/use_custom_user_dir", true)
	ProjectSettings.set_setting(
		"application/config/custom_user_dir_name", "Codex-VGROUND-002-review"
	)
	preload("res://tests/suites/ground_color_patches_suite.gd").run(self)
	print("VGROUND-002 REVIEW: %d passed / %d failed" % [passed, failed])
	quit(0 if failed == 0 else 1)


## Считает каждое профильное утверждение и сохраняет текст отказа в стандартном Godot-логе.
func expect(condition: bool, message: String) -> void:
	if condition:
		passed += 1
	else:
		failed += 1
		push_error(message)
