extends SceneTree

const Points := preload("res://tools/visual_camera_points.gd")
const Observer := preload("res://tools/render_order_game.gd")
const Reference := preload("res://scripts/presentation/visual_reference_mode.gd")
const WorldProjection := preload("res://scripts/systems/world_projection_system.gd")
const Pose := preload("res://scripts/systems/presentation_pose_system.gd")
const Clock := preload("res://scripts/presentation/village_ground_clock.gd")
var folder := ""
var profile := ""
var size := Vector2i(1152,648)
var game: Node
var bg: Node
var records := []
var errors := []

## Требует свежие отдельные каталог и профиль до создания настоящей игровой сцены.
func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): folder=arg.trim_prefix("--output=")
		elif arg.begins_with("--profile="): profile=arg.trim_prefix("--profile=")
		elif arg=="--wide": size=Vector2i(1280,720)
	if folder.is_empty() or not profile.begins_with("Codex-VRENDER-003-") or "/" in profile or "\\" in profile:
		push_error("Fresh isolated ground-layer output/profile required"); quit(2); return
	ProjectSettings.set_setting("application/config/use_custom_user_dir",true)
	ProjectSettings.set_setting("application/config/custom_user_dir_name",profile)
	_start.call_deferred()

## Снимает штатную сцену при двух проходах и проверяет реальный кеш, а не только исходный код.
func _start() -> void:
	if DisplayServer.get_name()=="headless" or not OS.get_user_data_dir().ends_with(profile) or DirAccess.dir_exists_absolute(folder) or FileAccess.file_exists("user://farm-settings.cfg"):
		push_error("Native display and fresh isolated paths required"); quit(2); return
	DirAccess.make_dir_recursive_absolute(folder)
	game=Points.create_game(); game.set_script(Observer); game.world_loot_seed=Points.SEED; root.add_child(game); current_scene=game
	Points.configure(game,Points.registry().points[0]); WorldProjection.set_reference_zoom(game,1.2); bg=game.get_node("WorldBackground")
	root.title="VRENDER-003 | static ground / live surface"
	await _settle(1000); root.mode=Window.MODE_WINDOWED; await _settle(1000); root.size=size; root.show(); root.grab_focus(); await _settle(1000)
	await _pair("village",Vector2(600.25,700.25))
	var tree:=Vector2.ZERO; var bush:=Vector2.ZERO
	for food in game.food_nodes:
		if food.kind=="apple" and tree==Vector2.ZERO: tree=food.position
		if food.kind=="berries" and bush==Vector2.ZERO: bush=food.position
	if tree==Vector2.ZERO or bush==Vector2.ZERO: errors.append("actual foreground fixtures absent")
	await _pair("tree-behind",tree+Vector2(0,-20)); await _pair("tree-front",tree+Vector2(0,50)); await _pair("bush",bush+Vector2(0,8))
	await _pair("bridge-west",game.VillageLayoutSystem.BRIDGES[0].get_center())
	await _pair("bridge-east",game.VillageLayoutSystem.BRIDGES[1].get_center())
	bg.set_environment("winter","snow"); await _pair("winter",Vector2(600.25,700.25))
	bg.set_environment("summer","rain"); await _pair("rain",Vector2(600.25,700.25))
	bg.set_environment("spring","clear")
	_set_pose(Vector2(600.25,700.25)); bg.set_ground_split(true); await _redraw(8)
	var key:=InputEventKey.new(); key.keycode=KEY_ESCAPE; key.pressed=true; game._unhandled_input(key)
	if not game.menu_state.pause_open: errors.append("production Escape did not open pause")
	await _pair("manual-pause",Vector2(600.25,700.25)); game.MenuSystem.resume(game)
	if not game.BuildingSystem.enter(game,"cottage"): errors.append("real home entry failed")
	await _pair("interior",game.player)
	if not game.BuildingSystem.leave(game): errors.append("real home exit failed")
	await _pair("returned",Vector2(600.25,700.25))
	await _cold_control(); await _direct_control(); await _water_control(); await _live_control()
	_write("capture.json",{"task":"VRENDER-003","profile":profile,"pid":OS.get_process_id(),"window":Points.pair(size),
		"display_server":DisplayServer.get_name(),"engine":Engine.get_version_info().string,"driver":RenderingServer.get_current_rendering_driver_name(),
		"records":records,"errors":errors,"simulation_frozen":true,"performance_eligible":false})
	quit(0 if errors.is_empty() else 2)

## Сравнивает прежний монолит и разделённые проходы с одной позой, средой и физическим окном.
func _pair(id: String, player: Vector2) -> void:
	_set_pose(player); Reference.enable(game,true)
	for split in [false,true]:
		bg.set_ground_split(split); await _redraw(8)
		await _shot(id+("-split" if split else "-legacy"))

## Показывает, что цвет поверхности меняется вне кеша, а верхний мост остаётся отдельным перекрытием.
func _water_control() -> void:
	_set_pose(game.VillageLayoutSystem.BRIDGES[0].get_center()); bg.set_ground_split(true); await _redraw(8)
	var cache:=_cache_hash(); var count:int=bg.terrain_canvas.paint_count
	await _shot("water-white"); bg.water_layer.modulate=Color(1,0.45,0.45,1); await _redraw(4); await _shot("water-tinted")
	if _cache_hash()!=cache or bg.terrain_canvas.paint_count!=count: errors.append("surface modulate rebuilt or changed base cache")
	bg.water_layer.modulate=Color.WHITE

## Наблюдает самый первый кадр инвалидированного кеша: полный прямой fallback не теряет мост или воду.
func _cold_control() -> void:
	_set_pose(Vector2(600.25,700.25)); bg.set_ground_split(true); await _redraw(8)
	bg.set_meta("terrain_direct",true); bg.queue_redraw(); await _redraw(8); await _shot("cold-reference")
	bg.set_meta("terrain_direct",false); bg.queue_redraw(); await _redraw(8)
	bg.refresh_terrain(); var before:=_state()
	if before.ready or bg.water_layer.visible: errors.append("cold cache exposed incomplete split surface")
	game.draw_records.clear(); game.observe_draw=true; game.queue_redraw(); await RenderingServer.frame_post_draw; game.observe_draw=false
	root.get_texture().get_image().save_png(folder.path_join("cold-first.png")); _write("cold-first-draws.json",game.draw_records)
	_write("cold.json",{"before":before,"after":_state(),"draws":game.draw_records.size(),"readback":Points.pair(root.get_texture().get_image().get_size())})

## Перестраивает сезон при прямом fallback и проверяет возвращение к полному прозрачному кешу.
func _direct_control() -> void:
	_set_pose(Vector2(600.25,700.25)); bg.set_ground_split(true); bg.set_meta("terrain_direct",true)
	bg.set_environment("winter","snow"); bg.queue_redraw(); await _redraw(8); await _shot("direct-fallback")
	bg.set_meta("terrain_direct",false); bg.queue_redraw(); await _redraw(8); await _shot("direct-return")
	bg.set_environment("spring","clear"); await _redraw(8)

## Проверяет движение существующего декора, ручную паузу и триста кадров без перестройки грунта.
func _live_control() -> void:
	Reference.disable(game); game.settings_state.reduced_motion=false; _set_pose(Vector2(1944,648))
	game.set_meta(Clock.META,0.0); await _redraw(8); await _shot("live-zero")
	var start:=_state(); var cache:=_cache_hash()
	for frame in 300:
		Clock.advance(game,1.0/60.0); game.queue_redraw(); await RenderingServer.frame_post_draw
	var after:=_state()
	for key in ["requests","base_paints","surface_paints","cover_paints","cutout_paints"]:
		if start[key]!=after[key]: errors.append("hot clock rebuilt retained commands: "+key)
	if _cache_hash()!=cache: errors.append("hot clock changed static texture")
	_write("hot-loop.json",{"callbacks":300,"before":start,"after":after,"cache_before":cache,"cache_after":_cache_hash(),"performance_eligible":false})
	await _shot("live-five")
	var event:=InputEventKey.new(); event.keycode=KEY_ESCAPE; event.pressed=true; game._unhandled_input(event)
	var frozen:=Clock.seconds(game)
	for frame in 30: Clock.advance(game,1.0/60.0); game.queue_redraw(); await RenderingServer.frame_post_draw
	if not game.menu_state.pause_open or Clock.seconds(game)!=frozen: errors.append("decorative clock advanced under native manual pause")
	await _shot("live-paused"); game.MenuSystem.resume(game); Clock.advance(game,0.25)
	if not is_equal_approx(Clock.seconds(game),frozen+0.25): errors.append("resume did not continue without catch-up")
	await _shot("live-resumed")

## Сохраняет полный framebuffer и настоящие до/после snapshots; чтение текстуры не является FPS-замером.
func _shot(id: String) -> void:
	game.message=""; game.observe_draw=false; await _redraw(4)
	game.draw_records.clear(); game.observe_draw=true; await _redraw(4); game.observe_draw=false
	var image:=root.get_texture().get_image(); image.save_png(folder.path_join(id+".png")); _write(id+"-draws.json",game.draw_records)
	for row in game.draw_records:
		if not row.equal or not row.geometry_equal or row.queue_after!=0: errors.append(id+": draw mutated saved gameplay/geometry/foreground queue")
	if image.get_size()!=size or DisplayServer.window_get_size()!=size or not DisplayServer.window_is_focused(): errors.append(id+": host/focus/readback changed")
	var record:=_state(); record.merge({"id":id,"readback":Points.pair(image.get_size()),"logical":Points.pair(root.get_visible_rect().size),"draws":game.draw_records.size(),
		"draw_calls":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),"texture_bytes":Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED)})
	records.append(record); print("GROUND SHOT ",id)

## Возвращает фактические узлы, режим viewport и счётчики построения команд для независимой проверки.
func _state() -> Dictionary:
	return {"location":game.current_location,"camera":Points.pair(game.camera_offset),"player":Points.pair(game.player),"season":bg.season,"weather":bg.weather,
		"split":bg.ground_split,"ready":bg.terrain_ready,"base_only":bg.terrain_canvas.base_only,"viewport_mode":bg.terrain_viewport.render_target_update_mode,
		"viewport_size":Points.pair(bg.terrain_viewport.size),"requests":bg.terrain_requests,"base_paints":bg.terrain_canvas.paint_count,
		"surface_paints":bg.water_layer.paint_count,"cover_paints":bg.cover_layer.paint_count,"cutout_paints":bg.cutout_layer.paint_count,"surface_visible":bg.water_layer.visible,"cover_visible":bg.cover_layer.visible,
		"surface_behind_parent":bg.water_layer.show_behind_parent,"cover_inside_cache":bg.cover_layer.get_parent()==bg.terrain_canvas,"cutout_visible":bg.cutout_layer.visible,
		"cutout_before_cover":bg.cutout_layer.get_index()<bg.cover_layer.get_index(),"child_viewports":bg.get_children().filter(func(n: Node): return n is SubViewport).size(),
		"time":Clock.seconds(game),"pause":game.menu_state.pause_open,"reference":Reference.active(game),"direct":bool(bg.get_meta("terrain_direct",false))}

## Сверяет байты настоящего offscreen readback, не подменяя их предположением о числе запросов.
func _cache_hash() -> String:
	var hash:=HashingContext.new(); hash.start(HashingContext.HASH_SHA256)
	hash.update(bg.terrain_viewport.get_texture().get_image().get_data())
	return hash.finish().hex_encode()

## Меняет только диагностическую позу с общей штатной проекцией мира и фона.
func _set_pose(player: Vector2) -> void:
	game.player=player; game.facing=Vector2.DOWN; game.update_camera(); Pose.reset(game)

## Ожидает реальные render callbacks, а не ручной вызов renderer вне draw.
func _redraw(count: int) -> void:
	for frame in count: game.queue_redraw(); await RenderingServer.frame_post_draw

## Даёт оконному серверу завершить размещение без короткого SceneTree-таймера.
func _settle(milliseconds: int) -> void:
	var deadline:=Time.get_ticks_msec()+milliseconds
	while Time.get_ticks_msec()<deadline: game.queue_redraw(); await RenderingServer.frame_post_draw

## Пишет доказательства в разрешённый отдельный каталог после callbacks.
func _write(name: String, value: Variant) -> void:
	FileAccess.open(folder.path_join(name),FileAccess.WRITE).store_string(JSON.stringify(value)+"\n")
