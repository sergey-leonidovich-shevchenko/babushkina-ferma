extends SceneTree


## Подтверждает эффективный userdata до импорта игровых скриптов, не создавая игровую сцену.
func _initialize() -> void:
	var arguments := OS.get_cmdline_user_args()
	var actual := OS.get_user_data_dir()
	var valid := (
		arguments.size() == 1
		and arguments[0].begins_with("Codex-VLIGHT-003-")
		and actual.get_file() == arguments[0]
	)
	print("DAYCYCLE PROFILE: ", actual)
	quit(0 if valid else 2)
