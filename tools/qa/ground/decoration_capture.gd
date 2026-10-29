extends SceneTree

const Points := preload("res://tools/visual_camera_points.gd")
const Rules := preload("res://scripts/presentation/village_decoration_rules.gd")
const Map := preload("res://scripts/systems/village_map_data.gd")
var folder := ""
var profile := ""
var size := Vector2i(1152,648)
var game: Node
var bg: Node
var overlay: Node2D
var rows := []
var errors := []

## Требует настоящее окно, новый каталог и отдельный QA-профиль.
func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): folder=arg.trim_prefix("--output=")
		elif arg.begins_with("--profile="): profile=arg.trim_prefix("--profile=")
		elif arg=="--wide": size=Vector2i(1280,720)
	if folder.is_empty() or not profile.begins_with("Codex-VGROUND-008-") or "/" in profile or "\\" in profile:
		push_error("Fresh isolated output/profile required"); quit(2); return
	ProjectSettings.set_setting("application/config/use_custom_user_dir",true)
	ProjectSettings.set_setting("application/config/custom_user_dir_name",profile)
	_start.call_deferred()

## Сравнивает штатную сцену и явно обозначенный запасной посев, не создавая новых игровых цветов.
func _start() -> void:
	if DisplayServer.get_name()=="headless" or DirAccess.dir_exists_absolute(folder) or not OS.get_user_data_dir().ends_with(profile) or FileAccess.file_exists("user://farm-settings.cfg"):
		push_error("Native display and unused isolated paths required"); quit(2); return
	DirAccess.make_dir_recursive_absolute(folder)
	game=Points.create_game(); game.set_script(preload("res://tools/render_order_game.gd")); root.add_child(game); current_scene=game
	Points.configure(game,Points.registry().points[0])
	preload("res://scripts/systems/world_projection_system.gd").set_reference_zoom(game,1.2)
	bg=game.get_node("WorldBackground"); overlay=preload("res://tools/qa/ground/decoration_overlay.gd").new(); bg.add_child(overlay)
	root.title="VGROUND-008 | decoration exclusions (diagnostic fallback)"
	await _settle(1000); root.mode=Window.MODE_WINDOWED; await _settle(800); root.size=size; root.show(); root.grab_focus(); await _settle(800)
	for attempt in 15:
		if root.mode==Window.MODE_WINDOWED and DisplayServer.window_get_size()==size: break
		root.mode=Window.MODE_WINDOWED; root.size=size; await _settle(200)
	if root.mode!=Window.MODE_WINDOWED or DisplayServer.window_get_size()!=size:
		push_error("Native size did not settle"); quit(2); return
	for entry in [
		["cottage",Vector2(360,648),1,"clear"],["services",Vector2(1392,624),1,"clear"],
		["farm",Vector2(456,984),1,"clear"],["bridge-west",Map.BRIDGES[0].get_center(),1,"clear"],
		["bridge-east",Map.BRIDGES[1].get_center(),1,"clear"],["road-turn",Vector2(2016,744),1,"clear"],
		["road-end",Vector2(1704,864),1,"clear"],["summer",Vector2(360,648),8,"clear"],
		["autumn",Vector2(360,648),15,"clear"],["winter",Vector2(360,648),22,"clear"],
		["rain",Vector2(360,648),1,"rain"]]:
		game.day=entry[2]; game.state.world.weather_day=game.day; game.state.world.weather=entry[3]
		bg.set_environment(game.WorldEventSystem.season(game.day),entry[3]); await _case(entry[0],entry[1])
	game.state.world.weather="clear"; bg.set_environment("spring","clear")
	if not game.BuildingSystem.enter(game,"cottage"): errors.append("house entry failed")
	await _case("interior",game.player)
	if not game.BuildingSystem.leave(game): errors.append("house exit failed")
	await _case("returned",Vector2(360,648))
	await _board(false); await _board(true)
	var zones:=[]; var candidates:=[]; var plan:=Rules.legacy_plan()
	for zone in Rules.exclusions(): zones.append({"id":zone.id,"reason":zone.reason,"rect":_rect(zone.rect)})
	for row in Rules.legacy_candidates(): candidates.append({"position":Points.pair(row.position),"rect":_rect(row.rect),"reason":Rules.reason(row.rect)})
	_write("policy.json",{"margin":Rules.MARGIN,"limit":Rules.LIMIT,"world":Points.pair(Map.WORLD_SIZE),"zones":zones,"candidates":candidates,
		"water":[Array(Map.river_polygon()).map(func(p:Vector2): return Points.pair(p)),Array(Map.pond_polygon()).map(func(p:Vector2): return Points.pair(p))],
		"accepted":plan.accepted.size(),"rejected":plan.rejected.size()})
	_write("capture.json",{"task":"VGROUND-008","profile":profile,"window":Points.pair(size),"display":DisplayServer.get_name(),
		"engine":Engine.get_version_info().string,"rows":rows,"errors":errors,"simulation_frozen":true,"performance_eligible":false,"gpu_time_ms":null,
		"ordinary_scene_has_procedural_seed":false,"diagnostic_overlay_only":true,"rain_pixel_equality_not_claimed":true})
	quit(0 if errors.is_empty() else 2)

## Возвращает исходное состояние вокруг старого и отфильтрованного диагностического слоя.
func _case(id: String, player: Vector2) -> void:
	game.player=player; game.facing=Vector2.DOWN; game.update_camera(); preload("res://scripts/systems/presentation_pose_system.gd").reset(game)
	for mode in ["control-before","before","after","control-after"]:
		overlay.visible=mode in ["before","after"] and game.current_location=="overworld"
		overlay.guarded=mode=="after"; overlay.queue_redraw(); bg.queue_redraw(); await _settle(150)
		await _shot(id+"-"+mode,mode)

## Записывает настоящий кадр с полными состояниями вокруг четырёх штатных draw.
func _shot(id: String, mode: String) -> void:
	game.message=""; game.observe_draw=false; await _redraw(4)
	game.draw_records.clear(); game.observe_draw=true; await _redraw(4); game.observe_draw=false
	var image:=root.get_texture().get_image(); image.save_png(folder.path_join(id+".png")); _write(id+"-draws.json",game.draw_records)
	if image.get_size()!=size or DisplayServer.window_get_size()!=size or not DisplayServer.window_is_focused(): errors.append(id+": size/focus changed")
	rows.append({"id":id,"mode":mode,"readback":Points.pair(image.get_size()),"logical":Points.pair(root.get_visible_rect().size),
		"camera":Points.pair(game.camera_offset),"player":Points.pair(game.player),"location":game.current_location,"season":bg.season,"weather":bg.weather,
		"draws":game.draw_records.size(),"snapshot":game.SaveSystem.snapshot(game),"focused":DisplayServer.window_is_focused(),
		"physical":Points.pair(DisplayServer.window_get_size()),"zoom":game.get_meta(&"camera_reference_zoom"),"diagnostic":overlay.visible})
	print("DECORATION SHOT ",id)

## Сохраняет прозрачный лист реальных травинок в полном мировом масштабе, без отдаления скриншота.
func _board(guarded: bool) -> void:
	var view:=SubViewport.new(); view.size=Vector2i(Map.WORLD_SIZE); view.disable_3d=true; view.transparent_bg=true; view.render_target_update_mode=SubViewport.UPDATE_ONCE
	var board:=preload("res://tools/qa/ground/decoration_overlay.gd").new(); board.guarded=guarded; root.add_child(view); view.add_child(board)
	await RenderingServer.frame_post_draw
	view.get_texture().get_image().save_png(folder.path_join("seed-"+("after" if guarded else "before")+".png"))
	view.queue_free(); await process_frame

## Ждёт реальные callbacks при остановленной симуляции; это не замер FPS.
func _redraw(count: int) -> void:
	for i in count: game.queue_redraw(); await RenderingServer.frame_post_draw

## Позволяет оконному серверу закончить размещение и перерисовку.
func _settle(ms: int) -> void:
	var deadline:=Time.get_ticks_msec()+ms
	while Time.get_ticks_msec()<deadline: game.queue_redraw(); await RenderingServer.frame_post_draw

## Переводит геометрию в числовые пары для независимой проверки.
func _rect(rect: Rect2) -> Array:
	return [rect.position.x,rect.position.y,rect.size.x,rect.size.y]

## Пишет только в свежий каталог доказательств.
func _write(name: String, value: Variant) -> void:
	FileAccess.open(folder.path_join(name),FileAccess.WRITE).store_string(JSON.stringify(value)+"\n")
