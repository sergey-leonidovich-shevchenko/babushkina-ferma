extends SceneTree

var passed := 0
var failed := 0


## Запускает реальные переключения и документы только в отдельном пользовательском каталоге.
func _initialize() -> void:
	if not OS.get_user_data_dir().get_file().begins_with("Codex-VCOMPAT-010-"):
		quit(2)
		return
	_run.call_deferred()


## Корневое окно уже в дереве: add_child действительно выполняет _ready у native-фабрики.
func _run() -> void:
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
