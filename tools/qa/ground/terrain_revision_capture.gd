extends SceneTree

const Points := preload("res://tools/qa/camera/visual_camera_points.gd")
const Soil := preload("res://scripts/presentation/garden_soil.gd")
var folder := ""
var profile := ""
var size := Vector2i(1152,648)
var game: Node
var bg: Node
var rows := []
var errors := []
var operations := []

## Требует отдельный новый профиль и настоящее графическое окно.
func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): folder=arg.trim_prefix("--output=")
		elif arg.begins_with("--profile="): profile=arg.trim_prefix("--profile=")
		elif arg=="--wide": size=Vector2i(1280,720)
	if folder.is_empty() or not profile.begins_with("Codex-VGROUND-009-") or "/" in profile or "\\" in profile:
		push_error("Fresh isolated output/profile required"); quit(2); return
	ProjectSettings.set_setting("application/config/use_custom_user_dir",true)
	ProjectSettings.set_setting("application/config/custom_user_dir_name",profile)
	_start.call_deferred()

## Сравнивает локальные записи с полным эталоном, реальные очереди, влагу и смену окружения.
func _start() -> void:
	if DisplayServer.get_name()=="headless" or DirAccess.dir_exists_absolute(folder) or not OS.get_user_data_dir().ends_with(profile) or FileAccess.file_exists("user://farm-settings.cfg"):
		push_error("Native display and unused isolated paths required"); quit(2); return
	DirAccess.make_dir_recursive_absolute(folder)
	game=Points.create_game(); game.set_script(preload("res://tools/qa/world/render_order_game.gd")); root.add_child(game); current_scene=game
	Points.configure(game,Points.registry().points[0]); preload("res://scripts/systems/world_projection_system.gd").set_reference_zoom(game,1.2)
	bg=game.get_node("WorldBackground"); _environment(1); _place(Vector2(456,984))
	for plot: Dictionary in game.plots.values(): plot.tilled=true; plot.planted=false; plot.watered=false
	root.title="VGROUND-009 | local terrain revision"
	await _settle(1000); root.mode=Window.MODE_WINDOWED; await _settle(800); root.size=size; root.show(); root.grab_focus(); await _settle(800)
	for attempt in 15:
		if root.mode==Window.MODE_WINDOWED and DisplayServer.window_get_size()==size: break
		root.mode=Window.MODE_WINDOWED; root.size=size; await _settle(200)
	if root.mode!=Window.MODE_WINDOWED or DisplayServer.window_get_size()!=size:
		push_error("Native window did not settle"); quit(2); return
	await _drain()
	for local in [false,true]:
		bg.local_terrain_updates=local; bg.set_soft_garden(true); await _drain()
		var prefix: String="local" if local else "full"
		await _shot(prefix+"-before"); _cache(prefix+"-before")
		var before:=_metrics(); bg.set_soft_garden(false)
		var scheduled:=_metrics(); await _first(prefix+"-first"); await _drain()
		await _shot(prefix+"-after"); _cache(prefix+"-after")
		operations.append({"id":prefix,"before":before,"scheduled":scheduled,"after":_metrics(),"rect":_rect(Soil.FARM)})
	bg.set_soft_garden(true); await _drain(); _cache("retained-before")
	var before:=_metrics()
	for rect in [Rect2(780,300,120,120),Rect2(144,240,96,96),Rect2(2016,720,48,48)]: bg.invalidate_terrain_rect(rect)
	var scheduled:=_metrics(); await _drain(); _cache("retained-after")
	operations.append({"id":"disjoint","before":before,"scheduled":scheduled,"after":_metrics()})
	before=_metrics(); bg.set_soft_garden(false); bg.set_soft_garden(true); scheduled=_metrics()
	await _drain(); _cache("rapid-after")
	operations.append({"id":"rapid","before":before,"scheduled":scheduled,"after":_metrics()})
	before=_metrics(); bg.set_soft_garden(false); _environment(15); scheduled=_metrics()
	await _drain(); _cache("global-after")
	operations.append({"id":"global","before":before,"scheduled":scheduled,"after":_metrics()})
	bg.set_soft_garden(true); await _drain(); _environment(1); await _drain()
	await _shot("plot-before"); _cache("plot-before")
	before=_metrics(); var mesh_before:=_meshes(); game.plots[Vector2i(2,2)].watered=true
	await _shot("plot-after"); _cache("plot-after")
	operations.append({"id":"plot","before":before,"after":_metrics(),"meshes_before":mesh_before,"meshes_after":_meshes(),"cell":[2,2]})
	for entry in [["cottage",Vector2(360,648),1],["bridge-west",Vector2(864,456),1],["bridge-east",Vector2(1608,960),1],
		["road-turn",Vector2(2016,744),1],["road-end",Vector2(456,984),1],["summer",Vector2(456,984),8],
		["autumn",Vector2(456,984),15],["winter",Vector2(456,984),22]]:
		_environment(entry[2]); await _drain(); _place(entry[1]); await _redraw(8)
		before=_metrics(); bg.invalidate_terrain_rect(Rect2(entry[1]-Vector2(48,48),Vector2(96,96)))
		await _drain(); await _shot(entry[0]+"-local"); bg.refresh_terrain(); await _drain(); await _shot(entry[0]+"-full")
		operations.append({"id":entry[0],"before":before,"after":_metrics()})
	_environment(1); await _drain(); _place(Vector2(456,984)); await _redraw(8)
	bg.set_meta("terrain_direct",true); bg.queue_redraw(); await _shot("direct-fallback")
	bg.set_meta("terrain_direct",false); bg.queue_redraw(); await _shot("cached-final")
	_cache("idle-before"); before=_metrics(); await _redraw(120); _cache("idle-after")
	operations.append({"id":"idle","callbacks":120,"before":before,"after":_metrics()})
	bg.invalidate_terrain_rect(Rect2(144,816,48,48)); bg.invalidate_terrain_rect(Rect2(1200,600,48,48))
	if not game.BuildingSystem.enter(game,"cottage"): errors.append("house entry failed")
	await _drain(); await _shot("interior")
	if bg.invalidate_terrain_rect(Soil.FARM): errors.append("interior accepted first-map region")
	if not game.BuildingSystem.leave(game): errors.append("house exit failed")
	await _drain(); _place(Vector2(456,984)); await _shot("returned")
	_write("capture.json",{"task":"VGROUND-009","profile":profile,"window":Points.pair(size),"display":DisplayServer.get_name(),
		"engine":Engine.get_version_info().string,"rows":rows,"operations":operations,"errors":errors,"simulation_frozen":true,
		"performance_eligible":false,"gpu_time_ms":null,"plot_water_set_by_fixture":true,"real_tools_in_profile":true})
	quit(0 if errors.is_empty() else 2)

## Сохраняет первый настоящий кадр с прямым fallback до окончания локальной записи.
func _first(id: String) -> void:
	game.draw_records.clear(); game.observe_draw=true; game.queue_redraw(); await RenderingServer.frame_post_draw
	game.observe_draw=false; root.get_texture().get_image().save_png(folder.path_join(id+".png")); _write(id+"-draws.json",game.draw_records)

## Сохраняет полное изображение мира и четыре снимка вокруг настоящего production draw.
func _shot(id: String) -> void:
	game.message=""; game.observe_draw=false; await _redraw(4)
	game.draw_records.clear(); game.observe_draw=true; await _redraw(4); game.observe_draw=false
	var image:=root.get_texture().get_image(); image.save_png(folder.path_join(id+".png")); _write(id+"-draws.json",game.draw_records)
	if image.get_size()!=size or DisplayServer.window_get_size()!=size or not DisplayServer.window_is_focused(): errors.append(id+": size/focus changed")
	rows.append({"id":id,"readback":Points.pair(image.get_size()),"physical":Points.pair(DisplayServer.window_get_size()),"logical":Points.pair(root.get_visible_rect().size),
		"focused":DisplayServer.window_is_focused(),"camera":Points.pair(game.camera_offset),"player":Points.pair(game.player),"zoom":game.get_meta(&"camera_reference_zoom"),
		"location":game.current_location,"season":bg.season,"weather":game.WorldEventSystem.weather(game),"garden":bg.soft_garden,"draws":game.draw_records.size(),
		"snapshot":game.SaveSystem.snapshot(game),"metrics":_metrics()})
	print("TERRAIN REVISION SHOT ",id)

## Читает точный GPU-кеш только в QA; production не копирует карту через CPU.
func _cache(id: String) -> void:
	bg.terrain_viewport.get_texture().get_image().save_png(folder.path_join(id+"-cache.png"))

## Отделяет ревизии, размеры и идентичность ресурсов от выдуманного GPU-времени.
func _metrics() -> Dictionary:
	var state:Dictionary=bg.terrain_revision.snapshot()
	state.active=_rect(state.active); state.last_completed=_rect(state.last_completed)
	state.pending=state.pending.map(func(r:Rect2): return _rect(r))
	return {"revision":state,"requests":bg.terrain_requests,"paints":bg.terrain_canvas.paint_count,"ready":bg.terrain_ready,
		"clip":_rect(Rect2(bg.terrain_clip.position,bg.terrain_clip.size)),"clear_mode":bg.terrain_viewport.render_target_clear_mode,
		"target_size":Points.pair(bg.terrain_viewport.size),"texture_id":bg.terrain_viewport.get_texture().get_instance_id(),
		"target_id":bg.terrain_viewport.get_instance_id(),"children":bg.get_children().size(),"targets":bg.get_children().filter(func(n:Node): return n is SubViewport).size()}

## Запоминает текущие меши тридцати домашних клеток, оставляя владение игровому CanvasItem.
func _meshes() -> Dictionary:
	var result:={}
	for cell:Vector2i in game.get_meta(&"garden_soil_meshes",{}): result[str(cell)]=game.get_meta(&"garden_soil_meshes")[cell].mesh.get_instance_id()
	return result

## Ждёт реального окончания ограниченной очереди, не заменяя его фиксированным числом кадров.
func _drain() -> void:
	for i in 100:
		await _redraw(1)
		if bg.terrain_ready and bg.terrain_revision.pending.is_empty() and not bg.terrain_revision.active.has_area(): return
	errors.append("terrain completion did not drain")

## Фиксирует календарь и реальную ясную погоду, включая интерьер.
func _environment(day: int) -> void:
	game.day=day; game.state.world.weather_day=day; game.state.world.weather="clear"
	bg.set_environment(game.WorldEventSystem.season(day),"clear")

## Устанавливает одинаковую позу и камеру для сравнения двух способов обновления.
func _place(player: Vector2) -> void:
	game.player=player; game.facing=Vector2.DOWN; game.update_camera(); preload("res://scripts/systems/presentation_pose_system.gd").reset(game)

## Ждёт callbacks без симуляции и без заявления FPS.
func _redraw(count: int) -> void:
	for i in count: game.queue_redraw(); await RenderingServer.frame_post_draw

## Даёт оконному серверу закончить размещение окна.
func _settle(ms: int) -> void:
	var deadline:=Time.get_ticks_msec()+ms
	while Time.get_ticks_msec()<deadline: game.queue_redraw(); await RenderingServer.frame_post_draw

## Сохраняет числовую геометрию без строкового округления.
func _rect(rect: Rect2) -> Array:
	return [rect.position.x,rect.position.y,rect.size.x,rect.size.y]

## Пишет только в свежий каталог доказательств.
func _write(name: String, value: Variant) -> void:
	FileAccess.open(folder.path_join(name),FileAccess.WRITE).store_string(JSON.stringify(value)+"\n")
