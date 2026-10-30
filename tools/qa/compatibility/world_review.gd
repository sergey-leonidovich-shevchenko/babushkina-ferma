extends "res://tools/qa/compatibility/dev_cabinet_review.gd"

## Запускает профиль мира в отдельном каталоге и сохраняет наблюдаемый маршрут первой недели.
func _initialize() -> void:
	ProjectSettings.set_setting("application/config/use_custom_user_dir",true)
	ProjectSettings.set_setting("application/config/custom_user_dir_name","Codex-WORLD-Review")
	DirAccess.make_dir_recursive_absolute(OS.get_user_data_dir())
	var suite := preload("res://tests/suites/first_week_route_suite.gd").new(self); suite.run()
	preload("res://tests/suites/village_wayfinding_suite.gd").new(self).run()
	preload("res://tests/suites/npc_availability_suite.gd").new(self).run()
	preload("res://tests/suites/expansion_suite.gd").new(self).test_npc_schedule_reacts_to_time_and_weather()
	var output := "/private/tmp/world-review.json"
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--output="): output = argument.trim_prefix("--output=")
	var file := FileAccess.open(output,FileAccess.WRITE)
	file.store_string(JSON.stringify({"schema":1,"week":suite.report,"passed":passed,"failed":failed},"\t")); file.close()
	print("WORLD REVIEW: %d passed, %d failed" % [passed,failed]); quit(0 if failed == 0 else 1)
