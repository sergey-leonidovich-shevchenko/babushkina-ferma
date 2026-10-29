extends SceneTree

const Points := preload("res://tools/visual_camera_points.gd")
const Observer := preload("res://tools/render_order_game.gd")
const ProjectionSystem := preload("res://scripts/systems/world_projection_system.gd")
const Pose := preload("res://scripts/systems/presentation_pose_system.gd")
var folder := ""
var profile := ""
var size := Vector2i(1152,648)
var game: Node
var bg: Node
var rows := []
var errors := []

## Разрешает только отдельный свежий профиль и настоящее графическое окно.
func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): folder=arg.trim_prefix("--output=")
		elif arg.begins_with("--profile="): profile=arg.trim_prefix("--profile=")
		elif arg=="--wide": size=Vector2i(1280,720)
	if folder.is_empty() or not profile.begins_with("Codex-VGROUND-003-") or "/" in profile or "\\" in profile:
		push_error("Fresh separate output/profile required"); quit(2); return
	ProjectSettings.set_setting("application/config/use_custom_user_dir",true)
	ProjectSettings.set_setting("application/config/custom_user_dir_name",profile)
	_start.call_deferred()

## Снимает деревню до/после, сезоны, возврат, холодный fallback и отдельные листы стыков/маски.
func _start() -> void:
	if DisplayServer.get_name()=="headless" or DirAccess.dir_exists_absolute(folder) or not OS.get_user_data_dir().ends_with(profile) or FileAccess.file_exists("user://farm-settings.cfg"):
		push_error("Native display and unused isolated paths required"); quit(2); return
	DirAccess.make_dir_recursive_absolute(folder)
	game=Points.create_game(); game.set_script(Observer); root.add_child(game); current_scene=game
	Points.configure(game,Points.registry().points[0]); ProjectionSystem.set_reference_zoom(game,1.2); bg=game.get_node("WorldBackground")
	root.title="VGROUND-003 | soft ground edges"
	await _settle(1000); root.mode=Window.MODE_WINDOWED; await _settle(800); root.size=size; root.show(); root.grab_focus(); await _settle(800)
	for season in ["spring","summer","autumn","winter"]:
		bg.set_environment(season,"clear"); await _pair(season,Vector2(600.25,700.25))
	bg.set_environment("spring","rain"); await _pair("rain",Vector2(600.25,700.25))
	bg.set_environment("spring","clear")
	await _pair("bridge-west",game.VillageLayoutSystem.BRIDGES[0].get_center())
	await _pair("bridge-east",game.VillageLayoutSystem.BRIDGES[1].get_center())
	if not game.BuildingSystem.enter(game,"cottage"): errors.append("actual house entry failed")
	await _pair("interior",game.player)
	if not game.BuildingSystem.leave(game): errors.append("actual house exit failed")
	await _pair("returned",Vector2(600.25,700.25))
	bg.set_soft_ground_edges(true); bg.set_meta("terrain_direct",true); bg.queue_redraw(); await _redraw(8); await _shot("direct")
	bg.set_meta("terrain_direct",false); bg.queue_redraw(); await _redraw(8); await _shot("cached")
	bg.refresh_terrain(); game.draw_records.clear(); game.observe_draw=true; game.queue_redraw()
	await RenderingServer.frame_post_draw
	game.observe_draw=false; root.get_texture().get_image().save_png(folder.path_join("cold-first.png"))
	_write("cold-first-draws.json",game.draw_records)
	var count: int=bg.terrain_canvas.paint_count; var requests: int=bg.terrain_requests
	var before := _hash_cache()
	await _redraw(120)
	_write("retained.json",{"callbacks":120,"paints_before":count,"paints_after":bg.terrain_canvas.paint_count,"requests_before":requests,"requests_after":bg.terrain_requests,"hash_before":before,"hash_after":_hash_cache()})
	await _board("before","spring"); await _board("after","spring"); await _board("mask","spring"); await _board("recolor","spring"); await _board("after","winter")
	_write("capture.json",{"task":"VGROUND-003","profile":profile,"window":Points.pair(size),"engine":Engine.get_version_info().string,
		"display":DisplayServer.get_name(),"driver":RenderingServer.get_current_rendering_driver_name(),"rows":rows,"errors":errors,
		"simulation_frozen":true,"performance_eligible":false,"season_preview_only":true,"gpu_time_ms":null,
		"material":{"size":Points.pair(preload("res://scripts/presentation/meadow_ground.gd").SOURCE.get_size()),"image_bytes":preload("res://scripts/presentation/meadow_ground.gd").SOURCE.get_image().get_data().size(),"cell_world":192,"scale":1.2}})
	quit(0 if errors.is_empty() else 2)

## Переключает только кромку при неизменных позе, камере и состоянии мира.
func _pair(id: String, player: Vector2) -> void:
	game.player=player; game.facing=Vector2.DOWN; game.update_camera(); Pose.reset(game)
	for enabled in [false,true]:
		bg.set_soft_ground_edges(enabled); await _redraw(8); await _shot(id+("-after" if enabled else "-before"))

## Сохраняет полный настоящий кадр и четыре полных снимка вокруг штатного draw.
func _shot(id: String) -> void:
	game.message=""; game.observe_draw=false; await _redraw(4)
	game.draw_records.clear(); game.observe_draw=true; await _redraw(4); game.observe_draw=false
	var image := root.get_texture().get_image(); image.save_png(folder.path_join(id+".png")); _write(id+"-draws.json",game.draw_records)
	if image.get_size()!=size or DisplayServer.window_get_size()!=size or not DisplayServer.window_is_focused(): errors.append(id+": readback/window/focus changed")
	rows.append({"id":id,"readback":Points.pair(image.get_size()),"logical":Points.pair(root.get_visible_rect().size),"camera":Points.pair(game.camera_offset),
		"player":Points.pair(game.player),"location":game.current_location,"season":bg.season,"weather":bg.weather,"soft_edges":bg.soft_ground_edges,
		"draws":game.draw_records.size(),"ready":bg.terrain_ready,"viewports":bg.get_children().filter(func(n:Node): return n is SubViewport).size(),
		"snapshot":game.SaveSystem.snapshot(game),"draw_calls":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
		"focused":DisplayServer.window_is_focused(),"physical":Points.pair(DisplayServer.window_get_size()),"zoom":game.get_meta(&"camera_reference_zoom")})
	print("EDGE SHOT ",id)

## Снимает стыки в игровом масштабе и отдельные прозрачные листы маски и сменного цвета.
func _board(kind: String, season: String) -> void:
	var view := SubViewport.new(); view.size=Vector2i(1152,1152); view.disable_3d=true; view.transparent_bg=true; view.render_target_update_mode=SubViewport.UPDATE_ONCE
	var board := preload("res://tools/qa/ground/ground_edge_board.gd").new(); board.kind=kind; board.season=season; board.scale=Vector2.ONE*1.2
	board.texture_repeat=CanvasItem.TEXTURE_REPEAT_ENABLED; root.add_child(view); view.add_child(board)
	await RenderingServer.frame_post_draw
	var image := view.get_texture().get_image()
	if image.get_size()!=Vector2i(1152,1152): errors.append("offscreen board size changed")
	image.save_png(folder.path_join("edges-"+kind+"-"+season+".png")); view.queue_free(); await process_frame

## Проверяет неизменность настоящей RGBA-текстуры кеша между callbacks, не подменяя её счётчиком.
func _hash_cache() -> String:
	var hash := HashingContext.new(); hash.start(HashingContext.HASH_SHA256); hash.update(bg.terrain_viewport.get_texture().get_image().get_data())
	return hash.finish().hex_encode()

## Ждёт реальные GPU callbacks; эти ожидания не являются замерами FPS.
func _redraw(count: int) -> void:
	for i in count: game.queue_redraw(); await RenderingServer.frame_post_draw

## Даёт оконному серверу закончить размещение окна.
func _settle(ms: int) -> void:
	var deadline := Time.get_ticks_msec()+ms
	while Time.get_ticks_msec()<deadline: game.queue_redraw(); await RenderingServer.frame_post_draw

## Пишет свидетельства без доступа к обычному каталогу пользователя.
func _write(name: String, value: Variant) -> void:
	FileAccess.open(folder.path_join(name),FileAccess.WRITE).store_string(JSON.stringify(value)+"\n")
