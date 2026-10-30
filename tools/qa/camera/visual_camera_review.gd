extends SceneTree

const Points := preload("res://tools/qa/camera/visual_camera_points.gd")
var folder := ""
var export_candidates := false
var profile := ""

## Создаёт отдельный профиль; экспорт кандидатов доступен только явным параметром и не пишет эталон.
func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): folder=arg.trim_prefix("--output=")
		elif arg.begins_with("--profile="): profile=arg.trim_prefix("--profile=")
		elif arg=="--export-candidates": export_candidates=true
	if folder.is_empty() or not profile.begins_with("Codex-VBASE-003-") or "/" in profile or "\\" in profile:
		push_error("Нужны новый --output и изолированный --profile=Codex-VBASE-003-..."); quit(2); return
	ProjectSettings.set_setting("application/config/use_custom_user_dir",true)
	ProjectSettings.set_setting("application/config/custom_user_dir_name",profile)
	_start.call_deferred()

## Проверяет все точки настоящей моделью навигации и камеры, не считая headless визуальной приёмкой.
func _start() -> void:
	if not OS.get_user_data_dir().ends_with(profile) or FileAccess.file_exists("user://farm-settings.cfg"):
		push_error("Нужен свежий изолированный профиль"); quit(2); return
	DirAccess.make_dir_recursive_absolute(folder)
	var rows:=[]; var faults:=[]; var ids:=[]
	var probe:=Points.create_game(); root.add_child(probe); probe.set_physics_process(false)
	var locations:=Points.Teleport.locations(probe); probe.free()
	var data:Dictionary={"schema":1,"preset":"camera-entry-noon-1152-v1","viewport":[1152,648],"points":[]} if export_candidates else Points.registry()
	for location in locations:
		var game:=Points.create_game(); root.add_child(game)
		var point:Dictionary
		if export_candidates:
			game.current_location=location
			var landing:=Points.Teleport.safe_landing(game)
			point={"id":location+"-entry-v1","location":location,"player":Points.pair(landing),"facing":[0,1],"day":1,"minutes":720,"seed":Points.SEED}
			Points.configure(game,point)
			var state:=Points.snapshot(game,point)
			for key in ["camera","phase","season","weather"]: point[key]=state[key]
			point["label"]=game.LocaleSystem.location(location)
			data.points.append(point)
		else:
			var found:Array=data.points.filter(func(p): return p.location==location)
			if found.size()!=1: faults.append("Missing/duplicate location: "+location); game.free(); continue
			point=found[0]; Points.configure(game,point)
		faults.append_array(Points.errors(game,point)); rows.append(Points.snapshot(game,point)); ids.append(point.id)
		game.free()
	if data.points.size()!=locations.size(): faults.append("Unexpected point count")
	FileAccess.open(folder.path_join("candidates.json" if export_candidates else "model.json"),FileAccess.WRITE).store_string(JSON.stringify(data if export_candidates else {"points":rows,"errors":faults,"native":false},"\t")+"\n")
	for fault in faults: push_error(fault)
	print("CAMERA MODEL: ",locations.size()," locations, ",faults.size()," errors")
	quit(0 if faults.is_empty() else 2)
