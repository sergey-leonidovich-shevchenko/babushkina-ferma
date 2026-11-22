extends SceneTree


## До любого импорта/запуска подтверждает фактическую отдельную папку нового QA-процесса.
func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	print(OS.get_user_data_dir())
	quit(0 if args.size() == 1 and OS.get_user_data_dir().get_file() == args[0] else 2)
