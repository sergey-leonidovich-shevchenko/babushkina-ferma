extends SceneTree

const Points := preload("res://tools/visual_camera_points.gd")
const Actor := preload("res://scripts/systems/animation_renderer.gd")
const Visual := preload("res://scripts/systems/hero_visual_system.gd")
const Legacy := preload("res://docs/reports/visual-overhaul/vcamera-002/legacy_camera_system.gd")
const RATE := 60
const COUNT := 180
const STARTS := [Vector2(562.25,672.25),Vector2(60.25,672.25)]
var folder := ""
var profile := ""
var requested := Vector2i.ZERO
var snap := false
var probe := false
var game: Node
var overlay: Markers
var rows := []
var errors := []
var sent := []
var initial := {}

class Markers extends Node2D:
	var foot := Vector2.ZERO
	var cell := Vector2.ZERO
	var pointer := Vector2.ZERO
	var received := Vector2.INF
	var label := ""
	## Наблюдает логический ввод после штатного преобразования окна движком.
	func _input(event: InputEvent) -> void:
		if event is InputEventMouseMotion: received=event.position
	## Отмечает реальные опоры, клетку и контрольный пиксель, не меняя игровой рисунок.
	func _draw() -> void:
		draw_line(foot-Vector2(7,0),foot+Vector2(7,0),Color.YELLOW,1)
		draw_line(foot-Vector2(0,7),foot+Vector2(0,7),Color.YELLOW,1)
		draw_rect(Rect2(cell,Vector2(24,24)),Color.CYAN,false,1)
		draw_circle(pointer,3,Color.CYAN)
		draw_rect(Rect2(16,160,8,8),Color.MAGENTA)
		draw_rect(Rect2(220,146,910,34),Color(0.02,0.03,0.03,0.93))
		draw_string(ThemeDB.fallback_font,Vector2(232,169),label,HORIZONTAL_ALIGNMENT_LEFT,-1,16,Color.WHITE)

## Выбирает только новый профиль и одну из трёх явно разрешённых физических конфигураций.
func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): folder=arg.trim_prefix("--output=")
		elif arg.begins_with("--profile="): profile=arg.trim_prefix("--profile=")
		elif arg.begins_with("--size="):
			var size:=arg.trim_prefix("--size=").split("x"); requested=Vector2i(int(size[0]),int(size[1]))
		elif arg=="--snap": snap=true
		elif arg=="--probe": probe=true
	if folder.is_empty() or not profile.begins_with("Codex-VCAMERA-002-") or "/" in profile or "\\" in profile or requested not in [Vector2i(1152,648),Vector2i(1920,1080),Vector2i(2304,1296)]:
		push_error("Need isolated VCAMERA-002 profile, fresh output and approved size"); quit(2); return
	ProjectSettings.set_setting("application/config/use_custom_user_dir",true)
	ProjectSettings.set_setting("application/config/custom_user_dir_name",profile)
	_start.call_deferred()

## Записывает две отдельные подготовленные сцены: переход к слежению и левый край карты.
## Мир продвигается обычным GameLoop фиксированными шагами; это диагностическое видео, не FPS.
func _start() -> void:
	if (DisplayServer.get_name()=="headless" and not probe) or not OS.get_user_data_dir().ends_with(profile) or FileAccess.file_exists("user://farm-settings.cfg") or DirAccess.dir_exists_absolute(folder):
		push_error("Need native display and new output/profile"); quit(2); return
	DirAccess.make_dir_recursive_absolute(folder.path_join("frames"))
	game=Points.create_game(); root.add_child(game); current_scene=game
	Points.configure(game,Points.registry().points[0])
	if not probe:
		root.title="VCAMERA-002 | "+("rounded" if snap else "fractional")+" | diagnostic only"
		await _settle(2000); root.mode=Window.MODE_WINDOWED
		await _settle(2000); root.size=requested; root.grab_focus(); await _settle(2000)
		initial={"window":Points.pair(DisplayServer.window_get_size()),"root":Points.pair(root.size),"focused":DisplayServer.window_is_focused(),"mode":root.mode}
		if DisplayServer.window_get_size()!=requested or root.size!=requested or not DisplayServer.window_is_focused():
			errors.append("initial window/focus"); _save(); quit(2); return
		overlay=Markers.new(); root.add_child(overlay)
	for stage in 2:
		Points.configure(game,Points.registry().points[0])
		game.player=STARTS[stage]; game.speed=18.0; game.clear_movement_keys(); game.update_camera()
		_key(KEY_D if stage==0 else KEY_A,true); _key(KEY_S,true)
		for frame in COUNT:
			if frame>0: game.GameLoop.physics_process(game,1.0/RATE)
			if snap:
				game.camera_offset=Legacy.target_offset(game)
				game.get_node("WorldBackground").position=-game.camera_offset
			var row:=_measure(stage,frame)
			if not probe:
				overlay.foot=Points.vector(row.foot_canvas); overlay.cell=Points.vector(row.cell_origin_canvas)
				overlay.pointer=Points.vector(row.pointer_canvas)
				overlay.label="VCAMERA-002 | "+("A rounded" if snap else "B fractional")+" | "+("follow threshold" if stage==0 else "world edge (new scene)")
				game.queue_redraw(); overlay.queue_redraw(); await RenderingServer.frame_post_draw
				var image:=root.get_texture().get_image()
				row.readback=Points.pair(image.get_size()); row.focused=DisplayServer.window_is_focused()
				row.foot_pixel=_pixel_matches(image,Points.vector(row.foot_canvas)*root.get_stretch_transform().get_scale(),Color.YELLOW)
				row.fiducial=_pixel_matches(image,Vector2(20,164)*root.get_stretch_transform().get_scale(),Color.MAGENTA)
				if image.get_size()!=requested or not row.focused or not row.foot_pixel or not row.fiducial: errors.append("readback/focus/pixels at "+str(row.index))
				if image.save_png(folder.path_join("frames/%04d.png"%row.index))!=OK: errors.append("PNG write")
			rows.append(row)
		_key(KEY_D if stage==0 else KEY_A,false); _key(KEY_S,false)
	_save(); print("QUANTIZATION: ",rows.size()," rows; ",errors)
	quit(0 if errors.is_empty() else 2)

## Посылает настоящую клавишу через игровой маршрутизатор, без изменения физической позиции в проходе.
func _key(key: Key, pressed: bool) -> void:
	var event:=InputEventKey.new(); event.physical_keycode=key; event.pressed=pressed
	game._input(event)
	sent.append({"after_rows":rows.size(),"key":OS.get_keycode_string(key),"pressed":pressed})

## Сверяет опору, проекцию и обратный ввод; из нативной геометрии не выводится неподтверждённый DPI.
func _measure(stage: int, frame: int) -> Dictionary:
	var raw:Vector2=game.CameraSystem.target_offset(game)
	var pose:=Visual.current_pose(game,game.facing,true)
	var destination:=Visual.destination(Actor.player_ground(game),pose)
	var foot:Vector2=destination.position+Vector2(pose.pivot)*float(pose.scale)
	var pointer_world:=Vector2(600.0+(-0.125 if frame%2==0 else 0.125),696.125)
	if stage==1: pointer_world=Vector2([0.125,23.875,24.125][frame%3],720.125)
	var pointer_canvas:Vector2=pointer_world-game.camera_offset
	var window:Vector2=root.get_final_transform()*pointer_canvas
	var received:=pointer_canvas
	if not probe:
		overlay.received=Vector2.INF
		var motion:=InputEventMouseMotion.new(); motion.position=window; motion.global_position=window
		root.push_input(motion,false); received=overlay.received
	var restored:Vector2=received+game.camera_offset
	var cell:Vector2i=game.FenceSystem.target_cell(game,restored)
	if game.current_location!="overworld" or not game.is_position_walkable(game.player) or game.GameLoop.modal_active(game) or game.GameLoop.gameplay_window_open(game): errors.append("blocked/modal/location at "+str(rows.size()))
	if foot.distance_to(game.player)>0.001 or restored.distance_to(pointer_world)>0.001 or cell!=Vector2i(floori(pointer_world.x/24),floori(pointer_world.y/24)): errors.append("foot/pointer at "+str(rows.size()))
	return {"index":rows.size(),"stage":stage,"frame":frame,"location":game.current_location,"player":Points.pair(game.player),"camera":Points.pair(game.camera_offset),"unsnapped":Points.pair(raw),"background":Points.pair(game.get_node("WorldBackground").position),
		"foot_world":Points.pair(foot),"foot_canvas":Points.pair(foot-game.camera_offset),"pointer_canvas":Points.pair(pointer_canvas),"pointer_window":Points.pair(window),"pointer_received":Points.pair(received),"pointer_world":Points.pair(restored),"pointer_cell":Points.pair(cell),
		"cell_origin_canvas":Points.pair(Vector2(cell)*24-game.camera_offset),"minutes":game.game_minutes,"walkable":game.is_position_walkable(game.player),"facing":Points.pair(game.facing),"delta":0.0 if frame==0 else 1.0/RATE,
		"movement":Points.pair(game.get_movement_direction()),"automatic_physics":game.is_physics_processing(),
		"window":Points.pair(DisplayServer.window_get_size()),"visible":Points.pair(root.get_visible_rect().size),"texture_reported_size":Points.pair(root.get_texture().get_size()),"stretch_scale":Points.pair(root.get_stretch_transform().get_scale()),"window_mode":root.mode}

## Даёт настоящему окну установиться по монотонным часам до фиксированной записи.
func _settle(milliseconds: int) -> void:
	var deadline:=Time.get_ticks_msec()+milliseconds
	while Time.get_ticks_msec()<deadline: game.queue_redraw(); await RenderingServer.frame_post_draw

## Проверяет реальный GPU-пиксель с допуском одного физического пикселя на растрирование.
func _pixel_matches(image: Image, point: Vector2, color: Color) -> bool:
	for y in range(roundi(point.y)-1,roundi(point.y)+2):
		for x in range(roundi(point.x)-1,roundi(point.x)+2):
			if x>=0 and y>=0 and x<image.get_width() and y<image.get_height():
				var actual:=image.get_pixel(x,y)
				if absf(actual.r-color.r)+absf(actual.g-color.g)+absf(actual.b-color.b)<0.04: return true
	return false

## Сохраняет все наблюдения, включая ошибки; headless никогда не становится нативным доказательством.
func _save() -> void:
	var actual_steps:=0
	for row in rows:
		if int(row.frame)>0: actual_steps+=1
	var report:={"schema":1,"kind":"quantization-probe" if probe else "quantization-native","performance_eligible":false,"simulation":"controlled full GameLoop at 60 Hz with routed diagonal keys; two prepared scenes, cut at 180",
		"profile":profile,"pid":OS.get_process_id(),"snap":snap,"requested":Points.pair(requested),"frames":rows,"errors":errors,"fps":RATE,"inputs":sent,"manual_steps":actual_steps,"initial":initial,
		"engine":Engine.get_version_info().string,"display_server":DisplayServer.get_name(),"renderer":RenderingServer.get_current_rendering_driver_name(),"adapter":RenderingServer.get_video_adapter_name(),
		"screen_scale":DisplayServer.screen_get_scale(),"screen_dpi":DisplayServer.screen_get_dpi(),"screen_size":Points.pair(DisplayServer.screen_get_size()),"hidpi":ProjectSettings.get_setting("display/window/dpi/allow_hidpi"),
		"content_scale_mode":root.content_scale_mode,"content_scale_size":Points.pair(root.content_scale_size),"content_scale_factor":root.content_scale_factor}
	FileAccess.open(folder.path_join("capture.json"),FileAccess.WRITE).store_string(JSON.stringify(report)+"\n")
