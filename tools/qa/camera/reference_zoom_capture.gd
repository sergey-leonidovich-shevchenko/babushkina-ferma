extends "res://tools/qa/camera/presentation_pose_capture.gd"

const WorldProjection := preload("res://scripts/systems/world_projection_system.gd")
const ZOOM_FRAMES := 120
const ZOOM_STARTS := [Vector2(600.25,700.25),Vector2(60.25,672.25)]
var amount := 1.2
var markers: ZoomMarkers

class ZoomMarkers extends Node2D:
	var foot := Vector2.ZERO
	var cell := Vector2.ZERO
	var pointer := Vector2.ZERO
	var received := Vector2.INF
	var cell_size := 24.0
	var label := ""
	## Наблюдает реальный ввод после единственного stretch окна.
	func _input(event: InputEvent) -> void:
		if event is InputEventMouseMotion: received=event.position
	## Рисует стопу и масштабированную мировую клетку отдельно от немасштабируемого HUD-контроля.
	func _draw() -> void:
		draw_line(foot-Vector2(7,0),foot+Vector2(7,0),Color.YELLOW,1)
		draw_line(foot-Vector2(0,7),foot+Vector2(0,7),Color.YELLOW,1)
		draw_rect(Rect2(cell,Vector2.ONE*cell_size),Color.CYAN,false,1)
		draw_circle(pointer,3,Color.CYAN)
		draw_rect(Rect2(16,160,8,8),Color.MAGENTA)
		draw_rect(Rect2(220,146,910,34),Color(0.02,0.03,0.03,0.93))
		draw_string(ThemeDB.fallback_font,Vector2(232,169),label,HORIZONTAL_ALIGNMENT_LEFT,-1,16,Color.WHITE)

## Принимает только два согласованных профиля, новый каталог и отдельные пользовательские данные.
func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): folder=arg.trim_prefix("--output=")
		elif arg.begins_with("--profile="): profile=arg.trim_prefix("--profile=")
		elif arg.begins_with("--zoom="): amount=float(arg.trim_prefix("--zoom="))
		elif arg.begins_with("--size="):
			var parts:=arg.trim_prefix("--size=").split("x"); requested=Vector2i(int(parts[0]),int(parts[1]))
		elif arg=="--probe": probe=true
	if folder.is_empty() or not profile.begins_with("Codex-VCAMERA-006-") or "/" in profile or "\\" in profile or amount not in [1.0,1.2] or requested not in [Vector2i(1152,648),Vector2i(1920,1080),Vector2i(2304,1296)]:
		push_error("Need new VCAMERA-006 output/profile, accepted zoom and size"); quit(2); return
	ProjectSettings.set_setting("application/config/use_custom_user_dir",true)
	ProjectSettings.set_setting("application/config/custom_user_dir_name",profile)
	_start.call_deferred()

## Снимает одну и ту же физическую траекторию при 100/120%; readback и ручной шаг исключены из FPS.
func _start() -> void:
	if (DisplayServer.get_name()=="headless" and not probe) or not OS.get_user_data_dir().ends_with(profile) or FileAccess.file_exists("user://farm-settings.cfg") or DirAccess.dir_exists_absolute(folder):
		push_error("Need native display and fresh isolated output"); quit(2); return
	DirAccess.make_dir_recursive_absolute(folder.path_join("frames"))
	if not probe: create_timer(60.0).timeout.connect(_startup_timeout)
	game=Points.create_game(); root.add_child(game); current_scene=game
	Points.configure(game,Points.registry().points[0]); WorldProjection.set_reference_zoom(game,amount); game.update_camera()
	if not probe:
		root.title="VCAMERA-006 | "+str(roundi(amount*100))+"%"
		await _settle(2000); root.mode=Window.MODE_WINDOWED; root.show()
		await _settle(2000); root.size=requested; root.grab_focus(); await _settle(2000)
		initial={"window":Points.pair(DisplayServer.window_get_size()),"root":Points.pair(root.size),"focused":DisplayServer.window_is_focused(),"mode":root.mode}
		if DisplayServer.window_get_size()!=requested or root.size!=requested or not DisplayServer.window_is_focused(): errors.append("initial window/focus"); _save(); quit(2); return
		markers=ZoomMarkers.new(); markers.z_index=20; markers.cell_size=24*amount; root.add_child(markers)
		plant=RootProbe.new(); plant.z_index=10; plant.scale=Vector2.ONE*amount; root.add_child(plant)
		var shader:=Shader.new(); shader.code="shader_type canvas_item; uniform vec2 contact; void vertex(){ VERTEX.x -= contact.x * 10.0 * max(0.0,-VERTEX.y/28.0); }"
		var material_value:=ShaderMaterial.new(); material_value.shader=shader; plant.material=material_value
	for stage in 2:
		Points.configure(game,Points.registry().points[0]); WorldProjection.set_reference_zoom(game,amount)
		game.player=ZOOM_STARTS[stage]; game.speed=18; game.update_camera(); Pose.reset(game)
		_key(KEY_D if stage==0 else KEY_A,true); _key(KEY_S,true)
		for frame in ZOOM_FRAMES:
			if frame>0 and frame%2==0: game._physics_process(1.0/30.0)
			Pose.present(game,(frame%2)*0.5)
			var row:=_measure(stage,frame)
			if not probe:
				markers.foot=Points.vector(row.foot_canvas); markers.cell=Points.vector(row.cell_origin_canvas); markers.pointer=Points.vector(row.pointer_canvas)
				markers.label="VCAMERA-006 | "+str(roundi(amount*100))+"% | "+("same world center; 30 physics / 60 video" if stage==0 else "edge (new scene)")
				plant.position=Points.vector(row.root_canvas); plant.material.set_shader_parameter("contact",Points.vector(row.contact))
				row.shader_contact=Points.pair(plant.material.get_shader_parameter("contact"))
				game.queue_redraw(); markers.queue_redraw(); plant.queue_redraw(); await RenderingServer.frame_post_draw
				var image:=root.get_texture().get_image(); var stretch:=root.get_stretch_transform().get_scale()
				row.readback=Points.pair(image.get_size()); row.focused=DisplayServer.window_is_focused()
				row.foot_pixel=_pixel_matches(image,Points.vector(row.foot_canvas)*stretch,Color.YELLOW)
				row.fiducial=_pixel_matches(image,Vector2(20,164)*stretch,Color.MAGENTA)
				var hud_rect:=Rect2i(Vector2(30,23)*stretch,Vector2(160,28)*stretch)
				row.hud_crop=[hud_rect.position.x,hud_rect.position.y,hud_rect.size.x,hud_rect.size.y]
				row.hud_sha256=image.get_region(hud_rect).get_data().hex_encode().sha256_text()
				if image.get_size()!=requested or not row.focused or not row.foot_pixel or not row.fiducial: errors.append("readback/focus/pixels "+str(rows.size()))
				if image.save_png(folder.path_join("frames/%04d.png"%rows.size()))!=OK: errors.append("PNG write")
			rows.append(row)
		_key(KEY_D if stage==0 else KEY_A,false); _key(KEY_S,false)
	_save(); print("REFERENCE ZOOM CAPTURE: ",rows.size()," rows; ",errors); quit(0 if errors.is_empty() else 2)

## Измеряет production-матрицу, корень, стопу, HUD и обратный ввод; физический мир остаётся общим.
func _measure(stage: int, frame: int) -> Dictionary:
	var ground:=Pose.ground(game); var pose:=Visual.current_pose(game,game.facing,true)
	var destination:=Visual.destination(Actor.player_ground(game),pose)
	var foot:Vector2=destination.position+Vector2(pose.pivot)*float(pose.scale)
	var origin:Vector2=ZOOM_STARTS[stage]+Vector2(24,32)
	var pointer_world:=Vector2(624+(-0.125 if frame%2==0 else 0.125),720.125)
	if stage==1: pointer_world=Vector2([0.125,23.875,24.125][frame%3],720.125)
	var canvas:=WorldProjection.world_to_screen(game,pointer_world)
	var window:Vector2=root.get_final_transform()*canvas
	var received:=canvas
	if not probe:
		markers.received=Vector2.INF
		var motion:=InputEventMouseMotion.new(); motion.position=window; motion.global_position=window; root.push_input(motion,false); received=markers.received
	var restored:=WorldProjection.screen_to_world(game,received)
	var cell:Vector2i=game.FenceSystem.target_cell(game,restored)
	if foot.distance_to(ground)>0.001 or restored.distance_to(pointer_world)>0.001 or not game.is_position_walkable(game.player): errors.append("foot/pointer/collision "+str(rows.size()))
	var matrix:=WorldProjection.transform(game)
	return {"index":rows.size(),"stage":stage,"frame":frame,"alpha":(frame%2)*0.5,"physical_step":frame>0 and frame%2==0,
		"zoom":WorldProjection.zoom(game),"field":Points.pair(WorldProjection.field_size(game)),"matrix":[Points.pair(matrix.x),Points.pair(matrix.y),Points.pair(matrix.origin)],
		"player":Points.pair(game.player),"previous":Points.pair(game.get_meta(Pose.META).previous),"ground":Points.pair(ground),"walk_clock":Pose.walk_clock(game),"physical_walk_clock":float(game.get_meta(&"player_walk_time",0.0)),"minutes":game.game_minutes,
		"foot_world":Points.pair(foot),"foot_canvas":Points.pair(WorldProjection.world_to_screen(game,foot)),"hero_frame_projected":Points.pair(destination.size*amount),
		"camera":Points.pair(game.camera_offset),"background":Points.pair(game.get_node("WorldBackground").position),"background_scale":Points.pair(game.get_node("WorldBackground").scale),
		"root":Points.pair(origin),"root_canvas":Points.pair(WorldProjection.world_to_screen(game,origin)),"contact":Points.pair(Pose.root_contact(game,origin,72)),"radius":72,
		"pointer_world":Points.pair(restored),"pointer_received":Points.pair(received),"pointer_canvas":Points.pair(canvas),"pointer_window":Points.pair(window),"pointer_cell":Points.pair(cell),"cell_size":Points.pair(Vector2.ONE*24*amount),"cell_origin_canvas":Points.pair(WorldProjection.world_to_screen(game,Vector2(cell)*24)),
		"location":game.current_location,"walkable":game.is_position_walkable(game.player),"automatic_physics":game.is_physics_processing(),"automatic_render":game.is_processing(),
		"window":Points.pair(DisplayServer.window_get_size()),"visible":Points.pair(root.get_visible_rect().size),"stretch_scale":Points.pair(root.get_stretch_transform().get_scale()),"window_mode":root.mode,
		"hud_bounds":[0,0,1152,80],"hud_hotbar":[game.HudLayoutSystem.HOTBAR_RESERVED_RECT.position.x,game.HudLayoutSystem.HOTBAR_RESERVED_RECT.position.y,game.HudLayoutSystem.HOTBAR_RESERVED_RECT.size.x,game.HudLayoutSystem.HOTBAR_RESERVED_RECT.size.y]}

## Записывает точные условия; probe и покадровый readback никогда не принимаются как FPS-профиль.
func _save() -> void:
	var report:={"schema":1,"task":"VCAMERA-006","kind":"zoom-probe" if probe else "zoom-native","performance_eligible":false,
		"profile":profile,"pid":OS.get_process_id(),"requested":Points.pair(requested),"initial":initial,"frames":rows,"inputs":sent,"errors":errors,"zoom":amount,
		"physics_hz":30,"video_hz":60,"simulation":"same full GameLoop, two prepared scenes; cut at frame 120", "display_server":DisplayServer.get_name(),"renderer":RenderingServer.get_current_rendering_driver_name(),
		"adapter":RenderingServer.get_video_adapter_name(),"engine":Engine.get_version_info().string,"screen_scale":DisplayServer.screen_get_scale(),"hidpi":ProjectSettings.get_setting("display/window/dpi/allow_hidpi"),
		"content_scale_mode":root.content_scale_mode,"content_scale_size":Points.pair(root.content_scale_size),"content_scale_factor":root.content_scale_factor}
	FileAccess.open(folder.path_join("capture.json"),FileAccess.WRITE).store_string(JSON.stringify(report)+"\n")
