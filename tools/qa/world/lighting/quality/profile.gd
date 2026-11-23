extends SceneTree


## Подтверждает фактический userdata до импорта и нативной сцены, не перенастраивая его поздно.
func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	print("LIGHT QUALITY PROFILE: ", OS.get_user_data_dir())
	quit(
		(
			0
			if (
				args.size() == 1
				and args[0].begins_with("Codex-VLIGHT-010-")
				and OS.get_user_data_dir().get_file() == args[0]
			)
			else 2
		)
	)
