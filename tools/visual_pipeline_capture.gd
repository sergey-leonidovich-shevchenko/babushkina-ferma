extends SceneTree
const Points := preload("res://tools/visual_camera_points.gd")
const Reference := preload("res://scripts/presentation/visual_reference_mode.gd")
var game: Node
var output:=OS.get_environment("VPIPELINE_CAPTURE")
## Изолирует нативный кадр от пользовательских сохранений.
func _initialize() -> void:
	var profile:=OS.get_environment("VPIPELINE_PROFILE")
	if output.is_empty() or DirAccess.dir_exists_absolute(output) or not profile.begins_with("Codex-VPIPELINE-001-") or "/" in profile or "\\" in profile:
		push_error("Нужны новый output и отдельный профиль VPIPELINE-001"); quit(2); return
	ProjectSettings.set_setting("application/config/use_custom_user_dir",true)
	ProjectSettings.set_setting("application/config/custom_user_dir_name",profile)
	_start.call_deferred()
## Снимает остановленную деревню при фиксированной камере без измерения производительности.
func _start() -> void:
	if DisplayServer.get_name()=="headless" or FileAccess.file_exists("user://farm-settings.cfg"):
		push_error("Нужны графический движок и новый профиль"); quit(2); return
	root.title="VPIPELINE-001 · проверка границ импорта"
	root.content_scale_mode=Window.CONTENT_SCALE_MODE_DISABLED
	root.content_scale_size=Vector2i.ZERO; root.content_scale_factor=1.0
	game=Points.create_game(); root.add_child(game); current_scene=game
	var point:Dictionary=Points.registry().points[0]
	Points.configure(game,point); Reference.enable(game,true)
	await create_timer(2.0).timeout
	root.mode=Window.MODE_WINDOWED; root.size=Points.SIZE
	await create_timer(1.0).timeout
	for i in 20:
		game.queue_redraw(); await process_frame; RenderingServer.force_draw(false)
	var image:=root.get_texture().get_image()
	DirAccess.make_dir_recursive_absolute(output)
	if image.get_size()!=Points.SIZE or image.save_png(output.path_join("village.png"))!=OK:
		push_error("Неверный framebuffer или PNG"); quit(2); return
	var data:=Points.snapshot(game,point)
	data.merge({"engine":Engine.get_version_info().string,"window":[root.size.x,root.size.y],"framebuffer":[image.get_width(),image.get_height()],"errors":Points.errors(game,point),"profile":OS.get_user_data_dir().get_file(),"performance_eligible":false})
	FileAccess.open(output.path_join("capture.json"),FileAccess.WRITE).store_string(JSON.stringify(data,"\t")+"\n")
	print("PIPELINE CAPTURE: ",output); quit(0 if data.errors.is_empty() else 2)
