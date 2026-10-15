extends SceneTree

const Scene := preload("res://main.tscn")
const Stone := preload("res://scripts/systems/qa_teleport_system.gd")
const WATER_MAPS := {"overworld":"river+pond", "village_river":"river", "cave_lake":"cave_pools", "moon_glade":"decorative_moon_pool", "pirate_ship":"sea_backdrop"}
const POINTS := {"overworld":Vector2(1248,744), "village_river":Vector2(864,744), "cave_lake":Vector2(1200,744), "moon_glade":Vector2(1200,888), "pirate_ship":Vector2(1200,600)}
var game: Node2D
var target: SubViewport
var folder := "res://docs/reports/water-2026-10/before/"
var label := "before"
var samples := 240
var dimensions := Vector2i(1152,648)
var draws := 0
var f10 := false
var only_map := ""

## Запускает изолированный нативный аудит после подготовки окна.
func _initialize() -> void:
	_start.call_deferred()

## Снимает полный каталог карт и сопоставимые реальные кадры без записи пользовательских слотов.
func _start() -> void:
	if DisplayServer.get_name()=="headless": push_error("Для аудита требуется нативный renderer"); quit(2); return
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--label="): label=arg.get_slice("=",1)
		elif arg=="--f10": f10=true
		elif arg.begins_with("--map="): only_map=arg.get_slice("=",1)
		elif arg.begins_with("--samples="): samples=clampi(int(arg.get_slice("=",1)),60,3600)
		elif arg.begins_with("--size="): dimensions=Vector2i(int(arg.get_slice("=",1).get_slice("x",0)),int(arg.get_slice("=",1).get_slice("x",1)))
	folder="res://docs/reports/water-2026-10/"+label+"/"; DirAccess.make_dir_recursive_absolute(folder)
	var user_levels := user_level_inventory()
	ProjectSettings.set_setting("application/config/use_custom_user_dir",true)
	ProjectSettings.set_setting("application/config/custom_user_dir_name","Codex-Water-Audit")
	if not OS.get_user_data_dir().contains("Codex-Water-Audit"): push_error("Не изолирован пользовательский профиль"); quit(2); return
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED); root.size=dimensions
	root.content_scale_mode=Window.CONTENT_SCALE_MODE_DISABLED
	seed(20261015)
	var container := SubViewportContainer.new(); root.add_child(container)
	target=SubViewport.new(); target.size=dimensions; target.disable_3d=true; target.render_target_update_mode=SubViewport.UPDATE_ALWAYS; container.add_child(target)
	target.canvas_transform=Transform2D().scaled(Vector2(dimensions)/Vector2(1152,648))
	game=Scene.instantiate(); game.set_meta("capture_windowed",true); target.add_child(game); current_scene=container
	game.get_node("WorldBackground").terrain_canvas.draw.connect(func(): draws+=1)
	await process_frame
	root.mode=Window.MODE_WINDOWED; root.size=dimensions; root.content_scale_factor=1.0
	root.content_scale_mode=Window.CONTENT_SCALE_MODE_DISABLED
	for frame in 8: await RenderingServer.frame_post_draw
	if target.size!=dimensions: push_error("Размер нативного framebuffer не соответствует протоколу"); quit(2); return
	game.set_process_input(false); game.set_process_unhandled_input(false)
	game.audio_enabled=false; game.language_screen=false; game.title_screen=false; game.tutorial_visible=false
	game.FarmLifeSystem.state(game).first_day=6; game.FarmLifeSystem.state(game).cutscene=""; game.FarmLifeSystem.state(game).cutscene_timer=0
	game.state.player.profile.created=true; game.FirstChapterSystem.state(game).completed=true; game.LocaleSystem.current="ru"
	game.discovery_current.clear(); game.change_inventory_count(Stone.KIND,1)
	var catalog := []
	for location in Stone.locations(game):
		catalog.append({"id":location,"group":Stone.group(game,location),"water":WATER_MAPS.get(location,"none"),"fishing":location in ["overworld","village_river"],"bridges":2 if location in ["overworld","village_river"] else 0})
	FileAccess.open(folder+"inventory.json",FileAccess.WRITE).store_string(JSON.stringify({"locations":catalog,"custom_levels":user_levels,"authority":"QA teleport unions the runtime registries; WATER_MAPS classifies all active background draw paths inspected in WATER-01"},"\t")+"\n")
	var measurements := []
	for location in WATER_MAPS:
		if not only_map.is_empty() and location!=only_map: continue
		if not Stone.open(game) or not Stone.travel(game,location): push_error("Не выполнен переход в "+location); quit(1); return
		game.player=POINTS[location]; game.update_camera(); game.menu_state.recovery_grace=60.0; root.grab_focus()
		game.message=""; game.hud_message_timer=0.0; game.discovery_current.clear()
		if f10: game.set_meta(game.DebugOverlaySystem.META_KEY,game.DebugOverlaySystem.default_state())
		for frame in 120: await RenderingServer.frame_post_draw
		if f10:
			var budget: int = game.get_meta(game.DebugOverlaySystem.META_KEY,{}).get("grid_build",{}).get("pending",[]).size()*4+240
			for frame in budget:
				if game.get_meta(game.DebugOverlaySystem.META_KEY,{}).get("grid_build",{}).is_empty(): break
				await RenderingServer.frame_post_draw
			if not game.get_meta(game.DebugOverlaySystem.META_KEY,{}).get("grid_build",{}).is_empty(): push_error("Не завершена навигационная сетка F10"); quit(2); return
		target.get_texture().get_image().save_png(folder+location+"-"+str(dimensions.x)+"-gameplay.png")
		if location=="overworld":
			var overview := SubViewport.new(); overview.size=Vector2i(1200,684); overview.disable_3d=true; root.add_child(overview)
			var background := preload("res://scripts/world_background.gd").new(); background.scale=Vector2(0.5,0.5); overview.add_child(background)
			for frame in 8: await RenderingServer.frame_post_draw
			overview.get_texture().get_image().save_png(folder+"overworld-overview.png"); overview.queue_free()
		for frame in 120: await RenderingServer.frame_post_draw
		for repeat in 3:
			if target.size!=dimensions: push_error("Framebuffer изменился во время трассы"); quit(2); return
			var ticks := Time.get_ticks_usec(); var frames := []; var process_ms := []; var physics_ms := []; var focused := 0; var started_draws := draws
			for frame in samples:
				await RenderingServer.frame_post_draw
				var now := Time.get_ticks_usec(); frames.append(now-ticks); ticks=now
				if root.has_focus(): focused+=1
				process_ms.append(Performance.get_monitor(Performance.TIME_PROCESS)*1000); physics_ms.append(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)*1000)
			measurements.append({"location":location,"repeat":repeat,"frame_usec":frames,"process_ms":process_ms,"physics_ms":physics_ms,"focused_frames":focused,"terrain_rebuilds":draws-started_draws,"texture_bytes":Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED),"static_bytes":Performance.get_monitor(Performance.MEMORY_STATIC),"nodes":Performance.get_monitor(Performance.OBJECT_NODE_COUNT),"resources":Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT),"draw_calls":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),"p95_usec":percentile(frames,0.95),"p99_usec":percentile(frames,0.99),"max_usec":frames.max()})
			print("WATER AUDIT: ",location," repeat ",repeat," p95=",percentile(frames,0.95)/1000,"ms")
	var rendered_size := target.get_texture().get_image().get_size()
	if rendered_size!=dimensions: push_error("Размер итогового framebuffer не соответствует протоколу"); quit(2); return
	var report := {"label":label,"engine":Engine.get_version_info().string,"adapter":RenderingServer.get_video_adapter_name(),"driver":RenderingServer.get_current_rendering_driver_name(),"window":[root.size.x,root.size.y],"render_pixels":[rendered_size.x,rendered_size.y],"canvas":[1152,648],"vsync":DisplayServer.window_get_vsync_mode(),"warmup_frames":240,"samples_per_repeat":samples,"seed":20261015,"protocol":"native frame_post_draw; fixed render target + host window composite; live simulation; fixed camera; isolated profile; invulnerable hero; screenshot readbacks outside measured intervals; route transitions excluded; GPU time unavailable in this probe; fixed target is not a physical-device claim","measurements":measurements}
	FileAccess.open(folder+"native-"+str(dimensions.x)+".json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t")+"\n")
	print("WATER AUDIT COMPLETE: ",catalog.size()," maps; ",measurements.size()," repeats")
	quit()

## Описывает только документы конструктора, не читая игровые слоты и не изменяя исходники пользователя.
func user_level_inventory() -> Array:
	var result := []
	for parent in ["res://level_designs/published","user://level_designs"]:
		if not DirAccess.dir_exists_absolute(parent): continue
		for filename in DirAccess.get_files_at(parent):
			if not filename.ends_with(".json"): continue
			var path: String = String(parent).path_join(filename); var data: Variant=JSON.parse_string(FileAccess.get_file_as_string(path))
			result.append({"source":"published" if parent.begins_with("res:") else "user","file_hash":filename.sha256_text(),"valid_json":data is Dictionary,"objects":data.get("objects",[]).size() if data is Dictionary else 0})
	return result

## Возвращает фактический квантиль без отбрасывания длинных кадров.
func percentile(values: Array, fraction: float) -> float:
	var sorted := values.duplicate(); sorted.sort()
	return float(sorted[clampi(ceili(sorted.size()*fraction)-1,0,sorted.size()-1)])
