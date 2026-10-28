extends SceneTree

## Проверяет фактический sandbox userdata без создания Game или чтения пользовательских слотов.
func _initialize() -> void:
	print(JSON.stringify({"data": OS.get_data_dir(), "user": OS.get_user_data_dir()}))
	quit(0)
