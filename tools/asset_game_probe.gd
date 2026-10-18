extends SceneTree

const Reference := preload("res://scripts/presentation/visual_reference_mode.gd")
var output:=OS.get_environment("VASSET_OUTPUT")
var errors:Array=[]

## Требует отдельный проект, профиль и новый каталог, не открывая игровые слоты пользователя.
func _initialize() -> void:
	var profile:=OS.get_environment("VASSET_PROFILE")
	if ProjectSettings.get_setting("application/config/name")!="VPIPELINE-010 export fixture" or DisplayServer.get_name()=="headless" or output.is_empty() or DirAccess.dir_exists_absolute(output) or not profile.begins_with("Codex-VPIPELINE-010-") or "/" in profile or "\\" in profile:quit(2);return
	if OS.get_environment("VASSET_PACK")=="1" and FileAccess.file_exists(ProjectSettings.globalize_path("res://")+"project.godot"):quit(2);return
	ProjectSettings.set_setting("application/config/use_custom_user_dir",true);ProjectSettings.set_setting("application/config/custom_user_dir_name",profile)
	_start.call_deferred()

## Сравнивает настоящие деревню и дом при одинаковых production-камере, состоянии и renderer.
func _start() -> void:
	var points=load(OS.get_environment("VASSET_POINTS"))
	var registry:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(OS.get_environment("VASSET_POINTS_JSON")))
	root.content_scale_mode=Window.CONTENT_SCALE_MODE_DISABLED;root.content_scale_size=Vector2i.ZERO;root.content_scale_factor=1.0
	root.mode=Window.MODE_WINDOWED;root.size=Vector2i(1152,648)
	DirAccess.make_dir_recursive_absolute(output)
	var scenes:={}
	for point in registry.points:
		if point.location not in ["overworld","cottage_interior"]:continue
		var game:Node=points.create_game();root.add_child(game);current_scene=game;points.configure(game,point);Reference.enable(game,true)
		for frame in 24:game.queue_redraw();await process_frame;RenderingServer.force_draw(false)
		var before:Dictionary=game.SaveSystem.snapshot(game)
		for frame in 4:game.queue_redraw();await process_frame;RenderingServer.force_draw(false)
		var after:Dictionary=game.SaveSystem.snapshot(game)
		var image:=root.get_texture().get_image()
		if image.get_size()!=Vector2i(1152,648) or image.save_png(output.path_join(point.location+".png"))!=OK:errors.append("invalid native frame")
		if before!=after:errors.append("draw changed serialized state: "+point.location)
		errors.append_array(points.errors(game,point))
		scenes[point.location]={"configuration":points.snapshot(game,point),"state":after,"state_unchanged":before==after}
		game.free();await process_frame
	var data:={"scenes":scenes,"errors":errors,"profile":OS.get_user_data_dir().get_file(),"framebuffer":[1152,648],"display_server":DisplayServer.get_name(),"engine":Engine.get_version_info().string,"method":RenderingServer.get_current_rendering_method(),"driver":RenderingServer.get_current_rendering_driver_name(),"performance_eligible":false,"probe_sha256":FileAccess.get_sha256(OS.get_environment("VASSET_GAME_PROBE")),"points_sha256":FileAccess.get_sha256(OS.get_environment("VASSET_POINTS")),"registry_sha256":FileAccess.get_sha256(OS.get_environment("VASSET_POINTS_JSON"))}
	data.resource_root=ProjectSettings.globalize_path("res://");data.physical_project_present=FileAccess.file_exists(data.resource_root+"project.godot")
	FileAccess.open(output.path_join("capture.json"),FileAccess.WRITE).store_string(JSON.stringify(data,"\t")+"\n")
	print("ASSET GAME PROBE: ",scenes.keys(),"; errors=",errors);quit(0 if errors.is_empty() else 2)
