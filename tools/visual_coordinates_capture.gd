extends SceneTree

const Points := preload("res://tools/visual_camera_points.gd")
const AnimationRenderer := preload("res://scripts/systems/animation_renderer.gd")
const Visual := preload("res://scripts/systems/hero_visual_system.gd")
const Scale := preload("res://scripts/systems/ui_scale_system.gd")
const FPS := 24
const FRAMES := 96
var folder := ""
var profile := ""
var requested := Vector2i.ZERO
var game: Node2D
var overlay: AuditOverlay
var rows := []
var faults := []

class AuditOverlay extends Node2D:
	var sample := {}
	var pointer := Vector2.INF
	## Принимает событие после штатного преобразования окна в логический холст движком.
	func _input(event: InputEvent) -> void:
		if event is InputEventMouseMotion: pointer=event.position

	## Рисует проверочные метки поверх настоящей сцены, не меняя её масштаб и геометрию.
	func _draw() -> void:
		if sample.is_empty(): return
		var foot:Vector2=sample.foot_canvas; var target:Vector2=sample.target_canvas
		draw_line(foot,target,Color("ffca66"),1)
		draw_circle(target,3,Color("ffca66"))
		draw_line(foot-Vector2(9,0),foot+Vector2(9,0),Color.YELLOW,1)
		draw_line(foot-Vector2(0,9),foot+Vector2(0,9),Color.YELLOW,1)
		draw_rect(Rect2(foot-Vector2.ONE*2,Vector2.ONE*4),Color.YELLOW)
		draw_rect(sample.cell_canvas,Color.CYAN,false,1)
		draw_circle(pointer,3,Color.CYAN)
		draw_rect(Rect2(16,160,8,8),Color.MAGENTA)
		draw_rect(Rect2(300,146,700,38),Color(0.05,0.07,0.08,0.92))
		draw_string(ThemeDB.fallback_font,Vector2(312,171),"VCAMERA-001 | feet = physics | cyan = pointer / 24px cell",HORIZONTAL_ALIGNMENT_LEFT,-1,16,Color.WHITE)

## Создаёт свежий профиль до загрузки игры; пользовательские слоты не читаются.
func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): folder=arg.trim_prefix("--output=")
		elif arg.begins_with("--profile="): profile=arg.trim_prefix("--profile=")
		elif arg.begins_with("--size="):
			var parts:=arg.trim_prefix("--size=").split("x"); requested=Vector2i(int(parts[0]),int(parts[1]))
	if folder.is_empty() or not profile.begins_with("Codex-VCAMERA-001-") or "/" in profile or "\\" in profile or requested not in [Vector2i(1152,648),Vector2i(1920,1080),Vector2i(2304,1296),Vector2i(1024,768)]:
		push_error("Нужны новый output, изолированный profile и разрешённый size"); quit(2); return
	ProjectSettings.set_setting("application/config/use_custom_user_dir",true)
	ProjectSettings.set_setting("application/config/custom_user_dir_name",profile)
	_start.call_deferred()

## Воспроизводит медленный шаг настоящим движением и считывает каждый завершённый нативный кадр.
func _start() -> void:
	if DisplayServer.get_name()=="headless" or not OS.get_user_data_dir().ends_with(profile) or FileAccess.file_exists("user://farm-settings.cfg"):
		push_error("Нужны нативная графика и свежий профиль"); quit(2); return
	DirAccess.make_dir_recursive_absolute(folder.path_join("frames"))
	game=Points.create_game(); root.add_child(game); current_scene=game
	Points.configure(game,Points.registry().points[0])
	# Сохраняем проектный canvas_items; прежние стенды отключали масштабирование и для этой задачи непригодны.
	root.title="VCAMERA-001 · координаты · "+str(requested)
	await create_timer(2.0).timeout; root.mode=Window.MODE_WINDOWED
	await create_timer(2.0).timeout; root.size=requested; root.grab_focus()
	await create_timer(2.0).timeout
	game.player=Vector2(556.25,672.25); game.speed=18.0; game.facing=Vector2.RIGHT
	game.update_camera()
	var key:=InputEventKey.new(); key.physical_keycode=KEY_D; key.pressed=true
	game.GameInputRouter.route(game,key)
	overlay=AuditOverlay.new(); root.add_child(overlay)
	for frame in FRAMES:
		if frame>0: game.update_player_movement(1.0/FPS); game.update_camera()
		var row:=_measure(frame)
		overlay.sample={"foot_canvas":Points.vector(row.foot_canvas),"target_canvas":Points.vector(row.target_canvas),"cell_canvas":Rect2(Points.vector(row.cell_origin_canvas),Vector2(24,24))}
		game.queue_redraw(); overlay.queue_redraw()
		await RenderingServer.frame_post_draw
		var image:=root.get_texture().get_image()
		row.readback=Points.pair(image.get_size()); row.focused=DisplayServer.window_is_focused()
		row.fiducial=_pixel_matches(image,Points.vector(row.fiducial_framebuffer),Color.MAGENTA)
		row.foot_pixel=_pixel_matches(image,Points.vector(row.foot_framebuffer),Color.YELLOW)
		var expected_readback:=Vector2i((root.get_visible_rect().size*root.get_stretch_transform().get_scale()).round())
		if image.get_size()!=expected_readback or not row.focused or not row.fiducial or not row.foot_pixel: faults.append("frame %d: readback/focus/marker"%frame)
		if image.save_png(folder.path_join("frames/%04d.png"%frame))!=OK: faults.append("PNG write")
		rows.append(row)
	key.pressed=false; game.GameInputRouter.route(game,key)
	var report:={"schema":1,"kind":"coordinate-contract-native","performance_eligible":false,"simulation":"controlled player-only step; world frozen", "input":"synthetic window-space mouse through Viewport.push_input(false); physical mouse not tested", "fps":FPS,"frames":rows,
		"profile":profile,"engine":Engine.get_version_info().string,"renderer":RenderingServer.get_current_rendering_driver_name(),"display_server":DisplayServer.get_name(),"adapter":RenderingServer.get_video_adapter_name(),
		"screen_size":Points.pair(DisplayServer.screen_get_size()),"screen_scale":DisplayServer.screen_get_scale(),"screen_dpi":DisplayServer.screen_get_dpi(),"hidpi":ProjectSettings.get_setting("display/window/dpi/allow_hidpi"),
		"content_scale_mode":root.content_scale_mode,"content_scale_size":Points.pair(root.content_scale_size),"content_scale_factor":root.content_scale_factor,"content_scale_aspect":root.content_scale_aspect,"window_position":Points.pair(root.position),"errors":faults}
	FileAccess.open(folder.path_join("capture.json"),FileAccess.WRITE).store_string(JSON.stringify(report,"\t")+"\n")
	for fault in faults: push_error(fault)
	print("COORDINATES: ",rows.size()," native frames, ",faults.size()," errors, ",requested)
	quit(0 if faults.is_empty() else 2)

## Сопоставляет реальный ввод, стопы и шаг сетки с фактическими преобразованиями окна.
func _measure(frame: int) -> Dictionary:
	var canvas:=Vector2(0.01+fmod(frame*3.125,144.0),420.25)
	var transform:=root.get_final_transform()
	var physical:=transform*canvas
	var motion:=InputEventMouseMotion.new(); motion.position=physical; motion.global_position=physical
	overlay.pointer=Vector2.INF; root.push_input(motion,false)
	var received:=overlay.pointer
	var world:Vector2=received+game.camera_offset
	var expected_world:Vector2=canvas+game.camera_offset
	var cell:Vector2i=game.FenceSystem.target_cell(game,world)
	var pose:=Visual.current_pose(game,Vector2.RIGHT,true)
	var destination:=Visual.destination(AnimationRenderer.player_ground(game),pose)
	var actual_foot:=destination.position+Vector2(pose.pivot)*float(pose.scale)
	var foot_canvas:Vector2=actual_foot+game.PresentationSystem.world_offset(game)
	var ui:=Scale.viewport_layout(Vector2(requested))
	var expected_window:Vector2=Vector2(ui.offset)+canvas*float(ui.scale)
	if received.distance_to(canvas)>0.001 or world.distance_to(expected_world)>0.001: faults.append("frame %d: pointer inverse"%frame)
	if cell!=game.FenceSystem.target_cell(game,expected_world): faults.append("frame %d: pointer cell"%frame)
	if actual_foot.distance_to(game.player)>0.001 or physical.distance_to(expected_window)>0.001: faults.append("frame %d: foot/window mapping"%frame)
	if not game.is_position_walkable(game.player): faults.append("frame %d: blocked route"%frame)
	return {"frame":frame,"time":frame/float(FPS),"location":game.current_location,"player":Points.pair(game.player),"camera":Points.pair(game.camera_offset),"foot_world":Points.pair(actual_foot),"foot_canvas":Points.pair(foot_canvas),"foot_window":Points.pair(transform*foot_canvas),"legacy_foot_error":Points.pair(game.player.round()-game.player),
		"target_canvas":Points.pair(game.player+game.facing*42.0-game.camera_offset),"pointer_requested":Points.pair(canvas),"pointer_window":Points.pair(physical),"pointer_received":Points.pair(received),"pointer_world":Points.pair(world),"pointer_cell":Points.pair(cell),"cell_origin_canvas":Points.pair(Vector2(cell)*24-game.camera_offset),
		"window":Points.pair(DisplayServer.window_get_size()),"visible":Points.pair(root.get_visible_rect().size),"texture_reported_size":Points.pair(root.get_texture().get_size()),"window_mode":DisplayServer.window_get_mode(),"background":Points.pair(game.get_node("WorldBackground").position),
		"final_transform":_matrix(transform),"stretch_transform":_matrix(root.get_stretch_transform()),"canvas_transform":_matrix(root.canvas_transform),"node_transform":_matrix(game.get_global_transform_with_canvas()),"screen_transform":_matrix(root.get_screen_transform()),"fiducial_window":Points.pair(transform*Vector2(20,164)),
		"fiducial_framebuffer":Points.pair(root.get_stretch_transform()*Vector2(20,164)),"foot_framebuffer":Points.pair(root.get_stretch_transform()*foot_canvas)}

## Проверяет цвет в реальном framebuffer, разрешая только один пиксель растрирования вокруг математической точки.
func _pixel_matches(image: Image, point: Vector2, color: Color) -> bool:
	for y in range(roundi(point.y)-1,roundi(point.y)+2):
		for x in range(roundi(point.x)-1,roundi(point.x)+2):
			if x>=0 and y>=0 and x<image.get_width() and y<image.get_height():
				var actual:=image.get_pixel(x,y)
				if absf(actual.r-color.r)+absf(actual.g-color.g)+absf(actual.b-color.b)<0.04: return true
	return false

## Сохраняет базис и перенос матрицы без сокращения до одного условного масштаба.
func _matrix(value: Transform2D) -> Array:
	return [Points.pair(value.x),Points.pair(value.y),Points.pair(value.origin)]
