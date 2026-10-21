extends SceneTree

const Fixture := preload("res://tools/ground_seasons_fixture.gd")
const Points := Fixture.Points
var folder := ""
var profile := ""
var size := Vector2i(1152,648)
var game: Node
var bg: Node
var rows := []
var climates := []
var errors := []

## Требует свежий профиль и настоящий дисплей; обычные сохранения не используются.
func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): folder=arg.trim_prefix("--output=")
		elif arg.begins_with("--profile="): profile=arg.trim_prefix("--profile=")
		elif arg=="--wide": size=Vector2i(1280,720)
	if folder.is_empty() or not profile.begins_with("Codex-VGROUND-010-") or "/" in profile or "\\" in profile:
		push_error("Fresh isolated output/profile required"); quit(2); return
	ProjectSettings.set_setting("application/config/use_custom_user_dir",true)
	ProjectSettings.set_setting("application/config/custom_user_dir_name",profile)
	_start.call_deferred()

## Принимает пять климатических состояний на одном замороженном мире и шести одинаковых камерах.
func _start() -> void:
	if DisplayServer.get_name()=="headless" or DirAccess.dir_exists_absolute(folder) or not OS.get_user_data_dir().ends_with(profile) or FileAccess.file_exists("user://farm-settings.cfg"):
		push_error("Native display and unused paths required"); quit(2); return
	DirAccess.make_dir_recursive_absolute(folder)
	print("GROUND SEASONS INIT scene")
	game=Points.create_game(); game.set_script(preload("res://tools/render_order_game.gd")); root.add_child(game); current_scene=game
	Points.configure(game,Points.registry().points[0]); preload("res://scripts/systems/world_projection_system.gd").set_reference_zoom(game,1.2)
	bg=game.get_node("WorldBackground")
	for cell:Vector2i in game.plots:
		game.plots[cell].tilled=cell.y>0; game.plots[cell].planted=false; game.plots[cell].watered=cell.x>=3 and cell.y>0
	root.title="VGROUND-010 | Проверка сезонов — окно закроется автоматически"
	root.mode=Window.MODE_WINDOWED; root.size=size; root.show(); root.grab_focus()
	print("GROUND SEASONS INIT window shown")
	await _settle(1000); root.mode=Window.MODE_WINDOWED; await _settle(800); root.size=size; root.show(); root.grab_focus(); await _settle(800)
	for attempt in 15:
		if root.mode==Window.MODE_WINDOWED and DisplayServer.window_get_size()==size: break
		root.mode=Window.MODE_WINDOWED; root.size=size; await _settle(200)
	if root.mode!=Window.MODE_WINDOWED or DisplayServer.window_get_size()!=size:
		push_error("Native size did not settle"); quit(2); return
	for climate in Fixture.CASES:
		print("GROUND SEASONS CLIMATE ",climate.id)
		Fixture.configure(game,climate,true); await _drain()
		var geometry:=Fixture.geometry(); var rules:=Fixture.rules(game)
		for view:String in Fixture.VIEWS:
			_place(Fixture.VIEWS[view]); await _shot(climate.id+"-"+view,climate,view,true)
		var cache:Image=bg.terrain_viewport.get_texture().get_image(); cache.save_png(folder.path_join(climate.id+"-cache.png"))
		_place(Fixture.VIEWS["farm-end"]); Fixture.configure(game,climate,false)
		await _shot(climate.id+"-ordinary",climate,"farm-end",false)
		var ordinary_same:bool=cache.get_data()==bg.terrain_viewport.get_texture().get_image().get_data()
		Fixture.configure(game,climate,true); var before:=_metrics()
		for i in 10: Fixture.configure(game,climate,true)
		await _redraw(12)
		climates.append({"id":climate.id,"day":game.day,"season":bg.season,"weather":bg.weather,
			"natural_weather":game.WorldEventSystem.location_weather(game.day,"overworld"),"geometry":geometry,"navigation":rules,
			"ordinary_cache_exact":ordinary_same,"idempotent_before":before,"idempotent_after":_metrics()})
	Fixture.configure(game,Fixture.CASES[0],true); await _drain(); _place(Fixture.VIEWS["farm-end"])
	await _shot("spring-return",Fixture.CASES[0],"farm-end",true)
	bg.terrain_viewport.get_texture().get_image().save_png(folder.path_join("spring-return-cache.png"))
	var before:=_metrics(); var cached:Image=bg.terrain_viewport.get_texture().get_image(); var saved:Dictionary=game.SaveSystem.snapshot(game)
	game.MenuSystem.open_pause(game); await _redraw(8); game.MenuSystem.resume(game); await _redraw(8)
	await _redraw(120)
	_write("retained.json",{"callbacks":120,"pause_resume":true,"before":before,"after":_metrics(),
		"cache_exact":cached.get_data()==bg.terrain_viewport.get_texture().get_image().get_data(),"save_before":saved,"save_after":game.SaveSystem.snapshot(game),
		"geometry_after":Fixture.geometry()})
	if not game.BuildingSystem.enter(game,"cottage"): errors.append("house entry failed")
	await _drain(); await _shot("interior",Fixture.CASES[0],"interior",false)
	if not game.BuildingSystem.leave(game): errors.append("house exit failed")
	await _drain(); Fixture.configure(game,Fixture.CASES[0],true); _place(Fixture.VIEWS["farm-end"])
	await _shot("returned",Fixture.CASES[0],"farm-end",true)
	_write("capture.json",{"task":"VGROUND-010","profile":profile,"window":Points.pair(size),"display":DisplayServer.get_name(),
		"engine":Engine.get_version_info().string,"rows":rows,"climates":climates,"errors":errors,"simulation_frozen":true,"performance_eligible":false,"gpu_time_ms":null,
		"plot_water_fixed_by_fixture":true,"reference_effects_suppressed":preload("res://scripts/presentation/visual_reference_mode.gd").EFFECTS,
		"ordinary_frames":"inspection only; moving precipitation is not an equality control"})
	quit(0 if errors.is_empty() else 2)

## Сохраняет настоящий кадр и четыре полных снимка вокруг штатного draw.
func _shot(id: String, climate: Dictionary, view: String, reference: bool) -> void:
	game.message=""; game.observe_draw=false; await _redraw(4)
	game.draw_records.clear(); game.observe_draw=true; await _redraw(4); game.observe_draw=false
	var image:=root.get_texture().get_image(); image.save_png(folder.path_join(id+".png")); _write(id+"-draws.json",game.draw_records)
	if image.get_size()!=size or DisplayServer.window_get_size()!=size or not DisplayServer.window_is_focused(): errors.append(id+": size/focus changed")
	rows.append({"id":id,"climate":climate.id,"view":view,"reference":reference,"readback":Points.pair(image.get_size()),
		"logical":Points.pair(root.get_visible_rect().size),"physical":Points.pair(DisplayServer.window_get_size()),"focused":DisplayServer.window_is_focused(),
		"player":Points.pair(game.player),"camera":Points.pair(game.camera_offset),"zoom":game.get_meta(&"camera_reference_zoom"),"day":game.day,
		"location":game.current_location,"season":bg.season,"weather":game.WorldEventSystem.weather(game),"draws":game.draw_records.size(),"snapshot":game.SaveSystem.snapshot(game),"metrics":_metrics()})
	print("GROUND SEASONS SHOT ",id)

## Читает ограниченные счётчики и идентичность существующего target без заявления GPU-времени.
func _metrics() -> Dictionary:
	return {"requests":bg.terrain_requests,"paints":bg.terrain_canvas.paint_count,"revision":bg.terrain_revision.revision,
		"target_id":bg.terrain_viewport.get_instance_id(),"texture_id":bg.terrain_viewport.get_texture().get_instance_id(),
		"targets":bg.get_children().filter(func(n:Node): return n is SubViewport).size(),"ready":bg.terrain_ready,
		"target_size":Points.pair(bg.terrain_viewport.size),"pending":bg.terrain_revision.pending.size()}

## Ждёт фактического завершения графической очереди; это не измерение плавности.
func _drain() -> void:
	for i in 100:
		await _redraw(1)
		if bg.terrain_ready and bg.terrain_revision.pending.is_empty() and not bg.terrain_revision.active.has_area(): return
	errors.append("terrain did not drain")

## Сохраняет одну и ту же позу и положение камеры для каждого вида календаря.
func _place(player: Vector2) -> void:
	game.player=player; game.facing=Vector2.DOWN; game.update_camera(); preload("res://scripts/systems/presentation_pose_system.gd").reset(game)

## Ждёт реальные callbacks при неподвижной симуляции.
func _redraw(count: int) -> void:
	for i in count: game.queue_redraw(); await RenderingServer.frame_post_draw

## Позволяет оконному серверу закончить размещение окна.
func _settle(ms: int) -> void:
	var deadline:=Time.get_ticks_msec()+ms
	while Time.get_ticks_msec()<deadline: game.queue_redraw(); await RenderingServer.frame_post_draw

## Записывает данные только в новый каталог доказательств.
func _write(name: String, value: Variant) -> void:
	FileAccess.open(folder.path_join(name),FileAccess.WRITE).store_string(JSON.stringify(value)+"\n")
