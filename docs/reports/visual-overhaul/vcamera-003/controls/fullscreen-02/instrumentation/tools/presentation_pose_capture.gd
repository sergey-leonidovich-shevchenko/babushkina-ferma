extends "res://tools/camera_quantization_capture.gd"

const Pose := preload("res://scripts/systems/presentation_pose_system.gd")
var legacy := false
var plant: RootProbe

class RootProbe extends Node2D:
	## Рисует только QA-пучок: вершины гнутся, корень остаётся неподвижным в мировом слое.
	func _draw() -> void:
		for x in [-8,0,8]:
			draw_colored_polygon(PackedVector2Array([Vector2(x-3,0),Vector2(x,-28),Vector2(x+4,0)]),Color("a3ce61"))

## Выбирает новый профиль VCAMERA-003 и разрешённый физический размер окна.
func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): folder=arg.trim_prefix("--output=")
		elif arg.begins_with("--profile="): profile=arg.trim_prefix("--profile=")
		elif arg.begins_with("--size="):
			var parts:=arg.trim_prefix("--size=").split("x"); requested=Vector2i(int(parts[0]),int(parts[1]))
		elif arg=="--legacy": legacy=true
		elif arg=="--probe": probe=true
	if folder.is_empty() or not profile.begins_with("Codex-VCAMERA-003-") or "/" in profile or "\\" in profile or requested not in [Vector2i(1152,648),Vector2i(1920,1080),Vector2i(2304,1296)]:
		push_error("Need isolated VCAMERA-003 profile, new output and approved size"); quit(2); return
	ProjectSettings.set_setting("application/config/use_custom_user_dir",true)
	ProjectSettings.set_setting("application/config/custom_user_dir_name",profile)
	_start.call_deferred()

## Записывает одинаковую физику 30 Hz и два отображаемых кадра на такт; это диагностический stress, не FPS.
func _start() -> void:
	if (DisplayServer.get_name()=="headless" and not probe) or not OS.get_user_data_dir().ends_with(profile) or FileAccess.file_exists("user://farm-settings.cfg") or DirAccess.dir_exists_absolute(folder):
		push_error("Need native display, fresh output and isolated profile"); quit(2); return
	DirAccess.make_dir_recursive_absolute(folder.path_join("frames"))
	if not probe: create_timer(60.0).timeout.connect(_startup_timeout)
	print("POSE START: create scene")
	game=Points.create_game(); root.add_child(game); current_scene=game
	Points.configure(game,Points.registry().points[0])
	print("POSE START: configured")
	if not probe:
		root.title="VCAMERA-003 | "+("A physical hold" if legacy else "B shared pose")
		root.mode=Window.MODE_WINDOWED; root.size=requested; root.show(); root.grab_focus(); await _settle(2000)
		initial={"window":Points.pair(DisplayServer.window_get_size()),"root":Points.pair(root.size),"focused":DisplayServer.window_is_focused(),"mode":root.mode}
		if DisplayServer.window_get_size()!=requested or root.size!=requested or not DisplayServer.window_is_focused():
			errors.append("initial window/focus"); _save(); quit(2); return
		overlay=Markers.new(); root.add_child(overlay)
		plant=RootProbe.new(); root.add_child(plant)
		var shader := Shader.new()
		shader.code="shader_type canvas_item; uniform vec2 contact; void vertex(){ VERTEX.x -= contact.x * 10.0 * max(0.0,-VERTEX.y/28.0); }"
		var mat := ShaderMaterial.new(); mat.shader=shader; plant.material=mat
	for stage in 2:
		Points.configure(game,Points.registry().points[0])
		game.player=STARTS[stage]; game.speed=18.0; game.clear_movement_keys(); game.update_camera(); Pose.reset(game)
		_key(KEY_D if stage==0 else KEY_A,true); _key(KEY_S,true)
		for frame in COUNT:
			if frame>0 and frame%2==0:
				if legacy: game.GameLoop.physics_process(game,1.0/30.0); Pose.reset(game)
				else: game._physics_process(1.0/30.0)
			if not legacy: Pose.present(game,(frame%2)*0.5)
			var row := _measure(stage,frame)
			if not probe:
				overlay.foot=Points.vector(row.foot_canvas); overlay.cell=Points.vector(row.cell_origin_canvas)
				overlay.pointer=Points.vector(row.pointer_canvas)
				overlay.label="VCAMERA-003 | "+("A physical hold" if legacy else "B shared pose")+" | "+("follow; 30 physics / 60 video" if stage==0 else "edge (new scene)")
				plant.position=Points.vector(row.root_canvas)
				plant.material.set_shader_parameter("contact",Points.vector(row.contact))
				row.shader_contact=Points.pair(plant.material.get_shader_parameter("contact"))
				game.queue_redraw(); overlay.queue_redraw(); plant.queue_redraw(); await RenderingServer.frame_post_draw
				var image:=root.get_texture().get_image()
				row.readback=Points.pair(image.get_size()); row.focused=DisplayServer.window_is_focused()
				row.foot_pixel=_pixel_matches(image,Points.vector(row.foot_canvas)*root.get_stretch_transform().get_scale(),Color.YELLOW)
				row.fiducial=_pixel_matches(image,Vector2(20,164)*root.get_stretch_transform().get_scale(),Color.MAGENTA)
				if image.get_size()!=requested or not row.focused or not row.foot_pixel or not row.fiducial: errors.append("readback/focus/pixels "+str(rows.size()))
				if image.save_png(folder.path_join("frames/%04d.png"%rows.size()))!=OK: errors.append("PNG write")
			rows.append(row)
		_key(KEY_D if stage==0 else KEY_A,false); _key(KEY_S,false)
	_save(); print("POSE: ",rows.size()," rows; ",errors)
	quit(0 if errors.is_empty() else 2)

## Ожидает установку окна по idle-часам, не зависая на ещё не появившемся GPU-сигнале.
func _settle(milliseconds: int) -> void:
	var deadline := Time.get_ticks_msec()+milliseconds
	while Time.get_ticks_msec()<deadline:
		game.queue_redraw(); await process_frame

## Сохраняет явный отказ вместо бесконечного ожидания первого нативного кадра.
func _startup_timeout() -> void:
	if rows.is_empty(): errors.append("no first GPU frame within 60 seconds"); _save(); quit(2)

## Измеряет настоящую позу, камеру, uniform растения и обратный ввод после преобразования движком.
func _measure(stage: int, frame: int) -> Dictionary:
	var ground := Pose.ground(game)
	var pose := Visual.current_pose(game,game.facing,true)
	var destination := Visual.destination(Actor.player_ground(game),pose)
	var foot := destination.position+Vector2(pose.pivot)*float(pose.scale)
	var origin: Vector2 = STARTS[stage]+Vector2(24,32)
	var pointer_world:=Vector2(600.0+(-0.125 if frame%2==0 else 0.125),696.125)
	if stage==1: pointer_world=Vector2([0.125,23.875,24.125][frame%3],720.125)
	var canvas: Vector2 = pointer_world-game.camera_offset
	var window: Vector2 = root.get_final_transform()*canvas
	var received := canvas
	if not probe:
		overlay.received=Vector2.INF
		var motion:=InputEventMouseMotion.new(); motion.position=window; motion.global_position=window
		root.push_input(motion,false); received=overlay.received
	var restored: Vector2 = received+game.camera_offset
	var cell: Vector2i = game.FenceSystem.target_cell(game,restored)
	if foot.distance_to(ground)>0.001 or restored.distance_to(pointer_world)>0.001 or not game.is_position_walkable(game.player): errors.append("foot/pointer/collision "+str(rows.size()))
	return {"index":rows.size(),"stage":stage,"frame":frame,"alpha":(frame%2)*0.5,"physical_step":frame>0 and frame%2==0,
		"player":Points.pair(game.player),"previous":Points.pair(game.get_meta(Pose.META).previous),"ground":Points.pair(ground),
		"foot_world":Points.pair(foot),"foot_canvas":Points.pair(foot-game.camera_offset),"camera":Points.pair(game.camera_offset),"background":Points.pair(game.get_node("WorldBackground").position),
		"root":Points.pair(origin),"root_canvas":Points.pair(origin-game.camera_offset),"contact":Points.pair(Pose.root_contact(game,origin,72)),"radius":72,
		"walk_clock":Pose.walk_clock(game),"physical_walk_clock":float(game.get_meta(&"player_walk_time",0.0)),"minutes":game.game_minutes,
		"pointer_world":Points.pair(restored),"pointer_received":Points.pair(received),"pointer_canvas":Points.pair(canvas),"pointer_window":Points.pair(window),"pointer_cell":Points.pair(cell),"cell_origin_canvas":Points.pair(Vector2(cell)*24-game.camera_offset),
		"location":game.current_location,"walkable":game.is_position_walkable(game.player),"automatic_physics":game.is_physics_processing(),"automatic_render":game.is_processing(),
		"window":Points.pair(DisplayServer.window_get_size()),"visible":Points.pair(root.get_visible_rect().size),"stretch_scale":Points.pair(root.get_stretch_transform().get_scale()),"window_mode":root.mode}

## Сохраняет все строки и настоящие ошибки; headless не может быть принят как нативная съёмка.
func _save() -> void:
	var report := {"schema":1,"task":"VCAMERA-003","kind":"pose-probe" if probe else "pose-native","performance_eligible":false,
		"simulation":"30 Hz full GameLoop, 60 Hz presentation; two prepared scenes, cut at 180","legacy":legacy,
		"profile":profile,"pid":OS.get_process_id(),"requested":Points.pair(requested),"initial":initial,"frames":rows,"inputs":sent,"errors":errors,
		"physics_hz":30,"video_hz":60,"display_server":DisplayServer.get_name(),"renderer":RenderingServer.get_current_rendering_driver_name(),"adapter":RenderingServer.get_video_adapter_name(),
		"engine":Engine.get_version_info().string,"screen_scale":DisplayServer.screen_get_scale(),"hidpi":ProjectSettings.get_setting("display/window/dpi/allow_hidpi"),
		"content_scale_mode":root.content_scale_mode,"content_scale_size":Points.pair(root.content_scale_size),"content_scale_factor":root.content_scale_factor}
	FileAccess.open(folder.path_join("capture.json"),FileAccess.WRITE).store_string(JSON.stringify(report)+"\n")
