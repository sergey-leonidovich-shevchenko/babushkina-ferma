extends "res://tools/qa/performance/cave_boss_frame_review.gd"

## Изолирует профиль арены и настройки окна от обычного запуска игры.
func _initialize() -> void:
	ProjectSettings.set_setting("application/config/use_custom_user_dir",true)
	ProjectSettings.set_setting("application/config/custom_user_dir_name","Codex-Optimization-Audit-20261014")
	super._initialize()

## Отклоняет отсутствие графики до старого стенда, не принимая headless за нативный замер.
func _start() -> void:
	if DisplayServer.get_name()=="headless": print("AUDIT REJECTED: native renderer required"); quit(2); return
	super._start()
