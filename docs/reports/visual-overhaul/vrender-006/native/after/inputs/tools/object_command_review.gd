extends SceneTree

var passed := 0
var failed := 0

## Запускает профиль команды объекта отдельно от обычных настроек и сохранений.
func _initialize() -> void:
	ProjectSettings.set_setting("application/config/use_custom_user_dir",true)
	ProjectSettings.set_setting("application/config/custom_user_dir_name","Codex-VRENDER-004-review-"+str(Time.get_ticks_usec()))
	preload("res://tests/suites/object_draw_command_suite.gd").run(self)
	print("OBJECT COMMAND: ",passed," passed, ",failed," failed")
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--export=") and failed==0:
			var path:=arg.trim_prefix("--export=")
			if FileAccess.file_exists(path): push_error("Fresh export required");quit(2);return
			var commands:=[]
			for direction in [0,1,3]:
				commands.append(preload("res://tools/object_command_canvas.gd").describe(preload("res://scripts/presentation/world_workbench_visual_system.gd").command(Vector2(720.25,612.5),direction)))
			FileAccess.open(path,FileAccess.WRITE).store_string(JSON.stringify({"schema":1,"task":"VRENDER-004","production_pass_enabled":false,"commands":commands})+"\n")
	quit(0 if failed==0 else 1)

## Записывает результат каждого утверждения с названием нарушенного условия.
func expect(condition: bool, label: String) -> void:
	if condition: passed+=1
	else: failed+=1; print("FAIL: ",label)
