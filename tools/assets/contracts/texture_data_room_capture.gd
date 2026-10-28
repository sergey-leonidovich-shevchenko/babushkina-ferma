extends SceneTree

const Points := preload("res://tools/visual_camera_points.gd")
const Reference := preload("res://scripts/presentation/visual_reference_mode.gd")
var output := OS.get_environment("VTEXTURE_OUTPUT")

## Изолирует нативный кадр от слотов и настроек игрока, не перезаписывая прошлый результат.
func _initialize() -> void:
	var profile := OS.get_environment("VTEXTURE_PROFILE")
	if output.is_empty() or DirAccess.dir_exists_absolute(output) or not profile.begins_with("Codex-VPIPELINE-005-") or "/" in profile or "\\" in profile:
		push_error("Нужны новый output и отдельный профиль VPIPELINE-005"); quit(2); return
	ProjectSettings.set_setting("application/config/use_custom_user_dir",true)
	ProjectSettings.set_setting("application/config/custom_user_dir_name",profile)
	_capture.call_deferred()

## Снимает неизменную комнату с остановленной симуляцией и полным сериализуемым состоянием.
func _capture() -> void:
	if DisplayServer.get_name()=="headless" or FileAccess.file_exists("user://farm-settings.cfg"):
		push_error("Нужны настоящий renderer и свежий профиль"); quit(2); return
	var point: Dictionary
	for candidate in Points.registry().points:
		if candidate.location=="cottage_interior": point=candidate; break
	root.content_scale_mode=Window.CONTENT_SCALE_MODE_DISABLED; root.content_scale_size=Vector2i.ZERO; root.content_scale_factor=1.0
	var game := Points.create_game(); root.add_child(game); current_scene=game
	Points.configure(game,point); Reference.enable(game,true)
	await create_timer(2.0).timeout
	root.mode=Window.MODE_WINDOWED; root.size=Points.SIZE
	var before: Dictionary=game.SaveSystem.snapshot(game)
	for index in 20:
		game.queue_redraw(); await process_frame; RenderingServer.force_draw(false)
	var image := root.get_texture().get_image()
	var faults: Array=Points.errors(game,point)
	if image.get_size()!=Points.SIZE or before!=game.SaveSystem.snapshot(game): faults.append("framebuffer or simulation changed")
	DirAccess.make_dir_recursive_absolute(output)
	image.save_png(output.path_join("room.png"))
	var data := Points.snapshot(game,point)
	data.merge({"errors":faults,"profile":OS.get_user_data_dir().get_file(),"engine":Engine.get_version_info().string,
		"framebuffer":[image.get_width(),image.get_height()],"state":before,"performance_eligible":false,
		"capture_sha256":FileAccess.get_sha256("res://tools/assets/contracts/texture_data_room_capture.gd")})
	FileAccess.open(output.path_join("capture.json"),FileAccess.WRITE).store_string(JSON.stringify(data,"\t")+"\n")
	print("TEXTURE ROOM: ",output); quit(0 if faults.is_empty() else 2)
