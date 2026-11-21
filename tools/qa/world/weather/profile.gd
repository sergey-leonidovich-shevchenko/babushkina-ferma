extends SceneTree


## Подтверждает эффективный userdata до импорта сцен и ресурсов игры.
func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var actual := OS.get_user_data_dir()
	var valid := (
		args.size() == 1
		and args[0].begins_with("Codex-VWEATHER-001-")
		and actual.get_file() == args[0]
	)
	print("WEATHER PROFILE: ", actual)
	quit(0 if valid else 2)
