extends SceneTree

const Points := preload("res://tools/qa/camera/visual_camera_points.gd")
var folder := ""
var profile := ""
var selected := ""
var rows := []
var faults := []

## Настраивает отдельный профиль до инициализации игровых данных и чтения настроек.
func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): folder=arg.trim_prefix("--output=")
		elif arg.begins_with("--profile="): profile=arg.trim_prefix("--profile=")
		elif arg.begins_with("--point="): selected=arg.trim_prefix("--point=")
	if folder.is_empty() or not profile.begins_with("Codex-VBASE-003-") or "/" in profile or "\\" in profile:
		push_error("Нужны --output и свежий --profile=Codex-VBASE-003-..."); quit(2); return
	ProjectSettings.set_setting("application/config/use_custom_user_dir",true)
	ProjectSettings.set_setting("application/config/custom_user_dir_name",profile)
	_start.call_deferred()

## Снимает фиксированные точки в настоящем окне; замороженная симуляция никогда не считается замером кадров.
func _start() -> void:
	if DisplayServer.get_name()=="headless": push_error("Нужна нативная графика"); quit(2); return
	if not OS.get_user_data_dir().ends_with(profile) or FileAccess.file_exists("user://farm-settings.cfg"):
		push_error("Нужен свежий изолированный профиль"); quit(2); return
	var data:=Points.registry(); var points:Array=data.points
	if not selected.is_empty(): points=points.filter(func(p): return p.id==selected)
	if points.is_empty(): push_error("Неизвестная точка"); quit(2); return
	DirAccess.make_dir_recursive_absolute(folder)
	root.title="VBASE-003 · точки камеры"
	root.content_scale_mode=Window.CONTENT_SCALE_MODE_DISABLED
	root.content_scale_size=Vector2i.ZERO; root.content_scale_factor=1.0
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED)
	for point in points:
		var game:=Points.create_game(); root.add_child(game); current_scene=game; Points.configure(game,point)
		if rows.is_empty():
			await create_timer(2.0).timeout
			root.mode=Window.MODE_WINDOWED
			await create_timer(2.0).timeout
			root.size=Points.SIZE; root.grab_focus()
			await create_timer(2.0).timeout
		var conditions:=[]
		for frame in 12:
			game.queue_redraw(); await RenderingServer.frame_post_draw
			conditions.append(_conditions())
		var actual:=Points.snapshot(game,point)
		faults.append_array(Points.errors(game,point))
		for condition in conditions:
			if not condition.valid: faults.append(point.id+": window/framebuffer/focus mismatch"); break
		var image:=root.get_texture().get_image(); var filename:String=point.id+".png"
		if image.get_size()!=Points.SIZE: faults.append(point.id+": readback mismatch")
		if image.save_png(folder.path_join(filename))!=OK: faults.append(point.id+": PNG failed")
		actual.merge({"image":filename,"readback":Points.pair(image.get_size()),"conditions":conditions})
		rows.append(actual)
		print("CAMERA CAPTURE: ",point.id)
		game.free(); current_scene=null
		if not faults.is_empty(): break
	var report:={"schema":1,"kind":"static-camera-reference","performance_eligible":false,"simulation_frozen":true,
		"preset":data.preset,"profile":profile,"renderer":RenderingServer.get_current_rendering_driver_name(),"display_server":DisplayServer.get_name(),
		"engine":Engine.get_version_info().string,"adapter":RenderingServer.get_video_adapter_name(),"hud":true,"reduced_motion":true,
		"effects":"existing; wall-clock water/glow remain animated","warmup_redraws":12,"points":rows,"errors":faults}
	FileAccess.open(folder.path_join("capture.json"),FileAccess.WRITE).store_string(JSON.stringify(report,"\t")+"\n")
	for fault in faults: push_error(fault)
	quit(0 if faults.is_empty() else 2)

## Проверяет и сохраняет реальные размеры, фокус и оконный режим каждого кадра подготовки.
func _conditions() -> Dictionary:
	var window:=DisplayServer.window_get_size(); var target:=Vector2i(root.get_texture().get_size())
	var focus:=DisplayServer.window_is_focused(); var mode:=DisplayServer.window_get_mode()
	return {"window":Points.pair(window),"framebuffer":Points.pair(target),"root":Points.pair(root.size),"focused":focus,"mode":mode,
		"valid":window==Points.SIZE and target==Points.SIZE and root.size==Points.SIZE and focus and mode==DisplayServer.WINDOW_MODE_WINDOWED}
